package com.fraud.messaging;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

/**
 * Publica alerta na fila sem aguardar envio de e-mail (fire-and-forget).
 */
@Service
@ConditionalOnProperty(name = "fraud.email.enabled", havingValue = "true")
@RequiredArgsConstructor
@Slf4j
public class FraudEmailNotificationPublisher {

    private final RabbitTemplate rabbitTemplate;

    @Value("${fraud.email.enabled:false}")
    private boolean enabled;

    public void publishFraudDetected(FraudAlertEmailMessage message) {
        if (!enabled || message == null) {
            return;
        }
        try {
            rabbitTemplate.convertAndSend(
                    FraudRabbitConstants.EXCHANGE,
                    FraudRabbitConstants.ROUTING_KEY,
                    message);
            log.info(
                    "Alerta de fraude enfileirado para e-mail: tx={} score={}",
                    message.getTransactionId(),
                    message.getFraudScore());
        } catch (Exception e) {
            log.warn(
                    "Falha ao publicar alerta na fila (API segue normal): tx={} — {}",
                    message.getTransactionId(),
                    e.getMessage());
        }
    }
}
