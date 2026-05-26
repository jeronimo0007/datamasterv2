# Kubernetes — DataMaster

| Caminho | Uso |
|---------|-----|
| `base/` | Namespace, MongoDB, API, Dashboard, Portal |
| `overlays/homelab/` | Deploy no servidor (k3s) |

```bash
kubectl apply -k infrastructure/kubernetes/overlays/homelab
```

Deploy automatizado: `scripts/deploy-kubernetes-server.sh` e [docs/DEPLOY_KUBERNETES_SERVIDOR.md](../../docs/DEPLOY_KUBERNETES_SERVIDOR.md).
