data "aws_kms_key" "rds" {
  key_id = var.rds_kms_key_id
}

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

module "rds" { # TODO Change name to "primary"
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