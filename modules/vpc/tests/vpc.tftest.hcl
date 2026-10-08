# Run with:  cd modules/vpc && terraform init -backend=false && terraform test
# These tests use a FAKE AWS provider, so they cost nothing and need no credentials.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
}

run "prod_style_one_nat_per_az" {
  command = plan

  variables {
    az_count           = 3
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "Expected one NAT gateway per AZ (3)."
  }

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.private) == 3
    error_message = "Expected 3 public and 3 private subnets."
  }
}

run "dev_style_single_nat" {
  command = plan

  variables {
    az_count           = 2
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Expected exactly one shared NAT gateway."
  }

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "Each AZ should still have its own private route table."
  }
}

run "public_and_private_do_not_overlap" {
  command = plan

  assert {
    condition     = aws_subnet.public[0].cidr_block != aws_subnet.private[0].cidr_block
    error_message = "Public and private subnets must use different CIDR blocks."
  }
}

run "endpoints_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 1 && length(aws_vpc_endpoint.ecr) == 2
    error_message = "Expected 1 S3 endpoint and 2 ECR endpoints."
  }
}

run "endpoints_can_be_turned_off" {
  command = plan

  variables {
    enable_s3_endpoint   = false
    enable_ecr_endpoints = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 0 && length(aws_vpc_endpoint.ecr) == 0
    error_message = "No endpoints should be created when both are disabled."
  }
}

run "bad_environment_is_rejected" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "single_az_is_rejected" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}
