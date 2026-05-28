# Comparativo Detalhado: Azure vs AWS para Detecção de Fraudes

## 1. Streaming de Dados

### Azure: Event Hubs
```python
# Python - Azure Event Hubs
from azure.eventhub import EventHubProducerClient, EventData

producer = EventHubProducerClient.from_connection_string(
    conn_str="Endpoint=sb://{namespace}.servicebus.windows.net/;SharedAccessKeyName={key_name};SharedAccessKey={key}",
    eventhub_name="transactions"
)

with producer:
    event_data_batch = producer.create_batch()
    event_data_batch.add(EventData(json.dumps(transaction)))
    producer.send_batch(event_data_batch)