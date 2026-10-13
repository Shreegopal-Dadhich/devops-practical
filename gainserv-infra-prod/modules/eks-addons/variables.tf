variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}
variable "aws_region" {
  description = "AWS region"
  type        = string
}
variable "vpc_id" {
  description = "VPC ID for the ALB controller"
  type        = string
}
variable "system_node_pool" {
  description = "node-pool label of the On-Demand pool that runs the controllers"
  type        = string
}
variable "spot_node_pool" {
  description = "node-pool name of the Spot pool Cluster Autoscaler should prefer"
  type        = string
}
variable "aws_load_balancer_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  type        = string
}
variable "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for Cluster Autoscaler"
  type        = string
}
variable "chart_versions" {
  description = "Pinned Helm chart versions"
  type = object({
    metrics_server               = string
    aws_load_balancer_controller = string
    external_secrets             = string
    cluster_autoscaler           = string
  })
}
