package com.example.messaging.application.services;

import com.example.messaging.application.dtos.MessageRequest;
import com.example.messaging.application.dtos.MessageResponse;
import com.example.messaging.application.ports.MessageServicePort;
import com.example.messaging.domain.models.Message;
import com.example.messaging.domain.models.MessageStatus;
import com.example.messaging.domain.ports.MessageEventPort;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@ApplicationScoped
public class MessageServiceImpl implements MessageServicePort {
    
    private final MessageEventPort messageEventPort;
    
    @Inject
    public MessageServiceImpl(MessageEventPort messageEventPort) {
        this.messageEventPort = messageEventPort;
    }
    
    @Override
    public Uni<MessageResponse> processAndSendMessage(MessageRequest request) {
        // 1. Crear mensaje del dominio
        Message message = Message.builder()
                .id(UUID.randomUUID())
                .content(request.getContent())
                .sender(request.getSender())
                .recipient(request.getRecipient())
                .status(MessageStatus.PENDING)
                .createdAt(LocalDateTime.now())
                .build();
        
        log.info("Processing message with ID: {}", message.getId());
        
        // 2. Enviar mensaje al tópico (paso 1)
        return messageEventPort.publishMessage(message)
                .onItem().transform(unused -> {
                    // 3. Marcar como enviado
                    message.markAsSent();
                    log.info("Message {} sent successfully", message.getId());
                    
                    // 4. Convertir a DTO de respuesta
                    return mapToResponse(message);
                })
                .onItem().call(response -> {
                    // 5. Enviar respuesta al tópico (paso 2)
                    log.info("Sending response to topic for message {}", message.getId());
                    return messageEventPort.publishResponse(message)
                            .onFailure().recoverWithItem(() -> {
                                log.warn("Failed to send response to topic for message {}", message.getId());
                                return null;
                            });
                })
                .onFailure().recoverWithItem(throwable -> {
                    log.error("Failed to process message: {}", throwable.getMessage());
                    message.markAsFailed();
                    return mapToResponse(message);
                });
    }
    
    private MessageResponse mapToResponse(Message message) {
        return MessageResponse.builder()
                .messageId(message.getId())
                .status(message.getStatus().name())
                .content(message.getContent())
                .sender(message.getSender())
                .recipient(message.getRecipient())
                .createdAt(message.getCreatedAt())
                .sentAt(message.getSentAt())
                .build();
    }
}