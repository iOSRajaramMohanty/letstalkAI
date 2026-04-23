//
//  SendMessageUseCase.swift
//  letstalkAI
//
//  Domain Use Case - Orchestrates sending messages with intelligent routing
//

import Foundation

protocol SendMessageUseCaseProtocol: Sendable {
    func execute(
        message: String,
        session: ChatSession,
        onStreamUpdate: @escaping @Sendable (String) -> Void
    ) async throws -> ChatMessage
}

final class SendMessageUseCase: SendMessageUseCaseProtocol, @unchecked Sendable {
    private let chatRepository: ChatRepositoryProtocol
    private let llmRepository: LLMRepositoryProtocol
    private let ragRepository: RAGRepositoryProtocol
    private let webSearchRepository: WebSearchRepositoryProtocol
    private let documentRepository: DocumentRepositoryProtocol
    
    init(
        chatRepository: ChatRepositoryProtocol,
        llmRepository: LLMRepositoryProtocol,
        ragRepository: RAGRepositoryProtocol,
        webSearchRepository: WebSearchRepositoryProtocol,
        documentRepository: DocumentRepositoryProtocol
    ) {
        self.chatRepository = chatRepository
        self.llmRepository = llmRepository
        self.ragRepository = ragRepository
        self.webSearchRepository = webSearchRepository
        self.documentRepository = documentRepository
    }
    
    func execute(
        message: String,
        session: ChatSession,
        onStreamUpdate: @escaping @Sendable (String) -> Void
    ) async throws -> ChatMessage {
        let userMessage = ChatMessage(text: message, isUser: true)
        try await chatRepository.saveMessage(userMessage, sessionId: session.id)
        
        await llmRepository.getOrCreateSession(sessionId: session.id)
        
        let (prompt, sources) = try await buildPromptWithContext(
            query: message,
            session: session
        )
        
        var fullResponse = ""
        var llmFailed = false
        
        do {
            let stream = llmRepository.generateResponse(prompt: prompt, sessionId: session.id)
            
            for try await partialResponse in stream {
                fullResponse = partialResponse
                onStreamUpdate(partialResponse)
            }
        } catch {
            llmFailed = true
            
            if let sources = sources, !sources.isEmpty {
                fullResponse = buildFallbackResponseFromSources(query: message, sources: sources)
                onStreamUpdate(fullResponse)
            } else {
                throw error
            }
        }
        
        let assistantMessage = ChatMessage(
            text: fullResponse,
            isUser: false,
            sources: sources
        )
        try await chatRepository.saveMessage(assistantMessage, sessionId: session.id)
        
        if !llmFailed {
            if let transcriptJSON = try await llmRepository.saveTranscript(sessionId: session.id) {
                let sessionRepo = await MainActor.run { DependencyContainer.shared.sessionRepository }
                try await sessionRepo.saveTranscript(transcriptJSON, sessionId: session.id)
            }
        }
        
        return assistantMessage
    }
    
    private func buildFallbackResponseFromSources(query: String, sources: [WebSearchResult]) -> String {
        var response = "Here's what I found from web search:\n\n"
        
        for (index, source) in sources.enumerated() {
            response += "**\(index + 1). \(source.title)**\n"
            
            let contentPreview = String(source.content.prefix(300))
            let cleanedContent = contentPreview
                .replacingOccurrences(of: "\n\n", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanedContent.isEmpty {
                response += "\(cleanedContent)"
                if source.content.count > 300 {
                    response += "..."
                }
                response += "\n\n"
            }
        }
        
        response += "_Note: Apple Intelligence is not available. Showing raw search results. For AI-powered summaries, please use a device with Apple Intelligence enabled._"
        
        return response
    }
    
    private func buildPromptWithContext(
        query: String,
        session: ChatSession
    ) async throws -> (prompt: String, sources: [WebSearchResult]?) {
        if session.useWebSearch {
            return try await buildWebSearchPrompt(query: query, session: session)
        }
        
        let hasDocuments = await documentRepository.hasDocuments(for: session.id)
        if hasDocuments {
            return try await buildRAGPrompt(query: query, session: session)
        }
        
        return (buildGeneralPrompt(query: query), nil)
    }
    
    private func buildWebSearchPrompt(
        query: String,
        session: ChatSession
    ) async throws -> (prompt: String, sources: [WebSearchResult]) {
        let results = try await webSearchRepository.searchAndScrape(query: query)
        
        guard !results.isEmpty else {
            throw LLMError.generationFailed("No web search results found for your query.")
        }
        
        try await ragRepository.loadCollection(name: session.collectionName)
        
        for result in results {
            let chunks = webSearchRepository.chunkText(result.content, maxLength: 1000, overlapTokens: 100)
            for chunk in chunks {
                try await ragRepository.addEntry(chunk, collectionName: session.collectionName)
            }
        }
        
        let neighbors = try await ragRepository.findNeighbors(
            query: query,
            collectionName: session.collectionName,
            count: 3
        )
        
        let semanticContext = neighbors.map { neighbor in
            "Relevance Score: \(String(format: "%.3f", neighbor.score))\n\(neighbor.text)"
        }.joined(separator: "\n\n---\n\n")
        
        let prompt = """
        You are a helpful assistant that answers questions based on semantically relevant web search results.
        
        Most Relevant Web Content (ranked by semantic similarity):
        \(semanticContext)
        
        Question: \(query)
        
        Instructions:
        1. Answer based primarily on the most relevant content above (higher relevance scores are more important)
        2. Be accurate and cite the sources when possible
        3. If the content doesn't fully answer the question, acknowledge the limitations
        4. Provide a comprehensive and informative response based on the available information
        
        Answer:
        """
        
        return (prompt, results)
    }
    
    private func buildRAGPrompt(
        query: String,
        session: ChatSession
    ) async throws -> (prompt: String, sources: [WebSearchResult]?) {
        try await ragRepository.loadCollection(name: session.collectionName)
        
        let neighbors = try await ragRepository.findNeighbors(
            query: query,
            collectionName: session.collectionName,
            count: 3
        )
        
        let contextItems = neighbors.map { "- \($0.text)" }.joined(separator: "\n")
        
        let prompt = """
        You are a helpful assistant that answers questions based on the provided context from uploaded documents and knowledge base.
        
        Context:
        \(contextItems)
        
        Question: \(query)
        
        Instructions:
        1. Answer based primarily on the information provided in the context above
        2. If the context contains relevant information from uploaded documents, prioritize that
        3. If the context doesn't contain enough information, say so clearly
        4. Be concise and accurate
        
        Answer:
        """
        
        return (prompt, nil)
    }
    
    private func buildGeneralPrompt(query: String) -> String {
        """
        You are a helpful assistant. Answer the following question based on your general knowledge and training.
        
        Question: \(query)
        
        Instructions:
        1. Provide a helpful and accurate response based on your general knowledge
        2. Be concise and informative
        3. If you're not certain about something, mention that
        4. Use a conversational tone
        
        Answer:
        """
    }
}
