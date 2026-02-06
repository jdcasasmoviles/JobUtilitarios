package com.example.messaging.infrastructure.input.rest;

import com.example.messaging.application.dtos.MessageRequest;
import com.example.messaging.application.dtos.MessageResponse;
import com.example.messaging.application.ports.MessageServicePort;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Path("/api/v1/messages")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MessageResource {
    
    private final MessageServicePort messageService;
    
    @Inject
    public MessageResource(MessageServicePort messageService) {
        this.messageService = messageService;
    }
    
    @POST
    @Path("/send")
    public Uni<Response> sendMessage(@Valid MessageRequest request) {
        log.info("Received message request from {} to {}", request.getSender(), request.getRecipient());
        
        return messageService.processAndSendMessage(request)
                .onItem().transform(response -> {
                    if ("SENT".equals(response.getStatus())) {
                        // Status 200 si se envió exitosamente
                        return Response.ok(response).build();
                    } else {
                        // Status 500 si falló
                        return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                                .entity(response)
                                .build();
                    }
                })
                .onFailure().recoverWithItem(throwable -> {
                    log.error("Error processing message: {}", throwable.getMessage());
                    return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                            .entity("Error processing message: " + throwable.getMessage())
                            .build();
                });
    }
}