include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/envoy-waf"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

inputs = {
  name    = local.account_vars.locals.account_name
  ip_sets = local.account_vars.locals.waf_ip_sets
}
