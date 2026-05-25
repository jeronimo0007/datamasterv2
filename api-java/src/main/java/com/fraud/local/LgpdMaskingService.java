package com.fraud.local;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class LgpdMaskingService {

    public Map<String, Object> maskPii(Map<String, Object> input) {
        Map<String, Object> out = new LinkedHashMap<>(input);
        maskField(out, "cpf", this::maskCpf);
        maskField(out, "email", this::maskEmail);
        maskField(out, "phone", this::maskPhone);
        maskField(out, "telefone", this::maskPhone);
        maskField(out, "name", this::maskName);
        maskField(out, "nome", this::maskName);
        maskField(out, "card_number", this::maskCard);
        maskField(out, "numero_cartao", this::maskCard);
        return out;
    }

    private void maskField(Map<String, Object> data, String key, java.util.function.Function<String, String> fn) {
        Object v = data.get(key);
        if (v != null && !String.valueOf(v).isBlank()) {
            data.put(key, fn.apply(String.valueOf(v)));
        }
    }

    String maskCpf(String cpf) {
        String clean = cpf.replaceAll("[^0-9]", "");
        if (clean.length() != 11) {
            return cpf;
        }
        return "***." + clean.substring(3, 6) + "*." + clean.substring(7, 9) + "-" + clean.substring(9);
    }

    String maskEmail(String email) {
        int at = email.indexOf('@');
        if (at < 1) {
            return email;
        }
        String local = email.substring(0, at);
        String domain = email.substring(at + 1);
        String maskedLocal = local.charAt(0) + "*".repeat(Math.max(0, local.length() - 1));
        String maskedDomain;
        int dot = domain.indexOf('.');
        if (dot > 0) {
            maskedDomain = domain.charAt(0) + "***." + domain.substring(dot + 1);
        } else {
            maskedDomain = domain.charAt(0) + "***";
        }
        return maskedLocal + "@" + maskedDomain;
    }

    String maskPhone(String phone) {
        String clean = phone.replaceAll("[^0-9]", "");
        if (clean.length() < 10) {
            return phone;
        }
        if (clean.length() == 11) {
            return "(" + clean.substring(0, 2) + ") " + clean.charAt(2) + "****-" + clean.substring(7);
        }
        return "(" + clean.substring(0, 2) + ") ****-" + clean.substring(clean.length() - 4);
    }

    String maskName(String name) {
        String[] parts = name.trim().split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < parts.length; i++) {
            if (i > 0) {
                sb.append(' ');
            }
            String p = parts[i];
            sb.append(p.length() > 1 ? p.charAt(0) + "*".repeat(p.length() - 1) : "*");
        }
        return sb.toString();
    }

    String maskCard(String card) {
        String clean = card.replaceAll("[^0-9]", "");
        if (clean.length() < 4) {
            return card;
        }
        String masked = "*".repeat(clean.length() - 4) + clean.substring(clean.length() - 4);
        if (card.contains(" ")) {
            StringBuilder spaced = new StringBuilder();
            for (int i = 0; i < masked.length(); i += 4) {
                if (spaced.length() > 0) {
                    spaced.append(' ');
                }
                spaced.append(masked, i, Math.min(i + 4, masked.length()));
            }
            return spaced.toString();
        }
        return masked;
    }
}
