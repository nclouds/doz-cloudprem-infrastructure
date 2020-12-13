data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_id
}

provider "aws" {
  alias  = "eks"
  region = var.region

  assume_role {
    role_arn = module.cluster_admin_role.this_iam_role_arn
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file       = false
  }
}

# Admin role to access the EKS cluster. By default only the user that creates the cluster has access to it
module "cluster_admin_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "3.6.0"

  create_role = true

  role_name              = "${local.identifier}-cluster-access"
  attach_readonly_policy = true
  role_requires_mfa      = false

  trusted_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
  ]

  tags = local.tags
}

data "aws_iam_policy_document" "eks_worker" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
      data.aws_kms_key.s3.arn,
    ]
  }

  statement {
    actions = [
      "rds:CreateDBSnapshot",
      "rds:DescribeDBSnapshots"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "logs:*",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_worker" {
  name   = "${local.identifier}-${data.aws_region.current.name}"
  policy = data.aws_iam_policy_document.eks_worker.json
}

module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "13.2.1"

  # EKS cofigurations
  cluster_name    = local.identifier
  cluster_version = "1.18"
  enable_irsa     = true

  vpc_id  = local.vpc_id
  subnets = local.private_subnet_ids

  workers_role_name = "${local.identifier}-worker"

  workers_additional_policies = [
    aws_iam_policy.eks_worker.arn,
  ]

  worker_groups = [
    {
      instance_type        = var.eks_instance_type
      root_volume_size     = var.eks_volume_size
      asg_min_size         = var.eks_min_size
      asg_max_size         = var.eks_max_size
      asg_desired_capacity = var.eks_desired_capacity
      subnets              = local.private_subnet_ids
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "propagate_at_launch" = "true"
          "value"               = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/${local.identifier}"
          "propagate_at_launch" = "true"
          "value"               = "owned"
        }
      ]
    }
  ]

  # Kubernetes configurations
  write_kubeconfig = false

  map_roles = [ # aws-auth configmap
    {
      rolearn  = module.cluster_admin_role.this_iam_role_arn
      username = "admin"
      groups   = ["system:masters"]
    },
  ]

  tags = local.tags
}