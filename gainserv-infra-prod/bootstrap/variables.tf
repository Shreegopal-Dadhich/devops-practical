variable "aws_region" {
  description = "AWS region - must match the backend block in ../main.tf"
  type        = string
  default     = "ap-south-1"
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
}
