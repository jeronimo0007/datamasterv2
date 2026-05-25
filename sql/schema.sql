-- DataMaster — schema OLTP PostgreSQL
-- Alinhado às entidades JPA (perfil enterprise) e narrativa da banca.
-- Executado automaticamente na primeira subida do container postgres.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------------
-- Transações (OLTP)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id    VARCHAR(64)  NOT NULL UNIQUE,
    user_id           VARCHAR(64)  NOT NULL,
    amount            NUMERIC(19, 2) NOT NULL CHECK (amount > 0),
    currency          CHAR(3)    NOT NULL DEFAULT 'BRL',
    merchant_id       VARCHAR(64)  NOT NULL,
    merchant_category VARCHAR(64),
    timestamp         TIMESTAMP    NOT NULL,
    user_country      CHAR(2),
    merchant_country  CHAR(2),
    payment_method    VARCHAR(32),
    device_id         VARCHAR(64),
    ip_address        VARCHAR(45),
    fraud_score       DOUBLE PRECISION,
    is_fraud          BOOLEAN,
    fraud_reason      TEXT,
    created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions (timestamp);
CREATE INDEX IF NOT EXISTS idx_transactions_fraud_score ON transactions (fraud_score);

-- ---------------------------------------------------------------------------
-- Alertas de fraude
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fraud_alerts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  VARCHAR(64)  NOT NULL,
    user_id         VARCHAR(64)  NOT NULL,
    fraud_score     DOUBLE PRECISION NOT NULL,
    fraud_reason    VARCHAR(1000),
    severity        VARCHAR(16)  NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'REVIEWED', 'RESOLVED', 'FALSE_POSITIVE')),
    reviewed_by     VARCHAR(128),
    reviewed_at     TIMESTAMP,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fraud_alerts_transaction_id ON fraud_alerts (transaction_id);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_user_id ON fraud_alerts (user_id);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_status ON fraud_alerts (status);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_created_at ON fraud_alerts (created_at DESC);

-- ---------------------------------------------------------------------------
-- Auditoria (narrativa governança / LGPD)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_events (
    id          BIGSERIAL PRIMARY KEY,
    event_type  VARCHAR(64)  NOT NULL,
    entity_type VARCHAR(64),
    entity_id   VARCHAR(128),
    actor       VARCHAR(128),
    payload     JSONB,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_events_created_at ON audit_events (created_at DESC);

COMMENT ON TABLE transactions IS 'OLTP — transações analisadas (perfil enterprise)';
COMMENT ON TABLE fraud_alerts IS 'Alertas gerados pelo motor de fraude';
COMMENT ON TABLE audit_events IS 'Trilha de auditoria para governança';
