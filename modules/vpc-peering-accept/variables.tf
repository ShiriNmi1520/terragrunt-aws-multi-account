variable "peering_connection_id" {
  description = "infra 的 peering stack 發起的連線 id(connection_ids output 取自己帳號那條)"
  type        = string
}

variable "private_route_table_ids" {
  description = "本帳號要加對 infra 路由的 route table"
  type        = list(string)
}

variable "peer_cidr" {
  description = "infra VPC 的 CIDR(路由目的地)"
  type        = string
}
