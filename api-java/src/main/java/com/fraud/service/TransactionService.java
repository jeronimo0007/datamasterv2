package com.fraud.service;

import com.fraud.model.Transaction;
import com.fraud.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@Profile("enterprise")
@RequiredArgsConstructor
public class TransactionService {
    
    private final TransactionRepository transactionRepository;
    
    @Transactional
    public Transaction save(Transaction transaction) {
        return transactionRepository.save(transaction);
    }
    
    public Optional<Transaction> findById(UUID id) {
        return transactionRepository.findById(id);
    }
    
    public Optional<Transaction> findByTransactionId(String transactionId) {
        return transactionRepository.findByTransactionId(transactionId);
    }
    
    public List<Transaction> findAll(String userId, Boolean isFraud, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Specification<Transaction> spec = Specification.where(null);
        
        if (userId != null) {
            spec = spec.and((root, query, cb) -> 
                cb.equal(root.get("userId"), userId));
        }
        
        if (isFraud != null) {
            spec = spec.and((root, query, cb) -> 
                cb.equal(root.get("isFraud"), isFraud));
        }
        
        return transactionRepository.findAll(spec, pageable).getContent();
    }
    
    @Transactional
    public Transaction updateFraudStatus(String transactionId, Boolean isFraud, 
                                        Double fraudScore, String fraudReason) {
        return findByTransactionId(transactionId)
                .map(transaction -> {
                    transaction.setIsFraud(isFraud);
                    transaction.setFraudScore(fraudScore);
                    transaction.setFraudReason(fraudReason);
                    return save(transaction);
                })
                .orElseThrow(() -> new RuntimeException("Transaction not found: " + transactionId));
    }
}

