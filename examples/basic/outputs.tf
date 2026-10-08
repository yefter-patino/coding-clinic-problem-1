output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "ecr_endpoint_ids" {
  value = module.vpc.ecr_endpoint_ids
}
