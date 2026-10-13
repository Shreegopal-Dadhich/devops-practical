locals {
  name_prefix  = "${var.ProjectName}-${var.Environment}"
  cluster_name = "${local.name_prefix}-eks"

  common_tags = {
    "project"     = var.ProjectName
    "Environment" = var.Environment
    "ManagedBy"   = "Terraform"
  }

  azs        = slice(data.aws_availability_zones.available.names, 0, 3)
  ssm_prefix = "/${var.ProjectName}/${var.Environment}/app-server"

  # Kubernetes side - must match gainserv-manifests/
  k8s_namespace = "gainserv"

  # IRSA roles - one IAM role per ServiceAccount, least privilege
  irsa_roles = {
    # App pods - read only on the app data bucket
    "app-server" = {
      namespace       = local.k8s_namespace
      service_account = "gainserv-app-server-prod-sa"
      policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["s3:ListBucket"]
            Resource = module.S3.bucket_arn
          },
          {
            Effect   = "Allow"
            Action   = ["s3:GetObject"]
            Resource = "${module.S3.bucket_arn}/*"
          }
        ]
      })
    }

    # External Secrets - read only the app's SSM parameters
    "app-server-secrets-reader" = {
      namespace       = local.k8s_namespace
      service_account = "gainserv-app-server-prod-secrets-reader-sa"
      policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ssm:GetParameter",
              "ssm:GetParameters",
              "ssm:GetParametersByPath"
            ]
            Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"
          }
        ]
      })
    }

    # AWS Load Balancer Controller - official policy (v3.5.0)
    "aws-load-balancer-controller" = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy_json     = file("${path.module}/policies/aws-load-balancer-controller.json")
    }

    # Cluster Autoscaler - can resize only this cluster's node groups
    "cluster-autoscaler" = {
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
      policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "autoscaling:DescribeAutoScalingGroups",
              "autoscaling:DescribeAutoScalingInstances",
              "autoscaling:DescribeLaunchConfigurations",
              "autoscaling:DescribeScalingActivities",
              "autoscaling:DescribeTags",
              "ec2:DescribeImages",
              "ec2:DescribeInstanceTypes",
              "ec2:DescribeLaunchTemplateVersions",
              "ec2:GetInstanceTypesFromInstanceRequirements",
              "eks:DescribeNodegroup"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "autoscaling:SetDesiredCapacity",
              "autoscaling:TerminateInstanceInAutoScalingGroup"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                "aws:ResourceTag/k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
              }
            }
          }
        ]
      })
    }
  }
}
