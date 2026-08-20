# 這三個值要填進 GitOps repo 的 karpenter chart values / EC2NodeClass:
# - queue_name        → settings.aws.interruptionQueue
# - node_iam_role_name → EC2NodeClass 的 role
# - controller_iam_role_arn → 對照用(Pod Identity 綁定已由本 module 建立)

output "queue_name" {
  value = module.karpenter.queue_name
}

output "node_iam_role_name" {
  value = module.karpenter.node_iam_role_name
}

output "controller_iam_role_arn" {
  value = module.karpenter.iam_role_arn
}
