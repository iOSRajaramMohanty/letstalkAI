//
//  AddDocumentUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol AddDocumentUseCaseProtocol: Sendable {
    func execute(url: URL, session: ChatSession) async throws -> Bool
    func getDocuments(for sessionId: String) async throws -> [Document]
}

final class AddDocumentUseCase: AddDocumentUseCaseProtocol, @unchecked Sendable {
    private let documentRepository: DocumentRepositoryProtocol
    private let ragRepository: RAGRepositoryProtocol
    
    init(documentRepository: DocumentRepositoryProtocol, ragRepository: RAGRepositoryProtocol) {
        self.documentRepository = documentRepository
        self.ragRepository = ragRepository
    }
    
    func execute(url: URL, session: ChatSession) async throws -> Bool {
        let extractedText = try await documentRepository.extractTextFromPDF(at: url)
        
        let originalFileName = url.lastPathComponent
        let fileExtension = url.pathExtension
        let baseName = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        let uniqueFileName = "\(baseName)_\(UUID().uuidString).\(fileExtension)"
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectory.appendingPathComponent("Documents").appendingPathComponent(uniqueFileName)
        
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url, to: destinationURL)
        
        let document = Document(
            sessionId: session.id,
            name: originalFileName,
            path: destinationURL.path,
            type: .pdf
        )
        
        let documentId = try await documentRepository.saveDocument(document)
        
        let chunks = documentRepository.chunkText(extractedText, maxChunkSize: 3500, overlapTokens: 125)
        
        try await ragRepository.loadCollection(name: session.collectionName)
        
        for (index, chunkText) in chunks.enumerated() {
            let chunk = DocumentChunk(
                documentId: documentId,
                text: chunkText,
                index: index
            )
            
            let chunkId = try await documentRepository.saveDocumentChunk(chunk)
            try await ragRepository.addEntry(chunkText, collectionName: session.collectionName)
            try await documentRepository.markChunkAsEmbedded(chunkId)
        }
        
        return true
    }
    
    func getDocuments(for sessionId: String) async throws -> [Document] {
        try await documentRepository.getDocuments(for: sessionId)
    }
}
