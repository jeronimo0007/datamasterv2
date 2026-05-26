package com.fraud.messaging;

import java.io.Serializable;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FraudAlertEmailMessage implements Serializable {

    private String alertId;
    private String transactionId;
    private Double fraudScore;
    private String riskLevel;
    private String recommendedAction;
    private Double amount;
    private String merchantCategory;
    private String paymentMethod;
    private String holderDocument;
    private String cardHolderName;
    private Instant detectedAt;
}
