//
//  ChatMessage.swift
//  letstalkAI
//
//  Domain Entity - Pure Swift, no external dependencies
//

import Foundation

struct ChatMessage: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let sources: [WebSearchResult]?
    let imageURLs: [URL]?
    
    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        sources: [WebSearchResult]? = nil,
        imageURLs: [URL]? = nil
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.sources = sources
        self.imageURLs = imageURLs
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp
    }
}
