variable "region" {
  description = "AWS region to deploy into, e.g. us-east-1."
  type        = string
}

variable "environment" {
  description = "dev, stage or prod."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "yefter"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones (2 to 6)."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheap). false = one NAT per AZ (highly available)."
  type        = bool
  default     = false
}

variable "enable_ecr_endpoints" {
  description = "Create ECR interface endpoints (costs money per hour)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
