#!/usr/bin/env python3
"""
Batch dataprep: lê transações históricas (JSON), agrega perfil por usuário e grava no MongoDB.
Uso na banca para mostrar camada batch (Bronze histórico → Silver perfil → serving na API).

  python3 scripts/batch_dataprep_mongo.py
  python3 scripts/batch_dataprep_mongo.py -i data/transactions.json -n 2000

Docker:
  docker compose run --rm batch-prep
"""
from __future__ import annotations

import argparse
import json
import os
import statistics
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

try:
    from pymongo import MongoClient, ReplaceOne
except ImportError:
    print("Instale: pip install pymongo", file=sys.stderr)
    sys.exit(1)


def parse_hour(ts: str) -> int:
    try:
        if "T" in ts:
            return int(ts.split("T")[1].split(":")[0])
    except (ValueError, IndexError):
        pass
    return 12


def build_profile(user_id: str, rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    amounts = [float(r.get("amount") or 0) for r in rows]
    hours = [parse_hour(str(r.get("timestamp") or "")) for r in rows]
    categories = [str(r.get("merchant_category") or "Outros") for r in rows]
    payments = [str(r.get("payment_method") or "PIX") for r in rows]
    intl = sum(
        1
        for r in rows
        if str(r.get("user_country", "BR")) != str(r.get("merchant_country", "BR"))
    )
    frauds = sum(1 for r in rows if r.get("is_fraud"))

    avg = statistics.mean(amounts) if amounts else 0.0
    std = statistics.pstdev(amounts) if len(amounts) > 1 else 0.0
    sorted_amt = sorted(amounts)
    p95_idx = max(0, int(len(sorted_amt) * 0.95) - 1)
    p95 = sorted_amt[p95_idx] if sorted_amt else 0.0

    cat_top = [c for c, _ in Counter(categories).most_common(5)]
    pay_top = [p for p, _ in Counter(payments).most_common(3)]

    return {
        "user_id": user_id,
        "tx_count": len(rows),
        "avg_amount": round(avg, 2),
        "std_amount": round(std, 2),
        "max_amount": round(max(amounts) if amounts else 0, 2),
        "p95_amount": round(p95, 2),
        "min_amount": round(min(amounts) if amounts else 0, 2),
        "typical_categories": cat_top,
        "typical_payment_methods": pay_top,
        "pct_international": round(intl / len(rows), 4) if rows else 0.0,
        "avg_hour": round(statistics.mean(hours), 1) if hours else 12.0,
        "historical_fraud_rate": round(frauds / len(rows), 4) if rows else 0.0,
        "profile_version": "batch-v1",
        "source": "historical_json",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Batch dataprep → MongoDB user_profiles")
    parser.add_argument("-i", "--input", default="data/transactions.json")
    parser.add_argument("-n", "--limit", type=int, default=0, help="Limitar linhas (0 = todas)")
    parser.add_argument(
        "--mongo-uri",
        default=os.environ.get(
            "MONGODB_URI",
            "mongodb://admin:admin123@localhost:27017/fraud_detection?authSource=admin",
        ),
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    input_path = root / args.input if not Path(args.input).is_absolute() else Path(args.input)
    if not input_path.exists():
        print(f"Arquivo não encontrado: {input_path}", file=sys.stderr)
        print("Gere antes: python3 scripts/generate_data.py -n 1000", file=sys.stderr)
        return 1

    with open(input_path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        print("JSON deve ser array de transações", file=sys.stderr)
        return 1
    if args.limit > 0:
        data = data[: args.limit]

    by_user: Dict[str, List[Dict[str, Any]]] = {}
    for row in data:
        uid = str(row.get("user_id") or "anonymous")
        by_user.setdefault(uid, []).append(row)

    profiles = [build_profile(uid, rows) for uid, rows in by_user.items()]

    client = MongoClient(args.mongo_uri, serverSelectionTimeoutMS=10000)
    client.admin.command("ping")
    db = client.get_default_database()
    coll = db["user_profiles"]

    ops = [ReplaceOne({"user_id": p["user_id"]}, p, upsert=True) for p in profiles]
    if ops:
        result = coll.bulk_write(ops)
        upserted = result.upserted_count + result.modified_count
    else:
        upserted = 0

    db["batch_runs"].insert_one(
        {
            "job": "batch_dataprep_mongo",
            "input_file": str(input_path),
            "records_read": len(data),
            "profiles_written": len(profiles),
            "started_at": datetime.now(timezone.utc).isoformat(),
            "status": "completed",
        }
    )

    print(f"✅ Batch dataprep concluído")
    print(f"   Transações lidas: {len(data)}")
    print(f"   Perfis de usuário: {len(profiles)}")
    print(f"   Upserts MongoDB: {upserted}")
    print(f"   URI: {args.mongo_uri.split('@')[-1] if '@' in args.mongo_uri else args.mongo_uri}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
