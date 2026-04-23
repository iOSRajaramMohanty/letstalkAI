//
//  ChatRepositoryTests.swift
//  letstalkAITests
//
//  Integration tests for ChatRepository
//

import XCTest
@testable import letstalkAI

final class ChatRepositoryTests: XCTestCase {
    var sut: ChatRepository!
    var databaseManager: DatabaseManager!
    var messageMapper: ChatMessageMapper!
    
    override func setUp() {
        super.setUp()
        databaseManager = DatabaseManager(inMemory: true)
        messageMapper = ChatMessageMapper()
        sut = ChatRepository(databaseManager: databaseManager, messageMapper: messageMapper)
    }
    
    override func tearDown() {
        sut = nil
        databaseManager = nil
        messageMapper = nil
        super.tearDown()
    }
    
    func testSaveMessage_PersistsMessage() async throws {
        let message = ChatMessage(text: "Test message", isUser: true)
        let sessionId = "test-session-id"
        
        try await sut.saveMessage(message, sessionId: sessionId)
        
        let messages = try await sut.getMessages(for: sessionId)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.text, "Test message")
        XCTAssertTrue(messages.first?.isUser ?? false)
    }
    
    func testGetMessages_ReturnsMessagesInOrder() async throws {
        let sessionId = "test-session-id"
        
        let message1 = ChatMessage(text: "First", isUser: true)
        let message2 = ChatMessage(text: "Second", isUser: false)
        let message3 = ChatMessage(text: "Third", isUser: true)
        
        try await sut.saveMessage(message1, sessionId: sessionId)
        try await Task.sleep(nanoseconds: 10_000_000)
        try await sut.saveMessage(message2, sessionId: sessionId)
        try await Task.sleep(nanoseconds: 10_000_000)
        try await sut.saveMessage(message3, sessionId: sessionId)
        
        let messages = try await sut.getMessages(for: sessionId)
        
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].text, "First")
        XCTAssertEqual(messages[1].text, "Second")
        XCTAssertEqual(messages[2].text, "Third")
    }
    
    func testGetMessages_DifferentSessions_ReturnsCorrectMessages() async throws {
        let session1 = "session-1"
        let session2 = "session-2"
        
        try await sut.saveMessage(ChatMessage(text: "Session 1 message", isUser: true), sessionId: session1)
        try await sut.saveMessage(ChatMessage(text: "Session 2 message", isUser: true), sessionId: session2)
        
        let session1Messages = try await sut.getMessages(for: session1)
        let session2Messages = try await sut.getMessages(for: session2)
        
        XCTAssertEqual(session1Messages.count, 1)
        XCTAssertEqual(session1Messages.first?.text, "Session 1 message")
        
        XCTAssertEqual(session2Messages.count, 1)
        XCTAssertEqual(session2Messages.first?.text, "Session 2 message")
    }
    
    func testSaveMessage_WithSources_PersistsSources() async throws {
        let sources = [
            WebSearchResult(title: "Source 1", url: "https://example.com", content: "Content 1")
        ]
        let message = ChatMessage(text: "Message with sources", isUser: false, sources: sources)
        let sessionId = "test-session"
        
        try await sut.saveMessage(message, sessionId: sessionId)
        
        let messages = try await sut.getMessages(for: sessionId)
        XCTAssertEqual(messages.first?.sources?.count, 1)
        XCTAssertEqual(messages.first?.sources?.first?.title, "Source 1")
    }
}
