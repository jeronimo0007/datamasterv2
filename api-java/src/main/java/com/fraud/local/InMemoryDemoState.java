package com.fraud.local;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Component;

@Component
public class InMemoryDemoState {

    public static final String REVIEW_OPEN = "OPEN";
    public static final String REVIEW_RELEASED = "RELEASED";

    private final Instant startedAt = Instant.now();
    private final List<Map<String, Object>> transactions = new CopyOnWriteArrayList<>();
    private final List<Map<String, Object>> alerts = new CopyOnWriteArrayList<>();
    private final AtomicLong transactionsProcessed = new AtomicLong();
    private final AtomicLong errors = new AtomicLong();

    public Instant getStartedAt() {
        return startedAt;
    }

    public List<Map<String, Object>> getTransactions() {
        return transactions;
    }

    public List<Map<String, Object>> getAlerts() {
        return alerts;
    }

    public void addTransaction(Map<String, Object> record) {
        if (!record.containsKey("review_status")) {
            record.put(
                    "review_status",
                    Boolean.TRUE.equals(record.get("is_fraud")) ? REVIEW_OPEN : "NORMAL");
        }
        transactions.add(record);
        transactionsProcessed.incrementAndGet();
    }

    public void addAlert(Map<String, Object> alert) {
        alerts.add(alert);
    }

    public void recordError() {
        errors.incrementAndGet();
    }

    public Optional<Map<String, Object>> findTransaction(String transactionId) {
        return transactions.stream()
                .filter(t -> transactionId.equals(String.valueOf(t.get("transaction_id"))))
                .findFirst();
    }

    public boolean releaseTransaction(String transactionId, String releasedBy) {
        Optional<Map<String, Object>> opt = findTransaction(transactionId);
        if (opt.isEmpty()) {
            return false;
        }
        Map<String, Object> tx = opt.get();
        tx.put("review_status", REVIEW_RELEASED);
        tx.put("released_at", Instant.now().toString());
        tx.put("released_by", releasedBy != null ? releasedBy : "analyst");
        tx.put("recommended_action", "APPROVE");
        tx.put("is_fraud", false);
        tx.put("risk_level", "LOW");

        alerts.stream()
                .filter(a -> transactionId.equals(String.valueOf(a.get("transaction_id"))))
                .forEach(a -> a.put("status", "RELEASED"));
        return true;
    }

    public List<Map<String, Object>> listTransactions(String filter, int limit) {
        List<Map<String, Object>> source = new ArrayList<>(transactions);
        String f = filter == null ? "all" : filter.toLowerCase();
        List<Map<String, Object>> filtered =
                switch (f) {
                    case "fraud" ->
                            source.stream()
                                    .filter(
                                            t ->
                                                    Boolean.TRUE.equals(t.get("is_fraud"))
                                                            && !REVIEW_RELEASED.equals(
                                                                    t.get("review_status")))
                                    .toList();
                    case "released" ->
                            source.stream()
                                    .filter(t -> REVIEW_RELEASED.equals(t.get("review_status")))
                                    .toList();
                    case "all" -> source;
                    default -> source;
                };
        int size = filtered.size();
        if (size <= limit) {
            return new ArrayList<>(filtered);
        }
        return new ArrayList<>(filtered.subList(size - limit, size));
    }

    public Map<String, Object> systemMetrics() {
        long processed = transactionsProcessed.get();
        long err = errors.get();
        double uptime =
                (Instant.now().toEpochMilli() - startedAt.toEpochMilli()) / 1000.0;
        return Map.of(
                "transactions_processed",
                processed,
                "errors",
                err,
                "error_rate",
                processed > 0 ? (double) err / processed : 0.0,
                "uptime_seconds",
                uptime);
    }

    public List<Map<String, Object>> recentTransactions(int limit) {
        return listTransactions("all", limit);
    }

    public List<Map<String, Object>> recentAlerts(int limit) {
        int size = alerts.size();
        if (size <= limit) {
            return new ArrayList<>(alerts);
        }
        return new ArrayList<>(alerts.subList(size - limit, size));
    }

    public List<Map<String, Object>> fraudTransactionsForChat(int limit) {
        return listTransactions("fraud", limit);
    }
}
