# Banca — Azure mínimo (API só)

Provisiona **Resource Group**, **Azure Container Registry**, **Container Apps Environment** e um **Container App** com imagem quickstart (porta 8080). Depois você faz **build** de `api-java/`, **push** para o ACR e **atualiza** o app na porta **8080**.

## 1. Login

```bash
az login
az account set --subscription "SUA_SUBSCRIPTION_ID"
```

## 2. Providers (uma vez)

```bash
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.OperationalInsights --wait
```

## 3. Terraform

```bash
cd infrastructure/terraform/banca-minimo
terraform init -upgrade
terraform apply
```

## 4. Imagem da API

Na **raiz do repositório**:

```bash
ACR=$(terraform -chdir=infrastructure/terraform/banca-minimo output -raw acr_name)
az acr login --name "$ACR"

docker build -f api-java/Dockerfile -t "${ACR}.azurecr.io/fraud-api:banca" api-java
docker push "${ACR}.azurecr.io/fraud-api:banca"
```

## 5. Atualizar Container App

```bash
RG=$(terraform -chdir=infrastructure/terraform/banca-minimo output -raw resource_group_name)
APP=$(terraform -chdir=infrastructure/terraform/banca-minimo output -raw container_app_name)
SERVER=$(terraform -chdir=infrastructure/terraform/banca-minimo output -raw acr_login_server)

az containerapp update --name "$APP" --resource-group "$RG" \
  --image "${SERVER}/fraud-api:banca"

az containerapp ingress update --name "$APP" --resource-group "$RG" \
  --target-port 8080
```

## 6. Testar

```bash
FQDN=$(terraform -chdir=infrastructure/terraform/banca-minimo output -raw container_app_fqdn)
curl -sS "https://${FQDN}/health"
```

## Destruir (para parar cobrança)

```bash
cd infrastructure/terraform/banca-minimo
terraform destroy
```
