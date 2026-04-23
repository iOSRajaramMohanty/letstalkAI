//
//  VectorDatabaseManager.swift
//  letstalkAI
//
//  SVDB Vector Database manager for RAG embeddings
//

import Foundation
import Accelerate
import NaturalLanguage
import SVDB

final class VectorDatabaseManager: @unchecked Sendable {
    private var collections: [String: Collection] = [:]
    
    func loadCollection(name: String) async throws {
        if collections[name] != nil {
            return
        }
        
        if let existing = SVDB.shared.getCollection(name) {
            collections[name] = existing
            return
        }
        
        let collection = try SVDB.shared.collection(name)
        collections[name] = collection
    }
    
    func addEntry(_ text: String, collectionName: String) async throws {
        guard let collection = collections[collectionName] else {
            throw RAGError.collectionNotFound
        }
        
        guard let embedding = generateEmbedding(for: text) else {
            throw RAGError.embeddingFailed
        }
        
        collection.addDocument(text: text, embedding: embedding)
    }
    
    func findNeighbors(query: String, collectionName: String, count: Int) async throws -> [(text: String, score: Double)] {
        guard let collection = collections[collectionName] else {
            throw RAGError.collectionNotFound
        }
        
        guard let queryEmbedding = generateEmbedding(for: query) else {
            throw RAGError.embeddingFailed
        }
        
        let results = collection.search(query: queryEmbedding, num_results: count)
        return results.map { ($0.text, $0.score) }
    }
    
    private func generateEmbedding(for sentence: String) -> [Double]? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            return nil
        }
        
        let words = sentence.lowercased().split(separator: " ").map { String($0) }
        guard !words.isEmpty else {
            return nil
        }
        
        var validVectors: [[Double]] = []
        
        for word in words {
            if let vector = embedding.vector(for: word) {
                validVectors.append([Double](vector))
            }
        }
        
        guard !validVectors.isEmpty else {
            return nil
        }
        
        let vectorLength = validVectors[0].count
        var vectorSum = [Double](repeating: 0, count: vectorLength)
        
        for vector in validVectors {
            vDSP_vaddD(vectorSum, 1, vector, 1, &vectorSum, 1, vDSP_Length(vectorSum.count))
        }
        
        var vectorAverage = [Double](repeating: 0, count: vectorSum.count)
        var divisor = Double(validVectors.count)
        vDSP_vsdivD(vectorSum, 1, &divisor, &vectorAverage, 1, vDSP_Length(vectorAverage.count))
        
        return vectorAverage
    }
}

enum RAGError: Error, LocalizedError, Sendable {
    case collectionNotFound
    case embeddingFailed
    
    var errorDescription: String? {
        switch self {
        case .collectionNotFound:
            return "RAG collection not found"
        case .embeddingFailed:
            return "Failed to generate embedding"
        }
    }
}
