#!/usr/bin/env bash
# Configuracao inicial do servidor (rode UMA vez como root ou com sudo).
# Instala Docker + Compose, git e clona o repo. k3s e opcional (deploy usa Compose).
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/servidor/kubernets/datamasterv2}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/jeronimo0007/datamasterv2.git}"
GIT_REF="${GIT_REF:-vps}"

if ! command -v curl >/dev/null 2>&1; then
  apt-get update && apt-get install -y curl git ca-certificates
fi

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

mkdir -p "$(dirname "$DEPLOY_DIR")"
if [[ ! -d "${DEPLOY_DIR}/.git" ]]; then
  git clone --branch "$GIT_REF" "$GIT_REPO_URL" "$DEPLOY_DIR"
fi

chmod +x "${DEPLOY_DIR}/scripts/deploy-kubernetes-server.sh"

if ! docker compose version >/dev/null 2>&1; then
  echo "Instale o plugin docker compose (Docker CE recente ja inclui)."
fi

echo "Bootstrap OK."
echo "Opcional k3s: curl -sfL https://get.k3s.io | sh -"
echo "Deploy completo: DEPLOY_DIR=${DEPLOY_DIR} bash ${DEPLOY_DIR}/scripts/deploy-kubernetes-server.sh"
