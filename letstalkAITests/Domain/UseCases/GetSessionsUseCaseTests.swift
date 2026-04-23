//
//  GetSessionsUseCaseTests.swift
//  letstalkAITests
//
//  Unit tests for GetSessionsUseCase
//

import XCTest
@testable import letstalkAI

final class GetSessionsUseCaseTests: XCTestCase {
    var sut: GetSessionsUseCase!
    var mockSessionRepository: MockSessionRepository!
    
    override func setUp() {
        super.setUp()
        mockSessionRepository = MockSessionRepository()
        sut = GetSessionsUseCase(sessionRepository: mockSessionRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockSessionRepository = nil
        super.tearDown()
    }
    
    func testExecute_ReturnsAllSessions() async throws {
        let session1 = ChatSession(title: "Session 1")
        let session2 = ChatSession(title: "Session 2")
        mockSessionRepository.sessions = [session1, session2]
        
        let sessions = try await sut.execute()
        
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(mockSessionRepository.getAllSessionsCalled)
    }
    
    func testExecute_EmptyList_ReturnsEmptyArray() async throws {
        mockSessionRepository.sessions = []
        
        let sessions = try await sut.execute()
        
        XCTAssertTrue(sessions.isEmpty)
    }
    
    func testExecute_Error_ThrowsError() async {
        mockSessionRepository.shouldThrowError = true
        
        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testUpdateSessionTitle_Success_ReturnsTrue() async throws {
        let session = ChatSession(id: "1", title: "Old Title")
        mockSessionRepository.sessions = [session]
        
        let success = try await sut.updateSessionTitle(
            sessionId: "1",
            title: "New Title",
            existingSessions: mockSessionRepository.sessions
        )
        
        XCTAssertTrue(success)
        XCTAssertTrue(mockSessionRepository.updateTitleCalled)
    }
    
    func testUpdateSessionTitle_DuplicateTitle_ReturnsFalse() async throws {
        let session1 = ChatSession(id: "1", title: "Session 1")
        let session2 = ChatSession(id: "2", title: "Existing Title")
        mockSessionRepository.sessions = [session1, session2]
        
        let success = try await sut.updateSessionTitle(
            sessionId: "1",
            title: "Existing Title",
            existingSessions: mockSessionRepository.sessions
        )
        
        XCTAssertFalse(success)
    }
    
    func testUpdateSessionWebSearch_CallsRepository() async throws {
        let session = ChatSession(id: "1", title: "Test")
        mockSessionRepository.sessions = [session]
        
        try await sut.updateSessionWebSearch(sessionId: "1", useWebSearch: true)
        
        XCTAssertTrue(mockSessionRepository.sessions.first?.useWebSearch ?? false)
    }
}
