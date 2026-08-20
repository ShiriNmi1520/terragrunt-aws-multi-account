output "bucket_name" {
  description = "CI 部署目標:aws s3 sync dist/ s3://<這個>/<site>/"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_regional_domain_name" {
  description = "cdn 帳號的 distribution 拿去當 origin domain"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
