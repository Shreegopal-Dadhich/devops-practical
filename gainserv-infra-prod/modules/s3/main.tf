terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

#app data bucket - the app reads it via IRSA
resource "aws_s3_bucket" "app_data" {
  bucket = var.bucket_name
  tags = {
    "Name" = var.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#versioning - required for replication
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

#replica bucket in the DR region
resource "aws_s3_bucket" "app_data_dr" {
  provider = aws.dr
  bucket   = "${var.bucket_name}-dr"
  tags = {
    "Name" = "${var.bucket_name}-dr"
  }
}

resource "aws_s3_bucket_public_access_block" "app_data_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.app_data_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app_data_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.app_data_dr.id
  versioning_configuration {
    status = "Enabled"
  }
}

#replication role
resource "aws_iam_role" "replication_role" {
  name = "${var.bucket_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    "Name" = "${var.bucket_name}-replication-role"
  }
}

resource "aws_iam_role_policy" "replication_policy" {
  name = "${var.bucket_name}-replication-policy"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = aws_s3_bucket.app_data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.app_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.app_data_dr.arn}/*"
      }
    ]
  })
}

#replication primary -> DR
resource "aws_s3_bucket_replication_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.app_data_dr.arn
      storage_class = "STANDARD_IA" # cold copy, cheaper storage
    }
  }

  depends_on = [aws_s3_bucket_versioning.app_data, aws_s3_bucket_versioning.app_data_dr]
}
