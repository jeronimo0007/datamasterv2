#!/usr/bin/env bash
# Deploy DataMaster no Kubernetes do servidor (k3s/microk8s/k8s).
# Executado localmente ou via GitHub Actions (SSH).
set -euo pipefail

REPO_DIR="${DEPLOY_DIR:-/home/servidor/kubernets/datamasterv2}"
# Apos cd, REPO_ABS e usado no restante do script
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infrastructure/kubernetes/overlays/homelab}"
GIT_REF="${GIT_REF:-vps}"
IMAGE_TAG="${IMAGE_TAG:-}"

REPO_ABS="$(cd "$REPO_DIR" && pwd)"
cd "$REPO_ABS"

# SSH pode entrar como usuario diferente do dono da pasta (ex.: root vs servidor).
git config --global --add safe.directory "$REPO_ABS"

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

# kubeconfig do k3s (CI nao tem TTY para sudo pedir senha)
if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

kubectl_cmd() {
  if kubectl "$@" 2>/dev/null; then
    return 0
  fi
  if sudo -n kubectl "$@" 2>/dev/null; then
    return 0
  fi
  echo "ERRO: kubectl falhou. Rode no VPS (uma vez):" >&2
  echo "  sudo chmod 644 /etc/rancher/k3s/k3s.yaml" >&2
  echo "  ou: echo '\$USER ALL=(ALL) NOPASSWD: /usr/local/bin/kubectl, /usr/bin/kubectl' | sudo tee /etc/sudoers.d/k8s-deploy" >&2
  return 1
}

echo "==> Build imagens (tag: $IMAGE_TAG)"
docker build -t "datamaster-api:${IMAGE_TAG}" -t datamaster-api:latest ./api-java
docker build -f Dockerfile.dashboard -t "datamaster-dashboard:${IMAGE_TAG}" -t datamaster-dashboard:latest .
docker build -f portal/Dockerfile -t "datamaster-portal:${IMAGE_TAG}" -t datamaster-portal:latest .

import_image() {
  local img="$1"
  local imported=0

  if command -v k3s >/dev/null 2>&1; then
    if docker save "$img" | k3s ctr images import - 2>/dev/null; then
      imported=1
    elif docker save "$img" | sudo -n k3s ctr images import - 2>/dev/null; then
      imported=1
    fi
  elif command -v microk8s >/dev/null 2>&1; then
    if docker save "$img" | microk8s ctr image import - 2>/dev/null; then
      imported=1
    fi
  fi

  if [[ "$imported" -eq 1 ]]; then
    echo "    import OK: $img"
    return 0
  fi

  echo "ERRO: nao foi possivel importar $img no k3s (sudo pediu senha ou sem permissao)." >&2
  echo "No VPS, rode UMA vez como usuario do deploy ($(whoami)):" >&2
  echo "  K3S=\$(command -v k3s)" >&2
  echo "  echo \"\$(whoami) ALL=(ALL) NOPASSWD: \${K3S} ctr\" | sudo tee /etc/sudoers.d/k3s-datamaster" >&2
  echo "  sudo chmod 440 /etc/sudoers.d/k3s-datamaster" >&2
  return 1
}

echo "==> Importar imagens no containerd do cluster"
import_image "datamaster-api:${IMAGE_TAG}"
import_image "datamaster-dashboard:${IMAGE_TAG}"
import_image "datamaster-portal:${IMAGE_TAG}"

OVERLAY_PATH="${REPO_ABS}/${KUSTOMIZE_OVERLAY}/kustomization.yaml"
if [[ ! -f "$OVERLAY_PATH" ]]; then
  echo "ERRO: overlay nao encontrado: $OVERLAY_PATH" >&2
  exit 1
fi

# Tags efemeras so para este apply (git reset restaura o arquivo no proximo deploy).
cp "$OVERLAY_PATH" "${OVERLAY_PATH}.bak"
trap 'mv -f "${OVERLAY_PATH}.bak" "$OVERLAY_PATH"' EXIT

sed -i "s/newTag: .*/newTag: ${IMAGE_TAG}/" "$OVERLAY_PATH" 2>/dev/null || \
  sed -i '' "s/newTag: .*/newTag: ${IMAGE_TAG}/" "$OVERLAY_PATH"

# Kustomize nao permite arquivos fora de base/ — sincroniza init do Mongo
INIT_SRC="${REPO_ABS}/scripts/init_mongo.js"
INIT_DST="${REPO_ABS}/infrastructure/kubernetes/base/config/init_mongo.js"
if [[ -f "$INIT_SRC" ]]; then
  cp "$INIT_SRC" "$INIT_DST"
fi

echo "==> kubectl apply -k ${KUSTOMIZE_OVERLAY}"
kubectl_cmd apply -k "${REPO_ABS}/${KUSTOMIZE_OVERLAY}"

echo "==> Reiniciar deployments"
kubectl_cmd rollout restart deployment/api deployment/dashboard deployment/portal -n datamaster
kubectl_cmd rollout status deployment/api -n datamaster --timeout=180s
kubectl_cmd rollout status deployment/dashboard -n datamaster --timeout=180s
kubectl_cmd rollout status deployment/portal -n datamaster --timeout=180s

echo ""
echo "Deploy concluido (tag ${IMAGE_TAG})."
kubectl_cmd get svc -n datamaster
