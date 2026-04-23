//
//  ChatMessageMapper.swift
//  letstalkAI
//
//  Maps between Domain entities and DTOs
//

import Foundation

final class ChatMessageMapper: @unchecked Sendable {
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    func toDTO(_ message: ChatMessage, sessionId: String) -> ChatMessageDTO {
        var sourcesJSON: String? = nil
        
        if let sources = message.sources, !sources.isEmpty {
            if let data = try? jsonEncoder.encode(sources) {
                sourcesJSON = String(data: data, encoding: .utf8)
            }
        }
        
        return ChatMessageDTO(
            id: message.id.uuidString,
            sessionId: sessionId,
            text: message.text,
            isUser: message.isUser,
            timestamp: message.timestamp,
            sourcesJSON: sourcesJSON
        )
    }
    
    func toDomain(_ dto: ChatMessageDTO) -> ChatMessage {
        var sources: [WebSearchResult]? = nil
        
        if let sourcesJSON = dto.sourcesJSON,
           let data = sourcesJSON.data(using: .utf8) {
            sources = try? jsonDecoder.decode([WebSearchResult].self, from: data)
        }
        
        return ChatMessage(
            id: UUID(uuidString: dto.id) ?? UUID(),
            text: dto.text,
            isUser: dto.isUser,
            timestamp: dto.timestamp,
            sources: sources
        )
    }
}
