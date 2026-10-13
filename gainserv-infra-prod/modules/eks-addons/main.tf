terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

locals {
  system_node_selector = {
    "node-pool" = var.system_node_pool
  }
}

#CoreDNS - needs nodes, so it's installed here (after node groups)
resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    nodeSelector = local.system_node_selector
  })
}

#metrics-server - CPU/memory metrics for the HPA
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server
  namespace  = "kube-system"

  values = [yamlencode({
    nodeSelector = local.system_node_selector
  })]
}

#AWS Load Balancer Controller - turns the app Ingress into an ALB
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_versions.aws_load_balancer_controller
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName  = var.cluster_name
    region       = var.aws_region
    vpcId        = var.vpc_id
    replicaCount = 2
    nodeSelector = local.system_node_selector
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.aws_load_balancer_controller_role_arn
      }
    }
  })]

  depends_on = [aws_eks_addon.coredns]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_versions.external_secrets
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    installCRDs  = true
    nodeSelector = local.system_node_selector
    webhook = {
      nodeSelector = local.system_node_selector
    }
    certController = {
      nodeSelector = local.system_node_selector
    }
  })]

  depends_on = [aws_eks_addon.coredns]
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.chart_versions.cluster_autoscaler
  namespace  = "kube-system"

  values = [yamlencode({
    cloudProvider = "aws"
    awsRegion     = var.aws_region
    autoDiscovery = {
      clusterName = var.cluster_name
    }
    nodeSelector = local.system_node_selector
    rbac = {
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
        }
      }
    }
    extraArgs = {
      expander                    = "priority" # try Spot first
      balance-similar-node-groups = true
      skip-nodes-with-system-pods = false # allow removing idle nodes (cost)
      max-node-provision-time     = "5m"
    }
    # higher number = tried first
    expanderPriorities = {
      50 = [".*${var.spot_node_pool}.*"]
      10 = [".*"]
    }
  })]

  depends_on = [aws_eks_addon.coredns]
}
