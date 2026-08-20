# hub-spoke VPC peering,infra 當 hub。本 module 是 requester,發起連線 + 建 infra 側路由;
# spoke 帳號跑 vpc-peering-accept 接受連線 + 建自己側路由。
# peering 是 non-transitive,spoke 之間不會經 infra 互通,環境隔離就靠這個特性。
#
# 路由只加 private route table。通了之後流量還是被兩側 SG 擋,
# 放行(例如 GitLab/Harbor 開環境網段)在各自的 stack 做。

resource "aws_vpc_peering_connection" "this" {
  for_each = var.peers

  vpc_id        = var.vpc_id
  peer_vpc_id   = each.value.vpc_id
  peer_owner_id = each.value.account_id
  peer_region   = each.value.region

  tags = {
    Name = "${var.name}-${each.key}"
  }
}

locals {
  # 每個 peer × infra 每張 private route table 一條路由
  routes = {
    for pair in setproduct(keys(var.peers), range(length(var.private_route_table_ids))) :
    "${pair[0]}-rtb${pair[1]}" => {
      peer           = pair[0]
      route_table_id = var.private_route_table_ids[pair[1]]
    }
  }
}

resource "aws_route" "to_spoke" {
  for_each = local.routes

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = var.peers[each.value.peer].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.value.peer].id
}
