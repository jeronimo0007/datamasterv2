# Mapa: Docker local ↔ Azure ↔ AWS (apresentação)

Use na banca para explicar que **o desenho é o mesmo**; só muda o produto.

| Função | Docker Compose (local) | Azure (`terraform/apresentacao`) | AWS (equivalente) |
|--------|------------------------|----------------------------------|-------------------|
| Hub / links | portal :8880 | — | — |
| API scoring | api-java :8080 | Container Apps + ACR | ECS/EKS + ALB |
| Dashboard | Streamlit :8501 | Power BI / Fabric (produção) | QuickSight |
| Simulador de carga | data-console :3333 | Data Factory (batch) | Glue |
| Streaming | Kafka :9092 | Event Hubs | Kinesis / MSK |
| Processamento | spark-master/worker | Databricks (opcional TF) | EMR / Glue Spark |
| Lake Medallion | `data/lake/` + MinIO buckets | ADLS `bronze/silver/gold` | S3 prefixes |
| OLTP | Postgres :5432 | PostgreSQL Flexible | RDS |
| NoSQL / perfis batch | Mongo :27017 · `user_profiles` | Cosmos DB (API Mongo) | DocumentDB |
| Dataprep perfis | `scripts/batch_dataprep_mongo.py` · serviço `batch-prep` | ADF + Databricks job → Cosmos | Glue → DynamoDB/DocumentDB |
| Cache | Redis :6379 | Azure Cache for Redis | ElastiCache |
| Object storage | MinIO :9000 | ADLS Gen2 | S3 |
| Segredos | .env local | Key Vault | Secrets Manager |
| Métricas / logs | Prometheus :9090, Grafana :3000 | Monitor + Log Analytics | CloudWatch |
| APM | — | Application Insights | X-Ray |
| ML treino | `models/fraud_model.pkl` (Python) | Azure ML (opcional TF) | SageMaker |
| IaC | docker-compose.yaml | `infrastructure/terraform/apresentacao` | Terraform AWS modules |

## Fluxo igual na mesa e na nuvem

```text
Fontes → batch histórico → Mongo user_profiles ──┐
       → streaming (Kafka) ─────────────────────┼→ API Java (analyze + perfil) → dashboard/alertas
       → Spark/lake (Bronze→Silver→Gold) → ML ─┘
```

## Comandos

**Local:**

```bash
docker compose up -d --build
bash scripts/demo_full_stack.sh
```

**Azure:**

```bash
cd infrastructure/terraform/apresentacao && terraform apply
# Ver README.md nesta pasta para push da imagem api-java
```
