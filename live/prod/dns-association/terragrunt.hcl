include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/private-zone-association"
}

dependency "zone" {
  config_path = "../../infra/dns"

  mock_outputs = {
    zone_id = "Z0000000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id = "vpc-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  zone_id = dependency.zone.outputs.zone_id
  vpc_id  = dependency.network.outputs.vpc_id
}
