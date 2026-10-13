variable "repository_name" {
  description = "ECR repository name"
  type        = string
}
variable "force_delete" {
  description = "Allow destroy while images exist"
  type        = bool
  default     = false
}
