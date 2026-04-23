//
//  ChatSessionDTO.swift
//  letstalkAI
//
//  Data Transfer Object for database operations
//

import Foundation

struct ChatSessionDTO: Sendable {
    let id: String
    var title: String
    let collectionName: String
    let createdAt: Date
    var updatedAt: Date
    var useWebSearch: Bool
    var transcriptJSON: String?
}
