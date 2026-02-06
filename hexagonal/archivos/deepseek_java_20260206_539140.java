package com.example.messaging.infrastructure.output.messaging;

import com.example.messaging.domain.models.Message;
import com.example.messaging.domain.ports.MessageEventPort;
import io.smallrye.mutiny.Uni;
import io.smallrye.reactive.messaging.kafka.Record;
import jakarta.enterprise.context.ApplicationScoped;
import lombok.extern.slf4j.Slf4j;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;

@Slf4j
@ApplicationScoped
public class KafkaMessageAdapter implements MessageEventPort {
    
    @Channel("messages-out")
    Emitter<Record<String, String>> messageEmitter;
    
    @Channel("responses-out")
    Emitter<Record<String, String>> responseEmitter;
    
    @Override
    public Uni<Void> publishMessage(Message message) {
        return Uni.createFrom().item(() -> {
            String key = message.getId().toString();
            String value = String.format(
                "{\"id\":\"%s\",\"content\":\"%s\",\"sender\":\"%s\",\"recipient\":\"%s\"}",
                message.getId(),
                message.getContent(),
                message.getSender(),
                message.getRecipient()
            );
            
            log.info("Sending message to Kafka topic. Key: {}, Value: {}", key, value);
            messageEmitter.send(Record.of(key, value));
            return null;
        });
    }
    
    @Override
    public Uni<Void> publishResponse(Message message) {
        return Uni.createFrom().item(() -> {
            String key = message.getId().toString();
            String value = String.format(
                "{\"id\":\"%s\",\"status\":\"%s\",\"sentAt\":\"%s\"}",
                message.getId(),
                message.getStatus(),
                message.getSentAt()
            );
            
            log.info("Sending response to Kafka topic. Key: {}, Value: {}", key, value);
            responseEmitter.send(Record.of(key, value));
            return null;
        });
    }
}