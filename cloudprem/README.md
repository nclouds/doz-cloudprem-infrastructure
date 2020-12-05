# CloudPrem Infrastructure

This Terraform project contains the CloudPrem infrastructure

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13.5 |
| aws | >= 3.5 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 3.5 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment of the application | `string` | n/a | yes |
| highly\_available\_nat\_gateway | Should be true if you want to provision a highly available NAT Gateway across all of your private networks | `bool` | `false` | no |
| private\_subnets | A list of private subnets inside the VPC | `list(string)` | n/a | yes |
| public\_subnets | A list of public subnets inside the VPC | `list(string)` | n/a | yes |
| region | The region where the resources will be deployed | `string` | n/a | yes |
| vpc\_cidr | The CIDR block for the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| azs | A list of availability zones spefified as argument to this module |
| private\_subnets | List of IDs of private subnets |
| public\_subnets | List of IDs of public subnets |
| vpc\_cidr\_block | The CIDR block of the VPC |
| vpc\_id | The ID of the VPC |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->