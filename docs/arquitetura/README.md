# Arquitetura DataMaster — draw.io

Diagramas versionados para a **banca** e para documentação técnica. Complementam o Mermaid dos slides (`portal/banca.html`) com detalhe de containers, batch e mapa Azure/AWS/local.

## Como abrir

1. [app.diagrams.net](https://app.diagrams.net)
2. **File → Open from → Device**
3. Selecione um `.drawio` desta pasta (ou abra `datamaster-azure-aws-local.drawio` e use as **abas** na barra inferior)

Exportar PNG/SVG: **File → Export as** (útil se o projetor não tiver internet).

## PNG (README e slides)

| Imagem | Uso |
|--------|-----|
| [datamaster-01-batch-medallion.png](datamaster-01-batch-medallion.png) | **Batch Medallion** — slide 7 banca · README |
| [datamaster-02-online-gateway.png](datamaster-02-online-gateway.png) | **Online** — slide 6b banca · README |
| [datamaster-00-visao-geral.png](datamaster-00-visao-geral.png) | Batch + online — visão geral |
| [datamaster-03-mapa.png](datamaster-03-mapa.png) | Mapa Azure · AWS · Local |
| [datamaster-01-batch-medallion.svg](datamaster-01-batch-medallion.svg) | Versão vetorial (legado portal) |

Também no [README da raiz](../../readme.md#diagramas-visão-geral-e-mapa-nuvem) e no slide **7** de `portal/banca.html`.

## Arquivos e quando usar na apresentação

| Arquivo | Slide `banca.html` / roteiro | Quando projetar | Conteúdo |
|---------|------------------------------|-----------------|----------|
| `datamaster-00-visao-geral.drawio` | Após visão pipeline | Abertura ou “como tudo se conecta” | Batch + online numa página; Lambda batch vs speed |
| `datamaster-01-batch-medallion.drawio` | **Slide 7** · banca | Processamento batch (estilo Azure) | Ingest · Store · Process · Serve · Governança — **editável no draw.io** |
| `datamaster-01-batch-medallion.svg` | Slide 7 · portal | Mesmo desenho (PNG/SVG export) | Gerado a partir do `.drawio` ou script |
| `datamaster-01-batch.drawio` | Tópico batch / slide 7b | Antes de `run_demo.sh` | Histórico → dataprep → `user_profiles` · Spark → lake |
| `datamaster-02-online.drawio` | Demo ao vivo | Durante console + API | Canal → **API :8080** direto; Mongo no `/analyze` |
| `datamaster-02-online-gateway.drawio` | **Banca online** | Arquitetura microserviços | LB + API Gateway **apagados** (não impl.) · caminho demo em verde |
| `datamaster-03-mapa.drawio` | Mapa Azure (slide 14) | Pergunta “qual serviço na nuvem?” | Equivalência local ↔ Azure (detalhe por caixa) |
| `datamaster-04-docker-compose.drawio` | Slide **4b** | “O que sobe no `docker compose`” | Cada serviço, porta e seta de quem chama quem |
| `datamaster-azure-aws-local.drawio` | Slide **4b** / encerramento | Fechamento banca | Abas: Azure, AWS, mesa local no mesmo arquivo |

**Cola verbal:** `portal/roteiro.html` — seção «Diagramas draw.io» (espelha o slide 4b).

**Slides no projetor:** http://localhost:8880/banca.html (após `docker compose up -d portal`).

## Fluxo online (demo real)

Na **mesa**, o canal **não passa pelo Kafka** no caminho crítico:

```
Console :3333  ──POST /analyze──►  API :8080  ──►  MongoDB (perfil batch)
Dashboard :8501 ──GET/POST──────►       │ is_fraud
Swagger/curl  ──────────────────►       ├──►  RabbitMQ ──► email-worker (SMTP)
                                        └──►  Streamlit (filtro, liberar, opinião IA)
```

**Kafka :9092** sobe no Compose para narrativa de **Event Hubs** / streaming; console e painel chamam a **API direto**.

**RabbitMQ** — fila `fraud.alert.email` quando `is_fraud`; ver [../online/FRAUD_EMAIL_RABBITMQ.md](../online/FRAUD_EMAIL_RABBITMQ.md). Índice: [../README.md](../README.md).

## Fluxo batch (demo)

```
data/transactions.json
    → batch_dataprep_mongo.py (perfis user_profiles)
    → spark_local_pipeline.py (Bronze / Silver / Gold em data/lake/)
```

Atalho: `bash scripts/run_demo.sh` ou botão **Executar fluxo completo** no portal (:8880).

## Docker Compose (`04-docker-compose`)

Três faixas no diagrama:

1. **Online** — portal, data-console, dashboard → **api** → mongodb  
2. **Batch** — batch-prep, spark, jupyter, minio → mongodb / lake  
3. **Infra** — postgres, redis, prometheus, grafana (Postgres/Grafana para métricas e painéis extras)

## Regenerar a partir do repositório

```bash
python3 scripts/generate_architecture_drawio.py
```

Isso recria os `.drawio` a partir dos templates do script — use após mudar `docker-compose.yaml` ou nomes de serviços. Inclui `datamaster-01-batch-medallion.drawio` (estilo Azure).

## Referências relacionadas

- Mapa texto local ↔ Azure: [infrastructure/MAPA_LOCAL_AZURE.md](../../infrastructure/MAPA_LOCAL_AZURE.md)
- README do projeto: [readme.md](../../readme.md) — seção «Apresentação na banca»
