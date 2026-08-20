output "zone_id" {
  description = "各帳號 dns-association 與日後建 record 都吃這個"
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  value = aws_route53_zone.this.name
}
