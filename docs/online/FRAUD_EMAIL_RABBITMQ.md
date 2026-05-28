# Alerta de fraude por e-mail (RabbitMQ)

Fluxo **assíncrono**: a API publica na fila quando detecta fraude; um worker consome e envia SMTP. A requisição HTTP **não espera** o e-mail.

## Arquitetura

```text
[Console / Dashboard] ──POST /analyze──► [API Java :8080]
                                              │ is_fraud
                                              ▼
                                        [RabbitMQ]
                                    fila fraud.alert.email
                                              │
                                              ▼
                                    [email-worker :8090]
                                              │ SMTP
                                              ▼
                                        destinatário
```

| Papel | Serviço | Porta (local) |
|-------|---------|---------------|
| Produtor | `api` (Spring AMQP) | 8080 |
| Broker | `rabbitmq` | 5672 (AMQP), **15672** (UI) |
| Consumidor | `email-worker` | 8090 (health Actuator) |

**Nuvem (narrativa):** fila gerenciada (Azure Service Bus / AWS SQS) + Function ou worker em container; SMTP via SendGrid / SES.

## Configuração (`.env` na raiz)

Copie de [`.env.example`](../.env.example):

| Variável | Descrição |
|----------|-----------|
| `RABBITMQ_USER` / `RABBITMQ_PASSWORD` | Credenciais do broker |
| `FRAUD_EMAIL_ENABLED` | `true` para publicar/consumir |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` | Servidor SMTP |
| `SMTP_FROM` | Remetente |
| `FRAUD_ALERT_TO` | Destinatário do alerta |

Sem `SMTP_HOST`, o worker **sobe** e registra aviso; nenhum e-mail é enviado.

## Docker Compose

```bash
docker compose up -d --build rabbitmq email-worker api
```

- UI RabbitMQ: http://localhost:15672 (`datamaster` / `datamaster` por padrão)
- Health worker: http://localhost:8090/actuator/health

**Teste rápido:** `POST /api/v1/transactions/analyze` com payload que gere `is_fraud: true` (score ≥ 0,74). Ver fila na UI e logs:

```bash
docker logs fraud-email-worker --tail 40
```

## Kubernetes (VPS / homelab)

Manifests: `infrastructure/kubernetes/base/rabbitmq.yaml`, `email-worker.yaml`, `smtp-secret.yaml`.

NodePorts (overlay homelab): Rabbit **30672** (AMQP), **31672** (UI).

Secret SMTP criado no deploy se `SMTP_HOST` estiver no `.env` do servidor (`scripts/deploy-kubernetes-server.sh`).

## Código

| Caminho | Função |
|---------|--------|
| `api-java/.../messaging/` | Publicador e DTO da mensagem |
| `email-worker/` | Listener AMQP + JavaMail |
| Fila | `fraud.alert.email` (`FraudRabbitConstants`) |

## Apresentação

- Slides: `portal/banca.html` (alerta assíncrono)
- Cola verbal: `portal/roteiro.html`

Índice: [../online/README.md](README.md) · [../README.md](../README.md)
