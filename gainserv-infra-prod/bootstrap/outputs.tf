output "state_bucket_name" {
  description = "Terraform state bucket - used in ../main.tf backend block"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "DynamoDB lock table - used in ../main.tf backend block"
  value       = aws_dynamodb_table.terraform_locks.name
}
