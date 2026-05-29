package com.fraud.local;

import com.fraud.local.mongo.UserProfileDocument;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("local")
public class UserProfileAnomalyService {

    private static final int MIN_TX_FOR_FULL_BEHAVIOR = 5;
    private static final int MIN_TX_FOR_SOFT_BEHAVIOR = 3;

    private static final double MAX_BOOST = 0.22;
    private static final double BOOST_AMOUNT_HIGH = 0.15;
    private static final double BOOST_AMOUNT_P95 = 0.09;
    private static final double BOOST_CATEGORY = 0.06;
    private static final double BOOST_PAYMENT = 0.05;
    private static final double BOOST_HOUR = 0.04;

    public Map<String, Object> analyzeAgainstProfile(
            UserProfileDocument profile, Map<String, Object> tx) {
        List<String> reasons = new ArrayList<>();
        double boost = 0.0;

        int txCount = profile.getTxCount();
        double confidence = confidenceForHistory(txCount);
        double behaviorScale = behaviorRuleScale(txCount);
        double sigmaMult = txCount < MIN_TX_FOR_SOFT_BEHAVIOR ? 3.4 : (txCount < MIN_TX_FOR_FULL_BEHAVIOR ? 2.9 : 2.5);

        double amount = toDouble(tx.get("amount"));
        String category =
                normalizeCategory(String.valueOf(tx.getOrDefault("merchant_category", "Outros")));
        String payment =
                String.valueOf(tx.getOrDefault("payment_method", "CREDIT_CARD")).toUpperCase(Locale.ROOT);
        int hour = toInt(tx.get("hour"), 12);

        double threshold = profile.getAvgAmount() + sigmaMult * Math.max(profile.getStdAmount(), 1.0);
        if (amount > threshold) {
            reasons.add(
                    String.format(
                            Locale.ROOT,
                            "Valor R$ %.2f acima do padrao historico (media R$ %.2f, p95 R$ %.2f)",
                            amount,
                            profile.getAvgAmount(),
                            profile.getP95Amount()));
            boost += BOOST_AMOUNT_HIGH * confidence;
        } else if (amount > profile.getP95Amount() * (txCount < MIN_TX_FOR_FULL_BEHAVIOR ? 1.08 : 1.0)) {
            reasons.add(
                    String.format(
                            Locale.ROOT,
                            "Valor acima do P95 historico (R$ %.2f)",
                            profile.getP95Amount()));
            boost += BOOST_AMOUNT_P95 * confidence;
        }

        if (txCount >= MIN_TX_FOR_SOFT_BEHAVIOR) {
            List<String> typical = Optional.ofNullable(profile.getTypicalCategories()).orElse(List.of());
            if (!typical.isEmpty() && !typical.contains(category)) {
                reasons.add(
                        "Categoria '"
                                + category
                                + "' atipica para o usuario (historico: "
                                + typical
                                + ")");
                boost += BOOST_CATEGORY * behaviorScale;
            }

            List<String> typicalPay =
                    Optional.ofNullable(profile.getTypicalPaymentMethods()).orElse(List.of());
            if (!typicalPay.isEmpty() && !typicalPay.contains(payment)) {
                reasons.add("Meio de pagamento '" + payment + "' incomum no historico");
                boost += BOOST_PAYMENT * behaviorScale;
            }

            if (txCount >= MIN_TX_FOR_FULL_BEHAVIOR
                    && Math.abs(hour - profile.getAvgHour()) >= 6) {
                reasons.add(
                        String.format(
                                Locale.ROOT,
                                "Horario %dh distante do padrao (media %.1fh)",
                                hour,
                                profile.getAvgHour()));
                boost += BOOST_HOUR;
            }
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("profile_found", true);
        out.put("user_id", profile.getUserId());
        out.put("historical_tx_count", txCount);
        out.put("anomaly_score_boost", round4(Math.min(MAX_BOOST, boost)));
        out.put("anomaly_reasons", reasons);
        out.put("is_unusual", !reasons.isEmpty());
        return out;
    }

    private static double behaviorRuleScale(int txCount) {
        if (txCount >= MIN_TX_FOR_FULL_BEHAVIOR) {
            return 1.0;
        }
        if (txCount >= MIN_TX_FOR_SOFT_BEHAVIOR) {
            return 0.55;
        }
        return 0.0;
    }

    private static double confidenceForHistory(int txCount) {
        if (txCount >= MIN_TX_FOR_FULL_BEHAVIOR) {
            return 1.0;
        }
        if (txCount >= 3) {
            return 0.88;
        }
        if (txCount == 2) {
            return 0.72;
        }
        if (txCount == 1) {
            return 0.58;
        }
        return 1.0;
    }

    public Map<String, Object> noProfile(String userId) {
        return Map.of(
                "profile_found",
                false,
                "user_id",
                userId != null ? userId : "anonymous",
                "anomaly_score_boost",
                0.0,
                "anomaly_reasons",
                List.of("Sem perfil batch no MongoDB — rode scripts/batch_dataprep_mongo.py"),
                "is_unusual",
                false);
    }

    private static String normalizeCategory(String value) {
        return switch (value) {
            case "Eletrônicos" -> "Eletronicos";
            case "Alimentação" -> "Alimentacao";
            case "Vestuário" -> "Vestuario";
            case "Serviços" -> "Servicos";
            default -> value.isBlank() ? "Outros" : value;
        };
    }

    private static double round4(double v) {
        return Math.round(v * 10_000.0) / 10_000.0;
    }

    private static double toDouble(Object o) {
        if (o instanceof Number n) {
            return n.doubleValue();
        }
        return 0.0;
    }

    private static int toInt(Object o, int defaultValue) {
        if (o instanceof Number n) {
            return n.intValue();
        }
        return defaultValue;
    }
}
