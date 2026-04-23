//
//  QueryRAGUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol QueryRAGUseCaseProtocol: Sendable {
    func execute(query: String, collectionName: String, count: Int) async throws -> [RAGNeighbor]
}

final class QueryRAGUseCase: QueryRAGUseCaseProtocol, @unchecked Sendable {
    private let ragRepository: RAGRepositoryProtocol
    
    init(ragRepository: RAGRepositoryProtocol) {
        self.ragRepository = ragRepository
    }
    
    func execute(query: String, collectionName: String, count: Int) async throws -> [RAGNeighbor] {
        try await ragRepository.loadCollection(name: collectionName)
        return try await ragRepository.findNeighbors(query: query, collectionName: collectionName, count: count)
    }
}
