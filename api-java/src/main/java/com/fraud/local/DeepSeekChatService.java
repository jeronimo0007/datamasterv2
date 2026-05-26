package com.fraud.local;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
@Profile("local")
public class DeepSeekChatService {

    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient httpClient =
            HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15)).build();

    @Value("${fraud.deepseek.api-key:}")
    private String apiKey;

    @Value("${fraud.deepseek.base-url:https://api.deepseek.com}")
    private String baseUrl;

    @Value("${fraud.deepseek.model:deepseek-chat}")
    private String model;

    public Map<String, Object> analyzeTransactionRelease(
            Map<String, Object> tx, String userMessage) {
        String question =
                userMessage == null || userMessage.isBlank()
                        ? "Devo liberar esta transacao para o fluxo normal? "
                                + "Responda em portugues com: (1) recomendacao LIBERAR ou MANTER BLOQUEIO, "
                                + "(2) nivel de confianca, (3) motivos objetivos em ate 5 linhas."
                        : userMessage;
        return analyzeFraudContext(question, List.of(tx), true);
    }

    public Map<String, Object> analyzeFraudContext(String userMessage, List<Map<String, Object>> fraudTxs) {
        return analyzeFraudContext(userMessage, fraudTxs, false);
    }

    private Map<String, Object> analyzeFraudContext(
            String userMessage, List<Map<String, Object>> fraudTxs, boolean releaseFocus) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "DEEPSEEK_API_KEY não configurada. Defina no docker-compose ou ambiente.");
        }

        StringBuilder context = new StringBuilder();
        context.append("Você é analista de fraude bancária. Responda em português, de forma objetiva.\n");
        if (releaseFocus) {
            context.append(
                    "Contexto: o analista avalia LIBERAÇÃO de UMA transação para fluxo normal.\n");
        } else {
            context.append("Contexto: transações marcadas como fraude na sessão atual:\n");
        }
        int i = 0;
        for (Map<String, Object> tx : fraudTxs) {
            if (i >= 15) {
                context.append("... (mais transações omitidas)\n");
                break;
            }
            context.append(formatTransactionLine(tx));
            i++;
        }
        context.append("\nPergunta do analista: ").append(userMessage);

        try {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("model", model);
            body.put(
                    "messages",
                    List.of(
                            Map.of("role", "system", "content", context.toString()),
                            Map.of("role", "user", "content", userMessage)));
            body.put("temperature", 0.3);

            String json = mapper.writeValueAsString(body);
            HttpRequest request =
                    HttpRequest.newBuilder()
                            .uri(URI.create(baseUrl + "/v1/chat/completions"))
                            .timeout(Duration.ofSeconds(60))
                            .header("Content-Type", "application/json")
                            .header("Authorization", "Bearer " + apiKey)
                            .POST(HttpRequest.BodyPublishers.ofString(json))
                            .build();

            HttpResponse<String> response =
                    httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 400) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_GATEWAY,
                        "DeepSeek erro HTTP " + response.statusCode() + ": " + response.body());
            }

            JsonNode root = mapper.readTree(response.body());
            String answer =
                    root.path("choices").path(0).path("message").path("content").asText("");

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("answer", answer);
            result.put("model", model);
            result.put("fraud_transactions_in_context", Math.min(fraudTxs.size(), 15));
            if (releaseFocus && !fraudTxs.isEmpty()) {
                result.put("transaction_id", fraudTxs.get(0).get("transaction_id"));
                result.put("focus", "release_decision");
            }
            return result;
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY, "Falha ao chamar DeepSeek: " + e.getMessage(), e);
        }
    }

    private static String formatTransactionLine(Map<String, Object> tx) {
        String doc =
                tx.get("holder_document") != null
                        ? String.valueOf(tx.get("holder_document"))
                        : "—";
        String card =
                tx.get("card_last4") != null
                        ? String.valueOf(tx.get("card_last4"))
                        : "—";
        return "- id="
                + tx.get("transaction_id")
                + " | doc="
                + doc
                + " | cartao="
                + card
                + " | R$ "
                + tx.get("amount")
                + " | "
                + tx.get("merchant_category")
                + " | "
                + tx.get("payment_method")
                + " | score="
                + tx.get("fraud_score")
                + " | fraude="
                + tx.get("is_fraud")
                + " | acao="
                + tx.get("recommended_action")
                + " | status="
                + tx.get("review_status")
                + " | motivos="
                + tx.getOrDefault("anomaly_reasons", List.of())
                + "\n";
    }
}
