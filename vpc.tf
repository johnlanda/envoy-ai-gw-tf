module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Use only 2 AZs to minimize resources
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = slice(var.public_subnet_cidrs, 0, 2)
  private_subnets = slice(var.private_subnet_cidrs, 0, 2)

  # Enable public IP auto-assignment for public subnets
  map_public_ip_on_launch = true

  # Minimal NAT gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = true  # Use a single NAT gateway to reduce costs

  tags = var.tags
}
