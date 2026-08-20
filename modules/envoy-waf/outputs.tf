output "web_acl_arn" {
  description = "填進 GitOps repo 的 alb.ingress.kubernetes.io/wafv2-acl-arn annotation"
  value       = aws_wafv2_web_acl.this.arn
}

output "ip_set_arns" {
  value = { for k, s in aws_wafv2_ip_set.this : k => s.arn }
}
