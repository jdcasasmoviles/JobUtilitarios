package com.example.messaging.infrastructure.input.rest.mappers;

import com.example.messaging.application.dtos.MessageRequest;
import com.example.messaging.application.dtos.MessageResponse;
import com.example.messaging.domain.models.Message;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.factory.Mappers;

@Mapper(componentModel = "cdi")
public interface MessageMapper {
    MessageMapper INSTANCE = Mappers.getMapper(MessageMapper.class);
    
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "status", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "sentAt", ignore = true)
    Message toDomain(MessageRequest request);
    
    MessageResponse toResponse(Message message);
}