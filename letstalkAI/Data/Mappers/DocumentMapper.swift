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
            pageIndex: chunk.pageIndex,
            isEmbedded: chunk.isEmbedded
        )
    }
    
    func chunkToDomain(_ dto: DocumentChunkDTO) -> DocumentChunk {
        DocumentChunk(
            id: dto.id,
            documentId: dto.documentId,
            text: dto.text,
            index: dto.chunkIndex,
            pageIndex: dto.pageIndex,
            isEmbedded: dto.isEmbedded
        )
    }
    
    func imageToDTO(_ image: DocumentImage) -> DocumentImageDTO {
        DocumentImageDTO(
            id: image.id,
            documentId: image.documentId,
            pageIndex: image.pageIndex,
            imagePath: image.imagePath,
            ocrText: image.ocrText,
            classificationLabels: image.classificationLabels
        )
    }
    
    func imageToDomain(_ dto: DocumentImageDTO) -> DocumentImage {
        DocumentImage(
            id: dto.id,
            documentId: dto.documentId,
            pageIndex: dto.pageIndex,
            imagePath: dto.imagePath,
            ocrText: dto.ocrText,
            classificationLabels: dto.classificationLabels
        )
    }
}
