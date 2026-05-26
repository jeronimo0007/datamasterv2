package com.fraud.email;

import java.time.Instant;
import lombok.Data;

@Data
public class FraudAlertEmailMessage {

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
