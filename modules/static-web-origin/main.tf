# 靜態檔案的 S3 origin,放各環境帳號。CloudFront 在 cdn 帳號(modules/static-web-cdn),
# 靠 bucket policy 的 SourceArn 限定只有 cdn 帳號的 distribution 能讀。
# bucket 維持 private,不開 website endpoint。

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# bucket 名帶 account/region 後綴,避免全域撞名
resource "aws_s3_bucket" "this" {
  bucket = "${var.name}-static-web-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "intelligent_tiering_rule"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    filter {
      object_size_greater_than = 131072 # 128KB in bytes
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudfront_read" {
  bucket = aws_s3_bucket.this.id

  # wildcard 是為了避開跨帳號的雞生蛋(bucket policy 要 dist ARN、dist 要 bucket domain);
  # distribution 建好後可以換成完整 ARN 收緊
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.this.arn}/*"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:cloudfront::${var.cdn_account_id}:distribution/*"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
