//
//  DocumentDTO.swift
//  letstalkAI
//
//  Data Transfer Object for database operations
//

import Foundation

struct DocumentDTO: Sendable {
    let id: String
    let sessionId: String
    let name: String
    let path: String
    let type: String
    let uploadedAt: Date
}

struct DocumentChunkDTO: Sendable {
    let id: String
    let documentId: String
    let text: String
    let chunkIndex: Int
    var isEmbedded: Bool
}
