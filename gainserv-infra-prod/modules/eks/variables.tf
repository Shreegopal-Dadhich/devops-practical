variable "name_prefix" {
  description = "Name prefix - <ProjectName>-<Environment>"
  type        = string
}
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}
variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
}
variable "private_subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs"
  type        = list(string)
}
variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint"
  type        = list(string)
}
