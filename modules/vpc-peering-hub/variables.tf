variable "name" {
  description = "hub 端名稱(infra)"
  type        = string
}

variable "vpc_id" {
  description = "hub(infra)的 VPC"
  type        = string
}

variable "private_route_table_ids" {
  description = "hub 側要加對 spoke 路由的 route table"
  type        = list(string)
}

variable "peers" {
  description = "spoke 清單,key 用帳號名;完成互通還需各帳號跑 vpc-peering-accept"
  type = map(object({
    vpc_id     = string
    vpc_cidr   = string
    account_id = string
    region     = string
  }))
}
