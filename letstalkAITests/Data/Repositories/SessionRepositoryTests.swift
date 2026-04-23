//
//  SessionRepositoryTests.swift
//  letstalkAITests
//
//  Integration tests for SessionRepository
//

import XCTest
@testable import letstalkAI

final class SessionRepositoryTests: XCTestCase {
    var sut: SessionRepository!
    var databaseManager: DatabaseManager!
    var sessionMapper: ChatSessionMapper!
    
    override func setUp() {
        super.setUp()
        databaseManager = DatabaseManager(inMemory: true)
        sessionMapper = ChatSessionMapper()
        sut = SessionRepository(databaseManager: databaseManager, sessionMapper: sessionMapper)
    }
    
    override func tearDown() {
        sut = nil
        databaseManager = nil
        sessionMapper = nil
        super.tearDown()
    }
    
    func testCreateSession_PersistsSession() async throws {
        let session = ChatSession(title: "Test Session")
        
        let createdSession = try await sut.createSession(session)
        
        let sessions = try await sut.getAllSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, "Test Session")
        XCTAssertEqual(createdSession.id, session.id)
    }
    
    func testGetAllSessions_ReturnsSortedByUpdatedAt() async throws {
        let session1 = ChatSession(title: "First")
        let session2 = ChatSession(title: "Second")
        
        _ = try await sut.createSession(session1)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await sut.createSession(session2)
        
        let sessions = try await sut.getAllSessions()
        
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.first?.title, "Second")
    }
    
    func testGetSession_ReturnsCorrectSession() async throws {
        let session = ChatSession(id: "test-id", title: "Test")
        _ = try await sut.createSession(session)
        
        let fetchedSession = try await sut.getSession(by: "test-id")
        
        XCTAssertNotNil(fetchedSession)
        XCTAssertEqual(fetchedSession?.title, "Test")
    }
    
    func testGetSession_NonExistent_ReturnsNil() async throws {
        let fetchedSession = try await sut.getSession(by: "non-existent")
        
        XCTAssertNil(fetchedSession)
    }
    
    func testDeleteSession_RemovesSession() async throws {
        let session = ChatSession(id: "to-delete", title: "Delete Me")
        _ = try await sut.createSession(session)
        
        try await sut.deleteSession("to-delete")
        
        let sessions = try await sut.getAllSessions()
        XCTAssertTrue(sessions.isEmpty)
    }
    
    func testUpdateSessionTitle_UpdatesTitle() async throws {
        let session = ChatSession(id: "test-id", title: "Old Title")
        _ = try await sut.createSession(session)
        
        let success = try await sut.updateSessionTitle("test-id", title: "New Title")
        
        XCTAssertTrue(success)
        let updated = try await sut.getSession(by: "test-id")
        XCTAssertEqual(updated?.title, "New Title")
    }
    
    func testUpdateSessionWebSearch_UpdatesFlag() async throws {
        var session = ChatSession(id: "test-id", title: "Test")
        session.useWebSearch = false
        _ = try await sut.createSession(session)
        
        try await sut.updateSessionWebSearch("test-id", useWebSearch: true)
        
        let updated = try await sut.getSession(by: "test-id")
        XCTAssertTrue(updated?.useWebSearch ?? false)
    }
    
    func testSaveAndLoadTranscript_PersistsTranscript() async throws {
        let session = ChatSession(id: "test-id", title: "Test")
        _ = try await sut.createSession(session)
        
        let transcript = "{\"messages\": []}"
        try await sut.saveTranscript(transcript, sessionId: "test-id")
        
        let loaded = try await sut.loadTranscript(for: "test-id")
        XCTAssertEqual(loaded, transcript)
    }
}
