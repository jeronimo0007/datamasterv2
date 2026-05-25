# Grafana — provisionamento local

Ao subir `docker compose up -d`, o Grafana carrega automaticamente:

| Arquivo | Função |
|---------|--------|
| `provisioning/datasources/prometheus.yml` | Datasource **Prometheus** → `http://prometheus:9090` |
| `provisioning/dashboards/dashboards.yml` | Pasta de dashboards em `/var/lib/grafana/dashboards` |
| `dashboards/datamaster-api.json` | Painel **DataMaster — API Fraude** |

## Uso na banca

1. http://localhost:3000 — `admin` / `admin`
2. **Dashboards** → **DataMaster** → **DataMaster — API Fraude**
3. Gere tráfego na API (console :3333 ou Swagger) para ver HTTP e JVM

## Validar coleta

- Prometheus targets: http://localhost:9090/targets — `fraud-api` deve estar **UP**
- Métricas brutas: http://localhost:8080/actuator/prometheus

## Alterar painéis

Edite `dashboards/datamaster-api.json` e reinicie:

```bash
docker compose restart grafana
```

Ou edite pela UI (alterações persistem no volume `grafana_data`).
