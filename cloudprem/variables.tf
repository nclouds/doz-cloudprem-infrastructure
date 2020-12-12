variable "region" {
  description = "The region where the resources will be deployed"
  type        = string
}

#  ############## VPC ##############

# variable "azs" {
#   description = "A list of availability zones for the VPC"
#   type        = list(string)
#   default     = ["us-west-2a", "us-west-2b"]
# }

variable "vpc_id" {
  description = "The VPC ID where we'll be deploying our resources. (If creating a new VPC leave this field and subnets blank)."
  type        = string
  default     = ""
}

# variable "public_subnet_ids" {
#   description = "Existing VPC public subnet ids where internet load balancers can be created. You must enter subnets that span at least 2 different availability zones (i.e. us-east-1a, us-east-1b, etc) or leave this and the VPC fields blank and subnets will be created for you."
#   type        = list(string)
#   default     = []
# }

# variable "private_subnet_ids" {
#   description = "existing VPC private subnet ids where EKS worker nodes and other private resources can be created. You must enter subnets that span at least 2 different availability zones (i.e. us-east-1a, us-east-1b, etc) and these AZ's must match the public subnets or the load balancer will not work. Alternatively you can leave this and other VPC/Subnet fields blank and they will be created for you."
#   type        = list(string)
#   default     = []
# }

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = ""
}

# variable "public_subnet_cidrs" {
#   description = "A list of public subnets inside the VPC"
#   type        = list(string)

#   validation {
#     condition = length(var.public_subnet_cidrs) == 3
#     error_message = "The number of subnets must be three, one for each AZ."
#   }
# }

# variable "private_subnet_cidrs" {
#   description = "A list of private subnets inside the VPC"
#   type        = list(string)

#   validation {
#     condition = length(var.private_subnet_cidrs) == 3
#     error_message = "The number of subnets must be three, one for each AZ."
#   }
# }

variable "highly_available_nat_gateway" {
  description = "Should be true if you want to provision a highly available NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "s3_kms_key_id" {
  description = "AWS KMS key identifier for S3 encryption. The identifier can be one of the following format: Key id, key ARN, alias name or alias ARN"
  type        = string
  default     = "alias/aws/s3"
}

variable "rds_kms_key_id" {
  description = "AWS KMS key identifier for RDS encryption. The identifier can be one of the following format: Key id, key ARN, alias name or alias ARN"
  type        = string
  default     = "alias/aws/rds"
}

variable "rds_multi_az" {
  description = "If true we will tell RDS to automatically deploy and manage a highly available standby instance of your database. Enabling this doubles the cost of the RDS instance but without it you are susceptible to downtime if the AWS availability zone your RDS instance is in becomes unavailable."
  type        = bool
  default     = true
}

variable "rds_instance_type" {
  description = "The instance type to use for your database. See this page for a breakdown of the performance and cost differences between the different instance types: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html"
  type        = string
  default     = "db.t3.small"
}

variable "rds_allocated_storage" {
  description = "The initial size of the database (Gb)"
  type        = number
  default     = 100

  validation {
    condition     = var.rds_allocated_storage > 5 && var.rds_allocated_storage < 1000
    error_message = "The RDS allocated storage must be between 5 and 1000 Gb."
  }
}

variable "rds_max_allocated_storage" {
  description = "The maximum size to which AWS will scale the database (Gb)"
  type        = number
  default     = 500

  validation {
    condition     = var.rds_max_allocated_storage > 5 && var.rds_max_allocated_storage < 1000
    error_message = "The RDS max allocated storage must be between 5 and 1000 Gb."
  }
}

variable "rds_backup_retention_period" {
  description = "The number of days to keep automatic database backups. Setting this value to 0 disables automatic backups."
  type        = number
  default     = 30

  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "AWS limits backup retention to 35 days max."
  }
}

variable "rds_snapshot_identifier" {
  description = "We can seed the database from an existing RDS snapshot in this region. Type the snapshot identifier in this field or leave blank to start with a fresh database. Note: If you do use a snapshot it's critical that during stack updates you continue to include the snapshot identifier in this parameter. Clearing this parameter after using it will cause AWS to spin up a new fresh DB and delete your old one."
  type        = string
  default     = ""
}

variable "enable_bi" {
  description = "This option will spin up a BI slave of your master database and enable conditional replication (everything but the mysql table will be replicated so you can have custom users)."
  type        = bool
  default     = true
}

variable "cache_instance_type" {
  description = "The compute and memory capacity of the nodes in the Cache Cluster"
  type        = string
  default     = "cache.t2.small"
}

variable "environment" {
  description = "Environment of the application"
  type        = string
}