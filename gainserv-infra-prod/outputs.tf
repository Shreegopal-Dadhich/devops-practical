# EKS Outputs
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.EKS.cluster_name
}

output "configure_kubectl" {
  description = "Command to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.EKS.cluster_name}"
}

# VPC Outputs
output "vpc_cidr" {
  description = "VPC CIDR block - the app NetworkPolicy blocks egress to it"
  value       = module.VPC.vpc_cidr
}

output "alb_source_cidr" {
  description = "CIDR holding all public subnets - the only ingress source the app NetworkPolicy allows"
  value       = module.VPC.public_supernet_cidr
}

# App Outputs
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ECR.repository_url
}

output "app_data_bucket" {
  description = "App data bucket name"
  value       = module.S3.bucket_name
}

output "ssm_prefix" {
  description = "SSM Parameter Store path for the app secrets"
  value       = module.SSM.path_prefix
}

# IAM Outputs
output "irsa_role_arns" {
  description = "IRSA role ARN per ServiceAccount"
  value       = { for k, m in module.IAM : k => m.role_arn }
}
