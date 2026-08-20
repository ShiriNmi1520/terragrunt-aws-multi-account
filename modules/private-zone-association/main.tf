# 跨帳號關聯的第二段:在 VPC 擁有者帳號接受 infra zone 的 association。
# 授權那一段在 modules/private-zone,執行順序由 terragrunt dependency 保證。

resource "aws_route53_zone_association" "this" {
  zone_id = var.zone_id
  vpc_id  = var.vpc_id
}
