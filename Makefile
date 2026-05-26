# Alvos de deploy — use variaveis de ambiente ou GitHub Secrets (nunca commit senha).
.PHONY: deploy-prod deploy-k8s deploy-azure help

DEPLOY_DIR ?= /home/servidor/kubernets/datamasterv2
K8S_SSH_HOST ?= servidor.tailb0be8.ts.net
K8S_SSH_USER ?= root
K8S_SSH_PORT ?= 22
TF_DIR ?= infrastructure/terraform/apresentacao

help:
	@echo "Targets:"
	@echo "  deploy-prod   - deploy no servidor Kubernetes (SSH + script remoto)"
	@echo "  deploy-k8s    - alias de deploy-prod"
	@echo "  deploy-azure  - terraform plan/apply local (requer az login)"
	@echo "Docs: docs/DEPLOY_KUBERNETES_SERVIDOR.md"

deploy-prod: deploy-k8s

deploy-k8s:
	@test -n "$(K8S_SSH_HOST)" || (echo "Defina K8S_SSH_HOST"; exit 1)
	@test -n "$(K8S_SSH_USER)" || (echo "Defina K8S_SSH_USER"; exit 1)
	ssh -p $(K8S_SSH_PORT) $(K8S_SSH_USER)@$(K8S_SSH_HOST) \
		"DEPLOY_DIR=$(DEPLOY_DIR) GIT_REF=vps bash $(DEPLOY_DIR)/scripts/deploy-kubernetes-server.sh"

deploy-azure:
	cd $(TF_DIR) && terraform init -upgrade && terraform plan && terraform apply
