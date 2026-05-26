#!/usr/bin/env bash
# Deploy DataMaster COMPLETO no VPS via Kubernetes (k3s).
# Executado pelo GitHub Actions (SSH) ou manualmente no servidor.
set -euo pipefail

REPO_DIR="${DEPLOY_DIR:-/home/servidor/kubernets/datamasterv2}"
GIT_REF="${GIT_REF:-vps}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infrastructure/kubernetes/overlays/homelab}"

REPO_ABS="$(cd "$REPO_DIR" && pwd)"
cd "$REPO_ABS"

git config --global --add safe.directory "$REPO_ABS"

if [[ -d .git ]]; then
  git fetch origin "$GIT_REF"
  git reset --hard "origin/${GIT_REF}"
else
  echo "ERRO: $REPO_ABS nao e um repositorio git." >&2
  exit 1
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [[ -z "${KAFKA_EXTERNAL_HOST:-}" ]]; then
  KAFKA_EXTERNAL_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  export KAFKA_EXTERNAL_HOST
fi

kubectl_cmd() {
  if kubectl "$@" 2>/dev/null; then
    return 0
  fi
  sudo -n kubectl "$@"
}

k3s_ctr() {
  if command -v k3s >/dev/null 2>&1; then
    sudo -n k3s ctr "$@"
  else
    echo "ERRO: k3s nao encontrado" >&2
    exit 1
  fi
}

echo "==> Parar Docker Compose (evita conflito de portas com NodePorts)"
if docker compose version >/dev/null 2>&1; then
  docker compose -f docker-compose.yaml -f docker-compose.vps.yaml down 2>/dev/null || true
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado (necessario para build das imagens)." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1 && ! command -v k3s >/dev/null 2>&1; then
  echo "ERRO: kubectl/k3s nao encontrado." >&2
  exit 1
fi

echo "==> Build imagens da aplicacao (tag ${IMAGE_TAG})"
docker build -f api-java/Dockerfile -t "datamaster-api:${IMAGE_TAG}" api-java
docker build -f Dockerfile.dashboard -t "datamaster-dashboard:${IMAGE_TAG}" .
docker build -f portal/Dockerfile -t "datamaster-portal:${IMAGE_TAG}" .  # contexto raiz (COPY portal/...)
docker build -f data-generator-console/Dockerfile -t "datamaster-data-console:${IMAGE_TAG}" .

echo "==> Importar imagens no k3s"
for img in datamaster-api datamaster-dashboard datamaster-portal datamaster-data-console; do
  docker save "${img}:${IMAGE_TAG}" | k3s_ctr images import -
done

kubectl_cmd create namespace datamaster --dry-run=client -o yaml | kubectl_cmd apply -f -

if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
  kubectl_cmd create secret generic datamaster-app-secrets -n datamaster \
    --from-literal=DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY}" \
    --dry-run=client -o yaml | kubectl_cmd apply -f -
fi

echo "==> Sincronizar config/ do Kustomize (SQL, Grafana, Mongo init)"
bash "${REPO_ABS}/scripts/sync-k8s-config.sh"

echo "==> Aplicar manifests (Kustomize homelab)"
tmp="$(mktemp)"
kubectl_cmd kustomize "${REPO_ABS}/${KUSTOMIZE_OVERLAY}" \
  | sed "s/newTag: latest/newTag: ${IMAGE_TAG}/g" >"$tmp"
kubectl_cmd apply -f "$tmp"
rm -f "$tmp"

echo "==> hostPath do repo (${REPO_ABS}) em data-console e jupyter"
for dep in data-console jupyter; do
  kubectl_cmd patch deployment "$dep" -n datamaster --type=strategic -p "
spec:
  template:
    spec:
      volumes:
        - name: workspace
          hostPath:
            path: ${REPO_ABS}
            type: Directory
" 2>/dev/null || true
done

echo "==> Job minio-init (recriar se ja existir)"
kubectl_cmd delete job minio-init -n datamaster --ignore-not-found=true
kubectl_cmd apply -f "${REPO_ABS}/infrastructure/kubernetes/base/minio-init-job.yaml"

echo "==> Kafka advertised listeners (acesso externo NodePort 30902)"
kubectl_cmd set env deployment/kafka -n datamaster \
  KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://kafka:29092,PLAINTEXT_HOST://${KAFKA_EXTERNAL_HOST}:30902" \
  --overwrite=true 2>/dev/null || true

echo "==> Aguardar API (NodePort 30080)"
for i in $(seq 1 60); do
  if curl -sf http://127.0.0.1:30080/health >/dev/null 2>&1; then
    echo "API OK"
    break
  fi
  if [[ "$i" -eq 60 ]]; then
    echo "AVISO: API ainda nao respondeu — kubectl logs -n datamaster deploy/api"
  fi
  sleep 3
done

NODE_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo ""
kubectl_cmd get pods -n datamaster -o wide
echo ""
echo "Deploy Kubernetes concluido (ref ${GIT_REF}, tag ${IMAGE_TAG})."
echo "NodePorts no host (${NODE_IP}):"
echo "  Portal      http://${NODE_IP}:30880"
echo "  API         http://${NODE_IP}:30080"
echo "  Dashboard   http://${NODE_IP}:30501"
echo "  Console     http://${NODE_IP}:30333"
echo "  Grafana     http://${NODE_IP}:30300  (admin/admin)"
echo "  Prometheus  http://${NODE_IP}:30090"
echo "  Spark UI    http://${NODE_IP}:30180"
echo "  Jupyter     http://${NODE_IP}:30888  (token: datamaster)"
echo "  MinIO       http://${NODE_IP}:30901"
echo "  Kafka       ${NODE_IP}:30902"
