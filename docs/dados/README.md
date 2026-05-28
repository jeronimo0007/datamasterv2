# Domínio: Dados

Engenharia de dados, persistência, lakehouse local e preparação de perfis para serving.

## Documentos

| Documento | Conteúdo |
|-----------|----------|
| [LOCAL_SPARK.md](LOCAL_SPARK.md) | Spark master/worker, job batch, notebook |
| [MONGODB_COMPASS.md](MONGODB_COMPASS.md) | MongoDB `user_profiles`, Compass |
| [../arquitetura/ARCHITECTURE.md](../arquitetura/ARCHITECTURE.md) | Arquitetura (camadas batch e lake) |
| [../operacao/SERVICOS_DOCKER.md](../operacao/SERVICOS_DOCKER.md) | Spark, Jupyter, Postgres, Mongo, MinIO |

## Scripts e artefatos

| Caminho | Função |
|---------|--------|
| `scripts/run_demo.sh` | Fluxo completo: JSON → Mongo → lake |
| `scripts/batch_dataprep_mongo.py` | Agregação por `user_id` → `user_profiles` |
| `scripts/spark_local_pipeline.py` | Medallion Bronze → Silver → Gold |
| `notebooks/01_dataprep_dq.py` | DQ no Jupyter |

## Diagramas

[../arquitetura/datamaster-01-batch.drawio](../arquitetura/datamaster-01-batch.drawio) · [../arquitetura/README.md](../arquitetura/README.md)

[← Índice geral](../README.md)
