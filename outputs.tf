output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "The IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "The IDs of the private subnets."
  value       = module.vpc.private_subnets
}

output "cluster_id" {
  description = "The ID of the EKS cluster."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "The endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "kubernetes_config" {
  sensitive = true
  value = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "region" {
  description = "The AWS region where the cluster is deployed."
  value       = var.region
}

output "gateway_address" {
  description = "The address of the Envoy AI Gateway LoadBalancer."
  value       = "kubectl get svc -n envoy-gateway-system -l app.kubernetes.io/name=envoy,app.kubernetes.io/component=proxy -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
}

output "aws_access_key_id" {
  description = "The AWS access key ID for Bedrock access."
  value       = aws_iam_access_key.bedrock_access_key.id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "The AWS secret access key for Bedrock access."
  value       = aws_iam_access_key.bedrock_access_key.secret
  sensitive   = true
}