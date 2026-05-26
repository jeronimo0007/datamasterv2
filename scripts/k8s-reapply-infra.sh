#!/usr/bin/env bash
# Reaplica so kafka/zookeeper/spark/jupyter (apos git pull com fixes).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl_cmd() { kubectl "$@" 2>/dev/null || sudo -n kubectl "$@"; }

for f in zookeeper.yaml kafka.yaml spark.yaml jupyter.yaml; do
  kubectl_cmd apply -f "${ROOT}/infrastructure/kubernetes/base/${f}"
done

kubectl_cmd rollout restart deployment/zookeeper deployment/kafka deployment/spark-master deployment/spark-worker deployment/jupyter -n datamaster
kubectl_cmd rollout status deployment/kafka -n datamaster --timeout=300s || true
kubectl_cmd rollout status deployment/spark-master -n datamaster --timeout=300s || true
kubectl_cmd rollout status deployment/jupyter -n datamaster --timeout=300s || true
kubectl_cmd get pods -n datamaster | grep -E 'kafka|zookeeper|spark|jupyter' || kubectl_cmd get pods -n datamaster
