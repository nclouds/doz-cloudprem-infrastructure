variable "region" {
  description = "The region where the resources will be deployed"
  type        = string
}

#  ############## VPC ##############

variable "azs" {
  description = "A list of availability zones for the VPC"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
}