# GitHub Actions + Tailscale (acessar o VPS)

O runner do GitHub roda na nuvem da Microsoft/GitHub — **não** está na sua rede local. Com **Tailscale**, o workflow entra na sua **tailnet** por alguns minutos e faz SSH no host `servidor.tailXXXX.ts.net`.

## Visão

```text
GitHub Actions (ubuntu-latest)
    → tailscale/github-action  (entra na tailnet)
    → SSH → servidor.tailb0be8.ts.net:22
    → scripts/deploy-kubernetes-server.sh
```

## Passo 1 — Servidor na tailnet

No VPS (já deve estar assim se você acessa pelo MagicDNS):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status   # anote o nome, ex: servidor
```

No [admin Tailscale](https://login.tailscale.com/admin/machines): confirme **MagicDNS** ligado (Settings → DNS).

O host SSH será algo como: `servidor.tailb0be8.ts.net` (o seu tailnet ID pode diferir).

## Passo 2 — ACL (opcional)

**Dificuldade com tags/ACL?** Use o **[Modo fácil sem ACL](TAILSCALE_ACL_PASSO_A_PASSO.md#modo-fácil-sem-mexer-em-acl)** (auth key sem tags).

Para restringir só SSH do CI → VPS: **[TAILSCALE_ACL_PASSO_A_PASSO.md](TAILSCALE_ACL_PASSO_A_PASSO.md)** (passo a passo com prints mentais e JSON para copiar).

## Passo 3 — OAuth (obrigatório no workflow atual)

O `tailscale/github-action@v3` **não aceita** auth key vazia e exige **OAuth + tag**.

### 3.1 Criar OAuth client (onde achar no painel)

O Tailscale moveu isso para **Trust credentials** (não aparece como “OAuth clients” em Settings em contas novas).

**Caminho A — link direto**

[https://login.tailscale.com/admin/settings/oauth](https://login.tailscale.com/admin/settings/oauth)

**Caminho B — menu**

1. [login.tailscale.com/admin](https://login.tailscale.com/admin)
2. Menu lateral → **Settings** (Configurações) ou **User settings**
3. Procure **Trust credentials** / **Credenciais de confiança**
4. Botão **Credential** / **Create credential** → tipo **OAuth**
5. Scope: **Devices** → **Write** (permite criar nós ephemeral do CI)
6. **Generate credential** → copie **Client ID** e **Client secret** (o secret só aparece uma vez)

Precisa ser **Owner**, **Admin** ou **Network admin** da tailnet. Conta gratuita pessoal costuma ter permissão se você é dono da rede.

Se **não existir** OAuth na sua conta, use a **Auth Key** abaixo (mais fácil).

### 3.2 ACL mínima para a tag `tag:ci`

Admin → **Access controls** → adicione (ou mescle no JSON existente):

```json
"tagOwners": {
  "tag:ci": ["autogroup:admin"]
},
"acls": [
  {
    "action": "accept",
    "src": ["tag:ci"],
    "dst": ["autogroup:member:22"]
  }
]
```

Isso permite o runner do GitHub (`tag:ci`) fazer SSH em qualquer máquina da tailnet. Ajuste depois se quiser restringir.

### 3.3 Secrets no GitHub

| Secret | Valor |
|--------|--------|
| `TS_OAUTH_CLIENT_ID` | Client ID |
| `TS_OAUTH_SECRET` | Client secret |

> Erro **"OAuth identity empty"** = falta `TS_OAUTH_CLIENT_ID` ou `TS_OAUTH_SECRET`, ou faltou `tags:` no workflow.  
> Se usava só `TAILSCALE_AUTHKEY` vazia, o v3 falha antes de conectar.

### Alternativa: Auth Key (mais fácil de achar)

1. [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. **Generate auth key** / **Gerar chave**
3. Marque: **Ephemeral**, **Reusable**, **Pre-approved**
4. Tags: vazio (homelab) ou `tag:ci` se usar ACL
5. Copie `tskey-auth-...`
6. GitHub secret: `TAILSCALE_AUTHKEY`

No workflow, troque o passo Tailscale para auth key (e comente OAuth) — ver comentário em `.github/workflows/deploy-vps.yml` ou peça para usar só auth key.

> Auth key **só funciona** se o secret no GitHub tiver a chave completa (não pode estar vazio).

## Passo 4 — Secrets SSH (GitHub)

| Secret | Exemplo |
|--------|---------|
| `K8S_SSH_HOST` | `servidor.tailb0be8.ts.net` |
| `K8S_SSH_USER` | `root` ou `ubuntu` |
| `K8S_SSH_KEY` | chave privada OpenSSH (recomendado) |
| `K8S_DEPLOY_DIR` | `/opt/datamaster` |

### Chave SSH dedicada ao CI

Na sua máquina:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/datamaster-github -N ""
cat ~/.ssh/datamaster-github.pub
```

No servidor:

```bash
echo "CONTEUDO_DA_CHAVE_PUBLICA" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

No GitHub: secret `K8S_SSH_KEY` = conteúdo de `~/.ssh/datamaster-github` (privada).

## Passo 5 — Testar

1. Commit na branch **`vps`** (ou **Actions** → **Deploy → VPS** → Run workflow).
2. No log, o passo **Conectar Tailscale** deve ficar verde.
3. O passo **Deploy via SSH** deve conectar e rodar o script.

Se falhar:

| Erro | Causa provável |
|------|----------------|
| Tailscale login failed | OAuth/Auth key errado ou expirado |
| SSH timeout | ACL bloqueando `tag:github-ci` → servidor |
| Host not found | MagicDNS off ou `K8S_SSH_HOST` errado |
| Permission denied | `K8S_SSH_KEY` / usuário incorretos |

## Alternativa: runner self-hosted

Se preferir **não** usar Tailscale no workflow:

1. Instale o [GitHub Actions Runner](https://docs.github.com/actions/hosting-your-own-runners) **no VPS** (ou numa máquina sempre na tailnet).
2. No workflow, use `runs-on: self-hosted` e remova o passo Tailscale.

O runner já está na rede; SSH pode ser `localhost` ou IP `100.x.x.x` do Tailscale.

## Referências

- [Tailscale + GitHub Actions](https://tailscale.com/kb/1276/github-action)
- [deploy-vps.yml](../.github/workflows/deploy-vps.yml)
