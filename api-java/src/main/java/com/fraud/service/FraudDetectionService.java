package com.fraud.service;

import com.azure.cosmos.CosmosClient;
import com.azure.cosmos.CosmosContainer;
import com.azure.cosmos.models.CosmosQueryRequestOptions;
import com.azure.cosmos.models.FeedResponse;
import com.fraud.model.FraudAlert;
import com.fraud.model.Transaction;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Service
@Profile("enterprise")
@RequiredArgsConstructor
@Slf4j
public class FraudDetectionService {
    
    private final TransactionService transactionService;
    private final FraudAlertService fraudAlertService;
    private final CosmosClient cosmosClient;
    
    @Value("${azure.cosmos.database-name:fraud-detection}")
    private String databaseName;
    
    @Value("${azure.cosmos.container-name:ml-models}")
    private String containerName;
    
    /**
     * Detecta fraude em uma transação de forma síncrona
     */
    public void detectFraud(Transaction transaction) {
        log.info("Detectando fraude para transação: {}", transaction.getTransactionId());
        
        // Calcular score de fraude usando modelo ML
        Double fraudScore = calculateFraudScore(transaction);
        
        // Determinar se é fraude (threshold: 0.7)
        Boolean isFraud = fraudScore >= 0.7;
        
        // Atualizar transação
        String fraudReason = isFraud ? generateFraudReason(transaction, fraudScore) : null;
        transactionService.updateFraudStatus(
            transaction.getTransactionId(),
            isFraud,
            fraudScore,
            fraudReason
        );
        
        // Criar alerta se for fraude
        if (isFraud) {
            createFraudAlert(transaction, fraudScore, fraudReason);
        }
    }
    
    /**
     * Detecta fraude de forma assíncrona
     */
    @Async
    public CompletableFuture<Void> detectFraudAsync(Transaction transaction) {
        detectFraud(transaction);
        return CompletableFuture.completedFuture(null);
    }
    
    /**
     * Calcula o score de fraude usando modelo ML
     * Em produção, isso chamaria um endpoint do Azure ML ou modelo local
     */
    @Cacheable(value = "fraudScores", key = "#transaction.transactionId")
    private Double calculateFraudScore(Transaction transaction) {
        // Simulação de cálculo de score
        // Em produção, isso chamaria o modelo ML treinado
        
        double score = 0.0;
        
        // Regras básicas de detecção
        if (transaction.getAmount().doubleValue() > 10000) {
            score += 0.3;
        }
        
        if (transaction.getUserCountry() != null && 
            !transaction.getUserCountry().equals(transaction.getMerchantCountry())) {
            score += 0.2;
        }
        
        if (transaction.getTimestamp().getHour() >= 0 && transaction.getTimestamp().getHour() < 6) {
            score += 0.15;
        }
        
        // Adicionar aleatoriedade para simulação
        score += Math.random() * 0.3;
        
        return Math.min(1.0, score);
    }
    
    private String generateFraudReason(Transaction transaction, Double fraudScore) {
        StringBuilder reason = new StringBuilder();
        
        if (transaction.getAmount().doubleValue() > 10000) {
            reason.append("Valor alto; ");
        }
        
        if (transaction.getUserCountry() != null && 
            !transaction.getUserCountry().equals(transaction.getMerchantCountry())) {
            reason.append("Transação internacional suspeita; ");
        }
        
        if (transaction.getTimestamp().getHour() >= 0 && transaction.getTimestamp().getHour() < 6) {
            reason.append("Horário incomum; ");
        }
        
        reason.append(String.format("Score: %.2f", fraudScore));
        
        return reason.toString();
    }
    
    private void createFraudAlert(Transaction transaction, Double fraudScore, String fraudReason) {
        FraudAlert.AlertSeverity severity = determineSeverity(fraudScore);
        
        FraudAlert alert = FraudAlert.builder()
                .transactionId(transaction.getTransactionId())
                .userId(transaction.getUserId())
                .fraudScore(fraudScore)
                .fraudReason(fraudReason)
                .severity(severity)
                .status(FraudAlert.AlertStatus.PENDING)
                .createdAt(LocalDateTime.now())
                .build();
        
        fraudAlertService.save(alert);
        log.warn("Alerta de fraude criado: {} - Score: {}", transaction.getTransactionId(), fraudScore);
    }
    
    private FraudAlert.AlertSeverity determineSeverity(Double fraudScore) {
        if (fraudScore >= 0.9) {
            return FraudAlert.AlertSeverity.CRITICAL;
        } else if (fraudScore >= 0.8) {
            return FraudAlert.AlertSeverity.HIGH;
        } else if (fraudScore >= 0.7) {
            return FraudAlert.AlertSeverity.MEDIUM;
        } else {
            return FraudAlert.AlertSeverity.LOW;
        }
    }
}

