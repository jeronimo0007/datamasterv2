"""
Adaptadores de fonte de dados -> formato canonico para o modelo (`FraudDetectionModel.predict`).

Hoje no projeto:
- **Entrada em tempo real:** HTTP POST na API (`src/api/main.py`) — o corpo JSON ja esta no formato esperado.
- **Armazenamento na demo:** listas em memoria `transactions_store` e `alerts_store` na API (nao persistem apos restart).
- **Modelo treinado:** arquivo `models/fraud_model.pkl` no disco.
- **Dados simulados em lote:** `scripts/generate_data.py` grava JSON com formato proprio (inclui `timestamp`, `is_fraud`, categorias com acento).
- **Producao (nuvem):** `src/data_storage/datalake_client.py` envia bytes ao lake; pastas **bronze/silver/gold** padronizadas em `src/data_architecture/medallion.py`.

Para **outra fonte** (SQL, CSV, S3, Mongo, Event Hub, Kafka), o padrao e:
1. Ler o registro bruto.
2. Chamar um adaptador abaixo para obter o **dict canonico** (mesmas chaves que a API usa).
3. Opcional: `model.predict(normalized)` ou POST para a API.
4. Persistir: Lake (parquet/jsonl), OLTP, ou fila — conforme o desenho Medallion.

Campos minimos para o modelo (ver `FraudDetectionModel.predict`):
`amount`, `hour`, `is_weekend`, `is_international`, `merchant_category`, `payment_method`.
"""

from __future__ import annotations

import json
import unicodedata
from datetime import datetime
from typing import Any, Dict, List, Optional

# Categorias do simulador (com acento) -> nomes proximos do contrato da API / treino
_MERCHANT_CATEGORY_MAP = {
    "Eletrônicos": "Eletronicos",
    "Alimentação": "Alimentacao",
    "Vestuário": "Vestuario",
    "Serviços": "Servicos",
    "Viagem": "Viagem",
    "Entretenimento": "Entretenimento",
}


def _parse_hour_from_timestamp(ts: str) -> int:
    """Extrai hora 0-23 de ISO8601 simples."""
    try:
        if "T" in ts:
            part = ts.split("T")[1]
            return int(part.split(":")[0])
    except (ValueError, IndexError):
        pass
    return 12


def _is_weekend_from_timestamp(ts: str) -> int:
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        # weekday(): seg=0 ... dom=6; fim de semana 5,6
        return 1 if dt.weekday() >= 5 else 0
    except ValueError:
        return 0


def from_api_body(body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Payload ja no formato da API (`TransactionInput`). Ap apenas garante defaults.
    """
    hour = body.get("hour")
    if hour is None:
        hour = 12
    is_weekend = body.get("is_weekend")
    if is_weekend is None:
        is_weekend = 0
    is_international = body.get("is_international")
    if is_international is None:
        uc = body.get("user_country", "BR")
        mc = body.get("merchant_country", "BR")
        is_international = int(uc != mc)
    return {
        "amount": float(body["amount"]),
        "merchant_category": str(body.get("merchant_category", "Outros")),
        "payment_method": str(body.get("payment_method", "PIX")),
        "hour": int(hour),
        "is_weekend": int(is_weekend),
        "is_international": int(is_international),
    }


def from_simulator_record(row: Dict[str, Any]) -> Dict[str, Any]:
    """
    Uma linha do JSON gerado por `scripts/generate_data.py`.

    Nao repasse `is_fraud` para o modelo em producao (vazamento de rotulo);
    aqui so montamos features para scoring.
    """
    ts = row.get("timestamp") or ""
    cat_raw = str(row.get("merchant_category", "Outros"))
    merchant_category = _MERCHANT_CATEGORY_MAP.get(cat_raw, cat_raw)
    # remove acentos residuais para alinhar ao vocabulario do modelo
    merchant_category = "".join(
        c
        for c in unicodedata.normalize("NFD", merchant_category)
        if unicodedata.category(c) != "Mn"
    )

    user_country = row.get("user_country", "BR")
    merchant_country = row.get("merchant_country", "BR")

    return {
        "amount": float(row.get("amount", 0)),
        "merchant_category": merchant_category,
        "payment_method": str(row.get("payment_method", "PIX")),
        "hour": _parse_hour_from_timestamp(ts),
        "is_weekend": _is_weekend_from_timestamp(ts),
        "is_international": int(user_country != merchant_country),
    }


def from_event_or_queue_message(payload: str | bytes | Dict[str, Any]) -> Dict[str, Any]:
    """
    Mensagem de Event Hubs / Kafka: corpo JSON com mesmo layout do simulador
    ou do canal core banking (ajuste mapeamento conforme contrato real).

    Se o core enviar outros nomes de coluna, crie um `from_core_banking_row` dedicado.
    """
    if isinstance(payload, dict):
        data = payload
    else:
        if isinstance(payload, bytes):
            payload = payload.decode("utf-8")
        data = json.loads(payload)

    # Heuristica: se tiver `timestamp` como no simulador, trata como simulator;
    # senao assume payload ja “flat” tipo API.
    if "timestamp" in data and "merchant_category" in data:
        return from_simulator_record(data)
    return from_api_body(data)


def from_csv_row(row: Dict[str, str]) -> Dict[str, Any]:
    """
    Exemplo: leitor CSV entregou dict com chaves do arquivo (`vlr`, `cat`, ...).
    Troque os nomes pelos campos reais do seu fornecedor.
    """
    return {
        "amount": float(row.get("vlr_transacao") or row.get("amount", 0)),
        "merchant_category": str(row.get("categoria") or row.get("merchant_category", "Outros")),
        "payment_method": str(row.get("meio_pagamento") or row.get("payment_method", "PIX")),
        "hour": int(row.get("hora", 12)),
        "is_weekend": int(row.get("fim_semana", 0)),
        "is_international": int(row.get("internacional", 0)),
    }


def normalize_for_model(raw: Dict[str, Any], source: str = "auto") -> Dict[str, Any]:
    """
    Despacha para o adaptador certo.

    source:
        - "api" — corpo do POST atual
        - "simulator" — linha `generate_data`
        - "event" — JSON de fila / Event Hub
        - "csv" — dict de CSV renomeado
        - "auto" — tenta inferir pela presenca de `timestamp` (simulador)
    """
    if source == "api":
        return from_api_body(raw)
    if source == "simulator":
        return from_simulator_record(raw)
    if source == "csv":
        return from_csv_row({k: str(v) for k, v in raw.items()})
    if source == "event":
        return from_event_or_queue_message(raw)

    if source == "auto":
        if "timestamp" in raw and "transaction_id" in raw:
            return from_simulator_record(raw)
        return from_api_body(raw)

    raise ValueError(f"source desconhecido: {source}")


def load_simulator_file(path: str) -> List[Dict[str, Any]]:
    """Carrega lista de transacoes do JSON do simulador e normaliza todas."""
    with open(path, encoding="utf-8") as f:
        rows = json.load(f)
    return [normalize_for_model(r, source="simulator") for r in rows]


# ----- Exemplos de persistencia (colar no consumer / job batch) -----


def example_persist_jsonl_local(normalized: Dict[str, Any], path: str) -> None:
    """Landing local estilo Bronze: uma linha JSON por evento (demo sem Azure)."""
    import json as _json
    from pathlib import Path

    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(_json.dumps(normalized, ensure_ascii=False) + "\n")


# from src.data_storage.datalake_client import DataLakeClient
# dl = DataLakeClient("minhaconta", connection_string=os.environ["ADLS_CONN"])
# dl.upload_data("bronze", "transactions/dt=2025-01-01/part.json", json.dumps(normalized).encode())


if __name__ == "__main__":
    # Smoke test sem subir API
    sample_api = {
        "amount": 150.0,
        "merchant_category": "Alimentacao",
        "user_country": "BR",
        "merchant_country": "BR",
        "payment_method": "PIX",
        "hour": 14,
        "is_weekend": 0,
        "is_international": 0,
    }
    sample_sim = {
        "transaction_id": "x",
        "amount": 999.0,
        "merchant_category": "Eletronicos",
        "timestamp": "2025-03-29T22:15:00",
        "user_country": "BR",
        "merchant_country": "US",
        "payment_method": "CREDIT_CARD",
    }
    print("api ->", normalize_for_model(sample_api, "api"))
    print("sim ->", normalize_for_model(sample_sim, "simulator"))
