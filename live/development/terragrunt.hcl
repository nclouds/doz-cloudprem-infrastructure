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

  vpc_cidr = "10.0.0.0/16"

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  environment = "dev"
}