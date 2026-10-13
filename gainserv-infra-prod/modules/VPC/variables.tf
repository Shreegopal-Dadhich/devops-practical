variable "name_prefix" {
  description = "Name prefix - <ProjectName>-<Environment>"
  type        = string
}
variable "aws_region" {
  description = "AWS region"
  type        = string
}
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}
variable "azs" {
  description = "Availability zones"
  type        = list(string)
}
