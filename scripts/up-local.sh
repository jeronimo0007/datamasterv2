#!/usr/bin/env bash
# Sobe a stack local (sem overlay VPS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [[ ! -f .env ]] && [[ -f .env.example ]]; then
  echo "Dica: cp .env.example .env e configure DEEPSEEK_API_KEY / DOCKER_HOST_WORKSPACE (Mac)"
fi

docker compose up -d --build --remove-orphans
echo ""
echo "Local: http://localhost:8880 (portal) | API :8080 | docs/AMBIENTE_LOCAL.md"
