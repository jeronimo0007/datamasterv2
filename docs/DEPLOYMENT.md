# Guia de Deployment

## Pré-requisitos

- Azure CLI instalado e configurado
- Terraform 1.5+
- Docker e Docker Compose
- Java 17+
- Python 3.9+

## Deploy com Terraform

### 1. Configurar Variáveis

Edite `infrastructure/terraform/environments/dev/terraform.tfvars`:

```hcl
resource_group_name = "rg-fraud-detection-dev"
location            = "brazilsouth"
storage_account     = "fraudstoragedev"
event_hub_namespace = "fraud-events-dev"
```

### 2. Inicializar Terraform

```bash
cd infrastructure/terraform/environments/dev
terraform init
```

### 3. Planejar Deploy

```bash
terraform plan
```

### 4. Aplicar Deploy

```bash
terraform apply
```

## Deploy Manual

### 1. Criar Resource Group

```bash
az group create --name rg-fraud-detection --location brazilsouth
```

### 2. Criar Storage Account

```bash
az storage account create \
  --name fraudstorage \
  --resource-group rg-fraud-detection \
  --location brazilsouth \
  --sku Standard_LRS \
  --kind StorageV2
```

### 3. Criar Event Hub

```bash
az eventhubs namespace create \
  --name fraud-events \
  --resource-group rg-fraud-detection \
  --location brazilsouth \
  --sku Standard

az eventhubs eventhub create \
  --name transactions \
  --namespace-name fraud-events \
  --resource-group rg-fraud-detection \
  --message-retention 1 \
  --partition-count 4
```

### 4. Deploy da API Java

```bash
cd api-java
./mvnw clean package
az spring-cloud app deploy \
  --name fraud-api \
  --resource-group rg-fraud-detection \
  --service fraud-service \
  --jar-path target/fraud-detection-api-1.0.0.jar
```

## Configuração de Ambiente

1. Configure variáveis de ambiente no Azure Key Vault
2. Configure Managed Identities para serviços
3. Configure regras de firewall e rede
4. Configure alertas e monitoramento

## Validação

Após o deploy, valide:

1. APIs respondendo corretamente
2. Event Hubs recebendo eventos
3. Data Lake armazenando dados
4. Monitoramento funcionando

