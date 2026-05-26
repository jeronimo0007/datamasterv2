# Kubernetes — DataMaster (stack completa)

Deploy no VPS (k3s) com **todos** os serviços equivalentes ao `docker-compose.yaml`.

| Caminho | Uso |
|---------|-----|
| `base/` | Namespace, MongoDB, Postgres, Redis, Kafka, MinIO, Spark, Jupyter, Prometheus, Grafana, API, Dashboard, Portal, Data Console |
| `overlays/homelab/` | Overlay para o servidor homelab |

Antes do `kubectl kustomize`, o deploy roda `scripts/sync-k8s-config.sh` (copia SQL/Grafana para `base/config/` — exigencia do Kustomize).

## Aplicar

```bash
# Recomendado (build + import + apply):
bash scripts/deploy-kubernetes-server.sh

# Somente manifests (imagens ja no k3s):
kubectl apply -k infrastructure/kubernetes/overlays/homelab
```

Documentação: [docs/DEPLOY_K8S.md](../../docs/DEPLOY_K8S.md).

## NodePorts (homelab)

| Serviço | Porta |
|---------|-------|
| API | 30080 |
| Dashboard | 30501 |
| Portal | 30880 |
| Data console | 30333 |
| Grafana | 30300 |
| Prometheus | 30090 |
| Spark UI | 30180 |
| Jupyter | 30888 |
| MinIO console | 30901 |
| Kafka | 30902 |
