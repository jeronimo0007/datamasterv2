#!/usr/bin/env bash
# Remove Service duplicado jupyter-svc (NodePort 30888 em conflito com jupyter).
set -euo pipefail
kubectl_cmd() { kubectl "$@" 2>/dev/null || sudo -n kubectl "$@"; }
kubectl_cmd delete svc jupyter-svc -n datamaster --ignore-not-found=true
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl_cmd apply -f "${ROOT}/infrastructure/kubernetes/base/jupyter.yaml"
kubectl_cmd get svc -n datamaster jupyter
echo "Jupyter: http://$(hostname -I | awk '{print $1}'):30888 (token: datamaster)"
