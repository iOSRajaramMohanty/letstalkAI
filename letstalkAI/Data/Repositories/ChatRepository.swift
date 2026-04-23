//
//  ChatRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation
//

import Foundation

final class ChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let messageMapper: ChatMessageMapper
    
    init(databaseManager: DatabaseManager, messageMapper: ChatMessageMapper) {
        self.databaseManager = databaseManager
        self.messageMapper = messageMapper
    }
    
    func saveMessage(_ message: ChatMessage, sessionId: String) async throws {
        let dto = messageMapper.toDTO(message, sessionId: sessionId)
        try databaseManager.saveMessage(dto)
    }
    
    func getMessages(for sessionId: String) async throws -> [ChatMessage] {
        let dtos = try databaseManager.getMessages(for: sessionId)
        return dtos.map { messageMapper.toDomain($0) }
    }
    
    func deleteMessages(for sessionId: String) async throws {
        try databaseManager.deleteMessages(for: sessionId)
    }
}
