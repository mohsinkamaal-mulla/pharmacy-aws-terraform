variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "priv_subnet_cidr" {
  description = "The CIDR blocks for the private subnets."
  type        = list(any)
}

variable "pub_subnet_cidr" {
  description = "The CIDR blocks for the public subnets."
  type        = list(any)
}

variable "subnet_az" {
  description = "The availability zones in region us-east-1"
  type        = list(any)
}

variable "priv_subnet_name" {
  description = "The name to be appended as prefix for the private subnets."
  type        = string
}

variable "pub_subnet_name" {
  description = "The name to be appended as prefix for the public subnets."
  type        = string
}

variable "region" {
  description = "Region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "access_key" {
  description = "AWS Access key"
  type        = string
}

variable "secret_key" {
  description = "AWS Secret key"
  type        = string
}

variable db_username {
  description = "Database username"
  type        = string
}

variable db_password {
  description = "Database password"
  type        = string
}

variable db_instance_class {
  description = "Database instance size"
  type        = string    
}