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
    
    // Cache embedding objects for performance
    private lazy var sentenceEmbedding: NLEmbedding? = {
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        if embedding != nil {
            print("✅ [Embedding] Sentence embedding loaded successfully")
        }
        return embedding
    }()
    
    private lazy var wordEmbedding: NLEmbedding? = {
        let embedding = NLEmbedding.wordEmbedding(for: .english)
        if embedding != nil {
            print("✅ [Embedding] Word embedding loaded successfully")
        }
        return embedding
    }()
    
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
    
    /// Generate embedding using sentence embedding (preferred) or word embedding (fallback)
    private func generateEmbedding(for text: String) -> [Double]? {
        // Preprocess text for better embedding results
        let cleanedText = preprocessText(text)
        
        guard !cleanedText.isEmpty else {
            print("❌ [Embedding] Empty text after preprocessing")
            return nil
        }
        
        // Try sentence embedding first (better for semantic search, iOS 14+)
        if let sentenceEmb = sentenceEmbedding,
           let vector = sentenceEmb.vector(for: cleanedText) {
            return [Double](vector)
        }
        
        // Fallback to word embedding with averaging
        return generateWordEmbedding(for: cleanedText)
    }
    
    /// Preprocess text to improve embedding quality
    private func preprocessText(_ text: String) -> String {
        var cleaned = text
        
        // Remove URLs
        let urlPattern = "https?://[^\\s]+"
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }
        
        // Remove email addresses
        let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }
        
        // Remove special characters but keep basic punctuation
        let allowedChars = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: ".,!?'-"))
        cleaned = cleaned.unicodeScalars.filter { allowedChars.contains($0) }.map { String($0) }.joined()
        
        // Normalize whitespace
        cleaned = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        
        // Truncate very long text (embedding models have limits)
        if cleaned.count > 2000 {
            cleaned = String(cleaned.prefix(2000))
        }
        
        return cleaned
    }
    
    /// Generate embedding using word embedding with averaging
    private func generateWordEmbedding(for text: String) -> [Double]? {
        guard let embedding = wordEmbedding else {
            print("❌ [Embedding] NLEmbedding not available (neither sentence nor word)")
            print("   This typically happens when:")
            print("   - Running on iOS Simulator")
            print("   - NL assets not downloaded on device")
            print("   - Device has low memory")
            return nil
        }
        
        let words = text.lowercased()
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count > 1 }
        
        guard !words.isEmpty else {
            print("❌ [Embedding] No words to embed after cleaning")
            return nil
        }
        
        var validVectors: [[Double]] = []
        
        for word in words {
            if let vector = embedding.vector(for: word) {
                validVectors.append([Double](vector))
            }
        }
        
        if validVectors.isEmpty {
            print("❌ [Embedding] No valid word vectors found")
            print("   Total words: \(words.count)")
            print("   First 5 words: \(words.prefix(5))")
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
    
    /// Pre-check if NLEmbedding is available on this device
    static func isEmbeddingAvailable() -> Bool {
        // Prefer sentence embedding, fallback to word embedding
        if NLEmbedding.sentenceEmbedding(for: .english) != nil {
            return true
        }
        return NLEmbedding.wordEmbedding(for: .english) != nil
    }
    
    /// Get a description of the available embedding type
    static func embeddingDescription() -> String {
        if NLEmbedding.sentenceEmbedding(for: .english) != nil {
            return "Sentence Embedding (recommended)"
        } else if NLEmbedding.wordEmbedding(for: .english) != nil {
            return "Word Embedding (fallback)"
        } else {
            return "Not Available"
        }
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
