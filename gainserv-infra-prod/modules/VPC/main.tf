terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  public_supernet = cidrsubnet(var.vpc_cidr, 6, 0)

  subnets = {
    for idx, az in var.azs : az => {
      public_cidr  = cidrsubnet(local.public_supernet, 2, idx)
      private_cidr = cidrsubnet(var.vpc_cidr, 4, idx + 1)
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "${var.name_prefix}-vpc"
  }
}

#internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.name_prefix}-igw"
  }
}

#public subnets - ALB and NAT gateways only
resource "aws_subnet" "public" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.public_cidr
  availability_zone = each.key

  tags = {
    "Name"                   = "${var.name_prefix}-public-subnet-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

#private subnets - EKS nodes and pods
resource "aws_subnet" "private" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.key

  tags = {
    "Name"                            = "${var.name_prefix}-private-subnet-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

#elastic IP for NAT gateways
resource "aws_eip" "nat" {
  for_each = local.subnets

  domain = "vpc"
  tags = {
    "Name" = "${var.name_prefix}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "main" {
  for_each = local.subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags = {
    "Name" = "${var.name_prefix}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

#public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    "Name" = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

#private route table per AZ - each AZ goes out through its own NAT
resource "aws_route_table" "private" {
  for_each = local.subnets

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = {
    "Name" = "${var.name_prefix}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = {
    "Name" = "${var.name_prefix}-s3-endpoint"
  }
}
