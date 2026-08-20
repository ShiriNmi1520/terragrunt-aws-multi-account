variable "name" {
  description = "環境名稱(等同帳號名:infra/dev/qat/zone0...),也是 karpenter.sh/discovery tag 值"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR,建議 /16"
  type        = string
}

variable "single_nat_gateway" {
  description = "true = 單一 NAT 省錢(dev/qat),false = 每 AZ 一個(prod)"
  type        = bool
  default     = false
}
