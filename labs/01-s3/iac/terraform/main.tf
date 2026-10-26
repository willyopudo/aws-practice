# 01-s3
#
# One private bucket. Nothing else — the point is the create/destroy loop.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Bucket names are global, so add 5 random lowercase letters to avoid collisions.
resource "random_string" "suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = false
  special = false
}

locals {
  bucket_name = "${var.bucket_prefix}-${data.aws_region.current.region}-${random_string.suffix.result}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  # Lets `terraform destroy` succeed even if objects were uploaded while experimenting.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
