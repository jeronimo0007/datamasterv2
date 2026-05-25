# Documentação DataMaster

Índice da pasta `docs/` — quick start, arquitetura, operação Docker, estudo, diagramas e material de apoio à banca.

Diagramas draw.io: [arquitetura/](arquitetura/) (índice em [arquitetura/README.md](arquitetura/README.md)). Regenerar: `python3 scripts/generate_architecture_drawio.py` na raiz do projeto.

**O que não está neste índice (ver `.gitignore` na raiz):** rascunhos e scripts em `base_estudo/` (exceto alguns `.md` versionados); duplicatas em `apresentacao/`.

**Apresentação ao vivo (demo local):** slides e cola verbal em `portal/banca.html` e `portal/roteiro.html` — http://localhost:8880 após `docker compose up -d portal`.

## Demo e operação

| Documento | Conteúdo |
|-----------|----------|
| [QUICK_START.md](QUICK_START.md) | Subir Docker, URLs, troubleshooting |
| [SERVICOS_DOCKER.md](SERVICOS_DOCKER.md) | O que é cada container |
| [LOCAL_SPARK.md](LOCAL_SPARK.md) | Spark / notebook no Docker |

## Banca

| Documento | Conteúdo |
|-----------|----------|
| [APRESENTACAO_BANCA.md](APRESENTACAO_BANCA.md) | Roteiro 90 min |
| [GUIA_APRESENTACAO_BANCA.md](GUIA_APRESENTACAO_BANCA.md) | Comandos terminal |
| [ESTUDO_BANCA.md](ESTUDO_BANCA.md) | Plano de estudo focado |
| [PLANO_ESTUDO.md](PLANO_ESTUDO.md) | Plano longo |
| [apresentacao/slides-projetor.html](apresentacao/slides-projetor.html) | Slides (fonte; no Docker: `portal/banca.html`) |
| [apresentacao/roteiro-verbal.html](apresentacao/roteiro-verbal.html) | Cola verbal (fonte; no Docker: `portal/roteiro.html`) |
| [base_estudo/contexto_pedido_arquitetura.md](base_estudo/contexto_pedido_arquitetura.md) | Contexto do pedido / arquitetura |
| [base_estudo/respostas_banca.md](base_estudo/respostas_banca.md) | Respostas preparadas |
| [base_estudo/estrutura_completa.txt](base_estudo/estrutura_completa.txt) | Estrutura do repositório (texto) |

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
| [PRESENTATION.md](PRESENTATION.md) | Apresentação (legado) |

## Outros

| Documento | Conteúdo |
|-----------|----------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribuição |
| [examples/](examples/) | Exemplos CI/CD |
