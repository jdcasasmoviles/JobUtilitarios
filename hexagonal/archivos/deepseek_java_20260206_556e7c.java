package com.example.messaging.application.ports;

import com.example.messaging.application.dtos.MessageRequest;
import com.example.messaging.application.dtos.MessageResponse;
import io.smallrye.mutiny.Uni;

public interface MessageServicePort {
    Uni<MessageResponse> processAndSendMessage(MessageRequest request);
}