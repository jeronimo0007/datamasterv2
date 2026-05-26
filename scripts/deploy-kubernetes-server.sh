#!/usr/bin/env bash
# Deploy DataMaster COMPLETO no VPS via Docker Compose (mesma stack do ambiente local).
# Executado pelo GitHub Actions (SSH) ou manualmente no servidor.
set -euo pipefail

REPO_DIR="${DEPLOY_DIR:-/home/servidor/kubernets/datamasterv2}"
GIT_REF="${GIT_REF:-vps}"
COMPOSE_FILES="-f docker-compose.yaml -f docker-compose.vps.yaml"

REPO_ABS="$(cd "$REPO_DIR" && pwd)"
cd "$REPO_ABS"

git config --global --add safe.directory "$REPO_ABS"

if [[ -d .git ]]; then
  git fetch origin "$GIT_REF"
  git reset --hard "origin/${GIT_REF}"
else
  echo "ERRO: $REPO_ABS nao e um repositorio git." >&2
  exit 1
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

# Kafka acessivel fora da rede Docker (opcional: export KAFKA_EXTERNAL_HOST no .env do VPS)
if [[ -z "${KAFKA_EXTERNAL_HOST:-}" ]]; then
  KAFKA_EXTERNAL_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  export KAFKA_EXTERNAL_HOST
fi

echo "==> Parar stack K8s minima (evita conflito de portas com Compose)"
if command -v kubectl >/dev/null 2>&1; then
  kubectl delete namespace datamaster --ignore-not-found=true --wait=false 2>/dev/null \
    || sudo -n kubectl delete namespace datamaster --ignore-not-found=true --wait=false 2>/dev/null \
    || true
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose (v2) nao encontrado. Instale Docker Compose plugin." >&2
  exit 1
fi

echo "==> Subir stack completa (Compose)"
# Sem profiles batch/spark-run — mesmo que 'docker compose up -d --build' local padrao
docker compose ${COMPOSE_FILES} up -d --build --remove-orphans

echo "==> Aguardar API (health)"
for i in $(seq 1 40); do
  if curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo "API OK"
    break
  fi
  if [[ "$i" -eq 40 ]]; then
    echo "AVISO: API ainda nao respondeu em :8080 — veja: docker compose logs api"
  fi
  sleep 3
done

echo ""
echo "==> Servicos (docker compose ps)"
docker compose ${COMPOSE_FILES} ps

echo ""
echo "Deploy Compose concluido (ref ${GIT_REF})."
echo "Portas no host:"
echo "  Portal      http://$(hostname -I | awk '{print $1}'):8880"
echo "  API         http://$(hostname -I | awk '{print $1}'):8080"
echo "  Dashboard   http://$(hostname -I | awk '{print $1}'):8501"
echo "  Console     http://$(hostname -I | awk '{print $1}'):3333"
echo "  Grafana     http://$(hostname -I | awk '{print $1}'):3000  (admin/admin)"
echo "  Prometheus  http://$(hostname -I | awk '{print $1}'):9090"
echo "  Spark UI    http://$(hostname -I | awk '{print $1}'):18080"
echo "  Jupyter     http://$(hostname -I | awk '{print $1}'):8888  (token: datamaster)"
echo "  MinIO       http://$(hostname -I | awk '{print $1}'):9001"
echo "  Kafka       $(hostname -I | awk '{print $1}'):9092"
