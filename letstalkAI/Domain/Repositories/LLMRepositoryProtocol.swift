//
//  LLMRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol LLMRepositoryProtocol: Sendable {
    func generateResponse(prompt: String, sessionId: String) -> AsyncThrowingStream<String, Error>
    func generateTitle(from response: String, sessionId: String) async throws -> String
    func getOrCreateSession(sessionId: String) async
    func saveTranscript(sessionId: String) async throws -> String?
    func loadTranscript(_ transcriptJSON: String, sessionId: String) async throws
    var isResponding: Bool { get }
}

enum LLMError: Error, LocalizedError, Sendable, Equatable {
    case contextWindowExceeded
    case rateLimited
    case safetyGuardrail
    case generationFailed(String)
    case sessionNotFound
    
    var errorDescription: String? {
        switch self {
        case .contextWindowExceeded:
            return "The conversation has exceeded the context window. Starting a new session."
        case .rateLimited:
            return "The on-device model is currently rate limited. Please wait a moment and try again."
        case .safetyGuardrail:
            return "Sorry, I cannot provide a response to that query due to safety guidelines. Please try rephrasing your question."
        case .generationFailed(let message):
            return "An error occurred while processing your request: \(message)"
        case .sessionNotFound:
            return "Chat session not found."
        }
    }
}
