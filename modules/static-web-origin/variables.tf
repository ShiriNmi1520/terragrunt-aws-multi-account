variable "name" {
  description = "環境名稱(等同帳號名)"
  type        = string
}

variable "cdn_account_id" {
  description = "CloudFront 所在帳號的 12 碼 ID(bucket policy 授權範圍)"
  type        = string
}
