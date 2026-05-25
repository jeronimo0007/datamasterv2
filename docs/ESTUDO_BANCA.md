# Estudo para aprofundar a apresentação (banca)

Lista focada no que o repositório **DataMaster** oferece hoje: demo Docker (API Java :8080, dashboard, Kafka, Spark) + narrativa Azure/AWS de produção.

**Relacionado:** [PLANO_ESTUDO.md](PLANO_ESTUDO.md) (plano longo ~40–50 h) · [SERVICOS_DOCKER.md](SERVICOS_DOCKER.md) · [APRESENTACAO_BANCA.md](APRESENTACAO_BANCA.md) · [QUICK_START.md](QUICK_START.md) · [base_estudo/](base_estudo/)

---

## Prioridade alta — dominar antes da banca

### 1. Narrativa e posicionamento (2–3 h)

- Ler de ponta a ponta: [APRESENTACAO_BANCA.md](APRESENTACAO_BANCA.md) (Partes 1–3) e ensaiar com `portal/banca.html` (projetor) + `portal/roteiro.html` (cola verbal).
- Fixar a frase-chave: **fraude é o caso; a banca avalia plataforma de dados** (ingestão → camadas → qualidade → ML → API → LGPD → observabilidade).
- Treinar a tabela **Azure ↔ AWS** de memória:
  - Event Hubs ≈ Kinesis / MSK (Kafka gerenciado)
  - ADLS Gen2 ≈ S3 (+ Lake Formation)
  - Databricks ≈ EMR / Glue Spark
  - Purview ≈ Glue Data Catalog + Lake Formation
  - Monitor + App Insights ≈ CloudWatch + X-Ray
- Material extra: [base_estudo/perguntas_banca.txt](base_estudo/perguntas_banca.txt) · [base_estudo/respostas_banca.txt](base_estudo/respostas_banca.txt) · [base_estudo/respostas_banca.md](base_estudo/respostas_banca.md)

### 2. Demo ao vivo — fluxo T0–T11 (3–4 h)

- [QUICK_START.md](QUICK_START.md) + `scripts/demo_full_stack.sh` — rodar **3 vezes** até não depender de notas.
- Ordem mental: **health → Swagger → analyze (normal/suspeito) → batch → dashboard → console → Kafka (se couber) → Spark UI → Grafana**.
- Regras de score vs alerta: [GUIA_APRESENTACAO_BANCA.md](GUIA_APRESENTACAO_BANCA.md).
- API local (código):
  - `api-java/src/main/java/com/fraud/local/LocalFraudScoringService.java`
  - `api-java/src/main/java/com/fraud/local/LocalDemoApiController.java`

| Passo | URL / comando |
|-------|----------------|
| Health | `curl http://localhost:8080/health` |
| Swagger | http://localhost:8080/swagger-ui.html |
| Dashboard | http://localhost:8501 |
| Console | http://localhost:3333 |
| Spark UI | http://localhost:18080 |
| Portal hub | http://localhost:8880 |
| Grafana | http://localhost:3000 (`admin` / `admin`) |
| MinIO | http://localhost:9001 (`minioadmin` / `minioadmin`) |
| Jupyter | http://localhost:8888/?token=datamaster |

### 3. Arquitetura Medalhão + Spark (4–5 h)

- `notebooks/01_dataprep_dq.py` — Bronze / Silver / Gold e Data Quality.
- `scripts/spark_local_pipeline.py` + [LOCAL_SPARK.md](LOCAL_SPARK.md) — o que roda no Docker vs narrativa Databricks.
- `src/data_architecture/medallion.py` · `config/medallion.yaml`.
- Conceitos: schema-on-read (lake) vs schema-on-write (warehouse); Parquet; particionamento por data.

### 4. Streaming e ingestão (3–4 h)

- `src/data_ingestion/event_hub_producer.py` · `event_hub_consumer.py` — batch, partições, **checkpoint**.
- `docker-compose.yaml` — Kafka local (mesmo padrão lógico: tópico, consumer group, offset).
- Lambda vs Kappa — quando citar cada um nos slides.

### 5. ML e métricas para fraude (4–5 h)

- `src/ml_models/fraud_model.py` — Isolation Forest, XGBoost, ensemble.
- Endpoints: `/api/v1/model/metrics`, feature importance (curl na :8080).
- **Recall vs precision** em fraude (priorizar recall; custo de falso positivo).
- Desbalanceamento (SMOTE, class weights) — o que está no código vs “próximo passo”.
- MLOps: MLflow, drift (Evidently) — narrativa se não estiver implementado.

---

## Prioridade média — diferencia na discussão

### 6. Multi-cloud e FinOps (2–3 h)

- `infrastructure/terraform/environments/dev/` — RG, Storage HNS, Event Hub, Cosmos, Key Vault, Postgres.
- `infrastructure/terraform/banca-minimo/README.md` — deploy mínimo Azure.
- [TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md](TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md) — CI/CD como desenho.
- Trade-offs: latência vs custo vs complexidade; Throughput Units (Event Hubs) vs partições Kafka.

### 7. Data Quality e governança (2–3 h)

- Expectations no notebook (`AzureDataQuality` em `01_dataprep_dq.py`).
- `config/governanca.yaml` — regras declarativas.
- **Data quality** (regras técnicas) vs **governança** (catálogo, linhagem, Purview).
- Data drift: detecção e ação quando o modelo degrada.

### 8. LGPD e segurança (2–3 h)

- `src/utils/data_masker.py` · `api-java/.../LgpdMaskingService.java`.
- Mascaramento vs pseudonimização vs anonimização.
- Azure: Key Vault, Managed Identity, RBAC — AWS: Secrets Manager, IAM.
- Princípios LGPD no pipeline (minimização, finalidade, retenção por camada).

### 9. Observabilidade (2 h)

- Prometheus (:9090) + Grafana (:3000) no compose.
- Três pilares: métricas, logs, tracing → Monitor/App Insights (Azure) · CloudWatch/X-Ray (AWS).
- SLO/SLA: promessa em produção vs o que a demo mostra.

### 10. Docker e operação (1–2 h)

- `docker-compose.yaml` — papel de cada serviço.
- Imagem vs container; volumes; rede (`http://api:8080` no Streamlit).
- `api-java/Dockerfile` e `docker compose up -d --build`.

---

## Prioridade baixa — se sobrar tempo

### 11. Dashboard e produto

- `src/dashboard/app.py` — consumo da API, KPIs e alertas.

### 12. Storage e formatos

- `src/data_storage/datalake_client.py` — ADLS (narrativa produção).
- Avro no streaming; Delta Lake como evolução do Parquet.

### 13. DevOps avançado

- Canary / blue-green / rolling — citar na banca.
- GitHub Actions + ACR + Container Apps ([tutorial](TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md)).

---

## Roteiro de leitura no código (ordem sugerida)

| # | Arquivo | Por quê |
|---|---------|--------|
| 1 | `docker-compose.yaml` | Mapa mental da demo |
| 2 | `api-java/.../local/*` | Como a API responde na banca |
| 3 | `scripts/generate_data.py` | Dados sintéticos |
| 4 | `src/ml_models/fraud_model.py` | Modelo e métricas |
| 5 | `notebooks/01_dataprep_dq.py` | Pipeline + DQ |
| 6 | `scripts/spark_local_pipeline.py` | Medallion local |
| 7 | `src/data_ingestion/event_hub_*.py` | Streaming Azure |
| 8 | `infrastructure/terraform/.../main.tf` | IaC |
| 9 | `config/governanca.yaml` | Governança |
| 10 | `src/utils/data_masker.py` | LGPD |

---

## Perguntas para ensaiar em voz alta

**Arquitetura**

- Por que Medalhão e não um único bucket?
- O que acontece se o consumer cair no meio do processamento?
- Event Hubs ou Kafka — quando cada um?

**ML**

- Por que recall importa mais que precision em fraude?
- E se o padrão de fraude mudar (concept drift)?
- Como você versiona e faz rollback de modelo?

**Cloud / IaC**

- Como versiona infra com Terraform? O que é o `tfstate`?
- Equivalente AWS do serviço X que você citou na Azure?

**LGPD**

- CPF na Bronze — o que você faz antes de expor na API?
- Mascaramento é reversível? Quando usar hash irreversível?

**Operação**

- API lenta — onde olha primeiro? (métrica → log → trace)
- O que acontece se uma validação de DQ falhar em produção?

---

## Recursos externos (curtos)

| Tema | Onde |
|------|------|
| Medalhão | Databricks — “Medallion Architecture” |
| Kafka | Confluent — Kafka 101 |
| Event Hubs | Microsoft Learn — Azure Event Hubs |
| Terraform Azure | HashiCorp Learn — Get Started Azure |
| Precision / Recall | StatQuest (YouTube) |
| Classes desbalanceadas | StatQuest — imbalanced classification |
| Lake vs warehouse | Alex The Analyst (YouTube) |

---

## Plano de 1 semana (resumo)

| Dia | Foco |
|-----|------|
| 1–2 | APRESENTACAO_BANCA + ensaio slides/roteiro + `demo_full_stack.sh` 3× |
| 3 | Medalhão + notebook + Spark local |
| 4 | Streaming (Event Hub + Kafka) + ML + métricas |
| 5 | Terraform + Azure/AWS + LGPD |
| 6 | DQ + observabilidade + base_estudo |
| 7 | Ensaio cronometrado 90 min + simulado com colega |

---

## Checklist pré-banca

- [ ] `docker compose up -d --build` sem erros
- [ ] http://localhost:8080/health e Swagger OK
- [ ] http://localhost:8501 e http://localhost:8880 OK
- [ ] `bash scripts/demo_full_stack.sh` (ou passos manuais T0–T11)
- [ ] Leu Partes 1–3 de [APRESENTACAO_BANCA.md](APRESENTACAO_BANCA.md)
- [ ] Ensaiou 3 blocos de perguntas (arquitetura, ML, LGPD)
- [ ] Sabe explicar: demo local ≠ datacenter Azure completo (mesmo **padrão**)

---

*Última atualização alinhada à stack: API Java perfil `local` :8080, portal :8880, sem FastAPI :8000 na demo Docker.*
