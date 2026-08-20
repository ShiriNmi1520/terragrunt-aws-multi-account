variable "region" {
  type    = string
  default = "ap-east-1"
}

variable "vpc_id" {
  type = string
}

# Worker/manager 落地的 private subnet(至少一個)
variable "private_subnet_ids" {
  type = list(string)
}

# 不指定就用 private_subnet_ids 的第一個
variable "manager_subnet_id" {
  type    = string
  default = ""
}

# S3 gateway endpoint 要掛的 route table
variable "private_route_table_ids" {
  type    = list(string)
  default = []
}

# VPC 已有 S3 gateway endpoint:填它的 id,改為只做 route table 關聯(不建新 endpoint)
# 掛關聯前先檢查:endpoint 同 VPC、endpoint policy、bucket policy 的 aws:SourceIp 條件
variable "existing_s3_endpoint_id" {
  type    = string
  default = ""
}

variable "create_s3_endpoint" {
  type    = bool
  default = true
}

# 允許 SSH 進 manager 的來源 CIDR(JumpServer);留空 = 不開 inbound
variable "manager_ssh_ingress_cidr" {
  type    = string
  default = ""
}

# 留空 = 自動組 gitlab-runner-cache-<account_id>-<region>;
# 只在需要沿用特定名稱時覆寫
variable "cache_bucket_name" {
  type    = string
  default = ""
}

variable "worker_instance_type" {
  type    = string
  default = "t4g.medium"
}

# ---- x86 build fleet(rollout 新增)----
variable "enable_amd64_fleet" {
  type    = bool
  default = false # rollout 時設 true
}

variable "amd64_instance_type" {
  type    = string
  default = "c7i.large"
}

variable "amd64_max_instances" {
  type    = number
  default = 4
}

variable "manager_instance_type" {
  type    = string
  default = "t4g.small"
}

variable "max_instances" {
  type    = number
  default = 4
}

variable "worker_disk_gb" {
  type    = number
  default = 40
}
