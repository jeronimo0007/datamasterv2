# CI/CD por branch (sem deploy na `main`)

## Regra geral

| Evento | Deploy? |
|--------|---------|
| **Pull Request** para `main` (ou qualquer branch) | **Não** — workflows usam só `push`, não `pull_request` |
| **Push / merge** na `main` | **Não** |
| **Push / merge** na `azure` | **Sim** → Azure (Terraform) |
| **Push / merge** na `aws` | **Sim** → AWS (Terraform) |
| **Push / merge** na `vps` | **Sim** → servidor Kubernetes (SSH) |

## Fluxo recomendado

```text
feature/*  ──PR──►  main     (integracao, sem deploy)
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
     azure        aws          vps
   (Terraform) (Terraform)  (K8s homelab)
```

1. Desenvolva em `feature/*` e abra **PR para `main`** — apenas revisão/código, **sem deploy**.
2. Quando quiser publicar:
   - Merge `main` → **`azure`** → Actions: `Deploy → Azure`
   - Merge `main` → **`aws`** → Actions: `Deploy → AWS`
   - Merge `main` → **`vps`** → Actions: `Deploy → VPS`

No GitHub: **Pull request** de `main` para `azure` (ou merge local + push na `azure`).

## Workflows

| Branch | Arquivo | Ação |
|--------|---------|------|
| `vps` | `.github/workflows/deploy-vps.yml` | SSH + `scripts/deploy-kubernetes-server.sh` |
| `azure` | `.github/workflows/deploy-azure.yml` | `terraform apply` em `infrastructure/terraform/apresentacao` |
| `aws` | `.github/workflows/deploy-aws.yml` | `terraform apply` em `infrastructure/terraform/aws` |

Deploy manual: **Actions** → escolha o workflow → **Run workflow** (na branch correta).

## Secrets

**VPS:** `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET` (Tailscale — ver [GITHUB_ACTIONS_TAILSCALE.md](GITHUB_ACTIONS_TAILSCALE.md)), `K8S_SSH_HOST`, `K8S_SSH_USER`, `K8S_SSH_KEY`, `K8S_DEPLOY_DIR`

**Azure:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

**AWS:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_LAKE_BUCKET_NAME` (se não usar `terraform.tfvars` na branch)

## Servidor VPS

Clone/checkout da branch **`vps`**:

```bash
cd /opt/datamaster
git fetch origin vps
git checkout vps
```

Detalhes: [DEPLOY_KUBERNETES_SERVIDOR.md](DEPLOY_KUBERNETES_SERVIDOR.md).
