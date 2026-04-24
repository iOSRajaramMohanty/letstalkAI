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
    private let documentImages = Table("document_images")
    private let queryLearning = Table("query_learning")
    
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
    private let messageImageURLs = Expression<String?>("image_urls")
    
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
    private let chunkPageIndex = Expression<Int?>("page_index")
    
    private let imageId = Expression<String>("id")
    private let imageDocumentId = Expression<String>("document_id")
    private let imagePageIndex = Expression<Int>("page_index")
    private let imagePath = Expression<String>("image_path")
    private let imageOcrText = Expression<String>("ocr_text")
    private let imageClassificationLabels = Expression<String>("classification_labels")
    
    private let learningId = Expression<String>("id")
    private let learningQueryWord = Expression<String>("query_word")
    private let learningMatchedLabel = Expression<String>("matched_label")
    private let learningSuccessCount = Expression<Int>("success_count")
    private let learningLastUsed = Expression<Date>("last_used")
    
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
                t.column(messageImageURLs)
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
                t.column(chunkPageIndex)
                t.foreignKey(chunkDocumentId, references: documents, documentId, delete: .cascade)
            })
            
            try db?.run(documentImages.create(ifNotExists: true) { t in
                t.column(imageId, primaryKey: true)
                t.column(imageDocumentId)
                t.column(imagePageIndex)
                t.column(imagePath)
                t.column(imageOcrText, defaultValue: "")
                t.column(imageClassificationLabels, defaultValue: "")
                t.foreignKey(imageDocumentId, references: documents, documentId, delete: .cascade)
            })
            
            try db?.run(queryLearning.create(ifNotExists: true) { t in
                t.column(learningId, primaryKey: true)
                t.column(learningQueryWord)
                t.column(learningMatchedLabel)
                t.column(learningSuccessCount, defaultValue: 1)
                t.column(learningLastUsed)
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
            
            let imagePragma = try db?.prepare("PRAGMA table_info(document_images)")
            let imageColumns = imagePragma?.compactMap { row in
                row[1] as? String
            } ?? []
            
            if !imageColumns.contains("ocr_text") {
                try db?.run("ALTER TABLE document_images ADD COLUMN ocr_text TEXT DEFAULT ''")
                print("   📦 [Migration] Added ocr_text column to document_images")
            }
            
            if !imageColumns.contains("classification_labels") {
                try db?.run("ALTER TABLE document_images ADD COLUMN classification_labels TEXT DEFAULT ''")
                print("   📦 [Migration] Added classification_labels column to document_images")
            }
            
            let messagePragma = try db?.prepare("PRAGMA table_info(chat_messages)")
            let messageColumns = messagePragma?.compactMap { row in
                row[1] as? String
            } ?? []
            
            if !messageColumns.contains("image_urls") {
                try db?.run("ALTER TABLE chat_messages ADD COLUMN image_urls TEXT")
                print("   📦 [Migration] Added image_urls column to chat_messages")
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
            messageSources <- dto.sourcesJSON,
            messageImageURLs <- dto.imageURLsJSON
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
                sourcesJSON: row[messageSources],
                imageURLsJSON: row[messageImageURLs]
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
    
    func getDocument(by id: String) throws -> DocumentDTO? {
        let query = documents.filter(documentId == id)
        guard let row = try db?.pluck(query) else { return nil }
        return DocumentDTO(
            id: row[documentId],
            sessionId: row[documentSessionId],
            name: row[documentName],
            path: row[documentPath],
            type: row[documentType],
            uploadedAt: row[documentUploadedAt]
        )
    }
    
    func deleteDocument(_ id: String) throws {
        let documentRow = documents.filter(documentId == id)
        try db?.run(documentRow.delete())
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
    
    // MARK: - Document Images
    
    func saveDocumentImage(_ dto: DocumentImageDTO) throws -> String {
        let labelsString = dto.classificationLabels.joined(separator: "|")
        let insert = documentImages.insert(
            imageId <- dto.id,
            imageDocumentId <- dto.documentId,
            imagePageIndex <- dto.pageIndex,
            imagePath <- dto.imagePath,
            imageOcrText <- dto.ocrText,
            imageClassificationLabels <- labelsString
        )
        try db?.run(insert)
        return dto.id
    }
    
    func getImagesForDocument(_ documentIdValue: String) throws -> [DocumentImageDTO] {
        let images = try db?.prepare(
            documentImages
                .filter(imageDocumentId == documentIdValue)
                .order(imagePageIndex.asc)
        )
        
        return images?.map { row in
            let labelsString = row[imageClassificationLabels]
            let labels = labelsString.isEmpty ? [] : labelsString.split(separator: "|").map(String.init)
            return DocumentImageDTO(
                id: row[imageId],
                documentId: row[imageDocumentId],
                pageIndex: row[imagePageIndex],
                imagePath: row[imagePath],
                ocrText: row[imageOcrText],
                classificationLabels: labels
            )
        } ?? []
    }
    
    func getImagesForPage(documentId documentIdValue: String, pageIndex pageIndexValue: Int) throws -> [DocumentImageDTO] {
        let images = try db?.prepare(
            documentImages
                .filter(imageDocumentId == documentIdValue && imagePageIndex == pageIndexValue)
        )
        
        return images?.map { row in
            let labelsString = row[imageClassificationLabels]
            let labels = labelsString.isEmpty ? [] : labelsString.split(separator: "|").map(String.init)
            return DocumentImageDTO(
                id: row[imageId],
                documentId: row[imageDocumentId],
                pageIndex: row[imagePageIndex],
                imagePath: row[imagePath],
                ocrText: row[imageOcrText],
                classificationLabels: labels
            )
        } ?? []
    }
    
    func searchImagesByOCR(query: String, documentId documentIdValue: String) throws -> [DocumentImageDTO] {
        let queryLower = query.lowercased()
        let images = try db?.prepare(
            documentImages
                .filter(imageDocumentId == documentIdValue)
                .order(imagePageIndex.asc)
        )
        
        return images?.compactMap { row -> DocumentImageDTO? in
            let ocrText = row[imageOcrText].lowercased()
            let queryWords = queryLower.split(separator: " ").map(String.init)
            let hasMatch = queryWords.contains { word in
                ocrText.contains(word) && word.count > 2
            }
            
            if hasMatch {
                let labelsString = row[imageClassificationLabels]
                let labels = labelsString.isEmpty ? [] : labelsString.split(separator: "|").map(String.init)
                return DocumentImageDTO(
                    id: row[imageId],
                    documentId: row[imageDocumentId],
                    pageIndex: row[imagePageIndex],
                    imagePath: row[imagePath],
                    ocrText: row[imageOcrText],
                    classificationLabels: labels
                )
            }
            return nil
        } ?? []
    }
    
    func deleteImagesForDocument(_ documentIdValue: String) throws {
        let images = documentImages.filter(imageDocumentId == documentIdValue)
        try db?.run(images.delete())
    }
    
    // MARK: - Query Learning
    
    func learnQueryLabelMapping(queryWord: String, matchedLabel: String) throws {
        let queryWordLower = queryWord.lowercased()
        let labelLower = matchedLabel.lowercased()
        
        let existing = queryLearning.filter(learningQueryWord == queryWordLower && learningMatchedLabel == labelLower)
        
        if let row = try db?.pluck(existing) {
            let currentCount = row[learningSuccessCount]
            try db?.run(existing.update(
                learningSuccessCount <- currentCount + 1,
                learningLastUsed <- Date()
            ))
        } else {
            let insert = queryLearning.insert(
                learningId <- UUID().uuidString,
                learningQueryWord <- queryWordLower,
                learningMatchedLabel <- labelLower,
                learningSuccessCount <- 1,
                learningLastUsed <- Date()
            )
            try db?.run(insert)
        }
    }
    
    func getLearnedLabelsForQuery(_ queryWord: String) throws -> [(label: String, score: Int)] {
        let queryWordLower = queryWord.lowercased()
        
        let results = try db?.prepare(
            queryLearning
                .filter(learningQueryWord == queryWordLower)
                .order(learningSuccessCount.desc)
                .limit(10)
        )
        
        return results?.map { row in
            (label: row[learningMatchedLabel], score: row[learningSuccessCount])
        } ?? []
    }
    
    func getAllLearnedMappings() throws -> [(queryWord: String, label: String, score: Int)] {
        let results = try db?.prepare(
            queryLearning.order(learningSuccessCount.desc).limit(100)
        )
        
        return results?.map { row in
            (queryWord: row[learningQueryWord], label: row[learningMatchedLabel], score: row[learningSuccessCount])
        } ?? []
    }
}
