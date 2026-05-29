package com.fraud.local;

import com.fraud.local.mongo.TransactionHistoryDocument;
import com.fraud.local.mongo.TransactionHistoryRepository;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("local")
public class TransactionHistoryService {

    public static final String COSMOS_PENDING = "PENDING";

    private final TransactionHistoryRepository repository;
    private final LgpdMaskingService masking;
    private final DemoIdentityGenerator identity;

    public TransactionHistoryService(
            TransactionHistoryRepository repository,
            LgpdMaskingService masking,
            DemoIdentityGenerator identity) {
        this.repository = repository;
        this.masking = masking;
        this.identity = identity;
    }

    /** Preenche CPF/cartao ficticios em registros antigos (demo). */
    public void ensureIdentityFields(Map<String, Object> record) {
        if (stringVal(record.get("holder_document")).isBlank()) {
            record.put("holder_document", identity.generateCpf());
        }
        if (stringVal(record.get("card_number")).isBlank()) {
            record.put("card_number", identity.generateCardNumber());
        }
        if (stringVal(record.get("card_holder_name")).isBlank()) {
            record.put("card_holder_name", identity.generateHolderName());
        }
        Object pm = record.get("payment_method");
        record.put("payment_method", identity.normalizePaymentMethod(pm == null ? null : String.valueOf(pm)));
    }

    /** Persiste transação analisada para histórico local (Cosmos em produção). */
    public void persist(Map<String, Object> record) {
        record.putIfAbsent("cosmos_sync_status", COSMOS_PENDING);
        repository.save(TransactionHistoryDocument.fromRecord(record));
    }

    public long countHistory() {
        return repository.count();
    }

    public long countPendingCosmosSync() {
        return repository.countByCosmosSyncStatus(COSMOS_PENDING);
    }

    /** Visão pública da lista — PII mascarado (LGPD). */
    public Map<String, Object> toPublicView(Map<String, Object> record) {
        ensureIdentityFields(record);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("transaction_id", record.get("transaction_id"));
        out.put("amount", record.get("amount"));
        out.put("merchant_category", record.get("merchant_category"));
        out.put("payment_method", record.get("payment_method"));
        out.put("user_country", record.get("user_country"));
        out.put("merchant_country", record.get("merchant_country"));
        out.put("fraud_score", record.get("fraud_score"));
        out.put("is_fraud", record.get("is_fraud"));
        out.put("risk_level", record.get("risk_level"));
        out.put("recommended_action", record.get("recommended_action"));
        out.put("review_status", record.get("review_status"));
        out.put("anomaly_reasons", record.get("anomaly_reasons"));
        out.put("profile_found", record.get("profile_found"));
        out.put("processing_time_ms", record.get("processing_time_ms"));
        out.put("timestamp", record.get("timestamp"));
        out.put("cosmos_sync_status", record.get("cosmos_sync_status"));
        out.put("history_stored", true);

        out.put("holder_document", masking.maskCpf(stringVal(record.get("holder_document"))));
        out.put("card_last4", masking.cardLast4Display(stringVal(record.get("card_number"))));

        return out;
    }

    private static String stringVal(Object o) {
        return o == null ? "" : String.valueOf(o).trim();
    }
}
