# DataMaster — Plataforma de detecção de fraudes bancárias

![Azure](https://img.shields.io/badge/Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Java](https://img.shields.io/badge/Java-Spring-6DB33F?style=for-the-badge&logo=spring&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Spark](https://img.shields.io/badge/Apache_Spark-E35A16?style=for-the-badge&logo=apachespark&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)

Repositório de **engenharia de dados** aplicada a antifraude: ingestão multi-fonte, lakehouse em camadas (Medallion), qualidade de dados, perfis históricos, API de scoring, governança, **LGPD** e observabilidade.

O caso de uso é **fraude em transações**; o artefato entregue é uma **plataforma** (batch + online + serving), não apenas um notebook de ML.

| Ambiente | Descrição |
|----------|-----------|
| **Execução local** | `docker compose` — API Java, dashboard, Spark, Kafka, MongoDB, Prometheus/Grafana |
| **Alvo em nuvem** | Azure (Event Hubs, ADLS, Databricks, Cosmos, Key Vault, Monitor) — ver [infrastructure/MAPA_LOCAL_AZURE.md](infrastructure/MAPA_LOCAL_AZURE.md) e Terraform em `infrastructure/terraform/` |

---

## Pré-requisitos

- Docker Desktop (ou Docker Engine + Compose v2)
- ~8 GB RAM livres para a stack completa
- Opcional: `DEEPSEEK_API_KEY` no `.env` ou no `docker-compose` para o assistente de IA na API

---

## Como executar

**Stack completa com dados de exemplo (recomendado para avaliar o fluxo):**

```bash
git clone <url-do-repositorio>
cd datamaster
bash scripts/run_demo.sh
```

O script sobe os containers, gera `data/transactions.json`, materializa perfis em MongoDB (`user_profiles`) e executa o pipeline Spark Bronze → Silver → Gold em `data/lake/`.

**Apenas subir os serviços (sem popular dados):**

```bash
docker compose up -d --build
```

**Validação rápida:**

```bash
curl -s http://localhost:8080/health
curl -s http://localhost:8080/api/v1/batch/profile-stats
```

Alias do fluxo completo: `bash scripts/demo_full_stack.sh`

---

## Serviços (demo local)

| Serviço | URL | Função |
|---------|-----|--------|
| API REST + Swagger | http://localhost:8080/swagger-ui.html | Scoring, batch, LGPD, alertas, métricas |
| Dashboard operacional | http://localhost:8501 | Fraudes, liberação de casos, LGPD, gráficos |
| Console de dados | http://localhost:3333 | Geração de JSON e envio de lotes à API |
| Portal de navegação | http://localhost:8880 | Links e atalhos da demo local |
| Spark UI | http://localhost:18080 | Jobs batch |
| Jupyter | http://localhost:8888/?token=datamaster | Notebooks PySpark |
| Prometheus / Grafana | http://localhost:9090 · http://localhost:3000 | Métricas (Grafana: `admin` / `admin`) |

Credenciais dos demais serviços (MongoDB, MinIO, Postgres): ver portal :8880 ou [docs/QUICK_START.md](docs/QUICK_START.md).

---

## Arquitetura

**Visão de plataforma (alvo):**

```mermaid
graph LR
    subgraph fontes [Fontes]
        A[Core / PIX / Arquivos]
    end
    subgraph ingestao [Ingestão]
        B[Event Hubs ou Kafka]
    end
    subgraph processamento [Processamento]
        C[Databricks / Spark]
    end
    subgraph lake [Lake Medallion]
        D[Bronze]
        E[Silver]
        F[Gold]
    end
    subgraph serving [Serving]
        G[ML treino / features]
        H[API scoring]
        I[Dashboard / canais]
    end
    A --> B --> C --> D --> E --> F --> G --> H --> I
```

**Recorte implementado no Docker (avaliação local):**

- **Batch:** histórico → `batch_dataprep_mongo.py` → MongoDB `user_profiles` · Spark → `data/lake/` (Medallion)
- **Online:** console/dashboard → **API :8080** → consulta perfil no `POST /analyze` (Kafka sobe no compose como analogia a streaming; o caminho crítico da demo chama a API diretamente)
- **Segurança / LGPD:** `POST /api/v1/lgpd/mask` (Java) e `src/utils/data_masker.py` (Python, jobs e testes)

Diagramas detalhados (draw.io, Docker, Azure/AWS): [docs/arquitetura/](docs/arquitetura/) — índice em [docs/arquitetura/README.md](docs/arquitetura/README.md). Regeneração: `python3 scripts/generate_architecture_drawio.py`.

---

## Stack técnica (Compose)

| Camada | Implementação |
|--------|----------------|
| API de scoring | Java 17, Spring Boot — `api-java/` (perfil `local`, porta **8080**) |
| Dashboard | Streamlit — `src/dashboard/` |
| Simulador / integração | Node.js — `data-generator-console/` |
| Lake batch | PySpark — `scripts/spark_local_pipeline.py` |
| Perfis online | `scripts/batch_dataprep_mongo.py` · serviço `batch-prep` |
| Streaming (referência) | Kafka + Zookeeper |
| Persistência | MongoDB (perfis), Postgres (schema demo), MinIO, Redis |
| Observabilidade | Prometheus + Grafana provisionados em `config/grafana/` |
| ML (treino / artefatos) | Python — `src/ml_models/`, notebooks em `notebooks/` |
| IaC | Terraform — `infrastructure/terraform/` |

A scoring **em tempo real na demo** é feita pelo serviço Java (`1.0.0-java-balanced`): heurística interpretável + boost quando o comportamento diverge do perfil em MongoDB. O pipeline Python/Spark no repositório cobre treino, features e lake — contrato exposto na API REST.

| Parâmetro | Valor na demo |
|-----------|----------------|
| Limiar `is_fraud` | score ≥ **0,74** |
| Métricas em `/api/v1/model/metrics` | Valores de **referência** (`java-heuristic-demo`), não retreino automático a cada requisição |

---

## Principais capacidades (API e UI)

- `POST /api/v1/transactions/analyze` — scoring com perfil histórico (MongoDB)
- `GET /api/v1/transactions` — listagem com filtros (`all`, `fraud`, `released`)
- `POST /api/v1/transactions/{id}/release` — fluxo de liberação de falso positivo
- `POST /api/v1/transactions/batch` — processamento em lote
- `POST /api/v1/lgpd/mask` — mascaramento de PII (CPF, e-mail, telefone, nome, cartão)
- `POST /api/v1/assistant/chat` — assistente contextual (requer `DEEPSEEK_API_KEY`)
- `GET /api/v1/dashboard/summary` — KPIs para o dashboard
- `GET /api/v1/model/feature-importance` — pesos de referência das variáveis
- Data quality e governança — `governanca.yaml`, notebook `notebooks/01_dataprep_dq.py`

No dashboard (:8501): abas **Transações**, **Batch / perfil**, **LGPD / mascaramento**, **Assistente IA**, **Gráficos**.

---

## Infraestrutura em nuvem (opcional)

Stack de referência Azure (ADLS bronze/silver/gold, Event Hubs, Cosmos, PostgreSQL, Key Vault, Monitor, Container App):

```bash
cd infrastructure/terraform/apresentacao
cp terraform.tfvars.example terraform.tfvars
terraform apply
```

- Mapa serviço a serviço: [infrastructure/MAPA_LOCAL_AZURE.md](infrastructure/MAPA_LOCAL_AZURE.md)
- Ambientes adicionais: `infrastructure/terraform/environments/dev/` · mínimo: `banca-minimo/`

---

## Estrutura do repositório

```
datamaster/
├── api-java/                 # API Spring Boot (scoring, LGPD, alertas)
├── src/                      # Python: ML, dashboard, ingestão, utilitários
├── scripts/                  # Demo, batch, Spark, geração de dados
├── notebooks/                # PySpark / DQ
├── data-generator-console/   # Simulador e fluxo via Docker socket
├── portal/                   # Páginas estáticas da demo local (:8880)
├── infrastructure/terraform/ # IaC Azure
├── config/grafana/           # Provisioning Grafana
├── sql/                      # Schema e seed Postgres
├── docker-compose.yaml
└── docs/                     # Documentação (índice em docs/README.md; ver .gitignore para exceções)
```

---

## Documentação complementar

Índice: [docs/README.md](docs/README.md) — quick start, arquitetura, operação Docker, estudo e diagramas em `docs/arquitetura/`.

Rascunhos e scripts de apoio em `docs/base_estudo/` (demais arquivos) e duplicatas em `docs/apresentacao/` permanecem fora do Git (ver `.gitignore`).

Material de **apresentação oral ao vivo** (slides, cola): `portal/banca.html` e `portal/roteiro.html` no portal :8880.

---

## Licença

MIT — ver [LICENSE](LICENSE).
