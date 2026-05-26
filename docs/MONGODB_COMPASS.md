# MongoDB — Compass e dados

## Conexão no MongoDB Compass

| Campo | Valor |
|-------|--------|
| Connection string | `mongodb://admin:admin123@localhost:27017/?authSource=admin` |
| Host | `localhost` |
| Port | `27017` |
| Authentication | Username `admin`, Password `admin123` |
| Authentication Database | `admin` |

Depois de conectar, abra o banco **`fraud_detection`**.

## Coleções (após batch ou init)

| Coleção | Conteúdo |
|-----------|----------|
| `user_profiles` | Perfis agregados por usuário (histórico, scores, flags) |
| `batch_runs` | Metadados de execuções do pipeline batch |
| `transaction_history` | Cada `POST /analyze` — PII em claro (ambiente demo); API lista mascarado; `cosmos_sync_status` para réplica |

> Na API, `GET /transactions` devolve **CPF e cartão mascarados**. No Compass você vê o documento completo (somente ambiente local).

## Se o init falhou na primeira subida (`EISDIR`)

O volume `mongodb_data` pode ter sido criado quando `init_mongo.js` era um diretório. **Recrie só o Mongo:**

```bash
docker compose stop mongodb
docker volume rm datamaster_mongodb_data
docker compose up -d mongodb
docker compose logs mongodb --tail 20
```

Procure por `init_mongo.js` nos logs **sem** `EISDIR`.

## Popular manualmente (se o volume já existia)

```bash
docker compose exec mongodb mongosh -u admin -p admin123 --authenticationDatabase admin \
  --file /docker-entrypoint-initdb.d/init_mongo.js
```

Ou copie o script:

```bash
docker compose cp scripts/init_mongo.js mongodb:/tmp/init.js
docker compose exec mongodb mongosh -u admin -p admin123 --authenticationDatabase admin --file /tmp/init.js
```

## Verificar

```bash
docker compose exec mongodb mongosh -u admin -p admin123 --authenticationDatabase admin \
  --eval "db.getSiblingDB('fraud_detection').getCollectionNames()"
```
