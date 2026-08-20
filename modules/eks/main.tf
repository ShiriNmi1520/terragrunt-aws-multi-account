module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  # 固定 nodegroup 只跑系統元件(Karpenter controller、CoreDNS 等),
  # 應用 node 全部交給 Karpenter 開
  eks_managed_node_groups = {
    system = {
      instance_types = ["m6i.large"] # TODO: 依實際負載調整
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }

  # Karpenter EC2NodeClass 靠 discovery tag 找 node SG
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# TODO(bootstrap 第二步): cluster 起來後在這裡加 ArgoCD 一次性安裝
# (helm_release 裝本體 + root Application 指向 GitOps repo),
# 需要 helm/kubernetes provider,建議等第一個 cluster 建起來再補。
