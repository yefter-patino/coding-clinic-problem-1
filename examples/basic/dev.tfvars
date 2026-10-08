# Dev: cheapest setup (one shared NAT, no paid ECR endpoints)
region               = "us-east-1"
environment          = "dev"
vpc_cidr             = "10.10.0.0/16"
az_count             = 2
single_nat_gateway   = true
enable_ecr_endpoints = false
tags = {
  Owner   = "yefter"
  Project = "vpc-module-clinic"
}
