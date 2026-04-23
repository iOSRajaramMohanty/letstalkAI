//
//  RAGRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol RAGRepositoryProtocol: Sendable {
    func loadCollection(name: String) async throws
    func addEntry(_ text: String, collectionName: String) async throws
    func findNeighbors(query: String, collectionName: String, count: Int) async throws -> [RAGNeighbor]
    func hasDocuments(sessionId: String, collectionName: String) async -> Bool
}
