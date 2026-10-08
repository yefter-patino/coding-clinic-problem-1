# Prod: highly available (3 AZs, one NAT per AZ, ECR endpoints on)
region               = "us-east-1"
environment          = "prod"
vpc_cidr             = "10.30.0.0/16"
az_count             = 3
single_nat_gateway   = false
enable_ecr_endpoints = true
tags = {
  Owner   = "yefter"
  Project = "vpc-module-clinic"
}
