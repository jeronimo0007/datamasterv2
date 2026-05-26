#!/usr/bin/env bash
# Copia SQL/Grafana/Mongo init para infrastructure/kubernetes/base/config/
# (Kustomize exige arquivos dentro do diretorio base/)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="${ROOT}/infrastructure/kubernetes/base/config"

mkdir -p "${CFG}/grafana/provisioning/datasources" \
  "${CFG}/grafana/provisioning/dashboards" \
  "${CFG}/grafana/dashboards"

cp "${ROOT}/scripts/init_mongo.js" "${CFG}/init_mongo.js"
cp "${ROOT}/sql/schema.sql" "${CFG}/01-schema.sql"
cp "${ROOT}/sql/seed_demo.sql" "${CFG}/02-seed_demo.sql"
cp "${ROOT}/config/grafana/provisioning/datasources/prometheus.yml" \
  "${CFG}/grafana/provisioning/datasources/prometheus.yml"
cp "${ROOT}/config/grafana/provisioning/dashboards/dashboards.yml" \
  "${CFG}/grafana/provisioning/dashboards/dashboards.yml"
cp "${ROOT}/config/grafana/dashboards/datamaster-api.json" \
  "${CFG}/grafana/dashboards/datamaster-api.json"

echo "K8s config sincronizado em ${CFG}"
