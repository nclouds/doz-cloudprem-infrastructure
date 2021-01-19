# This provider allows other users to apply the terraform even if they didn't 
# create the infrastructure initially. Otherwise Terraform would fail attempting to
# create the kubernetes resources
provider "aws" {
  alias  = "eks"
  region = var.region

  assume_role {
    role_arn     = data.aws_iam_role.create_eks_cluster.arn
    session_name = "terraform"
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  provider = aws.eks

  name = module.eks_cluster.cluster_id
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

# IAM role to access the EKS cluster. By default only the user that creates the cluster has access to it
module "cluster_access_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "3.6.0"

  create_role = true

  role_name              = "${local.identifier}-${data.aws_region.current.name}-cluster-access"
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

  providers = {
    aws = aws.eks
  }

  # EKS cofigurations
  cluster_name    = local.identifier
  cluster_version = "1.18"
  enable_irsa     = true

  vpc_id  = local.vpc_id
  subnets = local.private_subnet_ids

  workers_role_name = "${local.identifier}-${data.aws_region.current.name}-worker"

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
  internal           = !var.public_access

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

#  ############################# Create EKS Role #############################

# The aws_iam_role data and the time_sleep resource are required to wait until
# the role is completely created before initializing the aws.eks provider
data "aws_iam_role" "create_eks_cluster" {
  depends_on = [time_sleep.wait_create_eks_cluster_role]

  name = module.create_eks_cluster.this_iam_role_name
}

resource "time_sleep" "wait_create_eks_cluster_role" {
  depends_on = [module.create_eks_cluster]

  create_duration = "30s"
}

# Role for the provider to create the EKS cluster
# Don't change this role or it may cause issues with the EKS clusters
module "create_eks_cluster" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "3.6.0"

  create_role = true

  role_name         = "${local.identifier}-${data.aws_region.current.name}-create-eks-cluster"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
  ]

  custom_role_policy_arns = [aws_iam_policy.create_eks_cluster.arn]

  tags = local.tags
}

data "aws_iam_policy_document" "create_eks_cluster" {
  statement {
    actions = [
      "elasticloadbalancing:DescribeTargetHealth",
      "autoscaling:EnableMetricsCollection",
      "autoscaling:AttachInstances",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DeleteLaunchConfiguration",
      "autoscaling:DeleteTags",
      "autoscaling:Describe*",
      "autoscaling:DetachInstances",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SuspendProcesses",
      "ec2:AllocateAddress",
      "ec2:AssignPrivateIpAddresses",
      "ec2:Associate*",
      "ec2:AttachInternetGateway",
      "ec2:AttachNetworkInterface",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateDefaultSubnet",
      "ec2:CreateDhcpOptions",
      "ec2:CreateEgressOnlyInternetGateway",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateNetworkInterface",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:CreateVpc",
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteDhcpOptions",
      "ec2:DeleteEgressOnlyInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DeleteVpc",
      "ec2:DeleteVpnGateway",
      "ec2:Describe*",
      "ec2:DetachInternetGateway",
      "ec2:DetachNetworkInterface",
      "ec2:DetachVolume",
      "ec2:Disassociate*",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ModifyVpcEndpoint",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteLaunchTemplateVersions",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetLaunchTemplateData",
      "ec2:ModifyLaunchTemplate",
      "ec2:RunInstances",
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:DescribeUpdate",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:ListTagsForResource",
      "eks:CreateFargateProfile",
      "eks:DeleteFargateProfile",
      "eks:DescribeFargateProfile",
      "eks:ListFargateProfiles",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreateServiceLinkedRole",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeleteInstanceProfile",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DeleteServiceLinkedRole",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:List*",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      // Following permissions are needed if cluster_enabled_log_types is enabled
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:DeleteLogGroup",
      "logs:ListTagsLogGroup",
      "logs:PutRetentionPolicy",
      // Following permissions for working with secrets_encryption example
      "kms:CreateGrant",
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:ScheduleKeyDeletion"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "create_eks_cluster" {
  name   = "${local.identifier}-create-eks-cluster-${data.aws_region.current.name}"
  policy = data.aws_iam_policy_document.create_eks_cluster.json
}