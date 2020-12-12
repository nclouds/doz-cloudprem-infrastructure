# EFS terraform module

A terraform module to create an Elasticache Memached cluster

## Module usage:

```hcl
module "memcached" {
  source = "./modules/elasticache-memcached"

  name = local.identifier

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  allowed_cidr_blocks = [local.vpc_cidr]

  cluster_size  = 1
  instance_type = var.cache_instance_type
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 0.13.0 |
| aws | ~> 3.2.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 3.2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed\_cidr\_blocks | List of CIDR blocks to allow in the security group | `list(string)` | `[]` | no |
| dns\_name | DNS name for a record on Route53 | `string` | `""` | no |
| encrypted | If true, the file system will be encrypted | `bool` | `true` | no |
| kms\_key\_id | If set, use a specific KMS key | `string` | `null` | no |
| name | Name to be used on all the resources as identifier | `string` | `null` | no |
| performance\_mode | The file system performance mode. Can be either `generalPurpose` or `maxIO` | `string` | `"generalPurpose"` | no |
| provisioned\_throughput\_in\_mibps | The throughput, measured in MiB/s, that you want to provision for the file system. Only applicable with `throughput_mode` set to provisioned | `number` | `0` | no |
| subnet\_ids | List of subnets to deploy EFS mount targets | `list(string)` | `[]` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |
| throughput\_mode | Throughput mode for the file system. Defaults to bursting. Valid values: `bursting`, `provisioned`. When using `provisioned`, also set `provisioned_throughput_in_mibps` | `string` | `"bursting"` | no |
| transition\_to\_ia | Indicates how long it takes to transition files to the IA storage class. Valid values: AFTER\_7\_DAYS, AFTER\_14\_DAYS, AFTER\_30\_DAYS, AFTER\_60\_DAYS and AFTER\_90\_DAYS | `string` | `""` | no |
| vpc\_id | VPC id to deploy the EFS resources | `string` | n/a | yes |
| zone\_id | The ID of the hosted zone to contain the EFS record | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| arn | EFS ARN |
| dns\_name | EFS DNS name |
| id | EFS id |
| mount\_target\_dns\_names | List of EFS mount target DNS names |
| mount\_target\_ids | List of EFS mount target IDs (one per Availability Zone) |
| mount\_target\_ips | List of EFS mount target IPs (one per Availability Zone) |
| mount\_target\_subnet\_ids | List of EFS mount target subnet ids (one per Availability Zone) |
| network\_interface\_ids | List of mount target network interface IDs |
| route53\_dns | custom Route53 DNS name |
| security\_group\_arn | EFS Security Group ARN |
| security\_group\_id | EFS Security Group ID |
| security\_group\_name | EFS Security Group name |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
