#!/usr/bin/env bash
# Rode UMA vez no VPS (com sudo e senha): libera deploy CI sem pedir senha no k3s/kubectl.
set -euo pipefail

K3S_BIN="$(command -v k3s || true)"
KUBECTL_BIN="$(command -v kubectl || true)"
USER_NAME="$(whoami)"

if [[ -z "$K3S_BIN" ]]; then
  echo "k3s nao encontrado no PATH"
  exit 1
fi

K3S_BIN="$(readlink -f "$K3S_BIN")"

SUDOERS_FILE="/etc/sudoers.d/k3s-datamaster-${USER_NAME}"
{
  echo "# Deploy DataMaster (GitHub Actions) — usuario: ${USER_NAME}"
  echo "${USER_NAME} ALL=(ALL) NOPASSWD: ${K3S_BIN}"
  if [[ -n "$KUBECTL_BIN" ]]; then
    KUBECTL_BIN="$(readlink -f "$KUBECTL_BIN")"
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ${KUBECTL_BIN}"
  fi
} | sudo tee "$SUDOERS_FILE" >/dev/null

sudo chmod 440 "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE"

if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
  sudo chmod 644 /etc/rancher/k3s/k3s.yaml
fi

echo "OK. Teste:"
sudo -n "$K3S_BIN" ctr images list | head -3
echo "Se listou imagens acima, o deploy no GitHub deve passar."
