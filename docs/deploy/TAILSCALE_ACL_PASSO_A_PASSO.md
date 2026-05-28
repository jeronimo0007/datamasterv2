# Tailscale ACL — passo a passo (GitHub → SSH no servidor)

Se a parte de **tags** e **Access controls** pareceu difícil, use primeiro o **[Modo fácil](#modo-fácil-sem-mexer-em-acl)**. Só vá para tags se quiser restringir o que o CI pode acessar.

---

## Modo fácil (sem mexer em ACL)

Funciona na maioria das tailnets pessoais (política padrão: dispositivos se enxergam).

### 1. Auth key simples (sem tag)

1. Abra [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. **Generate auth key**
3. Marque:
   - **Ephemeral** — sim (o runner some depois do job)
   - **Reusable** — sim (vários deploys)
   - **Pre-approved** — sim
4. **Não** preencha campo de tags (deixe vazio).
5. Copie a chave `tskey-auth-...`

### 2. GitHub Secret

| Secret | Valor |
|--------|--------|
| `TAILSCALE_AUTHKEY` | a chave inteira |

Comente OAuth no workflow e use só authkey — em `.github/workflows/deploy-vps.yml`:

```yaml
      - name: Conectar Tailscale
        uses: tailscale/github-action@v3
        with:
          authkey: ${{ secrets.TAILSCALE_AUTHKEY }}
          version: latest
```

(comente ou apague as linhas `oauth-client-id` e `oauth-secret`)

### 3. Secrets SSH (como antes)

`K8S_SSH_HOST`, `K8S_SSH_USER`, `K8S_SSH_KEY`

### 4. Testar

Rode o workflow **Deploy → VPS**. Se conectar, **não precisa de ACL com tags**.

### Se ainda falhar SSH (timeout)

Sua tailnet pode ter ACL **restritiva**. Veja [Verificar política atual](#verificar-política-atual) e use a regra simples abaixo (sem tags no servidor).

---

## Regra ACL simples (sem tags no servidor)

Só uma linha extra na política — o CI (qualquer nó novo autenticado) pode SSH em **qualquer máquina da tailnet**:

1. Admin → **Access controls** → **Edit file** (ou **Open editor**)
2. Procure o bloco `"acls": [`
3. **Antes** de qualquer regra `"action": "deny"` (se existir), adicione:

```json
{
  "action": "accept",
  "src": ["autogroup:member"],
  "dst": ["autogroup:member:22"]
}
```

4. **Save**

Isso permite SSH (porta 22) entre membros da tailnet — inclui o nó ephemeral do GitHub depois que ele entra com a auth key.

> Se já existir `"src": ["*"], "dst": ["*:*"]`, a tailnet já libera tudo — o problema não é ACL, é host SSH ou chave.

---

## Modo com tags (mais seguro)

Use quando quiser que **só** o GitHub acesse **só** o VPS na porta 22.

### Passo A — Abrir o editor ACL

1. [login.tailscale.com](https://login.tailscale.com)
2. Menu lateral **Access controls** (ou **Policy file**)
3. Botão **Edit policy file** / **Edit JSON**

Você verá um JSON grande. **Não apague tudo** — só acrescente blocos.

### Passo B — Quem pode usar as tags (`tagOwners`)

Dentro do `{` principal, procure `"tagOwners"`:

- Se **não existir**, crie no início (junto com os outros campos de nível raiz):

```json
"tagOwners": {
  "tag:github-ci": ["autogroup:admin"],
  "tag:server": ["autogroup:admin"]
},
```

- Se **já existir**, só **adicione** as duas linhas dentro do objeto existente (cuidado com vírgulas).

`autogroup:admin` = usuários admin da tailnet podem atribuir essas tags.

### Passo C — Regra de permissão (`acls`)

No array `"acls": [ ... ]`, adicione **no começo** do array:

```json
{
  "action": "accept",
  "src": ["tag:github-ci"],
  "dst": ["tag:server:22"]
},
```

Salve. O Tailscale valida o JSON — se der erro de sintaxe, vírgula faltando ou sobrando.

### Passo D — Colocar a tag no VPS

1. **Machines** (Máquinas)
2. Clique no seu servidor (ex. `servidor`)
3. **⋮** ou **Edit** / **Machine settings**
4. Campo **Tags** ou **Apply tags**
5. Adicione: `tag:server`
6. Salve

Aguarde alguns segundos. Em `tailscale status` no VPS pode aparecer a tag.

### Passo E — Auth key ou OAuth com tag `github-ci`

**Auth key:** ao gerar a chave, em **Tags** coloque: `tag:github-ci`

**OAuth:** no workflow, descomente:

```yaml
tags: tag:github-ci
```

### Exemplo de arquivo ACL mínimo completo

Se sua tailnet estiver vazia / padrão e você quiser substituir por um modelo pequeno (cuidado: apaga regras antigas):

```json
{
  "tagOwners": {
    "tag:github-ci": ["autogroup:admin"],
    "tag:server": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:github-ci"],
      "dst": ["tag:server:22"]
    },
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["autogroup:member:*"]
    }
  ]
}
```

A segunda regra mantém seu PC/telefone acessando tudo como antes. Ajuste conforme sua necessidade.

---

## Verificar política atual

1. **Access controls** → veja se existe regra com `"action": "deny"` ou só `"accept"` para `*`
2. No workflow falho, abra o log do passo **Conectar Tailscale** → `tailscale status` deve listar seu servidor
3. No passo de ping/SSH: `ping servidor....ts.net` deve responder

---

## Erros comuns

| Sintoma | O que fazer |
|---------|-------------|
| `tag:github-ci not permitted` | Falta `tagOwners` para `tag:github-ci` |
| SSH timeout | Falta regra ACL ou servidor sem `tag:server` no modo com tags |
| `invalid ACL` ao salvar | Vírgula extra no JSON — use validador JSON |
| OAuth OK mas SSH não | Use auth key modo fácil para isolar o problema |
| Não acho Tags na máquina | Atualize Tailscale no VPS; tags ficam no admin web |

---

## Resumo

| Objetivo | O que fazer |
|----------|-------------|
| **Mais rápido** | Auth key sem tags + workflow sem `tags:` |
| **Um pouco de ACL** | Regra `autogroup:member:22` |
| **Mais seguro** | `tag:server` no VPS + `tag:github-ci` no CI + regra na ACL |

Guia geral: [GITHUB_ACTIONS_TAILSCALE.md](GITHUB_ACTIONS_TAILSCALE.md)
