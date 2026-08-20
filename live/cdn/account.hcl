locals {
  account_name = "cdn"
  account_id   = "000000000000" # TODO: 填 12 碼帳號 ID
  # CloudFront 的 viewer cert(ACM)和 CLOUDFRONT-scope WAF 都只能在 us-east-1,不要改
  aws_region = "us-east-1"
}
