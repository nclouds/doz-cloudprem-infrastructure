# Pull in the backend and provider configurations from a root terragrunt.hcl file that you include in each child terragrunt.hcl:
include {
  path = find_in_parent_folders()
}

# Set the source to an immutable released version of the infrastructure module being deployed:
terraform {
  source = "../..//cloudprem"
}

# Configure input values for the specific environment being deployed:
inputs = {
  region = "us-west-2"

  vpc_cidr = "172.16.0.0/16"

  # public_subnet_cidrs = ["172.16.0.0/20", "172.16.16.0/20", "172.16.32.0/20"]

  # private_subnet_cidrs  = ["172.16.48.0/20", "172.16.64.0/20", "172.16.80.0/20"]

  environment = "dev"
}