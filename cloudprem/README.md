# CloudPrem Infrastructure

This Terraform project contains the CloudPrem infrastructure

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.14 |
| aws | >= 3.5 |
| helm | ~> 1.3.2 |
| kubernetes | 1.13.3 |
| random | ~> 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 3.5 |
| kubernetes | 1.13.3 |
| random | ~> 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bastion\_instance\_type | The instance type to use for the bastion host | `string` | `"t3.micro"` | no |
| cache\_instance\_type | The compute and memory capacity of the nodes in the Cache Cluster | `string` | `"cache.t2.small"` | no |
| dozuki\_license\_parameter\_name | The SSM parameter name that stores the Dozuki license file provided to you. | `string` | n/a | yes |
| eks\_desired\_capacity | This is what the node count will start out as. | `number` | `"4"` | no |
| eks\_instance\_type | The instance type of each node in the application's EKS worker node group. | `string` | `"t3.medium"` | no |
| eks\_max\_size | The maximum amount of nodes we will autoscale to. | `number` | `"4"` | no |
| eks\_min\_size | The minimum amount of nodes we will autoscale to. | `number` | `"4"` | no |
| eks\_volume\_size | The amount of local storage (in gigabytes) to allocate to each kubernetes node. Keep in mind you will be billed for this amount of storage multiplied by how many nodes you spin up (i.e. 50GB \* 4 nodes = 200GB on your bill). For production installations 50GB should be the minimum. This local storage is used as a temporary holding area for uploaded and in-process assets like videos and images. | `number` | `50` | no |
| enable\_bi | This option will spin up a BI slave of your master database and enable conditional replication (everything but the mysql table will be replicated so you can have custom users). | `bool` | `true` | no |
| environment | Environment of the application | `string` | n/a | yes |
| highly\_available\_nat\_gateway | Should be true if you want to provision a highly available NAT Gateway across all of your private networks | `bool` | `false` | no |
| rds\_allocated\_storage | The initial size of the database (Gb) | `number` | `100` | no |
| rds\_backup\_retention\_period | The number of days to keep automatic database backups. Setting this value to 0 disables automatic backups. | `number` | `30` | no |
| rds\_instance\_type | The instance type to use for your database. See this page for a breakdown of the performance and cost differences between the different instance types: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html | `string` | `"db.t3.small"` | no |
| rds\_kms\_key\_id | AWS KMS key identifier for RDS encryption. The identifier can be one of the following format: Key id, key ARN, alias name or alias ARN | `string` | `"alias/aws/rds"` | no |
| rds\_max\_allocated\_storage | The maximum size to which AWS will scale the database (Gb) | `number` | `500` | no |
| rds\_multi\_az | If true we will tell RDS to automatically deploy and manage a highly available standby instance of your database. Enabling this doubles the cost of the RDS instance but without it you are susceptible to downtime if the AWS availability zone your RDS instance is in becomes unavailable. | `bool` | `true` | no |
| rds\_snapshot\_identifier | We can seed the database from an existing RDS snapshot in this region. Type the snapshot identifier in this field or leave blank to start with a fresh database. Note: If you do use a snapshot it's critical that during stack updates you continue to include the snapshot identifier in this parameter. Clearing this parameter after using it will cause AWS to spin up a new fresh DB and delete your old one. | `string` | `""` | no |
| region | The region where the resources will be deployed | `string` | `"us-west-2"` | no |
| s3\_kms\_key\_id | AWS KMS key identifier for S3 encryption. The identifier can be one of the following format: Key id, key ARN, alias name or alias ARN | `string` | `"alias/aws/s3"` | no |
| vpc\_cidr | The CIDR block for the VPC | `string` | `""` | no |
| vpc\_id | The VPC ID where we'll be deploying our resources. (If creating a new VPC leave this field and subnets blank). | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| eks\_cluster\_admin\_role | AWS IAM role with full access to the Kubernetes cluster. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->