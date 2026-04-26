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
        
        let (prompt, sources, imageURLs) = try await buildPromptWithContext(
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
            sources: sources,
            imageURLs: imageURLs
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
    ) async throws -> (prompt: String, sources: [WebSearchResult]?, imageURLs: [URL]?) {
        // Check for greetings/casual chat first - skip web search for these
        if isGreetingOrCasualChat(query: query) {
            print("👋 [Chat] Detected greeting/casual chat - skipping web search")
            return (buildGreetingOrCasualPrompt(query: query), nil, nil)
        }
        
        if session.useWebSearch {
            let (prompt, sources) = try await buildWebSearchPrompt(query: query, session: session)
            return (prompt, sources, nil)
        }
        
        let hasDocuments = await documentRepository.hasDocuments(for: session.id)
        if hasDocuments {
            return try await buildRAGPrompt(query: query, session: session)
        }
        
        return (buildGeneralPrompt(query: query), nil, nil)
    }
    
    /// Detects if the query is a simple greeting or casual chat
    private func isGreetingOrCasualChat(query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let greetings = ["hi", "hello", "hey", "hola", "namaste", "good morning", "good afternoon", 
                         "good evening", "howdy", "sup", "what's up", "whats up", "yo", "hii", "hiii",
                         "hi there", "hello there", "hey there"]
        
        let casualPhrases = ["how are you", "how r u", "how're you", "thank you", "thanks", 
                             "bye", "goodbye", "see you", "nice to meet", "who are you", 
                             "what's your name", "what is your name", "what can you do"]
        
        // Exact match for short greetings
        if greetings.contains(q) {
            return true
        }
        
        // Prefix match (e.g., "hi!" or "hello, how are you")
        for greeting in greetings {
            if q.hasPrefix(greeting + " ") || q.hasPrefix(greeting + "!") || 
               q.hasPrefix(greeting + ",") || q.hasPrefix(greeting + ".") {
                return true
            }
        }
        
        // Contains casual phrases
        for phrase in casualPhrases {
            if q.contains(phrase) {
                return true
            }
        }
        
        return false
    }
    
    /// Builds a prompt for greetings and casual conversation
    private func buildGreetingOrCasualPrompt(query: String) -> String {
        return """
        You are a friendly AI assistant. Respond naturally and warmly to the user.
        
        RULES:
        - Be friendly, warm, and conversational
        - Keep responses brief (1-3 sentences)
        - If greeted, greet back and offer to help
        - If asked who you are, say you're a helpful AI assistant
        - Do NOT search for information or provide facts
        - Just have a natural conversation
        
        User says: \(query)
        
        Your friendly response:
        """
    }
    
    private func buildWebSearchPrompt(
        query: String,
        session: ChatSession
    ) async throws -> (prompt: String, sources: [WebSearchResult]) {
        let results = try await webSearchRepository.searchAndScrape(query: query)
        
        guard !results.isEmpty else {
            throw LLMError.generationFailed("No web search results found for your query.")
        }
        
        // Try to use RAG for better context selection, fallback to raw results if embedding fails
        var semanticContext: String
        
        do {
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
            
            let maxContextLength = 1500
            semanticContext = neighbors.map { neighbor -> String in
                let text = neighbor.text
                if text.count > maxContextLength {
                    return String(text.prefix(maxContextLength)) + "..."
                }
                return text
            }.joined(separator: "\n")
            
            print("🌐 [Web] Using RAG context: \(semanticContext.count) characters")
            
        } catch {
            // Fallback: Use raw web results directly without RAG
            print("⚠️ [Web] RAG failed (\(error.localizedDescription)), using raw web results")
            
            let maxContentLength = 1000
            semanticContext = results.prefix(3).map { result -> String in
                let content = result.content.prefix(maxContentLength)
                return "**\(result.title)**\n\(content)\(result.content.count > maxContentLength ? "..." : "")"
            }.joined(separator: "\n\n")
            
            print("🌐 [Web] Using raw context: \(semanticContext.count) characters")
        }
        
        let prompt = """
        You are a helpful AI assistant with access to real-time web search results.
        
        IMPORTANT INSTRUCTIONS:
        - Answer the user's question using ONLY the web search results provided below
        - The web search was performed just now, so this information is current and up-to-date
        - Do NOT say you don't have real-time information - you DO have it from the web search below
        - Do NOT say you were trained until a certain date - use the web context provided
        - If the web results contain the answer, provide it directly and confidently
        - Be concise and helpful
        
        WEB SEARCH RESULTS (current as of today):
        \(semanticContext)
        
        User's Question: \(query)
        
        Your answer based on the web search results above:
        """
        
        print("📝 [Web] Final prompt length: \(prompt.count) characters")
        
        return (prompt, results)
    }
    
    private func buildRAGPrompt(
        query: String,
        session: ChatSession
    ) async throws -> (prompt: String, sources: [WebSearchResult]?, imageURLs: [URL]?) {
        try await ragRepository.loadCollection(name: session.collectionName)
        
        let neighbors = try await ragRepository.findNeighbors(
            query: query,
            collectionName: session.collectionName,
            count: 3
        )
        
        let maxContextLength = 2500
        var pageIndices: Set<Int> = []
        
        let contextItems = neighbors.map { neighbor -> String in
            let text = neighbor.text
            
            if text.contains("[Image Page") {
                let imagePageIndices = extractImagePageIndices(from: text)
                pageIndices.formUnion(imagePageIndices)
            }
            
            let foundPages = extractAllPageIndices(from: text)
            pageIndices.formUnion(foundPages)
            
            if text.count > maxContextLength {
                return String(text.prefix(maxContextLength)) + "..."
            }
            return text
        }.joined(separator: "\n")
        
        let queryWordsForLearning = query.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 }
        let stopWordsForLearning = Set(["can", "you", "give", "me", "the", "what", "how", "show", "display", "see"])
        let meaningfulWordsForLearning = queryWordsForLearning.filter { !stopWordsForLearning.contains($0) }
        await loadLearnedMappings(for: meaningfulWordsForLearning)
        
        var candidateImages: [(image: DocumentImage, score: Int)] = []
        let documents = try await documentRepository.getDocuments(for: session.id)
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 [Image Query] Documents in session: \(documents.count)")
        print("🧠 [Learning] Loaded mappings for: \(meaningfulWordsForLearning.joined(separator: ", "))")
        
        var totalImagesInDB = 0
        var filteredOut = 0
        
        var documentLabelIndex: Set<String> = []
        
        for document in documents {
            let allImages = try await documentRepository.getImagesForDocument(document.id)
            totalImagesInDB += allImages.count
            print("   📄 Document: \(document.name)")
            print("   🖼️ Images in database: \(allImages.count)")
            
            for image in allImages {
                documentLabelIndex.formUnion(image.classificationLabels.map { $0.lowercased() })
                
                if isQRCodeOrIrrelevant(image) {
                    filteredOut += 1
                    continue
                }
                
                let score = calculateImageRelevance(image: image, query: query, context: contextItems, pageIndices: pageIndices, documentLabels: documentLabelIndex)
                candidateImages.append((image, score))
            }
        }
        
        print("   🏷️ Document label index: \(documentLabelIndex.prefix(10).joined(separator: ", "))...")
        
        print("   📊 Total images in DB: \(totalImagesInDB)")
        print("   🚫 Filtered out (QR/irrelevant): \(filteredOut)")
        print("   ✅ Candidate images: \(candidateImages.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let selectedImages = selectDiverseImages(from: candidateImages, query: query)
        
        var imageURLs: [URL] = []
        
        let queryWords = query.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 }
        let stopWords = Set(["can", "you", "give", "me", "the", "what", "how", "show", "display", "see"])
        let meaningfulQueryWords = queryWords.filter { !stopWords.contains($0) }
        
        for (image, score) in selectedImages {
            let url = URL(fileURLWithPath: image.imagePath)
            if FileManager.default.fileExists(atPath: image.imagePath) && !imageURLs.contains(url) {
                imageURLs.append(url)
                let labelsPreview = image.classificationLabels.prefix(3).joined(separator: ", ")
                print("🖼️ [RAG] Selected image (score: \(score)): page \(image.pageIndex + 1), labels: [\(labelsPreview)], OCR: \"\(image.ocrText.prefix(20))...\"")
                
                if score >= 40 {
                    Task {
                        await learnFromSuccessfulMatch(queryWords: meaningfulQueryWords, imageLabels: image.classificationLabels)
                    }
                }
            }
        }
        
        if candidateImages.isEmpty {
            print("🖼️ [RAG] No relevant images found for this query - query topic not in document")
        }
        
        let totalContextLength = contextItems.count
        print("📚 [RAG] Context length: \(totalContextLength) characters (max: \(maxContextLength))")
        print("🖼️ [RAG] Selected \(imageURLs.count) relevant images")
        
        var imageDescriptions = ""
        for (image, _) in selectedImages.prefix(6) {
            let semanticDesc = getSemanticDescription(labels: image.classificationLabels)
            if !semanticDesc.isEmpty {
                imageDescriptions += "- \(semanticDesc)\n"
            }
        }
        
        if imageDescriptions.isEmpty && !selectedImages.isEmpty {
            imageDescriptions = "- Images from the uploaded document\n"
        }
        
        let hasEntityMismatch = detectEntityMismatch(query: query, context: contextItems)
        
        if hasEntityMismatch {
            print("⚠️ [RAG] Entity mismatch detected - hiding document images")
            imageURLs = []
        }
        
        let queryType = detectQueryType(query)
        let isVisualQuery = isQueryVisual(query: query)
        
        if !isVisualQuery {
            print("📝 [RAG] Non-visual query detected - hiding images (query: '\(query)')")
            imageURLs = []
        }
        
        let hasImages = !imageURLs.isEmpty && !hasEntityMismatch && isVisualQuery
        let documentNames = documents.map { $0.name }.joined(separator: ", ")
        let prompt = buildSmartPrompt(query: query, context: contextItems, imageDescriptions: (hasEntityMismatch || !isVisualQuery) ? "" : imageDescriptions, queryType: queryType, hasImages: hasImages, documentName: documentNames)
        
        print("📝 [RAG] Final prompt length: \(prompt.count) characters")
        print("🖼️ [RAG] Images will be displayed: \(hasImages ? "YES (\(imageURLs.count))" : "NO (visual query: \(isVisualQuery))")")
        
        return (prompt, nil, imageURLs.isEmpty ? nil : imageURLs)
    }
    
    /// Detects if user is asking about a specific entity (brand, product, name) not present in the document
    private func detectEntityMismatch(query: String, context: String) -> Bool {
        let contextLower = context.lowercased()
        
        // Extract capitalized proper nouns from query (potential entity names)
        let properNounPattern = try? NSRegularExpression(pattern: "\\b[A-Z][a-z]+(?:\\s+[A-Z][a-z]+)*\\b", options: [])
        var queryEntities: [String] = []
        
        if let regex = properNounPattern {
            let matches = regex.matches(in: query, options: [], range: NSRange(query.startIndex..., in: query))
            for match in matches {
                if let range = Range(match.range, in: query) {
                    let entity = String(query[range]).lowercased()
                    // Skip common words that might be capitalized at sentence start
                    let skipWords = Set(["the", "this", "that", "what", "how", "can", "show", "tell", "please", "give", "find", "does", "about", "where", "when", "which", "who", "why"])
                    if entity.count > 2 && !skipWords.contains(entity) {
                        queryEntities.append(entity)
                    }
                }
            }
        }
        
        // Check if query entities exist in document context
        for entity in queryEntities {
            if !contextLower.contains(entity) {
                // Entity mentioned in query but not in document
                print("⚠️ [RAG] User asked about '\(entity)' but it's not found in the document context")
                return true
            }
        }
        
        return false
    }
    
    private enum QueryType {
        case visual
        case general
    }
    
    private func detectQueryType(_ query: String) -> QueryType {
        let q = query.lowercased()
        
        let visualWords = ["look", "looks", "looking", "appear", "appearance", "show", "see", "image", "photo", "picture", "design", "style", "color", "colour", "shape", "view", "display", "visual"]
        if visualWords.contains(where: { q.contains($0) }) {
            return .visual
        }
        
        return .general
    }
    
    /// Determines if user query is asking for visual/image content
    private func isQueryVisual(query: String) -> Bool {
        let q = query.lowercased()
        
        // Generic non-visual keywords (text/data focused queries)
        let nonVisualKeywords = [
            // Pricing & numbers
            "price", "cost", "how much", "₹", "$", "rs", "inr", "amount", "total", "fee",
            // Specifications & details
            "specification", "spec", "list", "number", "quantity", "count",
            // Text content
            "summary", "summarize", "overview", "explain", "what is", "define", "meaning",
            "describe", "description", "detail", "information", "info",
            // Questions about facts
            "when", "where", "why", "who", "which",
            // Instructions & processes
            "step", "procedure", "process", "instruction", "guide", "how to",
            // Documents & text
            "term", "clause", "condition", "agreement", "contract", "section",
            "paragraph", "chapter", "page", "content", "text",
            // Transactions
            "invoice", "bill", "payment", "receipt", "order",
            // Comparisons
            "compare", "comparison", "vs", "versus", "difference", "between"
        ]
        
        for keyword in nonVisualKeywords {
            if q.contains(keyword) {
                return false
            }
        }
        
        // Generic visual keywords (asking to see something)
        let visualKeywords = [
            // Direct visual requests
            "show", "show me", "display", "view",
            // Appearance related
            "look", "looks", "looking", "appear", "appearance",
            // Image references
            "see", "image", "photo", "picture", "diagram", "figure", "chart", "graph",
            "illustration", "screenshot", "visual",
            // Design/style
            "design", "style", "color", "colour", "shape", "layout",
            // Position/view
            "front", "back", "side", "top", "bottom",
            // Phrases
            "what does it look", "how does it look", "can i see"
        ]
        
        for keyword in visualKeywords {
            if q.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    private func buildSmartPrompt(query: String, context: String, imageDescriptions: String, queryType: QueryType, hasImages: Bool, documentName: String = "") -> String {
        let conversationType = detectConversationType(query: query, context: context)
        
        switch conversationType {
        case .greeting:
            return buildGreetingPrompt(query: query, documentName: documentName)
        case .casualChat:
            return buildCasualChatPrompt(query: query)
        case .documentRelated:
            return buildDocumentPrompt(query: query, context: context, imageDescriptions: imageDescriptions, hasImages: hasImages, documentName: documentName)
        case .unrelated:
            return buildUnrelatedPrompt(query: query, context: context, documentName: documentName)
        }
    }
    
    private enum ConversationType {
        case greeting
        case casualChat
        case documentRelated
        case unrelated
    }
    
    private func detectConversationType(query: String, context: String) -> ConversationType {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Detect greetings
        let greetings = ["hi", "hello", "hey", "hola", "namaste", "good morning", "good afternoon", "good evening", "howdy", "sup", "what's up", "whats up"]
        if greetings.contains(q) || greetings.contains(where: { q.hasPrefix($0 + " ") || q.hasPrefix($0 + "!") || q.hasPrefix($0 + ",") }) {
            return .greeting
        }
        
        // Detect casual chat (how are you, thanks, etc.)
        let casualPhrases = ["how are you", "thank you", "thanks", "bye", "goodbye", "see you", "nice to meet", "who are you", "what's your name", "what is your name"]
        if casualPhrases.contains(where: { q.contains($0) }) {
            return .casualChat
        }
        
        // Check if query seems related to document context
        let contextLower = context.lowercased()
        let queryWords = q.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let stopWords = Set(["the", "and", "for", "are", "what", "how", "can", "you", "tell", "about", "this", "that", "with", "from"])
        let meaningfulWords = queryWords.filter { !stopWords.contains($0) }
        
        // Check if any meaningful query words appear in context
        let hasContextMatch = meaningfulWords.contains { word in
            contextLower.contains(word)
        }
        
        // Also check for document-related intent words
        let documentIntentWords = ["document", "pdf", "file", "uploaded", "attached", "show", "explain", "summarize", "tell me about"]
        let hasDocumentIntent = documentIntentWords.contains(where: { q.contains($0) })
        
        if hasContextMatch || hasDocumentIntent {
            return .documentRelated
        }
        
        return .unrelated
    }
    
    private func buildGreetingPrompt(query: String, documentName: String) -> String {
        let docMention = documentName.isEmpty ? "" : " I see you have \"\(documentName)\" ready - feel free to ask me anything about it!"
        
        return """
        You are a friendly AI assistant. The user is greeting you. Respond warmly and naturally like a helpful human would.
        
        IMPORTANT RULES:
        - Be warm, friendly, and conversational
        - Introduce yourself briefly as a helpful assistant
        - Ask how you can help them today
        - If there's a document, briefly mention you can help with it\(docMention.isEmpty ? "" : " (document: \(documentName))")
        - Keep the response short and natural (2-3 sentences max)
        
        User says: \(query)
        
        Your friendly response:
        """
    }
    
    private func buildCasualChatPrompt(query: String) -> String {
        return """
        You are a friendly AI assistant having a casual conversation. Respond naturally and warmly.
        
        IMPORTANT RULES:
        - Be conversational and friendly
        - Keep responses natural and brief
        - If asked who you are, say you're a helpful AI assistant
        - Do NOT mention documents unless the user asks about them
        
        User says: \(query)
        
        Your response:
        """
    }
    
    private func buildDocumentPrompt(query: String, context: String, imageDescriptions: String, hasImages: Bool, documentName: String = "") -> String {
        var prompt = """
        You are a helpful AI assistant. Answer the user's question based ONLY on the provided document context.
        
        Document Context:
        \(context)
        
        """
        
        if hasImages {
            prompt += "IMAGES ARE DISPLAYED TO USER. Acknowledge what you see.\n"
            if !imageDescriptions.isEmpty {
                prompt += "Image content: \(imageDescriptions)\n"
            }
        }
        
        prompt += """
        
        IMPORTANT RULES:
        - Answer based ONLY on the document context above
        - Be helpful and conversational
        - If asked to show images, describe what's in the document
        - Be concise but thorough
        
        User asks: \(query)
        
        Your helpful response:
        """
        
        return prompt
    }
    
    private func buildUnrelatedPrompt(query: String, context: String, documentName: String = "") -> String {
        // Use document name if available, otherwise extract topic from context
        let documentTopic: String
        if !documentName.isEmpty {
            documentTopic = documentName
        } else {
            documentTopic = extractDocumentTopic(from: context)
        }
        
        return """
        You are a helpful AI assistant. The user has uploaded a document: "\(documentTopic)".
        However, their question seems to be about a different topic.
        
        IMPORTANT RULES:
        - Politely acknowledge their question
        - Explain that you can only help with questions about the uploaded document
        - Briefly mention the document name/topic
        - Offer to help with questions related to "\(documentTopic)"
        - Be friendly and conversational, not robotic
        - Keep response to 2-3 sentences
        
        User asks: \(query)
        
        Your polite response:
        """
    }
    
    private func extractDocumentTopic(from context: String) -> String {
        // Extract meaningful words from context to understand what it's about
        let contextLower = context.lowercased()
        
        // Extract the most frequent meaningful words/phrases from context
        let words = contextLower.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        
        // Count word frequency
        var wordCounts: [String: Int] = [:]
        let stopWords = Set(["this", "that", "with", "from", "have", "been", "were", "will", "your", "about", "more", "some", "what", "when", "where", "which", "their", "there", "would", "could", "should", "these", "those", "than", "them", "then", "into", "also", "only", "other", "over", "such", "through", "very", "just", "being", "here", "after", "before", "each", "made", "make", "like", "back", "even", "most", "well", "much", "same", "does", "image", "page", "text", "document", "file"])
        
        for word in words {
            if !stopWords.contains(word) && word.count > 3 {
                wordCounts[word, default: 0] += 1
            }
        }
        
        // Get top keywords
        let topKeywords = wordCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        // Look for product names (capitalized words that appear frequently)
        let capitalizedPattern = try? NSRegularExpression(pattern: "\\b[A-Z][a-z]+(?:\\s+[A-Z][a-z]+)*\\b", options: [])
        var productNames: [String] = []
        if let regex = capitalizedPattern {
            let matches = regex.matches(in: context, options: [], range: NSRange(context.startIndex..., in: context))
            for match in matches.prefix(20) {
                if let range = Range(match.range, in: context) {
                    let name = String(context[range])
                    if name.count > 2 && !["The", "This", "That", "And", "For", "With", "From", "Are", "Was", "Were", "Has", "Have", "Page", "Image"].contains(name) {
                        productNames.append(name)
                    }
                }
            }
        }
        
        // Count product name occurrences
        var productCounts: [String: Int] = [:]
        for name in productNames {
            productCounts[name, default: 0] += 1
        }
        
        // Get most frequent product/brand name
        if let topProduct = productCounts.sorted(by: { $0.value > $1.value }).first, topProduct.value >= 2 {
            return topProduct.key
        }
        
        // Build topic description from top keywords
        if !topKeywords.isEmpty {
            let keywordList = topKeywords.prefix(3).joined(separator: ", ")
            return "topics related to: \(keywordList)"
        }
        
        return "the uploaded document"
    }
    
    private func selectDiverseImages(from candidates: [(image: DocumentImage, score: Int)], query: String) -> [(image: DocumentImage, score: Int)] {
        guard !candidates.isEmpty else { return [] }
        
        let queryLower = query.lowercased()
        let isVisualQuery = ["look", "show", "view", "image", "photo", "picture", "design", "display"].contains { queryLower.contains($0) }
        let minScoreThreshold = isVisualQuery ? 40 : 20
        
        var relevantCandidates = candidates.filter { $0.score >= minScoreThreshold }
        
        let queryWords = queryLower.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let stopWords = Set(["can", "you", "give", "me", "the", "what", "how", "show", "display", "see"])
        let meaningfulWords = queryWords.filter { !stopWords.contains($0) }
        
        if !meaningfulWords.isEmpty {
            let semanticFiltered = relevantCandidates.filter { candidate in
                let labels = candidate.image.classificationLabels.map { $0.lowercased() }
                return meaningfulWords.contains { word in
                    labels.contains { label in
                        label.contains(word) || word.contains(label) || areSemanticallyRelated(word, label)
                    }
                }
            }
            
            print("🖼️ [Selection] Semantic filter for '\(meaningfulWords.joined(separator: ", "))': \(semanticFiltered.count)/\(relevantCandidates.count) images match")
            
            if !semanticFiltered.isEmpty {
                relevantCandidates = semanticFiltered
            }
        }
        
        if relevantCandidates.isEmpty {
            print("🖼️ [Selection] No images meet relevance threshold (\(minScoreThreshold)) for query")
            return []
        }
        
        let wantsAll = ["all", "every", "complete", "full"].contains { queryLower.contains($0) }
        let maxImages = wantsAll ? 15 : 8
        
        var imagesByPage: [Int: [(image: DocumentImage, score: Int)]] = [:]
        for candidate in relevantCandidates {
            let page = candidate.image.pageIndex
            if imagesByPage[page] == nil {
                imagesByPage[page] = []
            }
            imagesByPage[page]?.append(candidate)
        }
        
        for page in imagesByPage.keys {
            imagesByPage[page]?.sort { $0.score > $1.score }
        }
        
        var selectedImages: [(image: DocumentImage, score: Int)] = []
        var selectedPages = Set<Int>()
        
        let sortedPages = imagesByPage.keys.sorted()
        
        for page in sortedPages {
            if selectedImages.count >= maxImages { break }
            
            if let pageImages = imagesByPage[page], let best = pageImages.first {
                selectedImages.append(best)
                selectedPages.insert(page)
            }
        }
        
        if selectedImages.count < maxImages {
            for page in sortedPages {
                if selectedImages.count >= maxImages { break }
                
                if let pageImages = imagesByPage[page], pageImages.count > 1 {
                    let second = pageImages[1]
                    if !selectedImages.contains(where: { $0.image.id == second.image.id }) {
                        selectedImages.append(second)
                    }
                }
            }
        }
        
        selectedImages.sort { $0.score > $1.score }
        
        print("🖼️ [Selection] Selected \(selectedImages.count) images from \(selectedPages.count) pages (relevant: \(relevantCandidates.count)/\(candidates.count), threshold: \(minScoreThreshold))")
        
        return selectedImages
    }
    
    /// Extracts meaningful keywords from the query that can be matched against image labels
    private func extractQueryKeywords(query: String) -> [String] {
        let q = query.lowercased()
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
                             "have", "has", "had", "do", "does", "did", "will", "would", "could",
                             "should", "may", "might", "must", "shall", "can", "need", "dare",
                             "show", "me", "see", "display", "view", "look", "looking", "find",
                             "what", "how", "where", "when", "which", "who", "why", "this", "that",
                             "with", "from", "about", "into", "through", "during", "before", "after"])
        
        let words = q.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        
        return words
    }
    
    /// Checks if image labels or OCR text match the query keywords
    private func imageMatchesQuery(_ image: DocumentImage, queryKeywords: [String]) -> Bool {
        guard !queryKeywords.isEmpty else { return false }
        
        let labelsLower = image.classificationLabels.map { $0.lowercased() }
        let ocrLower = image.ocrText.lowercased()
        
        // Check if any query keyword matches image content
        for keyword in queryKeywords {
            // Check labels
            if labelsLower.contains(where: { $0.contains(keyword) }) {
                return true
            }
            // Check OCR text
            if ocrLower.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    /// Generic image type categorization
    private enum ImageType {
        case photo       // Real photographs
        case diagram     // Technical diagrams, flowcharts
        case chart       // Data charts, graphs
        case icon        // Small icons, logos
        case screenshot  // UI screenshots
        case unknown
    }
    
    /// Determines the general type/category of an image
    private func detectImageType(_ image: DocumentImage) -> ImageType {
        let labelsLower = image.classificationLabels.map { $0.lowercased() }
        let ocrLower = image.ocrText.lowercased()
        
        // Check for charts/graphs
        let chartIndicators = ["chart", "graph", "bar", "pie", "line chart", "data", "axis", "legend"]
        if chartIndicators.contains(where: { labelsLower.joined().contains($0) || ocrLower.contains($0) }) {
            return .chart
        }
        
        // Check for diagrams
        let diagramIndicators = ["diagram", "flowchart", "schematic", "blueprint", "technical", "architecture", "flow"]
        if diagramIndicators.contains(where: { labelsLower.joined().contains($0) || ocrLower.contains($0) }) {
            return .diagram
        }
        
        // Check for screenshots
        let screenshotIndicators = ["screenshot", "screen", "ui", "interface", "app", "window", "button", "menu"]
        if screenshotIndicators.contains(where: { labelsLower.joined().contains($0) }) {
            return .screenshot
        }
        
        // Check for icons/logos (usually small images with minimal labels)
        if image.classificationLabels.count <= 2 && labelsLower.contains(where: { $0.contains("logo") || $0.contains("icon") || $0.contains("symbol") }) {
            return .icon
        }
        
        // Default to photo for images with object labels
        let photoIndicators = ["person", "people", "building", "outdoor", "indoor", "product", "object", "nature", "animal"]
        if photoIndicators.contains(where: { labelsLower.joined().contains($0) }) {
            return .photo
        }
        
        return .unknown
    }
    
    /// Checks if image appears to be a meaningful content image (not decorative)
    private func isContentImage(_ image: DocumentImage) -> Bool {
        // Skip very small classification label sets (might be decorative)
        if image.classificationLabels.isEmpty {
            return false
        }
        
        // Skip images that are likely QR codes or barcodes
        if isQRCodeOrIrrelevant(image) {
            return false
        }
        
        return true
    }
    
    private func isQRCodeOrIrrelevant(_ image: DocumentImage) -> Bool {
        let ocrText = image.ocrText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if ocrText.isEmpty {
            return false
        }
        
        if ocrText.contains("http://") || ocrText.contains("https://") || ocrText.contains("www.") {
            return true
        }
        
        let qrPatterns = ["scan", "qr code", "barcode", "play store", "app store", "download app"]
        for pattern in qrPatterns {
            if ocrText.contains(pattern) {
                return true
            }
        }
        
        if ocrText.count < 15 && !ocrText.contains(" ") {
            let hasOnlySymbols = ocrText.filter { $0.isLetter }.count < ocrText.count / 3
            if hasOnlySymbols {
                return true
            }
        }
        
        return false
    }
    
    private func calculateImageRelevance(image: DocumentImage, query: String, context: String, pageIndices: Set<Int>, documentLabels: Set<String>) -> Int {
        var score = 20
        let queryLower = query.lowercased()
        let ocrLower = image.ocrText.lowercased()
        
        let queryWords = queryLower.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let stopWords = Set(["can", "you", "give", "me", "the", "what", "how", "does", "is", "are", "this", "that", "some", "any", "about", "details", "information", "have", "do", "please", "want", "need", "would", "could", "should", "and", "or", "of", "show", "display"])
        let meaningfulWords = queryWords.filter { !stopWords.contains($0) }
        
        if pageIndices.contains(image.pageIndex) {
            score += 30
        }
        
        for word in meaningfulWords {
            if ocrLower.contains(word) {
                score += 25
            }
        }
        
        let labels = image.classificationLabels.map { $0.lowercased() }
        let labelMatchScore = calculateDynamicLabelScore(imageLabels: labels, queryWords: meaningfulWords, documentLabels: documentLabels)
        score += labelMatchScore
        
        if image.ocrText.count > 50 {
            score += 10
        }
        
        return score
    }
    
    private func calculateDynamicLabelScore(imageLabels: [String], queryWords: [String], documentLabels: Set<String>) -> Int {
        var score = 0
        
        for queryWord in queryWords {
            for label in imageLabels {
                if label.contains(queryWord) || queryWord.contains(label) {
                    score += 50
                }
                
                if areSemanticallyRelated(queryWord, label) {
                    score += 40
                }
            }
            
            if let learnedLabels = try? getLearnedLabelsSync(for: queryWord) {
                for (learnedLabel, learnedScore) in learnedLabels {
                    if imageLabels.contains(where: { $0.lowercased().contains(learnedLabel) }) {
                        let bonus = min(learnedScore * 5, 30)
                        score += bonus
                        print("🧠 [Learning] Applied learned mapping: '\(queryWord)' → '\(learnedLabel)' (+\(bonus))")
                    }
                }
            }
        }
        
        if !imageLabels.isEmpty && score == 0 {
            score += 5
        }
        
        return score
    }
    
    private var learnedMappingsCache: [String: [(label: String, score: Int)]] = [:]
    
    private func getLearnedLabelsSync(for queryWord: String) throws -> [(label: String, score: Int)] {
        if let cached = learnedMappingsCache[queryWord] {
            return cached
        }
        return []
    }
    
    private func loadLearnedMappings(for queryWords: [String]) async {
        for word in queryWords {
            if let mappings = try? await documentRepository.getLearnedLabelsForQuery(word) {
                learnedMappingsCache[word] = mappings
            }
        }
    }
    
    private func learnFromSuccessfulMatch(queryWords: [String], imageLabels: [String]) async {
        for queryWord in queryWords {
            for label in imageLabels {
                let labelLower = label.lowercased()
                if labelLower.contains(queryWord) || queryWord.contains(labelLower) || areSemanticallyRelated(queryWord, labelLower) {
                    do {
                        try await documentRepository.learnQueryLabelMapping(queryWord: queryWord, matchedLabel: labelLower)
                        print("🧠 [Learning] Stored mapping: '\(queryWord)' → '\(labelLower)'")
                    } catch {
                        print("⚠️ [Learning] Failed to store mapping: \(error)")
                    }
                }
            }
        }
    }
    
    private func areSemanticallyRelated(_ word1: String, _ word2: String) -> Bool {
        let semanticGroups: [[String]] = [
            ["interior", "inside", "indoor", "cabin", "dashboard", "seat", "steering", "console", "gauge", "cockpit"],
            ["exterior", "outside", "outdoor", "body", "front", "rear", "side"],
            ["wheel", "tire", "rim", "alloy", "rubber"],
            ["car", "vehicle", "automobile", "sedan", "suv", "truck", "auto"],
            ["chair", "seat", "sofa", "couch", "furniture"],
            ["table", "desk", "surface"],
            ["kitchen", "cooking", "stove", "oven", "refrigerator"],
            ["bedroom", "bed", "mattress", "pillow"],
            ["bathroom", "toilet", "shower", "sink"],
            ["food", "meal", "dish", "plate", "cuisine"],
            ["person", "people", "human", "face", "portrait"],
            ["building", "house", "home", "architecture", "structure"],
            ["nature", "landscape", "tree", "plant", "flower", "garden"],
            ["sky", "cloud", "weather", "outdoor"],
            ["water", "ocean", "sea", "river", "lake", "pool"],
            ["animal", "pet", "dog", "cat", "bird"],
            ["electronic", "device", "screen", "display", "monitor", "computer", "phone"]
        ]
        
        for group in semanticGroups {
            let word1InGroup = group.contains { $0.contains(word1) || word1.contains($0) }
            let word2InGroup = group.contains { $0.contains(word2) || word2.contains($0) }
            
            if word1InGroup && word2InGroup {
                return true
            }
        }
        
        return false
    }
    
    private func getSemanticDescription(labels: [String]) -> String {
        if labels.isEmpty {
            return ""
        }
        
        let labelsLower = labels.map { $0.lowercased() }
        let topLabels = labelsLower.prefix(4).joined(separator: ", ")
        return "Image showing: \(topLabels)"
    }
    
    
    private func extractImagePageIndices(from text: String) -> Set<Int> {
        var indices: Set<Int> = []
        let pattern = "\\[Image Page (\\d+)\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return indices
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text),
               let pageNumber = Int(text[range]) {
                indices.insert(pageNumber - 1)
            }
        }
        
        return indices
    }
    
    private func extractAllPageIndices(from text: String) -> Set<Int> {
        var indices: Set<Int> = []
        let pattern = "\\[Page (\\d+)\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return indices
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text),
               let pageNumber = Int(text[range]) {
                indices.insert(pageNumber - 1)
            }
        }
        
        return indices
    }
    
    private func buildGeneralPrompt(query: String) -> String {
        "Q: \(query)\nA:"
    }
}
