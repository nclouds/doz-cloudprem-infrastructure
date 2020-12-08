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
| kms\_key\_id | AWS KMS key identifier which can be one of the following format: Key id, key ARN, alias name or alias ARN | `string` | `"alias/aws/s3"` | no |
| region | The region where the resources will be deployed | `string` | n/a | yes |
| vpc\_cidr | The CIDR block for the VPC | `string` | `""` | no |
| vpc\_id | The VPC ID where we'll be deploying our resources. (If creating a new VPC leave this field and subnets blank). | `string` | `""` | no |

## Outputs

No output.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->