# Serviços Docker — o que é cada um e como explicar na banca

Referência da stack definida em `docker-compose.yaml`. Use como cola ao apresentar ou ao responder “para que serve cada container?”.

**Hub local:** http://localhost:8880 · **Credenciais:** ver portal ou [QUICK_START.md](QUICK_START.md).

---

## Camada visível na demo (produto)

| Serviço | Imagem / build | Porta | O que é | Como explicar na banca |
|---------|----------------|-------|---------|------------------------|
| **portal** | `datamaster-portal` (nginx) | **8880** → 80 | Página inicial com links, credenciais e passos | *“Hub da apresentação — mapa para API, dashboard, slides e roteiro; não é o motor de fraude.”* |
| **api** | `datamaster-api` (Spring Boot, perfil `local`) | **8080** | API REST: analyze, batch, alertas, health, métricas | *“Coração operacional: recebe JSON, calcula score e devolve decisão em tempo quase real. Em produção: API Gateway + LB na frente.”* |
| **dashboard** | `datamaster-dashboard` (Streamlit) | **8501** | Painéis de fraude, KPIs e alertas | *“Camada de negócio/ops: consome a API — o que o analista de risco vê.”* |
| **data-console** | `datamaster-data-console` (Node.js) | **3333** | Gera `data/transactions.json`, envia lotes à API, loop de demo | *“Simula carga do core bancário / testes sem sistema legado real.”* |

**Frase de amarração:** *“Portal orienta; console gera dado; API decide; dashboard visualiza.”*

**URLs úteis**

- Swagger: http://localhost:8080/swagger-ui.html  
- Health: http://localhost:8080/health  

---

## Processamento batch e analítico

| Serviço | Imagem | Porta | O que é | Como explicar na banca |
|---------|--------|-------|---------|------------------------|
| **spark-master** | `bitnamilegacy/spark:3.5.5` | **7077** (cluster), **18080** (UI) | Nó master do cluster Spark | *“Orquestra jobs batch — equivalente conceitual a Databricks / EMR.”* |
| **spark-worker** | `bitnamilegacy/spark:3.5.5` | (rede interna) | Worker — executa tarefas do master | *“Capacidade distribuída do pipeline Medallion (Bronze → Silver → Gold).”* |
| **jupyter** | `jupyter/pyspark-notebook:spark-3.5.0` | **8888** | Notebook PySpark (`notebooks/01_dataprep_dq.py`) | *“Engenharia de dados interativa: prep, DQ e camadas no lake.”* Token: `datamaster` |

**Job opcional (não sobe com `docker compose up -d` padrão)**

```bash
docker compose --profile spark-run run --rm spark-job
```

- Lê `data/transactions.json` e grava o lake em `data/lake/` via `scripts/spark_local_pipeline.py`.

**Frase:** *“API = tempo real; Spark + Jupyter = batch e lakehouse local.”*

---

## Mensageria (streaming e alertas)

| Serviço | Imagem | Porta | O que é | Como explicar na banca |
|---------|--------|-------|---------|------------------------|
| **zookeeper** | `confluentinc/cp-zookeeper:7.5.0` | **2181** (interno) | Coordenação do Kafka (modo Zookeeper) | *“Infra de suporte ao broker; em produção costuma ser serviço gerenciado.”* |
| **kafka** | `confluentinc/cp-kafka:7.5.0` | **9092** (host), **29092** (rede Docker) | Fila de eventos: tópicos, partições, consumer groups | *“Ingestão streaming. Azure: Event Hubs; AWS: Kinesis / MSK.”* |
| **rabbitmq** | `rabbitmq:3.13-management-alpine` | **5672** (AMQP), **15672** (UI) | Fila `fraud.alert.email` — alerta de fraude por e-mail | *“Desacoplamento: API publica; worker envia SMTP sem bloquear o HTTP. Azure: Service Bus; AWS: SQS.”* |
| **email-worker** | `datamaster-email-worker` (build) | **8090** | Consumidor Spring Boot + JavaMail | *“Worker assíncrono — health em `/actuator/health`. Ver [FRAUD_EMAIL_RABBITMQ.md](FRAUD_EMAIL_RABBITMQ.md).”* |

**RabbitMQ — teste rápido**

- UI: http://localhost:15672 (`datamaster` / `datamaster` por padrão)
- Após `analyze` com fraude: fila `fraud.alert.email` e `docker logs fraud-email-worker --tail 30`

**Teste rápido**

```bash
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

- Dentro da rede Docker: `kafka:29092`  
- No Mac: `localhost:9092`  

---

## Armazenamento e cache (infra de plataforma)

Na demo com perfil **`local`**, a API usa **estado em memória**. Estes serviços estão no compose como **infra pronta** / narrativa de produção / perfil enterprise:

| Serviço | Imagem | Porta | O que é | Como explicar na banca |
|---------|--------|-------|---------|------------------------|
| **postgres** | `postgres:14` | **5432** | Banco relacional (OLTP) | *“Transações, alertas, auditoria. Azure: PostgreSQL flexível; AWS: RDS.”* DB: `fraud_detection`, user `admin` / `admin123` |
| **mongodb** | `mongo:6.0` | **27017** | Banco `fraud_detection` (coleções `user_profiles`, `batch_runs`) | user `admin` / `admin123`, authSource `admin` — ver [MONGODB_COMPASS.md](MONGODB_COMPASS.md) |
| **redis** | `redis:7-alpine` | **6379** | Cache em memória | *“Cache de scores, sessões, rate limit. Azure: Azure Cache for Redis; AWS: ElastiCache.”* |
| **minio** | `minio/minio` | **9000** (API), **9001** (console) | Object storage tipo S3 | *“Data Lake local: Bronze/Silver/Gold em arquivos. Equivalente ADLS / S3.”* `minioadmin` / `minioadmin` |

**Frase honesta:** *“Na mesa a API é leve e em memória; Postgres, Mongo, Redis e MinIO mostram o desenho completo com persistência e lake.”*

---

## Observabilidade

| Serviço | Imagem | Porta | O que é | Como explicar na banca |
|---------|--------|-------|---------|------------------------|
| **prometheus** | `prom/prometheus` | **9090** | Coleta de métricas (pull) | *“Pilar métricas: latência, throughput, erros. Azure: Monitor; AWS: CloudWatch.”* |
| **grafana** | `grafana/grafana` | **3000** | Dashboards sobre métricas | *“Visualização para SRE/ops.”* Login: `admin` / `admin` |

Config Prometheus: `config/prometheus.yml`.

Grafana (provisionamento automático):

- Datasource: `config/grafana/provisioning/datasources/prometheus.yml`
- Dashboard: `config/grafana/dashboards/datamaster-api.json` (pasta **DataMaster** na UI)
- Reinicie após mudanças: `docker compose up -d grafana`

Postgres (schema + seed na primeira subida do volume):

- `sql/schema.sql` — tabelas `transactions`, `fraud_alerts`, `audit_events`
- `sql/seed_demo.sql` — 5 transações e alertas de exemplo
- Volume antigo: `bash scripts/seed_postgres.sh`

**Frase:** *“Prometheus coleta; Grafana exibe; Postgres mostra o desenho OLTP.”*

---

## Diagrama mental

```text
[data-console] ──JSON──► [api] ◄──HTTP── [dashboard]
                              │ is_fraud
                              ├──► [rabbitmq] ──► [email-worker] ──► SMTP
         [kafka] ◄── streaming (padrão Event Hubs)
         [spark]  ◄── batch Medallion ◄── data/transactions.json
         [postgres | mongo | redis | minio] ◄── persistência / lake
         [prometheus + grafana] ◄── observabilidade
[portal] = índice da demo (8880)
```

---

## Ordem sugerida na apresentação

1. **portal** (8880)  
2. **api** (8080) — health + Swagger  
3. **dashboard** (8501) + **data-console** (3333)  
4. **kafka** (+ zookeeper) — streaming  
4b. **rabbitmq** (UI **15672**) + **email-worker** — alerta assíncrono (opcional)  
5. **spark-master** (UI em **18080**) + worker — batch  
6. **prometheus** (9090) + **grafana** (3000)  
7. **postgres / mongo / redis / minio** — camada de dados (desenho produção)  
8. **jupyter** (8888) — se mostrar notebook ao vivo  

---

## Cola de uma linha por serviço

| Serviço | Uma linha |
|---------|-----------|
| portal | Mapa da demo |
| api | Motor de fraude REST (Java) |
| dashboard | Painel Streamlit |
| data-console | Gerador/simulador de transações |
| kafka | Fila de eventos (streaming) |
| rabbitmq | Fila de alerta de fraude (e-mail) |
| email-worker | Consumidor SMTP assíncrono |
| zookeeper | Suporte ao Kafka |
| spark-master / worker | Processamento batch distribuído |
| jupyter | Notebook PySpark |
| postgres | Banco relacional transacional |
| mongodb | Banco de documentos |
| redis | Cache |
| minio | Lake em object storage |
| prometheus | Métricas |
| grafana | Dashboards de métricas |

---

## Comandos úteis

```bash
# Subir stack
docker compose up -d --build

# Status
docker compose ps

# Logs Kafka
docker logs kafka --tail 30

# Parar tudo
docker compose down
```

---

## Documentação relacionada

- [QUICK_START.md](QUICK_START.md) — URLs e passo a passo  
- [INDICE_DOMINIOS.md](INDICE_DOMINIOS.md) — docs agrupadas: dados · observabilidade · online  
- [FRAUD_EMAIL_RABBITMQ.md](FRAUD_EMAIL_RABBITMQ.md) — RabbitMQ + e-mail de fraude  
- [banca/ESTUDO_BANCA.md](banca/ESTUDO_BANCA.md) — plano de estudo  
- [banca/APRESENTACAO_BANCA.md](banca/APRESENTACAO_BANCA.md) — roteiro da apresentação  
