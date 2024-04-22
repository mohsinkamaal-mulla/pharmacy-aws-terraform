data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "local_file" "public_key" {
    filename = "${path.root}/id_rsa.pub"
}

data "local_file" "private_key" {
    filename = "${path.root}/id_rsa"
}

resource "aws_key_pair" "trust" {
  key_name   = "trust-key"
  public_key = data.local_file.public_key.content
  tags = {
      Name = "Trust-project"
  }
}


resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id = var.priv_subnet_id
  key_name = aws_key_pair.trust.key_name
  vpc_security_group_ids = ["${var.private_security_group_id}"]

  root_block_device {
    volume_size = 30
  }

  tags = {
    Name = "Trust-DevCluster"
  }
  depends_on = [aws_key_pair.trust]
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.nano"
  user_data = templatefile("${path.module}/templates/hosts.tftpl", { jenkins_ip = "${aws_instance.jenkins.private_ip}", public_key = "${data.local_file.public_key.content}", private_key = "${data.local_file.private_key.content}"})
  subnet_id = var.bastion_subnet_id
  key_name = aws_key_pair.trust.key_name
  vpc_security_group_ids = ["${var.bastion_security_group_id}"]
  tags = {
    Name = "Trust-Workstation"
  }
  depends_on = [aws_key_pair.trust]
}

resource "aws_lb" "alb" {
  name               = "trust-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.app_security_group_id}"]
  subnets = [for subnet in var.public_subnet_id : subnet]
  tags = {
    Name = "Trust-ALB"
  }
}

resource "aws_lb_target_group" "jenkins" {
  name     = "jenkins-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port = 8080
    path = "/login"
  }
}

# resource "aws_lb_target_group" "app" {
#   name     = "app-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = var.vpc_id
# }

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = aws_instance.jenkins.id
  port             = 8080
}


# resource "aws_lb_target_group_attachment" "app" {
#   target_group_arn = aws_lb_target_group.app.arn
#   target_id        = aws_instance.jenkins.id
#   port             = 80
# }

# resource "aws_lb_listener" "lb" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = "80"
#   protocol          = "HTTP"
#   tags = {
#     Name = "Trust-ALB"
#   }
#   default_action {
#     type             = "forward"
#     forward {
#       # target_group {
#       #   arn = "${aws_lb_target_group.jenkins.arn}"
#       # }
#       target_group {
#         arn = "${aws_lb_target_group.app.arn}"
#       }
#       stickiness {
#         enabled = true
#         duration = 86400
#       }
#     }
#   }
# }

resource "aws_lb_listener" "jenkins-lb" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  tags = {
    Name = "Trust-ALB"
  }
  default_action {
    type             = "forward"
    forward {
      target_group {
        arn = "${aws_lb_target_group.jenkins.arn}"
      }
      # target_group {
      #   arn = "${aws_lb_target_group.app.arn}"
      # }
      stickiness {
        enabled = true
        duration = 86400
      }
    }
  }
}

# resource "aws_lb_listener_rule" "jenkins" {
#   listener_arn = aws_lb_listener.jenkins-lb.arn
#   condition {
#     path_pattern {
#       values = ["/jenkins", "/jenkins/*"]
#     }
#   }
#   action {
#     type = "forward"
#     target_group_arn = aws_lb_target_group.jenkins.arn
#   }
#   # action {
#   #   type = "redirect"
#   #   target_group_arn = aws_lb_target_group.jenkins.arn
#   #   redirect {
#   #     host = "#{host}"
#   #     path = "/jenkins"
#   #     protocol = "HTTP"
#   #     status_code = "HTTP_301"
#   #   }
#   # }
# }

# resource "aws_lb_listener_rule" "app" {
#   listener_arn = aws_lb_listener.lb.arn

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/*"]
#     }
#   }
# }

resource "aws_route53_zone" "dev" {
  name = "trustweb.tk"

  tags = {
    Environment = "Trust"
  }
}

resource "aws_db_instance" "mysql" {
  identifier = "trustdb"
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = var.db_instance_class
  name                 = "trustdb"
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = "dev"
  storage_encrypted    = true
  skip_final_snapshot  = false
  publicly_accessible = true
  depends_on = [aws_db_subnet_group.db_subnet_grp]
}

resource "aws_db_subnet_group" "db_subnet_grp" {
  name       = "dev"
  subnet_ids = concat(var.pub_subnet_id_list)

  tags = {
    Name = "Dev Subnet Group"
  }
}
resource "aws_ecr_repository" "trust-backend" {
  name                 = "trust-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr-backend-policy" {
  repository = aws_ecr_repository.trust-backend.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecr_repository" "trust-frontend" {
  name                 = "trust-frontend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr-frontend-policy" {
  repository = aws_ecr_repository.trust-frontend.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecr_repository" "ads-backend" {
  name                 = "ads-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr-ads-backend-policy" {
  repository = aws_ecr_repository.ads-backend.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecr_repository" "trust-usrmgmt" {
  name                 = "trust-usrmgmt"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr-trust-usrmgmt-policy" {
  repository = aws_ecr_repository.trust-usrmgmt.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}



resource "aws_s3_bucket" "s3" {
  bucket = "trust-s3-bucket"
  tags = {
    Name        = "Trust"
    Environment = "Dev"
  }

  versioning {
    enabled = true
  }

}