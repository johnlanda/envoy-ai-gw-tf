provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Use only 2 AZs to minimize resources
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = slice(var.public_subnet_cidrs, 0, 2)
  private_subnets = slice(var.private_subnet_cidrs, 0, 2)

  # Minimal NAT gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = true  # Use a single NAT gateway to reduce costs

  tags = var.tags
}

data "aws_availability_zones" "available" {}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.0"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  # Minimal node group configuration
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 2
      desired_size = 1
      instance_types = ["t3.medium"]
    }
  }

  tags = var.tags
}

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

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "helm_release" "envoy_ai_gateway" {
  name       = "aieg"
  chart      = "oci://docker.io/envoyproxy/ai-gateway-helm"
  version    = var.envoy_ai_gateway_config.version
  namespace  = var.envoy_ai_gateway_config.namespace
  create_namespace = true

  set {
    name  = "BEDROCK_REGION"
    value = var.region
  }

  depends_on = [module.eks]

  postrender {
    binary_path = "${path.module}/postrender-envoy-ai-gateway.sh"
  }
}