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

variable "kms_key_id" {
  description = "AWS KMS key identifier which can be one of the following format: Key id, key ARN, alias name or alias ARN"
  type        = string
  default     = "alias/aws/s3"
}

variable "environment" {
  description = "Environment of the application"
  type        = string
}