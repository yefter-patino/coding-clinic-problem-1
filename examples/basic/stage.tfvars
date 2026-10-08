# Stage: production-like but smaller; different region to show the module is portable
region               = "us-west-2"
environment          = "stage"
vpc_cidr             = "10.20.0.0/16"
az_count             = 2
single_nat_gateway   = true
enable_ecr_endpoints = true
tags = {
  Owner   = "yefter"
  Project = "vpc-module-clinic"
}
