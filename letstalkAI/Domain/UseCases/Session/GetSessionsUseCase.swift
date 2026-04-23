//
//  GetSessionsUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol GetSessionsUseCaseProtocol: Sendable {
    func execute() async throws -> [ChatSession]
    func getDisplayedSessions() async throws -> [ChatSession]
    func updateSessionTitle(sessionId: String, title: String, existingSessions: [ChatSession]) async throws -> Bool
    func updateSessionWebSearch(sessionId: String, useWebSearch: Bool) async throws
}

final class GetSessionsUseCase: GetSessionsUseCaseProtocol, @unchecked Sendable {
    private let sessionRepository: SessionRepositoryProtocol
    
    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }
    
    func execute() async throws -> [ChatSession] {
        try await sessionRepository.getAllSessions()
    }
    
    func getDisplayedSessions() async throws -> [ChatSession] {
        let sessions = try await sessionRepository.getAllSessions()
        let chatRepository = await MainActor.run { DependencyContainer.shared.chatRepository }
        
        var displayedSessions: [ChatSession] = []
        for session in sessions {
            let messages = try await chatRepository.getMessages(for: session.id)
            if !messages.isEmpty {
                displayedSessions.append(session)
            }
        }
        
        return displayedSessions
    }
    
    func updateSessionTitle(sessionId: String, title: String, existingSessions: [ChatSession]) async throws -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let hasDuplicate = existingSessions.contains { session in
            session.id != sessionId && session.title.lowercased() == normalizedTitle.lowercased()
        }
        
        if hasDuplicate {
            return false
        }
        
        return try await sessionRepository.updateSessionTitle(sessionId, title: normalizedTitle)
    }
    
    func updateSessionWebSearch(sessionId: String, useWebSearch: Bool) async throws {
        try await sessionRepository.updateSessionWebSearch(sessionId, useWebSearch: useWebSearch)
    }
}
