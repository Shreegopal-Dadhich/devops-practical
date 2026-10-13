variable "name_prefix" {
  description = "Name prefix - <ProjectName>-<Environment>"
  type        = string
}
variable "path_prefix" {
  description = "SSM path prefix, e.g. /gainserv/prod/app-server"
  type        = string
}
variable "secret_names" {
  description = "Secret env var names - one parameter each"
  type        = set(string)
}
