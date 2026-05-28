# Checklist — testar antes da apresentação

Use com **`portal/banca.html`** (slides) e **`portal/roteiro.html`** (cola verbal).  
Ambiente alvo da demo: **Docker Compose local** (não dependa do Terraform na hora da banca).

---

## 0. Pré-voo (5 min)

```bash
cp .env.example .env
# Opcional: DEEPSEEK_API_KEY, SMTP_* (para T4c e-mail)
docker compose up -d --build
docker compose ps   # tudo healthy ou Up (api pode levar ~60s no 1º build)
```

| URL | Esperado |
|-----|----------|
| http://localhost:8880 | Portal |
| http://localhost:8080/health | `{"status":"UP"}` ou equivalente |
| http://localhost:8090/actuator/health | email-worker UP |
| http://localhost:15672 | RabbitMQ UI (login `datamaster` / `datamaster`) |

---

## 1. Trilha obrigatória (slides T0–T7)

| # | Teste | Comando / ação | OK? |
|---|--------|----------------|-----|
| **T0** | Stack no ar | `docker compose up -d --build` | ☐ |
| **T1** | Health API | `curl -s http://localhost:8080/health` | ☐ |
| **T2** | Swagger | Abrir http://localhost:8080/swagger-ui.html | ☐ |
| **T3** | Batch + Mongo | `bash scripts/run_demo.sh` **ou** portal → **Executar fluxo completo** | ☐ |
| **T3b** | Perfis | `curl -s http://localhost:8080/api/v1/batch/profile-stats` → `profileCount` > 0 | ☐ |
| **T4** | Dashboard | http://localhost:8501 — fraudes, liberar, opinião IA | ☐ |
| **T4b** | LGPD | Aba **LGPD / mascaramento** — aplicar máscara | ☐ |
| **T5–T6** | Analyze + perfil | POST abaixo → `anomaly_reasons`, score | ☐ |
| **T7** | Batch API | Swagger `POST /api/v1/transactions/batch` ou console :3333 | ☐ |

**Analyze (T5–T6)** — copiar do slide 13:

```bash
curl -s -X POST http://localhost:8080/api/v1/transactions/analyze \
  -H "Content-Type: application/json" \
  -d '{"amount":50000,"merchant_category":"Viagem","user_country":"BR","merchant_country":"US","payment_method":"CREDIT_CARD","hour":3,"is_weekend":1,"is_international":1,"user_id":"user_1001"}' | python3 -m json.tool
```

Fraude explícita (T4c / fila): amount alto, categoria atípica, `user_id` sem perfil ou payload que passe de **0,74** — conferir `is_fraud: true`.

---

## 2. Opcional (T8–T12, se sobrar tempo)

| # | Teste | Ação | OK? |
|---|--------|------|-----|
| **T4c** | RabbitMQ + e-mail | Após fraude: fila `fraud.alert.email` na UI :15672 · `docker logs fraud-email-worker --tail 30` | ☐ |
| **T8** | Kafka | `docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list` | ☐ |
| **T9** | Jupyter | http://localhost:8888/?token=datamaster | ☐ |
| **T10** | Batch script | Mencionar `scripts/batch_dataprep_mongo.py` (já rodou no T3) | ☐ |
| **T11** | Observabilidade | Prometheus :9090 · Grafana :3000 — dashboard **DataMaster** | ☐ |
| **T12** | draw.io | `docs/arquitetura/datamaster-04-docker-compose.drawio` | ☐ |

**T4c SMTP:** sem `SMTP_HOST` no `.env` o worker sobe mas só loga aviso — para demo de e-mail real, preencha SMTP no `.env` e reinicie `email-worker`.

---

## 3. O que falar se perguntarem da nuvem

| Peça na mesa (Compose/K8s) | Azure `terraform/apresentacao` | AWS `terraform/aws` |
|----------------------------|-------------------------------|---------------------|
| Kafka | Event Hubs | Kinesis / MSK (**não no TF aws atual**) |
| RabbitMQ + email-worker | Service Bus + Function (**não no TF**) | SQS + Lambda (**não no TF**) |
| Mongo `user_profiles` | Cosmos (**SQL API no TF**, não Mongo API) | DocumentDB (**não no TF**) |
| Spark / Jupyter | Databricks (**opcional** `enable_analytics_stack`) | EMR (**não no TF**) |
| Streamlit | Power BI / Fabric (narrativa) | QuickSight (narrativa) |
| Prometheus/Grafana | Monitor + App Insights | CloudWatch (**não no TF**) |
| API :8080 | Container Apps + ACR | ECS/EKS (**não no TF**) |
| Lake / MinIO | ADLS bronze/silver/gold | S3 bucket (**só isso no TF aws**) |
| Postgres, Redis | Postgres Flexible (**sim**) · Redis (**não**) | RDS (**não no TF**) |

**Frase honesta (slide “recorte”):** o Compose é o laboratório completo; o Terraform Azure sobe o **esqueleto de plataforma** (lake, streaming, API, Cosmos, Postgres, Monitor); o Terraform AWS hoje é **mínimo (S3)** — o par AWS você cita na tabela do slide 14.

---

## 4. VPS (se for mostrar homelab)

Não é a trilha da banca no projetor — use só se a banca pedir.

- Doc: [../deploy/DEPLOY_K8S.md](../deploy/DEPLOY_K8S.md)
- Portal: `http://<IP-VPS>:30880`
- Mesma trilha T1–T7 com NodePorts

---

## 5. Plano B (se algo cair)

1. Só **API + Swagger** + um `POST /analyze`
2. Narrar batch/Mongo/Kafka/Rabbit como **arquitetura** (draw.io slide 4b)
3. Terraform como **declarativo de referência**, sem `apply` ao vivo

[← Operação](README.md) · [AMBIENTE_LOCAL](AMBIENTE_LOCAL.md) · [SERVICOS_DOCKER](SERVICOS_DOCKER.md)
