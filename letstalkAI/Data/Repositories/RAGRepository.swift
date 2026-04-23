//
//  RAGRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation
//

import Foundation

final class RAGRepository: RAGRepositoryProtocol, @unchecked Sendable {
    private let vectorDatabaseManager: VectorDatabaseManager
    
    init(vectorDatabaseManager: VectorDatabaseManager) {
        self.vectorDatabaseManager = vectorDatabaseManager
    }
    
    func loadCollection(name: String) async throws {
        try await vectorDatabaseManager.loadCollection(name: name)
    }
    
    func addEntry(_ text: String, collectionName: String) async throws {
        try await vectorDatabaseManager.addEntry(text, collectionName: collectionName)
    }
    
    func findNeighbors(query: String, collectionName: String, count: Int) async throws -> [RAGNeighbor] {
        let results = try await vectorDatabaseManager.findNeighbors(
            query: query,
            collectionName: collectionName,
            count: count
        )
        return results.map { RAGNeighbor(text: $0.text, score: $0.score) }
    }
    
    func hasDocuments(sessionId: String, collectionName: String) async -> Bool {
        do {
            try await loadCollection(name: collectionName)
            let neighbors = try await vectorDatabaseManager.findNeighbors(
                query: "test",
                collectionName: collectionName,
                count: 1
            )
            return !neighbors.isEmpty
        } catch {
            return false
        }
    }
}
