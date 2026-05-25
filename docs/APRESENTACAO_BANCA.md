# Apresentacao para Banca - Sistema de Deteccao de Fraudes Bancarias

## Informacoes Gerais
- **Duracao da apresentacao (cronometrada):** **90 minutos** = Partes 1 + 2 + 3 (slides + demos ao vivo + explicacao de codigo).
- **Formato:** Apresentacao + demonstracao pratica + discussao com a banca dentro dessa janela.
- **Ferramentas:** Este documento + **preferencia: tudo via Docker Compose** (API, dashboard, Kafka, Prometheus, Grafana, etc.) — ver tambem `docs/GUIA_APRESENTACAO_BANCA.md` se precisar de terminais sem Docker.
- **Parte 4 deste documento (perguntas e respostas preparadas):** **nao entra nos 90 minutos** — e material de **estudo e ensaio** para depois da apresentacao ou para treinar respostas; use como crib sheet, nao como roteiro obrigatorio no palco.

### Posicionamento para a banca (Data Master / Eng. de Dados Senior)

**Mensagem central:** o dominio é **fraude bancaria como caso de uso**, mas o que voce esta avaliando e o desenho de **plataforma de dados**: ingestao, armazenamento em camadas, qualidade, governanca, ML operacional, seguranca/LGPD, observabilidade, custo e escalabilidade.

**O que demonstrar além do slide:**
- Pensamento em **SLA, custo (FinOps)** e **trade-offs** (latencia vs custo vs complexidade).
- **Sequencia tecnologica** sempre com “**problema → requisito → opcao → escolha → risco**”.
- Honestidade: o repositorio mostra **um recorte executavel** em Docker (API, dashboard, mensageria local, observabilidade); a narrativa Azure (Event Hubs, Purview, Databricks) descreve o **alvo de producao** — deixe explicito que Event Hubs na Azure e o **Kafka do compose** seguem o mesmo *pattern* producer/consumer/particoes.

**Regra ao falar de Azure:** na mesma frase ou logo em seguida, cite o **equivalente AWS** (tabela no Slide 11 e secoes abaixo). Isso mostra visao **multi-cloud**, nao só vendor unico.

---

## GUIA: SEU RESUMO x ONDE MOSTRAR NA DEMO x AZURE x AWS

Use como **roteiro de conhecimento**: cada bloco liga conceito → **slide/parte** → **artefato no repo** (ou “só conceito”, se nao existir codigo). Itens **fora do escopo do repositorio** ficam como **narrativa de producao** — diga isso explicitamente na banca.

### 1. Arquitetura de dados (base)

| Tema (resumo) | Azure | AWS | Onde encaixar na apresentacao |
|---------------|-------|-----|-------------------------------|
| **Data Lake** — bruto, schema-on-read, risco de “swamp” | **ADLS Gen2** | **S3** (+ **Lake Formation** governanca) | Slide 5, 9; codigo `src/data_storage/datalake_client.py`; dados simulados `data/transactions.json` como analogia **landing** |
| **Warehouse** — schema-on-write, BI | **Synapse Dedicated** / **Fabric Warehouse** | **Redshift** / **Athena** sobre Iceberg | Slide 5; **Power BI**: `fraud_dashboard.pbix` (mostrar arquivo); na demo ao vivo o dashboard e **Streamlit**, nao Redshift |
| **Lakehouse** — lake + transacoes/qualidade | **OneLake / Fabric** com **Delta** | **S3 + Delta Lake** / **Glue** + **Athena** | Slide 9 + **fala**: camada **Gold** em Delta no Databricks; *neste repo* PySpark leitura **Parquet/JSON** no notebook — Delta seria o proximo passo |
| **Medalhao** Bronze / Silver / Gold | Pastas `bronze/` · `silver/` · `gold/` no ADLS | Mesmo padrao em S3 | **Slide 9**; `notebooks/01_dataprep_dq.py` + `src/data_architecture/medallion.py` + `config/medallion.yaml` |
| **Lambda / Kappa / Mesh** | Conceito multi-servico | Idem | **Slides 5 e 8** — *conceito only*; diga que **Kafka no Docker** ilustra parte **streaming**; **Mesh** como organizacao de times (sem codigo) |
| **Streaming** — particao, offset, consumer group | **Event Hubs** | **Kinesis Data Streams** / **MSK** (Kafka gerenciado) | **Slide 10**; codigo `event_hub_producer.py` / `consumer.py` + **Kafka console** no compose |
| **Checkpoint / DLQ / backpressure** | Checkpoint em **Blob** (SDK consumer) | **Kinesis checkpoints** / **SQS DLQ** | **Slide 10** ao abrir `BlobCheckpointStore` e `update_checkpoint`; DLQ/backpressure = **fala** de desenho (nao implementado no consumer demo) |

### 2. Apache Spark

| Tema | Azure | AWS | Onde encaixar |
|------|-------|-----|----------------|
| Cluster gerenciado | **Azure Databricks** | **EMR** ou **Glue** (Spark serverless) | Slide 8, 9; **notebook** `01_dataprep_dq.py` — `SparkSession`, `DataFrame`, transforms (`filter`/`groupBy` implicitos nas agregacoes) |
| Lazy eval / DAG / Catalyst | Motor Spark (mesmo) | Idem | **Fala** ao mostrar notebook: “transformacoes ate o `count()` ou `write`” |
| Shuffle / particao / broadcast | Config `spark.sql.adaptive` no notebook | Idem | **Linhas de config** no topo do `01_dataprep_dq.py` (`adaptive.enabled`) — aponte no editor |

### 3. Storage e formatos

| Formato | Uso no discurso | Demo / codigo |
|---------|-----------------|---------------|
| **Parquet** | Padrao Silver/Gold | Notebook le `parquet` no path `raw`; ADLS upload via `datalake_client.py` |
| **JSON** | Bronze / APIs | `generate_data.py`, `transactions.json`, adaptadores `transaction_adapters.py` |
| **Avro** | Streaming / schema evolution | **Conceito** + ligar a Event Hubs/Kinesis na fala |
| **Delta** | ACID, time travel | **Azure/AWS**: **Delta Lake** sobre ADLS ou S3; *repo* menciona narrativa Databricks — honestidade se nao houver tabelas Delta commitadas aqui |

### 4. Observabilidade (3 pilares)

| Pilar | Azure | AWS | Demo |
|-------|-------|-----|------|
| Metricas | **Azure Monitor** | **CloudWatch Metrics** | **Prometheus** (:9090) no compose — analogia **pull** de metricas |
| Logs | **Log Analytics** | **CloudWatch Logs** | Logs no terminal dos containers / **fala** de centralizacao |
| Tracing | **App Insights** | **X-Ray** / **OTel** | **Conceito** na banca; API lenta = metrica + trace + log (exemplo Slide abaixo) |

**Frase pronta:** “Localmente Prometheus+Grafana; na Azure seria Monitor; na AWS, CloudWatch — o **problema** e o mesmo: SLO, alerta, causas.”

### 5. Docker

| Tema | Onde mostrar |
|------|----------------|
| Imagem vs container | `api-java/Dockerfile`, `Dockerfile.dashboard` — Slide 14 Parte 3 |
| Compose — API, DB, Kafka, Redis | `docker-compose.yaml` — Slide 7 + `docker compose ps` |
| Volumes / network | Explicar `volumes:` e `networks:` no YAML; dashboard usa `http://api:8080` no compose |

### 6. DevOps / CI-CD

| Tema | Honestidade |
|------|-------------|
| Pipeline lint/test/build/deploy | **Nao ha** `.github/workflows` neste repo — apresente como **desenho**: GitHub Actions / **AWS CodePipeline** / **Azure DevOps** |
| IaC | **Terraform** `infrastructure/terraform/...` — **mostrar arquivo** |

### 7. Deploy (Canary, Blue-Green, Rolling)

| Estrategia | Onde falar |
|------------|------------|
| Canary / novo modelo | **Parte 4** respostas MLOps + **fala**: ECS/EKS **Rolling**, **CodeDeploy** canary na AWS; **AKS** + **Flighting** na Azure |
| Blue-Green | Conceito em producao — sem implementacao no compose |

### 8. Machine Learning

| Tema | Onde mostrar |
|------|----------------|
| Classificacao + anomalia | `src/ml_models/fraud_model.py` — **Isolation Forest** + **XGBoost** |
| Metricas Precision/Recall/F1/AUC | Endpoint `/api/v1/model/metrics` + trecho `train()` no mesmo arquivo |
| Balanceamento (SMOTE etc.) | **Nao esta** no codigo atual — cite como **melhoria** ou dataset sintetico com `generate_data` |
| MLOps MLflow / drift (Evidently) | **Narrativa** + resposta na Parte 4; integracao futura |

---

## PARTE 1: INTRODUCAO (15 minutos)

---

### Slide 1: Capa (1 min)
**Titulo:** Sistema de Deteccao de Fraudes Bancarias - Arquitetura Cloud-Native com Azure

**Notas do apresentador:**
- Cumprimente a banca
- Apresente-se brevemente
- Mencione que a apresentacao tera demonstracao pratica ao vivo

---

### Slide 2: Agenda (1 min)
**Conteudo:**
1. Contexto e Problema (5 min)
2. Visao Geral da Solucao + competencias de dados (5 min)
3. Demonstracao rapida com **Docker** (5 min)
4. Arquitetura detalhada + codigo (**notebook**, ingestao, qualidade) (30 min)
5. Demonstracao tecnica (**roteiro de demos** + explicacao linha a linha quando couber) (30 min)
6. Espaco para **dialogo com a banca** (o que couber nos 90 min; perguntas preparadas estao na Parte 4 **fora do cronometro**)

*(Consulte o bloco **GUIA: SEU RESUMO x ONDE MOSTRAR...** no inicio do documento para encaixar cada tecnologia na demo e o par Azure/AWS.)*

---

### Slide 3: O Problema - Fraudes Bancarias no Brasil (3 min)
**Conteudo:**
- Em 2023, fraudes bancarias digitais causaram perdas de **R$ 2,5 bilhoes** no Brasil (Febraban)
- Aumento de **165%** em tentativas de fraude nos ultimos 3 anos
- PIX: 1,7 milhao de golpes registrados em 2023
- Tempo medio de deteccao manual: **72 horas** (vs. < 2 segundos com automacao)
- Falsos positivos bloqueiam transacoes legitimas e prejudicam a experiencia do cliente

**O que falar:**
> "Fraudes bancarias sao um problema crescente no Brasil. Com a digitalizacao dos meios de pagamento, especialmente o PIX, o volume de tentativas de fraude cresceu exponencialmente. O desafio nao e apenas detectar fraudes, mas detecta-las em tempo real, minimizando falsos positivos que bloqueiam clientes legitimos. Foi esse problema que motivou este projeto."

---

### Slide 4: Requisitos do Sistema (2 min)
**Conteudo:**
| Requisito | Meta |
|-----------|------|
| Latencia | < 2 segundos para deteccao |
| Precisao | > 95% recall em fraudes |
| Escala | 10M+ transacoes/dia |
| Disponibilidade | 99.9% SLA |
| Conformidade | LGPD completa |
| Custo | ~R$ 3.000/mes para producao |

**O que falar:**
> "Definimos requisitos claros e mensuráveis para o sistema. A latencia de menos de 2 segundos e critica - uma fraude em PIX precisa ser bloqueada antes da compensacao. O recall acima de 95% garante que quase nenhuma fraude passe despercebida."

---

### Slide 5: Visao Geral da Solucao (3 min)
**Conteudo - Diagrama de alto nivel:**
```
[Fontes de Dados] --> [Ingestao (Event Hubs/Kafka)]
                          |
                    [Processamento (Spark/Databricks)]
                          |
              +-----------+-----------+
              |           |           |
        [Data Lake]  [Warehouse]  [ML Models]
              |           |           |
        [Data Quality] [Dashboard] [API de Predicao]
              |           |           |
        [Governanca]  [Power BI]  [Alertas]
```

**O que falar:**
> "A solucao segue uma arquitetura cloud-native na Azure, com processamento em tempo real e batch. Os dados fluem desde as fontes, passam por ingestao via Event Hubs, sao processados no Databricks, armazenados em multiplas camadas no Data Lake, e alimentam tanto dashboards quanto modelos de machine learning para deteccao automatica."

---

### Slide 6: Stack Tecnologica + “por que esta ferramenta” (3 min)
**Conteudo (lista):**
- **Cloud (alvo producao):** Azure (Event Hubs, Databricks, Data Lake Gen2, Synapse, Cosmos DB, ML)
- **Linguagens / servicos:** **API Java (Spring Boot, perfil local)** na demo Docker; Python (pipelines, ML, dashboard Streamlit); Node (console). Arquitetura real de banco costuma ser heterogenea.
- **Processamento:** Apache Spark / Databricks — batch e streaming em escala.
- **ML:** Scikit-learn, XGBoost, MLflow — modelo explicavel + boosting; rastreio de experimentos.
- **Infraestrutura:** **Docker + Compose** na demo local; **Terraform** para Azure em IaC.
- **Observabilidade (prioridade neste projeto):** **Prometheus + Grafana** no compose; na Azure, **Monitor / App Insights**. *Se a empresa exigir APM full-stack, da para integrar ferramentas como Dynatrace ou tracos via OpenTelemetry — cito como opcao, nao como nucleo da demo.*
- **Data Quality:** Great Expectations, Evidently — contratos e drift.
- **Seguranca:** Key Vault, RBAC, mascaramento LGPD.

**Tabela rapida — pilares**

| Pilar | Nesta demo | Na Azure / producao |
|-------|------------|---------------------|
| Metricas e paineis | Prometheus + Grafana (containers) | Azure Monitor, dashboards |
| Streaming | **Kafka no Docker** (mesmo padrao logico do **Event Hubs**) | Event Hubs gerenciado |
| Batch / lake | Notebook PySpark (codigo de referencia) | Databricks + ADLS |
| Catalogo / LGPD | `governanca.yaml`, mascaramento na API | Purview, politicas |

**O que falar:**
> "Nesta apresentacao eu **mostro containers** com Compose: API, dashboard, fila Kafka e observabilidade. Na Azure, Event Hubs desempenha o papel equivalente ao Kafka para ingestao em streaming — o **codigo** `event_hub_producer` / `consumer` mostra o padrao de lote, particao e checkpoint; localmente eu **valido o fluxo** na fila do compose."

---

### Slide 7: Demo Rapida - Docker e sistema rodando (4 min)
**Fala de abertura (30 seg):**
> "Subo a stack com Docker Compose: cada servico e um container — API, dashboard, Kafka, MongoDB, Prometheus, Grafana. Isso mostra **empacotamento**, **rede interna** e **paridade** entre o que eu descrevo na arquitetura e o que roda na maquina."

**DEMONSTRACAO AO VIVO:**
1. Na **raiz do projeto**: `docker compose up -d --build` (ou `docker-compose` se for a CLI antiga). Aguarde os servicos ficarem `healthy` / rodando (`docker compose ps`).
2. Opcional rapido: `docker compose ps` — cite **portas** (8080 API, 8501 dashboard, 8880 portal, 18080 Spark UI, 9090 Prometheus, 3000 Grafana).
3. Abra **http://localhost:8080/swagger-ui.html** (Swagger) e **http://localhost:8501** (Streamlit).
4. Envie uma transacao (pode ser pelo Swagger ou curl):
   `curl -s -X POST http://localhost:8080/api/v1/transactions/analyze -H "Content-Type: application/json" -d '{"amount": 15000, "merchant_category": "Eletronicos", "user_country": "BR", "merchant_country": "US", "payment_method": "CREDIT_CARD", "hour": 14, "is_weekend": 0, "is_international": 1}'`
5. Mostre JSON de resposta (`is_fraud`, `fraud_score`) e, se der tempo, o dashboard.

**O que falar:**
> "A API e o modelo rodam no container `api`; o Streamlit aponta para a API pela rede interna. Em producao seria o mesmo padrao com orquestrador e secrets — aqui o foco e mostrar o **fluxo** e o **contrato** REST."

---

## PARTE 2: ARQUITETURA DETALHADA (30 minutos)

---

### Slide 8: Arquitetura em Camadas (5 min)
**Conteudo - Diagrama Mermaid:**
```
Camada 1: INGESTAO
  - Azure Event Hubs (streaming em tempo real)
  - Azure Data Factory (batch historico)
  - Azure Functions (processamento serverless)

Camada 2: PROCESSAMENTO E ARMAZENAMENTO
  - Azure Databricks (Spark)
  - Data Lake Gen2 (Raw -> Processed -> Curated)
  - Azure Synapse (Data Warehouse)
  - Cosmos DB (operacional)

Camada 3: MACHINE LEARNING
  - Jupyter Notebooks (experimentacao)
  - Azure ML AutoML (treinamento)
  - MLflow (versionamento)
  - AKS endpoints (deploy)

Camada 4: SERVICOS E APIs
  - API Java Spring Boot (perfil `local`) — implementada neste projeto; OpenAPI/Swagger em `/swagger-ui.html`
  - (Opcional em corporacao) APIs em Java/Spring para sistemas legados — integracao via **contratos** e **versionamento**

Camada 5: OBSERVABILIDADE
  - Azure Monitor + Application Insights (telemetria PaaS/IaaS)
  - Prometheus + Grafana (metricas no Docker local)
  - Log Analytics (logs e auditoria na Azure)
```

**O que falar:**
> "A arquitetura foi organizada em 5 camadas bem definidas. Cada camada tem responsabilidades claras e pode escalar independentemente. Isso segue o principio de separacao de responsabilidades e facilita a manutencao."

---

### Slide 9: Data Lake Architecture - Medallion (5 min)
**Conteudo:**
```
BRONZE (Raw)          SILVER (Processed)       GOLD (Curated)
+-----------+         +---------------+         +-----------+
| JSON/CSV  |  ETL    | Parquet       |  Enrich | Features  |
| Sem schema| ------> | Schema valido | ------> | ML-ready  |
| Duplicatas|         | Limpo         |         | Agregados |
+-----------+         +---------------+         +-----------+
     |                       |                       |
  30 dias               90 dias                 Permanente
  retention             retention               retention
```

**O que falar:**
> "Adotamos a arquitetura Medallion com tres camadas. Os dados brutos chegam na camada Bronze sem transformacao. Na Silver, aplicamos limpeza, deduplicacao e validacao de schema. Na Gold, temos os dados prontos para consumo - features para ML, dados agregados para dashboards. Cada camada tem politicas diferentes de retencao e acesso."

**Ponto chave — MOSTRAR NO CODIGO (nao precisa executar Spark na sala se nao tiver cluster):**
- Abra `notebooks/01_dataprep_dq.py` no editor.
- **Explique:** formato **Databricks/PySpark** — `SparkSession`, paths `abfss://` no lake, classes `AzureDataPrep` / `AzureDataQuality`.
- Destaque **`clean_transactions()`**: deduplicacao `transaction_id`, `fillna`, `amount` nao negativo, derivacao de `transaction_date` / `transaction_hour`.
- Destaque **`enrich_data()`**: `is_weekend`, `is_night`, agregados por `user_id`.
- Role ate **Great Expectations** na classe de qualidade — contrato sobre DataFrame.
- **`src/data_architecture/medallion.py`:** `MedallionLayout` (paths ADLS/S3) + texto **Lambda vs Kappa** no docstring.
- **`config/medallion.yaml`:** convenções das camadas e notas de streaming.

**Fala opcional (30 s) — Lambda:** camada *speed* (Event Hub/Kafka + API) para baixa latencia; camada *batch* (este notebook Spark) para Silver/Gold e auditoria. **Kappa:** apenas replay de log/stream, sem segundo pipeline batch.

**O que falar:**
> "Subo isso no Databricks em producao; na banca mostro **estrutura e intencao** do pipeline Medallion sem depender de cluster local."

---

### Slide 10: Ingestao em streaming — Event Hubs (Azure) + pratica com Kafka no Docker (6 min)
**Diagrama (conceito):**
```
Transacao --> Event Hub ou Kafka --> Consumer (consumer group + checkpoint) --> processamento --> Lake / APIs
```

**O que falar:**
> "Event Hubs na Azure e o streaming gerenciado; no Compose uso **Kafka** para demonstrar o **mesmo padrao**: topico, particao, producer, consumer com offset. O codigo Python em `event_hub_*` e o que roda na Azure com connection string ou Managed Identity."

**MOSTRAR NO CODIGO (obrigatorio):**
1. **`src/data_ingestion/event_hub_producer.py`**: `EventHubProducerClient`, `EventData`, metadados `event_id` / `event_timestamp`, `send_batch`.
2. **`src/data_ingestion/event_hub_consumer.py`**: `EventHubConsumerClient`, **BlobCheckpointStore**, `process_event` (parse JSON), **`update_checkpoint`** apos sucesso.

**PRATICA LOCAL (Compose no ar — servico `kafka`):**
```bash
docker compose exec kafka kafka-topics --bootstrap-server kafka:9092 --create --topic transactions-demo --if-not-exists

echo '{"transaction_id":"demo-1","amount":999.0}' | docker compose exec -T kafka kafka-console-producer --bootstrap-server kafka:9092 --topic transactions-demo

docker compose exec kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic transactions-demo --from-beginning --max-messages 1
```

**O que falar na hora:**
> "Isso prova o fluxo de mensagens na mesa; na Azure seria o mesmo desenho com Event Hubs e checkpoint em Blob."

---

### Slide 11: Comparativo Azure vs AWS — **sempre citar os dois** (5 min)
**Conteudo (expandir conforme tempo):**
| Funcionalidade | Azure | AWS |
|---------------|-------|-----|
| Streaming ingestao | **Event Hubs** | **Kinesis Data Streams** ou **MSK** (Kafka) |
| Data Lake objeto | **ADLS Gen2** | **S3** |
| Lake + governanca | **Azure Purview** / **Microsoft Purview** | **AWS Lake Formation** + **Glue Catalog** |
| Spark gerenciado | **Azure Databricks** | **EMR** ou **Glue** (Spark) |
| SQL / Warehouse | **Synapse** / **Fabric** | **Redshift** / **Athena** |
| NoSQL wide | **Cosmos DB** | **DynamoDB** |
| ML treino/deploy | **Azure ML** | **SageMaker** |
| Metricas e alertas | **Azure Monitor** | **CloudWatch** |
| APM / trace | **Application Insights** | **X-Ray** ou **OTel** |
| Orquestracao ETL | **Data Factory** | **Glue Workflow** / **Step Functions** |
| Mensageria fila | **Service Bus** (fila) | **SQS** |
| Secrets | **Key Vault** | **Secrets Manager** / **Parameter Store** |
| Deploy containers | **ACA** / **AKS** | **ECS** / **EKS** |
| **Demo local (este repo)** | N/A | N/A — **Kafka / Prometheus / Grafana / Docker** simulam **padroes** que existem nas duas nuvens |

**Justificativa Azure:**
1. Data centers no Brasil (compliance LGPD)
2. Integracao nativa com ecossistema Microsoft (Office 365, AD)
3. Databricks como servico gerenciado de primeira classe
4. Cosmos DB com multi-model e distribuicao global
5. Adocao em nossa equipe

**O que falar:**
> "Escolhemos Azure por [LGPD / ecossistema Microsoft / Databricks]. Em paralelo conheco os equivalentes na **AWS** — na tabela: Event Hubs ~ **Kinesis** ou **MSK**, ADLS ~ **S3**, Synapse ~ **Redshift**/**Athena**, Monitor ~ **CloudWatch**. A **demo** roda em Docker com **Kafka** e **Prometheus**, que sao os mesmos **conceitos** de streaming e metricas que uso para falar com qualquer um dos dois clouds."

---

### Slide 12: Data Quality e Governanca (5 min)
**Conteudo:**
- **Great Expectations:** Validacoes automaticas nos dados
  - Schema validation (colunas obrigatorias)
  - Range checks (amount entre 0 e 1M)
  - Uniqueness (transaction_id unico)
  - Statistical checks (media de amount dentro do esperado)
- **Evidently:** Deteccao de data drift
- **Azure Purview:** Catalogo e linhagem de dados
- **Governanca YAML:** Regras declarativas em `governanca.yaml`

**MOSTRAR NO CODIGO:**
- Abra `notebooks/01_dataprep_dq.py` - classe `AzureDataQuality`
- Abra `governanca.yaml` - regras declarativas

**O que falar:**
> "Data Quality nao e opcional - dados ruins geram modelos ruins. Implementamos validacoes em multiplos niveis: schema, ranges, unicidade e estatisticas. O Great Expectations roda a cada ingestao e gera relatorios automaticos. Se detectarmos anomalias, alertas sao disparados antes que dados problematicos contaminem as camadas superiores."

---

### Slide 13: Seguranca e LGPD (5 min)
**Conteudo:**
1. **Mascaramento de Dados (PII):**
   - CPF: `123.456.789-00` -> `***.456.***-00`
   - Email: `usuario@email.com` -> `u*****@e***.com`
   - Telefone: `(11) 98765-4321` -> `(11) 9****-4321`
   - Cartao: `1234 5678 9012 3456` -> `**** **** **** 3456`

2. **Criptografia:** AES-256 em transito e repouso
3. **Azure Key Vault:** Gerenciamento seguro de secrets
4. **RBAC:** Controle de acesso baseado em papeis
5. **Audit Logs:** Todos os acessos registrados
6. **Data Retention:** Politicas automaticas de exclusao

**DEMONSTRACAO AO VIVO:**
```python
python -c "
from src.utils.data_masker import DataMasker
m = DataMasker()
print(m.mask_cpf('123.456.789-00'))
print(m.mask_email('joao.silva@banco.com.br'))
print(m.mask_card_number('1234 5678 9012 3456'))
"
```

**O que falar:**
> "A LGPD exige que dados pessoais sejam protegidos. Implementamos mascaramento para todos os campos PII - CPF, email, telefone, cartao. Em ambientes nao-produtivos, usamos anonimizacao via hash. Vou demonstrar o mascaramento funcionando."

---

## PARTE 3: DEMONSTRACAO TECNICA (30 minutos no cronometro)

Roteio pensado para: **(1)** tudo via Docker quando possivel; **(2)** explicar **codigo** (API, notebook, producer/consumer); **(3)** encaixar **streaming** com Kafka local + Event Hubs no discurso.

---

### ROTEIRO DE TESTE (faca na vespera — check sim / nao)

| # | O que testar | Comando / acao | Resultado esperado |
|---|----------------|----------------|-------------------|
| T0 | Compose sobe limpo | `docker compose down` ; `docker compose up -d --build` | `docker compose ps` sem erros criticos; API e dashboard sobem |
| T1 | API viva | Abrir http://localhost:8080/health | JSON com `status` ok |
| T2 | Swagger | http://localhost:8080/swagger-ui.html | Endpoints listados |
| T3 | Dashboard | http://localhost:8501 | Pagina carrega; sidebar API = `http://api:8080` **no Docker** (compose ja define) |
| T4 | Gerar dados | `docker compose exec api python scripts/generate_data.py -n 100 -o data/transactions.json` **ou** na maquina host com venv | Arquivo `data/transactions.json` existe |
| T5 | Curl analyze | Do host: curl transacao normal + suspeita (ver Demo 2) | `is_fraud` / `fraud_score` coerentes |
| T6 | Batch **formato API** | Usar JSON array (Demo 2) ou `bash scripts/demo_full_stack.sh` | **Nao** usar `transactions.json` bruto direto no `/batch` |
| T7 | Kafka console | Criar topico + producer + consumer (Slide 10) | Mensagem aparece no consumer |
| T8 | Notebook | Abrir `notebooks/01_dataprep_dq.py` no IDE | Classes visiveis; sem precisar executar |
| T9 | Producer Event Hub | Abrir `event_hub_producer.py` / `consumer.py` | Pronto para narrar linhas-chave |
| T10 | Grafana/Prometheus | http://localhost:9090 e :3000 | Targets / login Grafana se aplicavel |
| T11 | Demo completa | `bash scripts/demo_full_stack.sh` (API em localhost:8080) | Passos ate o fim |

**Nota:** A API da demo e **Java Spring** na porta **8080** (nao FastAPI :8000).

---

### Slide 14: Encerrando Parte 2 / inicio da demo tecnica (1 min)
- Mostrar rapidamente **api-java/Dockerfile** + **Dockerfile.dashboard**: API Java (Maven/JAR) e dashboard Python (`streamlit`) — ligue isso a **imagem imutavel** e **mesmo artefato em dev/CI**.

---

### Slide 15: Demo 1 — Geracao de dados + vinculo com batch (4 min)
**Executar (host com repo montado ou container `api`):**
```bash
python scripts/generate_data.py -n 100 -o data/transactions.json
python3 -c "import json; data=json.load(open('data/transactions.json')); print(f'Total: {len(data)}'); print(f'Fraudes: {sum(1 for t in data if t[\"is_fraud\"])}'); print(json.dumps(data[0], indent=2))"
```

**Explique o codigo:**
- Abrir `scripts/generate_data.py`: probabilidade de fraude, campos simulados, escrita JSON.

**O que falar:**
> "Isso simula a **carga** que viria do core bancario ou de um landing no lake. O arquivo tem `is_fraud` para benchmark — a **API de producao** nao recebe esse campo; ela so recebe features e devolve score."

---

### Slide 16: Demo 2 — API REST / modelo (10 min)
**Transacao normal e suspeita (curl ou Swagger):**
```bash
curl -s -X POST http://localhost:8080/api/v1/transactions/analyze \
  -H "Content-Type: application/json" \
  -d '{"amount": 150.00, "merchant_category": "Alimentacao", "user_country": "BR", "merchant_country": "BR", "payment_method": "PIX", "hour": 14, "is_weekend": 0, "is_international": 0}' | python3 -m json.tool

curl -s -X POST http://localhost:8080/api/v1/transactions/analyze \
  -H "Content-Type: application/json" \
  -d '{"amount": 45000.00, "merchant_category": "Eletronicos", "user_country": "BR", "merchant_country": "US", "payment_method": "CREDIT_CARD", "hour": 3, "is_weekend": 1, "is_international": 1}' | python3 -m json.tool
```

**Lote (`/batch`) — body deve ser lista de objetos no schema `TransactionInput`, nao o JSON cru de `generate_data`:**
```bash
curl -s -X POST http://localhost:8080/api/v1/transactions/batch \
  -H "Content-Type: application/json" \
  -d '[{"amount":150,"merchant_category":"Alimentacao","user_country":"BR","merchant_country":"BR","payment_method":"PIX","hour":14,"is_weekend":0,"is_international":0},{"amount":45000,"merchant_category":"Eletronicos","user_country":"BR","merchant_country":"US","payment_method":"CREDIT_CARD","hour":3,"is_weekend":1,"is_international":1}]' | python3 -m json.tool
```

**Explique o codigo:**
- `src/api/main.py`: `TransactionInput`, rota `analyze`, carregamento do modelo em `startup_event`, memoria `transactions_store` para demo.
- `src/ml_models/fraud_model.py`: ensemble, `predict`, treino (`train_and_save_model`) — abra e aponte **duas** funcoes.

---

### Slide 17: Demo 3 — Metricas do modelo (4 min)
```bash
curl -s http://localhost:8080/api/v1/model/metrics | python3 -m json.tool
curl -s http://localhost:8080/api/v1/model/feature-importance | python3 -m json.tool
```

**O que falar:** ensemble Isolation Forest + XGBoost; features; retreino periodico na narrativa de MLOps.

---

### Slide 18: Demo 4 — Dashboard Streamlit (4 min)
1. http://localhost:8501
2. Mostrar KPIs, graficos, formulario que chama a API.
**Codigo:** `src/dashboard/app.py` — `requests.post` para `/analyze`, widgets Streamlit.

---

### Slide 19: Demo 5 — Data Quality (API) (2 min)
```bash
curl -s http://localhost:8080/api/v1/data-quality/report | python3 -m json.tool
```
Relacione com `AzureDataQuality` no notebook e expectativas declarativas.

---

### Slide 20: Demo 6 — LGPD (2 min)
```bash
curl -s -X POST http://localhost:8080/api/v1/lgpd/mask \
  -H "Content-Type: application/json" \
  -d '{"cpf":"123.456.789-00","email":"joao.silva@banco.com.br","phone":"(11) 98765-4321","name":"Joao Silva Santos","card_number":"1234 5678 9012 3456","amount":1500.00}' | python3 -m json.tool
```
**Codigo:** `src/utils/data_masker.py`.

---

### Slide 21: Terraform + encerramento tecnico (2 min)
- `infrastructure/terraform/environments/dev/main.tf` — recursos declarados.
**Fecho:** "Compose prova o container; Terraform prova a nuvem."

---

### Opcional: script guiado completo
`bash scripts/demo_full_stack.sh` — util na banca para validar API, dashboard e Spark; API em **http://localhost:8080**.

---

## PARTE 4: PERGUNTAS E RESPOSTAS PREPARADAS (fora do tempo dos 90 minutos)

**Uso:** ensaio pos-apresentacao, simulado com colegas, ou respostas prontas se a banca esticar a conversa. **Nao precisa caber** nos 90 minutos contabilizados.

---

### Perguntas Esperadas e Respostas Preparadas

#### P1: "Como o sistema escala para milhoes de transacoes?"
**Resposta:**
> "A escalabilidade e garantida em todas as camadas. Event Hubs escala por Throughput Units - cada TU suporta 1MB/s de entrada. Databricks tem auto-scaling de clusters. O Data Lake e virtualmente ilimitado. Cosmos DB escala por RU/s. Podemos ir de 1.000 a 10 milhoes de transacoes/dia ajustando apenas parametros, sem mudar codigo."

#### P2: "Qual o custo estimado para producao?"
**Resposta:**
> "Estimamos cerca de R$ 3.000/mes para 10 milhoes de transacoes/dia. O maior custo e o Databricks (~40%). Usamos otimizacoes como auto-pause, spot instances e reserved capacity. Em desenvolvimento, o custo cai para ~R$ 500/mes."

#### P3: "Como garantir conformidade com LGPD?"
**Resposta:**
> "Tres pilares: mascaramento automatico de PII em todas as camadas, criptografia AES-256 em transito e repouso, e audit logs de todos os acessos. Usamos Azure Key Vault para secrets e RBAC para controle de acesso. Dados pessoais tem politicas de retencao automatica."

#### P4: "Como os modelos de ML sao atualizados?"
**Resposta:**
> "Seguimos uma pipeline MLOps completa. O modelo e retreinado semanalmente com dados novos. Usamos MLflow para versionamento. A transicao usa canary deployment - o novo modelo recebe 10% do trafego inicialmente. Monitoramos data drift com Evidently para detectar quando o modelo precisa ser atualizado."

#### P5: "Qual a estrategia de disaster recovery?"
**Resposta:**
> "Backup automatico do Data Lake com replicacao cross-region para dados criticos. RTO de 4 horas para recuperacao completa e RPO de 15 minutos. O Terraform permite recriar toda a infraestrutura em uma nova regiao se necessario."

#### P6: "Por que Azure e nao AWS?"
**Resposta:**
> "Tres razoes: data centers em Sao Paulo para compliance LGPD, integracao nativa com ecossistema Microsoft que bancos ja usam, e Databricks como servico gerenciado de primeira classe. Porem, a arquitetura e multi-cloud ready - todos os componentes tem equivalentes diretos."

#### P7: "Como voce lidaria com falsos positivos?"
**Resposta:**
> "Falsos positivos sao tao prejudiciais quanto falsos negativos - bloqueiam clientes legitimos. Usamos um threshold ajustavel no modelo. Para transacoes com score entre 0.5 e 0.8, aplicamos verificacao adicional (SMS, biometria) em vez de bloquear. Acima de 0.8, bloqueamos automaticamente. O feedback dos analistas retroalimenta o modelo."

#### P8: "O que voce faria diferente se comecasse de novo?"
**Resposta:**
> "Investiria mais tempo em feature engineering com dados historicos reais. Tambem consideraria uma arquitetura baseada em feature store dedicado (como Feast ou Tecton) para desacoplar a engenharia de features do treinamento do modelo."

#### P9: "Voce usaria Dynatrace ou so Prometheus?"
**Resposta (curta — opcional na banca):**
> "Hoje o nucleo da demo e **Prometheus + Grafana** no Docker, que ja cobre metricas e paineis. Se a politica da empresa pedir **APM** com causa raiz em cadeias grandes, da para **complementar** com Dynatrace ou outro backend — costumo instrumentar com **OpenTelemetry** para nao ficar preso a um vendor. Nao e o foco deste projeto."

#### P10: "Como voce organiza orquestracao e confiabilidade de pipelines?"
**Resposta:**
> "Separo **orquestracao de workflow** (Airflow, ADF ou Prefect) da **processagem distribuida** (Spark). Defino idempotencia por particao ou `run_id`, SLAs por camada Medallion, alertas de atraso e reprocessamento controlado. Observabilidade amarra run de pipeline a metricas de negocio — volume, taxa de fraude, drift."

#### P11: "O que significa 'Data Master' na pratica para voce?"
**Resposta:**
> "Além de construir pipeline, eu penso **produto de dados**: catalogo, linhagem, qualidade contratual, governanca de acesso, custo por workload e padroes para times consumidores. A fraude aqui é o **caso**; o que eu quero mostrar é que consigo desenhar a plataforma que sustenta varios casos parecidos com padroes reutilizaveis."

---

## Competencias que a banca costuma buscar (check mental)

Use como guia para **encaixar exemplos** da sua fala, nao como slide cheio:

| Tema | O que citar neste projeto |
|------|---------------------------|
| Plataforma | Medallion, multi-camada, separacao batch/streaming |
| Qualidade | Great Expectations, relatorios, DQ antes da Gold |
| Governanca | Purview (catalogo), `governanca.yaml`, LGPD/mascaramento |
| MLOps | MLflow, retreino, drift (Evidently), canary |
| Observabilidade | Prometheus/Grafana no compose; na Azure, Monitor; APM (ex. Dynatrace) só se política pedir |
| Confiabilidade | SLA, RPO/RTO, idempotencia, filas |
| Custo | FinOps, autoscale, spot, tier de storage |
| Seguranca | Key Vault, RBAC, auditoria |

---

## CHECKLIST PRE-APRESENTACAO

### No dia anterior:
- [ ] Testar **`docker compose up -d --build`** (ou `docker-compose`) no mesmo notebook/Mac da apresentacao
- [ ] Percorrer a tabela **ROTEIRO DE TESTE** (T0–T11), inclusive **Kafka console** (Slide 10)
- [ ] Verificar API: http://localhost:8080/docs e `/health`
- [ ] Verificar dashboard: http://localhost:8501 (com compose: API interna `http://api:8080` no Streamlit)
- [ ] Testar curls da Parte 3, inclusive **batch** com JSON array (nao arquivo bruto de `generate_data`)
- [ ] Cronometrar **Partes 1+2+3** juntas (alvo: **~90 min**; Parte 4 é estudo, nao entra no clock)

### No dia:
- [ ] Subir stack **~30 min antes**: `docker compose up -d --build`
- [ ] Abas: Swagger, Streamlit, opcional Prometheus/Grafana
- [ ] Terminal com comandos do doc (Kafka, curl, opcional `demo_full_stack.sh`)
- [ ] Backup: screenshots / JSON salvos
- [ ] Agua

### Plano B (se a demo falhar):
- Tenha screenshots de cada tela do dashboard
- Tenha as respostas JSON salvas em arquivos
- Mostre o codigo fonte diretamente e explique a logica
- Foque nos diagramas de arquitetura e no codigo

---

## DICAS FINAIS

1. **Comece forte:** A demo rapida no inicio gera impacto e curiosidade
2. **Mostre codigo:** A banca quer ver que voce entende o codigo, nao so slides
3. **Use numeros:** Latencia, custos, throughput - numeros concretos impressionam
4. **Admita limitacoes:** Se algo nao foi implementado completamente, diga e explique o plano
5. **Conecte teoria e pratica:** Para cada conceito, mostre o codigo correspondente
6. **Controle o tempo:** Use um timer discreto; melhor terminar 5 min antes do que correr
7. **Respire:** Em perguntas dificeis, repita a pergunta, pense 3 segundos, depois responda
8. **Data Master:** enfatize **plataforma, governanca e operacao**; use fraude como exemplo, nao como unico foco
9. **Containers:** mencione **imagem**, **porta** e **rede do Compose** ao mostrar `docker compose ps` — liga a demo a boas praticas de deploy
10. **Parte 4 deste arquivo:** é **ensaio** de respostas; nao precisa caber nos 90 minutos cronometrados
11. **Multi-cloud:** ao citar **Azure**, encaixe na mesma ideia o servico **AWS** da tabela do Slide 11 ou do **GUIA** no topo do arquivo
