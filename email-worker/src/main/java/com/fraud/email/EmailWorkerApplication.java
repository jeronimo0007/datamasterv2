package com.fraud.email;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.mail.MailSenderAutoConfiguration;

@SpringBootApplication(exclude = MailSenderAutoConfiguration.class)
public class EmailWorkerApplication {

    public static void main(String[] args) {
        SpringApplication.run(EmailWorkerApplication.class, args);
    }
}
