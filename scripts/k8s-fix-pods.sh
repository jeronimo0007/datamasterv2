#!/usr/bin/env bash
# Corrige ErrImageNeverPull / ImagePullBackOff nas apps custom.
# Uso no VPS:
#   export IMAGE_TAG=<sha do ultimo deploy>
#   bash scripts/k8s-import-app-images.sh   # se ainda nao importou
#   bash scripts/k8s-fix-pods.sh
set -euo pipefail

REPO_DIR="${DEPLOY_DIR:-/home/servidor/kubernets/datamasterv2}"
cd "$REPO_DIR"
IMAGE_TAG="${IMAGE_TAG:?Defina IMAGE_TAG (commit SHA do ultimo build)}"

kubectl_cmd() { kubectl "$@" 2>/dev/null || sudo -n kubectl "$@"; }

if [[ -x "${REPO_DIR}/scripts/k3s-import-app-images.sh" ]]; then
  IMAGE_TAG="${IMAGE_TAG}" bash "${REPO_DIR}/scripts/k3s-import-app-images.sh"
fi

fix() {
  local dep="$1" short="$2"
  local ref="docker.io/library/${short}"
  kubectl_cmd set image "deployment/${dep}" -n datamaster "${dep}=${ref}:${IMAGE_TAG}"
  kubectl_cmd patch deployment "$dep" -n datamaster --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
}

fix api datamaster-api
fix dashboard datamaster-dashboard
fix portal datamaster-portal
fix data-console datamaster-data-console

kubectl_cmd rollout status deployment/api -n datamaster --timeout=180s || true
kubectl_cmd get pods -n datamaster
