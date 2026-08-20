variable "zone_name" {
  description = "Private zone 網域名"
  type        = string
}

variable "vpc_id" {
  description = "infra 帳號自己的 VPC(zone 建立時的第一個關聯)"
  type        = string
}

variable "foreign_vpcs" {
  description = "其他帳號的 VPC,key 用帳號名;完成關聯還需各帳號跑 private-zone-association"
  type = map(object({
    vpc_id     = string
    vpc_region = string
  }))
  default = {}
}
