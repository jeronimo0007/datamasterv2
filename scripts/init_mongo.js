// Inicialização MongoDB — perfis batch (dataprep histórico)
db = db.getSiblingDB('fraud_detection');

db.createCollection('user_profiles');
db.user_profiles.createIndex({ user_id: 1 }, { unique: true });
db.user_profiles.createIndex({ updated_at: -1 });

db.createCollection('batch_runs');
db.batch_runs.createIndex({ started_at: -1 });

print('MongoDB fraud_detection: coleções user_profiles e batch_runs prontas');
