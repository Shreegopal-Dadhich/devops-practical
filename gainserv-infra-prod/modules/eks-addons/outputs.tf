output "alb_controller_release" {
  value       = helm_release.aws_load_balancer_controller.version
  description = "AWS Load Balancer Controller chart version"
}
