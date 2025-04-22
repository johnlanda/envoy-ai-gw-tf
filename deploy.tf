resource "helm_release" "envoy_ai_gateway" {
  name             = "aieg"
  chart            = "oci://docker.io/envoyproxy/ai-gateway-helm"
  version          = var.envoy_ai_gateway_config.version
  namespace        = var.envoy_ai_gateway_config.namespace
  create_namespace = true

  set {
    name  = "BEDROCK_REGION"
    value = var.region
  }

  depends_on = [module.eks]
}

resource "kubernetes_manifest" "gateway" {
  depends_on = [data.aws_eks_cluster_auth.cluster, helm_release.envoy_ai_gateway]

  manifest = {
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind = "EnvoyGateway"
    metadata = {
      name = "envoy-gateway"
      namespace = "envoy-gateway-system"
    }
    spec = {
      gateway = {
        controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
      }
      provider = {
        type = "kubernetes"
      }
      logging = {
        level = {
          default = "info"
        }
      }
      extensionApis = {
        enable = true
      }
      rateLimit = {
        backend = {
          type = "Redis"
          redis = {
            url = "redis-service.envoy-gateway-system:6379"
          }
        }
      }
      extensionServer = {
        port = 8080
        host = "0.0.0.0"
      }
      extensionFilters = [
        {
          name = "bedrock"
          type = "HTTP"
          config = {
            region = var.region
            models = values(var.bedrock_models)
          }
        }
      ]
    }
  }
}
