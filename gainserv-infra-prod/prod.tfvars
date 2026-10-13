
aws_region  = "ap-south-1" # Mumbai
dr_region   = "ap-southeast-1"
ProjectName = "gainserv"
Environment = "prod"

# VPC
vpc_cidr = "10.20.0.0/16"

# EKS
kubernetes_version = "1.35"

cluster_endpoint_public_access_cidrs = ["171.61.167.8/32"]

# EKS - node groups
node_groups = {
  system = {
    capacity_type  = "ON_DEMAND"
    instance_types = ["c7i-flex.large"]
    min_size       = 2
    max_size       = 3
    desired_size   = 2
  }

  apps-spot = {
    capacity_type  = "SPOT"
    instance_types = ["c7i-flex.large", "m7i-flex.large"]
    min_size       = 0
    max_size       = 6
    desired_size   = 0
  }
}

addon_chart_versions = {
  metrics_server               = "3.13.0"
  aws_load_balancer_controller = "3.5.0"
  external_secrets             = "2.11.0"
  cluster_autoscaler           = "9.58.0"
}

# App
app_secret_names = ["APP_API_KEY"]
