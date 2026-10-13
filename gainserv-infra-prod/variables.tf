variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster recovery region for the app data bucket replica"
  type        = string

  validation {
    condition     = var.dr_region != var.aws_region
    error_message = "dr_region must be different from aws_region - a replica in the same region does not survive a regional outage."
  }
}

variable "ProjectName" {
  description = "Project name"
  type        = string
  default     = "gainserv"
}

variable "Environment" {
  description = "Environment name"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.Environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR block - pods get real VPC IPs (AWS VPC CNI), so it must be large"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 18
    error_message = "vpc_cidr must be a valid CIDR between /16 and /18 - smaller VPCs run out of pod IPs."
  }
}

# EKS
variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API (office / VPN IPs)"
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.cluster_endpoint_public_access_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Use valid CIDRs and never 0.0.0.0/0 - the Kubernetes API must not be open to the whole internet."
  }
}

variable "node_groups" {
  description = "EKS managed node groups, keyed by pool name"
  type = map(object({
    capacity_type  = string
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
  }))
}

variable "addon_chart_versions" {
  description = "Pinned Helm chart versions for the cluster add-ons"
  type = object({
    metrics_server               = string
    aws_load_balancer_controller = string
    external_secrets             = string
    cluster_autoscaler           = string
  })
}

# App
variable "app_secret_names" {
  description = "Secret env var names for the app - one SSM parameter each"
  type        = set(string)
}
