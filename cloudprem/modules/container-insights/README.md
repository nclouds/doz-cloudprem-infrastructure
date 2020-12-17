# AWS Container Insights terraform module

A terraform module to install AWS container insights in an EKS cluster

## Module usage:

```hcl
module "container_insights" {
  source = "./modules/container-insights"

  cluster_name = "cloudprem-dev"

  aws_region = "us-west-2"
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13.0 |
| kubernetes | ~> 1.13.3 |

## Providers

| Name | Version |
|------|---------|
| kubernetes | ~> 1.13.3 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws\_region | AWS region where the EKS cluster is deployed. | `string` | n/a | yes |
| cluster\_name | The EKS cluster name. | `string` | n/a | yes |

## Outputs

No output.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
