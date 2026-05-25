package com.fraud.repository;

import com.fraud.model.FraudAlert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
@Profile("enterprise")
public interface FraudAlertRepository extends JpaRepository<FraudAlert, UUID>, 
                                              JpaSpecificationExecutor<FraudAlert> {
    
    long countByStatus(FraudAlert.AlertStatus status);
}

