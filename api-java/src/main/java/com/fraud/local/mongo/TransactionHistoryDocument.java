package com.fraud.local.mongo;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;

@Data
@Document(collection = "transaction_history")
public class TransactionHistoryDocument {

    @Id
    private String id;

    @Indexed(unique = true)
    @Field("transaction_id")
    private String transactionId;

    @Field("profile_user_id")
    private String profileUserId;

    @Field("holder_document")
    private String holderDocument;

    @Field("card_number")
    private String cardNumber;

    @Field("card_holder_name")
    private String cardHolderName;

    private Double amount;

    @Field("merchant_category")
    private String merchantCategory;

    @Field("payment_method")
    private String paymentMethod;

    @Field("user_country")
    private String userCountry;

    @Field("merchant_country")
    private String merchantCountry;

    @Field("fraud_score")
    private Double fraudScore;

    @Field("is_fraud")
    private Boolean isFraud;

    @Field("risk_level")
    private String riskLevel;

    @Field("recommended_action")
    private String recommendedAction;

    @Field("review_status")
    private String reviewStatus;

    @Field("anomaly_reasons")
    private List<String> anomalyReasons;

    @Field("profile_found")
    private Boolean profileFound;

    @Field("processing_time_ms")
    private Double processingTimeMs;

    @Indexed
    private Instant timestamp;

    /** Fila para replicação em Cosmos DB (produção). */
    @Field("cosmos_sync_status")
    private String cosmosSyncStatus;

    public static TransactionHistoryDocument fromRecord(Map<String, Object> record) {
        TransactionHistoryDocument doc = new TransactionHistoryDocument();
        doc.setTransactionId(str(record.get("transaction_id")));
        doc.setProfileUserId(str(record.get("profile_user_id")));
        doc.setHolderDocument(str(record.get("holder_document")));
        doc.setCardNumber(str(record.get("card_number")));
        doc.setCardHolderName(str(record.get("card_holder_name")));
        doc.setAmount(num(record.get("amount")));
        doc.setMerchantCategory(str(record.get("merchant_category")));
        doc.setPaymentMethod(str(record.get("payment_method")));
        doc.setUserCountry(str(record.get("user_country")));
        doc.setMerchantCountry(str(record.get("merchant_country")));
        doc.setFraudScore(num(record.get("fraud_score")));
        doc.setIsFraud(bool(record.get("is_fraud")));
        doc.setRiskLevel(str(record.get("risk_level")));
        doc.setRecommendedAction(str(record.get("recommended_action")));
        doc.setReviewStatus(str(record.get("review_status")));
        @SuppressWarnings("unchecked")
        List<String> reasons = (List<String>) record.get("anomaly_reasons");
        doc.setAnomalyReasons(reasons);
        doc.setProfileFound(bool(record.get("profile_found")));
        doc.setProcessingTimeMs(num(record.get("processing_time_ms")));
        Object ts = record.get("timestamp");
        if (ts != null) {
            doc.setTimestamp(Instant.parse(String.valueOf(ts)));
        } else {
            doc.setTimestamp(Instant.now());
        }
        doc.setCosmosSyncStatus(
                str(record.getOrDefault("cosmos_sync_status", "PENDING")));
        return doc;
    }

    private static String str(Object o) {
        return o == null ? "" : String.valueOf(o);
    }

    private static Double num(Object o) {
        if (o instanceof Number n) {
            return n.doubleValue();
        }
        return null;
    }

    private static Boolean bool(Object o) {
        if (o instanceof Boolean b) {
            return b;
        }
        return null;
    }
}
