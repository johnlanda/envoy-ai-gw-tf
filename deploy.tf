# Install Envoy Gateway CRDs
resource "helm_release" "envoy_gateway_crds" {
  name             = "envoy-gateway-crds"
  chart            = "oci://docker.io/envoyproxy/gateway-helm"
  version          = "v0.0.0-latest"
  namespace        = "envoy-gateway-system"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    module.eks,
    module.eks.eks_managed_node_groups
  ]
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

  depends_on = [
    helm_release.envoy_gateway_crds,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create GatewayClass
resource "kubectl_manifest" "gateway_class" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
YAML

  depends_on = [
    helm_release.envoy_ai_gateway,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create Gateway resource to expose the service
resource "kubectl_manifest" "gateway" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      port: 80
      protocol: HTTP
YAML

  depends_on = [
    kubectl_manifest.gateway_class,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create Backend for Bedrock
resource "kubectl_manifest" "bedrock_backend" {
  yaml_body = <<YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: bedrock-backend
  namespace: envoy-gateway-system
spec:
  endpoints:
    - fqdn:
        hostname: bedrock-runtime.${var.region}.amazonaws.com
        port: 443
YAML

  depends_on = [
    kubectl_manifest.gateway,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create BackendTLSPolicy for Bedrock
resource "kubectl_manifest" "bedrock_tls" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: bedrock-tls
  namespace: envoy-gateway-system
spec:
  targetRefs:
    - group: gateway.envoyproxy.io
      kind: Backend
      name: bedrock-backend
  validation:
    wellKnownCACertificates: System
    hostname: bedrock-runtime.${var.region}.amazonaws.com
YAML

  depends_on = [
    kubectl_manifest.bedrock_backend,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create BackendSecurityPolicy for AWS credentials
resource "kubectl_manifest" "aws_credentials" {
  yaml_body = <<YAML
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: BackendSecurityPolicy
metadata:
  name: aws-credentials
  namespace: envoy-gateway-system
spec:
  type: AWSCredentials
  awsCredentials:
    region: ${var.region}
    credentialsFile:
      secretRef:
        name: aws-credentials
        namespace: envoy-gateway-system
YAML

  depends_on = [
    kubectl_manifest.gateway,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create Secret for AWS credentials
resource "kubectl_manifest" "aws_credentials_secret" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: envoy-gateway-system
type: Opaque
data:
  credentials: ${base64encode(<<-EOT
    [default]
    aws_access_key_id = ${aws_iam_access_key.bedrock_access_key.id}
    aws_secret_access_key = ${aws_iam_access_key.bedrock_access_key.secret}
  EOT
  )}
YAML

  depends_on = [
    kubectl_manifest.gateway,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create AIServiceBackend for Bedrock
resource "kubectl_manifest" "bedrock_service" {
  yaml_body = <<YAML
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: bedrock-service
  namespace: envoy-gateway-system
spec:
  schema:
    name: AWSBedrock
  backendRef:
    name: bedrock-backend
    kind: Backend
    group: gateway.envoyproxy.io
  backendSecurityPolicyRef:
    name: aws-credentials
    kind: BackendSecurityPolicy
    group: aigateway.envoyproxy.io
YAML

  depends_on = [
    kubectl_manifest.bedrock_backend,
    kubectl_manifest.aws_credentials,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create AIGatewayRoute for Claude
resource "kubectl_manifest" "claude_route" {
  yaml_body = <<YAML
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIGatewayRoute
metadata:
  name: claude-route
  namespace: envoy-gateway-system
spec:
  schema:
    name: AWSBedrock
  targetRefs:
    - name: envoy-gateway
      kind: Gateway
      group: gateway.networking.k8s.io
  rules:
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: ${var.bedrock_models["claude"].model_id}
      backendRefs:
        - name: bedrock-service
YAML

  depends_on = [
    kubectl_manifest.bedrock_service,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}

# Create AIGatewayRoute for Llama
resource "kubectl_manifest" "llama_route" {
  yaml_body = <<YAML
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIGatewayRoute
metadata:
  name: llama-route
  namespace: envoy-gateway-system
spec:
  schema:
    name: AWSBedrock
  targetRefs:
    - name: envoy-gateway
      kind: Gateway
      group: gateway.networking.k8s.io
  rules:
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: ${var.bedrock_models["llama"].model_id}
      backendRefs:
        - name: bedrock-service
YAML

  depends_on = [
    kubectl_manifest.bedrock_service,
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}