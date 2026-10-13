terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_iam_role" "irsa" {
  name = "${var.name_prefix}-${var.name}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
            "${var.oidc_issuer}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    "Name" = "${var.name_prefix}-${var.name}-irsa-role"
  }
}

resource "aws_iam_role_policy" "irsa" {
  name   = "${var.name_prefix}-${var.name}-irsa-policy"
  role   = aws_iam_role.irsa.id
  policy = var.policy_json
}
