#!/bin/bash
# ============================================================
# Script de Demonstracao - Sistema de Deteccao de Fraudes
# Use este script durante a apresentacao na banca
# ============================================================

set -e

# Sem pausas: DEMO_NONINTERACTIVE=1 bash scripts/demo.sh  OU  bash scripts/demo.sh --auto
if [ "${1:-}" = "--auto" ]; then
    export DEMO_NONINTERACTIVE=1
    shift
fi

API_URL="${API_URL:-http://localhost:8080}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Sistema de Deteccao de Fraudes Bancarias - Demo${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Funcao para pausar entre demos (desliga com DEMO_NONINTERACTIVE=1 ou --auto)
pause() {
    if [ -n "${DEMO_NONINTERACTIVE:-}" ] || [ -n "${CI:-}" ]; then
        return 0
    fi
    echo ""
    echo -e "${YELLOW}[Pressione ENTER para continuar...]${NC}"
    read -r
}

# 1. Health Check
echo -e "${GREEN}>>> DEMO 1: Verificando saude do sistema${NC}"
echo "curl -s ${API_URL}/health | python3 -m json.tool"
curl -s "${API_URL}/health" | python3 -m json.tool
pause

# 2. Gerar dados de teste
echo -e "${GREEN}>>> DEMO 2: Gerando dados de teste${NC}"
echo "python3 scripts/generate_data.py -n 100 -o data/transactions.json"
python3 scripts/generate_data.py -n 100 -o data/transactions.json
echo ""
echo "Resumo dos dados gerados:"
python3 -c "
import json
data = json.load(open('data/transactions.json'))
frauds = sum(1 for t in data if t['is_fraud'])
print(f'  Total de transacoes: {len(data)}')
print(f'  Transacoes fraudulentas: {frauds}')
print(f'  Transacoes legitimas: {len(data) - frauds}')
print(f'  Taxa de fraude: {frauds/len(data):.1%}')
print()
print('Exemplo de transacao:')
print(json.dumps(data[0], indent=2, ensure_ascii=False))
"
pause

# 3. Transacao normal (baixo risco)
echo -e "${GREEN}>>> DEMO 3: Analisando transacao NORMAL (baixo risco)${NC}"
echo "Cenario: PIX de R\$150 em alimentacao, mesmo pais, horario comercial"
echo ""
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
  }' | python3 -m json.tool
pause

# 4. Transacao suspeita (alto risco)
echo -e "${RED}>>> DEMO 4: Analisando transacao SUSPEITA (alto risco)${NC}"
echo "Cenario: Cartao de credito, R\$45.000 em eletronicos, internacional, madrugada, fim de semana"
echo ""
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
  }' | python3 -m json.tool
pause

# 5. Transacao de risco medio
echo -e "${YELLOW}>>> DEMO 5: Analisando transacao de RISCO MEDIO${NC}"
echo "Cenario: Cartao de debito, R\$3.000 em viagem, internacional, horario noturno"
echo ""
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
  }' | python3 -m json.tool
pause

# 6. Processar lote
echo -e "${GREEN}>>> DEMO 6: Processando lote de transacoes${NC}"
echo "Enviando as 100 transacoes geradas para analise em lote..."
echo ""
# Transformar para o formato esperado pela API
python3 -c "
import json, requests
from datetime import datetime
data = json.load(open('data/transactions.json'))
batch = []
for t in data[:20]:
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
        'user_id': t['user_id']
    })
resp = requests.post('${API_URL}/api/v1/transactions/batch', json=batch, timeout=30)
result = resp.json()
print(f'Total analisadas: {result[\"total_analyzed\"]}')
print(f'Fraudes detectadas: {result[\"total_frauds_detected\"]}')
print(f'Taxa de fraude: {result[\"fraud_rate\"]:.1%}')
"
pause

# 7. Metricas do modelo
echo -e "${GREEN}>>> DEMO 7: Metricas do modelo de ML${NC}"
echo "curl -s ${API_URL}/api/v1/model/metrics | python3 -m json.tool"
curl -s "${API_URL}/api/v1/model/metrics" | python3 -m json.tool
pause

# 8. Feature importance
echo -e "${GREEN}>>> DEMO 8: Importancia das features${NC}"
echo "curl -s ${API_URL}/api/v1/model/feature-importance | python3 -m json.tool"
curl -s "${API_URL}/api/v1/model/feature-importance" | python3 -m json.tool
pause

# 9. Data Quality
echo -e "${GREEN}>>> DEMO 9: Relatorio de Data Quality${NC}"
echo "curl -s ${API_URL}/api/v1/data-quality/report | python3 -m json.tool"
curl -s "${API_URL}/api/v1/data-quality/report" | python3 -m json.tool
pause

# 10. Mascaramento LGPD
echo -e "${GREEN}>>> DEMO 10: Mascaramento de dados LGPD${NC}"
echo "Demonstrando mascaramento de dados pessoais..."
echo ""
curl -s -X POST "${API_URL}/api/v1/lgpd/mask" \
  -H "Content-Type: application/json" \
  -d '{
    "cpf": "123.456.789-00",
    "email": "joao.silva@banco.com.br",
    "phone": "(11) 98765-4321",
    "name": "Joao Silva Santos",
    "card_number": "1234 5678 9012 3456",
    "amount": 1500.00
  }' | python3 -m json.tool
pause

# 11. Metricas do sistema
echo -e "${GREEN}>>> DEMO 11: Metricas do sistema${NC}"
echo "curl -s ${API_URL}/api/v1/metrics | python3 -m json.tool"
curl -s "${API_URL}/api/v1/metrics" | python3 -m json.tool
pause

# 12. Alertas
echo -e "${GREEN}>>> DEMO 12: Alertas de fraude${NC}"
echo "curl -s ${API_URL}/api/v1/alerts | python3 -m json.tool"
curl -s "${API_URL}/api/v1/alerts" | python3 -m json.tool

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Demo concluida!${NC}"
echo -e "${BLUE}  Dashboard Streamlit: rode na RAIZ do projeto (outro terminal):${NC}"
echo -e "${BLUE}    source .venv/bin/activate && PYTHONPATH=. streamlit run src/dashboard/app.py --server.port 8501${NC}"
echo -e "${BLUE}  Depois abra: http://localhost:8501  |  Ou: docker compose up dashboard${NC}"
echo -e "${BLUE}  API Swagger em: http://localhost:8080/swagger-ui.html${NC}"
echo -e "${BLUE}============================================================${NC}"
