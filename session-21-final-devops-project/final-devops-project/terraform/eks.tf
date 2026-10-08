resource "aws_eks_cluster" "main" {
  name     = "${var.name}-eks"
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat([for s in aws_subnet.private : s.id], [for s in aws_subnet.public : s.id])
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.api_allowed_cidrs
  }

  access_config {
    authentication_mode = "API" # EKS access entries instead of the aws-auth ConfigMap
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# worker nodes live in the private subnets and reach the internet through the NAT gateway
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_scaling.min
    desired_size = var.node_scaling.desired
    max_size     = var.node_scaling.max
  }

  update_config {
    max_unavailable = 1
  }

  labels = { workload = "general" }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_route_table_association.private,
  ]
}
