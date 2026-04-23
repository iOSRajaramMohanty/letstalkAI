//
//  ChatSessionMapper.swift
//  letstalkAI
//
//  Maps between Domain entities and DTOs
//

import Foundation

final class ChatSessionMapper: Sendable {
    func toDTO(_ session: ChatSession) -> ChatSessionDTO {
        ChatSessionDTO(
            id: session.id,
            title: session.title,
            collectionName: session.collectionName,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            useWebSearch: session.useWebSearch,
            transcriptJSON: nil
        )
    }
    
    func toDomain(_ dto: ChatSessionDTO) -> ChatSession {
        ChatSession(
            id: dto.id,
            title: dto.title,
            collectionName: dto.collectionName,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            useWebSearch: dto.useWebSearch
        )
    }
}
