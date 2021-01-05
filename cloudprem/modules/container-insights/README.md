# AWS Container Insights terraform module

A terraform module to install AWS container insights with fluentd in an EKS cluster

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

## Development

The module is based on the container insights kubernetes manifest kubernetes manifest from the [AWS documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html). A simple Helm chart was created to be deployed within Terraform with the Helm provider. To update container insights to a newer version replace the templates in the Helm chart with the updated kubernetes manifests. We created a simple bash script that can be used as guidance, however we recommend to review the documentation and the script before upgrading.