terraform {
  backend "s3" {}

  required_version = ">= 0.13.5"

  required_providers {
    aws = ">= 3.5"
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
}

#  ########### Resources ###########

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"

  name = local.identifier
  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  enable_nat_gateway     = true
  single_nat_gateway     = ! var.highly_available_nat_gateway
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true

  public_subnets = var.public_subnets

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.identifier}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    "type"                                      = "public"
  }

  private_subnets = var.private_subnets

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.identifier}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "type"                                      = "private"
  }

  tags = local.tags
}