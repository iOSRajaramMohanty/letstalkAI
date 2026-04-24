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
    let pageIndex: Int?
    var isEmbedded: Bool
    
    init(id: String, documentId: String, text: String, chunkIndex: Int, pageIndex: Int? = nil, isEmbedded: Bool = false) {
        self.id = id
        self.documentId = documentId
        self.text = text
        self.chunkIndex = chunkIndex
        self.pageIndex = pageIndex
        self.isEmbedded = isEmbedded
    }
}

struct DocumentImageDTO: Sendable {
    let id: String
    let documentId: String
    let pageIndex: Int
    let imagePath: String
    let ocrText: String
    let classificationLabels: [String]
    
    init(id: String, documentId: String, pageIndex: Int, imagePath: String, ocrText: String = "", classificationLabels: [String] = []) {
        self.id = id
        self.documentId = documentId
        self.pageIndex = pageIndex
        self.imagePath = imagePath
        self.ocrText = ocrText
        self.classificationLabels = classificationLabels
    }
}
