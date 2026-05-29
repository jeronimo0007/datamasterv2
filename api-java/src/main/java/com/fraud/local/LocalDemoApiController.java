package com.fraud.local;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fraud.local.mongo.UserProfileRepository;
import com.fraud.messaging.FraudAlertEmailMessage;
import com.fraud.messaging.FraudEmailNotificationPublisher;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Locale;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Profile("local")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class LocalDemoApiController {

    private final InMemoryDemoState state;
    private final LocalFraudScoringService scoring;
    private final LgpdMaskingService masking;
    private final UserProfileRepository userProfileRepository;
    private final UserProfileAnomalyService profileAnomaly;
    private final DeepSeekChatService chatService;
    private final TransactionHistoryService transactionHistory;
    private final DemoIdentityGenerator demoIdentity;

    @Autowired(required = false)
    private FraudEmailNotificationPublisher fraudEmailPublisher;

    @GetMapping("/")
    public Map<String, Object> root() {
        return Map.of(
                "service", "Fraud Detection API",
                "version", "1.0.0",
                "runtime", "java-spring-boot",
                "docs", "/swagger-ui.html",
                "status", "running");
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> metrics = state.systemMetrics();
        return Map.of(
                "status", "healthy",
                "model_loaded", true,
                "transactions_processed", metrics.get("transactions_processed"),
                "uptime_seconds", metrics.get("uptime_seconds"),
                "timestamp", Instant.now().toString());
    }

    @PostMapping("/api/v1/transactions/analyze")
    public Map<String, Object> analyze(@RequestBody TransactionAnalyzeRequest body) {
        long start = System.nanoTime();
        try {
            ZonedDateTime now = ZonedDateTime.now(ZoneOffset.UTC);
            String paymentMethod = demoIdentity.normalizePaymentMethod(body.paymentMethod());
            Map<String, Object> txData = new LinkedHashMap<>();
            txData.put("amount", body.amount());
            txData.put("merchant_category", body.merchantCategory());
            txData.put("payment_method", paymentMethod);
            txData.put(
                    "hour",
                    body.hour() != null ? body.hour() : now.getHour());
            txData.put(
                    "is_weekend",
                    body.isWeekend() != null
                            ? body.isWeekend()
                            : (now.getDayOfWeek().getValue() >= 6 ? 1 : 0));
            txData.put(
                    "is_international",
                    body.isInternational() != null
                            ? body.isInternational()
                            : (body.userCountry() != null
                                            && body.merchantCountry() != null
                                            && !body.userCountry().equals(body.merchantCountry())
                                    ? 1
                                    : 0));

            String profileUserId = resolveProfileUserId(body);
            Map<String, Object> profileContext =
                    userProfileRepository
                            .findByUserId(profileUserId)
                            .map(p -> profileAnomaly.analyzeAgainstProfile(p, txData))
                            .orElseGet(() -> profileAnomaly.noProfile(profileUserId));
            double boost = ((Number) profileContext.get("anomaly_score_boost")).doubleValue();
            txData.put("profile_anomaly_boost", boost);

            Map<String, Object> result = new LinkedHashMap<>(scoring.score(txData));
            result.put("user_profile", profileContext);
            double processingMs = (System.nanoTime() - start) / 1_000_000.0;

            String holderDocument =
                    body.holderDocument() != null && !body.holderDocument().isBlank()
                            ? body.holderDocument().trim()
                            : demoIdentity.generateCpf();
            String cardNumber =
                    body.cardNumber() != null && !body.cardNumber().isBlank()
                            ? body.cardNumber().trim()
                            : demoIdentity.generateCardNumber();
            String cardHolderName =
                    body.cardHolderName() != null && !body.cardHolderName().isBlank()
                            ? body.cardHolderName().trim()
                            : demoIdentity.generateHolderName();

            String txId =
                    body.transactionId() != null ? body.transactionId() : UUID.randomUUID().toString();
            Map<String, Object> record = new LinkedHashMap<>();
            record.put("transaction_id", txId);
            record.put("profile_user_id", profileUserId);
            record.put("holder_document", holderDocument);
            record.put("card_number", cardNumber);
            record.put("card_holder_name", cardHolderName);
            record.put("amount", body.amount());
            record.put("merchant_category", body.merchantCategory());
            record.put("payment_method", paymentMethod);
            record.put("user_country", body.userCountry());
            record.put("merchant_country", body.merchantCountry());
            record.put("fraud_score", result.get("fraud_score"));
            record.put("is_fraud", result.get("is_fraud"));
            record.put("risk_level", result.get("risk_level"));
            record.put("recommended_action", result.get("recommended_action"));
            record.put("review_status", result.get("review_status"));
            record.put("processing_time_ms", Math.round(processingMs * 100.0) / 100.0);
            record.put("timestamp", now.toInstant().toString());
            record.put("anomaly_reasons", profileContext.get("anomaly_reasons"));
            record.put("profile_found", profileContext.get("profile_found"));
            record.put("cosmos_sync_status", TransactionHistoryService.COSMOS_PENDING);
            state.addTransaction(record);
            transactionHistory.persist(record);

            if (Boolean.TRUE.equals(result.get("is_fraud"))) {
                String alertId = UUID.randomUUID().toString();
                Map<String, Object> alert = new LinkedHashMap<>();
                alert.put("alert_id", alertId);
                alert.put("transaction_id", txId);
                alert.put("fraud_score", result.get("fraud_score"));
                alert.put("risk_level", result.get("risk_level"));
                alert.put("amount", body.amount());
                alert.put("timestamp", now.toInstant().toString());
                alert.put("status", "OPEN");
                state.addAlert(alert);

                if (fraudEmailPublisher != null) {
                    fraudEmailPublisher.publishFraudDetected(
                            FraudAlertEmailMessage.builder()
                                    .alertId(alertId)
                                    .transactionId(txId)
                                    .fraudScore(((Number) result.get("fraud_score")).doubleValue())
                                    .riskLevel(String.valueOf(result.get("risk_level")))
                                    .recommendedAction(String.valueOf(result.get("recommended_action")))
                                    .amount(body.amount())
                                    .merchantCategory(body.merchantCategory())
                                    .paymentMethod(paymentMethod)
                                    .holderDocument(holderDocument)
                                    .cardHolderName(cardHolderName)
                                    .detectedAt(now.toInstant())
                                    .build());
                }
            }

            Map<String, Object> response = new LinkedHashMap<>(result);
            response.put("transaction_id", txId);
            response.put("processing_time_ms", record.get("processing_time_ms"));
            return response;
        } catch (Exception e) {
            state.recordError();
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage(), e);
        }
    }

    @PostMapping("/api/v1/transactions/batch")
    public Map<String, Object> batch(@RequestBody List<TransactionAnalyzeRequest> transactions) {
        List<Map<String, Object>> results = new ArrayList<>();
        for (TransactionAnalyzeRequest tx : transactions) {
            results.add(analyze(tx));
        }
        long frauds = results.stream().filter(r -> Boolean.TRUE.equals(r.get("is_fraud"))).count();
        return Map.of(
                "total_analyzed",
                results.size(),
                "total_frauds_detected",
                frauds,
                "fraud_rate",
                results.isEmpty() ? 0.0 : round4((double) frauds / results.size()),
                "results",
                results);
    }

    @GetMapping("/api/v1/transactions")
    public Map<String, Object> listTransactions(
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(defaultValue = "all") String filter) {
        List<Map<String, Object>> list =
                state.listTransactions(filter, limit).stream()
                        .map(transactionHistory::toPublicView)
                        .toList();
        return Map.of(
                "total",
                state.getTransactions().size(),
                "history_mongodb",
                transactionHistory.countHistory(),
                "history_cosmos_pending",
                transactionHistory.countPendingCosmosSync(),
                "filter",
                filter,
                "returned",
                list.size(),
                "transactions",
                list);
    }

    @PostMapping("/api/v1/transactions/{transactionId}/release")
    public Map<String, Object> releaseTransaction(
            @PathVariable String transactionId,
            @RequestBody(required = false) Map<String, String> body) {
        String by = body != null ? body.getOrDefault("released_by", "analyst") : "analyst";
        if (!state.releaseTransaction(transactionId, by)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Transação não encontrada");
        }
        return Map.of(
                "transaction_id",
                transactionId,
                "review_status",
                InMemoryDemoState.REVIEW_RELEASED,
                "message",
                "Transação liberada para fluxo normal");
    }

    @GetMapping("/api/v1/batch/profile-stats")
    public Map<String, Object> batchProfileStats() {
        long count = userProfileRepository.count();
        long historyCount = transactionHistory.countHistory();
        return Map.of(
                "mongodb_profiles_loaded",
                count,
                "transaction_history_count",
                historyCount,
                "transaction_history_cosmos_pending",
                transactionHistory.countPendingCosmosSync(),
                "batch_ready",
                count > 0,
                "hint",
                count == 0
                        ? "Execute: python3 scripts/batch_dataprep_mongo.py ou docker compose run --rm batch-prep"
                        : "Perfis históricos disponíveis para consulta na análise online");
    }

    @PostMapping("/api/v1/assistant/chat")
    public Map<String, Object> assistantChat(@RequestBody ChatRequest body) {
        if (body.transactionId() != null && !body.transactionId().isBlank()) {
            Map<String, Object> tx =
                    state.findTransaction(body.transactionId())
                            .orElseThrow(
                                    () ->
                                            new ResponseStatusException(
                                                    HttpStatus.NOT_FOUND,
                                                    "Transação não encontrada"));
            return chatService.analyzeTransactionRelease(
                    transactionHistory.toPublicView(tx), body.message());
        }
        if (body.message() == null || body.message().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "message obrigatório");
        }
        int limit = body.contextLimit() != null && body.contextLimit() > 0 ? body.contextLimit() : 15;
        List<Map<String, Object>> fraudCtx =
                state.fraudTransactionsForChat(limit).stream()
                        .map(transactionHistory::toPublicView)
                        .toList();
        return chatService.analyzeFraudContext(body.message(), fraudCtx);
    }

    @GetMapping("/api/v1/alerts")
    public Map<String, Object> listAlerts(@RequestParam(defaultValue = "50") int limit) {
        long open =
                state.getAlerts().stream()
                        .filter(a -> "OPEN".equals(String.valueOf(a.get("status"))))
                        .count();
        return Map.of(
                "total",
                state.getAlerts().size(),
                "open",
                open,
                "alerts",
                state.recentAlerts(limit));
    }

    @GetMapping("/api/v1/model/metrics")
    public Map<String, Object> modelMetrics() {
        return scoring.modelMetrics();
    }

    @GetMapping("/api/v1/model/feature-importance")
    public Map<String, Double> featureImportance() {
        return scoring.featureImportance();
    }

    @GetMapping("/api/v1/metrics")
    public Map<String, Object> systemMetrics() {
        return state.systemMetrics();
    }

    @PostMapping("/api/v1/lgpd/mask")
    public Map<String, Object> mask(@RequestBody Map<String, Object> data) {
        Map<String, Object> filtered = new LinkedHashMap<>();
        data.forEach(
                (k, v) -> {
                    if (v != null) {
                        filtered.put(k, v);
                    }
                });
        return Map.of(
                "original_fields",
                filtered.keySet(),
                "masked_data",
                masking.maskPii(filtered),
                "masked_at",
                Instant.now().toString());
    }

    @GetMapping("/api/v1/data-quality/report")
    public Map<String, Object> dataQualityReport() {
        List<Map<String, Object>> txs = state.getTransactions();
        if (txs.isEmpty()) {
            return Map.of(
                    "status", "no_data",
                    "message", "Nenhuma transacao processada ainda");
        }

        List<Double> amounts = new ArrayList<>();
        List<Double> scores = new ArrayList<>();
        for (Map<String, Object> t : txs) {
            amounts.add(((Number) t.get("amount")).doubleValue());
            scores.add(((Number) t.get("fraud_score")).doubleValue());
        }

        long nullAmounts = txs.stream().filter(t -> t.get("amount") == null).count();
        long outOfRange =
                txs.stream()
                        .filter(
                                t -> {
                                    double a = ((Number) t.get("amount")).doubleValue();
                                    return a < 0 || a > 1_000_000;
                                })
                        .count();
        List<String> ids =
                txs.stream().map(t -> String.valueOf(t.get("transaction_id"))).toList();
        long duplicates = ids.size() - ids.stream().distinct().count();
        long frauds = txs.stream().filter(t -> Boolean.TRUE.equals(t.get("is_fraud"))).count();
        double fraudRate = (double) frauds / txs.size();

        List<Map<String, Object>> checks = List.of(
                Map.of(
                        "rule",
                        "amount_not_null",
                        "passed",
                        nullAmounts == 0,
                        "details",
                        nullAmounts + " valores nulos encontrados"),
                Map.of(
                        "rule",
                        "amount_range_0_1M",
                        "passed",
                        outOfRange == 0,
                        "details",
                        outOfRange + " valores fora do range"),
                Map.of(
                        "rule",
                        "transaction_id_unique",
                        "passed",
                        duplicates == 0,
                        "details",
                        duplicates + " IDs duplicados"),
                Map.of(
                        "rule",
                        "fraud_rate_below_50pct",
                        "passed",
                        fraudRate < 0.5,
                        "details",
                        String.format(Locale.ROOT, "Taxa de fraude: %.2f%%", fraudRate * 100)));

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("amount_mean", round2(mean(amounts)));
        stats.put("amount_median", round2(median(amounts)));
        stats.put("amount_stddev", amounts.size() > 1 ? round2(stddev(amounts)) : 0.0);
        stats.put("amount_min", round2(amounts.stream().min(Double::compare).orElse(0.0)));
        stats.put("amount_max", round2(amounts.stream().max(Double::compare).orElse(0.0)));
        stats.put("fraud_score_mean", round4(mean(scores)));
        stats.put("fraud_rate", round4(fraudRate));

        return Map.of(
                "report_timestamp",
                Instant.now().toString(),
                "total_records",
                txs.size(),
                "all_passed",
                checks.stream().allMatch(c -> Boolean.TRUE.equals(c.get("passed"))),
                "checks",
                checks,
                "statistics",
                stats);
    }

    @GetMapping("/api/v1/dashboard/summary")
    public Map<String, Object> dashboardSummary() {
        List<Map<String, Object>> txs = state.getTransactions();
        long nFraud =
                txs.stream()
                        .filter(
                                t ->
                                        Boolean.TRUE.equals(t.get("is_fraud"))
                                                && !InMemoryDemoState.REVIEW_RELEASED.equals(
                                                        t.get("review_status")))
                        .count();
        long nReleased =
                txs.stream()
                        .filter(t -> InMemoryDemoState.REVIEW_RELEASED.equals(t.get("review_status")))
                        .count();
        double fraudRate = txs.isEmpty() ? 0.0 : (double) nFraud / txs.size();
        double avgMs =
                txs.isEmpty()
                        ? 0.0
                        : txs.stream()
                                .mapToDouble(
                                        t ->
                                                ((Number)
                                                                t.getOrDefault(
                                                                        "processing_time_ms", 0))
                                                        .doubleValue())
                                .average()
                                .orElse(0.0);

        Map<String, Integer> categoryCounts = new LinkedHashMap<>();
        Map<String, Integer> categoryFrauds = new LinkedHashMap<>();
        Map<String, Integer> paymentCounts = new LinkedHashMap<>();
        for (Map<String, Object> t : txs) {
            String cat = String.valueOf(t.getOrDefault("merchant_category", "Outros"));
            categoryCounts.merge(cat, 1, Integer::sum);
            if (Boolean.TRUE.equals(t.get("is_fraud"))) {
                categoryFrauds.merge(cat, 1, Integer::sum);
            }
            String pm = String.valueOf(t.getOrDefault("payment_method", "Outros"));
            paymentCounts.merge(pm, 1, Integer::sum);
        }

        List<Double> scores =
                txs.stream()
                        .map(t -> ((Number) t.get("fraud_score")).doubleValue())
                        .toList();
        Map<String, Integer> scoreDistribution = Map.of(
                "approved_below_60",
                (int) scores.stream().filter(s -> s < LocalFraudScoringService.THRESHOLD_AUTO_RELEASE_MAX).count(),
                "review_60_75",
                (int)
                        scores.stream()
                                .filter(
                                        s ->
                                                s >= LocalFraudScoringService.THRESHOLD_AUTO_RELEASE_MAX
                                                        && s
                                                                <= LocalFraudScoringService
                                                                        .THRESHOLD_BLOCK_MIN)
                                .count(),
                "blocked_above_75",
                (int)
                        scores.stream()
                                .filter(s -> s > LocalFraudScoringService.THRESHOLD_BLOCK_MIN)
                                .count());

        Map<String, Object> metrics = state.systemMetrics();
        Map<String, Object> kpis = new LinkedHashMap<>();
        kpis.put("total_transactions", txs.size());
        kpis.put("total_frauds", nFraud);
        kpis.put("total_released", nReleased);
        kpis.put("mongodb_profiles", userProfileRepository.count());
        kpis.put("fraud_rate", fraudRate);
        kpis.put("avg_processing_time_ms", Math.round(avgMs * 100.0) / 100.0);
        kpis.put("error_rate", metrics.getOrDefault("error_rate", 0.0));

        return Map.of(
                "kpis",
                kpis,
                "score_distribution",
                scoreDistribution,
                "category_distribution",
                categoryCounts,
                "category_fraud_counts",
                categoryFrauds,
                "payment_distribution",
                paymentCounts,
                "recent_transactions",
                state.recentTransactions(10),
                "recent_alerts",
                state.recentAlerts(5));
    }

    private static double mean(List<Double> values) {
        return values.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
    }

    private static double median(List<Double> values) {
        List<Double> sorted = values.stream().sorted().toList();
        int n = sorted.size();
        if (n == 0) {
            return 0.0;
        }
        if (n % 2 == 1) {
            return sorted.get(n / 2);
        }
        return (sorted.get(n / 2 - 1) + sorted.get(n / 2)) / 2.0;
    }

    private static double stddev(List<Double> values) {
        double m = mean(values);
        double var =
                values.stream().mapToDouble(v -> (v - m) * (v - m)).average().orElse(0.0);
        return Math.sqrt(var);
    }

    private static double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }

    private static double round4(double v) {
        return Math.round(v * 10_000.0) / 10_000.0;
    }

    public record ChatRequest(
            String message,
            @JsonProperty("context_limit") Integer contextLimit,
            @JsonProperty("transaction_id") String transactionId) {}

    public record TransactionAnalyzeRequest(
            double amount,
            @JsonProperty("merchant_category") String merchantCategory,
            @JsonProperty("user_country") String userCountry,
            @JsonProperty("merchant_country") String merchantCountry,
            @JsonProperty("payment_method") String paymentMethod,
            Integer hour,
            @JsonProperty("is_weekend") Integer isWeekend,
            @JsonProperty("is_international") Integer isInternational,
            @JsonProperty("transaction_id") String transactionId,
            @JsonProperty("holder_document") String holderDocument,
            @JsonProperty("card_number") String cardNumber,
            @JsonProperty("card_holder_name") String cardHolderName,
            @JsonProperty("profile_user_id") String profileUserId,
            @JsonProperty("user_id") String userId) {

        public TransactionAnalyzeRequest {
            if (merchantCategory == null || merchantCategory.isBlank()) {
                merchantCategory = "Outros";
            }
            if (userCountry == null || userCountry.isBlank()) {
                userCountry = "BR";
            }
            if (merchantCountry == null || merchantCountry.isBlank()) {
                merchantCountry = "BR";
            }
            if (paymentMethod == null || paymentMethod.isBlank()) {
                paymentMethod = "CREDIT_CARD";
            }
        }
    }

    /** Perfil batch (Mongo user_profiles); legado: user_id no JSON. */
    private static String resolveProfileUserId(TransactionAnalyzeRequest body) {
        if (body.profileUserId() != null && !body.profileUserId().isBlank()) {
            return body.profileUserId().trim();
        }
        if (body.userId() != null && !body.userId().isBlank()) {
            return body.userId().trim();
        }
        return "anonymous";
    }
}
