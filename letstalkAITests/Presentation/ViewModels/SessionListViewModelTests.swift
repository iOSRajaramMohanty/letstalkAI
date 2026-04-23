//
//  SessionListViewModelTests.swift
//  letstalkAITests
//
//  Unit tests for SessionListViewModel
//

import XCTest
@testable import letstalkAI

@MainActor
final class SessionListViewModelTests: XCTestCase {
    var sut: SessionListViewModel!
    var mockGetSessionsUseCase: MockGetSessionsUseCase!
    var mockCreateSessionUseCase: MockCreateSessionUseCase!
    var mockDeleteSessionUseCase: MockDeleteSessionUseCase!
    
    override func setUp() {
        super.setUp()
        mockGetSessionsUseCase = MockGetSessionsUseCase()
        mockCreateSessionUseCase = MockCreateSessionUseCase()
        mockDeleteSessionUseCase = MockDeleteSessionUseCase()
        
        sut = SessionListViewModel(
            getSessionsUseCase: mockGetSessionsUseCase,
            createSessionUseCase: mockCreateSessionUseCase,
            deleteSessionUseCase: mockDeleteSessionUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        mockGetSessionsUseCase = nil
        mockCreateSessionUseCase = nil
        mockDeleteSessionUseCase = nil
        super.tearDown()
    }
    
    func testSelectSession_SetsSelectedSession() {
        let session = ChatSession(title: "Test Session")
        
        sut.selectSession(session)
        
        XCTAssertEqual(sut.selectedSession?.id, session.id)
    }
    
    func testToggleEditMode_TogglesEditMode() {
        XCTAssertFalse(sut.isEditMode)
        
        sut.toggleEditMode()
        
        XCTAssertTrue(sut.isEditMode)
        
        sut.toggleEditMode()
        
        XCTAssertFalse(sut.isEditMode)
    }
    
    func testToggleEditMode_ClearsSelectionWhenDisabling() {
        sut.isEditMode = true
        sut.selectedSessionIds = ["1", "2", "3"]
        
        sut.toggleEditMode()
        
        XCTAssertTrue(sut.selectedSessionIds.isEmpty)
    }
    
    func testToggleSelection_AddsAndRemovesSelection() {
        sut.toggleSelection("1")
        XCTAssertTrue(sut.selectedSessionIds.contains("1"))
        
        sut.toggleSelection("1")
        XCTAssertFalse(sut.selectedSessionIds.contains("1"))
    }
    
    func testSelectAll_SelectsAllSessions() {
        let sessions = [
            ChatSession(id: "1", title: "Session 1"),
            ChatSession(id: "2", title: "Session 2"),
            ChatSession(id: "3", title: "Session 3")
        ]
        sut.sessions = sessions
        
        sut.selectAll()
        
        XCTAssertEqual(sut.selectedSessionIds.count, 3)
        XCTAssertTrue(sut.selectedSessionIds.contains("1"))
        XCTAssertTrue(sut.selectedSessionIds.contains("2"))
        XCTAssertTrue(sut.selectedSessionIds.contains("3"))
    }
    
    func testDeselectAll_ClearsAllSelections() {
        sut.selectedSessionIds = ["1", "2", "3"]
        
        sut.deselectAll()
        
        XCTAssertTrue(sut.selectedSessionIds.isEmpty)
    }
    
    func testDeleteSession_RemovesFromList() async {
        let session = ChatSession(id: "1", title: "Test")
        sut.sessions = [session]
        sut.selectedSession = session
        
        await sut.deleteSession(session)
        
        XCTAssertTrue(mockDeleteSessionUseCase.executeCalled)
        XCTAssertTrue(sut.sessions.isEmpty)
        XCTAssertNil(sut.selectedSession)
    }
}

final class MockGetSessionsUseCase: GetSessionsUseCaseProtocol {
    var mockSessions: [ChatSession] = []
    
    func execute() async throws -> [ChatSession] {
        return mockSessions
    }
    
    func getDisplayedSessions() async throws -> [ChatSession] {
        return mockSessions
    }
    
    func updateSessionTitle(sessionId: String, title: String, existingSessions: [ChatSession]) async throws -> Bool {
        return true
    }
    
    func updateSessionWebSearch(sessionId: String, useWebSearch: Bool) async throws {}
}

final class MockCreateSessionUseCase: CreateSessionUseCaseProtocol {
    var mockSession = ChatSession(title: "New Session")
    
    func execute(title: String) async throws -> SessionCreationResult {
        return .success(mockSession)
    }
    
    func getOrCreateEmptySession(existingSessions: [ChatSession]) async throws -> ChatSession {
        return mockSession
    }
}

final class MockDeleteSessionUseCase: DeleteSessionUseCaseProtocol {
    var executeCalled = false
    
    func execute(sessionId: String) async throws {
        executeCalled = true
    }
    
    func executeMultiple(sessionIds: Set<String>) async throws {
        executeCalled = true
    }
}
