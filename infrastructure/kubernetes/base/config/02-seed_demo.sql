-- Dados de exemplo para inspeção na banca (psql / DBeaver).
-- Idempotente: pode rodar várias vezes após schema.sql.

INSERT INTO transactions (
    transaction_id, user_id, amount, currency, merchant_id, merchant_category,
    timestamp, user_country, merchant_country, payment_method,
    device_id, ip_address, fraud_score, is_fraud, fraud_reason
) VALUES
(
    'demo-tx-001', 'user_1001', 89.90, 'BRL', 'merchant_12', 'Alimentacao',
    NOW() - INTERVAL '2 hours', 'BR', 'BR', 'PIX',
    'device-demo-1', '10.0.0.1', 0.12, false, NULL
),
(
    'demo-tx-002', 'user_2042', 12500.00, 'BRL', 'merchant_88', 'Eletronicos',
    NOW() - INTERVAL '45 minutes', 'BR', 'US', 'CREDIT_CARD',
    'device-demo-2', '10.0.0.2', 0.91, true, 'Valor acima do p95 do perfil; transação internacional'
),
(
    'demo-tx-003', 'user_1001', 320.50, 'BRL', 'merchant_5', 'Vestuario',
    NOW() - INTERVAL '20 minutes', 'BR', 'BR', 'DEBIT_CARD',
    'device-demo-1', '10.0.0.1', 0.08, false, NULL
),
(
    'demo-tx-004', 'user_3300', 45000.00, 'BRL', 'merchant_99', 'Eletronicos',
    NOW() - INTERVAL '5 minutes', 'BR', 'US', 'CREDIT_CARD',
    'device-demo-9', '203.0.113.50', 0.97, true, 'Madrugada + internacional + valor extremo'
),
(
    'demo-tx-005', 'user_2042', 45.00, 'BRL', 'merchant_3', 'Servicos',
    NOW() - INTERVAL '1 minute', 'BR', 'BR', 'PIX',
    'device-demo-2', '10.0.0.2', 0.05, false, NULL
)
ON CONFLICT (transaction_id) DO UPDATE SET
    fraud_score = EXCLUDED.fraud_score,
    is_fraud = EXCLUDED.is_fraud,
    fraud_reason = EXCLUDED.fraud_reason,
    updated_at = NOW();

INSERT INTO fraud_alerts (transaction_id, user_id, fraud_score, fraud_reason, severity, status)
SELECT
    t.transaction_id,
    t.user_id,
    t.fraud_score,
    t.fraud_reason,
    CASE
        WHEN t.fraud_score >= 0.9 THEN 'CRITICAL'
        WHEN t.fraud_score >= 0.7 THEN 'HIGH'
        WHEN t.fraud_score >= 0.4 THEN 'MEDIUM'
        ELSE 'LOW'
    END,
    'PENDING'
FROM transactions t
WHERE t.is_fraud = true
  AND NOT EXISTS (
      SELECT 1 FROM fraud_alerts a WHERE a.transaction_id = t.transaction_id
  );

INSERT INTO audit_events (event_type, entity_type, entity_id, actor, payload)
SELECT * FROM (VALUES
    ('TRANSACTION_ANALYZED', 'transaction', 'demo-tx-002', 'fraud-api',
     '{"channel":"batch_seed","decision":"BLOCK"}'::jsonb),
    ('ALERT_CREATED', 'fraud_alert', 'demo-tx-004', 'fraud-api',
     '{"severity":"CRITICAL"}'::jsonb)
) AS v(event_type, entity_type, entity_id, actor, payload)
WHERE NOT EXISTS (
    SELECT 1 FROM audit_events e
    WHERE e.entity_id = v.entity_id AND e.event_type = v.event_type
);
