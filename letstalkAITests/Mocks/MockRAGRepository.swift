//
//  MockRAGRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockRAGRepository: RAGRepositoryProtocol {
    var collections: Set<String> = []
    var entries: [String: [String]] = [:]
    var mockNeighbors: [RAGNeighbor] = []
    var shouldThrowError = false
    var errorToThrow: Error = RAGError.collectionNotFound
    
    var loadCollectionCalled = false
    var addEntryCalled = false
    var findNeighborsCalled = false
    
    func loadCollection(name: String) async throws {
        loadCollectionCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        collections.insert(name)
        if entries[name] == nil {
            entries[name] = []
        }
    }
    
    func addEntry(_ text: String, collectionName: String) async throws {
        addEntryCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        entries[collectionName, default: []].append(text)
    }
    
    func findNeighbors(query: String, collectionName: String, count: Int) async throws -> [RAGNeighbor] {
        findNeighborsCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return Array(mockNeighbors.prefix(count))
    }
    
    func hasDocuments(sessionId: String, collectionName: String) async -> Bool {
        return !(entries[collectionName]?.isEmpty ?? true)
    }
    
    func reset() {
        collections = []
        entries = [:]
        mockNeighbors = []
        shouldThrowError = false
        loadCollectionCalled = false
        addEntryCalled = false
        findNeighborsCalled = false
    }
}
