module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.36"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnet_ids      = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

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