# Envoy AI Gateway Terraform Module

## Overview
This Terraform module sets up an EKS cluster with Envoy AI Gateway and integrates it with AWS Bedrock models. The module creates the necessary infrastructure and configurations to run the Envoy AI Gateway service with routes configured to send traffic to different Bedrock models based on the request path.

## Features
- EKS cluster setup with managed node groups
- Envoy AI Gateway deployment
- AWS Bedrock integration with multiple models
- Automatic route configuration for different models
- IAM roles and permissions for Bedrock access

## Usage

### Requirements
Install the required tools:
* `kubectl`
* `helm`
* `terraform`

### Configure Credentials
Ensure that you have either configured `~/.aws/credentials` or set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

If you have the aws CLI installed, you can test that your credentials are properly configured by running:

```bash
aws sts get-caller-identity
```

### Configuration
The module can be configured using the following variables in `terraform.tfvars`:

```hcl
region            = "us-west-2"
cluster_name      = "example-cluster"
cluster_version   = "1.24"
vpc_cidr          = "10.1.0.0/16"
public_subnet_cidrs = [
  "10.1.1.0/24",
  "10.1.2.0/24"
]
private_subnet_cidrs = [
  "10.1.3.0/24",
  "10.1.4.0/24"
]
node_groups = {
  default = {
    desired_capacity = 2
    max_capacity     = 3
    min_capacity     = 1
    instance_type    = "t3.medium"
  }
}
bedrock_models = {
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
tags = {
  Environment = "production"
  Project     = "envoy-ai-gateway"
}
```

### Execute Terraform

Initialize the terraform configuration:
```shell
terraform init
```

Plan the terraform deployment:
```shell
terraform plan
```

Apply the terraform configuration:
```shell
terraform apply
```

### Accessing the Envoy AI Gateway

Once deployed, you can access the different Bedrock models through the following endpoints:
- Claude: `http://<gateway-address>/claude`
- Llama: `http://<gateway-address>/llama`

Example request to Claude:
```json
{
  "prompt": "Hello, how are you?",
  "max_tokens": 100
}
```

### Clean Up
To destroy all resources created by this module:
```shell
terraform destroy
```

## Developers

### Updating the TF lock file

Run the following command to ensure all the supported platforms are included in the new lock file

```shell
terraform providers lock -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64 -platform=linux_amd64 -platform=linux_arm64
```
