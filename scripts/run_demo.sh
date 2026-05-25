#!/usr/bin/env bash
# Fluxo completo da demo: stack + JSON + MongoDB + Spark Medallion.
# Use sempre após subir Docker (ou sozinho — o script sobe a stack).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/demo_full_stack.sh"
