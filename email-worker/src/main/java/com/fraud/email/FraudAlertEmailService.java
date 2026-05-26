package com.fraud.email;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
@RequiredArgsConstructor
@Slf4j
public class FraudAlertEmailService {

    private final JavaMailSender mailSender;

    @Value("${fraud.email.from}")
    private String from;

    @Value("${fraud.email.to}")
    private String to;

    @Value("${fraud.email.enabled:true}")
    private boolean enabled;

    @Value("${spring.mail.host:}")
    private String smtpHost;

    public void sendFraudAlert(FraudAlertEmailMessage msg) {
        if (!enabled) {
            log.debug("E-mail desabilitado (FRAUD_EMAIL_ENABLED=false)");
            return;
        }
        if (!StringUtils.hasText(smtpHost)) {
            log.warn(
                    "SMTP_HOST nao configurado — alerta tx={} nao enviado por e-mail",
                    msg.getTransactionId());
            return;
        }

        String subject =
                String.format(
                        "[DataMaster] Fraude detectada — %s (score %.2f)",
                        msg.getTransactionId(), msg.getFraudScore() != null ? msg.getFraudScore() : 0.0);

        String body =
                """
                Alerta de fraude — DataMaster

                ID alerta: %s
                Transacao: %s
                Score: %s
                Nivel de risco: %s
                Acao recomendada: %s
                Valor: %s
                Categoria: %s
                Pagamento: %s
                Titular: %s
                Detectado em: %s

                Este e-mail foi disparado de forma assincrona pela fila RabbitMQ.
                """
                        .formatted(
                                nullSafe(msg.getAlertId()),
                                nullSafe(msg.getTransactionId()),
                                msg.getFraudScore(),
                                nullSafe(msg.getRiskLevel()),
                                nullSafe(msg.getRecommendedAction()),
                                msg.getAmount(),
                                nullSafe(msg.getMerchantCategory()),
                                nullSafe(msg.getPaymentMethod()),
                                maskHolder(msg.getCardHolderName(), msg.getHolderDocument()),
                                msg.getDetectedAt());

        SimpleMailMessage mail = new SimpleMailMessage();
        mail.setFrom(from);
        mail.setTo(to);
        mail.setSubject(subject);
        mail.setText(body);
        mailSender.send(mail);
        log.info("E-mail de fraude enviado para {} (tx={})", to, msg.getTransactionId());
    }

    private static String nullSafe(String v) {
        return v != null ? v : "-";
    }

    private static String maskHolder(String name, String doc) {
        if (StringUtils.hasText(name)) {
            return name;
        }
        if (StringUtils.hasText(doc) && doc.length() > 4) {
            return "***" + doc.substring(doc.length() - 4);
        }
        return "-";
    }
}
