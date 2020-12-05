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

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) == 2
    error_message = "The number of subnets must be two, one for each AZ."
  }
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) == 2
    error_message = "The number of subnets must be two, one for each AZ."
  }
}

variable "highly_available_nat_gateway" {
  description = "Should be true if you want to provision a highly available NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment of the application"
  type        = string
}