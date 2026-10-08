variable "name_prefix" {
  description = "Prefix added to every resource name, e.g. yefter -> yefter-dev-vpc."
  type        = string
  default     = "yefter"
}

variable "environment" {
  description = "Which environment this VPC is for. Must be dev, stage or prod."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "vpc_cidr" {
  description = "IP range for the whole VPC, e.g. 10.0.0.0/16."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "How many Availability Zones to spread across (2 to 6)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "az_count must be between 2 and 6 (multi-AZ needs at least 2)."
  }
}

variable "subnet_newbits" {
  description = "How many bits to add to the VPC mask for each subnet. 4 turns a /16 into /20 subnets."
  type        = number
  default     = 4

  validation {
    condition     = var.subnet_newbits >= 4 && var.subnet_newbits <= 8
    error_message = "subnet_newbits must be between 4 and 8."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, for dev). false = one NAT per AZ (highly available, for prod)."
  type        = bool
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Create the free S3 gateway endpoint."
  type        = bool
  default     = true
}

variable "enable_ecr_endpoints" {
  description = "Create the ECR interface endpoints (ecr.api and ecr.dkr). These cost money per hour per AZ."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
