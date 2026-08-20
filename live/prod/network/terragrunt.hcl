include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/network"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

inputs = {
  name               = local.account_vars.locals.account_name
  vpc_cidr           = local.account_vars.locals.vpc_cidr
  single_nat_gateway = local.account_vars.locals.single_nat_gateway
}
