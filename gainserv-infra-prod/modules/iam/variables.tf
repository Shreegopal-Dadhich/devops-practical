variable "name" {
  description = "Role name (map key)"
  type        = string
}
variable "name_prefix" {
  description = "Name prefix - <ProjectName>-<Environment>"
  type        = string
}
variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}
variable "oidc_issuer" {
  description = "EKS OIDC issuer without https://"
  type        = string
}
variable "namespace" {
  description = "Kubernetes namespace of the ServiceAccount"
  type        = string
}
variable "service_account" {
  description = "Kubernetes ServiceAccount allowed to assume the role"
  type        = string
}
variable "policy_json" {
  description = "IAM policy JSON - only what this workload needs"
  type        = string
}
