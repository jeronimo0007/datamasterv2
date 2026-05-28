# Deploy Kubernetes (VPS / homelab)

Stack **completa** no servidor com **k3s**, equivalente ao `docker-compose.yaml` (API, dashboard, portal, console, Spark, Jupyter, Kafka, **RabbitMQ**, **email-worker**, MongoDB, Postgres, Redis, MinIO, Prometheus, Grafana).

## Pré-requisitos

- k3s (ou Kubernetes) no VPS
- Docker no host (build das imagens)
- Repositório em `/home/servidor/kubernets/datamasterv2` (ou `DEPLOY_DIR`)
- Branch **`vps`** — deploy via GitHub Actions ou manual
- `.env` na raiz do repo no servidor (opcional: `DEEPSEEK_API_KEY`, SMTP, RabbitMQ)

Copie [.env.vps.example](../../.env.vps.example) → `.env`.

## Deploy automático (CI)

Push na branch `vps` dispara [.github/workflows/deploy-vps.yml](../../.github/workflows/deploy-vps.yml) (SSH via Tailscale).

Secrets: `K8S_SSH_HOST`, `K8S_SSH_KEY` ou `K8S_SSH_PASSWORD`, `TAILSCALE_AUTHKEY`.

## Deploy manual no servidor

```bash
cd /home/servidor/kubernets/datamasterv2
git fetch origin vps && git reset --hard origin/vps
cp .env.vps.example .env   # edite SMTP, DEEPSEEK, etc.
bash scripts/deploy-kubernetes-server.sh
```

O script: build das imagens → import no k3s → `kubectl apply -k infrastructure/kubernetes/overlays/homelab`.

## NodePorts (homelab)

Substitua `IP` pelo IP do VPS (ou Tailscale).

| Serviço | URL |
|---------|-----|
| Portal | http://IP:30880 |
| API | http://IP:30080 |
| Dashboard | http://IP:30501 |
| Data console | http://IP:30333 |
| Grafana | http://IP:30300 (`admin` / `admin`) |
| Prometheus | http://IP:30090 |
| Spark UI | http://IP:30180 |
| Jupyter | http://IP:30888 (token `datamaster`) |
| MinIO console | http://IP:30901 |
| Kafka | IP:30902 |
| RabbitMQ AMQP | IP:30672 |
| RabbitMQ UI | http://IP:31672 (`datamaster` / `datamaster`) |

Email-worker: health interno na porta 8090 (sem NodePort); logs: `kubectl logs -n datamaster deploy/email-worker`.

## Operação

```bash
kubectl get pods -n datamaster
kubectl logs -n datamaster deploy/api --tail=50
kubectl rollout restart deployment/email-worker -n datamaster
```

Manifests: [`infrastructure/kubernetes/`](../../infrastructure/kubernetes/) — ver [README do Kubernetes](../../infrastructure/kubernetes/README.md).

Mapa de equivalência (local · VPS · Azure · AWS): [MAPA_LOCAL_AZURE.md](../../infrastructure/MAPA_LOCAL_AZURE.md).

Resumo CI e Tailscale: [DEPLOY_VPS.md](DEPLOY_VPS.md).
