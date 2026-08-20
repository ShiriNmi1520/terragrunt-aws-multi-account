include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/vpc-peering-accept"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  infra_vars   = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/live/infra/account.hcl")
}

dependency "peering" {
  config_path = "../../infra/peering"

  mock_outputs = {
    connection_ids = {
      dev  = "pcx-00000000"
      uat  = "pcx-00000000"
      prod = "pcx-00000000"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    private_route_table_ids = ["rtb-00000000"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  peering_connection_id   = dependency.peering.outputs.connection_ids[local.account_vars.locals.account_name]
  private_route_table_ids = dependency.network.outputs.private_route_table_ids
  peer_cidr               = local.infra_vars.locals.vpc_cidr
}
