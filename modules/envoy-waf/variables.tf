variable "name" {
  description = "環境名稱(等同帳號名)"
  type        = string
}

variable "ip_sets" {
  description = "IPSet 規則。action: allow/block/count;priority 需 < 10(排在 managed rules 前)且互不重複"
  type = map(object({
    addresses          = list(string) # CIDR 格式,單一 IP 用 /32
    action             = string
    priority           = number
    ip_address_version = optional(string, "IPV4")
  }))
  default = {}

  validation {
    condition     = alltrue([for s in var.ip_sets : contains(["allow", "block", "count"], s.action)])
    error_message = "action 只能是 allow / block / count。"
  }
}

variable "enable_managed_rules" {
  type    = bool
  default = true
}
