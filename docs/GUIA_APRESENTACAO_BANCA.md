# Guia rápido — apresentação na banca

Use este roteiro **terminal a terminal**. Abra o Terminal (macOS) ou o terminal integrado do Cursor.

**Pasta do projeto** (ajuste se estiver em outro lugar):

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
```

**Sempre que abrir um terminal novo** para este projeto, entre na pasta e ative o ambiente virtual:

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
source .venv/bin/activate
```

---

## Pré-requisitos (uma vez, antes do dia)

1. Python 3 instalado (`python3 --version`).
2. Dependências instaladas: `pip install -r requirements-demo.txt` (com a `.venv` ativa).
3. Se a pasta `.venv` não existir: `python3 -m venv .venv` e depois o `pip install` acima.

---

## Ordem sugerida na apresentação

| Ordem | Terminal | O que faz |
|-------|----------|-----------|
| 1 | **A** | (Opcional) Treinar modelo antecipadamente |
| 2 | **B** | Subir a API |
| 3 | **C** | Subir o dashboard Streamlit |
| 4 | **D** | Rodar o script de demo (ou usar só o navegador) |

Deixe os terminais **B** e **C** abertos com os processos rodando. Use **D** quando for mostrar os `curl`/fluxo guiado.

---

## Terminal A — Treinar o modelo (opcional)

**Quando usar:** na primeira vez no computador, ou se quiser garantir o arquivo `models/fraud_model.pkl` antes da banca (evita o treino automático na subida da API, que demora mais).

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
source .venv/bin/activate
PYTHONPATH=. python src/ml_models/fraud_model.py
```

Aguarde terminar. Pode fechar este terminal depois.

**Se já existir `models/fraud_model.pkl`**, você pode pular o Terminal A — a API carrega o arquivo sozinha.

---

## Terminal B — API (FastAPI)

**Deixe rodando durante toda a demo.**

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
source .venv/bin/activate
PYTHONPATH=. uvicorn src.api.main:app --port 8000
```

**No navegador:**

- API: http://127.0.0.1:8000  
- Documentação interativa (Swagger): http://127.0.0.1:8000/docs  

---

## Terminal B2 (opcional) — Spring Boot como fachada (mesmo contrato)

Use quando quiser **expor a API na porta 8080 com Java**, mantendo o **ML e o estado em memória na FastAPI** (porta **8000**). O Spring encaminha as requisições para a Python.

1. Deixe o **Terminal B** (`uvicorn` na **8000**) rodando.
2. Em outro terminal, na pasta `api-java` (com Maven instalado):

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final/api-java
mvn spring-boot:run -Dspring-boot.run.profiles=banca
```

- **Fachada Spring:** http://127.0.0.1:8080  
- Variável opcional se a Python não estiver em `127.0.0.1:8000`: `ML_PROXY_BASE_URL=http://host:porta`  
- Se a porta **8080** já estiver em uso (ex.: Spark no Docker), use `SERVER_PORT=8081` ao subir o Spring.

**Dashboard / demo:** no Streamlit, **API URL** = `http://127.0.0.1:8080` (ou a porta que escolheu). No script: `API_URL=http://127.0.0.1:8080 bash scripts/demo.sh`.

---

## Terminal C — Dashboard (Streamlit)

**Abra outro terminal. Deixe rodando junto com o Terminal B.**

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
source .venv/bin/activate
PYTHONPATH=. streamlit run src/dashboard/app.py --server.port 8501
```

**No navegador:** http://127.0.0.1:8501  

Na barra lateral, confira se a **API URL** está como `http://127.0.0.1:8000` (padrão fora do Docker).

---

## Terminal D — Demo guiada (script)

**Só depois** do Terminal B estar no ar (API respondendo).

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
source .venv/bin/activate
bash scripts/demo.sh
```

O script pede **Enter** entre as etapas — bom ritmo para explicar na banca.

Se a API estiver em outra URL/porta:

```bash
API_URL=http://127.0.0.1:8000 bash scripts/demo.sh
```

---

## Cola de URLs

| Serviço    | URL |
|------------|-----|
| Swagger    | http://127.0.0.1:8000/docs |
| Health     | http://127.0.0.1:8000/health |
| Spring (perfil banca, opcional) | http://127.0.0.1:8080/health |
| Dashboard  | http://127.0.0.1:8501 |

---

## Alternativa: tudo com Docker

Se preferir um único comando (API, dashboard, banco, etc.):

```bash
cd /Users/jeronimo/projetos/datamaster-apresentacao_final
docker compose up --build
```

Espere os serviços subirem; use as mesmas portas **8000** (API) e **8501** (dashboard) no navegador.

---

## Problemas rápidos na hora H

| Sintoma | O que verificar |
|---------|------------------|
| `pip: command not found` | Ative a venv: `source .venv/bin/activate` ou use `python3 -m pip ...` |
| `python: command not found` | Use `python3` ou ative a `.venv` |
| Porta 8000 em uso | Feche o outro `uvicorn` ou use outra porta (e ajuste URL no dashboard/demo) |
| localhost:8501 não abre | O Streamlit precisa estar rodando no **Terminal C** |
| Dashboard não fala com a API | API URL na sidebar = `http://127.0.0.1:8000`; API precisa estar no **Terminal B** |

---

## Roteiro verbal — regras de detecção de fraude (banca)

*(Texto para você explicar com segurança o que o sistema faz hoje.)*

### Visão geral

O pipeline não usa só uma “regra fixa” nem só o modelo: primeiro calculamos um **score de fraude entre 0 e 1** combinando **dois blocos de aprendizado de máquina** e, em seguida, aplicamos uma **heurística de piso muito restrita** só para cenários extremos típicos de demonstração. Depois disso, o score alimenta **faixas de risco operacional** (aprovar, monitorar, revisar, bloquear) e um **limiar binário** que define se contamos a transação como **fraude** nos indicadores e nos **alertas**.

### Quais informações entram na decisão

Para cada transação usamos, entre outras: **valor (`amount`)**, **hora** e se é **fim de semana**, se é **internacional** (país do usuário ≠ país do estabelecimento), **categoria do comerciante** e **meio de pagamento** (após codificação numérica para o modelo), além de **`log_amount`** (logaritmo do valor), quando aplicável. Tudo isso passa por um **pré-processamento** (escala e codificação) alinhado ao que foi usado no treino.

### Score do ensemble (machine learning)

O score base vem da média ponderada de dois modelos:

1. **Isolation Forest** — trata **anomalias** no espaço das features; a saída é normalizada para um intervalo entre 0 e 1 e entra com peso **40%** no score final.
2. **XGBoost** — classificador supervisionado; usamos a **probabilidade da classe fraude** com peso **60%**.

O resultado é limitado entre **0 e 1**. Em seguida o sistema compara esse valor com regras extras abaixo.

### Heurística de piso (cenários extremos da demo)

Para evitar que a taxa de fraude exploda em lote de testes, as regras explícitas são **estreitas**: só elevam o score quando vários fatores de risco aparecem **juntos**.

- **Janela “madrugada / noite”:** hora **antes das 6** ou **depois das 22**.
- **Regra mais forte (piso 0,68):** valor **≥ R$ 42.000**, transação **internacional**, **fim de semana**, **cartão de crédito** e horário na janela noturna acima.
- **Regra um pouco mais ampla (piso 0,64):** valor **≥ R$ 40.000**, **internacional**, **fim de semana** e **cartão de crédito** (sem exigir a janela de madrugada).

O **score final** é o **máximo** entre o que o ensemble já tinha produzido e esse **piso** — ou seja, a heurística só **força** casos muito específicos, como o exemplo clássico da apresentação (valor alto, internacional, fim de semana, cartão).

### Faixas de risco e ações sugeridas

Com o score já calculado, classificamos a **severidade** para narrativa operacional:

| Score | Nível de risco | Ação sugerida |
|-------|------------------|----------------|
| **≥ 0,80** | CRITICAL | BLOCK |
| **0,50 a 0,79** | HIGH | REVIEW |
| **0,30 a 0,49** | MEDIUM | MONITOR |
| **abaixo de 0,30** | LOW | APPROVE |

Isso ajuda a explicar o **gráfico de distribuição de scores** e o texto de recomendação na resposta da API, **mesmo quando** a transação ainda não é contada como “fraude” binária.

### O que é “fraude” para KPI e alertas

Para **taxa de fraude**, **contagem de fraudes** e **criação de alerta** na API usamos um único limiar: **`is_fraud = true`** quando o score **≥ 0,70**.

Assim, uma transação pode ser **HIGH** (revisar) com score entre **0,50 e 0,69** sem disparar alerta de fraude confirmada — o que deixa a demo **mais realista** do que marcar metade do lote como fraude. Se a banca perguntar a diferença entre **risco alto** e **fraude declarada**, essa é a resposta: **risco** orienta fila humana; **fraude** no painel segue um **corte mais alto**.

### Resumo em uma frase para a banca

*“Combinamos detecção de anomalia e classificação por gradient boosting, calibramos o score com uma heurística mínima para cenários extremos da demo, classificamos o risco em quatro faixas e só chamamos de fraude oficial — com alerta — o que passa de 70% no score.”*

---

## Checklist 5 minutos antes da banca

- [ ] `source .venv/bin/activate` em cada terminal que for usar  
- [ ] Terminal B: `uvicorn` rodando — teste http://127.0.0.1:8000/docs  
- [ ] Terminal C: Streamlit rodando — teste http://127.0.0.1:8501  
- [ ] (Opcional) Terminal D: `bash scripts/demo.sh` até o primeiro ENTER para ver se responde  

Boa apresentação.

---

## Demo em loop (sem ENTER — alimenta a API sozinho)

Use **`scripts/demo_loop.sh`**, não `demo.sh`:

```bash
API_URL=http://127.0.0.1:8000 ./scripts/demo_loop.sh        # a cada 60 s, sem fim
API_URL=http://127.0.0.1:8000 ./scripts/demo_loop.sh 60 10  # 60 s entre ciclos, 10 vezes
```

Opcional: `GENERATE_N=80` `BATCH_SLICE=20` (veja comentários no topo do script).

Para rodar o **`demo.sh` completo sem pausas** (uma vez só):  
`DEMO_NONINTERACTIVE=1 bash scripts/demo.sh` ou `bash scripts/demo.sh --auto`.