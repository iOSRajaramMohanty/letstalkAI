//
//  MockLLMRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockLLMRepository: LLMRepositoryProtocol {
    var mockResponse: String = "Test response"
    var mockTitle: String = "Test Title"
    var shouldThrowError = false
    var errorToThrow: LLMError = .generationFailed("Test error")
    var streamDelay: UInt64 = 0
    
    var generateResponseCalled = false
    var generateTitleCalled = false
    var getOrCreateSessionCalled = false
    
    private var _isResponding = false
    var isResponding: Bool { _isResponding }
    
    func getOrCreateSession(sessionId: String) async {
        getOrCreateSessionCalled = true
    }
    
    func generateResponse(prompt: String, sessionId: String) -> AsyncThrowingStream<String, Error> {
        generateResponseCalled = true
        
        return AsyncThrowingStream { continuation in
            Task {
                if self.shouldThrowError {
                    continuation.finish(throwing: self.errorToThrow)
                    return
                }
                
                self._isResponding = true
                
                let words = self.mockResponse.split(separator: " ")
                var currentResponse = ""
                
                for word in words {
                    if self.streamDelay > 0 {
                        try? await Task.sleep(nanoseconds: self.streamDelay)
                    }
                    
                    currentResponse += (currentResponse.isEmpty ? "" : " ") + word
                    continuation.yield(currentResponse)
                }
                
                self._isResponding = false
                continuation.finish()
            }
        }
    }
    
    func generateTitle(from response: String, sessionId: String) async throws -> String {
        generateTitleCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockTitle
    }
    
    func saveTranscript(sessionId: String) async throws -> String? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return "{\"transcript\": []}"
    }
    
    func loadTranscript(_ transcriptJSON: String, sessionId: String) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func reset() {
        mockResponse = "Test response"
        mockTitle = "Test Title"
        shouldThrowError = false
        streamDelay = 0
        generateResponseCalled = false
        generateTitleCalled = false
        getOrCreateSessionCalled = false
    }
}
