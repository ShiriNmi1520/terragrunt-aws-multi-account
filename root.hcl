# Terragrunt root 設定:所有 unit 透過 include 繼承 backend 與 provider。
# 全 org 常數集中在這裡;帳號層變數在各 live/<account>/account.hcl。

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.account_id
  aws_region   = local.account_vars.locals.aws_region

  # ── org 常數 ──────────────────────────────────────────────
  infra_account_id = "000000000000" # TODO: infra 帳號 ID(state bucket 所在)
  state_region     = "ap-east-1"    # TODO: 跟 infra 帳號同 region
  # 命名慣例:<用途>-<account_id>-<region>;TODO: 換成自己的前綴
  state_bucket = "myorg-terraform-state-${local.infra_account_id}-${local.state_region}"
  terraform_role_name = "terraform-execution" # TODO: 各帳號內給 Terraform assume 的 role 名稱
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = local.state_bucket
    region       = local.state_region
    key          = "${path_relative_to_include()}/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # Terraform 1.11+ S3 原生 lockfile,不需要 DynamoDB

    # 執行身分若不在 infra 帳號,打開這段讓 backend 自己 assume 進去讀寫 state:
    # assume_role = {
    #   role_arn = "arn:aws:iam::${local.infra_account_id}:role/${local.terraform_role_name}"
    # }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      assume_role {
        role_arn = "arn:aws:iam::${local.account_id}:role/${local.terraform_role_name}"
      }

      default_tags {
        tags = {
          ManagedBy = "terraform"
          Account   = "${local.account_name}"
        }
      }
    }
  EOF
}
