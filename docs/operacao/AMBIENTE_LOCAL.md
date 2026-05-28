# Ambiente local (Docker Compose)

Guia **manual** para rodar o DataMaster na sua máquina. Detalhes de cada serviço: [QUICK_START.md](QUICK_START.md) e [SERVICOS_DOCKER.md](SERVICOS_DOCKER.md).

---

## 1. Pré-requisitos

- Docker Desktop ou Docker Engine + **Compose v2** (`docker compose version`)
- **~8 GB RAM** livres para a stack completa (ou suba só API + dashboard + console — ver §6)
- Git clone do repositório

---

## 2. Configurar `.env` (uma vez)

Na **raiz do projeto**:

```bash
cp .env.example .env
```

Edite `.env`:

| Variável | Obrigatório | Uso |
|----------|-------------|-----|
| `DEEPSEEK_API_KEY` | Não | Assistente de IA na API e no dashboard |
| `DOCKER_HOST_WORKSPACE` | **Mac** (recomendado) | Caminho **absoluto** do repo no host — o console (:3333) usa o socket Docker para `spark-job` |

Exemplo no Mac:

```bash
# .env
DEEPSEEK_API_KEY=sk-...
DOCKER_HOST_WORKSPACE=/Users/seu.usuario/projetos/datamaster
```

No Linux, em geral **não** precisa de `DOCKER_HOST_WORKSPACE` (o console detecta o mount).

> O arquivo `.env` está no `.gitignore` — nunca commite chaves.

---

## 3. Subir a stack

**Opção A — script (recomendado):**

```bash
bash scripts/up-local.sh
```

**Opção B — Makefile:**

```bash
make up-local
```

**Opção C — comando direto:**

```bash
docker compose up -d --build
```

Confira:

```bash
docker compose ps
curl -s http://localhost:8080/health
```

---

## 4. URLs (localhost)

| Serviço | URL |
|---------|-----|
| Portal | http://localhost:8880 |
| API (Swagger) | http://localhost:8080/swagger-ui.html |
| Dashboard | http://localhost:8501 |
| Console gerador | http://localhost:3333 |
| Grafana | http://localhost:3000 (`admin` / `admin`) |
| Prometheus | http://localhost:9090 |
| Spark UI | http://localhost:18080 |
| Jupyter | http://localhost:8888 (token: `datamaster`) |
| MinIO console | http://localhost:9001 (`minioadmin` / `minioadmin`) |
| MongoDB Compass | `mongodb://admin:admin123@localhost:27017/?authSource=admin` |

---

## 5. Demo com dados (opcional)

Fluxo completo (JSON + Mongo + lake Spark):

```bash
bash scripts/run_demo.sh
```

Jobs sob demanda (não sobem no `up` padrão):

```bash
# Perfis Mongo + transactions.json
docker compose --profile batch run --rm batch-prep

# Pipeline Medallion → data/lake/
docker compose --profile spark-run run --rm spark-job
```

---

## 6. Stack reduzida (máquina com pouca RAM)

```bash
docker compose up -d --build api dashboard data-console portal mongodb spark-master spark-worker
```

Sem Jupyter, Kafka, Grafana, etc.

---

## 7. Parar e limpar

```bash
docker compose down
# volumes também:
docker compose down -v
```

---

## 8. Problemas comuns

| Sintoma | Solução |
|---------|---------|
| Console não roda `spark-job` no Mac | Defina `DOCKER_HOST_WORKSPACE` no `.env` com caminho absoluto do repo |
| `init_mongo.js` / Mongo não inicia | Confirme que `scripts/init_mongo.js` é **arquivo**, não pasta; `docker compose up -d mongodb` |
| API não fica healthy | `docker compose logs api --tail 80` — aguarde ~60s no primeiro build |
| Porta em uso | `docker compose down` ou pare outro processo na porta (8080, 27017, …) |
| Pouca memória no Docker Desktop | Settings → Resources → 8 GB+ |

---

## Diferença em relação ao VPS

| | Local | VPS |
|---|--------|-----|
| Compose | só `docker-compose.yaml` | `docker-compose.yaml` + `docker-compose.vps.yaml` |
| Kafka externo | `localhost:9092` (padrão) | `KAFKA_EXTERNAL_HOST` = IP Tailscale |
| Deploy | manual na máquina | branch `vps` + CI ou script no servidor |

Ver [deploy no VPS (Kubernetes)](../deploy/DEPLOY_K8S.md) · [checklist da banca](CHECKLIST_DEMO_BANCA.md).
