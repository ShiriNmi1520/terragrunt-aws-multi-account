include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/static-web-cdn"
}

dependency "origin" {
  config_path = "../../prod/static-web"

  mock_outputs = {
    bucket_regional_domain_name = "mock.s3.ap-northeast-1.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name                      = "prod"
  origin_bucket_domain_name = dependency.origin.outputs.bucket_regional_domain_name

  # 每站一個 distribution。aliases 要等該站的 certificate_arn(us-east-1 ACM)填上才生效,
  # 沒 cert 前會先用 *.cloudfront.net。alias 全球唯一,各環境別填同一個網域。
  sites = {
    # 純 SPA 站:bucket 內以 origin_path 為根
    app = {
      origin_path = "/app"
      aliases     = [] # TODO: 站台網域,填了就要一起給 certificate_arn
    }
    # 需要 URI rewrite 的站:origin 指 bucket 根,路由和 SPA fallback 都在 function 裡
    assets = {
      origin_path           = ""
      aliases               = [] # TODO
      spa_fallback          = false
      rewrite_function_file = "functions/rewrite-example.js"
    }
  }
}
