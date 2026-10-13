terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Created by ./bootstrap (S3 bucket + DynamoDB lock table)
  backend "s3" {
    bucket         = "gainserv-prod-terraform-state"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "gainserv-prod-terraform-locks"
    encrypt        = true
  }

}

# Primary region - EKS cluster and app
provider "aws" {
  alias  = "primary"
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

# DR region - replica of the app data bucket
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  default_tags {
    tags = local.common_tags
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.EKS.cluster_endpoint
    cluster_ca_certificate = base64decode(module.EKS.cluster_certificate_authority)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.EKS.cluster_name, "--region", var.aws_region]
    }
  }
}

data "aws_availability_zones" "available" {
  provider = aws.primary
  state    = "available"
}

data "aws_caller_identity" "current" {
  provider = aws.primary
}

# Module: VPC
# 3 public + 3 private subnets, NAT gateway per AZ, S3 gateway endpoint
module "VPC" {
  source = "./modules/VPC"
  providers = {
    aws = aws.primary
  }

  name_prefix = local.name_prefix
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr
  azs         = local.azs
}

# Module: EKS
# Control plane, OIDC provider for IRSA, node IAM role, VPC CNI with network policy
module "EKS" {
  source = "./modules/eks"
  providers = {
    aws = aws.primary
  }

  name_prefix                  = local.name_prefix
  cluster_name                 = local.cluster_name
  kubernetes_version           = var.kubernetes_version
  private_subnet_ids           = module.VPC.private_subnet_ids
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  depends_on = [module.VPC]
}

# Module: NodeGroup
# One managed node group per entry in var.node_groups (system on-demand, apps spot)
module "NodeGroup" {
  source   = "./modules/nodegroup"
  for_each = var.node_groups
  providers = {
    aws = aws.primary
  }

  name           = each.key
  name_prefix    = local.name_prefix
  cluster_name   = module.EKS.cluster_name
  node_role_arn  = module.EKS.node_role_arn
  subnet_ids     = module.VPC.private_subnet_ids
  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  min_size       = each.value.min_size
  max_size       = each.value.max_size
  desired_size   = each.value.desired_size
  tags           = local.common_tags

  depends_on = [module.EKS]
}

# Module: IAM
# One IRSA role per Kubernetes ServiceAccount, for_each over local.irsa_roles
module "IAM" {
  source   = "./modules/iam"
  for_each = local.irsa_roles
  providers = {
    aws = aws.primary
  }

  name              = each.key
  name_prefix       = local.name_prefix
  oidc_provider_arn = module.EKS.oidc_provider_arn
  oidc_issuer       = module.EKS.oidc_issuer
  namespace         = each.value.namespace
  service_account   = each.value.service_account
  policy_json       = each.value.policy_json
}

# Module: S3
# App data bucket (read by the app via IRSA) + replica in the DR region
module "S3" {
  source = "./modules/s3"
  providers = {
    aws    = aws.primary
    aws.dr = aws.dr
  }

  bucket_name = "${local.name_prefix}-app-data-${data.aws_caller_identity.current.account_id}"
}

# Module: ECR
# Image registry - immutable tags, scan on push
module "ECR" {
  source = "./modules/ecr"
  providers = {
    aws = aws.primary
  }

  repository_name = "${local.name_prefix}-app-server"
  force_delete    = true
}

# Module: SSM
# App secrets in Parameter Store (values set outside Terraform)
module "SSM" {
  source = "./modules/ssm"
  providers = {
    aws = aws.primary
  }

  name_prefix  = local.name_prefix
  path_prefix  = local.ssm_prefix
  secret_names = var.app_secret_names
}

# Module: EKSAddons
# metrics-server, AWS Load Balancer Controller, External Secrets, Cluster Autoscaler
module "EKSAddons" {
  source = "./modules/eks-addons"
  providers = {
    aws  = aws.primary
    helm = helm
  }

  cluster_name     = module.EKS.cluster_name
  aws_region       = var.aws_region
  vpc_id           = module.VPC.vpc_id
  system_node_pool = "system"
  spot_node_pool   = "apps-spot"
  chart_versions   = var.addon_chart_versions

  aws_load_balancer_controller_role_arn = module.IAM["aws-load-balancer-controller"].role_arn
  cluster_autoscaler_role_arn           = module.IAM["cluster-autoscaler"].role_arn

  depends_on = [module.NodeGroup, module.IAM]
}
