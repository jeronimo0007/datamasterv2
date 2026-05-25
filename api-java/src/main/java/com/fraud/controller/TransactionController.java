package com.fraud.controller;

import com.fraud.model.Transaction;
import com.fraud.service.FraudDetectionService;
import com.fraud.service.TransactionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@Profile("enterprise")
@RequestMapping("/api/v1/transactions")
@Tag(name = "Transactions", description = "API para gerenciamento de transações bancárias")
@RequiredArgsConstructor
public class TransactionController {
    
    private final TransactionService transactionService;
    private final FraudDetectionService fraudDetectionService;
    
    @PostMapping
    @Operation(summary = "Criar nova transação e verificar fraude")
    public ResponseEntity<Transaction> createTransaction(@Valid @RequestBody Transaction transaction) {
        Transaction saved = transactionService.save(transaction);
        
        // Verificar fraude de forma assíncrona
        fraudDetectionService.detectFraudAsync(saved);
        
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }
    
    @GetMapping("/{id}")
    @Operation(summary = "Buscar transação por ID")
    public ResponseEntity<Transaction> getTransaction(@PathVariable UUID id) {
        return transactionService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @GetMapping
    @Operation(summary = "Listar transações com filtros")
    public ResponseEntity<List<Transaction>> getTransactions(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) Boolean isFraud,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        List<Transaction> transactions = transactionService.findAll(userId, isFraud, page, size);
        return ResponseEntity.ok(transactions);
    }
    
    @GetMapping("/{id}/fraud-check")
    @Operation(summary = "Verificar fraude em transação específica")
    public ResponseEntity<Transaction> checkFraud(@PathVariable UUID id) {
        return transactionService.findById(id)
                .map(transaction -> {
                    fraudDetectionService.detectFraud(transaction);
                    return ResponseEntity.ok(transaction);
                })
                .orElse(ResponseEntity.notFound().build());
    }
}

