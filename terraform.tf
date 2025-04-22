terraform {
  required_version = "~>1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.94"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.3"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags = {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
