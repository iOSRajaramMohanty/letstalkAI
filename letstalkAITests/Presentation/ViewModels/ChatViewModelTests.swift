//
//  ChatViewModelTests.swift
//  letstalkAITests
//
//  Unit tests for ChatViewModel
//

import XCTest
@testable import letstalkAI

@MainActor
final class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockSendMessageUseCase: MockSendMessageUseCase!
    var mockGetChatHistoryUseCase: MockGetChatHistoryUseCase!
    var mockGenerateTitleUseCase: MockGenerateTitleUseCase!
    var mockSpeakTextUseCase: MockSpeakTextUseCase!
    
    override func setUp() {
        super.setUp()
        mockSendMessageUseCase = MockSendMessageUseCase()
        mockGetChatHistoryUseCase = MockGetChatHistoryUseCase()
        mockGenerateTitleUseCase = MockGenerateTitleUseCase()
        mockSpeakTextUseCase = MockSpeakTextUseCase()
        
        sut = ChatViewModel(
            sendMessageUseCase: mockSendMessageUseCase,
            getChatHistoryUseCase: mockGetChatHistoryUseCase,
            generateTitleUseCase: mockGenerateTitleUseCase,
            speakTextUseCase: mockSpeakTextUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        mockSendMessageUseCase = nil
        mockGetChatHistoryUseCase = nil
        mockGenerateTitleUseCase = nil
        mockSpeakTextUseCase = nil
        super.tearDown()
    }
    
    func testSendMessage_EmptyText_DoesNothing() async {
        let session = ChatSession(title: "Test")
        sut.currentSession = session
        
        await sut.sendMessage("")
        
        XCTAssertFalse(mockSendMessageUseCase.executeCalled)
    }
    
    func testSendMessage_ValidText_AddsUserMessage() async {
        let session = ChatSession(title: "Test")
        sut.currentSession = session
        mockSendMessageUseCase.mockResponse = ChatMessage(text: "AI response", isUser: false)
        
        await sut.sendMessage("Hello")
        
        XCTAssertTrue(mockSendMessageUseCase.executeCalled)
        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertTrue(sut.messages[0].isUser)
        XCTAssertFalse(sut.messages[1].isUser)
    }
    
    func testSendMessage_Error_SetsErrorMessage() async {
        let session = ChatSession(title: "Test")
        sut.currentSession = session
        mockSendMessageUseCase.shouldThrowError = true
        mockSendMessageUseCase.errorToThrow = LLMError.rateLimited
        
        await sut.sendMessage("Hello")
        
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testToggleWebSearch_TogglesSessionWebSearch() async {
        var session = ChatSession(title: "Test")
        session.useWebSearch = false
        sut.currentSession = session
        
        await sut.toggleWebSearch()
        
        XCTAssertTrue(sut.currentSession?.useWebSearch ?? false)
    }
    
    func testClearError_ClearsErrorMessage() {
        sut.errorMessage = "Test error"
        
        sut.clearError()
        
        XCTAssertNil(sut.errorMessage)
    }
}

final class MockSendMessageUseCase: SendMessageUseCaseProtocol {
    var executeCalled = false
    var mockResponse = ChatMessage(text: "Mock response", isUser: false)
    var shouldThrowError = false
    var errorToThrow: Error = LLMError.generationFailed("Test error")
    
    func execute(
        message: String,
        session: ChatSession,
        onStreamUpdate: @escaping (String) -> Void
    ) async throws -> ChatMessage {
        executeCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        onStreamUpdate(mockResponse.text)
        return mockResponse
    }
}

final class MockGetChatHistoryUseCase: GetChatHistoryUseCaseProtocol {
    var mockMessages: [ChatMessage] = []
    
    func execute(sessionId: String) async throws -> [ChatMessage] {
        return mockMessages
    }
}

final class MockGenerateTitleUseCase: GenerateTitleUseCaseProtocol {
    var mockTitle = "Generated Title"
    
    func execute(from response: String, sessionId: String) async throws -> String {
        return mockTitle
    }
}

final class MockSpeakTextUseCase: SpeakTextUseCaseProtocol {
    var _isSpeaking = false
    var isSpeaking: Bool { _isSpeaking }
    var currentText: String = ""
    
    func execute(text: String) async {
        _isSpeaking = true
        currentText = text
        _isSpeaking = false
    }
    
    func execute(text: String, completion: @escaping () -> Void) async {
        _isSpeaking = true
        currentText = text
        _isSpeaking = false
        completion()
    }
    
    func stop() {
        _isSpeaking = false
    }
}
