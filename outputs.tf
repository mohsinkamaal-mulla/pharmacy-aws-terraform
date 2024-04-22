output "bastion_ip" {
  value = module.instances.bastion_ip
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "private_ips" {
  value = module.instances.private_ips
}