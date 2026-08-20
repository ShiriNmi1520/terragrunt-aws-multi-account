# terragrunt-aws-multi-account

多帳號 AWS 的 Terragrunt template:infra / dev / uat / prod 四個 workload 帳號,加一個 CloudFront 專用帳號,從零建起。

## 邊界規則

打 AWS API 建的資源歸這個 repo;`kubectl apply` 進 cluster 的東西歸 GitOps repo(Kustomize/ArgoCD)。

所以 NodePool/EC2NodeClass、ArgoCD Application 不在這裡,Karpenter 的 IAM/SQS、EKS cluster、VPC 在這裡。兩層接縫靠 `karpenter.sh/discovery` tag(subnet、node SG 都打了),GitOps 側不硬編 resource ID。

## 目錄結構

```
root.hcl                  # backend(S3 in infra 帳號)+ provider 生成,org 常數
live/
  <account>/              # infra / dev / uat / prod
    account.hcl           # 帳號 ID、region、VPC CIDR、NAT 策略、k8s 版本
    network/              # VPC(terraform-aws-modules/vpc,全帳號都有)
    eks/                  # cluster + system nodegroup(terraform-aws-modules/eks v21)
    karpenter-infra/      # controller/node IAM、SQS、EventBridge(eks//modules/karpenter)
    static-web/           # 靜態檔案的 S3 origin,private + OAC(uat + prod)
    envoy-waf/            # Envoy Gateway 用的 REGIONAL WAF + IPSet;掛載走 k8s annotation 引 ARN
    runner-autoscaler/    # GitLab Runner fleeting autoscaler(僅 infra 帳號)
    dns/                  # 共用 Route 53 private zone + 對外部 VPC 的關聯授權(僅 infra 帳號)
    dns-association/      # 各帳號 VPC 與 private zone 的跨帳號關聯(infra 以外全帳號)
    peering/              # hub-spoke VPC peering 發起 + infra 側路由(僅 infra 帳號)
    peering-accept/       # 接受 peering + 本帳號側路由(infra 以外全帳號)
  cdn/                    # CloudFront 專用帳號(region 固定 us-east-1)
    static-web-<env>/     # 各環境的 CloudFront distribution + WAF,跨帳號指向 <env> 的 bucket
modules/                  # 包 community module 的薄 wrapper
```

Unit 依賴關係見 [docs/dependency-graph.svg](docs/dependency-graph.svg),`terragrunt dag graph | dot -Tsvg` 產的,改結構後重跑一次。

同名 stack 的 `terragrunt.hcl` 各帳號完全相同,環境差異全收在 `account.hcl`;要改 stack 行為就改一份再複製過去。module 能用 `terraform-aws-modules` 就不手寫,從零建沒有 import 對齊問題,犯不著自己維護幾百行 VPC/EKS 樣板。

## 開工前 TODO

1. `root.hcl`:填 infra 帳號 ID、region、execution role 名。state bucket 名會組成 `<前綴>-<account_id>-<region>`,改前綴即可
2. 各 `live/<account>/account.hcl`:帳號 ID、region、VPC CIDR、k8s 版本。CIDR 預切了互不重疊的 /16(10.0 / 10.16 / 10.32 / 10.48),跟既有網段對過再用,之後要 peering / TGW 才不用重編
3. 各帳號建 `terraform-execution` role,信任 infra 帳號(或你們的 SSO role)

State bucket 不用手動建,第一次 `terragrunt init` 會提示自動建立(或加 `--backend-bootstrap`)。
