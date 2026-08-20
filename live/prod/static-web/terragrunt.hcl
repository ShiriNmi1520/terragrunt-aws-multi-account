include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/static-web-origin"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  cdn_vars     = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/live/cdn/account.hcl")
}

inputs = {
  name           = local.account_vars.locals.account_name
  cdn_account_id = local.cdn_vars.locals.account_id
}
