package com.example.messaging.domain.ports;

import com.example.messaging.domain.models.Message;
import io.smallrye.mutiny.Uni;

public interface MessageEventPort {
    Uni<Void> publishMessage(Message message);
    Uni<Void> publishResponse(Message message);
}