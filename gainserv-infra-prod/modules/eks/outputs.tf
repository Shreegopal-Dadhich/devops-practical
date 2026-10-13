output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "EKS cluster name"
}
output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "EKS API endpoint"
}
output "cluster_certificate_authority" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "EKS cluster CA certificate (base64)"
}
output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.eks.arn
  description = "OIDC provider ARN - trusted by every IRSA role"
}
output "oidc_issuer" {
  value       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  description = "OIDC issuer without https://"
}
output "node_role_arn" {
  value       = aws_iam_role.eks_node_role.arn
  description = "EKS node role ARN"
}
