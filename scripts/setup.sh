#!/bin/bash
# Setup local: Docker (infra + API Java + dashboard) e venv Python para scripts.

set -e

echo "Configurando ambiente local..."

if ! command -v docker &> /dev/null; then
    echo "Docker nao encontrado. Instale o Docker Desktop."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "Docker daemon nao esta rodando. Abra o Docker Desktop e tente de novo."
    exit 1
fi

if command -v python3 &> /dev/null; then
    echo "Criando venv Python (dashboard e scripts)..."
    python3 -m venv .venv
    # shellcheck source=/dev/null
    source .venv/bin/activate
    pip install --upgrade pip -q
    pip install -r requirements-demo.txt -q
fi

echo "Subindo stack com Docker Compose..."
docker compose up -d --build

echo ""
echo "Pronto."
echo "  API Java:    http://localhost:8080/swagger-ui.html"
echo "  Dashboard:   http://localhost:8501"
echo "  Demo:        bash scripts/demo.sh"
echo "  Parar:       docker compose down"
