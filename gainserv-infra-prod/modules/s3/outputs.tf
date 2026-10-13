output "bucket_name" {
  value       = aws_s3_bucket.app_data.id
  description = "App data bucket name"
}
output "bucket_arn" {
  value       = aws_s3_bucket.app_data.arn
  description = "App data bucket ARN"
}
output "dr_bucket_name" {
  value       = aws_s3_bucket.app_data_dr.id
  description = "DR replica bucket name"
}
