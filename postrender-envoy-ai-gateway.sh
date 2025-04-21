#!/bin/bash

# This script installs the Envoy AI Gateway using Helm.
# Based on the documentation here: https://aigateway.envoyproxy.io/docs/getting-started/installation

# Handled by the helm provider
#helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
#    --version v0.0.0-latest \
#    --namespace envoy-ai-gateway-system \
#    --create-namespace

echo "Waiting for the Envoy AI Gateway Controller to become ready..."
kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available

# After installing Envoy AI Gateway, apply the AI Gateway-specific configuration to Envoy Gateway,
# restart the deployment, and wait for it to be ready.
echo "Applying AI Gateway configuration to Envoy Gateway..."
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-config/redis.yaml
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-config/rbac.yaml

# Apply the Bedrock configuration
echo "Applying Bedrock configuration..."
cat > /tmp/bedrock-config.yaml << EOF
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyGateway
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
spec:
  gateway:
    controllerName: gateway.envoyproxy.io/gatewayclass-controller
  provider:
    type: Kubernetes
  logging:
    level:
      default: info
  extensionApis:
    enable: true
  rateLimit:
    backend:
      type: Redis
      redis:
        url: redis-service.envoy-gateway-system:6379
  extensionServer:
    port: 8080
    host: 0.0.0.0
  extensionFilters:
    - name: bedrock
      type: HTTP
      config:
        region: ${BEDROCK_REGION}
        assumeRoleArn: ${BEDROCK_ASSUME_ROLE_ARN}
        models:
          - name: claude
            modelId: anthropic.claude-v2
            routePrefix: /claude
          - name: llama
            modelId: meta.llama2-13b-chat-v1
            routePrefix: /llama
EOF

kubectl apply -f /tmp/bedrock-config.yaml

echo "Restarting Envoy Gateway deployment to apply the new configuration..."
kubectl rollout restart -n envoy-gateway-system deployment/envoy-gateway

echo "Waiting for the Envoy Gateway deployment to become ready..."
kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

echo "Envoy AI Gateway installation and configuration complete."