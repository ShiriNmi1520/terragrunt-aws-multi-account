include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/vpc-peering-hub"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  repo_root    = dirname(find_in_parent_folders("root.hcl"))
  dev_vars     = read_terragrunt_config("${local.repo_root}/live/dev/account.hcl")
  uat_vars     = read_terragrunt_config("${local.repo_root}/live/uat/account.hcl")
  prod_vars    = read_terragrunt_config("${local.repo_root}/live/prod/account.hcl")
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id                  = "vpc-00000000"
    private_route_table_ids = ["rtb-00000000"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "dev_network" {
  config_path = "../../dev/network"

  mock_outputs = {
    vpc_id = "vpc-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "uat_network" {
  config_path = "../../uat/network"

  mock_outputs = {
    vpc_id = "vpc-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "prod_network" {
  config_path = "../../prod/network"

  mock_outputs = {
    vpc_id = "vpc-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name                    = local.account_vars.locals.account_name
  vpc_id                  = dependency.network.outputs.vpc_id
  private_route_table_ids = dependency.network.outputs.private_route_table_ids

  peers = {
    dev = {
      vpc_id     = dependency.dev_network.outputs.vpc_id
      vpc_cidr   = local.dev_vars.locals.vpc_cidr
      account_id = local.dev_vars.locals.account_id
      region     = local.dev_vars.locals.aws_region
    }
    uat = {
      vpc_id     = dependency.uat_network.outputs.vpc_id
      vpc_cidr   = local.uat_vars.locals.vpc_cidr
      account_id = local.uat_vars.locals.account_id
      region     = local.uat_vars.locals.aws_region
    }
    prod = {
      vpc_id     = dependency.prod_network.outputs.vpc_id
      vpc_cidr   = local.prod_vars.locals.vpc_cidr
      account_id = local.prod_vars.locals.account_id
      region     = local.prod_vars.locals.aws_region
    }
  }
}
