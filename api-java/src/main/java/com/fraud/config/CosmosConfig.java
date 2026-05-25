package com.fraud.config;

import com.azure.cosmos.CosmosClient;
import com.azure.cosmos.CosmosClientBuilder;
import com.azure.identity.DefaultAzureCredentialBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
@Profile("enterprise")
@Slf4j
public class CosmosConfig {
    
    @Value("${azure.cosmos.endpoint:}")
    private String cosmosEndpoint;
    
    @Bean
    public CosmosClient cosmosClient() {
        if (cosmosEndpoint == null || cosmosEndpoint.isEmpty()) {
            log.warn("Cosmos DB endpoint não configurado. Usando cliente mock para desenvolvimento local.");
            return null; // Em produção, sempre configurar
        }
        
        return new CosmosClientBuilder()
                .endpoint(cosmosEndpoint)
                .credential(new DefaultAzureCredentialBuilder().build())
                .buildClient();
    }
}

