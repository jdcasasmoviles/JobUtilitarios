package com.example.messaging.application.dtos;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MessageRequest {
    @NotBlank(message = "Content is required")
    private String content;
    
    @NotBlank(message = "Sender is required")
    private String sender;
    
    @JsonProperty("to")
    @NotBlank(message = "Recipient is required")
    private String recipient;
}