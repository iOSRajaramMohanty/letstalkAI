//
//  ChatSession.swift
//  letstalkAI
//
//  Domain Entity - Pure Swift, no external dependencies
//

import Foundation

struct ChatSession: Identifiable, Equatable, Codable, Sendable {
    let id: String
    var title: String
    let collectionName: String
    let createdAt: Date
    var updatedAt: Date
    var useWebSearch: Bool
    
    var displayTitle: String {
        title.isEmpty ? "New Chat" : title
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }
    
    init(
        id: String = UUID().uuidString,
        title: String = "",
        collectionName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        useWebSearch: Bool = false
    ) {
        self.id = id
        self.title = title
        self.collectionName = collectionName ?? "chat_\(id)"
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.useWebSearch = useWebSearch
    }
}

enum SessionCreationResult: Sendable {
    case success(ChatSession)
    case duplicateUntitled
    case duplicateTitle
    case databaseError
}
