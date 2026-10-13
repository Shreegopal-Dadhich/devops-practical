output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}
output "vpc_cidr" {
  value       = aws_vpc.main.cidr_block
  description = "VPC CIDR block"
}
output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "Public subnet IDs"
}
output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "Private subnet IDs"
}
output "public_supernet_cidr" {
  value       = local.public_supernet
  description = "CIDR that contains every public subnet"
}
