output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat.public_ip
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  value = aws_eks_cluster.main.version
}

output "node_group" {
  value = {
    name    = aws_eks_node_group.default.node_group_name
    status  = aws_eks_node_group.default.status
    scaling = var.node_scaling
  }
}

output "kubeconfig_command" {
  description = "Point kubectl at the new cluster (real AWS)."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
