package com.fraud.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "transactions", indexes = {
    @Index(name = "idx_user_id", columnList = "user_id"),
    @Index(name = "idx_timestamp", columnList = "timestamp"),
    @Index(name = "idx_fraud_score", columnList = "fraud_score")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Transaction {
    
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    
    @NotBlank
    @Column(name = "transaction_id", unique = true, nullable = false)
    private String transactionId;
    
    @NotBlank
    @Column(name = "user_id", nullable = false)
    private String userId;
    
    @NotNull
    @DecimalMin(value = "0.0", inclusive = false)
    @Column(name = "amount", nullable = false, precision = 19, scale = 2)
    private BigDecimal amount;
    
    @NotBlank
    @Column(name = "currency", nullable = false, length = 3)
    private String currency;
    
    @NotBlank
    @Column(name = "merchant_id", nullable = false)
    private String merchantId;
    
    @Column(name = "merchant_category")
    private String merchantCategory;
    
    @NotNull
    @Column(name = "timestamp", nullable = false)
    private LocalDateTime timestamp;
    
    @Column(name = "user_country", length = 2)
    private String userCountry;
    
    @Column(name = "merchant_country", length = 2)
    private String merchantCountry;
    
    @Column(name = "payment_method")
    private String paymentMethod;
    
    @Column(name = "device_id")
    private String deviceId;
    
    @Column(name = "ip_address")
    private String ipAddress;
    
    @Column(name = "fraud_score")
    private Double fraudScore;
    
    @Column(name = "is_fraud")
    private Boolean isFraud;
    
    @Column(name = "fraud_reason")
    private String fraudReason;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

