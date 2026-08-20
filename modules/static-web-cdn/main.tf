# sites map 一項一個 distribution,共用同一個 origin bucket(origin_path 分 prefix)
# 和同一組 OAC / CORS policy / WAF ACL。WAF 按 ACL 收月費,沒必要一站一組。
# 只能在 us-east-1 provider 下跑:CLOUDFRONT scope 的 WAF 跟 viewer cert 的 ACM
# 都限定 us-east-1,cdn 帳號的 account.hcl 已寫死。

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name}-static-web"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS managed 的 cache / origin request policy,不自己造
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "cors_s3" {
  name = "Managed-CORS-S3Origin"
}

# 靜態站常見 CORS 設定(Allow-Origin * / Expose Content-Length / Max-Age 3600)
resource "aws_cloudfront_response_headers_policy" "cors" {
  name = "${var.name}-static-web-cors"

  cors_config {
    access_control_allow_credentials = false
    access_control_max_age_sec       = 3600
    origin_override                  = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_expose_headers {
      items = ["Content-Length"]
    }
  }
}

# 站台專屬的 viewer-request rewrite(範例見 functions/rewrite-example.js)
resource "aws_cloudfront_function" "rewrite" {
  for_each = { for k, s in var.sites : k => s if s.rewrite_function_file != null }

  name    = "${var.name}-${each.key}-rewrite"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "${var.name} ${each.key} URI rewrite"
  code    = file("${path.module}/${each.value.rewrite_function_file}")
}

resource "aws_cloudfront_distribution" "this" {
  for_each = var.sites

  enabled             = true
  comment             = "${var.name} ${each.key}"
  default_root_object = "index.html"
  price_class         = var.price_class
  web_acl_id          = aws_wafv2_web_acl.this.arn

  # CloudFront 不允許 aliases 配預設憑證,cert 沒填前先忽略 aliases,
  # 用 *.cloudfront.net 把鏈路建起來驗證
  aliases = each.value.certificate_arn == null ? [] : each.value.aliases

  origin {
    domain_name              = var.origin_bucket_domain_name
    origin_id                = "s3"
    origin_path              = each.value.origin_path
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.cors_s3.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id

    dynamic "function_association" {
      for_each = each.value.rewrite_function_file != null ? [1] : []

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.rewrite[each.key].arn
      }
    }
  }

  # SPA fallback。OAC 下拿不到的 key S3 回的是 403 不是 404,兩個都要接;
  # response_page_path 在 origin_path 底下解析,回到該站自己的 index.html
  dynamic "custom_error_response" {
    for_each = each.value.spa_fallback ? [403, 404] : []

    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = each.value.certificate_arn == null
    acm_certificate_arn            = each.value.certificate_arn
    ssl_support_method             = each.value.certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = each.value.certificate_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }
}

# WAF:整個環境的 distribution 共用一組(CLOUDFRONT scope)

locals {
  waf_managed_rules = {
    common     = { name = "AWSManagedRulesCommonRuleSet", priority = 10 }
    bad_inputs = { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 }
    ip_rep     = { name = "AWSManagedRulesAmazonIpReputationList", priority = 30 }
  }
}

resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name}-static-web"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.waf_managed_rules

    content {
      name     = rule.key
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-static-web"
    sampled_requests_enabled   = true
  }
}
