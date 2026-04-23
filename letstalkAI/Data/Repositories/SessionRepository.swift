//
//  SessionRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation
//

import Foundation

final class SessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let sessionMapper: ChatSessionMapper
    
    init(databaseManager: DatabaseManager, sessionMapper: ChatSessionMapper) {
        self.databaseManager = databaseManager
        self.sessionMapper = sessionMapper
    }
    
    func createSession(_ session: ChatSession) async throws -> ChatSession {
        let dto = sessionMapper.toDTO(session)
        let savedDTO = try databaseManager.createChatSession(dto)
        return sessionMapper.toDomain(savedDTO)
    }
    
    func getAllSessions() async throws -> [ChatSession] {
        let dtos = try databaseManager.getAllChatSessions()
        return dtos.map { sessionMapper.toDomain($0) }
    }
    
    func getSession(by id: String) async throws -> ChatSession? {
        guard let dto = try databaseManager.getChatSession(by: id) else {
            return nil
        }
        return sessionMapper.toDomain(dto)
    }
    
    func updateSession(_ session: ChatSession) async throws {
        let dto = sessionMapper.toDTO(session)
        try databaseManager.updateChatSession(dto)
    }
    
    func deleteSession(_ sessionId: String) async throws {
        try databaseManager.deleteChatSession(sessionId)
    }
    
    func deleteSessions(_ sessionIds: Set<String>) async throws {
        try databaseManager.deleteChatSessions(sessionIds)
    }
    
    func updateSessionTitle(_ sessionId: String, title: String) async throws -> Bool {
        do {
            try databaseManager.updateChatSessionTitle(sessionId, title: title)
            return true
        } catch {
            return false
        }
    }
    
    func updateSessionWebSearch(_ sessionId: String, useWebSearch: Bool) async throws {
        try databaseManager.updateChatSessionWebSearch(sessionId, useWebSearch: useWebSearch)
    }
    
    func saveTranscript(_ transcriptJSON: String, sessionId: String) async throws {
        try databaseManager.saveTranscriptJSON(transcriptJSON, sessionId: sessionId)
    }
    
    func loadTranscript(for sessionId: String) async throws -> String? {
        try databaseManager.loadTranscriptJSON(for: sessionId)
    }
}
