# Install Envoy Gateway CRDs
resource "helm_release" "envoy_gateway_crds" {
  name             = "envoy-gateway-crds"
  chart            = "oci://docker.io/envoyproxy/gateway-helm"
  version          = "v0.1.5"
  namespace        = "envoy-gateway-system"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "envoy_ai_gateway" {
  name             = "aieg"
  chart            = "oci://docker.io/envoyproxy/ai-gateway-helm"
  version          = "v0.0.0-latest"
  namespace        = "envoy-gateway-system"
  create_namespace = true

  set {
    name  = "envoyGateway.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "envoyGateway.service.ports[0].name"
    value = "http"
  }

  set {
    name  = "envoyGateway.service.ports[0].port"
    value = "80"
  }

  set {
    name  = "envoyGateway.service.ports[0].targetPort"
    value = "8080"
  }

  depends_on = [helm_release.envoy_gateway_crds]
}

# Create GatewayClass
resource "kubernetes_manifest" "gateway_class" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "envoy-gateway"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  }

  depends_on = [helm_release.envoy_ai_gateway]
}

# Create Gateway resource to expose the service
resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "envoy-gateway"
      namespace = "envoy-gateway-system"
    }
    spec = {
      gatewayClassName = "envoy-gateway"
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gateway_class]
}

# Create Backend for Bedrock
resource "kubernetes_manifest" "bedrock_backend" {
  manifest = {
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "Backend"
    metadata = {
      name      = "bedrock-backend"
      namespace = "envoy-gateway-system"
    }
    spec = {
      endpoints = [
        {
          fqdn = {
            hostname = "bedrock-runtime.${var.region}.amazonaws.com"
            port     = 443
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}

# Create BackendTLSPolicy for Bedrock
resource "kubernetes_manifest" "bedrock_tls" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1alpha3"
    kind       = "BackendTLSPolicy"
    metadata = {
      name      = "bedrock-tls"
      namespace = "envoy-gateway-system"
    }
    spec = {
      targetRefs = [
        {
          group = "gateway.envoyproxy.io"
          kind  = "Backend"
          name  = "bedrock-backend"
        }
      ]
      validation = {
        wellKnownCACertificates = "System"
        hostname               = "bedrock-runtime.${var.region}.amazonaws.com"
      }
    }
  }

  depends_on = [kubernetes_manifest.bedrock_backend]
}

# Create BackendSecurityPolicy for AWS credentials
resource "kubernetes_manifest" "aws_credentials" {
  manifest = {
    apiVersion = "aigateway.envoyproxy.io/v1alpha1"
    kind       = "BackendSecurityPolicy"
    metadata = {
      name      = "aws-credentials"
      namespace = "envoy-gateway-system"
    }
    spec = {
      type = "AWSCredentials"
      awsCredentials = {
        region = var.region
        credentialsFile = {
          secretRef = {
            name      = "aws-credentials"
            namespace = "envoy-gateway-system"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}

# Create Secret for AWS credentials
resource "kubernetes_manifest" "aws_credentials_secret" {
  manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "aws-credentials"
      namespace = "envoy-gateway-system"
    }
    type = "Opaque"
    data = {
      credentials = base64encode(<<-EOT
        [default]
        aws_access_key_id = ${aws_iam_access_key.bedrock_access_key.id}
        aws_secret_access_key = ${aws_iam_access_key.bedrock_access_key.secret}
      EOT
      )
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}

# Create AIServiceBackend for Bedrock
resource "kubernetes_manifest" "bedrock_service" {
  manifest = {
    apiVersion = "aigateway.envoyproxy.io/v1alpha1"
    kind       = "AIServiceBackend"
    metadata = {
      name      = "bedrock-service"
      namespace = "envoy-gateway-system"
    }
    spec = {
      schema = {
        name = "AWSBedrock"
      }
      backendRef = {
        name  = "bedrock-backend"
        kind  = "Backend"
        group = "gateway.envoyproxy.io"
      }
      backendSecurityPolicyRef = {
        name  = "aws-credentials"
        kind  = "BackendSecurityPolicy"
        group = "aigateway.envoyproxy.io"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.bedrock_backend,
    kubernetes_manifest.aws_credentials
  ]
}

# Create AIGatewayRoute for Claude
resource "kubernetes_manifest" "claude_route" {
  manifest = {
    apiVersion = "aigateway.envoyproxy.io/v1alpha1"
    kind       = "AIGatewayRoute"
    metadata = {
      name      = "claude-route"
      namespace = "envoy-gateway-system"
    }
    spec = {
      schema = {
        name = "AWSBedrock"
      }
      targetRefs = [
        {
          name  = "envoy-gateway"
          kind  = "Gateway"
          group = "gateway.networking.k8s.io"
        }
      ]
      rules = [
        {
          matches = [
            {
              headers = [
                {
                  type  = "Exact"
                  name  = "x-ai-eg-model"
                  value = var.bedrock_models["claude"].model_id
                }
              ]
            }
          ]
          backendRefs = [
            {
              name = "bedrock-service"
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.bedrock_service]
}

# Create AIGatewayRoute for Llama
resource "kubernetes_manifest" "llama_route" {
  manifest = {
    apiVersion = "aigateway.envoyproxy.io/v1alpha1"
    kind       = "AIGatewayRoute"
    metadata = {
      name      = "llama-route"
      namespace = "envoy-gateway-system"
    }
    spec = {
      schema = {
        name = "AWSBedrock"
      }
      targetRefs = [
        {
          name  = "envoy-gateway"
          kind  = "Gateway"
          group = "gateway.networking.k8s.io"
        }
      ]
      rules = [
        {
          matches = [
            {
              headers = [
                {
                  type  = "Exact"
                  name  = "x-ai-eg-model"
                  value = var.bedrock_models["llama"].model_id
                }
              ]
            }
          ]
          backendRefs = [
            {
              name = "bedrock-service"
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.bedrock_service]
}