#!/usr/bin/env bash
# ============================================================
# Demo automatica em ciclos (sem interacao) — alimenta a API
# Uso:
#   API_URL=http://localhost:8000 bash scripts/demo_loop.sh
#   API_URL=http://localhost:8000 bash scripts/demo_loop.sh 60      # a cada 60 s, sem fim
#   API_URL=http://localhost:8000 bash scripts/demo_loop.sh 60 10   # a cada 60 s, 10 ciclos
#
# Variaveis opcionais:
#   GENERATE_N=80   tamanho do lote JSON a cada ciclo
#   BATCH_SLICE=20  quantas linhas do JSON enviar no /batch
# ============================================================
# Este arquivo NAO usa demo.sh e NAO pede ENTER.
# Se aparecer "Pressione ENTER", voce esta em outro script
# (ex.: demo.sh). Use: ./scripts/demo_loop.sh ou bash scripts/demo_loop.sh
# ============================================================

set -u

# Nenhum subshell deve esperar tecla; evita read acidental no stdin do terminal
exec </dev/null

API_URL="${API_URL:-http://localhost:8080}"
INTERVAL_SEC="${1:-60}"
MAX_CYCLES="${2:-0}"
GENERATE_N="${GENERATE_N:-80}"
BATCH_SLICE="${BATCH_SLICE:-20}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

run_one_cycle() {
  local c="$1"
  echo -e "${GREEN}--- Ciclo ${c} | $(date '+%Y-%m-%d %H:%M:%S') ---${NC}"

  if ! curl -sf "${API_URL}/health" -o /dev/null; then
    echo "API indisponivel em ${API_URL} (health falhou). Pulando ciclo."
    return 1
  fi

  python3 scripts/generate_data.py -n "${GENERATE_N}" -o data/transactions.json

  curl -s -X POST "${API_URL}/api/v1/transactions/analyze" \
    -H "Content-Type: application/json" \
    -d '{
    "amount": 150.00,
    "merchant_category": "Alimentacao",
    "user_country": "BR",
    "merchant_country": "BR",
    "payment_method": "PIX",
    "hour": 14,
    "is_weekend": 0,
    "is_international": 0
  }' -o /dev/null

  curl -s -X POST "${API_URL}/api/v1/transactions/analyze" \
    -H "Content-Type: application/json" \
    -d '{
    "amount": 45000.00,
    "merchant_category": "Eletronicos",
    "user_country": "BR",
    "merchant_country": "US",
    "payment_method": "CREDIT_CARD",
    "hour": 3,
    "is_weekend": 1,
    "is_international": 1
  }' -o /dev/null

  curl -s -X POST "${API_URL}/api/v1/transactions/analyze" \
    -H "Content-Type: application/json" \
    -d '{
    "amount": 3000.00,
    "merchant_category": "Viagem",
    "user_country": "BR",
    "merchant_country": "FR",
    "payment_method": "DEBIT_CARD",
    "hour": 22,
    "is_weekend": 0,
    "is_international": 1
  }' -o /dev/null

  python3 -c "
import json, requests
from datetime import datetime

api = '${API_URL}'
n = int('${BATCH_SLICE}')
data = json.load(open('data/transactions.json'))
batch = []
for t in data[:n]:
    ts = t.get('timestamp', '')
    try:
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        hour = dt.hour
        is_weekend = 1 if dt.weekday() >= 5 else 0
    except Exception:
        hour, is_weekend = 12, 0
    batch.append({
        'amount': t['amount'],
        'merchant_category': t['merchant_category'],
        'payment_method': t['payment_method'],
        'user_country': t['user_country'],
        'merchant_country': t['merchant_country'],
        'hour': hour,
        'is_weekend': is_weekend,
        'is_international': 1 if t['user_country'] != t['merchant_country'] else 0,
        'transaction_id': t['transaction_id'],
        'user_id': t['user_id'],
    })
r = requests.post(f'{api}/api/v1/transactions/batch', json=batch, timeout=120)
r.raise_for_status()
out = r.json()
print(f\"  batch: analisadas={out['total_analyzed']} fraudes={out['total_frauds_detected']} taxa={out['fraud_rate']:.1%}\")
"

  echo -e "${BLUE}  Resumo dashboard:${NC}"
  python3 -c "
import json, urllib.request
u = '${API_URL}/api/v1/dashboard/summary'
with urllib.request.urlopen(u, timeout=10) as r:
    s = json.load(r)
kp = s.get('kpis', {})
print(f\"  total_tx={kp.get('total_transactions', 0)} fraudes={kp.get('total_frauds', 0)} taxa={kp.get('fraud_rate', 0):.1%}\")
"
}

echo -e "${BLUE}Demo em loop | API=${API_URL} | intervalo=${INTERVAL_SEC}s | max_ciclos=${MAX_CYCLES:-infinito}${NC}"
echo "Ctrl+C para parar."
echo ""

cycle=0
while true; do
  cycle=$((cycle + 1))
  run_one_cycle "${cycle}" || true
  if [ "${MAX_CYCLES}" -gt 0 ] && [ "${cycle}" -ge "${MAX_CYCLES}" ]; then
    echo -e "${GREEN}Encerrado apos ${MAX_CYCLES} ciclo(s).${NC}"
    break
  fi
  echo -e "${YELLOW}Proximo ciclo em ${INTERVAL_SEC}s...${NC}"
  sleep "${INTERVAL_SEC}"
done
