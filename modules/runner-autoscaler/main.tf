# GitLab Runner fleeting autoscaler:manager EC2 跑 gitlab-runner + fleeting plugin,
# worker 用 ASG(min/desired 0,容量由 plugin 全控),job cache 走 S3。
# IAM role / SG / ASG 名稱是固定字串,同帳號只能部署一份。

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix = "gitlab-runner"
  asg_name    = "gitlab-runner-arm64-asg"

  # 命名慣例:<用途>-<account_id>-<region>;沒覆寫變數時自動組出
  cache_bucket_name = var.cache_bucket_name != "" ? var.cache_bucket_name : "gitlab-runner-cache-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"

  # ASG CloudWatch group metrics(免費,1 分鐘粒度);與 WebUI「enable all」對齊
  asg_metrics = [
    "GroupAndWarmPoolDesiredCapacity", "GroupAndWarmPoolTotalCapacity",
    "GroupDesiredCapacity", "GroupInServiceCapacity", "GroupInServiceInstances",
    "GroupMaxSize", "GroupMinSize", "GroupPendingCapacity", "GroupPendingInstances",
    "GroupStandbyCapacity", "GroupStandbyInstances", "GroupTerminatingCapacity",
    "GroupTerminatingInstances", "GroupTerminatingRetainedCapacity",
    "GroupTerminatingRetainedInstances", "GroupTotalCapacity", "GroupTotalInstances",
    "WarmPoolDesiredCapacity", "WarmPoolMinSize", "WarmPoolPendingCapacity",
    "WarmPoolPendingRetainedCapacity", "WarmPoolTerminatingCapacity",
    "WarmPoolTerminatingRetainedCapacity", "WarmPoolTotalCapacity", "WarmPoolWarmedCapacity",
  ]
  manager_subnet_id = var.manager_subnet_id != "" ? var.manager_subnet_id : var.private_subnet_ids[0]
  # gitlab-runner-* 前綴涵蓋兩個 fleet 的 ASG(arm64 / amd64),之後加 fleet 免改 IAM
  asg_arn = "arn:aws:autoscaling:${var.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/gitlab-runner-*"
}

# ---------- AMI ----------

# Worker:ECS-optimized AL2023 arm64,Docker 內建
data "aws_ssm_parameter" "worker_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

# Manager:一般 AL2023 arm64
data "aws_ssm_parameter" "manager_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# x86 build fleet worker:ECS-optimized AL2023 x86_64
data "aws_ssm_parameter" "worker_ami_amd64" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# ---------- S3 cache ----------

resource "aws_s3_bucket" "cache" {
  bucket = local.cache_bucket_name
}

resource "aws_s3_bucket_public_access_block" "cache" {
  bucket                  = aws_s3_bucket.cache.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cache" {
  bucket = aws_s3_bucket.cache.id
  rule {
    id     = "expire-30d"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  # 沒給 route table 就不建(沒關聯的 endpoint 是死的);已有 endpoint + 關聯時全部留空即可
  count             = var.create_s3_endpoint && var.existing_s3_endpoint_id == "" && length(var.private_route_table_ids) > 0 ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
}

# 現存 endpoint 只補 route table 關聯
resource "aws_vpc_endpoint_route_table_association" "s3_existing" {
  count           = var.existing_s3_endpoint_id != "" ? length(var.private_route_table_ids) : 0
  vpc_endpoint_id = var.existing_s3_endpoint_id
  route_table_id  = var.private_route_table_ids[count.index]
}

# ---------- Security groups ----------

resource "aws_security_group" "manager" {
  name        = "${local.name_prefix}-manager"
  description = "GitLab Runner autoscaler manager"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "manager_ssh" {
  count             = var.manager_ssh_ingress_cidr != "" ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.manager.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.manager_ssh_ingress_cidr]
}

resource "aws_security_group" "worker" {
  name        = "${local.name_prefix}-worker"
  description = "GitLab Runner autoscaler worker"
  vpc_id      = var.vpc_id

  # 只有 manager 能 SSH 進 worker
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.manager.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- IAM:manager ----------

resource "aws_iam_role" "manager" {
  name = "${local.name_prefix}-manager"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "manager" {
  name = "fleeting"
  role = aws_iam_role.manager.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:SetInstanceProtection",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = local.asg_arn
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeSpotInstanceRequests",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "ec2-instance-connect:SendSSHPublicKey"
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/aws:autoscaling:groupName" = "gitlab-runner-*"
          }
        }
      },
    ]
  })
}

# 維運連入走 SSM Session Manager(零 inbound)
resource "aws_iam_role_policy_attachment" "manager_ssm" {
  role       = aws_iam_role.manager.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "manager" {
  name = "${local.name_prefix}-manager"
  role = aws_iam_role.manager.name
}

# ---------- IAM:worker(S3 cache) ----------

resource "aws_iam_role" "worker" {
  name = "${local.name_prefix}-worker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

locals {
  cache_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.cache.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.cache.arn
      },
    ]
  })
}

resource "aws_iam_role_policy" "worker" {
  name   = "runner-cache"
  role   = aws_iam_role.worker.id
  policy = local.cache_policy
}

# 新版 runner 的 cache 走 presigned URL:簽名者是 manager(產 URL 給 helper),
# 所以 S3 權限必須在 manager role 上;worker 那份留作備援(舊行為/直傳模式)
resource "aws_iam_role_policy" "manager_cache" {
  name   = "runner-cache"
  role   = aws_iam_role.manager.id
  policy = local.cache_policy
}

resource "aws_iam_instance_profile" "worker" {
  name = "${local.name_prefix}-worker"
  role = aws_iam_role.worker.name
}

# ---------- Worker launch template + ASG ----------

resource "aws_launch_template" "worker" {
  name                   = "${local.name_prefix}-worker-arm64"
  update_default_version = true
  image_id               = data.aws_ssm_parameter.worker_ami.value
  instance_type          = var.worker_instance_type

  vpc_security_group_ids = [aws_security_group.worker.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  # helper container 拿 instance profile 憑證要過兩跳,hop limit 必須 2
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.worker_disk_gb
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    usermod -aG docker ec2-user || true
    systemctl enable --now docker
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-worker-arm64"
    }
  }
}

resource "aws_autoscaling_group" "worker" {
  name                = local.asg_name
  enabled_metrics     = local.asg_metrics
  min_size            = 0
  desired_capacity    = 0
  max_size            = var.max_instances
  vpc_zone_identifier = var.private_subnet_ids

  # fleeting 硬性要求:plugin 逐台指定終止、AWS 不得自行 rebalance
  protect_from_scale_in = true
  suspended_processes   = ["AZRebalance"]
  health_check_type     = "EC2"
  # worker 為 ephemeral;destroy/重建 ASG 時直接終止殘留 instance(操作前先 pause+stop runner)
  force_delete = true

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  # 容量由 fleeting plugin 全控,TF 不得干預
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ---------- x86 build fleet(rollout 新增,enable_amd64_fleet 開關)----------
# 僅承接 amd64 buildkit build(~17 job/天);SG / instance profile / 磁碟與 arm64 fleet 共用設定

resource "aws_launch_template" "worker_amd64" {
  count                  = var.enable_amd64_fleet ? 1 : 0
  name                   = "${local.name_prefix}-worker-amd64"
  update_default_version = true
  image_id               = data.aws_ssm_parameter.worker_ami_amd64.value
  instance_type          = var.amd64_instance_type

  vpc_security_group_ids = [aws_security_group.worker.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.worker_disk_gb
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    usermod -aG docker ec2-user || true
    systemctl enable --now docker
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-worker-amd64"
    }
  }
}

resource "aws_autoscaling_group" "worker_amd64" {
  count               = var.enable_amd64_fleet ? 1 : 0
  name                = "gitlab-runner-amd64-asg"
  enabled_metrics     = local.asg_metrics
  min_size            = 0
  desired_capacity    = 0
  max_size            = var.amd64_max_instances
  vpc_zone_identifier = var.private_subnet_ids

  protect_from_scale_in = true
  suspended_processes   = ["AZRebalance"]
  health_check_type     = "EC2"
  force_delete          = true

  launch_template {
    id      = aws_launch_template.worker_amd64[0].id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ---------- Manager EC2 ----------

resource "aws_instance" "manager" {
  ami                         = data.aws_ssm_parameter.manager_ami.value
  instance_type               = var.manager_instance_type
  subnet_id                   = local.manager_subnet_id
  vpc_security_group_ids      = [aws_security_group.manager.id]
  iam_instance_profile        = aws_iam_instance_profile.manager.name
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # 只裝套件;config.toml、fleeting plugin 安裝、runner 註冊依內部 runbook 手動做
  user_data = <<-EOT
    #!/bin/bash
    curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash
    dnf install -y gitlab-runner
    mkdir -p /etc/systemd/system/gitlab-runner.service.d
    printf '[Service]\nEnvironment="AWS_REGION=${var.region}"\n' > /etc/systemd/system/gitlab-runner.service.d/aws.conf
    systemctl daemon-reload
  EOT

  tags = {
    Name = "${local.name_prefix}-manager"
  }

  # manager 是有狀態的(config.toml/token 手工管理),AMI 隨 SSM recommended 漂移
  # 不得觸發重建;要升級 OS 用 dnf,要換 AMI 時拿掉這行明確操作
  lifecycle {
    ignore_changes = [ami]
  }
}
