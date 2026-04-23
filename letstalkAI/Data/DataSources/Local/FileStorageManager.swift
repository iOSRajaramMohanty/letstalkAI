//
//  FileStorageManager.swift
//  letstalkAI
//
//  Manages file storage for documents
//

import Foundation
import PDFKit
import NaturalLanguage

final class FileStorageManager: @unchecked Sendable {
    
    func extractTextFromPDF(at url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw DocumentError.accessDenied
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.extractionFailed
        }
        
        let pageCount = pdfDocument.pageCount
        var extractedText = ""
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            if let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        guard !extractedText.isEmpty else {
            throw DocumentError.extractionFailed
        }
        
        return extractedText
    }
    
    func chunkText(_ text: String, maxChunkSize: Int = 3500, overlapTokens: Int = 125) -> [String] {
        let maxTokens = maxChunkSize / 4
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { sentence in
                sentence.hasSuffix(".") || sentence.hasSuffix("!") || sentence.hasSuffix("?") ?
                sentence : sentence + "."
            }
        
        var chunks: [String] = []
        var currentChunk = ""
        var currentTokenCount = 0
        var previousChunkSentences: [String] = []
        
        for sentence in sentences {
            let sentenceTokenCount = countTokens(in: sentence)
            let potentialChunk = currentChunk.isEmpty ? sentence : currentChunk + " " + sentence
            let potentialTokenCount = currentTokenCount + sentenceTokenCount + (currentChunk.isEmpty ? 0 : 1)
            
            if potentialTokenCount <= maxTokens {
                currentChunk = potentialChunk
                currentTokenCount = potentialTokenCount
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                    
                    let chunkSentences = currentChunk.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    previousChunkSentences = chunkSentences
                }
                
                var overlapText = ""
                var overlapTokenCount = 0
                
                if !previousChunkSentences.isEmpty && chunks.count > 0 {
                    for sentenceIndex in stride(from: previousChunkSentences.count - 1, through: 0, by: -1) {
                        let overlapSentence = previousChunkSentences[sentenceIndex]
                        let overlapSentenceTokens = countTokens(in: overlapSentence)
                        
                        if overlapTokenCount + overlapSentenceTokens <= overlapTokens {
                            overlapText = overlapSentence + (overlapText.isEmpty ? "" : " " + overlapText)
                            overlapTokenCount += overlapSentenceTokens
                        } else {
                            break
                        }
                    }
                }
                
                if sentenceTokenCount <= maxTokens {
                    if !overlapText.isEmpty {
                        currentChunk = overlapText + " " + sentence
                        currentTokenCount = overlapTokenCount + sentenceTokenCount + 1
                    } else {
                        currentChunk = sentence
                        currentTokenCount = sentenceTokenCount
                    }
                } else {
                    let words = sentence.components(separatedBy: .whitespaces)
                    var truncatedSentence = ""
                    var truncatedTokenCount = 0
                    
                    for word in words {
                        let wordTokenCount = countTokens(in: word)
                        if truncatedTokenCount + wordTokenCount <= maxTokens {
                            truncatedSentence += (truncatedSentence.isEmpty ? "" : " ") + word
                            truncatedTokenCount += wordTokenCount
                        } else {
                            break
                        }
                    }
                    
                    if !truncatedSentence.isEmpty {
                        if !truncatedSentence.hasSuffix(".") && !truncatedSentence.hasSuffix("!") && !truncatedSentence.hasSuffix("?") {
                            truncatedSentence += "."
                        }
                        chunks.append(truncatedSentence)
                    }
                    currentChunk = ""
                    currentTokenCount = 0
                }
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks.filter { !$0.isEmpty }
    }
    
    private func countTokens(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        return tokens.count
    }
    
    func saveDocument(_ data: Data, fileName: String) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DocumentError.saveFailed
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("Documents").appendingPathComponent(fileName)
        
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
        
        return fileURL
    }
}
