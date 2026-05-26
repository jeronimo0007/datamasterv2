output "lake_bucket_name" {
  description = "Bucket S3 do data lake"
  value       = aws_s3_bucket.datamaster_lake.bucket
}

output "lake_bucket_arn" {
  description = "ARN do bucket"
  value       = aws_s3_bucket.datamaster_lake.arn
}
