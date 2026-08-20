output "sites" {
  description = "每站的 distribution id(CI invalidation 用)、domain_name(DNS CNAME 目標)、arn(收緊 bucket policy 用)"
  value = {
    for k, d in aws_cloudfront_distribution.this : k => {
      distribution_id = d.id
      domain_name     = d.domain_name
      arn             = d.arn
    }
  }
}
