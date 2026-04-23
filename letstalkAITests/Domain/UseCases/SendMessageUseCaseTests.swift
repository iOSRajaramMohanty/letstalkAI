//
//  SendMessageUseCaseTests.swift
//  letstalkAITests
//
//  Unit tests for SendMessageUseCase
//

import XCTest
@testable import letstalkAI

final class SendMessageUseCaseTests: XCTestCase {
    var sut: SendMessageUseCase!
    var mockChatRepository: MockChatRepository!
    var mockLLMRepository: MockLLMRepository!
    var mockRAGRepository: MockRAGRepository!
    var mockWebSearchRepository: MockWebSearchRepository!
    var mockDocumentRepository: MockDocumentRepository!
    
    override func setUp() {
        super.setUp()
        mockChatRepository = MockChatRepository()
        mockLLMRepository = MockLLMRepository()
        mockRAGRepository = MockRAGRepository()
        mockWebSearchRepository = MockWebSearchRepository()
        mockDocumentRepository = MockDocumentRepository()
        
        sut = SendMessageUseCase(
            chatRepository: mockChatRepository,
            llmRepository: mockLLMRepository,
            ragRepository: mockRAGRepository,
            webSearchRepository: mockWebSearchRepository,
            documentRepository: mockDocumentRepository
        )
    }
    
    override func tearDown() {
        sut = nil
        mockChatRepository = nil
        mockLLMRepository = nil
        mockRAGRepository = nil
        mockWebSearchRepository = nil
        mockDocumentRepository = nil
        super.tearDown()
    }
    
    func testExecute_GeneralQuery_SavesUserMessageAndReturnsAIResponse() async throws {
        let session = ChatSession(title: "Test Session")
        let message = "Hello, AI!"
        mockLLMRepository.mockResponse = "Hello! How can I help you?"
        
        var streamUpdates: [String] = []
        
        let response = try await sut.execute(
            message: message,
            session: session
        ) { partial in
            streamUpdates.append(partial)
        }
        
        XCTAssertTrue(mockChatRepository.saveMessageCalled)
        XCTAssertEqual(mockChatRepository.savedMessages.count, 2)
        XCTAssertTrue(mockChatRepository.savedMessages[0].isUser)
        XCTAssertEqual(mockChatRepository.savedMessages[0].text, message)
        XCTAssertFalse(response.isUser)
        XCTAssertEqual(response.text, "Hello! How can I help you?")
        XCTAssertFalse(streamUpdates.isEmpty)
    }
    
    func testExecute_WithWebSearchEnabled_UsesWebSearchRepository() async throws {
        var session = ChatSession(title: "Test Session")
        session.useWebSearch = true
        
        mockWebSearchRepository.mockResults = [
            WebSearchResult(title: "Test Result", url: "https://example.com", content: "Test content")
        ]
        mockLLMRepository.mockResponse = "Based on web search, here is the answer."
        
        let response = try await sut.execute(
            message: "Search for something",
            session: session
        ) { _ in }
        
        XCTAssertTrue(mockWebSearchRepository.searchCalled)
        XCTAssertTrue(mockRAGRepository.loadCollectionCalled)
        XCTAssertTrue(mockRAGRepository.addEntryCalled)
        XCTAssertFalse(response.isUser)
    }
    
    func testExecute_WithDocuments_UsesRAGRepository() async throws {
        let session = ChatSession(title: "Test Session")
        
        mockDocumentRepository.hasDocumentsResult = true
        mockRAGRepository.mockNeighbors = [
            RAGNeighbor(text: "Document context", score: 0.9)
        ]
        mockLLMRepository.mockResponse = "Based on your documents, here is the answer."
        
        let response = try await sut.execute(
            message: "What does my document say?",
            session: session
        ) { _ in }
        
        XCTAssertTrue(mockRAGRepository.loadCollectionCalled)
        XCTAssertTrue(mockRAGRepository.findNeighborsCalled)
        XCTAssertFalse(response.isUser)
    }
    
    func testExecute_LLMError_ThrowsError() async {
        let session = ChatSession(title: "Test Session")
        mockLLMRepository.shouldThrowError = true
        mockLLMRepository.errorToThrow = .rateLimited
        
        do {
            _ = try await sut.execute(
                message: "Test message",
                session: session
            ) { _ in }
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testExecute_CallsGetOrCreateSession() async throws {
        let session = ChatSession(title: "Test Session")
        mockLLMRepository.mockResponse = "Response"
        
        _ = try await sut.execute(
            message: "Test",
            session: session
        ) { _ in }
        
        XCTAssertTrue(mockLLMRepository.getOrCreateSessionCalled)
    }
}
