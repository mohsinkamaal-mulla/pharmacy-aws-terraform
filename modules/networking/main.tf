resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "Trust-VPC"
  }
}

resource "aws_subnet" "private_subnet" {
  count      = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.priv_subnet_cidr, count.index)
  availability_zone = element(var.subnet_az, count.index)
  tags = {
      Name = join("-",[var.priv_subnet_name,count.index+1]),
      "kubernetes.io/role/internal-elb" = "1",
      "kubernetes.io/cluster" = "trust-dev"
  }
}

resource "aws_subnet" "public_subnet" {
  count      = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.pub_subnet_cidr, count.index)
  availability_zone = element(var.subnet_az, count.index)
  map_public_ip_on_launch = true
  tags = {
      Name = join("-",[var.pub_subnet_name,count.index+1]),
      "kubernetes.io/role/elb" = "1",
      "kubernetes.io/cluster" = "trust dev"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet Gateway"
  }
}

resource "aws_eip" "eip_gw" {
    vpc      = true
  tags = {
    Name = "EIP_NAT_GW"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip_gw.id
  subnet_id         = element(aws_subnet.public_subnet.*.id,0)
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route" "private_routes" {
  route_table_id            = aws_route_table.private_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_nat_gateway.natgw.id
  depends_on                = [aws_route_table.private_route_table]
}

resource "aws_route" "public_routes" { 
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.igw.id
  depends_on                = [aws_route_table.public_route_table]
}

resource "aws_route_table_association" "rta_private" {
  count      			= length(var.priv_subnet_cidr)
  subnet_id             = element(aws_subnet.private_subnet.*.id,count.index)
  route_table_id        = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "rta_public" {
  count          = length(var.pub_subnet_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id,count.index)
  route_table_id = aws_route_table.public_route_table.id
}

data "http" "ip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "bastion" {
  name        = "Bastion host SG"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH access to bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.ip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Bastion host SG"
  }
}

resource "aws_security_group" "private" {
  name        = "Private Instances SG"
  description = "Allow VPC inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "All from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["${var.vpc_cidr}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Private Instances SG"
  }
}

resource "aws_security_group" "public" {
  name        = "Public Web SG"
  description = "Allow frontend inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Frontend"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.ip.body)}/32","0.0.0.0/0"]
  }
  ingress {
    description      = "Frontend"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.ip.body)}/32","0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Public Web SG"
  }
}
