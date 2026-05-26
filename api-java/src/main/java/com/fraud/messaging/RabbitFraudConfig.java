package com.fraud.messaging;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "fraud.email.enabled", havingValue = "true")
public class RabbitFraudConfig {

    @Bean
    TopicExchange fraudEventsExchange() {
        return new TopicExchange(FraudRabbitConstants.EXCHANGE, true, false);
    }

    @Bean
    Queue fraudAlertEmailQueue() {
        return QueueBuilder.durable(FraudRabbitConstants.QUEUE).build();
    }

    @Bean
    Binding fraudAlertEmailBinding(Queue fraudAlertEmailQueue, TopicExchange fraudEventsExchange) {
        return BindingBuilder.bind(fraudAlertEmailQueue)
                .to(fraudEventsExchange)
                .with(FraudRabbitConstants.ROUTING_KEY);
    }

    @Bean
    MessageConverter jacksonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}
