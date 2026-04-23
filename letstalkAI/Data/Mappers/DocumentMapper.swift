//
//  DocumentMapper.swift
//  letstalkAI
//
//  Maps between Domain entities and DTOs
//

import Foundation

final class DocumentMapper: Sendable {
    func toDTO(_ document: Document) -> DocumentDTO {
        DocumentDTO(
            id: document.id,
            sessionId: document.sessionId,
            name: document.name,
            path: document.path,
            type: document.type.rawValue,
            uploadedAt: document.uploadedAt
        )
    }
    
    func toDomain(_ dto: DocumentDTO) -> Document {
        Document(
            id: dto.id,
            sessionId: dto.sessionId,
            name: dto.name,
            path: dto.path,
            type: DocumentType(rawValue: dto.type) ?? .unknown,
            uploadedAt: dto.uploadedAt
        )
    }
    
    func chunkToDTO(_ chunk: DocumentChunk) -> DocumentChunkDTO {
        DocumentChunkDTO(
            id: chunk.id,
            documentId: chunk.documentId,
            text: chunk.text,
            chunkIndex: chunk.index,
            isEmbedded: chunk.isEmbedded
        )
    }
    
    func chunkToDomain(_ dto: DocumentChunkDTO) -> DocumentChunk {
        DocumentChunk(
            id: dto.id,
            documentId: dto.documentId,
            text: dto.text,
            index: dto.chunkIndex,
            isEmbedded: dto.isEmbedded
        )
    }
}
