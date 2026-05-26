# Alvos de deploy — use variaveis de ambiente ou GitHub Secrets (nunca commit senha).
.PHONY: help up-local up-vps deploy-prod deploy-k8s deploy-azure

DEPLOY_DIR ?= /home/servidor/kubernets/datamasterv2
K8S_SSH_HOST ?= servidor.tailb0be8.ts.net
K8S_SSH_USER ?= root
K8S_SSH_PORT ?= 22
TF_DIR ?= infrastructure/terraform/apresentacao
COMPOSE_VPS = docker compose -f docker-compose.yaml -f docker-compose.vps.yaml

help:
	@echo "Targets:"
	@echo "  up-local      - docker compose local (docs/AMBIENTE_LOCAL.md)"
	@echo "  up-vps        - compose com overlay VPS (no servidor)"
	@echo "  deploy-prod   - SSH + deploy K8s remoto (branch vps)"
	@echo "  deploy-k8s    - alias de deploy-prod"
	@echo "  deploy-azure  - terraform plan/apply (requer az login)"
	@echo "Docs: docs/AMBIENTE_LOCAL.md | docs/DEPLOY_VPS.md"

up-local:
	bash scripts/up-local.sh

up-vps:
	bash scripts/up-vps.sh

deploy-prod: deploy-k8s

deploy-k8s:
	@test -n "$(K8S_SSH_HOST)" || (echo "Defina K8S_SSH_HOST"; exit 1)
	@test -n "$(K8S_SSH_USER)" || (echo "Defina K8S_SSH_USER"; exit 1)
	ssh -p $(K8S_SSH_PORT) $(K8S_SSH_USER)@$(K8S_SSH_HOST) \
		"DEPLOY_DIR=$(DEPLOY_DIR) GIT_REF=vps bash $(DEPLOY_DIR)/scripts/deploy-kubernetes-server.sh"

deploy-azure:
	cd $(TF_DIR) && terraform init -upgrade && terraform plan && terraform apply
