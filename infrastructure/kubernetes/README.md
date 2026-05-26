# Kubernetes — DataMaster (legado / MVP)

Deploy **completo** no VPS usa **Docker Compose** (`scripts/deploy-kubernetes-server.sh`), não estes manifests.

| Caminho | Uso |
|---------|-----|
| `base/` | MVP antigo: MongoDB, API, Dashboard, Portal |
| `overlays/homelab/` | k3s (substituido por Compose no CI) |

Para testar o MVP em k3s manualmente: `kubectl apply -k infrastructure/kubernetes/overlays/homelab`

Ver [docs/DEPLOY_KUBERNETES_SERVIDOR.md](../../docs/DEPLOY_KUBERNETES_SERVIDOR.md).
