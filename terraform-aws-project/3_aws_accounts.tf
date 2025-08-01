# AWS Organizations 
# Note: In AWS, you typically don't create accounts via Terraform in production
# This is more for reference and would be done manually or via AWS Control Tower

# IAM Roles for cross-account access (equivalent to service accounts)
resource "aws_iam_role" "cross_account_role" {
  for_each = local.accounts
  name     = "CrossAccountRole-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${each.value.account_id}:root"
        }
      }
    ]
  })

  tags = {
    Name        = "CrossAccountRole-${each.key}"
    Environment = each.value.environment
    Account     = each.key
  }
}

# IAM policies for the roles
resource "aws_iam_role_policy" "cross_account_policy" {
  for_each = local.accounts
  name     = "CrossAccountPolicy-${each.key}"
  role     = aws_iam_role.cross_account_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "elasticache:*",
          "rds:*",
          "logs:*",
          "cloudformation:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Enable necessary AWS services 
# Note: Most AWS services are enabled by default, but some require explicit enablement

# Enable Config for compliance
resource "aws_config_configuration_recorder" "recorder" {
  for_each = local.accounts
  name     = "config-recorder-${each.key}"
  role_arn = aws_iam_role.config_role[each.key].arn

  recording_group {
    all_supported = true
  }

  depends_on = [aws_iam_role.config_role]
}

# IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  for_each = local.accounts
  name     = "aws-config-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "aws-config-role-${each.key}"
    Environment = each.value.environment
    Account     = each.key
  }
}

# Attach AWS managed policy for Config
resource "aws_iam_role_policy_attachment" "config_policy" {
  for_each   = local.accounts
  role       = aws_iam_role.config_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Enable CloudTrail for audit logging
resource "aws_cloudtrail" "main" {
  for_each                      = local.accounts
  name                          = "cloudtrail-${each.key}"
  s3_bucket_name               = aws_s3_bucket.cloudtrail[each.key].bucket
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  tags = {
    Name        = "cloudtrail-${each.key}"
    Environment = each.value.environment
    Account     = each.key
  }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  for_each = local.accounts
  bucket   = "cloudtrail-logs-${each.key}-${random_string.bucket_suffix[each.key].result}"

  tags = {
    Name        = "cloudtrail-logs-${each.key}"
    Environment = each.value.environment
    Account     = each.key
  }
}

# Random string for unique S3 bucket names
resource "random_string" "bucket_suffix" {
  for_each = local.accounts
  length   = 8
  special  = false
  upper    = false
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  for_each = local.accounts
  bucket   = aws_s3_bucket.cloudtrail[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[each.key].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[each.key].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
