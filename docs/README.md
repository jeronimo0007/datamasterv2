# Documentação DataMaster

Índice da pasta `docs/` — operação Docker, arquitetura técnica, cloud e diagramas.

Diagramas draw.io: [arquitetura/](arquitetura/) (índice em [arquitetura/README.md](arquitetura/README.md)). Regenerar: `python3 scripts/generate_architecture_drawio.py` na raiz do projeto.

**Estudo e apresentação (não versionados):** pasta [`../banca/`](../banca/) na raiz do projeto — roteiros, planos de estudo e rascunhos (ver `.gitignore`).

**Demo ao vivo (versionado):** slides e cola em `portal/banca.html` e `portal/roteiro.html` — http://localhost:8880 após `docker compose up -d portal`.

## Demo e operação

| Documento | Conteúdo |
|-----------|----------|
| [QUICK_START.md](QUICK_START.md) | Subir Docker, URLs, troubleshooting |
| [SERVICOS_DOCKER.md](SERVICOS_DOCKER.md) | O que é cada container |
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
| [DEPLOY_KUBERNETES_SERVIDOR.md](DEPLOY_KUBERNETES_SERVIDOR.md) | Git → servidor K8s (Tailscale / k3s) |

## Outros

| Documento | Conteúdo |
|-----------|----------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribuição |
| [examples/](examples/) | Exemplos CI/CD |
