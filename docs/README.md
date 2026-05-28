# Documentação DataMaster

Índice da pasta `docs/` — operação Docker, arquitetura técnica, cloud e diagramas.

**Documentação por domínio:** [INDICE_DOMINIOS.md](INDICE_DOMINIOS.md) — agrupa material de **dados**, **observabilidade** e **online**.

Diagramas draw.io: [arquitetura/](arquitetura/) (índice em [arquitetura/README.md](arquitetura/README.md)). Regenerar: `python3 scripts/generate_architecture_drawio.py` na raiz do projeto.

**Estudo e apresentação:** [banca/ESTUDO_BANCA.md](banca/ESTUDO_BANCA.md) · [banca/APRESENTACAO_BANCA.md](banca/APRESENTACAO_BANCA.md) (versionados). Cópia local opcional em [`../banca/`](../banca/) (`.gitignore`).

**Demo ao vivo (versionado):** slides e cola em `portal/banca.html` e `portal/roteiro.html` — http://localhost:8880 após `docker compose up -d portal`.

## Por domínio

| Domínio | Índice |
|---------|--------|
| Dados (batch, lake, Mongo, Spark) | [dados/README.md](dados/README.md) |
| Observabilidade (Prometheus, Grafana) | [observabilidade/README.md](observabilidade/README.md) |
| Online (API, Kafka, **RabbitMQ**, e-mail) | [online/README.md](online/README.md) |

## Demo e operação

| Documento | Conteúdo |
|-----------|----------|
| [AMBIENTE_LOCAL.md](AMBIENTE_LOCAL.md) | **Rodar na sua máquina** — `.env`, `up-local`, Mac/Linux |
| [DEPLOY_VPS.md](DEPLOY_VPS.md) | **Rodar no VPS** — resumo, CI, Tailscale |
| [DEPLOY_K8S.md](DEPLOY_K8S.md) | **Kubernetes completo** — todos os serviços, NodePorts |
| [QUICK_START.md](QUICK_START.md) | Subir Docker, URLs, troubleshooting |
| [SERVICOS_DOCKER.md](SERVICOS_DOCKER.md) | O que é cada container |
| [FRAUD_EMAIL_RABBITMQ.md](FRAUD_EMAIL_RABBITMQ.md) | Alerta de fraude por fila + SMTP |
| [LOCAL_SPARK.md](LOCAL_SPARK.md) | Spark / notebook no Docker |
| [MONGODB_COMPASS.md](MONGODB_COMPASS.md) | MongoDB e Compass |

## Arquitetura e cloud

| Documento | Conteúdo |
|-----------|----------|
| [arquitetura/README.md](arquitetura/README.md) | Diagramas draw.io (local, Azure, AWS, Docker Compose) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitetura detalhada |
| [PROJETO_ESTRUTURADO.md](PROJETO_ESTRUTURADO.md) | Estrutura do repositório |
| [cloud_comparison.md](cloud_comparison.md) | Azure vs AWS |
| [TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md](TUTORIAL_AZURE_TERRAFORM_E_GITHUB_ACTIONS.md) | Deploy Azure |
| [TERRAFORM_BANCA_MINIMO.md](TERRAFORM_BANCA_MINIMO.md) | Stack mínima Azure |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Deployment |
| [CI_CD_BRANCHES.md](CI_CD_BRANCHES.md) | Deploy por branch (`azure` / `aws` / `vps`, sem deploy na `main`) |
| [GITHUB_ACTIONS_TAILSCALE.md](GITHUB_ACTIONS_TAILSCALE.md) | GitHub Actions acessar VPS via Tailscale |
| [TAILSCALE_ACL_PASSO_A_PASSO.md](TAILSCALE_ACL_PASSO_A_PASSO.md) | ACL / tags Tailscale (modo fácil + passo a passo) |
| [DEPLOY_KUBERNETES_SERVIDOR.md](DEPLOY_KUBERNETES_SERVIDOR.md) | Índice → [DEPLOY_VPS.md](DEPLOY_VPS.md) |

## Outros

| Documento | Conteúdo |
|-----------|----------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribuição |
| [examples/](examples/) | Exemplos CI/CD |
