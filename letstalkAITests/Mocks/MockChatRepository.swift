//
//  MockChatRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockChatRepository: ChatRepositoryProtocol {
    var savedMessages: [ChatMessage] = []
    var messagesBySession: [String: [ChatMessage]] = [:]
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "Test", code: -1)
    
    var saveMessageCalled = false
    var getMessagesCalled = false
    var deleteMessagesCalled = false
    
    func saveMessage(_ message: ChatMessage, sessionId: String) async throws {
        saveMessageCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        savedMessages.append(message)
        
        if messagesBySession[sessionId] == nil {
            messagesBySession[sessionId] = []
        }
        messagesBySession[sessionId]?.append(message)
    }
    
    func getMessages(for sessionId: String) async throws -> [ChatMessage] {
        getMessagesCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return messagesBySession[sessionId] ?? []
    }
    
    func deleteMessages(for sessionId: String) async throws {
        deleteMessagesCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        messagesBySession[sessionId] = nil
    }
    
    func reset() {
        savedMessages = []
        messagesBySession = [:]
        shouldThrowError = false
        saveMessageCalled = false
        getMessagesCalled = false
        deleteMessagesCalled = false
    }
}
