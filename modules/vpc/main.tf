# ---------------------------------------------------------------
# Lookups (nothing is hardcoded: region and AZ names are discovered)
# ---------------------------------------------------------------
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  # Skip Local Zones / Wavelength Zones, they are opt-in only.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ---------------------------------------------------------------
# Small calculations used below
# ---------------------------------------------------------------
locals {
  name   = "${var.name_prefix}-${var.environment}"
  region = data.aws_region.current.region

  # Take the first N zones of whatever region we are in.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private subnets start halfway through the CIDR space so they never
  # overlap with the public ones. (newbits=4 -> public 0-7, private 8-15)
  private_offset = pow(2, var.subnet_newbits - 1)

  # One NAT gateway for everyone, or one per AZ.
  nat_count = var.single_nat_gateway ? 1 : var.az_count

  ecr_services = var.enable_ecr_endpoints ? toset(["ecr.api", "ecr.dkr"]) : toset([])

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ---------------------------------------------------------------
# VPC
# ---------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })

  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available.names) >= var.az_count
      error_message = "This region does not have enough Availability Zones for az_count."
    }
  }
}

# Lock the default security group: no inbound, no outbound.
# Anything that needs network access must use its own security group.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-default-sg-locked" })
}

# ---------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index)

  # Instances do NOT get a public IP automatically (safer default).
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index + local.private_offset)

  tags = merge(local.common_tags, {
    Name = "${local.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# ---------------------------------------------------------------
# Internet gateway + public route table
# ---------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------
# NAT gateways (live in the PUBLIC subnets, serve the PRIVATE ones)
# ---------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${local.name}-nat-eip-${count.index + 1}" })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, { Name = "${local.name}-nat-${count.index + 1}" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------
# Private route tables (one per AZ, each points at a NAT gateway)
# ---------------------------------------------------------------
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-private-rt-${local.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count = var.az_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---------------------------------------------------------------
# VPC endpoints: reach AWS services without going through the NAT
# ---------------------------------------------------------------

# S3 gateway endpoint: free, works by adding a route to the private route tables.
# ECR stores image layers in S3, so this is needed for ECR pulls too.
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(local.common_tags, { Name = "${local.name}-vpce-s3" })
}

# Security group for the ECR interface endpoints: only HTTPS from inside the VPC.
resource "aws_security_group" "endpoints" {
  count = var.enable_ecr_endpoints ? 1 : 0

  name        = "${local.name}-vpce-sg"
  description = "Allow HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-vpce-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = var.enable_ecr_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from the VPC"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = merge(local.common_tags, { Name = "${local.name}-vpce-https-in" })
}

# ECR interface endpoints (ecr.api = talk to ECR, ecr.dkr = docker pull/push).
resource "aws_vpc_endpoint" "ecr" {
  for_each = local.ecr_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${local.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpce-${each.key}" })
}
