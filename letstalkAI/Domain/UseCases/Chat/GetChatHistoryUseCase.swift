//
//  GetChatHistoryUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol GetChatHistoryUseCaseProtocol: Sendable {
    func execute(sessionId: String) async throws -> [ChatMessage]
}

final class GetChatHistoryUseCase: GetChatHistoryUseCaseProtocol, @unchecked Sendable {
    private let chatRepository: ChatRepositoryProtocol
    
    init(chatRepository: ChatRepositoryProtocol) {
        self.chatRepository = chatRepository
    }
    
    func execute(sessionId: String) async throws -> [ChatMessage] {
        try await chatRepository.getMessages(for: sessionId)
    }
}
