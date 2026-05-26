# Quick Start — ambiente local

Guia completo para rodar o **DataMaster** localmente. A **API principal é Java (Spring Boot)** na porta **8080**. Python entra no **dashboard**, nos **scripts de dados** e no **console Node.js** de gerenciamento.

---

## Visão geral

| Componente | Tecnologia | Porta | Função |
|------------|------------|-------|--------|
| API | Java / Spring Boot (`api-java`) | **8080** | Análise de fraude, alertas, LGPD, métricas |
| Dashboard | Streamlit (`src/dashboard`) | **8501** | Painéis em tempo real |
| Portal início | nginx (`portal/`) | **8880** | Links e passo a passo da demo |
| Console gerador | Node.js (`data-generator-console`) | **3333** | UI para `generate_data` e `demo_loop` |
| Spark | PySpark cluster (`spark-master` + `spark-worker`) | **18080** (UI), **7077** | Pipeline Medallion batch |
| **spark-master**, **spark-worker** | — | Não sobem no `docker compose up` padrão — use `spark-job` profile |
| **jupyter** | `fraud-jupyter` | Notebooks PySpark ligados ao cluster |
| Jupyter | PySpark notebook | **8888** | Explorar dados / rodar jobs (token: `datamaster`) |
| Infra | Docker Compose | várias | Kafka, Postgres, Mongo, Redis, MinIO, Prometheus, Grafana |

> A API **FastAPI** (`src/api/`) e o perfil Spring **`banca`** (proxy Python) foram **removidos**. O scoring da demo roda **nativamente em Java** (perfil `local`).

---

## Pré-requisitos

Guia passo a passo (`.env`, Mac, VPS): **[AMBIENTE_LOCAL.md](AMBIENTE_LOCAL.md)**.

- **Docker Desktop** (rodando — ícone da baleia estável no menu)
- **Java 17+** e **Maven 3.8+** (API fora do Docker, opcional)
- **Python 3.9+** (dashboard, scripts, `demo_loop` com `/batch`)
- **Node.js 18+** (console do gerador, opcional)

Ambiente Python (uma vez, na raiz do repo):

```bash
cd datamaster   # pasta raiz do projeto
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-demo.txt
```

- **`requirements-demo.txt`** — dashboard, scripts e venv da demo (também no `Dockerfile.dashboard`).
- **`requirements.txt`** — stack **completa** (Azure, PySpark, DQ, MLflow); use só se for desenvolver/treinar fora do Compose mínimo.

---

## 1. Fluxo completo (recomendado)

Um comando faz **tudo**: sobe a stack, gera JSON, perfis MongoDB, lake Medallion e valida a API.

```bash
cd datamaster
bash scripts/run_demo.sh
```

Equivalente: `bash scripts/demo_full_stack.sh`.

| Etapa | O que acontece |
|-------|----------------|
| Compose | API Java :8080, dashboard :8501, console :3333, Spark, Kafka, MongoDB, Grafana… |
| Dados | `data/transactions.json` |
| Batch | `user_profiles` no MongoDB |
| Lake | `data/lake/` Bronze → Silver → Gold |
| Check | `profile-stats` na API |

Portal :8880 → botão **Executar fluxo completo** (mesmo fluxo via console :3333).

---

## 1b. Só subir Docker (sem popular dados)

Se quiser apenas os containers, sem JSON/lake:

```bash
cd datamaster
docker compose up -d --build
```

Confira:

```bash
docker compose ps
```

### URLs após o `up` (acesse no navegador)

| Serviço | URL |
|---------|-----|
| **Portal de início** | http://localhost:8880 |
| **API Java (Swagger)** | http://localhost:8080/swagger-ui.html |
| **Dashboard — Detecção de Fraudes** | http://localhost:8501 |
| **Console gerador de dados (Node)** | http://localhost:3333 |
| API Health | http://localhost:8080/health |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (login: `admin` / `admin`) — datasource Prometheus e dashboard **DataMaster — API Fraude** já provisionados |
| MinIO Console | http://localhost:9001 (`minioadmin` / `minioadmin`) |
| **Spark UI** | http://localhost:18080 |
| **Jupyter (PySpark)** | http://localhost:8888 (token: `datamaster`) |

### O que o Compose sobe

| Serviço | Container | Descrição |
|---------|-----------|-----------|
| **api** | `fraud-api` | Spring Boot, perfil `local` |
| **dashboard** | `fraud-dashboard` | Streamlit — título *Sistema de Detecção de Fraudes Bancárias* |
| **data-console** | `fraud-data-console` | Node.js — `generate_data` + `demo_loop` |
| mongodb, postgres, redis, kafka, zookeeper, minio | — | Infraestrutura de apoio |
| **portal** | `fraud-portal` | Página inicial — http://localhost:8880 |
| **spark-master**, **spark-worker** | — | Cluster Spark 3.5 (sobe no `up` padrão) |
| **jupyter** | `fraud-jupyter` | Notebooks PySpark ligados ao cluster |
| prometheus, grafana | — | Observabilidade |

O console Node monta a pasta do projeto em `/workspace` (alterações em `scripts/` e `data/` refletem no container).

> **RAM:** para a stack completa (API + Kafka + Spark + Jupyter), reserve **~8 GB** no Docker Desktop.

### Kafka não sobe (`KAFKA_PROCESS_ROLES is not set`)

Se o log do Kafka mostrar `environment variable "KAFKA_PROCESS_ROLES" is not set`, a imagem antiga (`cp-kafka:latest`) não serve. O projeto já usa **`confluentinc/cp-kafka:7.5.0`** com Zookeeper. Recrie os containers:

```bash
docker compose down
docker compose up -d --build
docker compose ps kafka zookeeper
```

Com `State` **Up**, crie o tópico (opcional — também há auto-create):

```bash
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 \
  --create --topic fraud-transactions --if-not-exists --partitions 1 --replication-factor 1
```

### MongoDB (`init_mongo.js` é diretório)

Se aparecer `could not read from input file: Is a directory`, o volume apontava para uma pasta. O repositório inclui `scripts/init_mongo.js` como arquivo; suba de novo com `docker compose up -d mongodb`.

### Só a aplicação (sem Kafka/DBs extras)

```bash
docker compose up -d --build api dashboard data-console
```

### Nada na máquina além do Docker

| Antes (host) | Agora (Docker) |
|--------------|----------------|
| `mvn spring-boot:run` | serviço **api** |
| `streamlit run ...` | serviço **dashboard** |
| `npm start` em `data-generator-console` | serviço **data-console** |
| `python3 scripts/generate_data.py` | aba **Gerar JSON** em :3333 ou logs do console |
| `bash scripts/demo_loop.sh` | botão **Iniciar loop** em :3333 |

### Pipeline Spark (Medallion) após gerar JSON

Com a stack no ar, gere o arquivo de landing e rode o job:

```bash
# Gerar dados (host ou dentro do console)
python3 scripts/generate_data.py -n 500 -o data/transactions.json --fraud-rate 0.08

# Job PySpark no cluster Docker (Bronze → Silver → Gold + relatório DQ)
docker compose --profile spark-run run --rm spark-job
```

Resultado em `data/lake/` (`bronze/`, `silver/`, `gold/`, `reports/dq_latest.json`). Detalhes: [LOCAL_SPARK.md](LOCAL_SPARK.md).

**Tudo de uma vez** (sobe compose, gera JSON, roda Spark):

```bash
bash scripts/demo_full_stack.sh
```

### Parar a stack

```bash
docker compose down
```

---

## 2. API Java sem Docker (opcional)

```bash
cd api-java
mvn spring-boot:run
```

- Perfil padrão: **`local`**
- Swagger: http://localhost:8080/swagger-ui.html

### Perfis Spring

| Perfil | Uso |
|--------|-----|
| **`local`** (padrão) | Demo: `/api/v1/*`, estado em memória, sem JPA/Postgres |
| **`enterprise`** | Postgres + Redis + JPA + OAuth (integração “produção”) |

```bash
SPRING_PROFILES_ACTIVE=enterprise mvn spring-boot:run
```

---

## 3. Testar a API

### Health

```bash
curl -s http://localhost:8080/health | python3 -m json.tool
```

### Transação normal (baixo risco)

```bash
curl -s -X POST http://localhost:8080/api/v1/transactions/analyze \
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
```

### Transação suspeita (demo de fraude)

```bash
curl -s -X POST http://localhost:8080/api/v1/transactions/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 45000,
    "merchant_category": "Eletronicos",
    "user_country": "BR",
    "merchant_country": "US",
    "payment_method": "CREDIT_CARD",
    "hour": 3,
    "is_weekend": 1,
    "is_international": 1
  }' | python3 -m json.tool
```

### Listar transações e alertas

```bash
curl -s http://localhost:8080/api/v1/transactions | python3 -m json.tool
curl -s http://localhost:8080/api/v1/alerts | python3 -m json.tool
curl -s http://localhost:8080/api/v1/dashboard/summary | python3 -m json.tool
```

---

## 4. Dashboard (Streamlit)

Com a API no ar.

**Via Docker:** abra http://localhost:8501 (já aponta para a API interna).

**Manual:**

```bash
source .venv/bin/activate
API_URL=http://127.0.0.1:8080 streamlit run src/dashboard/app.py --server.port 8501
```

Na sidebar, confira **API URL** = `http://127.0.0.1:8080`.

---

## 5. Gerar dados (`generate_data.py`)

Gera o arquivo `data/transactions.json` (rótulo `is_fraud` do **simulador** — só vira gráfico na API depois de chamar `/analyze` ou `/batch`).

```bash
source .venv/bin/activate
cd datamaster

# Padrão: 100 transações → data/transactions.json
python3 scripts/generate_data.py

# Personalizado
python3 scripts/generate_data.py -n 500 -o data/transactions.json --fraud-rate 0.08
```

| Parâmetro | Significado | Padrão |
|-----------|-------------|--------|
| `-n` / `--num` | Quantidade de transações | 100 |
| `-o` / `--output` | Caminho do JSON | `data/transactions.json` |
| `--fraud-rate` | Taxa de fraude no JSON (0.0–1.0) | 0.05 |

---

## 6. Demo guiada (`demo.sh`)

Passo a passo com pausas (Enter entre etapas):

```bash
source .venv/bin/activate
bash scripts/demo.sh
```

Sem pausas:

```bash
DEMO_NONINTERACTIVE=1 bash scripts/demo.sh
# ou
bash scripts/demo.sh --auto
```

Usa `API_URL=http://localhost:8080` por padrão.

---

## 7. Demo em loop (`demo_loop.sh`)

Gera JSON, envia transações fixas + lote `/batch` em ciclos. **Requer API no ar** e `requests` no venv.

```bash
source .venv/bin/activate

# A cada 60 s, infinito (Ctrl+C para parar)
bash scripts/demo_loop.sh 60

# A cada 30 s, 5 ciclos
bash scripts/demo_loop.sh 30 5

# Variáveis opcionais
GENERATE_N=200 BATCH_SLICE=50 API_URL=http://localhost:8080 bash scripts/demo_loop.sh 45 3
```

| Argumento / variável | Significado | Padrão |
|----------------------|-------------|--------|
| `$1` | Intervalo entre ciclos (segundos) | 60 |
| `$2` | Máximo de ciclos (`0` = infinito) | 0 |
| `GENERATE_N` | Transações geradas por ciclo | 80 |
| `BATCH_SLICE` | Linhas enviadas no `/batch` | 20 |
| `API_URL` | Base da API Java | `http://localhost:8080` |

**Cada ciclo:** health → `generate_data` → 3× `analyze` → `batch` → resumo do dashboard.

---

## 8. Console do gerador (Node.js)

### Dentro do Docker (padrão com `docker compose up`)

Abra **http://localhost:3333** — o serviço `data-console` já usa `API_URL=http://api:8080` na rede interna.

### No host (opcional, sem Docker para o console)

```bash
cd data-generator-console
npm install
npm start
```

Na tela você pode:

- Gerar JSON (quantidade, taxa de fraude, caminho)
- Ver estatísticas do arquivo
- Enviar lote para `POST /api/v1/transactions/batch`
- Iniciar / parar `demo_loop.sh` e ver logs
- Ver status da API (`/health`)

---

## 9. Script de setup (`setup.sh`)

Automatiza venv + `docker compose up`:

```bash
bash scripts/setup.sh
```

Requer Docker Desktop em execução.

---

## 10. Roteiro completo para apresentação (API + dados + Spark)

```bash
bash scripts/demo_full_stack.sh
```

Ou passo a passo:

```bash
docker compose up -d --build
docker compose ps   # api healthy, spark-master, jupyter
```

| Ordem | Onde | O que mostrar |
|-------|------|----------------|
| 0 | http://localhost:8880 | Portal — links para todas as telas |
| 1 | http://localhost:8080/swagger-ui.html | API Java — `analyze`, `batch`, health |
| 2 | http://localhost:8501 | Dashboard reagindo aos alertas |
| 3 | http://localhost:3333 | Gerar JSON → **Enviar lote** ou **Iniciar loop** |
| 4 | http://localhost:18080 | Spark UI — master/workers e jobs |
| 5 | Terminal | `docker compose --profile spark-run run --rm spark-job` → lake em `data/lake/` |
| 6 | http://localhost:8888 | Jupyter (`datamaster`) — `work/notebooks/`, script `spark_local_pipeline.py` |
| 7 | `cat data/lake/reports/dq_latest.json` | Data quality do pipeline batch |

Opcional: `docker compose logs -f data-console` durante o demo loop.

---

## 11. PostgreSQL — schema e dados de exemplo

Na primeira subida do Postgres (volume novo), rodam automaticamente `sql/schema.sql` e `sql/seed_demo.sql`.

**Se o volume já existia** (Postgres sem tabelas):

```bash
bash scripts/seed_postgres.sh
```

Inspecionar:

```bash
docker exec -it postgres psql -U admin -d fraud_detection -c "\dt"
docker exec -it postgres psql -U admin -d fraud_detection -c \
  "SELECT transaction_id, user_id, amount, fraud_score, is_fraud FROM transactions;"
docker exec -it postgres psql -U admin -d fraud_detection -c \
  "SELECT transaction_id, severity, status FROM fraud_alerts;"
```

> A API no perfil **`local`** não grava no Postgres; os dados acima são para **mostrar o OLTP na banca**. Transações ao vivo continuam na API (memória) + perfis no Mongo.

Recriar Postgres do zero (apaga dados):

```bash
docker compose down
docker volume rm datamaster_postgres_data 2>/dev/null || true
docker compose up -d postgres
```

---

## 12. Grafana — já configurado

Arquivos em `config/grafana/`:

- `provisioning/datasources/prometheus.yml` → Prometheus em `http://prometheus:9090`
- `dashboards/datamaster-api.json` → painel **DataMaster — API Fraude**

Após `docker compose up -d`:

1. http://localhost:3000 — login `admin` / `admin`
2. **Dashboards** → pasta **DataMaster** → **DataMaster — API Fraude**
3. Gere tráfego (console :3333 ou `curl` em `/analyze`) para ver gráficos de HTTP e JVM

Validar Prometheus: http://localhost:9090/targets → job `fraud-api` **UP**.

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `docker.sock` não encontrado | Abra o **Docker Desktop** e aguarde iniciar; teste com `docker ps` |
| Erro `bitnami/spark:latest` not found | Use a stack atual: imagem `bitnamilegacy/spark:3.5.5` no compose |
| Spark job falha “file not found” | Rode `generate_data.py` antes do `spark-job` |
| Jupyter não abre | Aguarde pull da imagem (~2 GB); token `datamaster` |
| Docker sem memória | Aumente RAM do Docker Desktop (8 GB+) ou `docker compose up api dashboard data-console spark-master spark-worker` sem Jupyter/Kafka |
| Prometheus: `not a directory` no mount | Docker criou `config/prometheus.yml` como **pasta** (arquivo não existia). Rode `rm -rf config/prometheus.yml` e suba de novo — o repo traz o `.yml` correto |
| Build da API falha no Docker | Rode `cd api-java && mvn -DskipTests package` e veja o erro; dependência `azure-eventhubs` inválida já foi removida |
| Porta **8080** em uso | Spark UI usa **18080** no host; pare outro processo ou `SERVER_PORT=8081` no Spring |
| Dashboard vazio | API deve responder em `/health`; envie dados via **analyze**, **batch** ou **demo_loop** |
| `demo_loop` falha no batch | `pip install requests` no venv ativo |
| Console Node: erro ao gerar | Use `python3` no PATH; arquivo de saída deve estar em `data/` |
| Maven não encontrado | Instale Maven ou use só Docker para a API |

### Logs

```bash
docker compose logs api --tail 80
docker compose logs dashboard --tail 40
```

---

## Azure (fora do escopo local)

- Infra na nuvem: `infrastructure/terraform/environments/dev` (modo econômico: `enable_analytics_stack = false`)
- API mínima na banca: `infrastructure/terraform/banca-minimo`
- Tutorial completo: `docs/TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md`

---

## Referências no repositório

| Documento | Conteúdo |
|-----------|----------|
| `docs/GUIA_APRESENTACAO_BANCA.md` | Roteiro terminal a terminal na banca |
| `docs/TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md` | Deploy Azure + CI |
| `api-java/` | Código da API Java |
| `data-generator-console/` | Painel Node do gerador |
