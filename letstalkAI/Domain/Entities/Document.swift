//
//  Document.swift
//  letstalkAI
//
//  Domain Entity - Pure Swift, no external dependencies
//

import Foundation

struct Document: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let sessionId: String
    let name: String
    let path: String
    let type: DocumentType
    let uploadedAt: Date
    
    init(
        id: String = UUID().uuidString,
        sessionId: String,
        name: String,
        path: String,
        type: DocumentType = .pdf,
        uploadedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.name = name
        self.path = path
        self.type = type
        self.uploadedAt = uploadedAt
    }
}

enum DocumentType: String, Codable, Sendable {
    case pdf = "pdf"
    case text = "txt"
    case unknown = "unknown"
}

struct DocumentChunk: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let documentId: String
    let text: String
    let index: Int
    let pageIndex: Int?
    var isEmbedded: Bool
    
    init(
        id: String = UUID().uuidString,
        documentId: String,
        text: String,
        index: Int,
        pageIndex: Int? = nil,
        isEmbedded: Bool = false
    ) {
        self.id = id
        self.documentId = documentId
        self.text = text
        self.index = index
        self.pageIndex = pageIndex
        self.isEmbedded = isEmbedded
    }
}

struct DocumentImage: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let documentId: String
    let pageIndex: Int
    let imagePath: String
    let ocrText: String
    let classificationLabels: [String]
    
    init(
        id: String = UUID().uuidString,
        documentId: String,
        pageIndex: Int,
        imagePath: String,
        ocrText: String = "",
        classificationLabels: [String] = []
    ) {
        self.id = id
        self.documentId = documentId
        self.pageIndex = pageIndex
        self.imagePath = imagePath
        self.ocrText = ocrText
        self.classificationLabels = classificationLabels
    }
}
