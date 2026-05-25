#!/usr/bin/env python3
"""
Pipeline Medallion local (Bronze → Silver → Gold) com PySpark.
Uso no Docker:
  docker compose run --rm spark-job
Ou no host (com Spark instalado):
  spark-submit --master local[*] scripts/spark_local_pipeline.py
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    avg,
    col,
    count,
    dayofweek,
    hour,
    month,
    stddev,
    to_date,
    to_timestamp,
    when,
)


def project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT", Path(__file__).resolve().parents[1]))


def lake_base(root: Path) -> str:
    path = root / "data" / "lake"
    path.mkdir(parents=True, exist_ok=True)
    return path.as_uri()


class LocalMedallionPrep:
    LAYER_BRONZE = "bronze"
    LAYER_SILVER = "silver"
    LAYER_GOLD = "gold"

    def __init__(self, base_uri: str):
        self.base_uri = base_uri.rstrip("/")

    def layer_path(self, layer: str, entity: str = "transactions") -> str:
        return f"{self.base_uri}/{layer}/{entity}"

    def read_bronze_json(self, spark: SparkSession, json_path: Path):
        raw = json_path.read_text(encoding="utf-8").strip()
        if raw.startswith("["):
            records = json.loads(raw)
            if not records:
                raise ValueError(f"JSON vazio: {json_path}")
            df = spark.createDataFrame(records)
        else:
            df = spark.read.json(str(json_path))
        if "timestamp" in df.columns:
            df = df.withColumn("timestamp", to_timestamp(col("timestamp")))
        print(f"Bronze (JSON): {df.count()} registros")
        return df

    def write_bronze_parquet(self, df, spark: SparkSession):
        out = self.layer_path(self.LAYER_BRONZE)
        (
            df.write.mode("overwrite")
            .parquet(out)
        )
        print(f"Bronze (Parquet): {out}")

    def read_bronze_parquet(self, spark: SparkSession):
        path = self.layer_path(self.LAYER_BRONZE)
        df = spark.read.parquet(path)
        print(f"Lendo Bronze Parquet: {df.count()} registros")
        return df

    def clean(self, df):
        return (
            df.dropDuplicates(["transaction_id"])
            .fillna({"amount": 0, "merchant_category": "UNKNOWN", "user_country": "UNKNOWN"})
            .withColumn("amount", when(col("amount") < 0, 0).otherwise(col("amount")))
            .withColumn("transaction_date", to_date(col("timestamp")))
            .withColumn("transaction_hour", hour(col("timestamp")))
        )

    def enrich(self, df):
        df = (
            df.withColumn(
                "is_weekend",
                when(dayofweek(col("transaction_date")).isin([1, 7]), 1).otherwise(0),
            )
            .withColumn(
                "is_night",
                when((col("transaction_hour") >= 0) & (col("transaction_hour") < 6), 1).otherwise(0),
            )
            .withColumn("transaction_month", month(col("transaction_date")))
        )
        user_stats = df.groupBy("user_id").agg(
            avg("amount").alias("user_avg_amount"),
            count("*").alias("user_total_transactions"),
            stddev("amount").alias("user_amount_stddev"),
        )
        df = df.join(user_stats, "user_id", "left")
        if "merchant_id" in df.columns:
            merchant_stats = df.groupBy("merchant_id").agg(
                count("*").alias("merchant_transaction_count"),
                avg("amount").alias("merchant_avg_amount"),
            )
            df = df.join(merchant_stats, "merchant_id", "left")
        return df

    def save_layer(self, df, layer: str, entity: str = "transactions"):
        out = self.layer_path(layer, entity)
        (
            df.write.mode("overwrite")
            .partitionBy("transaction_date")
            .parquet(out)
        )
        print(f"Gravado {layer}: {out}")


def run_dq_checks(df) -> dict:
    total = df.count()
    null_amount = df.filter(col("amount").isNull()).count()
    dupes = total - df.dropDuplicates(["transaction_id"]).count()
    frauds = df.filter(col("is_fraud") == True).count() if "is_fraud" in df.columns else 0  # noqa: E712
    return {
        "validation_time": datetime.utcnow().isoformat(),
        "total_records": total,
        "null_amount": null_amount,
        "duplicate_ids": dupes,
        "fraud_labeled": frauds,
        "fraud_rate": round(frauds / total, 4) if total else 0,
        "success": null_amount == 0 and dupes == 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Pipeline Spark local Medallion")
    parser.add_argument(
        "-i",
        "--input",
        default="data/transactions.json",
        help="JSON de entrada (landing)",
    )
    parser.add_argument(
        "--master",
        default=os.environ.get("SPARK_MASTER_URL", "local[*]"),
        help="Spark master (ex: spark://spark-master:7077)",
    )
    args = parser.parse_args()

    root = project_root()
    json_path = root / args.input
    if not json_path.exists():
        print(f"Arquivo não encontrado: {json_path}", file=sys.stderr)
        print("Gere antes: python3 scripts/generate_data.py -n 500", file=sys.stderr)
        return 1

    spark = (
        SparkSession.builder.appName("FraudDetectionLocalMedallion")
        .master(args.master)
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .getOrCreate()
    )

    prep = LocalMedallionPrep(lake_base(root))

    print("=== Passo 1: Bronze (JSON → Parquet) ===")
    raw_df = prep.read_bronze_json(spark, json_path)
    prep.write_bronze_parquet(raw_df, spark)

    print("=== Passo 2: Data Quality ===")
    bronze_df = prep.read_bronze_parquet(spark)
    dq = run_dq_checks(bronze_df)
    print(json.dumps(dq, indent=2, ensure_ascii=False))
    dq_path = root / "data" / "lake" / "reports" / "dq_latest.json"
    dq_path.parent.mkdir(parents=True, exist_ok=True)
    dq_path.write_text(json.dumps(dq, indent=2), encoding="utf-8")

    print("=== Passo 3: Silver (limpeza + enriquecimento) ===")
    cleaned = prep.clean(bronze_df)
    enriched = prep.enrich(cleaned)
    prep.save_layer(enriched, prep.LAYER_SILVER)

    print("=== Passo 4: Gold (features ML) ===")
    gold_cols = [
        c
        for c in [
            "transaction_id",
            "transaction_date",
            "user_id",
            "amount",
            "merchant_category",
            "is_weekend",
            "is_night",
            "user_avg_amount",
            "user_amount_stddev",
            "merchant_transaction_count",
            "is_fraud",
        ]
        if c in enriched.columns
    ]
    gold_df = enriched.select(*gold_cols)
    if "is_fraud" in gold_df.columns:
        gold_df = gold_df.filter(col("is_fraud").isNotNull())
    prep.save_layer(gold_df, prep.LAYER_GOLD, entity="transactions_ml")

    print("=== Pipeline Spark concluído ===")
    spark.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
