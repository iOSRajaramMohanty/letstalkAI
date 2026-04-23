//
//  ChatMessageDTO.swift
//  letstalkAI
//
//  Data Transfer Object for database operations
//

import Foundation

struct ChatMessageDTO: Sendable {
    let id: String
    let sessionId: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    let sourcesJSON: String?
}
