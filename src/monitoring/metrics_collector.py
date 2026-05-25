"""
Coletor de métricas para observabilidade
"""
import time
from typing import Dict, Any
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MetricsCollector:
    """Classe para coletar métricas do sistema"""
    
    def __init__(self):
        self.metrics = {
            'transactions_processed': 0,
            'frauds_detected': 0,
            'false_positives': 0,
            'processing_time_avg': 0.0,
            'errors': 0,
            'start_time': datetime.utcnow()
        }
        self.timings = []
    
    def record_transaction(self, is_fraud: bool = False, processing_time: float = 0.0):
        """
        Registra uma transação processada
        
        Args:
            is_fraud: Se a transação foi identificada como fraude
            processing_time: Tempo de processamento em segundos
        """
        self.metrics['transactions_processed'] += 1
        
        if is_fraud:
            self.metrics['frauds_detected'] += 1
        
        if processing_time > 0:
            self.timings.append(processing_time)
            self.metrics['processing_time_avg'] = sum(self.timings) / len(self.timings)
    
    def record_error(self):
        """Registra um erro"""
        self.metrics['errors'] += 1
    
    def record_false_positive(self):
        """Registra um falso positivo"""
        self.metrics['false_positives'] += 1
    
    def get_metrics(self) -> Dict[str, Any]:
        """
        Retorna as métricas atuais
        
        Returns:
            Dicionário com métricas
        """
        uptime = (datetime.utcnow() - self.metrics['start_time']).total_seconds()
        
        return {
            **self.metrics,
            'uptime_seconds': uptime,
            'fraud_rate': (
                self.metrics['frauds_detected'] / self.metrics['transactions_processed']
                if self.metrics['transactions_processed'] > 0 else 0
            ),
            'error_rate': (
                self.metrics['errors'] / self.metrics['transactions_processed']
                if self.metrics['transactions_processed'] > 0 else 0
            ),
            'precision': (
                (self.metrics['frauds_detected'] - self.metrics['false_positives']) / 
                self.metrics['frauds_detected']
                if self.metrics['frauds_detected'] > 0 else 0
            )
        }
    
    def reset(self):
        """Reseta as métricas"""
        self.metrics = {
            'transactions_processed': 0,
            'frauds_detected': 0,
            'false_positives': 0,
            'processing_time_avg': 0.0,
            'errors': 0,
            'start_time': datetime.utcnow()
        }
        self.timings = []


# Instância global
metrics_collector = MetricsCollector()

