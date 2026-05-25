#!/usr/bin/env bash
# Aplica schema + dados demo no Postgres (útil se o volume já existia antes do schema.sql).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONTAINER="${POSTGRES_CONTAINER:-postgres}"
DB="${POSTGRES_DB:-fraud_detection}"
USER="${POSTGRES_USER:-admin}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Container '$CONTAINER' não está rodando. Suba: docker compose up -d postgres" >&2
  exit 1
fi

echo "==> Aplicando schema..."
docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" < sql/schema.sql

echo "==> Inserindo dados demo..."
docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" < sql/seed_demo.sql

echo ""
echo "✅ Postgres pronto para inspeção:"
echo "   docker exec -it $CONTAINER psql -U $USER -d $DB"
echo "   \\dt"
echo "   SELECT transaction_id, user_id, amount, fraud_score, is_fraud FROM transactions;"
echo "   SELECT transaction_id, severity, status FROM fraud_alerts;"
