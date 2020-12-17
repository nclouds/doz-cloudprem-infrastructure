terraform {
  required_version = ">= 0.13.0"

  required_providers {
    aws        = ">= 3.2.0"
    kubernetes = "~> 1.13.3"
  }
}