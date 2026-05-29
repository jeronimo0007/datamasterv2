# Roteiro — mostrar cada componente na banca

Objetivo: a banca vê **tudo no ar** no Docker **e** entende que **você sabe onde cada peça está** (papel, URL, par na nuvem).

Use com `portal/banca.html`, `portal/roteiro.html` e `docker compose ps`.

---

## Antes de entrar na sala (10 min)

```bash
docker compose up -d --build
bash scripts/run_demo.sh          # Mongo perfis + lake
docker compose ps                 # printar ou screenshot
```

Abas no navegador (fixar na barra):

| # | Aba | URL |
|---|-----|-----|
| 1 | Portal | http://localhost:8880 |
| 2 | Swagger | http://localhost:8080/swagger-ui.html |
| 3 | Dashboard | http://localhost:8501 |
| 4 | RabbitMQ | http://localhost:15672 |
| 5 | Grafana | http://localhost:3000 |
| 6 | Prometheus | http://localhost:9090 |
| 7 | Spark UI | http://localhost:18080 |
| 8 | Jupyter | http://localhost:8888/?token=datamaster |
| 9 | MinIO | http://localhost:9001 |

---

## Frase de abertura (30 s)

> “Na mesa eu subo a **stack completa** no Docker — mesma lógica do VPS em Kubernetes e da Azure no Terraform. Vou passar **componente a componente**: o que é, onde abre, e o equivalente na nuvem. Depois faço o fluxo de fraude ao vivo.”

Mostre: `docker compose ps` ou slide **Mapa nuvem** (`docs/arquitetura/datamaster-03-mapa.png`).

---

## Ordem do tour (≈ 12–15 min) — “sei onde está cada coisa”

### 1. Hub e camada online (produto)

| Componente | Container | Onde abrir | O que dizer |
|------------|-----------|------------|-------------|
| **Portal** | `fraud-portal` | :8880 | “Mapa da demo — links e credenciais.” |
| **API Java** | `fraud-api` | :8080/health · Swagger | “Motor de scoring — Spring Boot. Na Azure: Container Apps.” |
| **Dashboard** | `fraud-dashboard` | :8501 | “Operação — fraudes, LGPD, IA. Na Azure: Power BI / Fabric.” |
| **Console** | `fraud-data-console` | :3333 | “Simula o core — gera JSON e dispara batch/Spark.” |

**Prova rápida:** `curl -s localhost:8080/health` · abrir Swagger.

---

### 2. Dados e lake (engenharia)

| Componente | Container | Onde abrir | O que dizer |
|------------|-----------|------------|-------------|
| **MongoDB** | `mongodb` | Compass :27017 ou `profile-stats` na API | “Perfis `user_profiles` para o `/analyze`. Azure: Cosmos.” |
| **PostgreSQL** | `postgres` | `docker exec -it postgres psql -U admin -d fraud_detection -c '\dt'` | “OLTP — `transactions`, `fraud_alerts`. Azure: Postgres Flexible.” |
| **MinIO** | `minio` | Console :9001 (`minioadmin`) | “Lake objeto Bronze/Silver/Gold. Azure: ADLS.” |
| **Spark master** | `spark-master` | UI :18080 | “Batch distribuído. Azure: Databricks.” |
| **Spark worker** | `spark-worker` | (via UI master) | “Capacidade do cluster.” |
| **Jupyter** | `fraud-jupyter` | :8888 token `datamaster` | “Engenharia interativa — notebook DQ.” |

**Prova rápida:**

```bash
curl -s http://localhost:8080/api/v1/batch/profile-stats
docker exec minio mc ls local/ 2>/dev/null || echo "buckets: bronze silver gold no MinIO"
ls -la data/lake/ 2>/dev/null | head
```

---

### 3. Mensageria (streaming + alertas)

| Componente | Container | Onde abrir | O que dizer |
|------------|-----------|------------|-------------|
| **Zookeeper** | `zookeeper` | (interno) | “Suporte ao Kafka — em produção seria gerenciado.” |
| **Kafka** | `kafka` | `docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list` | “Streaming — narrativa Event Hubs / Kinesis.” |
| **RabbitMQ** | `fraud-rabbitmq` | UI :15672 `datamaster/datamaster` | “Fila de alerta de fraude — desacopla a API do e-mail.” |
| **email-worker** | `fraud-email-worker` | :8090/actuator/health | “Consumidor SMTP. Azure: Service Bus + Function.” |

**Prova rápida (Kafka):**

```bash
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

**Prova rápida (RabbitMQ):** depois de um `analyze` com fraude — fila `fraud.alert.email` na UI · `docker logs fraud-email-worker --tail 15`.

---

### 4. Cache e observabilidade

| Componente | Container | Onde abrir | O que dizer |
|------------|-----------|------------|-------------|
| **Redis** | `redis` | `docker exec redis redis-cli PING` → `PONG` | “Cache / sessão. Azure: Azure Cache for Redis.” |
| **Prometheus** | `prometheus` | :9090 → Status → Targets | “Coleta métricas da API. Azure: Monitor.” |
| **Grafana** | `grafana` | :3000 `admin/admin` → pasta **DataMaster** | “Dashboards de SRE. Azure: dashboards no Monitor.” |

**Prova rápida:**

```bash
docker exec redis redis-cli PING
```

No Prometheus: target `api` **UP**. No Grafana: dashboard **DataMaster — API Fraude**.

---

## Mapa mental (fale apontando)

```text
[Console/Dashboard] → API :8080 → Mongo (perfil)
                         │ is_fraud
                         └── RabbitMQ → email-worker

[Kafka] ← streaming (Event Hubs)     [Spark/Jupyter] → lake (MinIO + data/lake/)
[Postgres] ← OLTP                    [Redis] ← cache

[Prometheus] → [Grafana]             [Portal :8880] = índice
```

Imagem: [datamaster-00-visao-geral.png](../arquitetura/datamaster-00-visao-geral.png)

---

## Depois do tour — demo de negócio (≈ 20 min)

Siga [CHECKLIST_DEMO_BANCA.md](CHECKLIST_DEMO_BANCA.md) T3–T7: fluxo completo, analyze, dashboard, LGPD, RabbitMQ opcional.

---

## Comando único — status de tudo

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

Ou:

```bash
bash scripts/status-stack.sh
```

---

## Se perguntarem “cadê o X?”

| Pergunta | Resposta curta |
|----------|----------------|
| Onde está o lake? | `data/lake/` no host + buckets MinIO :9001 |
| API usa Postgres? | Demo scoring usa Mongo; Postgres tem schema demo OLTP |
| Kafka na demo online? | Console chama API direto; Kafka é par streaming |
| E-mail saiu? | Rabbit UI + logs `fraud-email-worker` (precisa SMTP no `.env`) |
| Equivalente AWS? | Slide mapa + [MAPA_LOCAL_AZURE.md](../../infrastructure/MAPA_LOCAL_AZURE.md) |

---

## Checklist “mostrei tudo”

| ☐ | Componente |
|---|------------|
| ☐ | Portal :8880 |
| ☐ | API :8080 + Swagger |
| ☐ | Dashboard :8501 |
| ☐ | Console :3333 |
| ☐ | Mongo (profile-stats ou Compass) |
| ☐ | Postgres (`\dt`) |
| ☐ | MinIO :9001 |
| ☐ | Spark :18080 |
| ☐ | Jupyter :8888 |
| ☐ | Kafka (list topics) |
| ☐ | RabbitMQ :15672 |
| ☐ | email-worker :8090/health |
| ☐ | Redis PING |
| ☐ | Prometheus :9090 |
| ☐ | Grafana :3000 |

[← Operação](README.md) · [CHECKLIST_DEMO_BANCA](CHECKLIST_DEMO_BANCA.md)
