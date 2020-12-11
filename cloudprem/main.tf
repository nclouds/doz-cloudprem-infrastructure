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

  # Networking
  azs_count          = 3
  create_vpc         = var.vpc_id == "" ? true : false
  vpc_id             = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
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

# data "aws_kms_key" "this" {
#   key_id = var.s3_kms_key_id
# }


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
        kms_master_key_id = var.s3_kms_key_id # TODO review parameter name
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
        kms_master_key_id = var.s3_kms_key_id # TODO review parameter name
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
        kms_master_key_id = var.s3_kms_key_id # TODO review parameter name
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
        kms_master_key_id = var.s3_kms_key_id # TODO review parameter name
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