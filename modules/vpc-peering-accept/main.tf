# peering 的 accepter 側:接受 infra 發起的連線 + 建回程路由。
# 跨 region peering 的 accepter 要在 spoke VPC 的 region 跑,本帳號 provider 即是。

resource "aws_vpc_peering_connection_accepter" "this" {
  vpc_peering_connection_id = var.peering_connection_id
  auto_accept               = true

  tags = {
    Name = "to-infra"
  }
}

resource "aws_route" "to_hub" {
  count = length(var.private_route_table_ids)

  route_table_id            = var.private_route_table_ids[count.index]
  destination_cidr_block    = var.peer_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.this.id
}
