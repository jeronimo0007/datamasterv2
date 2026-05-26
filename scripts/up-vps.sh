#!/usr/bin/env bash
# Sobe a stack no VPS (overlay docker-compose.vps.yaml). Rode no servidor após git pull.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
COMPOSE_FILES="-f docker-compose.yaml -f docker-compose.vps.yaml"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [[ -z "${KAFKA_EXTERNAL_HOST:-}" ]]; then
  KAFKA_EXTERNAL_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  export KAFKA_EXTERNAL_HOST
  echo "KAFKA_EXTERNAL_HOST=${KAFKA_EXTERNAL_HOST} (defina no .env se precisar de Tailscale)"
fi

docker compose ${COMPOSE_FILES} up -d --build --remove-orphans
echo ""
echo "VPS: veja portas em docs/DEPLOY_VPS.md"
