# Deploy no VPS (homelab)

Ambiente de produção/homelab do projeto: **Kubernetes (k3s)** na branch **`vps`**, não Docker Compose em produção no servidor.

## Guia principal

**[DEPLOY_K8S.md](DEPLOY_K8S.md)** — stack completa, NodePorts, `deploy-kubernetes-server.sh`, RabbitMQ, email-worker.

## Fluxo resumido

1. Servidor com k3s + Docker
2. Clone em `/home/servidor/kubernets/datamasterv2`
3. `.env` na raiz (`.env.vps.example`)
4. Push em `vps` → GitHub Actions **Deploy → VPS (Kubernetes)** ou `bash scripts/deploy-kubernetes-server.sh` no host

## Compose no VPS (opcional / legado)

Para testes locais no servidor sem K8s: `docker compose` + [../operacao/AMBIENTE_LOCAL.md](../operacao/AMBIENTE_LOCAL.md). O script de deploy K8s dá `docker compose down` para evitar conflito de portas com NodePorts.

## Documentação relacionada

| Doc | Conteúdo |
|-----|----------|
| [DEPLOY_K8S.md](DEPLOY_K8S.md) | Kubernetes completo |
| [../online/FRAUD_EMAIL_RABBITMQ.md](../online/FRAUD_EMAIL_RABBITMQ.md) | Fila + SMTP |
| [GITHUB_ACTIONS_TAILSCALE.md](GITHUB_ACTIONS_TAILSCALE.md) | CI via Tailscale (se existir no repo) |
