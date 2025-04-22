variable "region" {
  description = "The AWS region to deploy the EKS cluster in."
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnets."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "bedrock_models" {
  description = "Configuration for Bedrock models to be used with Envoy AI Gateway."
  type = map(object({
    model_id     = string
    region       = string
    route_prefix = string
  }))
  default = {
    "claude" = {
      model_id     = "anthropic.claude-v2"
      region       = "us-west-2"
      route_prefix = "/claude"
    }
    "llama" = {
      model_id     = "meta.llama2-13b-chat-v1"
      region       = "us-west-2"
      route_prefix = "/llama"
    }
  }
}

variable "envoy_ai_gateway_config" {
  description = "Configuration for Envoy AI Gateway."
  type = object({
    namespace = string
  })
  default = {
    namespace = "envoy-ai-gateway-system"
  }
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default     = {}
}