terraform {
  backend "s3" {}

  required_version = ">= 0.13.5"

  required_providers {
    aws    = ">= 3.5"
    random = "~> 3.0.0"
  }
}

#  ########### Providers ###########

provider "aws" {
  region = var.region
}

#  ############# Locals ############

locals {
  identifier = "cloudprem-${var.environment}"

  tags = {
    Terraform = "true"
    Project   = "cloudprem"
  }

  protect_resources = false #var.stack_type == "prod" ? true : false

  # Networking
  azs_count          = 3
  create_vpc         = var.vpc_id == "" ? true : false
  vpc_id             = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  vpc_cidr           = local.create_vpc ? module.vpc[0].vpc_cidr_block : module.vpc[0].vpc_cidr_block
  public_subnet_ids  = local.create_vpc ? module.vpc[0].public_subnets : data.aws_subnet_ids.public[0]
  private_subnet_ids = local.create_vpc ? module.vpc[0].private_subnets : data.aws_subnet_ids.private[0]

}

#  ########### Resources ###########

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_subnet_ids" "public" {
  count = local.create_vpc ? 0 : 1

  vpc_id = var.vpc_id

  tags = {
    type = "public"
  }
}

data "aws_subnet_ids" "private" {
  count = local.create_vpc ? 0 : 1

  vpc_id = var.vpc_id

  tags = {
    type = "private"
  }
}

data "aws_kms_key" "rds" {
  key_id = var.rds_kms_key_id
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"

  count = local.create_vpc ? 1 : 0

  name = local.identifier
  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  enable_nat_gateway     = true
  single_nat_gateway     = ! var.highly_available_nat_gateway # TODO review HA nat gateway
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true

  public_subnets = [for i in range(local.azs_count) : cidrsubnet(var.vpc_cidr, 4, i)]

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.identifier}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    "type"                                      = "public"
  }

  private_subnets = [for i in range(local.azs_count, local.azs_count * 2) : cidrsubnet(var.vpc_cidr, 4, i)]

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.identifier}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "type"                                      = "private"
  }

  tags = local.tags
}

module "guide_images_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "1.16.0"

  bucket        = "dozuki-guide-images-${local.identifier}-${data.aws_caller_identity.current.account_id}" # TODO Review bucket names
  acl           = "private"
  force_destroy = true # TODO parameterize this

  # S3 bucket-level Public Access Block configuration
  block_public_acls   = true
  block_public_policy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = var.s3_kms_key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = local.tags
}

module "guide_pdfs_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "1.16.0"

  bucket        = "dozuki-guide-pdfs-${local.identifier}-${data.aws_caller_identity.current.account_id}" # TODO Review bucket names
  acl           = "private"
  force_destroy = true # TODO parameterize this

  # S3 bucket-level Public Access Block configuration
  block_public_acls   = true
  block_public_policy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = var.s3_kms_key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = local.tags
}

module "guide_objects_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "1.16.0"

  bucket        = "dozuki-guide-objects-${local.identifier}-${data.aws_caller_identity.current.account_id}" # TODO Review bucket names
  acl           = "private"
  force_destroy = true # TODO parameterize this

  # S3 bucket-level Public Access Block configuration
  block_public_acls   = true
  block_public_policy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = var.s3_kms_key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = local.tags
}

module "documents_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "1.16.0"

  bucket        = "dozuki-documents-${local.identifier}-${data.aws_caller_identity.current.account_id}" # TODO Review bucket names
  acl           = "private"
  force_destroy = true # TODO parameterize this

  # S3 bucket-level Public Access Block configuration
  block_public_acls   = true
  block_public_policy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = var.s3_kms_key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  cors_rule = [
    {
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      allowed_headers = ["Authorization", "Range"]
      expose_headers  = ["Accept-Ranges", "Content-Encoding", "Content-Length", "Content-Range"]
      max_age_seconds = 3000
    }
  ]

  tags = local.tags
}

#  ############## RDS ##############

module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.17.0"

  name            = "${local.identifier}-rds" # TODO Update name
  use_name_prefix = false
  description     = "Security group for ${local.identifier}. Allows access from within the VPC on port 3306"
  vpc_id          = local.vpc_id

  ingress_cidr_blocks = [local.vpc_cidr]
  ingress_rules       = ["mysql-tcp"]

  egress_rules = ["all-tcp"]
}

resource "random_password" "rds_password" {
  length  = 40
  special = false
}

module "rds" { # TODO Change name to "master"
  source  = "terraform-aws-modules/rds/aws"
  version = "2.20.0"

  identifier = local.identifier

  engine                = "mysql"
  engine_version        = "5.7"
  port                  = 3306
  instance_class        = var.rds_instance_type
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = data.aws_kms_key.rds.arn

  username = "dozuki"
  password = random_password.rds_password.result

  multi_az = var.rds_multi_az

  maintenance_window      = "Sun:19:00-Sun:23:00"
  backup_window           = "17:00-19:00"
  backup_retention_period = var.rds_backup_retention_period

  vpc_security_group_ids = [module.rds_sg.this_security_group_id]

  # Snapshot configuration
  deletion_protection       = true
  snapshot_identifier       = var.rds_snapshot_identifier # Restore from snapshot
  skip_final_snapshot       = ! local.protect_resources
  final_snapshot_identifier = local.identifier # Snapshot name upon DB deletion
  copy_tags_to_snapshot     = true

  # DB subnet group
  # db_subnet_group_name = local.identifier # https://github.com/terraform-aws-modules/terraform-aws-rds/issues/42
  subnet_ids = local.private_subnet_ids

  # DB parameter group
  family                          = "mysql5.7"
  parameter_group_name            = local.identifier
  use_parameter_group_name_prefix = false

  parameters = [
    {
      name  = "binlog_format"
      value = "ROW"
    }
  ]

  # DB option group
  major_engine_version = "5.7"
  # create_db_option_group = false # https://github.com/terraform-aws-modules/terraform-aws-rds/issues/188

  tags = local.tags
}

resource "aws_secretsmanager_secret" "rds" {
  name = "${local.identifier}-master-rds"
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    dbInstanceIdentifier = module.rds.this_db_instance_id
    resourceId           = module.rds.this_db_instance_resource_id
    host                 = module.rds.this_db_instance_endpoint
    port                 = module.rds.this_db_instance_port
    engine               = "mysql"
    username             = module.rds.this_db_instance_username
    password             = random_password.rds_password.result
  })
}

module "replica" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.20.0"

  count = var.enable_bi ? 1 : 0

  identifier = "${local.identifier}-replica"

  # Source database. For cross-region use this_db_instance_arn
  replicate_source_db = module.rds.this_db_instance_id

  engine                = "mysql"
  engine_version        = "5.7"
  port                  = 3306
  instance_class        = var.rds_instance_type
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = data.aws_kms_key.rds.arn

  # Username and password should not be set for replicas
  username = ""
  password = ""

  multi_az = var.rds_multi_az

  maintenance_window      = "Sun:19:00-Sun:23:00"
  backup_retention_period = 0
  backup_window           = "17:00-19:00"

  vpc_security_group_ids = [module.rds_sg.this_security_group_id]

  # Not allowed to specify a subnet group for replicas in the same region
  create_db_subnet_group    = false
  create_db_option_group    = false
  create_db_parameter_group = false
  # DB option group
  major_engine_version = "5.7"
}

module "memcached" {
  source = "./modules/elasticache-memcached"

  name = local.identifier

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  allowed_cidr_blocks = [local.vpc_cidr]

  cluster_size  = 1
  instance_type = var.cache_instance_type
}