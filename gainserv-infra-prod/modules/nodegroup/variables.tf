variable "name" {
  description = "Node pool name (map key), e.g. system or apps-spot"
  type        = string
}
variable "name_prefix" {
  description = "Name prefix - <ProjectName>-<Environment>"
  type        = string
}
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}
variable "node_role_arn" {
  description = "EKS node role ARN"
  type        = string
}
variable "subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}
variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
}
variable "instance_types" {
  description = "Instance types for the node group"
  type        = list(string)

  validation {
    condition     = var.capacity_type != "SPOT" || length(var.instance_types) >= 2
    error_message = "SPOT node groups need at least 2 instance types so one reclaimed Spot pool can't take out the whole group."
  }
}
variable "min_size" {
  description = "Minimum nodes"
  type        = number
}
variable "max_size" {
  description = "Maximum nodes"
  type        = number
}
variable "desired_size" {
  description = "Initial nodes (Cluster Autoscaler owns it afterwards)"
  type        = number
}
variable "tags" {
  description = "Tags for EC2 instances and volumes"
  type        = map(string)
}
