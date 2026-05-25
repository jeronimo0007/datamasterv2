package com.fraud.service;

import com.fraud.model.FraudAlert;
import com.fraud.repository.FraudAlertRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
@Profile("enterprise")
@RequiredArgsConstructor
public class FraudAlertService {
    
    private final FraudAlertRepository fraudAlertRepository;
    
    @Transactional
    public FraudAlert save(FraudAlert alert) {
        return fraudAlertRepository.save(alert);
    }
    
    public Optional<FraudAlert> findById(UUID id) {
        return fraudAlertRepository.findById(id);
    }
    
    public List<FraudAlert> findAll(FraudAlert.AlertStatus status, 
                                    FraudAlert.AlertSeverity severity,
                                    int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Specification<FraudAlert> spec = Specification.where(null);
        
        if (status != null) {
            spec = spec.and((root, query, cb) -> 
                cb.equal(root.get("status"), status));
        }
        
        if (severity != null) {
            spec = spec.and((root, query, cb) -> 
                cb.equal(root.get("severity"), severity));
        }
        
        return fraudAlertRepository.findAll(spec, pageable).getContent();
    }
    
    @Transactional
    public Optional<FraudAlert> reviewAlert(UUID id, FraudAlert.AlertStatus status, String reviewedBy) {
        return findById(id).map(alert -> {
            alert.setStatus(status);
            alert.setReviewedBy(reviewedBy);
            alert.setReviewedAt(LocalDateTime.now());
            return save(alert);
        });
    }
    
    public Map<String, Object> getStatistics() {
        Map<String, Object> stats = new HashMap<>();
        
        long total = fraudAlertRepository.count();
        long pending = fraudAlertRepository.countByStatus(FraudAlert.AlertStatus.PENDING);
        long resolved = fraudAlertRepository.countByStatus(FraudAlert.AlertStatus.RESOLVED);
        long falsePositive = fraudAlertRepository.countByStatus(FraudAlert.AlertStatus.FALSE_POSITIVE);
        
        stats.put("total", total);
        stats.put("pending", pending);
        stats.put("resolved", resolved);
        stats.put("falsePositive", falsePositive);
        stats.put("resolutionRate", total > 0 ? (double) resolved / total : 0.0);
        
        return stats;
    }
}

