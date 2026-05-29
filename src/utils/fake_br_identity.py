"""CPF e cartao ficticios para demo (nao usar dados reais)."""

from __future__ import annotations

import random


def _cpf_check_digits(base9: list[int]) -> list[int]:
    def digit(nums: list[int], weights: list[int]) -> int:
        s = sum(n * w for n, w in zip(nums, weights))
        r = 11 - (s % 11)
        return 0 if r >= 10 else r

    d1 = digit(base9, list(range(10, 1, -1)))
    d2 = digit(base9 + [d1], list(range(11, 1, -1)))
    return base9 + [d1, d2]


def fake_cpf(formatted: bool = True) -> str:
    """CPF valido no formato (digitos verificadores corretos)."""
    base = [random.randint(0, 9) for _ in range(9)]
    while len(set(base)) == 1:
        base = [random.randint(0, 9) for _ in range(9)]
    digits = _cpf_check_digits(base)
    if not formatted:
        return "".join(str(d) for d in digits)
    return (
        f"{digits[0]}{digits[1]}{digits[2]}."
        f"{digits[3]}{digits[4]}{digits[5]}."
        f"{digits[6]}{digits[7]}{digits[8]}-"
        f"{digits[9]}{digits[10]}"
    )


def fake_card_number(spaced: bool = True) -> str:
    """16 digitos (bandeira generica 4xxx)."""
    prefix = random.choice(["4", "5", "2"])
    rest = "".join(str(random.randint(0, 9)) for _ in range(15))
    digits = prefix + rest[:15]
    if not spaced:
        return digits
    return " ".join(digits[i : i + 4] for i in range(0, 16, 4))


def fake_holder_name() -> str:
    first = random.choice(
        ["Ana", "Bruno", "Carla", "Diego", "Elena", "Felipe", "Gabriela", "Henrique"]
    )
    last = random.choice(
        ["Silva", "Santos", "Oliveira", "Souza", "Lima", "Costa", "Ferreira", "Almeida"]
    )
    return f"{first} {last}"


def enrich_transaction_identity(tx: dict) -> dict:
    """Garante CPF, cartao e titular no dict de transacao simulada."""
    out = dict(tx)
    if not out.get("holder_document"):
        out["holder_document"] = fake_cpf()
    if not out.get("card_number"):
        out["card_number"] = fake_card_number()
    if not out.get("card_holder_name"):
        out["card_holder_name"] = fake_holder_name()
    pm = str(out.get("payment_method") or "CREDIT_CARD").upper()
    if pm == "PIX":
        pm = "CREDIT_CARD"
    out["payment_method"] = pm
    return out
