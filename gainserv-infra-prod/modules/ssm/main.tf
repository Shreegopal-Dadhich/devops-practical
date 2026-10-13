terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_ssm_parameter" "app_secrets" {
  for_each = var.secret_names

  name        = "${var.path_prefix}/${each.value}"
  type        = "SecureString"
  value       = "dummy"
  description = "SSM Parameter of ${var.path_prefix}/${each.value}"

  tags = {
    "Name" = "${var.name_prefix}-${each.value}"
  }

  lifecycle {
    ignore_changes = [value]
  }
}
