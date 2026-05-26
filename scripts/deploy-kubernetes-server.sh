#!/usr/bin/env bash
# Deploy DataMaster no Kubernetes do servidor (k3s/microk8s/k8s).
# Executado localmente ou via GitHub Actions (SSH).
set -euo pipefail

REPO_DIR="${DEPLOY_DIR:-/opt/datamaster}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infrastructure/kubernetes/overlays/homelab}"
GIT_REF="${GIT_REF:-main}"
IMAGE_TAG="${IMAGE_TAG:-}"

cd "$REPO_DIR"

if [[ -d .git ]]; then
  git fetch origin "$GIT_REF"
  git reset --hard "origin/${GIT_REF}"
else
  echo "ERRO: $REPO_DIR nao e um repositorio git." >&2
  exit 1
fi

if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="$(git rev-parse --short HEAD)"
fi

echo "==> Build imagens (tag: $IMAGE_TAG)"
docker build -t "datamaster-api:${IMAGE_TAG}" -t datamaster-api:latest ./api-java
docker build -f Dockerfile.dashboard -t "datamaster-dashboard:${IMAGE_TAG}" -t datamaster-dashboard:latest .
docker build -f portal/Dockerfile -t "datamaster-portal:${IMAGE_TAG}" -t datamaster-portal:latest .

import_image() {
  local img="$1"
  if command -v k3s >/dev/null 2>&1; then
    docker save "$img" | sudo k3s ctr images import -
  elif command -v microk8s >/dev/null 2>&1; then
    docker save "$img" | microk8s ctr image import -
  else
    echo "    (sem k3s/microk8s: use registry ou cluster com acesso ao Docker local)"
  fi
}

echo "==> Importar imagens no containerd do cluster (se aplicavel)"
import_image "datamaster-api:${IMAGE_TAG}"
import_image "datamaster-dashboard:${IMAGE_TAG}"
import_image "datamaster-portal:${IMAGE_TAG}"

OVERLAY_PATH="${REPO_DIR}/${KUSTOMIZE_OVERLAY}/kustomization.yaml"
if [[ ! -f "$OVERLAY_PATH" ]]; then
  echo "ERRO: overlay nao encontrado: $OVERLAY_PATH" >&2
  exit 1
fi

# Tags efemeras so para este apply (git reset restaura o arquivo no proximo deploy).
cp "$OVERLAY_PATH" "${OVERLAY_PATH}.bak"
trap 'mv -f "${OVERLAY_PATH}.bak" "$OVERLAY_PATH"' EXIT

sed -i "s/newTag: .*/newTag: ${IMAGE_TAG}/" "$OVERLAY_PATH" 2>/dev/null || \
  sed -i '' "s/newTag: .*/newTag: ${IMAGE_TAG}/" "$OVERLAY_PATH"

echo "==> kubectl apply -k ${KUSTOMIZE_OVERLAY}"
kubectl apply -k "${REPO_DIR}/${KUSTOMIZE_OVERLAY}"

echo "==> Reiniciar deployments"
kubectl rollout restart deployment/api deployment/dashboard deployment/portal -n datamaster
kubectl rollout status deployment/api -n datamaster --timeout=180s
kubectl rollout status deployment/dashboard -n datamaster --timeout=180s
kubectl rollout status deployment/portal -n datamaster --timeout=180s

echo ""
echo "Deploy concluido (tag ${IMAGE_TAG})."
kubectl get svc -n datamaster
