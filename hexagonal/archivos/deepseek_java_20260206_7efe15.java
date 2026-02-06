package com.example.messaging.domain.models;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class Message {
    private UUID id;
    private String content;
    private String sender;
    private String recipient;
    private MessageStatus status;
    private LocalDateTime createdAt;
    private LocalDateTime sentAt;
    
    public Message markAsSent() {
        this.status = MessageStatus.SENT;
        this.sentAt = LocalDateTime.now();
        return this;
    }
    
    public Message markAsFailed() {
        this.status = MessageStatus.FAILED;
        return this;
    }
}