#!/usr/bin/env bash
# Configuracao inicial do servidor (rode UMA vez como root ou com sudo).
# Instala k3s, git, docker e clona o repositorio em /opt/datamaster.
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/datamaster}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/jeronimo0007/datamasterv2.git}"
GIT_REF="${GIT_REF:-main}"

if ! command -v curl >/dev/null 2>&1; then
  apt-get update && apt-get install -y curl git ca-certificates
fi

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

mkdir -p "$(dirname "$DEPLOY_DIR")"
if [[ ! -d "${DEPLOY_DIR}/.git" ]]; then
  git clone --branch "$GIT_REF" "$GIT_REPO_URL" "$DEPLOY_DIR"
fi

chmod +x "${DEPLOY_DIR}/scripts/deploy-kubernetes-server.sh"

echo "Bootstrap OK."
echo "Proximo passo: configure secrets no GitHub e rode o workflow deploy-kubernetes,"
echo "ou execute: DEPLOY_DIR=${DEPLOY_DIR} bash ${DEPLOY_DIR}/scripts/deploy-kubernetes-server.sh"
