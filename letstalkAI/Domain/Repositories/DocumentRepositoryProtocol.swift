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
    func extractContentFromPDF(at url: URL, documentId: String) async throws -> PDFExtractionResult
    func chunkText(_ text: String, maxChunkSize: Int, overlapTokens: Int) -> [String]
    
    func hasDocuments(for sessionId: String) async -> Bool
    
    func saveDocumentImage(_ image: DocumentImage) async throws -> String
    func getImagesForDocument(_ documentId: String) async throws -> [DocumentImage]
    func getImagesForPage(documentId: String, pageIndex: Int) async throws -> [DocumentImage]
    func deleteImagesForDocument(_ documentId: String) async throws
    func searchImagesByOCR(query: String, documentId: String) async throws -> [DocumentImage]
    
    func learnQueryLabelMapping(queryWord: String, matchedLabel: String) async throws
    func getLearnedLabelsForQuery(_ queryWord: String) async throws -> [(label: String, score: Int)]
}

enum DocumentError: Error, LocalizedError, Sendable {
    case accessDenied
    case extractionFailed
    case saveFailed
    case notFound
    case fileNotFound
    case emptyDocument
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to the file was denied."
        case .extractionFailed:
            return "Failed to extract text from the PDF. The file may be corrupted or contain only images."
        case .saveFailed:
            return "Failed to save the document."
        case .notFound:
            return "Document not found."
        case .fileNotFound:
            return "The selected file could not be found or accessed."
        case .emptyDocument:
            return "The document appears to be empty or contains no readable text."
        case .processingFailed(let reason):
            return "Failed to process document: \(reason)"
        }
    }
}
