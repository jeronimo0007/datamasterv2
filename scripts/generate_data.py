#!/usr/bin/env python3
"""
Script para gerar dados de transações simuladas para testes
"""
import json
import sys
import uuid
import random
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from src.utils.fake_br_identity import enrich_transaction_identity


def generate_transaction(transaction_id: str = None, fraud_rate: float = 0.05) -> dict:
    """Gera uma transação simulada"""
    if not transaction_id:
        transaction_id = str(uuid.uuid4())
    
    # Simula alguns casos de fraude
    rate = max(0.0, min(1.0, float(fraud_rate)))
    is_fraud = random.random() < rate
    
    amount = random.uniform(10, 10000)
    if is_fraud:
        # Fraudes tendem a ter valores mais altos
        amount = random.uniform(5000, 50000)
    
    timestamp = datetime.utcnow() - timedelta(
        hours=random.randint(0, 24),
        minutes=random.randint(0, 59)
    )
    
    tx = {
        'transaction_id': transaction_id,
        'user_id': f"user_{random.randint(1000, 9999)}",
        'amount': round(amount, 2),
        'currency': 'BRL',
        'merchant_id': f"merchant_{random.randint(1, 100)}",
        'merchant_category': random.choice([
            'Eletronicos',
            'Alimentacao',
            'Vestuario',
            'Servicos',
            'Viagem',
            'Entretenimento',
        ]),
        'timestamp': timestamp.isoformat(),
        'user_country': 'BR',
        'merchant_country': random.choice(['BR', 'US', 'GB', 'FR']),
        'payment_method': random.choice([
            'CREDIT_CARD', 'CREDIT_CARD', 'DEBIT_CARD', 'DEBIT_CARD'
        ]),
        'device_id': str(uuid.uuid4()),
        'ip_address': f"{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}",
        'is_fraud': is_fraud
    }
    return enrich_transaction_identity(tx)


def generate_batch(
    num_transactions: int = 100,
    output_file: str = None,
    fraud_rate: float = 0.05,
) -> list:
    """Gera um lote de transações"""
    transactions = []
    
    for _ in range(num_transactions):
        transactions.append(generate_transaction(fraud_rate=fraud_rate))
    
    if output_file:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(transactions, f, indent=2)
        
        print(f"✅ {num_transactions} transações geradas em {output_file}")
    
    return transactions


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Gera transações simuladas')
    parser.add_argument('-n', '--num', type=int, default=100, 
                       help='Número de transações a gerar')
    parser.add_argument('-o', '--output', type=str, 
                       default='data/transactions.json',
                       help='Arquivo de saída')
    parser.add_argument(
        '--fraud-rate',
        type=float,
        default=0.05,
        help='Taxa simulada de fraude no JSON (0.0 a 1.0)',
    )
    
    args = parser.parse_args()
    
    generate_batch(args.num, args.output, fraud_rate=args.fraud_rate)

