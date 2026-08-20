output "asg_name" {
  value = aws_autoscaling_group.worker.name
}

output "amd64_asg_name" {
  value = var.enable_amd64_fleet ? aws_autoscaling_group.worker_amd64[0].name : null
}

output "manager_private_ip" {
  value = aws_instance.manager.private_ip
}

output "manager_instance_id" {
  value = aws_instance.manager.id
}

output "cache_bucket" {
  value = aws_s3_bucket.cache.bucket
}

output "worker_ami" {
  value = nonsensitive(data.aws_ssm_parameter.worker_ami.value)
}
