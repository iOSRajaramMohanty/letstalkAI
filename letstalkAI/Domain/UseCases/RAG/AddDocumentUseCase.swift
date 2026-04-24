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
    func deleteDocument(_ documentId: String) async throws
}

final class AddDocumentUseCase: AddDocumentUseCaseProtocol, @unchecked Sendable {
    private let documentRepository: DocumentRepositoryProtocol
    private let ragRepository: RAGRepositoryProtocol
    
    init(documentRepository: DocumentRepositoryProtocol, ragRepository: RAGRepositoryProtocol) {
        self.documentRepository = documentRepository
        self.ragRepository = ragRepository
    }
    
    func execute(url: URL, session: ChatSession) async throws -> Bool {
        print("📄 [Document Upload] Starting document processing...")
        print("📄 [Document Upload] File: \(url.lastPathComponent)")
        
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ [Document Upload] Error: File not found at path")
            throw DocumentError.fileNotFound
        }
        print("✅ [Document Upload] File exists and accessible")
        
        let originalFileName = url.lastPathComponent
        let fileExtension = url.pathExtension
        let baseName = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        let uniqueFileName = "\(baseName)_\(UUID().uuidString).\(fileExtension)"
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectory.appendingPathComponent("Documents").appendingPathComponent(uniqueFileName)
        
        print("💾 [Document Upload] Copying file to app storage...")
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: url, to: destinationURL)
        print("✅ [Document Upload] File copied to: \(destinationURL.lastPathComponent)")
        
        let document = Document(
            sessionId: session.id,
            name: originalFileName,
            path: destinationURL.path,
            type: .pdf
        )
        
        print("💾 [Document Upload] Saving document to database...")
        let documentId = try await documentRepository.saveDocument(document)
        print("✅ [Document Upload] Document saved with ID: \(documentId)")
        
        print("📖 [Document Upload] Extracting text and images from PDF...")
        let extractionResult = try await documentRepository.extractContentFromPDF(at: destinationURL, documentId: documentId)
        
        guard !extractionResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ [Document Upload] Error: No text extracted from PDF")
            throw DocumentError.emptyDocument
        }
        let characterCount = extractionResult.text.count
        print("✅ [Document Upload] Text extracted: \(characterCount) characters")
        print("🖼️ [Document Upload] Page images extracted: \(extractionResult.totalImages)")
        
        print("📚 [Document Upload] Loading RAG collection: \(session.collectionName)")
        try await ragRepository.loadCollection(name: session.collectionName)
        print("✅ [Document Upload] Collection loaded")
        
        print("🖼️ [Document Upload] Saving images, OCR text, and classification labels...")
        var savedImageCount = 0
        var imagesWithOCR = 0
        var imagesWithLabels = 0
        
        for pageContent in extractionResult.pageContents {
            for (imageIndex, imageURL) in pageContent.imageURLs.enumerated() {
                let ocrText = imageIndex < pageContent.imageOCRTexts.count ? pageContent.imageOCRTexts[imageIndex] : ""
                let labels = imageIndex < pageContent.imageClassifications.count ? pageContent.imageClassifications[imageIndex] : []
                
                let image = DocumentImage(
                    documentId: documentId,
                    pageIndex: pageContent.pageIndex,
                    imagePath: imageURL.path,
                    ocrText: ocrText,
                    classificationLabels: labels
                )
                _ = try await documentRepository.saveDocumentImage(image)
                savedImageCount += 1
                
                if !labels.isEmpty {
                    imagesWithLabels += 1
                }
                
                if !ocrText.isEmpty {
                    imagesWithOCR += 1
                    let ocrEntry = "[Image Page \(pageContent.pageIndex + 1)] \(ocrText)"
                    try await ragRepository.addEntry(ocrEntry, collectionName: session.collectionName)
                }
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 [Image Save Summary]")
        print("   🖼️ Total images saved to DB: \(savedImageCount)")
        print("   📝 Images with OCR text: \(imagesWithOCR)")
        print("   🏷️ Images with classification: \(imagesWithLabels)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        print("✂️ [Document Upload] Chunking text for RAG processing...")
        let chunks = documentRepository.chunkText(extractionResult.text, maxChunkSize: 3500, overlapTokens: 125)
        print("✅ [Document Upload] Created \(chunks.count) text chunks")
        
        print("🔄 [Document Upload] Processing chunks and creating embeddings...")
        for (index, chunkText) in chunks.enumerated() {
            let pageIndex = extractPageIndex(from: chunkText)
            
            let chunk = DocumentChunk(
                documentId: documentId,
                text: chunkText,
                index: index,
                pageIndex: pageIndex
            )
            
            let chunkId = try await documentRepository.saveDocumentChunk(chunk)
            try await ragRepository.addEntry(chunkText, collectionName: session.collectionName)
            try await documentRepository.markChunkAsEmbedded(chunkId)
            print("   ✅ Chunk \(index + 1)/\(chunks.count) processed (\(chunkText.count) chars, page: \(pageIndex ?? -1))")
        }
        
        print("🎉 [Document Upload] Document processing complete!")
        print("   📄 File: \(originalFileName)")
        print("   📊 Total chunks: \(chunks.count)")
        print("   📝 Total characters: \(characterCount)")
        print("   🖼️ Total images: \(extractionResult.totalImages)")
        
        return true
    }
    
    private func extractPageIndex(from text: String) -> Int? {
        let pattern = "\\[Page (\\d+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text),
              let pageNumber = Int(text[range]) else {
            return nil
        }
        return pageNumber - 1
    }
    
    func getDocuments(for sessionId: String) async throws -> [Document] {
        try await documentRepository.getDocuments(for: sessionId)
    }
    
    func deleteDocument(_ documentId: String) async throws {
        print("🗑️ [Document Delete] Starting deletion...")
        print("   Document ID: \(documentId)")
        
        try await documentRepository.deleteDocument(documentId)
        
        print("✅ [Document Delete] Document and associated data removed")
    }
}
