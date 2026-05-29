package com.fraud.local;

import java.util.Locale;
import java.util.Random;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.stereotype.Component;

/** CPF e cartao ficticios para demo (LGPD: exibir mascarados na lista). */
@Component
public class DemoIdentityGenerator {

    private static final String[] FIRST_NAMES = {
        "Ana", "Bruno", "Carla", "Diego", "Elena", "Felipe", "Gabriela", "Henrique"
    };
    private static final String[] LAST_NAMES = {
        "Silva", "Santos", "Oliveira", "Souza", "Lima", "Costa", "Ferreira", "Almeida"
    };

    public String generateCpf() {
        Random r = ThreadLocalRandom.current();
        int[] base = new int[9];
        for (int i = 0; i < 9; i++) {
            base[i] = r.nextInt(10);
        }
        int d1 = cpfDigit(base, 10);
        int d2 = cpfDigit(append(base, d1), 11);
        return String.format(
                Locale.ROOT,
                "%d%d%d.%d%d%d.%d%d%d-%d%d",
                base[0],
                base[1],
                base[2],
                base[3],
                base[4],
                base[5],
                base[6],
                base[7],
                base[8],
                d1,
                d2);
    }

    public String generateCardNumber() {
        Random r = ThreadLocalRandom.current();
        char prefix = r.nextBoolean() ? '4' : (r.nextBoolean() ? '5' : '2');
        StringBuilder digits = new StringBuilder().append(prefix);
        for (int i = 0; i < 15; i++) {
            digits.append(r.nextInt(10));
        }
        String raw = digits.toString();
        return raw.substring(0, 4)
                + " "
                + raw.substring(4, 8)
                + " "
                + raw.substring(8, 12)
                + " "
                + raw.substring(12, 16);
    }

    public String generateHolderName() {
        Random r = ThreadLocalRandom.current();
        return FIRST_NAMES[r.nextInt(FIRST_NAMES.length)]
                + " "
                + LAST_NAMES[r.nextInt(LAST_NAMES.length)];
    }

    public String normalizePaymentMethod(String paymentMethod) {
        if (paymentMethod == null || paymentMethod.isBlank()) {
            return "CREDIT_CARD";
        }
        String pm = paymentMethod.trim().toUpperCase(Locale.ROOT);
        if ("PIX".equals(pm)) {
            return "CREDIT_CARD";
        }
        return pm;
    }

    private static int cpfDigit(int[] nums, int weightStart) {
        int sum = 0;
        int w = weightStart;
        for (int n : nums) {
            sum += n * w--;
        }
        int mod = 11 - (sum % 11);
        return mod >= 10 ? 0 : mod;
    }

    private static int[] append(int[] base, int extra) {
        int[] out = new int[base.length + 1];
        System.arraycopy(base, 0, out, 0, base.length);
        out[base.length] = extra;
        return out;
    }
}
