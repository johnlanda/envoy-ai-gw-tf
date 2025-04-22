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

# Create IAM user for Bedrock access
resource "aws_iam_user" "bedrock_user" {
  name = "${var.cluster_name}-bedrock-user"
  tags = var.tags
}

# Create IAM access key for the user
resource "aws_iam_access_key" "bedrock_access_key" {
  user = aws_iam_user.bedrock_user.name
}

# Create IAM policy for Bedrock access
resource "aws_iam_user_policy" "bedrock_policy" {
  name = "${var.cluster_name}-bedrock-policy"
  user = aws_iam_user.bedrock_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}
