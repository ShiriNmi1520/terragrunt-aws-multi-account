include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/private-zone"
}

locals {
  repo_root = dirname(find_in_parent_folders("root.hcl"))
  dev_vars  = read_terragrunt_config("${local.repo_root}/live/dev/account.hcl")
  uat_vars  = read_terragrunt_config("${local.repo_root}/live/uat/account.hcl")
  prod_vars = read_terragrunt_config("${local.repo_root}/live/prod/account.hcl")
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id = "vpc-00000000"
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
  zone_name = "myorg.internal" # TODO: 換成自己的 private zone 網域名
  vpc_id    = dependency.network.outputs.vpc_id

  foreign_vpcs = {
    dev = {
      vpc_id     = dependency.dev_network.outputs.vpc_id
      vpc_region = local.dev_vars.locals.aws_region
    }
    uat = {
      vpc_id     = dependency.uat_network.outputs.vpc_id
      vpc_region = local.uat_vars.locals.aws_region
    }
    prod = {
      vpc_id     = dependency.prod_network.outputs.vpc_id
      vpc_region = local.prod_vars.locals.aws_region
    }
  }
}
