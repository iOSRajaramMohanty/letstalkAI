//
//  DocumentRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation
//

import Foundation

final class DocumentRepository: DocumentRepositoryProtocol, @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let fileStorageManager: FileStorageManager
    private let documentMapper: DocumentMapper
    
    init(
        databaseManager: DatabaseManager,
        fileStorageManager: FileStorageManager,
        documentMapper: DocumentMapper
    ) {
        self.databaseManager = databaseManager
        self.fileStorageManager = fileStorageManager
        self.documentMapper = documentMapper
    }
    
    func saveDocument(_ document: Document) async throws -> String {
        let dto = documentMapper.toDTO(document)
        return try databaseManager.saveDocument(dto)
    }
    
    func getDocuments(for sessionId: String) async throws -> [Document] {
        let dtos = try databaseManager.getDocuments(for: sessionId)
        return dtos.map { documentMapper.toDomain($0) }
    }
    
    func deleteDocument(_ documentId: String) async throws {
        throw DocumentError.notFound
    }
    
    func saveDocumentChunk(_ chunk: DocumentChunk) async throws -> String {
        let dto = documentMapper.chunkToDTO(chunk)
        return try databaseManager.saveDocumentChunk(dto)
    }
    
    func getUnembeddedChunks(for sessionId: String) async throws -> [DocumentChunk] {
        let dtos = try databaseManager.getUnembeddedChunks(for: sessionId)
        return dtos.map { documentMapper.chunkToDomain($0) }
    }
    
    func markChunkAsEmbedded(_ chunkId: String) async throws {
        try databaseManager.markChunkAsEmbedded(chunkId)
    }
    
    func extractTextFromPDF(at url: URL) async throws -> String {
        try fileStorageManager.extractTextFromPDF(at: url)
    }
    
    func chunkText(_ text: String, maxChunkSize: Int, overlapTokens: Int) -> [String] {
        fileStorageManager.chunkText(text, maxChunkSize: maxChunkSize, overlapTokens: overlapTokens)
    }
    
    func hasDocuments(for sessionId: String) async -> Bool {
        do {
            return try databaseManager.hasDocuments(for: sessionId)
        } catch {
            return false
        }
    }
}
