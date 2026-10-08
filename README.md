# yefter-terraform-vpc-module

A beginner-friendly Terraform module that builds a **multi-AZ AWS VPC** with public and
private subnets, NAT gateways, and VPC endpoints for **S3** and **ECR**. The same code works
in any region and for any environment (`dev`, `stage`, `prod`). Nothing is hardcoded:
region, CIDR, number of AZs and NAT layout are all inputs.

## Problem statement

Teams need a repeatable, reviewed network foundation. Copy-pasting console clicks produces
drift and one-off mistakes. This module gives one tested building block that every
environment reuses with different inputs.

## Architecture

```
                        Internet
                           |
                   [Internet Gateway]
                           |
   +-----------------------+------------------------+
   |  VPC (var.vpc_cidr)                            |
   |                                                |
   |  AZ-a                         AZ-b   (... up to az_count)
   |  +----------------+           +----------------+
   |  | public subnet  |           | public subnet  |
   |  |  [NAT GW + EIP]|           |  [NAT GW + EIP]|   <- one per AZ (prod)
   |  +-------+--------+           +-------+--------+      or one shared (dev)
   |          |                            |
   |  +-------v--------+           +-------v--------+
   |  | private subnet |           | private subnet |
   |  | (apps, ECS...) |           | (apps, ECS...) |
   |  +-------+--------+           +-------+--------+
   |          |                            |
   |          +-----> S3 gateway endpoint (free, route table based)
   |          +-----> ECR api + dkr interface endpoints (HTTPS 443, in-VPC only)
   +------------------------------------------------+
```

How the CIDR is split: `cidrsubnet(vpc_cidr, 4, n)`. For a `/16` that gives `/20` subnets.
Public subnets use numbers 0 to 7, private subnets use 8 to 15, so they never overlap.

## What gets created

| Resource | Count |
|---|---|
| VPC (DNS support + hostnames on) | 1 |
| Public subnets | `az_count` |
| Private subnets | `az_count` |
| Internet gateway + public route table | 1 + 1 |
| NAT gateways + Elastic IPs | 1 (`single_nat_gateway = true`) or `az_count` |
| Private route tables (default route to NAT) | `az_count` |
| S3 gateway endpoint | 1 (optional) |
| ECR interface endpoints (`ecr.api`, `ecr.dkr`) + security group | 2 + 1 (optional) |
| Default security group, locked down (no rules) | 1 |

## Prerequisites

- Terraform `>= 1.7` (needed for the built-in test mocks)
- AWS provider `~> 6.0`
- AWS credentials that can create VPC resources (for example `aws configure` or `aws sso login`)
- Optional: [TFLint](https://github.com/terraform-linters/tflint)

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  single_nat_gateway   = var.single_nat_gateway
  enable_ecr_endpoints = var.enable_ecr_endpoints
  tags                 = var.tags
}
```

### Try the example

```bash
cd examples/basic
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
terraform destroy -var-file=dev.tfvars     # clean up so you stop paying for the NAT
```

Sample inputs live in `examples/basic/`: `dev.tfvars`, `stage.tfvars`, `prod.tfvars`.

| | dev | stage | prod |
|---|---|---|---|
| Region | us-east-1 | us-west-2 | us-east-1 |
| AZs | 2 | 2 | 3 |
| NAT gateways | 1 shared | 1 shared | 1 per AZ |
| ECR endpoints | off | on | on |

> Tip: for real teams, keep one Terraform state per environment (separate workspaces or
> separate remote-state keys) so dev and prod never share a state file.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | string | (required) | `dev`, `stage` or `prod` |
| `vpc_cidr` | string | (required) | VPC range, e.g. `10.0.0.0/16` |
| `name_prefix` | string | `"yefter"` | Prefix for all names |
| `az_count` | number | `2` | AZs to use (2 to 6) |
| `subnet_newbits` | number | `4` | Extra mask bits per subnet (4 to 8) |
| `single_nat_gateway` | bool | `false` | One shared NAT instead of one per AZ |
| `enable_s3_endpoint` | bool | `true` | Create S3 gateway endpoint |
| `enable_ecr_endpoints` | bool | `true` | Create ECR interface endpoints |
| `tags` | map(string) | `{}` | Extra tags for every resource |

## Outputs

`vpc_id`, `vpc_cidr`, `availability_zones`, `public_subnet_ids`, `private_subnet_ids`,
`private_route_table_ids`, `nat_gateway_ids`, `nat_public_ips`, `s3_endpoint_id`,
`ecr_endpoint_ids`, `endpoint_security_group_id`.

## Testing and CI

```bash
terraform fmt -check -recursive
cd modules/vpc
terraform init -backend=false
terraform validate
terraform test          # mocked AWS provider: free, no credentials
tflint --init && tflint --recursive
```

GitHub Actions (`.github/workflows/ci.yml`) runs the same checks on every pull request:
format, validate (module and example), unit tests, TFLint.

## Security considerations

- **Default security group is locked** (no inbound or outbound rules), so nothing is open by accident.
- **Public subnets do not auto-assign public IPs.** Only resources you explicitly give an Elastic IP or place behind a load balancer are reachable.
- **Private subnets have no inbound path from the internet.** Outbound goes through NAT only.
- **Endpoint security group** allows only TCP 443 from the VPC CIDR.
- **S3 and ECR traffic stays on the AWS network** instead of crossing the NAT and the public internet.
- No secrets, account IDs or credentials are stored in the code. Do not commit state files (`.gitignore` already excludes them).
- Not included (good next steps): VPC Flow Logs, endpoint policies, Network ACLs, restricting the S3 endpoint to specific buckets.

## Idempotency notes

- Running `terraform apply` twice with the same inputs makes **no changes** the second time (`No changes. Your infrastructure matches the configuration.`).
- Changing `az_count` adds or removes subnets for the affected AZs only. Removing an AZ destroys the resources in that AZ.
- Switching `single_nat_gateway` replaces NAT gateways and rewrites private routes; expect a short egress interruption.
- Resource addresses use `count` / `for_each` keyed by position or service name, so plans stay stable.
- AZ names are looked up at plan time. If AWS adds a zone to a region later, your first N zones stay the same.

## Cost warning

NAT gateways cost money every hour (plus data). Each ECR interface endpoint also costs per AZ per hour.
For learning, use `dev.tfvars` and run `terraform destroy` when finished. The S3 gateway endpoint is free.

## Limitations

- IPv4 only.
- Endpoint service names use the standard `com.amazonaws.<region>.<service>` format (not the China partition).
- Interface endpoints for services other than ECR are not included; add them by extending `aws_vpc_endpoint.ecr`.
