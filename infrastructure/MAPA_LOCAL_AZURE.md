# Mapa: Docker local ↔ VPS (k3s) ↔ Azure ↔ AWS

Use na banca e na operação para explicar que **o desenho é o mesmo**; só muda o produto e o ambiente de execução.

| Função | Docker Compose (local) | VPS homelab (k3s) | Azure (`terraform/apresentacao`) | AWS (equivalente) |
|--------|------------------------|-------------------|----------------------------------|-------------------|
| Hub / links | portal :8880 | NodePort **30880** | — | — |
| API scoring | api-java :8080 | NodePort **30080** | Container Apps + ACR | ECS/EKS + ALB |
| Dashboard | Streamlit :8501 | NodePort **30501** | Power BI / Fabric (produção) | QuickSight |
| Simulador de carga | data-console :3333 | NodePort **30333** | Data Factory (batch) | Glue |
| Streaming | Kafka :9092 | NodePort **30902** | Event Hubs | Kinesis / MSK |
| Fila alerta e-mail | RabbitMQ :5672, UI **:15672** | NodePort **30672** / **31672** | Service Bus (+ Logic App) | SQS (+ Lambda) |
| Worker e-mail | email-worker :8090 | Deployment `email-worker` | Function / Container App | Lambda / ECS task |
| Processamento | spark-master/worker | Spark no cluster, UI **30180** | Databricks (opcional TF) | EMR / Glue Spark |
| Lake Medallion | `data/lake/` + MinIO | MinIO + hostPath/console | ADLS `bronze/silver/gold` | S3 prefixes |
| OLTP | Postgres :5432 | Service interno | PostgreSQL Flexible | RDS |
| NoSQL / perfis batch | Mongo :27017 · `user_profiles` | Mongo no cluster | Cosmos DB (API Mongo) | DocumentDB |
| Dataprep perfis | `batch_dataprep_mongo.py` | Job/console no VPS | ADF + Databricks → Cosmos | Glue → DocumentDB |
| Cache | Redis :6379 | Redis no cluster | Azure Cache for Redis | ElastiCache |
| Object storage | MinIO :9000 | NodePort **30901** | ADLS Gen2 | S3 |
| Segredos | `.env` local | Secrets K8s | Key Vault | Secrets Manager |
| Métricas / logs | Prometheus :9090, Grafana :3000 | **30090** / **30300** | Monitor + Log Analytics | CloudWatch |
| APM | — | — | Application Insights | X-Ray |
| ML treino | `models/` (Python) | hostPath / notebooks | Azure ML (opcional TF) | SageMaker |
| IaC / deploy | docker-compose.yaml | Kustomize `overlays/homelab` · branch **`vps`** | `terraform/apresentacao` | Terraform AWS |

Deploy VPS: **[docs/DEPLOY_K8S.md](../docs/DEPLOY_K8S.md)**.

## Fluxo igual na mesa, no VPS e na nuvem

```text
Fontes → batch histórico → Mongo user_profiles ──┐
       → streaming (Kafka / Event Hubs) ─────────┼→ API Java (analyze + perfil)
       → fraude → RabbitMQ → email-worker (SMTP) ┤
       → Spark/lake (Bronze→Silver→Gold) → ML ───┘→ dashboard / alertas
```

## Comandos

**Local:**

```bash
docker compose up -d --build
bash scripts/run_demo.sh
```

**VPS (Kubernetes):**

```bash
bash scripts/deploy-kubernetes-server.sh
# Portal: http://<IP-VPS>:30880
```

**Azure (apresentação / referência):**

```bash
cd infrastructure/terraform/apresentacao && terraform apply
```
