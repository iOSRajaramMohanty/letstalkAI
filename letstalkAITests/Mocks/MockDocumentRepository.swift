//
//  MockDocumentRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockDocumentRepository: DocumentRepositoryProtocol {
    var documents: [Document] = []
    var chunks: [DocumentChunk] = []
    var mockExtractedText: String = "Sample extracted text from PDF document."
    var shouldThrowError = false
    var errorToThrow: Error = DocumentError.extractionFailed
    
    var saveDocumentCalled = false
    var extractTextCalled = false
    var hasDocumentsResult = false
    
    func saveDocument(_ document: Document) async throws -> String {
        saveDocumentCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        documents.append(document)
        return document.id
    }
    
    func getDocuments(for sessionId: String) async throws -> [Document] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return documents.filter { $0.sessionId == sessionId }
    }
    
    func deleteDocument(_ documentId: String) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        documents.removeAll { $0.id == documentId }
    }
    
    func saveDocumentChunk(_ chunk: DocumentChunk) async throws -> String {
        if shouldThrowError {
            throw errorToThrow
        }
        
        chunks.append(chunk)
        return chunk.id
    }
    
    func getUnembeddedChunks(for sessionId: String) async throws -> [DocumentChunk] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return chunks.filter { !$0.isEmbedded }
    }
    
    func markChunkAsEmbedded(_ chunkId: String) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let index = chunks.firstIndex(where: { $0.id == chunkId }) {
            chunks[index].isEmbedded = true
        }
    }
    
    func extractTextFromPDF(at url: URL) async throws -> String {
        extractTextCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockExtractedText
    }
    
    func chunkText(_ text: String, maxChunkSize: Int, overlapTokens: Int) -> [String] {
        let words = text.split(separator: " ")
        let wordsPerChunk = maxChunkSize / 10
        
        var chunks: [String] = []
        var currentChunk: [Substring] = []
        
        for word in words {
            currentChunk.append(word)
            if currentChunk.count >= wordsPerChunk {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        
        return chunks
    }
    
    func hasDocuments(for sessionId: String) async -> Bool {
        return hasDocumentsResult
    }
    
    func reset() {
        documents = []
        chunks = []
        mockExtractedText = "Sample extracted text from PDF document."
        shouldThrowError = false
        saveDocumentCalled = false
        extractTextCalled = false
        hasDocumentsResult = false
    }
}
