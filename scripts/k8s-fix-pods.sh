#!/usr/bin/env bash
# Corrige ImagePullBackOff sem rebuild: usa imagem local importada no k3s.
# Uso no VPS: IMAGE_TAG=<sha-do-ultimo-deploy> bash scripts/k8s-fix-pods.sh
set -euo pipefail
IMAGE_TAG="${IMAGE_TAG:-latest}"

kubectl_cmd() { kubectl "$@" 2>/dev/null || sudo -n kubectl "$@"; }

fix() {
  local dep="$1" img="$2"
  kubectl_cmd set image "deployment/${dep}" -n datamaster "${dep}=${img}:${IMAGE_TAG}"
  kubectl_cmd patch deployment "$dep" -n datamaster --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"}]'
}

fix api datamaster-api
fix dashboard datamaster-dashboard
fix portal datamaster-portal
fix data-console datamaster-data-console

kubectl_cmd rollout restart deployment/kafka deployment/jupyter -n datamaster
kubectl_cmd rollout status deployment/api -n datamaster --timeout=180s || true
kubectl_cmd get pods -n datamaster
