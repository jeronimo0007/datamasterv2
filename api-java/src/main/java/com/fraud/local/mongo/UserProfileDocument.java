package com.fraud.local.mongo;

import java.time.Instant;
import java.util.List;
import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;

@Data
@Document(collection = "user_profiles")
public class UserProfileDocument {

    @Id
    private String id;

    @Indexed(unique = true)
    @Field("user_id")
    private String userId;

    @Field("tx_count")
    private int txCount;

    @Field("avg_amount")
    private double avgAmount;

    @Field("std_amount")
    private double stdAmount;

    @Field("max_amount")
    private double maxAmount;

    @Field("p95_amount")
    private double p95Amount;

    @Field("min_amount")
    private double minAmount;

    @Field("typical_categories")
    private List<String> typicalCategories;

    @Field("typical_payment_methods")
    private List<String> typicalPaymentMethods;

    @Field("pct_international")
    private double pctInternational;

    @Field("avg_hour")
    private double avgHour;

    @Field("historical_fraud_rate")
    private double historicalFraudRate;

    @Field("profile_version")
    private String profileVersion;

    private String source;

    @Field("updated_at")
    private Instant updatedAt;
}
