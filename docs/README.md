# Documentação DataMaster

Documentação organizada **por categoria**. Slides e cola verbal da banca ficam em `portal/` (versionados); material pessoal de estudo em `banca/` na raiz (**não versionado**).

## Categorias

| Pasta | Conteúdo |
|-------|----------|
| [operacao/](operacao/) | Docker local, quick start, cada serviço do Compose |
| [deploy/](deploy/) | VPS, Kubernetes (k3s), CI, Tailscale |
| [dados/](dados/) | Spark, lake, MongoDB, batch |
| [online/](online/) | API, Kafka, RabbitMQ, e-mail de fraude |
| [observabilidade/](observabilidade/) | Prometheus, Grafana, health |
| [arquitetura/](arquitetura/) | Diagramas draw.io, arquitetura detalhada |
| [cloud/](cloud/) | Azure, AWS, Terraform |
| [contribuicao/](contribuicao/) | Como contribuir |
| [examples/](examples/) | Workflows CI de referência |

## Começar rápido

| Objetivo | Documento |
|----------|-----------|
| Subir na sua máquina | [operacao/QUICK_START.md](operacao/QUICK_START.md) |
| `.env` e scripts locais | [operacao/AMBIENTE_LOCAL.md](operacao/AMBIENTE_LOCAL.md) |
| Deploy no VPS (k3s) | [deploy/DEPLOY_K8S.md](deploy/DEPLOY_K8S.md) |
| Mapa local · VPS · cloud | [../infrastructure/MAPA_LOCAL_AZURE.md](../infrastructure/MAPA_LOCAL_AZURE.md) |

## Domínios (visão de plataforma)

```text
  DADOS ──► ONLINE ──► OBSERVABILIDADE
 (batch)   (API/filas)  (métricas)
```

| Domínio | Índice |
|---------|--------|
| Dados | [dados/README.md](dados/README.md) |
| Online | [online/README.md](online/README.md) |
| Observabilidade | [observabilidade/README.md](observabilidade/README.md) |

## Apresentação (banca)

| Recurso | Onde |
|---------|------|
| Slides | `portal/banca.html` |
| Cola verbal | `portal/roteiro.html` |
| Hub demo | http://localhost:8880 (`portal/index.html`) |
| Diagramas | [arquitetura/](arquitetura/) — regenerar: `python3 scripts/generate_architecture_drawio.py` |

Estudo e rascunhos: pasta **`banca/`** na raiz do projeto (`.gitignore`).
