#!/usr/bin/env bash
# Dispara provisionamento VPS (k3s) + Azure (terraform apresentacao) em paralelo.
# A demo ao vivo na banca continua sendo Docker local (portal :8880).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== DataMaster — pré-banca (VPS + Azure em paralelo) ==="
echo ""
echo "1) LOCAL (faça na hora da demo ou agora para testar):"
echo "   docker compose up -d --build"
echo "   bash scripts/run_demo.sh"
echo "   Portal: http://localhost:8880"
echo ""
echo "2) VPS — stack completa Kubernetes (escolha UMA opção):"
echo "   A) No servidor homelab:"
echo "      ssh servidor 'cd /home/servidor/kubernets/datamasterv2 && git fetch origin vps && git reset --hard origin/vps && bash scripts/deploy-kubernetes-server.sh'"
echo "   B) Da sua máquina (CI):"
echo "      git push origin vps"
echo "      # Acompanhe: GitHub Actions → Deploy → VPS (Kubernetes)"
echo "   NodePorts: docs/deploy/DEPLOY_K8S.md"
echo ""
echo "3) AZURE — stack apresentacao (outro terminal):"
echo "   cd infrastructure/terraform/apresentacao"
echo "   cp -n terraform.tfvars.example terraform.tfvars 2>/dev/null || true"
echo "   # Edite db_admin_password em terraform.tfvars"
echo "   terraform init -upgrade && terraform apply"
echo "   # Depois: docker push da api-java para o ACR (ver README nesta pasta)"
echo ""
echo "4) AWS — NÃO aplicar na banca:"
echo "   Use apenas o slide mapa multicloud (equivalências Kinesis, S3, SageMaker)."
echo ""
echo "Documentação: docs/operacao/CHECKLIST_DEMO_BANCA.md"
