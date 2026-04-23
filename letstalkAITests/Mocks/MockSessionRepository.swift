//
//  MockSessionRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockSessionRepository: SessionRepositoryProtocol {
    var sessions: [ChatSession] = []
    var transcripts: [String: String] = [:]
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "Test", code: -1)
    
    var createSessionCalled = false
    var getAllSessionsCalled = false
    var deleteSessionCalled = false
    var updateTitleCalled = false
    
    func createSession(_ session: ChatSession) async throws -> ChatSession {
        createSessionCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        sessions.append(session)
        return session
    }
    
    func getAllSessions() async throws -> [ChatSession] {
        getAllSessionsCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return sessions
    }
    
    func getSession(by id: String) async throws -> ChatSession? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return sessions.first { $0.id == id }
    }
    
    func updateSession(_ session: ChatSession) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }
    
    func deleteSession(_ sessionId: String) async throws {
        deleteSessionCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        sessions.removeAll { $0.id == sessionId }
    }
    
    func deleteSessions(_ sessionIds: Set<String>) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        sessions.removeAll { sessionIds.contains($0.id) }
    }
    
    func updateSessionTitle(_ sessionId: String, title: String) async throws -> Bool {
        updateTitleCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].title = title
            return true
        }
        return false
    }
    
    func updateSessionWebSearch(_ sessionId: String, useWebSearch: Bool) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].useWebSearch = useWebSearch
        }
    }
    
    func saveTranscript(_ transcriptJSON: String, sessionId: String) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        transcripts[sessionId] = transcriptJSON
    }
    
    func loadTranscript(for sessionId: String) async throws -> String? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return transcripts[sessionId]
    }
    
    func reset() {
        sessions = []
        transcripts = [:]
        shouldThrowError = false
        createSessionCalled = false
        getAllSessionsCalled = false
        deleteSessionCalled = false
        updateTitleCalled = false
    }
}
