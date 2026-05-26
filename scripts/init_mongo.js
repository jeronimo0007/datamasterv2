// Inicialização MongoDB — perfis batch (dataprep histórico)
db = db.getSiblingDB('fraud_detection');

db.createCollection('user_profiles');
db.user_profiles.createIndex({ user_id: 1 }, { unique: true });
db.user_profiles.createIndex({ updated_at: -1 });

db.createCollection('batch_runs');
db.batch_runs.createIndex({ started_at: -1 });

db.createCollection('transaction_history');
db.transaction_history.createIndex({ transaction_id: 1 }, { unique: true });
db.transaction_history.createIndex({ timestamp: -1 });
db.transaction_history.createIndex({ cosmos_sync_status: 1 });

print('MongoDB fraud_detection: user_profiles, batch_runs e transaction_history prontas');
