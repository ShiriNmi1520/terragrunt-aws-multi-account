# Karpenter 的 AWS 前置件:controller IAM role(Pod Identity)、
# node IAM role、interruption SQS queue、EventBridge rules。
# cluster 內的 NodePool/EC2NodeClass 留在 GitOps repo。

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.25.0"

  cluster_name = var.cluster_name

  # Pod Identity(不走 IRSA),對應 karpenter chart 的 serviceAccount
  create_pod_identity_association = true
  namespace                       = "karpenter"
}
