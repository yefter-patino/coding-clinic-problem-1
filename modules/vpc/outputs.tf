output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "The Availability Zones that were used."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (one per AZ)."
  value       = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables."
  value       = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways (useful for allow-lists)."
  value       = aws_eip.nat[*].public_ip
}

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint (null if disabled)."
  value       = one(aws_vpc_endpoint.s3[*].id)
}

output "ecr_endpoint_ids" {
  description = "Map of ECR interface endpoint IDs, keyed by service name."
  value       = { for name, ep in aws_vpc_endpoint.ecr : name => ep.id }
}

output "endpoint_security_group_id" {
  description = "Security group used by the interface endpoints (null if disabled)."
  value       = one(aws_security_group.endpoints[*].id)
}
