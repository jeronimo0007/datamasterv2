"""
Consumer para receber transações do Azure Event Hubs
"""
import asyncio
import json
from typing import Dict, Any
from azure.eventhub import EventHubConsumerClient
from azure.eventhub.checkpointstoreblob import BlobCheckpointStore
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventHubConsumer:
    """Classe para consumir eventos do Azure Event Hubs"""
    
    def __init__(self, event_hub_namespace: str, event_hub_name: str,
                 consumer_group: str, storage_account: str, container_name: str,
                 connection_string: str = None):
        """
        Inicializa o consumer
        
        Args:
            event_hub_namespace: Namespace do Event Hub
            event_hub_name: Nome do Event Hub
            consumer_group: Grupo de consumidores
            storage_account: Conta de armazenamento para checkpoint
            container_name: Container para checkpoint
            connection_string: String de conexão (opcional)
        """
        self.event_hub_name = event_hub_name
        self.consumer_group = consumer_group
        
        fully_qualified_namespace = f"{event_hub_namespace}.servicebus.windows.net"
        
        # Configura checkpoint store
        if connection_string:
            checkpoint_store = BlobCheckpointStore.from_connection_string(
                conn_str=connection_string,
                container_name=container_name
            )
            self.consumer = EventHubConsumerClient.from_connection_string(
                conn_str=connection_string,
                consumer_group=consumer_group,
                eventhub_name=event_hub_name,
                checkpoint_store=checkpoint_store
            )
        else:
            # Usa Managed Identity
            blob_service_client = BlobServiceClient(
                account_url=f"https://{storage_account}.blob.core.windows.net",
                credential=DefaultAzureCredential()
            )
            checkpoint_store = BlobCheckpointStore(
                blob_service_client=blob_service_client,
                container_name=container_name
            )
            
            self.consumer = EventHubConsumerClient(
                fully_qualified_namespace=fully_qualified_namespace,
                eventhub_name=event_hub_name,
                consumer_group=consumer_group,
                credential=DefaultAzureCredential(),
                checkpoint_store=checkpoint_store
            )
    
    async def process_event(self, partition_context, event):
        """
        Processa um evento recebido
        
        Args:
            partition_context: Contexto da partição
            event: Evento recebido
        """
        try:
            # Deserializa JSON
            transaction = json.loads(event.body_as_str(encoding='UTF-8'))
            
            logger.info(f"Transação recebida: {transaction.get('transaction_id')}")
            
            # Aqui você processaria a transação
            # Exemplo: salvar no Data Lake, verificar fraude, etc.
            await self.handle_transaction(transaction)
            
            # Atualiza checkpoint
            await partition_context.update_checkpoint(event)
            
        except Exception as e:
            logger.error(f"Erro ao processar evento: {e}")
            # Em produção, você pode querer enviar para uma dead letter queue
    
    async def handle_transaction(self, transaction: Dict[str, Any]) -> None:
        """
        Manipula uma transação recebida
        
        Args:
            transaction: Dados da transação
        """
        # Implementar lógica de processamento
        # Exemplo: salvar no Data Lake, verificar fraude, etc.
        logger.info(f"Processando transação: {transaction.get('transaction_id')}")
    
    async def start_consuming(self):
        """Inicia o consumo de eventos"""
        logger.info(f"Iniciando consumo do Event Hub: {self.event_hub_name}")
        
        async with self.consumer:
            await self.consumer.receive(
                on_event=self.process_event,
                starting_position="-1"  # Começa do início
            )


async def main():
    """Exemplo de uso"""
    # Configuração
    EVENT_HUB_NAMESPACE = "fraud-events"
    EVENT_HUB_NAME = "transactions"
    CONSUMER_GROUP = "$Default"
    STORAGE_ACCOUNT = "fraudstorage"
    CONTAINER_NAME = "checkpoints"
    
    # Cria consumer
    consumer = EventHubConsumer(
        event_hub_namespace=EVENT_HUB_NAMESPACE,
        event_hub_name=EVENT_HUB_NAME,
        consumer_group=CONSUMER_GROUP,
        storage_account=STORAGE_ACCOUNT,
        container_name=CONTAINER_NAME
    )
    
    try:
        await consumer.start_consuming()
    except KeyboardInterrupt:
        logger.info("Parando consumer...")


if __name__ == "__main__":
    asyncio.run(main())

