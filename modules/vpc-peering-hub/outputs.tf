output "connection_ids" {
  description = "各 spoke 帳號的 peering-accept 用帳號名取自己那條"
  value       = { for k, c in aws_vpc_peering_connection.this : k => c.id }
}
