package com.fraud.email;

public final class FraudRabbitConstants {

    public static final String EXCHANGE = "fraud.events";
    public static final String ROUTING_KEY = "fraud.alert.email";
    public static final String QUEUE = "fraud.alert.email";

    private FraudRabbitConstants() {}
}
