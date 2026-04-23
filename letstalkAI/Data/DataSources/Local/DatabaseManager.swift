//
//  DatabaseManager.swift
//  letstalkAI
//
//  SQLite database manager for local persistence
//

import Foundation
import SQLite

final class DatabaseManager: @unchecked Sendable {
    private var db: Connection?
    
    private let chatSessions = Table("chat_sessions")
    private let chatMessages = Table("chat_messages")
    private let documents = Table("documents")
    private let documentChunks = Table("document_chunks")
    
    private let sessionId = Expression<String>("id")
    private let sessionTitle = Expression<String>("title")
    private let sessionCollectionName = Expression<String>("collection_name")
    private let sessionCreatedAt = Expression<Date>("created_at")
    private let sessionUpdatedAt = Expression<Date>("updated_at")
    private let sessionUseWebSearch = Expression<Bool>("use_web_search")
    private let transcriptEntryJSON = Expression<String>("transcript_entry_json")
    
    private let messageId = Expression<String>("id")
    private let messageSessionId = Expression<String>("session_id")
    private let messageText = Expression<String>("text")
    private let messageIsUser = Expression<Bool>("is_user")
    private let messageTimestamp = Expression<Date>("timestamp")
    private let messageSources = Expression<String?>("sources")
    
    private let documentId = Expression<String>("id")
    private let documentSessionId = Expression<String>("session_id")
    private let documentName = Expression<String>("name")
    private let documentPath = Expression<String>("path")
    private let documentType = Expression<String>("type")
    private let documentUploadedAt = Expression<Date>("uploaded_at")
    
    private let chunkId = Expression<String>("id")
    private let chunkDocumentId = Expression<String>("document_id")
    private let chunkText = Expression<String>("text")
    private let chunkIndex = Expression<Int>("chunk_index")
    private let chunkEmbedded = Expression<Bool>("embedded")
    
    init(inMemory: Bool = false) {
        setupDatabase(inMemory: inMemory)
    }
    
    private func setupDatabase(inMemory: Bool) {
        do {
            if inMemory {
                db = try Connection(.inMemory)
            } else {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dbPath = documentsPath.appendingPathComponent("chat_database.sqlite3").path
                db = try Connection(dbPath)
            }
            createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func createTables() {
        do {
            try db?.run(chatSessions.create(ifNotExists: true) { t in
                t.column(sessionId, primaryKey: true)
                t.column(sessionTitle)
                t.column(sessionCollectionName)
                t.column(sessionCreatedAt)
                t.column(sessionUpdatedAt)
                t.column(sessionUseWebSearch, defaultValue: false)
                t.column(transcriptEntryJSON, defaultValue: "")
            })
            
            runMigrations()
            
            try db?.run(chatMessages.create(ifNotExists: true) { t in
                t.column(messageId, primaryKey: true)
                t.column(messageSessionId)
                t.column(messageText)
                t.column(messageIsUser)
                t.column(messageTimestamp)
                t.column(messageSources)
                t.foreignKey(messageSessionId, references: chatSessions, sessionId, delete: .cascade)
            })
            
            try db?.run(documents.create(ifNotExists: true) { t in
                t.column(documentId, primaryKey: true)
                t.column(documentSessionId)
                t.column(documentName)
                t.column(documentPath)
                t.column(documentType)
                t.column(documentUploadedAt)
                t.foreignKey(documentSessionId, references: chatSessions, sessionId, delete: .cascade)
            })
            
            try db?.run(documentChunks.create(ifNotExists: true) { t in
                t.column(chunkId, primaryKey: true)
                t.column(chunkDocumentId)
                t.column(chunkText)
                t.column(chunkIndex)
                t.column(chunkEmbedded, defaultValue: false)
                t.foreignKey(chunkDocumentId, references: documents, documentId, delete: .cascade)
            })
        } catch {
            print("Create tables error: \(error)")
        }
    }
    
    private func runMigrations() {
        do {
            let pragma = try db?.prepare("PRAGMA table_info(chat_sessions)")
            let columns = pragma?.compactMap { row in
                row[1] as? String
            } ?? []
            
            if !columns.contains("use_web_search") {
                try db?.run("ALTER TABLE chat_sessions ADD COLUMN use_web_search BOOLEAN DEFAULT 0")
            }
            
            if !columns.contains("transcript_entry_json") {
                try db?.run("ALTER TABLE chat_sessions ADD COLUMN transcript_entry_json TEXT DEFAULT ''")
            }
        } catch {
            print("Migration error: \(error)")
        }
    }
    
    // MARK: - Chat Sessions
    
    func createChatSession(_ dto: ChatSessionDTO) throws -> ChatSessionDTO {
        let insert = chatSessions.insert(
            sessionId <- dto.id,
            sessionTitle <- dto.title,
            sessionCollectionName <- dto.collectionName,
            sessionCreatedAt <- dto.createdAt,
            sessionUpdatedAt <- dto.updatedAt,
            sessionUseWebSearch <- dto.useWebSearch
        )
        try db?.run(insert)
        return dto
    }
    
    func getAllChatSessions() throws -> [ChatSessionDTO] {
        let sessions = try db?.prepare(chatSessions.order(sessionUpdatedAt.desc))
        return sessions?.compactMap { row in
            ChatSessionDTO(
                id: row[sessionId],
                title: row[sessionTitle],
                collectionName: row[sessionCollectionName],
                createdAt: row[sessionCreatedAt],
                updatedAt: row[sessionUpdatedAt],
                useWebSearch: row[sessionUseWebSearch],
                transcriptJSON: row[transcriptEntryJSON]
            )
        } ?? []
    }
    
    func getChatSession(by id: String) throws -> ChatSessionDTO? {
        let query = chatSessions.filter(sessionId == id)
        guard let row = try db?.pluck(query) else { return nil }
        return ChatSessionDTO(
            id: row[sessionId],
            title: row[sessionTitle],
            collectionName: row[sessionCollectionName],
            createdAt: row[sessionCreatedAt],
            updatedAt: row[sessionUpdatedAt],
            useWebSearch: row[sessionUseWebSearch],
            transcriptJSON: row[transcriptEntryJSON]
        )
    }
    
    func updateChatSession(_ dto: ChatSessionDTO) throws {
        let sessionRow = chatSessions.filter(sessionId == dto.id)
        try db?.run(sessionRow.update(
            sessionTitle <- dto.title,
            sessionUpdatedAt <- Date(),
            sessionUseWebSearch <- dto.useWebSearch
        ))
    }
    
    func updateChatSessionTitle(_ id: String, title: String) throws {
        let sessionRow = chatSessions.filter(sessionId == id)
        try db?.run(sessionRow.update(
            sessionTitle <- title,
            sessionUpdatedAt <- Date()
        ))
    }
    
    func updateChatSessionWebSearch(_ id: String, useWebSearch: Bool) throws {
        let sessionRow = chatSessions.filter(sessionId == id)
        try db?.run(sessionRow.update(
            sessionUseWebSearch <- useWebSearch,
            sessionUpdatedAt <- Date()
        ))
    }
    
    func deleteChatSession(_ id: String) throws {
        let sessionRow = chatSessions.filter(sessionId == id)
        try db?.run(sessionRow.delete())
    }
    
    func deleteChatSessions(_ ids: Set<String>) throws {
        for id in ids {
            try deleteChatSession(id)
        }
    }
    
    func saveTranscriptJSON(_ jsonString: String, sessionId id: String) throws {
        let sessionRow = chatSessions.filter(sessionId == id)
        try db?.run(sessionRow.update(
            transcriptEntryJSON <- jsonString,
            sessionUpdatedAt <- Date()
        ))
    }
    
    func loadTranscriptJSON(for id: String) throws -> String? {
        let sessionRow = chatSessions.filter(sessionId == id)
        if let session = try db?.pluck(sessionRow) {
            let json = session[transcriptEntryJSON]
            return json.isEmpty ? nil : json
        }
        return nil
    }
    
    // MARK: - Chat Messages
    
    func saveMessage(_ dto: ChatMessageDTO) throws {
        let insert = chatMessages.insert(
            messageId <- dto.id,
            messageSessionId <- dto.sessionId,
            messageText <- dto.text,
            messageIsUser <- dto.isUser,
            messageTimestamp <- dto.timestamp,
            messageSources <- dto.sourcesJSON
        )
        try db?.run(insert)
    }
    
    func getMessages(for sessionIdValue: String) throws -> [ChatMessageDTO] {
        let messages = try db?.prepare(
            chatMessages
                .filter(messageSessionId == sessionIdValue)
                .order(messageTimestamp.asc)
        )
        
        return messages?.compactMap { row in
            ChatMessageDTO(
                id: row[messageId],
                sessionId: row[messageSessionId],
                text: row[messageText],
                isUser: row[messageIsUser],
                timestamp: row[messageTimestamp],
                sourcesJSON: row[messageSources]
            )
        } ?? []
    }
    
    func deleteMessages(for sessionIdValue: String) throws {
        let sessionMessages = chatMessages.filter(messageSessionId == sessionIdValue)
        try db?.run(sessionMessages.delete())
    }
    
    // MARK: - Documents
    
    func saveDocument(_ dto: DocumentDTO) throws -> String {
        let insert = documents.insert(
            documentId <- dto.id,
            documentSessionId <- dto.sessionId,
            documentName <- dto.name,
            documentPath <- dto.path,
            documentType <- dto.type,
            documentUploadedAt <- dto.uploadedAt
        )
        try db?.run(insert)
        return dto.id
    }
    
    func getDocuments(for sessionIdValue: String) throws -> [DocumentDTO] {
        let docs = try db?.prepare(
            documents
                .filter(documentSessionId == sessionIdValue)
                .order(documentUploadedAt.desc)
        )
        
        return docs?.map { row in
            DocumentDTO(
                id: row[documentId],
                sessionId: row[documentSessionId],
                name: row[documentName],
                path: row[documentPath],
                type: row[documentType],
                uploadedAt: row[documentUploadedAt]
            )
        } ?? []
    }
    
    func hasDocuments(for sessionIdValue: String) throws -> Bool {
        let count = try db?.scalar(documents.filter(documentSessionId == sessionIdValue).count) ?? 0
        return count > 0
    }
    
    func saveDocumentChunk(_ dto: DocumentChunkDTO) throws -> String {
        let insert = documentChunks.insert(
            chunkId <- dto.id,
            chunkDocumentId <- dto.documentId,
            chunkText <- dto.text,
            chunkIndex <- dto.chunkIndex,
            chunkEmbedded <- dto.isEmbedded
        )
        try db?.run(insert)
        return dto.id
    }
    
    func getUnembeddedChunks(for sessionIdValue: String) throws -> [DocumentChunkDTO] {
        let chunks = try db?.prepare(
            documentChunks
                .join(documents, on: chunkDocumentId == documentId)
                .filter(documentSessionId == sessionIdValue && chunkEmbedded == false)
                .order(chunkIndex.asc)
        )
        
        return chunks?.map { row in
            DocumentChunkDTO(
                id: row[chunkId],
                documentId: row[chunkDocumentId],
                text: row[chunkText],
                chunkIndex: row[chunkIndex],
                isEmbedded: row[chunkEmbedded]
            )
        } ?? []
    }
    
    func markChunkAsEmbedded(_ id: String) throws {
        let chunk = documentChunks.filter(chunkId == id)
        try db?.run(chunk.update(chunkEmbedded <- true))
    }
}
