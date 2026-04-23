//
//  MockWebSearchRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockWebSearchRepository: WebSearchRepositoryProtocol {
    var mockResults: [WebSearchResult] = []
    var shouldThrowError = false
    var errorToThrow: Error = URLError(.badURL)
    
    var searchCalled = false
    var lastQuery: String?
    
    func searchAndScrape(query: String) async throws -> [WebSearchResult] {
        searchCalled = true
        lastQuery = query
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockResults
    }
    
    func chunkText(_ text: String, maxLength: Int, overlapTokens: Int) -> [String] {
        let words = text.split(separator: " ")
        let wordsPerChunk = maxLength / 10
        
        var chunks: [String] = []
        var currentChunk: [Substring] = []
        
        for word in words {
            currentChunk.append(word)
            if currentChunk.count >= wordsPerChunk {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        
        return chunks
    }
    
    func reset() {
        mockResults = []
        shouldThrowError = false
        searchCalled = false
        lastQuery = nil
    }
}
