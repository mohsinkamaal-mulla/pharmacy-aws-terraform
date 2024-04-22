module "networking" {
  source           = "./modules/networking"
  vpc_cidr         = var.vpc_cidr
  subnet_az        = var.subnet_az
  priv_subnet_cidr = var.priv_subnet_cidr
  priv_subnet_name = var.priv_subnet_name
  pub_subnet_cidr  = var.pub_subnet_cidr
  pub_subnet_name  = var.pub_subnet_name
}

module "instances" {
  source                    = "./modules/instances"
  db_username = var.db_username
  db_password = var.db_password
  db_instance_class = var.db_instance_class
  vpc_id                    = module.networking.vpc_id
  public_subnet_id          = module.networking.public_subnet_id
  bastion_security_group_id = module.networking.bastion_security_group_id
  bastion_subnet_id         = module.networking.bastion_subnet_id
  priv_subnet_id            = module.networking.priv_subnet_id
  private_security_group_id = module.networking.private_security_group_id
  app_security_group_id     = module.networking.app_security_group_id
  priv_subnet_id_list = module.networking.priv_subnet_id_list
  pub_subnet_id_list = module.networking.pub_subnet_id_list
}