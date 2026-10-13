terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_launch_template" "node" {
  name_prefix = "${var.name_prefix}-${var.name}-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      "Name" = "${var.name_prefix}-${var.name}-node"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      "Name" = "${var.name_prefix}-${var.name}-node"
    })
  }

  tags = {
    "Name" = "${var.name_prefix}-${var.name}-lt"
  }

  lifecycle {
    create_before_destroy = true
  }
}

#EKS managed node group
resource "aws_eks_node_group" "main" {
  cluster_name           = var.cluster_name
  node_group_name_prefix = "${var.name_prefix}-${var.name}-"
  node_role_arn          = var.node_role_arn
  subnet_ids             = var.subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = var.capacity_type
  instance_types = var.instance_types

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    min_size     = var.min_size
    max_size     = var.max_size
    desired_size = var.desired_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = {
    "node-pool" = var.name
  }

  tags = {
    "Name" = "${var.name_prefix}-${var.name}"
  }

  lifecycle {
    create_before_destroy = true

    ignore_changes = [scaling_config[0].desired_size]
  }
}
