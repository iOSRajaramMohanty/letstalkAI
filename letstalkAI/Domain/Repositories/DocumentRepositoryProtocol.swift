//
//  DocumentRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol DocumentRepositoryProtocol: Sendable {
    func saveDocument(_ document: Document) async throws -> String
    func getDocuments(for sessionId: String) async throws -> [Document]
    func deleteDocument(_ documentId: String) async throws
    
    func saveDocumentChunk(_ chunk: DocumentChunk) async throws -> String
    func getUnembeddedChunks(for sessionId: String) async throws -> [DocumentChunk]
    func markChunkAsEmbedded(_ chunkId: String) async throws
    
    func extractTextFromPDF(at url: URL) async throws -> String
    func chunkText(_ text: String, maxChunkSize: Int, overlapTokens: Int) -> [String]
    
    func hasDocuments(for sessionId: String) async -> Bool
}

enum DocumentError: Error, LocalizedError, Sendable {
    case accessDenied
    case extractionFailed
    case saveFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Failed to access document"
        case .extractionFailed:
            return "Failed to extract text from PDF"
        case .saveFailed:
            return "Failed to save document"
        case .notFound:
            return "Document not found"
        }
    }
}
