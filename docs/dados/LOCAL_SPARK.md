# Spark local (Docker)

O notebook `01_dataprep_dq.py` foi escrito para **Databricks** (`abfss://`, `dbutils`). Para a banca com stack Docker use:

## Opção A — Job batch (recomendado na apresentação)

```bash
# Na raiz, com a stack no ar:
python3 scripts/generate_data.py -n 500 -o data/transactions.json
docker compose --profile spark-run run --rm spark-job
```

Saídas em `data/lake/bronze`, `silver`, `gold` e `data/lake/reports/dq_latest.json`.

## Opção B — Jupyter interativo

1. `docker compose up -d` (Jupyter sobe na porta **8888**, token **`datamaster`**).
2. Abra http://localhost:8888 e navegue até `work/scripts/spark_local_pipeline.py` ou crie um notebook com:

```python
import os
os.environ["SPARK_MASTER_URL"] = "spark://spark-master:7077"
os.environ["PROJECT_ROOT"] = "/home/jovyan/work"

# %run work/scripts/spark_local_pipeline.py
```

Ou no terminal do notebook:

```bash
!cd /home/jovyan/work && spark-submit --master spark://spark-master:7077 \
  scripts/spark_local_pipeline.py --input data/transactions.json
```

## Spark UI

http://localhost:18080 — master + workers após o job.

## Script único (tudo automatizado)

```bash
bash scripts/demo_full_stack.sh
```
