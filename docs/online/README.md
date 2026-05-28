# Domínio: Online

API de scoring, interfaces, mensageria e notificações em tempo quase real.

## Documentos

| Documento | Conteúdo |
|-----------|----------|
| [FRAUD_EMAIL_RABBITMQ.md](FRAUD_EMAIL_RABBITMQ.md) | **RabbitMQ + email-worker** |
| [../operacao/SERVICOS_DOCKER.md](../operacao/SERVICOS_DOCKER.md) | API, dashboard, Kafka, RabbitMQ |
| [../operacao/QUICK_START.md](../operacao/QUICK_START.md) | Swagger, analyze, batch |
| [../arquitetura/ARCHITECTURE.md](../arquitetura/ARCHITECTURE.md) | Contrato REST |

## Serviços (Compose)

| Serviço | Porta | Papel |
|---------|-------|--------|
| api | 8080 | Scoring, alertas, LGPD |
| dashboard | 8501 | Streamlit |
| data-console | 3333 | Simulador de carga |
| kafka | 9092 | Streaming (narrativa Event Hubs) |
| rabbitmq | 15672 (UI) | Fila `fraud.alert.email` |
| email-worker | 8090 | SMTP assíncrono |

## Diagramas

[../arquitetura/datamaster-02-online.drawio](../arquitetura/datamaster-02-online.drawio)

Apresentação: `portal/banca.html` · checklist **T4c** (RabbitMQ).

[← Índice geral](../README.md)
