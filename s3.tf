resource "aws_s3_bucket" "site" {
  bucket        = "final-lab-site-${data.aws_caller_identity.me.account_id}"
  force_destroy = true

  tags = {
    Name = "final-lab-site"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyUploadExceptBastion"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          ArnNotEquals = { "aws:PrincipalArn" = aws_iam_role.bastion.arn }
        }
      },
      {
        Sid       = "DenyContentAccessOutsideVpce"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:PutObject"]
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringNotEquals = { "aws:SourceVpce" = aws_vpc_endpoint.s3.id }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}
