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

  postrender {
    binary_path = "${path.root}/postrender-envoy-ai-gateway.sh"
  }
}