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
        print("🗑️ [DocumentRepository] Getting document info...")
        
        guard let dto = try databaseManager.getDocument(by: documentId) else {
            print("❌ [DocumentRepository] Document not found in database")
            throw DocumentError.notFound
        }
        
        print("🗑️ [DocumentRepository] Deleting file from storage: \(dto.path)")
        let fileURL = URL(fileURLWithPath: dto.path)
        if FileManager.default.fileExists(atPath: dto.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ [DocumentRepository] File deleted from storage")
        } else {
            print("⚠️ [DocumentRepository] File not found on disk (already deleted?)")
        }
        
        print("🗑️ [DocumentRepository] Deleting document from database...")
        try databaseManager.deleteDocument(documentId)
        print("✅ [DocumentRepository] Document and chunks deleted from database")
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
    
    func extractContentFromPDF(at url: URL, documentId: String) async throws -> PDFExtractionResult {
        try fileStorageManager.extractContentFromPDF(at: url, documentId: documentId)
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
    
    // MARK: - Document Images
    
    func saveDocumentImage(_ image: DocumentImage) async throws -> String {
        let dto = documentMapper.imageToDTO(image)
        return try databaseManager.saveDocumentImage(dto)
    }
    
    func getImagesForDocument(_ documentId: String) async throws -> [DocumentImage] {
        let dtos = try databaseManager.getImagesForDocument(documentId)
        return dtos.map { documentMapper.imageToDomain($0) }
    }
    
    func getImagesForPage(documentId: String, pageIndex: Int) async throws -> [DocumentImage] {
        let dtos = try databaseManager.getImagesForPage(documentId: documentId, pageIndex: pageIndex)
        return dtos.map { documentMapper.imageToDomain($0) }
    }
    
    func deleteImagesForDocument(_ documentId: String) async throws {
        try databaseManager.deleteImagesForDocument(documentId)
        fileStorageManager.deleteImagesForDocument(documentId)
    }
    
    func searchImagesByOCR(query: String, documentId: String) async throws -> [DocumentImage] {
        let dtos = try databaseManager.searchImagesByOCR(query: query, documentId: documentId)
        return dtos.map { documentMapper.imageToDomain($0) }
    }
    
    // MARK: - Query Learning
    
    func learnQueryLabelMapping(queryWord: String, matchedLabel: String) async throws {
        try databaseManager.learnQueryLabelMapping(queryWord: queryWord, matchedLabel: matchedLabel)
    }
    
    func getLearnedLabelsForQuery(_ queryWord: String) async throws -> [(label: String, score: Int)] {
        try databaseManager.getLearnedLabelsForQuery(queryWord)
    }
}
