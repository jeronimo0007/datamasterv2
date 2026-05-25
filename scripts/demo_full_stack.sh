#!/usr/bin/env bash
# Fluxo completo: stack Docker → JSON → batch MongoDB → Spark Bronze/Silver/Gold.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

wait_http() {
  local url="$1" label="$2" max="${3:-40}" sleep_s="${4:-3}"
  echo "==> Aguardando $label ($url)..."
  for i in $(seq 1 "$max"); do
    if curl -sf "$url" >/dev/null 2>&1; then
      echo "$label OK"
      return 0
    fi
    sleep "$sleep_s"
  done
  echo "$label não respondeu: $url" >&2
  return 1
}

echo "==> Subindo stack Docker (API, Spark, Jupyter, Kafka, MinIO, MongoDB…)..."
docker compose up -d --build

wait_http "http://localhost:8080/health" "API"

echo "==> Aguardando MongoDB..."
for i in $(seq 1 30); do
  if docker compose exec -T mongodb mongosh -u admin -p admin123 --authenticationDatabase admin \
    --quiet --eval "db.adminCommand('ping').ok" 2>/dev/null | grep -q 1; then
    echo "MongoDB OK"
    break
  fi
  sleep 2
  if [[ "$i" -eq 30 ]]; then
    echo "MongoDB não respondeu" >&2
    exit 1
  fi
done

echo "==> Aguardando Spark master..."
for i in $(seq 1 40); do
  if curl -sf http://localhost:18080 >/dev/null 2>&1; then
    echo "Spark master OK"
    break
  fi
  sleep 2
  if [[ "$i" -eq 40 ]]; then
    echo "Spark UI não respondeu em :18080" >&2
    exit 1
  fi
done

echo "==> Gerando data/transactions.json (500 transações)..."
docker compose exec -T data-console python3 /workspace/scripts/generate_data.py \
  -n 500 -o /workspace/data/transactions.json --fraud-rate 0.08

echo "==> Batch dataprep → MongoDB (perfis user_profiles)..."
docker compose --profile batch run --rm batch-prep

echo "==> Pipeline Spark (Bronze → Silver → Gold em data/lake/)..."
echo "    (modo local[*] no container — estável na demo Docker)"
docker compose --profile spark-run run --rm spark-job

echo ""
echo "==> Verificação do fluxo completo"
PROFILES=$(docker compose exec -T mongodb mongosh -u admin -p admin123 --authenticationDatabase admin \
  --quiet --eval "db.getSiblingDB('fraud_detection').user_profiles.countDocuments()" 2>/dev/null | tr -d '\r')
curl -sf "http://localhost:8080/api/v1/batch/profile-stats" | python3 -m json.tool 2>/dev/null || true

LAKE_OK=0
for layer in bronze silver gold; do
  if [[ -d "data/lake/$layer" ]] && [[ -n "$(ls -A "data/lake/$layer" 2>/dev/null)" ]]; then
    LAKE_OK=$((LAKE_OK + 1))
  fi
done
DQ=""
[[ -f data/lake/reports/dq_latest.json ]] && DQ="data/lake/reports/dq_latest.json"

echo "  MongoDB user_profiles: ${PROFILES:-?}"
echo "  Camadas lake (bronze/silver/gold com dados): ${LAKE_OK}/3"
echo "  Relatório DQ: ${DQ:-(ainda não gerado)}"

if [[ "${PROFILES:-0}" -lt 1 ]] || [[ "$LAKE_OK" -lt 3 ]]; then
  echo "Aviso: fluxo terminou mas alguma etapa pode estar incompleta — veja logs acima." >&2
fi

echo ""
echo "=== Stack pronta (fluxo completo) ==="
echo "  Portal:          http://localhost:8880"
echo "  Swagger API:     http://localhost:8080/swagger-ui.html"
echo "  Dashboard:       http://localhost:8501"
echo "  Console dados:   http://localhost:3333"
echo "  Spark UI:        http://localhost:18080"
echo "  Jupyter:         http://localhost:8888  (token: datamaster)"
echo "  Lake local:      data/lake/ (bronze, silver, gold, reports/dq_latest.json)"
echo ""
echo "Comando canônico: bash scripts/run_demo.sh"
