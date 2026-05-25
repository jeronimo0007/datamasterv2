# Terraform — stack de apresentação (Azure)

Provisiona o **mesmo desenho** dos slides e do Docker Compose local:

| Slide / local | Azure (este módulo) |
|---------------|---------------------|
| Event Hubs | `azurerm_eventhub` + namespace |
| ADLS Bronze/Silver/Gold | containers `bronze`, `silver`, `gold` (+ `raw`/`processed`/`curated`) |
| API REST | Container App + ACR (imagem `api-java`) |
| Cosmos DB | `azurerm_cosmosdb_*` |
| PostgreSQL | Flexible Server |
| Key Vault | `azurerm_key_vault` |
| Monitor + App Insights | Log Analytics + Application Insights |
| Databricks / Synapse / AML | `enable_analytics_stack = true` (opcional, caro) |

Mapa completo local ↔ nuvem: [../../MAPA_LOCAL_AZURE.md](../../MAPA_LOCAL_AZURE.md).

### No slide mas não neste Terraform (fale na banca)

| Bloco no diagrama | Na demo |
|-------------------|---------|
| **Data Factory** | Orquestração batch — local: `scripts/` + `demo_full_stack.sh`; Azure: ADF em projeto CI/CD |
| **Purview** | Governança — `config/governanca.yaml` + narrativa |
| **Power BI** | BI — local: **Streamlit** :8501 |

Com `enable_analytics_stack = true` entram **Databricks, Synapse e Azure ML** (par do slide de processamento/ML).

## Pré-requisitos

```bash
az login
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.OperationalInsights --wait
az provider register -n Microsoft.EventHub --wait
```

## Apply

```bash
cd infrastructure/terraform/apresentacao
cp terraform.tfvars.example terraform.tfvars
# Edite db_admin_password

terraform init -upgrade
terraform plan
terraform apply
```

## Publicar API Java (após apply)

```bash
RG=$(terraform output -raw resource_group_name)
ACR=$(terraform output -raw container_registry_login_server)
APP=$(terraform output -raw container_app_api_name)

az acr login --name "${ACR%%.azurecr.io}"

docker build -f api-java/Dockerfile -t "${ACR}/fraud-api:apresentacao" api-java
docker push "${ACR}/fraud-api:apresentacao"

az containerapp update -g "$RG" -n "$APP" \
  --image "${ACR}/fraud-api:apresentacao"

az containerapp ingress update -g "$RG" -n "$APP" --target-port 8080

FQDN=$(terraform output -raw container_app_api_fqdn)
curl -s "https://${FQDN}/health"
```

## Stack analítica completa (slide com Databricks)

No `terraform.tfvars`:

```hcl
enable_analytics_stack           = true
analytics_high_cost_acknowledged = true
```

Requer registro: `Microsoft.Synapse`, `Microsoft.Databricks`, `Microsoft.MachineLearningServices`.

## Destruir

```bash
terraform destroy
```
