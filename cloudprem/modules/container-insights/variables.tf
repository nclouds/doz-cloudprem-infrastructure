variable "cluster_name" {
  description = "The EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed."
  type        = string
}