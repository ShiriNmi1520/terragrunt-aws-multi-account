# Envoy Gateway 前面那顆 ALB 用的 REGIONAL WAF。這裡只建 web ACL + IPSet,
# 掛載在 k8s 側,ingress/gateway annotation 填:
#   alb.ingress.kubernetes.io/wafv2-acl-arn: <web_acl_arn output>
#
# IPSet 比對的是連線來源 IP。流量若先過 Cloudflare/CloudFront 再進 ALB,
# 來源會是 CDN 的 IP,得改用 forwarded_ip_config 看 header;
# 確認流量鏈之前別把規則設成 block。

resource "aws_wafv2_ip_set" "this" {
  for_each = var.ip_sets

  name               = "${var.name}-${each.key}"
  scope              = "REGIONAL"
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.addresses
}

resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name}-envoy"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # IPSet 規則(priority 要排在 managed rules 的 10/20/30 之前)
  dynamic "rule" {
    for_each = var.ip_sets

    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.this[rule.key].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  # AWS managed rules;API 流量(JSON body)被 CommonRuleSet 誤殺很常見,
  # 上線先觀察 CloudWatch metrics,誤殺的 sub-rule 再用 rule_action_override 放行
  dynamic "rule" {
    for_each = var.enable_managed_rules ? local.waf_managed_rules : {}

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
    metric_name                = "${var.name}-envoy"
    sampled_requests_enabled   = true
  }
}

locals {
  waf_managed_rules = {
    common     = { name = "AWSManagedRulesCommonRuleSet", priority = 10 }
    bad_inputs = { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 }
    ip_rep     = { name = "AWSManagedRulesAmazonIpReputationList", priority = 30 }
  }
}
