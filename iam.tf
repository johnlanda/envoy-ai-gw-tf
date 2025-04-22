# Create IAM role policy for EKS nodes
resource "aws_iam_role_policy" "eks_node_bedrock" {
  name = "${var.cluster_name}-eks-node-bedrock"
  role = module.eks.eks_managed_node_groups["default"].iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
