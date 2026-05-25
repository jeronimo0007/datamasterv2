package com.fraud.controller;

import com.fraud.model.FraudAlert;
import com.fraud.service.FraudAlertService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@Profile("enterprise")
@RequestMapping("/api/v1/alerts")
@Tag(name = "Fraud Alerts", description = "API para gerenciamento de alertas de fraude")
@RequiredArgsConstructor
public class FraudAlertController {
    
    private final FraudAlertService fraudAlertService;
    
    @GetMapping
    @Operation(summary = "Listar alertas de fraude")
    public ResponseEntity<List<FraudAlert>> getAlerts(
            @RequestParam(required = false) FraudAlert.AlertStatus status,
            @RequestParam(required = false) FraudAlert.AlertSeverity severity,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        List<FraudAlert> alerts = fraudAlertService.findAll(status, severity, page, size);
        return ResponseEntity.ok(alerts);
    }
    
    @GetMapping("/{id}")
    @Operation(summary = "Buscar alerta por ID")
    public ResponseEntity<FraudAlert> getAlert(@PathVariable UUID id) {
        return fraudAlertService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @PutMapping("/{id}/review")
    @Operation(summary = "Revisar alerta de fraude")
    public ResponseEntity<FraudAlert> reviewAlert(
            @PathVariable UUID id,
            @RequestParam FraudAlert.AlertStatus status,
            @RequestParam(required = false) String reviewedBy) {
        return fraudAlertService.reviewAlert(id, status, reviewedBy)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @GetMapping("/stats")
    @Operation(summary = "Estatísticas de alertas")
    public ResponseEntity<Object> getAlertStats() {
        return ResponseEntity.ok(fraudAlertService.getStatistics());
    }
}

