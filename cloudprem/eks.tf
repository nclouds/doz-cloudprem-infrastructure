data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  provider = aws.eks

  name = module.eks_cluster.cluster_id
}

# This provider allows other users to apply the terraform even if they didn't 
# create the infrastructure initially. Otherwise Terraform would fail attempting to
# create the kubernetes resources
provider "aws" {
  alias  = "eks"
  region = var.region

  assume_role {
    role_arn = module.cluster_access_role.this_iam_role_arn
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
  }
}

# Admin role to access the EKS cluster. By default only the user that creates the cluster has access to it
module "cluster_access_role" {
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

module "eks_worker_node_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.17.0"

  name            = "${local.identifier}-worker-node"
  use_name_prefix = false
  description     = "Allows access to the worker nodes to expose the Cloudprem application"
  vpc_id          = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 32001
      to_port     = 32001
      protocol    = 6
      description = "Allow internet access to the replicated-ui"
      cidr_blocks = var.replicated_ui_access_cidr
    },
    {
      from_port   = 32005
      to_port     = 32005
      protocol    = 6
      description = " Allow internet access to the app via https"
      cidr_blocks = var.app_access_cidr
    },
    {
      from_port   = 32010
      to_port     = 32010
      protocol    = 6
      description = "Allow internet access to the app via http"
      cidr_blocks = var.app_access_cidr
    },
  ]

  egress_rules = ["all-tcp"]
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

  worker_additional_security_group_ids = [
    module.eks_worker_node_sg.this_security_group_id
  ]

  worker_groups = [
    {
      name                 = "workers"
      instance_type        = var.eks_instance_type
      root_volume_size     = var.eks_volume_size
      asg_min_size         = var.eks_min_size
      asg_max_size         = var.eks_max_size
      asg_desired_capacity = var.eks_desired_capacity
      subnets              = local.private_subnet_ids
      enabled_metrics      = ["GroupInServiceInstances"]
      target_group_arns    = module.nlb.target_group_arns
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
      rolearn  = module.cluster_access_role.this_iam_role_arn
      username = "admin"
      groups   = ["system:masters"]
    },
  ]

  tags = local.tags
}

module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "5.10.0"

  name = local.identifier

  load_balancer_type = "network"
  internal           = ! var.public_access

  vpc_id  = local.vpc_id
  subnets = local.public_subnet_ids

  target_groups = [
    {
      name             = "${local.identifier}-replicated"
      backend_protocol = "TCP"
      backend_port     = 32001
      target_type      = "instance"
    },
    {
      name             = "${local.identifier}-app"
      backend_protocol = "TCP"
      backend_port     = 32005
      target_type      = "instance"
    },
    {
      name             = "${local.identifier}-http-redirect"
      backend_protocol = "TCP"
      backend_port     = 32010
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 8800
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 443
      protocol           = "TCP"
      target_group_index = 1
    },
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 2
    }
  ]

  tags = local.tags
}

module "cpu_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "1.3.0"

  alarm_name        = "${local.identifier}-cpu-high"
  alarm_description = "CPU utilization high for ${local.identifier} worker nodes"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 90
  period              = 60

  dimensions = {
    AutoScalingGroupName = module.eks_cluster.workers_asg_names[0]
  }

  alarm_actions = [
    module.sns.this_sns_topic_arn
  ]

  ok_actions = [
    module.sns.this_sns_topic_arn
  ]
}

module "memory_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "1.3.0"

  alarm_name        = "${local.identifier}-memory-high"
  alarm_description = "Memory utilization high for ${local.identifier} cluster"

  namespace   = "ContainerInsights"
  metric_name = "node_memory_utilization"
  statistic   = "Average"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 75
  period              = 120

  dimensions = {
    ClusterName = module.eks_cluster.cluster_id
  }

  alarm_actions = [
    module.sns.this_sns_topic_arn
  ]

  ok_actions = [
    module.sns.this_sns_topic_arn
  ]
}

module "status_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "1.3.0"

  alarm_name        = "${local.identifier}-status"
  alarm_description = "Status check for ${local.identifier} cluster"

  namespace   = "AWS/EC2"
  metric_name = "StatusCheckFailed"
  statistic   = "Average"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 1
  period              = 60

  dimensions = {
    AutoScalingGroupName = module.eks_cluster.workers_asg_names[0]
  }

  alarm_actions = [
    module.sns.this_sns_topic_arn
  ]

  ok_actions = [
    module.sns.this_sns_topic_arn
  ]
}

module "nodes_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "1.3.0"

  alarm_name        = "${local.identifier}-nodes-in-service"
  alarm_description = "Nodes in service under desired capacity for ${local.identifier} cluster"

  namespace   = "AWS/AutoScaling"
  metric_name = "GroupInServiceInstances"
  statistic   = "Sum"

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = var.eks_desired_capacity
  period              = 60

  dimensions = {
    AutoScalingGroupName = module.eks_cluster.workers_asg_names[0]
  }

  alarm_actions = [
    module.sns.this_sns_topic_arn
  ]

  ok_actions = [
    module.sns.this_sns_topic_arn
  ]
}