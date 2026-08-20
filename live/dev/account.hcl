locals {
  account_name = "dev"
  account_id   = "000000000000"   # TODO: 填 12 碼帳號 ID
  aws_region   = "ap-northeast-1" # TODO: 確認 region

  vpc_cidr           = "10.16.0.0/16" # TODO: 確認不與既有網段衝突
  single_nat_gateway = true
}
