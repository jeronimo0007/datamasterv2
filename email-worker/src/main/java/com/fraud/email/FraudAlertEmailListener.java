package com.fraud.email;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class FraudAlertEmailListener {

    private final FraudAlertEmailService emailService;

    @RabbitListener(queues = FraudRabbitConstants.QUEUE)
    public void onFraudAlert(FraudAlertEmailMessage message) {
        try {
            emailService.sendFraudAlert(message);
        } catch (Exception e) {
            // Nao propaga — API ja respondeu; apenas loga falha de SMTP
            log.error(
                    "Falha ao enviar e-mail de fraude (tx={}): {}",
                    message != null ? message.getTransactionId() : "?",
                    e.getMessage());
        }
    }
}
