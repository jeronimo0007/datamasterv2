#!/usr/bin/env bash
# Reaplica kafka/zookeeper/spark/jupyter na ordem certa (apos git pull).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl_cmd() { kubectl "$@" 2>/dev/null || sudo -n kubectl "$@"; }

echo "==> Pre-pull imagens (evita timeout no primeiro pod)"
for img in confluentinc/cp-zookeeper:7.5.0 confluentinc/cp-kafka:7.5.0 \
  bitnamilegacy/spark:3.5.5 jupyter/pyspark-notebook:spark-3.5.0 busybox:1.36; do
  sudo docker pull "$img" 2>/dev/null || docker pull "$img" 2>/dev/null || true
done

echo "==> Zookeeper primeiro"
kubectl_cmd apply -f "${ROOT}/infrastructure/kubernetes/base/zookeeper.yaml"
kubectl_cmd rollout status deployment/zookeeper -n datamaster --timeout=300s

for f in kafka.yaml spark.yaml jupyter.yaml; do
  echo "==> Apply ${f}"
  kubectl_cmd apply -f "${ROOT}/infrastructure/kubernetes/base/${f}"
done

kubectl_cmd delete pod -n datamaster -l app=kafka --force --grace-period=0 2>/dev/null || true
kubectl_cmd delete pod -n datamaster -l app=spark-master --force --grace-period=0 2>/dev/null || true
kubectl_cmd delete pod -n datamaster -l app=spark-worker --force --grace-period=0 2>/dev/null || true
kubectl_cmd delete pod -n datamaster -l app=jupyter --force --grace-period=0 2>/dev/null || true

echo "==> Aguardar subir (ate 5 min cada)"
kubectl_cmd rollout status deployment/kafka -n datamaster --timeout=300s || true
kubectl_cmd rollout status deployment/spark-master -n datamaster --timeout=300s || true
kubectl_cmd rollout status deployment/jupyter -n datamaster --timeout=300s || true

echo ""
kubectl_cmd get pods -n datamaster | grep -E 'kafka|zookeeper|spark|jupyter' || kubectl_cmd get pods -n datamaster
echo ""
echo "Se falhar: kubectl logs -n datamaster deploy/kafka --tail=40"
echo "           kubectl logs -n datamaster deploy/spark-master --tail=40"
echo "           kubectl logs -n datamaster deploy/jupyter --tail=40"
