# Deprecado — use a stack completa

Este diretório era uma stack **mínima** (só API em Container Apps). A apresentação passou a usar sempre a **stack completa**:

| Ambiente | Caminho |
|----------|---------|
| **Azure (banca)** | [`../apresentacao/`](../apresentacao/) |
| **VPS homelab** | `bash scripts/deploy-kubernetes-server.sh` — [docs/deploy/DEPLOY_K8S.md](../../../docs/deploy/DEPLOY_K8S.md) |
| **Local (demo ao vivo)** | `docker compose up -d --build` |

Não use `banca-minimo` para a banca. Mantido no repo apenas por referência histórica.
