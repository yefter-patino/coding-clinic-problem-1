provider "aws" {
  region = var.region

  # Every resource created through this provider gets these tags automatically.
  default_tags {
    tags = var.tags
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = var.name_prefix
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  single_nat_gateway   = var.single_nat_gateway
  enable_ecr_endpoints = var.enable_ecr_endpoints
  tags                 = var.tags
}
