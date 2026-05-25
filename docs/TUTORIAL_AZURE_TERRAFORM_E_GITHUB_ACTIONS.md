  # Tutorial: subir a stack no Azure (Terraform) e a API com GitHub Actions

  Este roteiro mostra como ir além do ambiente local: provisionar a infraestrutura de dados na **Azure** com **Terraform** e publicar a **API FastAPI** (imagem do `Dockerfile.api`) com um **pipeline no GitHub Actions** — build, push para o **Azure Container Registry (ACR)** e atualização do **Azure Container Apps**.

  > **Escopo do repositório hoje:** em `infrastructure/terraform/environments/dev/main.tf` já existem Resource Group, Data Lake (Storage Gen2), Event Hubs, Cosmos DB, Key Vault e PostgreSQL flexível. **Não** há ainda recursos de hospedagem da API no mesmo arquivo; ao final deste guia há um **exemplo opcional** (`container_api.tf.example`) para ACR + Container Apps, que você pode fundir ao módulo `dev`.

  **Deploy da API via CI:** o roteiro completo (App Registration, secrets, copiar o YAML, primeira run, validação `curl`/Swagger) está na **seção 6**.

  ---

  ## 1. O que você vai demonstrar

  | Camada | Ferramenta | Resultado |
  |--------|------------|-----------|
  | Infra (dados, integração, segredos, DB) | Terraform (`azurerm`) | Recursos reproducíveis na subscription |
  | Imagem da API | Docker + `Dockerfile.api` | Container com Uvicorn na porta 8000 |
  | Entrega contínua da API | GitHub Actions | A cada merge/push na branch principal: build → ACR → revisão nova no Container App |

  ---

  ## 2. Pré-requisitos

  - Conta Azure com **permissão** para criar resource groups, storage, etc.
  - [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) instalado.
  - [Terraform](https://developer.hashicorp.com/terraform/install) **≥ 1.5**.
  - [Docker](https://docs.docker.com/get-docker/) (para testar build local opcional).
  - Repositório no **GitHub** (para o workflow).

  ### 2.1 Login e subscription

  ```bash
  az login
  az account list --output table
  az account set --subscription "<SUBSCRIPTION_ID_OU_NOME>"
  ```

  Confirme:

  ```bash
  az account show --query "{name:name, id:id}" -o table
  ```

  ---

  ## 3. Deploy da infraestrutura com Terraform (módulo `dev`)

  ### 3.1 Nomes únicos globais

  No Azure, nomes como **storage account** e **Event Hubs namespace** precisam ser **únicos**. Ajuste em `terraform.tfvars` (crie a partir do exemplo):

  ```bash
  cp infrastructure/terraform/environments/dev/terraform.tfvars.example \
    infrastructure/terraform/environments/dev/terraform.tfvars
  ```

  Edite `terraform.tfvars` e troque, por exemplo:

  - `storage_account_name` → algo como `frauddemo2026abc` (só minúsculas e números, sem hífen, até 24 caracteres).
  - `event_hub_namespace` → algo como `fraud-events-demo-seunome`.

  **Senha do PostgreSQL:** use uma senha forte; ela fica no estado do Terraform — trate o `terraform.tfstate` como sensível.

  ### 3.2 Backend remoto (recomendado para time/CI)

  O bloco `backend "azurerm"` em `main.tf` está comentado. Para CI e revisões seguras:

  1. Crie manualmente (uma vez) um resource group, storage account e container para o state.
  2. Descomente e preencha `backend "azurerm" { ... }`.
  3. Rode `terraform init -migrate-state` se já tiver state local.

  Enquanto isso não estiver configurado, o Terraform usa **state local** (`terraform.tfstate` na pasta) — aceitável só na sua máquina.

  ### 3.3 Aplicar

  ```bash
  cd infrastructure/terraform/environments/dev
  terraform init -upgrade
  terraform plan -out=tfplan
  terraform apply tfplan
  ```

  ### 3.4 Conferir outputs

  ```bash
  terraform output
  ```

  Anote: nome do resource group, storage, namespace do Event Hub, endpoint do Cosmos, URI do Key Vault, servidor PostgreSQL — úteis para configurar a aplicação e para a narrativa da banca (“não roda só no Docker da minha máquina”).

  ### 3.5 Permissões no Key Vault (quando for usar secrets da app)

  O Key Vault criado pelo Terraform precisa de políticas de acesso ou RBAC para o usuário/identidade que vai ler segredos. Isso costuma ser um passo explícito (`azurerm_key_vault_access_policy` ou Azure RBAC). Ajuste conforme o modelo de identidade da API (Managed Identity no Container App é o ideal em produção).

  ---

  ## 4. Hospedar a API na Azure (visão geral)

  Fluxo típico:

  1. **Azure Container Registry (ACR)** — registro privado de imagens.
  2. **Azure Container Apps** — executa o container público/interno com HTTPS na borda (ingress).
  3. A imagem segue o `Dockerfile.api` na raiz do repositório (`uvicorn` na porta **8000**).

  No repositório foi adicionado um exemplo de Terraform em:

  `infrastructure/terraform/environments/dev/container_api.tf.example`

  **Como usar:**

  ```bash
  cd infrastructure/terraform/environments/dev
  cp container_api.tf.example container_api.tf
  # Revise nomes; depois:
  terraform plan
  terraform apply
  ```

  Depois do `apply`, pegue a URL do Container App (output sugerido no exemplo ou no portal). O exemplo Terraform usa a imagem **quickstart** na porta **8080** só para validar o ambiente. Depois que o **pipeline do GitHub Actions** (seção 6) rodar, ele já aplica **ingress na porta 8000** e a imagem **`fraud-api`** — ou você ajusta manualmente no portal / Terraform (`target_port = 8000`).

  Depois teste:

  ```bash
  curl -sS "https://<FQDN_DO_CONTAINER_APP>/health"
  ```

  > Se a API depender de variáveis (Connection strings, Event Hub, etc.), configure-as em `azurerm_container_app` → bloco `template` → `env` ou via Key Vault referenciado — alinhado à sua arquitetura de segredos.

  ---

  ## 5. Primeiro push manual da imagem (sanidade)

  Antes de automatizar no GitHub, valide build e push **na sua máquina** (substitua valores):

  ```bash
  # na raiz do repositório
  az acr login --name <NOME_DO_ACR_SEM_DOMINIO>

  docker build -f Dockerfile.api -t <NOME_ACR>.azurecr.io/fraud-api:v1 .
  docker push <NOME_ACR>.azurecr.io/fraud-api:v1
  ```

  Atualize o Container App para usar a tag `v1` (portal, CLI ou Terraform com `image` atualizado). Exemplo CLI:

  ```bash
  az containerapp update \
    --name <nome-do-container-app> \
    --resource-group <seu-rg> \
    --image <NOME_ACR>.azurecr.io/fraud-api:v1
  ```

  ---

  ## 6. Tutorial: subir a **API** pelo pipeline **GitHub Actions**

  Este é o fluxo completo **só para a API**: o GitHub compila a imagem a partir do `Dockerfile.api`, envia para o **ACR** e atualiza o **Azure Container App**. O Terraform (seções 3 e 4) precisa ter criado **ACR + Container App** antes — ou equivalente no portal.

  ### 6.1 O que o pipeline faz (resumo)

  1. **Checkout** do código no runner Ubuntu.
  2. **`azure/login`** com OIDC (sem senha da aplicação no repositório).
  3. **`az acr login`** no seu registro.
  4. **`docker build`** com `-f Dockerfile.api` e **push** de `:latest` e `:<commit-sha>`.
  5. **`az containerapp update --image ...`** apontando a nova revisão para a imagem no ACR.
  6. **`az containerapp ingress update --target-port 8000`** para alinhar com o Uvicorn da API (ver arquivo em `docs/examples/`).

  Arquivo de referência no repo: **`docs/examples/github-actions-deploy-api-azure.yml`**.

  ### 6.2 Pré-condições antes de ligar o GitHub

  | Item | Onde conferir |
  |------|----------------|
  | Resource Group existe | Portal Azure ou `terraform output` |
  | ACR criado e nome conhecido | Ex.: `frauddetectionacr01` (deve bater com o workflow) |
  | Container App criado e nome conhecido | Ex.: `fraud-detection-api` |
  | Branch principal | O exemplo usa `main`; se for `master`, altere o YAML em `on.push.branches` |

  ### 6.3 Registrar a identidade na Azure (OIDC — recomendado)

  Siga também o guia oficial: [Use the Azure Login action with OpenID Connect](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux).

  **Passo A — App registration**

  1. Portal Azure → **Microsoft Entra ID** → **App registrations** → **New registration**.
  2. Nome: ex. `github-actions-fraud-api`.
  3. **Accounts in this organizational directory only** (ou conforme sua política).
  4. Em **Register**, anote **Application (client) ID** e **Directory (tenant) ID**.

  **Passo B — Federated credential (GitHub)**

  1. Na app → **Certificates & secrets** → aba **Federated credentials** → **Add credential**.
  2. **Federated credential scenario**: *GitHub Actions deploying Azure resources*.
  3. **Organization** e **Repository**: seu usuário/org e nome do repo (ex. `datamaster`).
  4. **Entity**: *Branch* → **Branch name** `main` (ou a branch que dispara o deploy).
  5. **Name**: ex. `github-main-fraud-api` → **Add**.

  **Passo C — Papéis (RBAC) na subscription ou no RG**

  O principal da app registration precisa conseguir: **push de imagem no ACR** e **atualizar o Container App**.

  Opção **simples** (dev/demo): no Resource Group da solução, adicione uma role assignment:

  - **Role**: *Contributor*
  - **Assign access to**: *User, group, or service principal*
  - **Members**: a app registration `github-actions-fraud-api`

  Opção **mais restrita** (evolução): combine *AcrPush* no ACR + papel adequado em Container Apps (ex. *Contributor* só no Container App ou papéis customizados).

  Via CLI (substitua IDs e nomes):

  ```bash
  SUB_ID="<subscription-id>"
  RG="rg-fraud-detection-dev"
  APP_ID="<Application-client-id-do-pass-A>"

  az role assignment create \
    --assignee "$APP_ID" \
    --role "Contributor" \
    --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"
  ```

  ### 6.4 Secrets no repositório GitHub

  No GitHub: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

  | Secret | Valor |
  |--------|--------|
  | `AZURE_CLIENT_ID` | Application (client) ID da app registration |
  | `AZURE_TENANT_ID` | Directory (tenant) ID |
  | `AZURE_SUBSCRIPTION_ID` | ID da subscription Azure |

  Não é necessário `AZURE_CLIENT_SECRET` se você usar apenas OIDC com `azure/login@v2` como no exemplo.

  ### 6.5 Instalar o workflow no repositório

  Na raiz do projeto (local):

  ```bash
  mkdir -p .github/workflows
  cp docs/examples/github-actions-deploy-api-azure.yml .github/workflows/deploy-api-azure.yml
  ```

  **Edite** `.github/workflows/deploy-api-azure.yml` no bloco `env:` e deixe **iguais** aos recursos que o Terraform (ou o portal) criou:

  ```yaml
  env:
    AZURE_RESOURCE_GROUP: rg-fraud-detection-dev    # seu RG
    CONTAINER_APP_NAME: fraud-detection-api         # nome do Container App
    ACR_NAME: frauddetectionacr01                  # só o nome curto do ACR, sem .azurecr.io
    IMAGE_NAME: fraud-api                           # nome lógico da imagem no ACR
  ```

  Confirme também:

  - `on.push.branches` usa a branch que você trabalha (`main` ou outra).
  - `paths` lista os arquivos que, ao mudar, devem disparar o deploy (já inclui `Dockerfile.api`, `src/**`, etc.).

  Faça **commit** e **push** do arquivo para o GitHub.

  ### 6.6 Primeira execução do pipeline

  **Forma 1 — Disparo manual**

  1. GitHub → **Actions** → workflow **Deploy API → Azure (ACR + Container Apps)**.
  2. **Run workflow** → escolha a branch → **Run workflow**.

  **Forma 2 — Por commit**

  Altere um arquivo coberto por `paths` (ex. comentário em `src/api/main.py`) e faça push na `main`.

  Abra o job: cada etapa deve ficar verde. Se **Login no ACR** ou **Atualizar Container App** falhar, revise os papéis do passo 6.3.

  ### 6.7 Validar a API na nuvem

  O job imprime FQDN, `/health` e `/docs`. No seu terminal:

  ```bash
  # Substitua pelo FQDN que apareceu no log ou no portal
  curl -sS "https://<FQDN>/health"
  ```

  Abra no navegador: `https://<FQDN>/docs` (Swagger da FastAPI).

  ### 6.8 Alternativa: login com client secret (sem OIDC)

  Se não puder usar federated credential, crie um service principal com senha e use o login por JSON:

  ```bash
  az ad sp create-for-rbac \
    --name "github-fraud-api" \
    --role contributor \
    --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME> \
    --json-auth
  ```

  No GitHub, crie um secret `AZURE_CREDENTIALS` com o **JSON completo** retornado.

  No workflow, **substitua** o passo `Azure Login (OIDC)` por:

  ```yaml
        - name: Azure Login (client secret)
          uses: azure/login@v2
          with:
            creds: ${{ secrets.AZURE_CREDENTIALS }}
  ```

  E pode remover os três secrets OIDC se usar só `AZURE_CREDENTIALS`. Mantenha `permissions` mínimo (`contents: read`); `id-token: write` não é obrigatório nesse modo.

  ### 6.9 Ajustes comuns após o primeiro deploy

  - **API 502 / connection refused**: confira se o passo **Ingress na porta 8000** rodou sem erro e se o Container App está na última revisão.
  - **Pull de imagem falha**: ACR admin / `registry` no Terraform; identidade do pipeline com **AcrPull** ou **AcrPush** no ACR.
  - **Workflow não dispara**: branch diferente de `main` ou arquivo alterado fora dos `paths` — use **Run workflow** (manual) para testar.

  ### 6.10 Permissões no YAML (`permissions`)

  O job do exemplo inclui (necessário para OIDC):

  ```yaml
  permissions:
    id-token: write
    contents: read
  ```

  ---

  ## 7. Roteiro sugerido para apresentação (“nuvem, não só local”)

  1. Mostrar o **repositório**: Terraform em `infrastructure/terraform/environments/dev`.
  2. Mostrar **`terraform plan` / `apply`** (ou vídeo gravado) criando RG + dados + (opcional) Container Apps.
  3. Abrir o **GitHub Actions** com o último deploy verde.
  4. Chamar **`/health` e `/docs`** na URL pública do Container App.
  5. Conectar **mentalmente** com o restante: Event Hub e Storage já existem na mesma subscription para ingestão e lake — “o mesmo desenho do slide, materializado na Azure”.

  ---

  ## 8. Troubleshooting rápido

  | Sintoma | O que verificar |
  |--------|------------------|
  | `terraform apply` falha em nome de storage | Nome globalmente único; só `a-z` e `0-9`. |
  | Container App não puxa imagem | ACR admin / `registry` + `secret` no Terraform; rede privada (se usar). |
  | 403 no Key Vault | Access policy / RBAC para a identidade certa. |
  | GitHub Actions sem permissão | OIDC federation mal configurado; escopo do SP; `permissions:` do job. |

  ---

  ## 9. Arquivos de apoio neste repositório

  | Arquivo | Uso |
  |---------|-----|
  | `infrastructure/terraform/environments/dev/container_api.tf.example` | Opcional: ACR + Log Analytics + Container Apps Env + Container App |
  | `docs/examples/github-actions-deploy-api-azure.yml` | Copiar para `.github/workflows/` |
  | `Dockerfile.api` | Imagem da API FastAPI |
  | `docs/DEPLOYMENT.md` | Referência legada; este tutorial complementa com CA + Actions |

  ---

  ## 10. Custos e segurança (checklist curto)

  - **Desligue** o que não for usar (Container App scale to zero, remover ambiente de dev ao final da demo).
  - Não commite `terraform.tfvars` com senha real; use `.gitignore` e variáveis CI.
  - Prefira **Managed Identity** da aplicação para ACR e Key Vault em evoluções futuras.
  - Habilite **soft delete** e políticas de retenção onde fizer sentido (storage já tem padrões no módulo ampliado `terraform/azure/` se você integrar esse desenho).

  Com isso você cobre o argumento: **local para desenvolvimento; Azure + Terraform + pipeline para entrega e prova de portabilidade para nuvem**.
