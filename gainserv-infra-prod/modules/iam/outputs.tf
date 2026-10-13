output "role_arn" {
  value       = aws_iam_role.irsa.arn
  description = "IRSA role ARN - goes on the ServiceAccount annotation"
}
