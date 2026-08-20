variable "name" {
  description = "對應的環境名(qat/zone0...)"
  type        = string
}

variable "origin_bucket_domain_name" {
  description = "環境帳號 static-web bucket 的 regional domain name"
  type        = string
}

variable "sites" {
  description = "每站一個 distribution。origin_path = bucket 內的 prefix(前導斜線);aliases 要配 certificate_arn(us-east-1 ACM)才會生效"
  type = map(object({
    origin_path           = string
    aliases               = optional(list(string), [])
    certificate_arn       = optional(string)
    spa_fallback          = optional(bool, true)
    rewrite_function_file = optional(string) # module 內 functions/ 下的 viewer-request rewrite(例:rewrite-example.js)
  }))
}

variable "price_class" {
  type    = string
  default = "PriceClass_All" # 亞洲流量為主可考慮 PriceClass_200
}
