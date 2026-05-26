#!/usr/bin/env bash
# Importa imagens Docker buildadas para o containerd do k3s com o nome que o kubelet usa.
# Uso: IMAGE_TAG=abc123 bash scripts/k3s-import-app-images.sh
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:?Defina IMAGE_TAG (ex. git SHA do deploy)}"

k3s_ctr() {
  sudo -n k3s ctr "$@"
}

import_one() {
  local short="$1" # datamaster-api
  local ref="docker.io/library/${short}"

  if ! docker image inspect "${short}:${IMAGE_TAG}" >/dev/null 2>&1; then
    echo "ERRO: imagem local ${short}:${IMAGE_TAG} nao existe. Rode o build antes." >&2
    exit 1
  fi

  docker tag "${short}:${IMAGE_TAG}" "${ref}:${IMAGE_TAG}"
  docker tag "${short}:${IMAGE_TAG}" "${ref}:latest"

  echo "==> Importando ${ref}:${IMAGE_TAG}"
  docker save "${ref}:${IMAGE_TAG}" | k3s_ctr images import -

  # Alias :latest no containerd (kubelet resolve datamaster-api -> docker.io/library/...)
  if k3s_ctr images ls -q | grep -q "${ref}:${IMAGE_TAG}"; then
    k3s_ctr images tag "${ref}:${IMAGE_TAG}" "${ref}:latest" 2>/dev/null || true
  fi
}

for img in datamaster-api datamaster-dashboard datamaster-portal datamaster-data-console datamaster-email-worker; do
  import_one "$img"
done

echo "==> Imagens no k3s:"
k3s_ctr images ls -q | grep datamaster || true
