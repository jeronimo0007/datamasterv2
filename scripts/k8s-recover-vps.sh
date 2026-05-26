#!/usr/bin/env bash
# Recupera a stack no VPS quando so grafana/prometheus/redis sobem.
# Rode NO SERVIDOR:  bash scripts/k8s-recover-vps.sh
set -euo pipefail

REPO_DIR="${DEPLOY_DIR:-/home/servidor/kubernets/datamasterv2}"
cd "$REPO_DIR"

kubectl_cmd() { kubectl "$@" 2>/dev/null || sudo -n kubectl "$@"; }

echo "=== Diagnostico rapido ==="
kubectl_cmd get pods -n datamaster -o wide 2>/dev/null || echo "Namespace datamaster ausente?"
echo ""
sudo k3s ctr images ls 2>/dev/null | grep datamaster || echo "(nenhuma imagem datamaster no k3s)"
echo ""

if [[ -d .git ]]; then
  git fetch origin vps 2>/dev/null || true
  git reset --hard origin/vps 2>/dev/null || git pull origin vps || true
fi

export IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse HEAD 2>/dev/null || echo latest)}"
export GIT_REF=vps
export DEPLOY_DIR="$REPO_DIR"

echo "=== Deploy completo (build + import k3s + apply) tag=${IMAGE_TAG} ==="
bash "${REPO_DIR}/scripts/deploy-kubernetes-server.sh"

echo ""
echo "=== Status final ==="
kubectl_cmd get pods -n datamaster
