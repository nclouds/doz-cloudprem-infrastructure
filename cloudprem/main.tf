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
}

#  ########### Resources ###########

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"

  name = local.identifier
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = var.environment
  }
}