//
//  CreateSessionUseCaseTests.swift
//  letstalkAITests
//
//  Unit tests for CreateSessionUseCase
//

import XCTest
@testable import letstalkAI

final class CreateSessionUseCaseTests: XCTestCase {
    var sut: CreateSessionUseCase!
    var mockSessionRepository: MockSessionRepository!
    
    override func setUp() {
        super.setUp()
        mockSessionRepository = MockSessionRepository()
        sut = CreateSessionUseCase(sessionRepository: mockSessionRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockSessionRepository = nil
        super.tearDown()
    }
    
    func testExecute_NewSession_ReturnsSuccess() async throws {
        let result = try await sut.execute(title: "Test Session")
        
        switch result {
        case .success(let session):
            XCTAssertEqual(session.title, "Test Session")
            XCTAssertTrue(mockSessionRepository.createSessionCalled)
        default:
            XCTFail("Expected success result")
        }
    }
    
    func testExecute_EmptyTitle_CreatesUntitledSession() async throws {
        let result = try await sut.execute(title: "")
        
        switch result {
        case .success(let session):
            XCTAssertEqual(session.title, "")
        default:
            XCTFail("Expected success result")
        }
    }
    
    func testExecute_DuplicateUntitled_ReturnsDuplicateUntitled() async throws {
        mockSessionRepository.sessions = [ChatSession(title: "")]
        
        let result = try await sut.execute(title: "")
        
        switch result {
        case .duplicateUntitled:
            break
        default:
            XCTFail("Expected duplicateUntitled result")
        }
    }
    
    func testExecute_DuplicateTitle_ReturnsDuplicateTitle() async throws {
        mockSessionRepository.sessions = [ChatSession(title: "Existing Session")]
        
        let result = try await sut.execute(title: "Existing Session")
        
        switch result {
        case .duplicateTitle:
            break
        default:
            XCTFail("Expected duplicateTitle result")
        }
    }
    
    func testExecute_CaseInsensitiveDuplicateCheck() async throws {
        mockSessionRepository.sessions = [ChatSession(title: "Test Session")]
        
        let result = try await sut.execute(title: "test session")
        
        switch result {
        case .duplicateTitle:
            break
        default:
            XCTFail("Expected duplicateTitle result for case-insensitive match")
        }
    }
    
    func testExecute_TrimmedTitle() async throws {
        let result = try await sut.execute(title: "  Test Session  ")
        
        switch result {
        case .success(let session):
            XCTAssertEqual(session.title, "Test Session")
        default:
            XCTFail("Expected success result with trimmed title")
        }
    }
    
    func testExecute_DatabaseError_ReturnsDatabaseError() async throws {
        mockSessionRepository.shouldThrowError = true
        
        let result = try await sut.execute(title: "Test")
        
        switch result {
        case .databaseError:
            break
        default:
            XCTFail("Expected databaseError result")
        }
    }
}
