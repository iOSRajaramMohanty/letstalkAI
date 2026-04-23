//
//  GenerateTitleUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol GenerateTitleUseCaseProtocol: Sendable {
    func execute(from response: String, sessionId: String) async throws -> String
}

final class GenerateTitleUseCase: GenerateTitleUseCaseProtocol, @unchecked Sendable {
    private let llmRepository: LLMRepositoryProtocol
    
    init(llmRepository: LLMRepositoryProtocol) {
        self.llmRepository = llmRepository
    }
    
    func execute(from response: String, sessionId: String) async throws -> String {
        try await llmRepository.generateTitle(from: response, sessionId: sessionId)
    }
}
