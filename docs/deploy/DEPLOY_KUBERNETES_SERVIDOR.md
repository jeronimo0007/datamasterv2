# Deploy no servidor (homelab)

| Ambiente | Documento |
|----------|-----------|
| **VPS — Kubernetes (stack completa)** | **[DEPLOY_K8S.md](DEPLOY_K8S.md)** |
| **VPS — resumo + CI** | [DEPLOY_VPS.md](DEPLOY_VPS.md) |
| **Sua máquina (local)** | [../operacao/AMBIENTE_LOCAL.md](../operacao/AMBIENTE_LOCAL.md) |
| CI por branch | [CI_CD_BRANCHES.md](CI_CD_BRANCHES.md) |
| Tailscale + Actions | [GITHUB_ACTIONS_TAILSCALE.md](GITHUB_ACTIONS_TAILSCALE.md) |

```bash
# VPS
bash scripts/deploy-kubernetes-server.sh

# Local
cp .env.example .env && bash scripts/up-local.sh
```
