locals {
  account_name = "uat"
  account_id   = "000000000000"   # TODO: 填 12 碼帳號 ID
  aws_region   = "ap-northeast-1" # TODO: 確認 region

  vpc_cidr           = "10.32.0.0/16" # TODO: 確認不與既有網段衝突
  single_nat_gateway = true

  kubernetes_version = "1.36" # TODO: 確認要跑的版本

  # envoy-waf 的 IPSet;action: allow/block/count,priority 需 < 10 且互不重複。範例:
  # waf_ip_sets = {
  #   office-allow = {
  #     addresses = ["1.2.3.4/32"]
  #     action    = "allow"
  #     priority  = 1
  #   }
  # }
  waf_ip_sets = {}
}
