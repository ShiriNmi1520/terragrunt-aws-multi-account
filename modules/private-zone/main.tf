# Route 53 private hosted zone(infra 帳號持有,共用給所有帳號的 VPC)。
# 跨帳號關聯是兩段式握手:
#   1. 本 module(zone 擁有者)對每個外部 VPC 發 association authorization
#   2. VPC 擁有者帳號跑 private-zone-association module 完成關聯
# infra 自己的 VPC 直接掛在 zone 上(建 zone 至少要掛一個 VPC)。

resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = "Shared private zone, managed in infra account"

  vpc {
    vpc_id = var.vpc_id
  }

  # 其他帳號的 VPC 由各帳號的 aws_route53_zone_association 掛,
  # 不歸 zone 資源管,必須 ignore 否則每次 plan 都想拆別人的關聯
  lifecycle {
    ignore_changes = [vpc]
  }
}

# 對外部帳號 VPC 的關聯授權。外部 VPC 跟本 provider 不同 region,vpc_region 必填
resource "aws_route53_vpc_association_authorization" "foreign" {
  for_each = var.foreign_vpcs

  zone_id    = aws_route53_zone.this.zone_id
  vpc_id     = each.value.vpc_id
  vpc_region = each.value.vpc_region
}
