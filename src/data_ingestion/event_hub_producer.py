"""
Producer para enviar transações ao Azure Event Hubs
"""
import asyncio
import json
import uuid
from datetime import datetime
from typing import Dict, Any
from azure.eventhub import EventHubProducerClient, EventData
from azure.identity import DefaultAzureCredential
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventHubProducer:
    """Classe para enviar eventos ao Azure Event Hubs"""
    
    def __init__(self, event_hub_namespace: str, event_hub_name: str, 
                 connection_string: str = None):
        """
        Inicializa o producer
        
        Args:
            event_hub_namespace: Namespace do Event Hub
            event_hub_name: Nome do Event Hub
            connection_string: String de conexão (opcional, usa Managed Identity se não fornecido)
        """
        self.event_hub_name = event_hub_name
        
        if connection_string:
            self.producer = EventHubProducerClient.from_connection_string(
                conn_str=connection_string,
                eventhub_name=event_hub_name
            )
        else:
            # Usa Managed Identity
            fully_qualified_namespace = f"{event_hub_namespace}.servicebus.windows.net"
            self.producer = EventHubProducerClient(
                fully_qualified_namespace=fully_qualified_namespace,
                eventhub_name=event_hub_name,
                credential=DefaultAzureCredential()
            )
    
    async def send_transaction(self, transaction: Dict[str, Any]) -> None:
        """
        Envia uma transação ao Event Hub
        
        Args:
            transaction: Dicionário com dados da transação
        """
        try:
            # Adiciona metadados
            transaction['event_id'] = str(uuid.uuid4())
            transaction['event_timestamp'] = datetime.utcnow().isoformat()
            
            # Serializa para JSON
            event_data = EventData(json.dumps(transaction))
            
            # Envia ao Event Hub
            async with self.producer:
                event_data_batch = await self.producer.create_batch()
                event_data_batch.add(event_data)
                await self.producer.send_batch(event_data_batch)
            
            logger.info(f"Transação enviada: {transaction.get('transaction_id')}")
            
        except Exception as e:
            logger.error(f"Erro ao enviar transação: {e}")
            raise
    
    async def send_batch(self, transactions: list[Dict[str, Any]]) -> None:
        """
        Envia múltiplas transações em lote
        
        Args:
            transactions: Lista de transações
        """
        try:
            async with self.producer:
                event_data_batch = await self.producer.create_batch()
                
                for transaction in transactions:
                    transaction['event_id'] = str(uuid.uuid4())
                    transaction['event_timestamp'] = datetime.utcnow().isoformat()
                    event_data = EventData(json.dumps(transaction))
                    
                    try:
                        event_data_batch.add(event_data)
                    except ValueError:
                        # Batch está cheio, envia e cria novo
                        await self.producer.send_batch(event_data_batch)
                        event_data_batch = await self.producer.create_batch()
                        event_data_batch.add(event_data)
                
                # Envia o último batch
                if len(event_data_batch) > 0:
                    await self.producer.send_batch(event_data_batch)
            
            logger.info(f"Lote de {len(transactions)} transações enviado")
            
        except Exception as e:
            logger.error(f"Erro ao enviar lote: {e}")
            raise
    
    def close(self):
        """Fecha a conexão"""
        if self.producer:
            self.producer.close()


def generate_sample_transaction() -> Dict[str, Any]:
    """Gera uma transação de exemplo"""
    import random
    
    return {
        'transaction_id': str(uuid.uuid4()),
        'user_id': f"user_{random.randint(1000, 9999)}",
        'amount': round(random.uniform(10, 10000), 2),
        'currency': 'BRL',
        'merchant_id': f"merchant_{random.randint(1, 100)}",
        'merchant_category': random.choice(
            ['Eletronicos', 'Alimentacao', 'Vestuario', 'Servicos']
        ),
        'timestamp': datetime.utcnow().isoformat(),
        'user_country': 'BR',
        'merchant_country': random.choice(['BR', 'US', 'GB']),
        'payment_method': random.choice(['CREDIT_CARD', 'DEBIT_CARD', 'PIX']),
        'device_id': str(uuid.uuid4()),
        'ip_address': f"{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}"
    }


async def main():
    """Exemplo de uso"""
    # Configuração
    EVENT_HUB_NAMESPACE = "fraud-events"
    EVENT_HUB_NAME = "transactions"
    CONNECTION_STRING = None  # Ou forneça a connection string
    
    # Cria producer
    producer = EventHubProducer(
        event_hub_namespace=EVENT_HUB_NAMESPACE,
        event_hub_name=EVENT_HUB_NAME,
        connection_string=CONNECTION_STRING
    )
    
    try:
        # Envia transação única
        transaction = generate_sample_transaction()
        await producer.send_transaction(transaction)
        
        # Envia lote
        transactions = [generate_sample_transaction() for _ in range(10)]
        await producer.send_batch(transactions)
        
    finally:
        producer.close()


if __name__ == "__main__":
    asyncio.run(main())

