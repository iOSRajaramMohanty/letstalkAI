//
//  DeleteSessionUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol DeleteSessionUseCaseProtocol: Sendable {
    func execute(sessionId: String) async throws
    func executeMultiple(sessionIds: Set<String>) async throws
}

final class DeleteSessionUseCase: DeleteSessionUseCaseProtocol, @unchecked Sendable {
    private let sessionRepository: SessionRepositoryProtocol
    
    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }
    
    func execute(sessionId: String) async throws {
        try await sessionRepository.deleteSession(sessionId)
    }
    
    func executeMultiple(sessionIds: Set<String>) async throws {
        try await sessionRepository.deleteSessions(sessionIds)
    }
}
