"""
Dashboard Streamlit — fraudes online + batch (MongoDB) + chat DeepSeek.
"""
import json
import os
import time
from datetime import datetime

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import requests
import streamlit as st

st.set_page_config(
    page_title="Fraud Detection Dashboard",
    page_icon="🔍",
    layout="wide",
    initial_sidebar_state="expanded",
)

_default_api_url = os.environ.get("API_URL", "http://127.0.0.1:8080")
API_URL = st.sidebar.text_input("API URL", value=_default_api_url)

st.title("Sistema de Deteccao de Fraudes Bancarias")
st.caption("Online (API) + Batch (perfis MongoDB) + Assistente DeepSeek")

auto_refresh = st.sidebar.checkbox("Auto-refresh (2s)", value=False)
if auto_refresh:
    st.sidebar.caption("Pausado nas abas **Assistente IA** e **LGPD**.")

FEATURE_LABELS = {
    "amount": "Valor da transacao (amount)",
    "log_amount": "Valor em escala log (log_amount)",
    "hour": "Hora do dia (hour)",
    "is_weekend": "Fim de semana (is_weekend)",
    "is_international": "Compra internacional (is_international)",
    "merchant_category_encoded": "Categoria do comercio (merchant_category_encoded)",
    "payment_method_encoded": "Meio de pagamento (payment_method_encoded)",
}

FEATURE_DETAILS = {
    "amount": {
        "resumo": "Valor absoluto da compra. Transacoes muito acima do habitual do cliente sao o principal indicio de fraude.",
        "efeito": "No motor Java entra em escala logaritmica (contribuicao de ate ~30% no bloco heuristico).",
    },
    "log_amount": {
        "resumo": "Mesmo valor em escala log — estabiliza picos e deixa comparavel transacoes de R$ 50 e R$ 50 mil.",
        "efeito": "Suaviza outliers; peso alto porque combina bem com perfil historico no MongoDB.",
    },
    "is_international": {
        "resumo": "Compra em moeda/pais diferente do cadastro do usuario.",
        "efeito": "Soma ~10% ao score base; combinado com cartao e valor alto dispara regras de piso.",
    },
    "hour": {
        "resumo": "Hora do dia (0–23). Madrugada e noite aumentam risco operacional.",
        "efeito": "Fora do horario comercial (antes das 6h ou apos 22h) adiciona ~8% ao score.",
    },
    "payment_method_encoded": {
        "resumo": "Meio de pagamento (credito, debito, etc.).",
        "efeito": "Cartao de credito em compras suspeitas soma ~8%; debito costuma ser mais neutro na demo.",
    },
    "merchant_category_encoded": {
        "resumo": "Segmento do comercio (eletronicos, alimentacao, viagens…).",
        "efeito": "Categorias de ticket alto (ex.: eletronicos) recebem boost moderado (~6%).",
    },
    "is_weekend": {
        "resumo": "Indica se a transacao ocorreu no fim de semana.",
        "efeito": "Fim de semana adiciona ~5%; reforca padroes atipicos junto com valor e internacional.",
    },
}

DEFAULT_FEATURE_WEIGHTS = {
    "amount": 0.28,
    "log_amount": 0.22,
    "is_international": 0.18,
    "hour": 0.12,
    "payment_method_encoded": 0.10,
    "merchant_category_encoded": 0.06,
    "is_weekend": 0.04,
}


def feature_label(name: str) -> str:
    return FEATURE_LABELS.get(
        name,
        f"{name.replace('_', ' ').strip().title()} ({name})",
    )


def resolve_feature_weights(feature_importance: dict) -> dict:
    if feature_importance and "error" not in feature_importance:
        return dict(feature_importance)
    return dict(DEFAULT_FEATURE_WEIGHTS)


@st.dialog("Variaveis do modelo e pesos", width="large")
def show_feature_details_modal(weights: dict) -> None:
    st.markdown(
        "Pesos **relativos** do modelo de referencia (`1.0.0-java-balanced`). "
        "Na demo ao vivo o score final ainda soma **boost do perfil MongoDB** "
        "quando o comportamento foge do historico do cliente."
    )
    for feat, peso in sorted(weights.items(), key=lambda x: x[1], reverse=True):
        meta = FEATURE_DETAILS.get(feat, {})
        st.markdown(f"**{feature_label(feat)}**")
        c1, c2 = st.columns([1, 4])
        with c1:
            st.metric("Peso", f"{peso * 100:.1f}%")
        with c2:
            st.write(meta.get("resumo", "Variavel usada no pipeline de scoring."))
            if meta.get("efeito"):
                st.caption(meta["efeito"])
        st.divider()
    if st.button("Fechar", use_container_width=True):
        st.rerun()


def sync_tx_select_from_table(df: pd.DataFrame, event, valid_ids: list) -> None:
    """Atualiza o selectbox de liberacao quando o usuario clica numa linha da tabela."""
    if event is None or not valid_ids:
        return
    selection = getattr(event, "selection", None)
    if selection is None or not getattr(selection, "rows", None):
        return
    row_idx = selection.rows[0]
    if row_idx < 0 or row_idx >= len(df):
        return
    tid = str(df.iloc[row_idx].get("transaction_id", ""))
    if tid in valid_ids and st.session_state.get("release_tx_select") != tid:
        st.session_state["release_tx_select"] = tid


SECTION_TX = "Transacoes"
SECTION_BATCH = "Batch / perfil"
SECTION_LGPD = "LGPD / mascaramento"
SECTION_CHAT = "Assistente IA"
SECTION_CHARTS = "Graficos"

LGPD_DEMO_PAYLOAD = {
    "cpf": "123.456.789-00",
    "email": "joao.silva@banco.com.br",
    "phone": "(11) 98765-4321",
    "name": "Joao Silva",
    "card_number": "1234 5678 9012 3456",
}

LGPD_FIELD_META = {
    "cpf": {
        "rotulo": "CPF",
        "principio": "Dado pessoal sensivel — nunca expor completo em log, export ou ambiente de homologacao.",
        "regra": "Mantem trecho central e ultimos digitos para suporte sem revelar o documento inteiro.",
    },
    "email": {
        "rotulo": "E-mail",
        "principio": "Identificador direto do titular; exige minimizacao em paineis e APIs de consulta.",
        "regra": "Oculta local e dominio; preserva apenas pistas para correlacao interna.",
    },
    "phone": {
        "rotulo": "Telefone",
        "principio": "Contato PII — mascarar em dashboards operacionais e relatorios de fraude.",
        "regra": "Exibe DDD e ultimos quatro digitos; oculta o miolo do numero.",
    },
    "name": {
        "rotulo": "Nome",
        "principio": "Minimizacao: analista de fraude precisa do padrao, nao do nome civil completo.",
        "regra": "Iniciais visiveis por palavra; restante substituido por asteriscos.",
    },
    "card_number": {
        "rotulo": "Cartao",
        "principio": "Dado de pagamento — PCI + LGPD; ultimos quatro digitos quando indispensavel.",
        "regra": "Somente final do PAN visivel; blocos anteriores mascarados.",
    },
}


def fetch_data(endpoint: str, method: str = "GET", json_body=None):
    try:
        if method == "POST":
            resp = requests.post(f"{API_URL}{endpoint}", json=json_body, timeout=60)
        else:
            resp = requests.get(f"{API_URL}{endpoint}", timeout=10)
        if resp.status_code == 200:
            return resp.json()
        return {"error": resp.status_code, "detail": resp.text[:500]}
    except requests.exceptions.ConnectionError:
        return None
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}


# --- Sidebar: batch + teste ---
st.sidebar.header("Batch (dataprep → MongoDB)")
batch_stats = fetch_data("/api/v1/batch/profile-stats")
if batch_stats:
    n = batch_stats.get("mongodb_profiles_loaded", 0)
    if n > 0:
        st.sidebar.success(f"{n} perfis no MongoDB")
    else:
        st.sidebar.warning("Sem perfis batch. Rode:")
        st.sidebar.code("docker compose run --rm batch-prep")
else:
    st.sidebar.error("API offline")

st.sidebar.markdown("---")
st.sidebar.header("Enviar transacao de teste")
with st.sidebar.form("send_transaction"):
    amount = st.number_input("Valor (R$)", min_value=0.0, value=500.0, step=100.0)
    holder_document = st.text_input("CPF (documento)", value="123.456.789-00")
    card_number = st.text_input("Cartao", value="1234 5678 9012 3456")
    profile_user_id = st.text_input(
        "Perfil batch (user_id)",
        value="user_1001",
        help="Consulta user_profiles no Mongo; nao aparece mascarado na tabela.",
    )
    category = st.selectbox(
        "Categoria",
        ["Alimentacao", "Eletronicos", "Vestuario", "Servicos", "Viagem", "Entretenimento"],
    )
    payment = st.selectbox("Pagamento", ["CREDIT_CARD", "DEBIT_CARD"])
    user_country = st.selectbox("Pais Usuario", ["BR", "US", "GB", "FR"])
    merchant_country = st.selectbox("Pais Comerciante", ["BR", "US", "GB", "FR"])
    hour = st.slider("Hora", 0, 23, 14)
    is_weekend = st.checkbox("Fim de semana")
    if st.form_submit_button("Analisar"):
        payload = {
            "amount": amount,
            "merchant_category": category,
            "payment_method": payment,
            "user_country": user_country,
            "merchant_country": merchant_country,
            "hour": hour,
            "is_weekend": int(is_weekend),
            "is_international": int(user_country != merchant_country),
            "holder_document": holder_document,
            "card_number": card_number,
            "profile_user_id": profile_user_id,
        }
        r = fetch_data("/api/v1/transactions/analyze", method="POST", json_body=payload)
        if r and "fraud_score" in r:
            if r.get("is_fraud"):
                st.sidebar.error(f"FRAUDE — score {r['fraud_score']:.2%}")
            else:
                st.sidebar.success(f"OK — score {r['fraud_score']:.2%}")
            if r.get("user_profile", {}).get("anomaly_reasons"):
                st.sidebar.info("; ".join(r["user_profile"]["anomaly_reasons"][:2]))

summary = fetch_data("/api/v1/dashboard/summary")
if summary is None:
    st.warning(f"API indisponivel em {API_URL}")
    st.stop()

kpis = summary.get("kpis", {})
c1, c2, c3, c4, c5, c6 = st.columns(6)
c1.metric("Transacoes", kpis.get("total_transactions", 0))
c2.metric("Fraudes abertas", kpis.get("total_frauds", 0))
c3.metric("Liberadas", kpis.get("total_released", 0))
c4.metric("Perfis MongoDB", kpis.get("mongodb_profiles", 0))
c5.metric("Taxa fraude", f"{kpis.get('fraud_rate', 0):.2%}")
c6.metric("Tempo medio ms", f"{kpis.get('avg_processing_time_ms', 0):.1f}")

section = st.radio(
    "Seção",
    [SECTION_TX, SECTION_BATCH, SECTION_LGPD, SECTION_CHAT, SECTION_CHARTS],
    horizontal=True,
    key="main_section",
    label_visibility="collapsed",
)

# --- Transacoes ---
if section == SECTION_TX:
    n_fraud_open = int(kpis.get("total_frauds", 0))
    tx_open = fetch_data("/api/v1/transactions?filter=fraud&limit=5000")
    rows_open = (tx_open or {}).get("transactions", [])
    model_metrics = fetch_data("/api/v1/model/metrics") or {}
    feature_importance = fetch_data("/api/v1/model/feature-importance") or {}
    feature_weights = resolve_feature_weights(feature_importance)

    chart_col, model_col = st.columns([3, 2])

    with chart_col:
        st.subheader("Fraudes abertas por categoria")
        if rows_open:
            df_open = pd.DataFrame(rows_open)
            chart_total = len(df_open)
            if "merchant_category" in df_open.columns:
                fraud_by_cat = (
                    df_open.groupby("merchant_category", dropna=False)
                    .size()
                    .reset_index(name="fraudes")
                    .sort_values("fraudes", ascending=False)
                )
                chart_total = int(fraud_by_cat["fraudes"].sum())
                fig_fraud = px.bar(
                    fraud_by_cat,
                    x="merchant_category",
                    y="fraudes",
                    text="fraudes",
                    labels={"merchant_category": "Categoria", "fraudes": "Fraudes abertas"},
                    color="fraudes",
                    color_continuous_scale="Reds",
                )
                fig_fraud.update_layout(
                    showlegend=False,
                    coloraxis_showscale=False,
                    margin=dict(t=24, b=48),
                    height=320,
                )
                fig_fraud.update_traces(textposition="outside")
            else:
                fig_fraud = go.Figure(
                    data=[
                        go.Bar(
                            x=["Fraudes abertas"],
                            y=[chart_total],
                            text=[chart_total],
                            textposition="outside",
                            marker_color=["#ef4444"],
                        )
                    ]
                )
                fig_fraud.update_layout(margin=dict(t=24, b=48), height=320)
            st.plotly_chart(fig_fraud, use_container_width=True)
            st.caption(
                f"**{n_fraud_open}** fraudes abertas (nao liberadas) — alinhado ao KPI. "
                f"Soma no grafico: **{chart_total}**."
            )
        elif n_fraud_open > 0:
            cat_fraud = summary.get("category_fraud_counts", {})
            if cat_fraud:
                fig_fraud = px.bar(
                    x=list(cat_fraud.keys()),
                    y=list(cat_fraud.values()),
                    labels={"x": "Categoria", "y": "Fraudes"},
                    color=list(cat_fraud.values()),
                    color_continuous_scale="Reds",
                )
                fig_fraud.update_layout(showlegend=False, coloraxis_showscale=False, height=320)
                st.plotly_chart(fig_fraud, use_container_width=True)
                st.caption(f"**{n_fraud_open}** fraudes abertas (estimativa por categoria da sessao).")
            else:
                st.info(f"{n_fraud_open} fraudes abertas — sem detalhe por categoria.")
        else:
            st.info("Nenhuma fraude aberta. Envie transacoes via sidebar ou console.")

    with model_col:
        st.subheader("Modelo de scoring")
        st.markdown(
            """
**Motor:** `1.0.0-java-balanced` (heuristica + boost de perfil MongoDB)

```
Entrada → features → score [0–1] → limiar 0,74 → fraude? (~5–15% em lote)
         ↘ perfil batch (Mongo)
```

**Variaveis (resumo):** valor e escala log pesam mais; internacional e horario
reforcam risco; meio de pagamento e categoria afinam o score; fim de semana e sinal auxiliar.
            """
        )
        if feature_weights:
            fi_df = pd.DataFrame(
                {"feature": list(feature_weights.keys()), "peso": list(feature_weights.values())}
            )
            fi_df["rotulo"] = fi_df["feature"].map(feature_label)
            fi_df["peso_pct"] = (fi_df["peso"] * 100).round(1)
            fi_df = fi_df.sort_values("peso_pct", ascending=True)
            fig_fi = px.bar(
                fi_df,
                x="peso_pct",
                y="rotulo",
                orientation="h",
                text="peso_pct",
                labels={"peso_pct": "Importancia (%)", "rotulo": "Variavel"},
                color="peso_pct",
                color_continuous_scale="Blues",
            )
            fig_fi.update_traces(
                texttemplate="%{x:.1f}%",
                textposition="outside",
                textfont_size=13,
            )
            fig_fi.update_layout(
                showlegend=False,
                coloraxis_showscale=False,
                xaxis_tickformat=".0f",
                xaxis_title="Importancia relativa (%)",
                margin=dict(t=8, l=8, r=48, b=8),
                height=280,
            )
            st.plotly_chart(fig_fi, use_container_width=True)
        if model_metrics and "error" not in model_metrics:
            m1, m2, m3 = st.columns(3)
            m1.metric("Precisao", f"{model_metrics.get('precision', 0):.1%}")
            m2.metric("Recall", f"{model_metrics.get('recall', 0):.1%}")
            m3.metric("AUC-ROC", f"{model_metrics.get('auc_roc', 0):.3f}")

        if st.button(
            "Entender variaveis e pesos",
            key="btn_feature_modal",
            use_container_width=True,
            help="Abre explicacao de cada parametro e peso relativo no modelo.",
        ):
            show_feature_details_modal(feature_weights)

    st.markdown("---")
    filt = st.radio(
        "Filtro",
        ["all", "fraud", "released"],
        format_func=lambda x: {"all": "Todas", "fraud": "Fraudes", "released": "Liberadas"}[x],
        horizontal=True,
    )
    tx_data = fetch_data(f"/api/v1/transactions?filter={filt}&limit=100")
    rows = (tx_data or {}).get("transactions", [])
    if rows:
        df = pd.DataFrame(rows)
        for col in ("holder_document", "card_last4"):
            if col not in df.columns:
                df[col] = "—"
        display_cols = [
            "transaction_id",
            "holder_document",
            "card_last4",
            "amount",
            "merchant_category",
            "payment_method",
            "fraud_score",
            "is_fraud",
            "review_status",
            "cosmos_sync_status",
            "anomaly_reasons",
            "recommended_action",
        ]
        display_cols = [c for c in display_cols if c in df.columns]
        st.caption(
            "Politica: score abaixo de 60% libera automatico; entre 60% e 75% vai para revisao; "
            "acima de 75% bloqueio. CPF/cartao mascarados (LGPD)."
        )
        table_df = df[display_cols].rename(
            columns={
                "holder_document": "cpf_mascarado",
                "card_last4": "cartao_ult4",
            }
        )
        all_tx_ids = [str(r.get("transaction_id")) for r in rows if r.get("transaction_id")]
        if all_tx_ids and st.session_state.get("release_tx_select") not in all_tx_ids:
            st.session_state["release_tx_select"] = all_tx_ids[0]

        try:
            table_event = st.dataframe(
                table_df,
                use_container_width=True,
                height=360,
                on_select="rerun",
                selection_mode="single-row",
                key="tx_table_select",
            )
            sync_tx_select_from_table(df, table_event, all_tx_ids)
        except TypeError:
            st.dataframe(table_df, use_container_width=True, height=360)
            st.caption(
                "Clique na linha da tabela exige Streamlit >= 1.35. "
                "Reconstrua o dashboard: docker compose up -d --build dashboard"
            )

        st.subheader("Liberar transacao (fluxo normal)")
        if all_tx_ids:
            sel = st.selectbox(
                "Transaction ID",
                all_tx_ids,
                key="release_tx_select",
                help="Clique numa linha da tabela acima para preencher automaticamente.",
            )
            sel_row = next(
                (r for r in rows if str(r.get("transaction_id")) == sel),
                None,
            )
            action = str(sel_row.get("recommended_action", "")).upper() if sel_row else ""
            can_release = bool(
                sel_row
                and sel_row.get("review_status") != "RELEASED"
                and action == "REVIEW"
            )
            if sel_row:
                c1, c2, c3 = st.columns(3)
                c1.metric("Score", f"{sel_row.get('fraud_score', 0):.0%}")
                c2.metric("Acao", str(sel_row.get("recommended_action", "—")))
                c3.metric("Status", str(sel_row.get("review_status", "—")))
                reasons = sel_row.get("anomaly_reasons") or []
                if reasons:
                    st.caption("Motivos: " + "; ".join(str(x) for x in reasons[:3]))
                if action == "BLOCK":
                    st.warning("Score acima de 75% — transacao **bloqueada** (sem liberacao manual).")
                elif sel_row.get("review_status") == "RELEASED":
                    st.info("Score abaixo de 60% — **liberada automaticamente**.")

            btn_release, btn_ai = st.columns(2)
            with btn_release:
                do_release = st.button(
                    "Liberar para transacao normal",
                    use_container_width=True,
                    disabled=not can_release,
                )
            with btn_ai:
                do_ai = st.button("Opiniao da IA", use_container_width=True)

            if do_release and can_release:
                out = fetch_data(
                    f"/api/v1/transactions/{sel}/release",
                    method="POST",
                    json_body={"released_by": "dashboard"},
                )
                if out and "review_status" in out:
                    st.success(out.get("message", "Liberada"))
                    st.rerun()
                elif out and out.get("error"):
                    st.error(str(out.get("detail", out.get("error"))))

            if do_ai:
                with st.spinner("Consultando assistente DeepSeek..."):
                    ans = fetch_data(
                        "/api/v1/assistant/chat",
                        method="POST",
                        json_body={
                            "transaction_id": sel,
                            "message": (
                                "Esta transacao deve ser liberada para o fluxo normal? "
                                "Justifique com base no score, nos motivos de anomalia "
                                "e no perfil historico do usuario."
                            ),
                        },
                    )
                if ans and ans.get("answer"):
                    st.session_state["release_ai_opinion"] = {
                        "tx_id": sel,
                        "answer": ans["answer"],
                        "model": ans.get("model", ""),
                    }
                elif ans and ans.get("detail"):
                    st.error(ans.get("detail"))
                elif ans is None:
                    st.error("API indisponivel ou DEEPSEEK_API_KEY nao configurada no servico api.")
                else:
                    st.error(str(ans.get("error", "Falha ao obter opiniao da IA")))

            opinion = st.session_state.get("release_ai_opinion")
            if opinion and opinion.get("tx_id") == sel:
                with st.expander("Opiniao da IA sobre liberacao", expanded=True):
                    st.markdown(opinion.get("answer", ""))
                    if opinion.get("model"):
                        st.caption(f"Modelo: {opinion['model']}")
        else:
            st.info("Sem transaction_id neste filtro.")
    else:
        st.info("Sem transacoes neste filtro.")

elif section == SECTION_BATCH:
    st.subheader("Camada batch — historico → dataprep → MongoDB")
    st.markdown(
        """
1. **Fonte:** `data/transactions.json` (bases historicas simuladas)
2. **Dataprep:** agregacao por `user_id` (media, desvio, categorias, P95…)
3. **Destino:** MongoDB `user_profiles`
4. **Online:** cada `POST /analyze` consulta o perfil e sinaliza comportamento atipico
        """
    )
    if batch_stats:
        h1, h2 = st.columns(2)
        h1.metric("Perfis batch", batch_stats.get("mongodb_profiles_loaded", 0))
        h2.metric(
            "Historico transacoes (Mongo)",
            batch_stats.get("transaction_history_count", 0),
        )
        pending = batch_stats.get("transaction_history_cosmos_pending", 0)
        if pending:
            st.caption(f"{pending} registro(s) com `cosmos_sync_status=PENDING` (replicação alvo).")
        with st.expander("Detalhe batch-stats"):
            st.json(batch_stats)
    st.code(
        "docker compose run --rm batch-prep\n"
        "# ou:\n"
        "python3 scripts/batch_dataprep_mongo.py -i data/transactions.json",
        language="bash",
    )

elif section == SECTION_LGPD:
    st.subheader("LGPD — mascaramento de dados pessoais (PII)")
    st.markdown(
        """
Na plataforma o mascaramento acontece **antes** de expor PII em painel, export ou ambiente nao produtivo:

| Camada | Implementacao na demo |
|--------|------------------------|
| **API** | `POST /api/v1/lgpd/mask` — `LgpdMaskingService` (Java) |
| **Biblioteca** | `src/utils/data_masker.py` — mesma logica para jobs Spark/notebooks |
| **Nuvem (alvo)** | Purview + politicas no lake; Key Vault para segredos; RBAC no acesso |

**Principios LGPD na fala:** minimizacao (so o necessario), finalidade (fraude/antifraude),
necessidade (analista ve mascarado), seguranca (TLS + mascaramento + auditoria).
        """
    )

    lgpd_defaults = st.session_state.get("lgpd_last_payload", LGPD_DEMO_PAYLOAD)
    col_form, col_info = st.columns([3, 2])
    with col_form:
        st.markdown("**Simulador ao vivo** — mesmos campos do slide da banca")
        with st.form("lgpd_mask_form", clear_on_submit=False):
            cpf = st.text_input("CPF", value=lgpd_defaults.get("cpf", ""))
            email = st.text_input("E-mail", value=lgpd_defaults.get("email", ""))
            phone = st.text_input("Telefone", value=lgpd_defaults.get("phone", ""))
            name = st.text_input("Nome", value=lgpd_defaults.get("name", ""))
            card = st.text_input("Cartao", value=lgpd_defaults.get("card_number", ""))
            run_mask = st.form_submit_button(
                "Aplicar mascaramento (API)",
                use_container_width=True,
                type="primary",
            )

        if st.button("Carregar exemplo da apresentacao", use_container_width=True):
            st.session_state["lgpd_force_mask"] = True
            st.rerun()

    force_mask = st.session_state.pop("lgpd_force_mask", False)
    mask_payload = None
    if run_mask:
        mask_payload = {
            "cpf": cpf,
            "email": email,
            "phone": phone,
            "name": name,
            "card_number": card,
        }
    elif force_mask:
        mask_payload = dict(LGPD_DEMO_PAYLOAD)

    if mask_payload is not None:
        st.session_state["lgpd_last_payload"] = mask_payload
        with st.spinner("Chamando API de mascaramento..."):
            st.session_state["lgpd_mask_result"] = fetch_data(
                "/api/v1/lgpd/mask",
                method="POST",
                json_body=mask_payload,
            )

    mask_result = st.session_state.get("lgpd_mask_result")
    last_payload = st.session_state.get("lgpd_last_payload", LGPD_DEMO_PAYLOAD)

    with col_info:
        st.markdown("**Onde aplicar na operacao**")
        st.markdown(
            """
- Export CSV/Parquet do lake → mascarar PII na **Silver**
- Resposta de API para canais externos → campo ja mascarado
- Homologacao / demo → **nunca** CPF ou cartao reais
- Anonimizacao irreversivel (`hash` + salt) em analytics agregado
            """
        )
        with st.expander("Equivalente Azure / AWS"):
            st.markdown(
                """
- **Azure:** Microsoft Purview (classificacao), politicas no ADLS, Key Vault
- **AWS:** Macie, Lake Formation, Secrets Manager + KMS
- **Local:** endpoint Java + `DataMasker` Python no mesmo contrato
                """
            )

    if mask_result and mask_result.get("masked_data"):
        masked = mask_result["masked_data"]
        rows_cmp = []
        for key in LGPD_FIELD_META:
            if key in last_payload or key in masked:
                rows_cmp.append(
                    {
                        "campo": LGPD_FIELD_META[key]["rotulo"],
                        "original": last_payload.get(key, "—"),
                        "mascarado": masked.get(key, "—"),
                    }
                )
        st.markdown("#### Antes × depois")
        st.dataframe(pd.DataFrame(rows_cmp), use_container_width=True, hide_index=True)

        detail_rows = []
        weights_order = list(LGPD_FIELD_META.keys())
        for key in weights_order:
            meta = LGPD_FIELD_META[key]
            detail_rows.append(
                {
                    "Campo": meta["rotulo"],
                    "Por que importa (LGPD)": meta["principio"],
                    "Regra de mascara": meta["regra"],
                }
            )
        st.markdown("#### Significado de cada campo")
        st.dataframe(pd.DataFrame(detail_rows), use_container_width=True, hide_index=True)

        st.success(
            f"Mascaramento aplicado em {mask_result.get('masked_at', '—')} "
            f"· campos: {', '.join(mask_result.get('original_fields', []))}"
        )
        st.code(
            "curl -s -X POST http://localhost:8080/api/v1/lgpd/mask \\\n"
            "  -H 'Content-Type: application/json' \\\n"
            f"  -d '{json.dumps(last_payload, ensure_ascii=False)}'",
            language="bash",
        )
    else:
        st.info(
            "Preencha os campos e clique em **Aplicar mascaramento** "
            "ou use **Carregar exemplo da apresentacao**."
        )

    with st.expander("Codigo no repositorio"):
        st.markdown(
            """
- Python: `src/utils/data_masker.py` — `DataMasker.mask_pii()`
- Java: `api-java/.../LgpdMaskingService.java` — usado pelo endpoint REST
- Governanca: `governanca.yaml` (classificacao e politicas de retencao)
            """
        )

elif section == SECTION_CHAT:
    st.subheader("Assistente — DeepSeek (contexto das fraudes da sessao)")
    st.caption(
        "O chat passa pela API (`/api/v1/assistant/chat`). "
        "Configure `DEEPSEEK_API_KEY` no serviço `api` do docker-compose."
    )
    prompt = st.text_area(
        "Pergunta sobre as fraudes exibidas",
        placeholder="Ex.: Por que estas transacoes foram marcadas como fraude?",
        height=100,
    )
    if st.button("Perguntar ao assistente") and prompt.strip():
        with st.spinner("Analisando contexto..."):
            ans = fetch_data(
                "/api/v1/assistant/chat",
                method="POST",
                json_body={"message": prompt, "context_limit": 15},
            )
        if ans and "answer" in ans:
            st.markdown(ans["answer"])
        elif ans and "detail" in ans:
            st.error(ans.get("detail"))
        elif ans and "error" in ans:
            st.error(f"Erro {ans['error']}")

elif section == SECTION_CHARTS:
    col_l, col_r = st.columns(2)
    with col_l:
        st.subheader("Distribuicao de scores")
        sd = summary.get("score_distribution", {})
        if any(sd.values()):
            fig = go.Figure(
                data=[
                    go.Bar(
                        x=["< 60% lib.", "60–75% rev.", "> 75% bloq."],
                        y=[
                            sd.get("approved_below_60", sd.get("low_0_30", 0)),
                            sd.get("review_60_75", sd.get("high_50_80", 0)),
                            sd.get("blocked_above_75", sd.get("critical_80_100", 0)),
                        ],
                    )
                ]
            )
            st.plotly_chart(fig, use_container_width=True)
    with col_r:
        st.subheader("Por categoria")
        cat = summary.get("category_distribution", {})
        if cat:
            st.plotly_chart(
                px.pie(names=list(cat.keys()), values=list(cat.values()), hole=0.4),
                use_container_width=True,
            )

st.markdown("---")
alerts = summary.get("recent_alerts", [])
if alerts:
    st.subheader("Alertas recentes")
    for a in reversed(alerts[:5]):
        with st.expander(f"Alerta {a.get('transaction_id')} — {a.get('fraud_score', 0):.2%}"):
            st.json(a)

if auto_refresh and st.session_state.get("main_section") not in (
    SECTION_CHAT,
    SECTION_LGPD,
):
    time.sleep(2)
    st.rerun()
