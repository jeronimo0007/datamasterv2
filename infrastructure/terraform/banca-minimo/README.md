# Terraform — banca mínimo (Azure)

Comandos resumidos. Guia completo: `docs/cloud/TERRAFORM_BANCA_MINIMO.md`.

```bash
az login
cd infrastructure/terraform/banca-minimo
terraform init -upgrade
terraform apply
```

API Java: build `api-java/`, push ACR, atualizar Container App na porta **8080**.
