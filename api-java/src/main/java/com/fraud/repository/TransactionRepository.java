package com.fraud.repository;

import com.fraud.model.Transaction;
import org.springframework.context.annotation.Profile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
@Profile("enterprise")
public interface TransactionRepository extends JpaRepository<Transaction, UUID>, 
                                              JpaSpecificationExecutor<Transaction> {
    
    Optional<Transaction> findByTransactionId(String transactionId);
}

