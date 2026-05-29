# Checklist — testar antes da apresentação

Use com **`portal/banca.html`** (slides) e **`portal/roteiro.html`** (cola verbal).

**Mostrar todos os componentes (RabbitMQ, Kafka, Grafana…):** [ROTEIRO_TOUR_COMPONENTES.md](ROTEIRO_TOUR_COMPONENTES.md) · `bash scripts/status-stack.sh`

**Estratégia:** demo **ao vivo = Docker local (stack completa)** · em paralelo **VPS (k3s)** + **Azure (`terraform/apresentacao`)** · **AWS = só mapa** multicloud (sem apply).

---

## 0. T0-pré — disparar VPS + Azure (30–60 min antes)

```bash
bash scripts/pre-banca-paralelo.sh   # cola dos comandos
```

| Frente | Ação | Conferir |
|--------|------|----------|
| **VPS** | `git push origin vps` ou `deploy-kubernetes-server.sh` no servidor | `kubectl get pods -n datamaster` · portal `:30880` |
| **Azure** | `cd infrastructure/terraform/apresentacao && terraform apply` | outputs: RG, FQDN API, ADLS, Event Hubs |
| **AWS** | Não aplicar | Slide mapa multicloud na banca |

---

## 1. Pré-voo local (5 min)

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

## 2. Trilha obrigatória (slides T0–T7)

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

## 3. Opcional (T8–T12, se sobrar tempo)

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

## 4. O que falar se perguntarem da nuvem

| Peça na mesa (Compose/K8s) | Azure `terraform/apresentacao` | AWS `terraform/aws` |
|----------------------------|-------------------------------|---------------------|
| Kafka | Event Hubs | Kinesis / MSK (**não no TF aws atual**) |
| RabbitMQ + email-worker | Service Bus + Function (**não no TF**) | SQS + Lambda (**não no TF**) |
| Mongo `user_profiles` | Cosmos (**SQL API no TF**, não Mongo API) | DocumentDB (**não no TF**) |
| Spark / Jupyter | **Databricks** + Synapse (`enable_analytics_stack = true` padrão) | EMR (**não no TF aws**) |
| Streamlit | Power BI / Fabric (narrativa) | QuickSight (narrativa) |
| Prometheus/Grafana | Monitor + App Insights | CloudWatch (**não no TF**) |
| API :8080 | Container Apps + ACR | ECS/EKS (**não no TF**) |
| Lake / MinIO | ADLS bronze/silver/gold | S3 bucket (**só isso no TF aws**) |
| Postgres, Redis | Postgres Flexible (**sim**) · Redis (**não**) | RDS (**não no TF**) |

**Frase na banca:** “Local eu opero tudo ao vivo; no VPS e na Azure o **mesmo desenho** está provisionado — AWS eu mostro só o **mapa de equivalência**.”

Detalhe técnico (se perguntarem): Azure TF não inclui RabbitMQ/Streamlit — local e VPS sim; na Azure o par é Service Bus + Power BI na narrativa.

---

## 5. Mostrar VPS/Azure durante a demo

- Aba: GitHub Actions (workflow `Deploy → VPS`)
- Terminal: `kubectl get pods -n datamaster -w`
- Azure Portal: resource group `rg-fraud-apresentacao-*` · Container App · ADLS

---

## 6. Plano B (se algo cair)

1. Só **API + Swagger** + um `POST /analyze`
2. Narrar batch/Mongo/Kafka/Rabbit como **arquitetura** (draw.io slide 4b)
3. Terraform como **declarativo de referência**, sem `apply` ao vivo

[← Operação](README.md) · [AMBIENTE_LOCAL](AMBIENTE_LOCAL.md) · [SERVICOS_DOCKER](SERVICOS_DOCKER.md)
