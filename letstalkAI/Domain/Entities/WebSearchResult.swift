//
//  WebSearchResult.swift
//  letstalkAI
//
//  Domain Entity - Pure Swift, no external dependencies
//

import Foundation

struct WebSearchResult: Identifiable, Equatable, Codable, Sendable {
    var id: String { url }
    let title: String
    let url: String
    let content: String
    
    init(title: String, url: String, content: String) {
        self.title = title
        self.url = url
        self.content = content
    }
}

struct RAGNeighbor: Equatable, Sendable {
    let text: String
    let score: Double
    
    init(text: String, score: Double) {
        self.text = text
        self.score = score
    }
}
