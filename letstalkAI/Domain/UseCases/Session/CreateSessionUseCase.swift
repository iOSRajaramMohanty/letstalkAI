//
//  CreateSessionUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol CreateSessionUseCaseProtocol: Sendable {
    func execute(title: String) async throws -> SessionCreationResult
    func getOrCreateEmptySession(existingSessions: [ChatSession]) async throws -> ChatSession
}

final class CreateSessionUseCase: CreateSessionUseCaseProtocol, @unchecked Sendable {
    private let sessionRepository: SessionRepositoryProtocol
    
    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }
    
    func execute(title: String) async throws -> SessionCreationResult {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let existingSessions = try await sessionRepository.getAllSessions()
        
        if normalizedTitle.isEmpty {
            if existingSessions.contains(where: { $0.title.isEmpty }) {
                return .duplicateUntitled
            }
        } else {
            if existingSessions.contains(where: { $0.title.lowercased() == normalizedTitle.lowercased() }) {
                return .duplicateTitle
            }
        }
        
        let newSession = ChatSession(title: normalizedTitle)
        
        do {
            let savedSession = try await sessionRepository.createSession(newSession)
            return .success(savedSession)
        } catch {
            return .databaseError
        }
    }
    
    func getOrCreateEmptySession(existingSessions: [ChatSession]) async throws -> ChatSession {
        let chatRepository = await MainActor.run { DependencyContainer.shared.chatRepository }
        
        for session in existingSessions {
            let messages = try await chatRepository.getMessages(for: session.id)
            if messages.isEmpty {
                return session
            }
        }
        
        let newSession = ChatSession(title: "")
        return try await sessionRepository.createSession(newSession)
    }
}
