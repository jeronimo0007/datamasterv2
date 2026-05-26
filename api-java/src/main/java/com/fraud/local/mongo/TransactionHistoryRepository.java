package com.fraud.local.mongo;

import org.springframework.context.annotation.Profile;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

@Repository
@Profile("local")
public interface TransactionHistoryRepository
        extends MongoRepository<TransactionHistoryDocument, String> {

    long countByCosmosSyncStatus(String cosmosSyncStatus);
}
