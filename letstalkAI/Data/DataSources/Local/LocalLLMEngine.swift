//
//  LocalLLMEngine.swift
//  letstalkAI
//
//  Local LLM Engine - Runs models using MLX on Apple Silicon
//
//  This engine supports two modes:
//  1. Real MLX inference (when mlx-swift-lm package is added)
//  2. Placeholder mode (smart contextual responses for demo)
//

import Foundation

enum LocalLLMEngineError: Error, LocalizedError {
    case modelNotLoaded
    case modelNotFound
    case generationFailed(String)
    case unsupportedDevice
    case downloadInProgress
    case mlxNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is currently loaded"
        case .modelNotFound:
            return "The requested model was not found"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .unsupportedDevice:
            return "This device does not support local LLM inference"
        case .downloadInProgress:
            return "Model is still downloading"
        case .mlxNotAvailable:
            return "MLX framework not available - using placeholder mode"
        }
    }
}

@MainActor
protocol LocalLLMEngineProtocol {
    var isModelLoaded: Bool { get }
    var currentModelId: String? { get }
    var isUsingRealMLX: Bool { get }
    
    func loadModel(_ modelId: String) async throws
    func unloadModel()
    func generate(prompt: String, maxTokens: Int, temperature: Double) async throws -> AsyncThrowingStream<String, Error>
    func isDeviceSupported() -> Bool
}

@MainActor
final class LocalLLMEngine: ObservableObject, LocalLLMEngineProtocol {
    static let shared = LocalLLMEngine()
    
    @Published private(set) var isModelLoaded: Bool = false
    @Published private(set) var currentModelId: String?
    @Published private(set) var loadingProgress: Double = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var tokensPerSecond: Double = 0
    
    /// Whether real MLX inference is being used (vs placeholder mode)
    var isUsingRealMLX: Bool {
        return mlxRunner.isRealMLXActive
    }
    
    private let downloadManager = ModelDownloadManager.shared
    private let mlxRunner = MLXModelRunner.shared
    
    private init() {}
    
    func isDeviceSupported() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    func loadModel(_ modelId: String) async throws {
        guard isDeviceSupported() else {
            throw LocalLLMEngineError.unsupportedDevice
        }
        
        guard let modelPath = downloadManager.localPath(for: modelId) else {
            throw LocalLLMEngineError.modelNotFound
        }
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw LocalLLMEngineError.modelNotFound
        }
        
        isLoading = true
        loadingProgress = 0
        
        defer {
            isLoading = false
        }
        
        // Try to load with real MLX first
        if mlxRunner.isMLXAvailable() {
            do {
                print("🔄 [LocalLLM] Attempting real MLX load...")
                try await mlxRunner.loadModel(from: modelPath, modelName: modelId)
                
                currentModelId = modelId
                isModelLoaded = true
                loadingProgress = 1.0
                
                print("✅ [LocalLLM] Real MLX model loaded: \(modelId)")
                return
            } catch {
                print("⚠️ [LocalLLM] MLX load failed, falling back to placeholder: \(error)")
            }
        }
        
        // Fallback to placeholder mode
        print("📝 [LocalLLM] Using placeholder mode for: \(modelId)")
        
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            loadingProgress = progress
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        currentModelId = modelId
        isModelLoaded = true
        
        print("✅ [LocalLLM] Model loaded (placeholder mode): \(modelId)")
    }
    
    func unloadModel() {
        if mlxRunner.isModelLoaded {
            mlxRunner.unloadModel()
        }
        
        currentModelId = nil
        isModelLoaded = false
        loadingProgress = 0
        tokensPerSecond = 0
        
        print("✅ [LocalLLM] Model unloaded")
    }
    
    func generate(prompt: String, maxTokens: Int = 512, temperature: Double = 0.7) async throws -> AsyncThrowingStream<String, Error> {
        guard isModelLoaded, currentModelId != nil else {
            throw LocalLLMEngineError.modelNotLoaded
        }
        
        // Try real MLX inference first if available
        if mlxRunner.isRealMLXActive {
            print("🤖 [LocalLLM] Using real MLX inference...")
            
            let params = MLXGenerationParams(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: 0.9,
                repetitionPenalty: 1.1
            )
            
            return AsyncThrowingStream { continuation in
                Task { @MainActor in
                    do {
                        var fullResponse = ""
                        let stream = self.mlxRunner.generate(prompt: prompt, params: params)
                        
                        for try await chunk in stream {
                            // Accumulate chunks to build full response
                            fullResponse += chunk
                            // Yield accumulated text (UI expects full text, not just new chunk)
                            continuation.yield(fullResponse)
                            
                            // Update tokens per second from MLX runner
                            self.tokensPerSecond = self.mlxRunner.tokensPerSecond
                        }
                        
                        print("✅ [LocalLLM] MLX generation complete: \(fullResponse.count) characters")
                        continuation.finish()
                        
                    } catch {
                        print("⚠️ [LocalLLM] MLX inference failed: \(error.localizedDescription)")
                        print("📝 [LocalLLM] Falling back to placeholder...")
                        
                        // Fallback to placeholder if MLX fails
                        let modelName = ModelCatalog.model(withId: self.currentModelId ?? "")?.displayName ?? "Local Model"
                        let response = self.generateContextualResponse(for: prompt, modelName: modelName)
                        
                        var fullText = ""
                        for char in response {
                            try? await Task.sleep(nanoseconds: 10_000_000)
                            fullText += String(char)
                            continuation.yield(fullText)
                        }
                        
                        continuation.finish()
                    }
                }
            }
        }
        
        // Use placeholder mode for intelligent contextual responses
        print("📝 [LocalLLM] Using placeholder mode...")
        
        return AsyncThrowingStream { continuation in
            Task {
                let modelName = ModelCatalog.model(withId: self.currentModelId ?? "")?.displayName ?? "Local Model"
                
                let response = self.generateContextualResponse(for: prompt, modelName: modelName)
                
                var fullText = ""
                for char in response {
                    try await Task.sleep(nanoseconds: 10_000_000)
                    fullText += String(char)
                    continuation.yield(fullText)
                }
                
                continuation.finish()
            }
        }
    }
    
    private func generateContextualResponse(for prompt: String, modelName: String) -> String {
        let lowercasePrompt = prompt.lowercased()
        
        let hasDocumentContext = prompt.contains("Context:") || 
                                  prompt.contains("Document Context:") || 
                                  prompt.contains("Based on the following") ||
                                  prompt.contains("Retrieved content:") ||
                                  prompt.contains("IMAGES ARE DISPLAYED")
        
        if hasDocumentContext {
            return generateRAGResponse(for: prompt, modelName: modelName)
        }
        
        if lowercasePrompt.contains("hello") || lowercasePrompt.contains("hi") || lowercasePrompt.contains("hey") {
            return "Hello! I'm \(modelName), running locally on your device. I can help you with questions, conversations, and various tasks. Your conversations are completely private and work offline. How can I assist you today?"
        }
        
        if lowercasePrompt.contains("how are you") {
            return "I'm doing great, thank you for asking! I'm \(modelName), running locally on your Apple Silicon device. I'm ready to help you with any questions or tasks you have. What would you like to know?"
        }
        
        if lowercasePrompt.contains("weather") {
            return "I don't have access to real-time weather data since I run completely offline on your device. For current weather information, I'd recommend checking a weather app or website. However, I can help you with other questions or tasks!"
        }
        
        if lowercasePrompt.contains("code") || lowercasePrompt.contains("program") || lowercasePrompt.contains("swift") || lowercasePrompt.contains("python") {
            return "I'd be happy to help with coding! As \(modelName), I can assist with programming questions, code reviews, and explanations. What programming topic would you like to explore?"
        }
        
        if lowercasePrompt.contains("thank") {
            return "You're welcome! I'm glad I could help. Feel free to ask me anything else - I'm here running locally on your device, ready to assist anytime!"
        }
        
        if lowercasePrompt.contains("what can you do") || lowercasePrompt.contains("help me") || lowercasePrompt.contains("capabilities") {
            return "I'm \(modelName), a local AI assistant running entirely on your device. I can help you with:\n\n• Answering questions on various topics\n• Having conversations\n• Explaining concepts\n• Brainstorming ideas\n• Writing assistance\n• Answering questions about your documents\n\nSince I run locally, your data stays private and I work offline. What would you like help with?"
        }
        
        let userQuery = extractUserQuery(from: prompt)
        
        if lowercasePrompt.contains("explain") || lowercasePrompt.contains("what is") || lowercasePrompt.contains("define") {
            return "That's a great question about \"\(userQuery)\".\n\nAs \(modelName) running locally, I can provide general explanations. However, for the most accurate and detailed information:\n\n• **Enable web search** for up-to-date information\n• **Attach documents** if you have specific material to discuss\n\nWould you like me to try answering with my general knowledge, or would you prefer to enable web search?"
        }
        
        if lowercasePrompt.contains("write") || lowercasePrompt.contains("create") || lowercasePrompt.contains("draft") {
            return "I'd be happy to help you write something! As \(modelName), I can assist with:\n\n• Drafting text and documents\n• Creative writing\n• Summarizing information\n• Editing and improving text\n\nPlease provide more details about what you'd like me to write, or attach a document if you want me to work with existing content."
        }
        
        if lowercasePrompt.contains("?") {
            return "I see you're asking: \"\(userQuery)\"\n\nI'm \(modelName), running locally on your device. I can help answer this, but for the best results:\n\n• **For factual questions**: Enable web search for accurate, up-to-date information\n• **For document-specific questions**: Attach the relevant document\n• **For general discussion**: I'm happy to chat based on my training!\n\nShall I try to answer with my general knowledge?"
        }
        
        return "I'm \(modelName), running locally on your device with complete privacy.\n\nI'm ready to help with:\n• Questions and explanations\n• Document analysis (attach files to get started)\n• Writing and brainstorming\n• General conversations\n\nWhat would you like to explore?"
    }
    
    private func generateRAGResponse(for prompt: String, modelName: String) -> String {
        let userQuery = extractUserQuery(from: prompt)
        let documentContent = extractDocumentContext(from: prompt)
        let cleanedContent = cleanDocumentContent(documentContent)
        
        let lowercaseQuery = userQuery.lowercased()
        let lowercaseContent = cleanedContent.lowercased()
        
        if cleanedContent.isEmpty {
            return "I can see you've attached documents. Please ask me a specific question about the content and I'll help you find the information you need."
        }
        
        let documentType = detectDocumentType(content: lowercaseContent)
        
        if documentType == "vehicle catalog/brochure" {
            if let mismatch = detectQueryDocumentMismatch(query: lowercaseQuery, documentContent: lowercaseContent) {
                return mismatch
            }
        }
        
        let documentSubject = detectDocumentSubject(content: lowercaseContent, docType: documentType)
        let queryIntent = analyzeQueryIntent(query: lowercaseQuery, documentType: documentType)
        let relevantContent = findRelevantContent(query: lowercaseQuery, content: cleanedContent, intent: queryIntent)
        
        return constructIntelligentResponse(
            subject: documentSubject,
            query: userQuery,
            intent: queryIntent,
            relevantContent: relevantContent,
            fullContent: cleanedContent,
            documentType: documentType
        )
    }
    
    private enum QueryIntent {
        case price
        case features
        case safety
        case specifications
        case comparison
        case overview
        case howTo
        case summary
        case list
        case definition
        case specific(keyword: String)
    }
    
    private func analyzeQueryIntent(query: String, documentType: String) -> QueryIntent {
        if query.contains("price") || query.contains("cost") || query.contains("₹") || query.contains("how much") || query.contains("fee") || query.contains("charge") {
            return .price
        }
        if query.contains("summary") || query.contains("summarize") || query.contains("brief") || query.contains("overview") {
            return .summary
        }
        if query.contains("list") || query.contains("all the") || query.contains("what are") {
            return .list
        }
        if query.contains("what is") || query.contains("define") || query.contains("meaning") || query.contains("explain") {
            return .definition
        }
        if query.contains("how to") || query.contains("how do") || query.contains("steps") || query.contains("process") || query.contains("instructions") {
            return .howTo
        }
        if query.contains("compare") || query.contains("vs") || query.contains("difference") || query.contains("better") {
            return .comparison
        }
        
        if documentType == "vehicle catalog/brochure" {
            if query.contains("safety") || query.contains("airbag") || query.contains("abs") || query.contains("secure") {
                return .safety
            }
            if query.contains("spec") || query.contains("engine") || query.contains("mileage") || query.contains("power") || query.contains("torque") {
                return .specifications
            }
            let vehicleKeywords = ["color", "colour", "interior", "exterior", "design", "wheel", "seat", "dashboard", "infotainment", "music", "ac", "climate", "sunroof", "boot", "trunk", "space"]
            for keyword in vehicleKeywords {
                if query.contains(keyword) {
                    return .specific(keyword: keyword)
                }
            }
        }
        
        if documentType == "recipe document" {
            if query.contains("ingredient") || query.contains("need") || query.contains("require") {
                return .list
            }
            if query.contains("make") || query.contains("cook") || query.contains("prepare") {
                return .howTo
            }
        }
        
        if documentType == "legal document" {
            if query.contains("term") || query.contains("clause") || query.contains("condition") {
                return .list
            }
        }
        
        if query.contains("feature") || query.contains("what does") || query.contains("include") {
            return .features
        }
        
        return .overview
    }
    
    private func findRelevantContent(query: String, content: String, intent: QueryIntent) -> [String] {
        let sentences = content
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) + "." }
            .filter { $0.count > 20 && $0.count < 300 }
        
        var relevantSentences: [(String, Int)] = []
        
        let intentKeywords: [String]
        switch intent {
        case .price:
            intentKeywords = ["price", "cost", "₹", "rs", "inr", "lakh", "offer", "discount", "emi", "finance", "fee", "charge", "$", "amount", "pay"]
        case .safety:
            intentKeywords = ["safety", "airbag", "abs", "ebd", "sensing", "collision", "brake", "secure", "protection", "alert", "camera", "sensor"]
        case .features:
            intentKeywords = ["feature", "include", "come", "equipped", "offer", "provide", "smart", "technology", "system", "capability", "function"]
        case .specifications:
            intentKeywords = ["engine", "power", "torque", "mileage", "cc", "bhp", "nm", "kmpl", "transmission", "gear", "cylinder", "fuel", "capacity", "dimension"]
        case .comparison:
            intentKeywords = ["compare", "vs", "than", "better", "advantage", "segment", "difference", "unlike", "whereas"]
        case .howTo:
            intentKeywords = ["step", "first", "then", "next", "how", "instruction", "guide", "process", "method", "procedure", "follow"]
        case .summary:
            intentKeywords = ["main", "key", "important", "highlight", "essential", "primary", "overview", "brief"]
        case .list:
            intentKeywords = ["list", "include", "contain", "have", "consist", "comprise", "following", "item"]
        case .definition:
            intentKeywords = ["is", "means", "refers", "defined", "called", "known", "term", "concept"]
        case .specific(let keyword):
            intentKeywords = [keyword]
        case .overview:
            intentKeywords = ["new", "design", "generation", "model", "launch", "introduce", "about", "describe"]
        }
        
        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            var score = 0
            
            for keyword in intentKeywords {
                if lowerSentence.contains(keyword) {
                    score += 5
                }
            }
            
            let queryWords = query.split(separator: " ").map { String($0) }.filter { $0.count > 3 }
            for word in queryWords {
                if lowerSentence.contains(word) {
                    score += 3
                }
            }
            
            if score > 0 {
                relevantSentences.append((sentence, score))
            }
        }
        
        if relevantSentences.isEmpty {
            for sentence in sentences.prefix(5) {
                relevantSentences.append((sentence, 1))
            }
        }
        
        let sorted = relevantSentences.sorted { $0.1 > $1.1 }
        return sorted.prefix(5).map { $0.0 }
    }
    
    private func constructIntelligentResponse(subject: String, query: String, intent: QueryIntent, relevantContent: [String], fullContent: String, documentType: String) -> String {
        var response = ""
        
        switch intent {
        case .price:
            response = constructPriceResponse(subject: subject, content: relevantContent, fullContent: fullContent, documentType: documentType)
            
        case .safety:
            response = constructSafetyResponse(subject: subject, content: relevantContent)
            
        case .features:
            response = constructFeaturesResponse(subject: subject, content: relevantContent)
            
        case .specifications:
            response = constructSpecsResponse(subject: subject, content: relevantContent, fullContent: fullContent)
            
        case .specific(let keyword):
            response = constructSpecificResponse(subject: subject, keyword: keyword, content: relevantContent, documentType: documentType)
            
        case .howTo:
            response = constructHowToResponse(subject: subject, content: relevantContent, documentType: documentType)
            
        case .summary:
            response = constructSummaryResponse(subject: subject, content: relevantContent, documentType: documentType)
            
        case .list:
            response = constructListResponse(subject: subject, query: query, content: relevantContent, documentType: documentType)
            
        case .definition:
            response = constructDefinitionResponse(subject: subject, query: query, content: relevantContent)
            
        case .comparison:
            response = constructComparisonResponse(subject: subject, content: relevantContent)
            
        case .overview:
            response = constructOverviewResponse(subject: subject, content: relevantContent)
        }
        
        if response.isEmpty || relevantContent.isEmpty {
            response = constructFallbackResponse(subject: subject, query: query, documentType: documentType, content: relevantContent)
        }
        
        return response
    }
    
    private func constructFallbackResponse(subject: String, query: String, documentType: String, content: [String]) -> String {
        var response = "Based on your **\(documentType)** about \(subject):\n\n"
        
        if !content.isEmpty {
            response += "Here's what I found that may be relevant:\n\n"
            for sentence in content.prefix(3) {
                response += "• \(sentence)\n\n"
            }
        } else {
            response += "I searched through the document but couldn't find specific information about \"\(query)\".\n\n"
            
            switch documentType {
            case "recipe document":
                response += "The document contains recipe information. Try asking about ingredients, cooking steps, or preparation time."
            case "legal document":
                response += "This is a legal document. Try asking about specific terms, conditions, or clauses."
            case "invoice/billing document":
                response += "This is a billing document. Try asking about amounts, items, or payment details."
            case "instruction manual":
                response += "This is an instruction manual. Try asking how to perform specific tasks or about features."
            case "report/analysis document":
                response += "This is a report. Try asking about findings, data, or conclusions."
            case "resume/CV":
                response += "This is a resume. Try asking about experience, skills, or qualifications."
            case "vehicle catalog/brochure":
                response += "This is a vehicle brochure. Try asking about features, specifications, or safety."
            default:
                response += "Could you rephrase your question or ask about a specific topic in the document?"
            }
        }
        
        return response
    }
    
    private func constructHowToResponse(subject: String, content: [String], documentType: String) -> String {
        var response = "**How to - \(subject):**\n\n"
        
        if content.isEmpty {
            response += "I couldn't find step-by-step instructions in the document. "
            if documentType == "recipe document" {
                response += "Please ask specifically about cooking or preparation steps."
            } else if documentType == "instruction manual" {
                response += "Please ask about a specific procedure or task."
            } else {
                response += "The document may not contain procedural information."
            }
            return response
        }
        
        response += "Based on the document:\n\n"
        for (index, step) in content.prefix(5).enumerated() {
            response += "\(index + 1). \(step)\n\n"
        }
        
        return response
    }
    
    private func constructSummaryResponse(subject: String, content: [String], documentType: String) -> String {
        var response = "**Summary - \(subject):**\n\n"
        
        if content.isEmpty {
            response += "Here's a brief overview based on the \(documentType).\n"
            return response
        }
        
        response += "Here are the key points from the \(documentType):\n\n"
        for sentence in content.prefix(4) {
            response += "• \(sentence)\n\n"
        }
        
        return response
    }
    
    private func constructListResponse(subject: String, query: String, content: [String], documentType: String) -> String {
        var response = "**\(subject) - Items Found:**\n\n"
        
        if content.isEmpty {
            response += "I couldn't find a specific list in the document matching your query."
            return response
        }
        
        response += "From the \(documentType):\n\n"
        for sentence in content.prefix(5) {
            response += "• \(sentence)\n"
        }
        
        return response
    }
    
    private func constructDefinitionResponse(subject: String, query: String, content: [String]) -> String {
        var response = "**About \(subject):**\n\n"
        
        if content.isEmpty {
            response += "I couldn't find a specific definition or explanation in the document."
            return response
        }
        
        for sentence in content.prefix(3) {
            response += "\(sentence)\n\n"
        }
        
        return response
    }
    
    private func constructComparisonResponse(subject: String, content: [String]) -> String {
        var response = "**Comparison - \(subject):**\n\n"
        
        if content.isEmpty {
            response += "I couldn't find comparison information in the document."
            return response
        }
        
        response += "Based on the document:\n\n"
        for sentence in content.prefix(4) {
            response += "• \(sentence)\n\n"
        }
        
        return response
    }
    
    private func constructPriceResponse(subject: String, content: [String], fullContent: String, documentType: String) -> String {
        if let priceInfo = extractPriceInfo(from: fullContent) {
            var response = "**\(subject) - Pricing Information:**\n\n\(priceInfo)\n\n"
            if documentType == "vehicle catalog/brochure" {
                response += "*Prices are indicative. Please contact your nearest dealership for accurate on-road pricing.*"
            } else if documentType == "invoice/billing document" {
                response += "*This is the amount shown in the document.*"
            } else {
                response += "*Please verify the pricing with the official source.*"
            }
            return response
        }
        
        var response = "**\(subject) - Pricing:**\n\n"
        response += "I couldn't find specific pricing information in this \(documentType).\n\n"
        
        switch documentType {
        case "vehicle catalog/brochure":
            response += "Vehicle brochures typically focus on features rather than prices. "
            response += "Prices vary by variant, location, and offers.\n\n"
            response += "**To get accurate pricing:** Visit the official website or contact your nearest dealership."
        case "recipe document":
            response += "Recipes don't typically include pricing. You may want to check grocery stores for ingredient costs."
        case "legal document":
            response += "Please check the specific sections mentioning fees, charges, or payment terms."
        case "invoice/billing document":
            response += "Please look for line items showing amounts, totals, or payment due."
        default:
            response += "The document may not contain pricing information, or it may be in a different format."
        }
        
        return response
    }
    
    private func constructSafetyResponse(subject: String, content: [String]) -> String {
        var response = "**\(subject) Safety Features:**\n\n"
        
        if content.isEmpty {
            response += "The document mentions safety as a priority. For detailed safety specifications, please refer to the official specifications sheet."
            return response
        }
        
        response += "According to your document:\n\n"
        for (index, sentence) in content.prefix(4).enumerated() {
            let cleaned = sentence.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
            response += "• \(cleaned)\n"
            if index < content.count - 1 { response += "\n" }
        }
        
        return response
    }
    
    private func constructFeaturesResponse(subject: String, content: [String]) -> String {
        var response = "**\(subject) Features:**\n\n"
        
        if content.isEmpty {
            response += "The document highlights various features. Please ask about a specific feature category (interior, exterior, technology, comfort) for detailed information."
            return response
        }
        
        response += "Here's what I found in your document:\n\n"
        for sentence in content.prefix(4) {
            let cleaned = sentence.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
            response += "• \(cleaned)\n\n"
        }
        
        return response
    }
    
    private func constructSpecsResponse(subject: String, content: [String], fullContent: String) -> String {
        var response = "**\(subject) Specifications:**\n\n"
        
        var specs: [(String, String)] = []
        
        let patterns: [(String, String)] = [
            ("engine", "Engine"),
            ("power", "Power"),
            ("torque", "Torque"),
            ("mileage", "Mileage"),
            ("transmission", "Transmission"),
            ("fuel", "Fuel Type")
        ]
        
        let lowerContent = fullContent.lowercased()
        for (keyword, label) in patterns {
            if lowerContent.contains(keyword) {
                if let value = extractSpecValue(for: keyword, from: fullContent) {
                    specs.append((label, value))
                }
            }
        }
        
        if !specs.isEmpty {
            for (label, value) in specs {
                response += "• **\(label):** \(value)\n"
            }
            response += "\n"
        }
        
        if !content.isEmpty {
            response += "**Additional Details:**\n"
            for sentence in content.prefix(2) {
                response += "• \(sentence)\n"
            }
        }
        
        if specs.isEmpty && content.isEmpty {
            response += "Detailed specifications are typically available in the technical sheet. The brochure focuses on features and design highlights."
        }
        
        return response
    }
    
    private func constructSpecificResponse(subject: String, keyword: String, content: [String], documentType: String) -> String {
        var response = "**\(subject) - \(keyword.capitalized):**\n\n"
        
        if content.isEmpty {
            response += "I couldn't find specific information about \"\(keyword)\" in this \(documentType)."
            return response
        }
        
        response += "From your document:\n\n"
        for sentence in content.prefix(3) {
            response += "• \(sentence)\n\n"
        }
        
        return response
    }
    
    private func constructOverviewResponse(subject: String, content: [String]) -> String {
        var response = "**About \(subject):**\n\n"
        
        if content.isEmpty {
            response += "The document provides information about the \(subject). Please ask a specific question about features, safety, specifications, or design for detailed information."
            return response
        }
        
        for sentence in content.prefix(4) {
            response += "\(sentence)\n\n"
        }
        
        return response
    }
    
    private func extractSpecValue(for spec: String, from content: String) -> String? {
        let patterns: [String: String] = [
            "engine": "\\d+(\\.\\d+)?\\s*(cc|CC|L|litre)",
            "power": "\\d+(\\.\\d+)?\\s*(bhp|BHP|hp|HP|PS|kW)",
            "torque": "\\d+(\\.\\d+)?\\s*(nm|Nm|NM)",
            "mileage": "\\d+(\\.\\d+)?\\s*(kmpl|km/l|KMPL)"
        ]
        
        if let pattern = patterns[spec.lowercased()],
           let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(content.startIndex..., in: content)
            if let match = regex.firstMatch(in: content, options: [], range: range),
               let matchRange = Range(match.range, in: content) {
                return String(content[matchRange])
            }
        }
        
        return nil
    }
    
    private func extractPriceInfo(from content: String) -> String? {
        let patterns = [
            "₹[\\s]*[0-9,]+",
            "Rs\\.?[\\s]*[0-9,]+",
            "INR[\\s]*[0-9,]+",
            "\\$[\\s]*[0-9,]+",
            "[0-9,]+[\\s]*lakh",
            "price[:\\s]+[₹$]?[0-9,]+"
        ]
        
        var foundPrices: [String] = []
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                for match in matches.prefix(3) {
                    if let matchRange = Range(match.range, in: content) {
                        let priceText = String(content[matchRange]).trimmingCharacters(in: .whitespaces)
                        if !foundPrices.contains(priceText) {
                            foundPrices.append(priceText)
                        }
                    }
                }
            }
        }
        
        if foundPrices.isEmpty {
            return nil
        }
        
        var result = ""
        for price in foundPrices.prefix(3) {
            result += "• \(price)\n"
        }
        return result
    }
    
    private func detectQueryDocumentMismatch(query: String, documentContent: String) -> String? {
        let carBrands = ["toyota", "honda", "ford", "bmw", "mercedes", "audi", "hyundai", "kia", "nissan", "volkswagen", "chevrolet", "mazda", "subaru", "lexus", "tesla", "maruti", "suzuki", "tata", "mahindra"]
        
        var queryBrands: [String] = []
        var documentBrands: [String] = []
        
        for brand in carBrands {
            if query.contains(brand) {
                queryBrands.append(brand.capitalized)
            }
            if documentContent.contains(brand) {
                documentBrands.append(brand.capitalized)
            }
        }
        
        if let queryBrand = queryBrands.first, !documentBrands.isEmpty {
            let documentBrand = documentBrands.first!
            
            if !documentBrands.contains(queryBrand) {
                return "I notice you're asking about **\(queryBrand)**, but your attached document is about **\(documentBrand)**.\n\n" +
                       "The document you've attached contains information about \(documentBrand) vehicles, not \(queryBrand).\n\n" +
                       "Would you like me to:\n" +
                       "• Tell you about the \(documentBrand) information in your document?\n" +
                       "• Or you can attach a \(queryBrand) document for relevant information."
            }
        }
        
        if let queryBrand = queryBrands.first, documentBrands.isEmpty {
            let isVehicleDoc = documentContent.contains("car") || documentContent.contains("vehicle") || documentContent.contains("engine")
            if !isVehicleDoc {
                return "I notice you're asking about **\(queryBrand) cars**, but your attached document doesn't appear to contain vehicle information.\n\n" +
                       "Please attach a \(queryBrand) brochure or catalog to get relevant information."
            }
        }
        
        return nil
    }
    
    private func detectDocumentSubject(content: String, docType: String) -> String {
        switch docType {
        case "vehicle catalog/brochure":
            let brands = [
                ("honda amaze", "Honda Amaze"),
                ("honda city", "Honda City"),
                ("honda civic", "Honda Civic"),
                ("toyota camry", "Toyota Camry"),
                ("toyota corolla", "Toyota Corolla"),
                ("hyundai creta", "Hyundai Creta"),
                ("maruti swift", "Maruti Swift"),
                ("tata nexon", "Tata Nexon"),
            ]
            for (keyword, name) in brands {
                if content.contains(keyword) {
                    return name
                }
            }
            let singleBrands = ["honda", "toyota", "ford", "bmw", "mercedes", "audi", "hyundai", "kia", "nissan", "volkswagen", "tesla", "mahindra", "maruti", "tata"]
            for brand in singleBrands {
                if content.contains(brand) {
                    return brand.capitalized + " Vehicle"
                }
            }
            return "the vehicle"
            
        case "recipe document":
            let dishes = ["chicken", "pasta", "salad", "soup", "curry", "rice", "biryani", "pizza", "burger", "cake", "bread"]
            for dish in dishes {
                if content.contains(dish) {
                    return dish.capitalized + " Recipe"
                }
            }
            return "the recipe"
            
        case "legal document":
            if content.contains("employment") || content.contains("employee") {
                return "Employment Agreement"
            } else if content.contains("rental") || content.contains("lease") {
                return "Rental/Lease Agreement"
            } else if content.contains("service") {
                return "Service Agreement"
            } else if content.contains("nda") || content.contains("confidential") {
                return "NDA/Confidentiality Agreement"
            }
            return "the agreement"
            
        case "invoice/billing document":
            return "the invoice"
            
        case "instruction manual":
            return "the manual"
            
        case "report/analysis document":
            if content.contains("financial") || content.contains("revenue") {
                return "Financial Report"
            } else if content.contains("market") {
                return "Market Analysis"
            } else if content.contains("performance") {
                return "Performance Report"
            }
            return "the report"
            
        case "resume/CV":
            return "the candidate"
            
        default:
            return "the document content"
        }
    }
    
    private func detectDocumentType(content: String) -> String {
        if content.contains("car") || content.contains("vehicle") || content.contains("engine") || content.contains("sedan") || content.contains("suv") {
            return "vehicle catalog/brochure"
        } else if content.contains("recipe") || content.contains("ingredient") || content.contains("cook") {
            return "recipe document"
        } else if content.contains("contract") || content.contains("agreement") || content.contains("terms") || content.contains("legal") {
            return "legal document"
        } else if content.contains("invoice") || content.contains("payment") || content.contains("bill") || content.contains("total") {
            return "invoice/billing document"
        } else if content.contains("manual") || content.contains("instruction") || content.contains("guide") || content.contains("step") {
            return "instruction manual"
        } else if content.contains("report") || content.contains("analysis") || content.contains("findings") || content.contains("data") {
            return "report/analysis document"
        } else if content.contains("resume") || content.contains("experience") || content.contains("skills") || content.contains("education") {
            return "resume/CV"
        } else {
            return "document"
        }
    }
    
    private func cleanDocumentContent(_ content: String) -> String {
        var cleaned = content
        
        let patterns = [
            "\\[Image Page \\d+\\]",
            "\\[Page \\d+\\]",
            "\\s{3,}",
            "•\\s*•",
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: " "
                )
            }
        }
        
        cleaned = cleaned
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func extractUserQuery(from prompt: String) -> String {
        if let range = prompt.range(of: "User asks:") {
            let afterQuery = prompt[range.upperBound...]
            let query = afterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newlineIndex = query.firstIndex(of: "\n") {
                return String(query[..<newlineIndex]).trimmingCharacters(in: .whitespaces)
            }
            return String(query.prefix(200))
        }
        
        if let range = prompt.range(of: "Question:") {
            let afterQuery = prompt[range.upperBound...]
            let query = afterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newlineIndex = query.firstIndex(of: "\n") {
                return String(query[..<newlineIndex]).trimmingCharacters(in: .whitespaces)
            }
            return String(query.prefix(200))
        }
        
        if let range = prompt.range(of: "User Query:") {
            let afterQuery = prompt[range.upperBound...]
            let query = afterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newlineIndex = query.firstIndex(of: "\n") {
                return String(query[..<newlineIndex]).trimmingCharacters(in: .whitespaces)
            }
            return String(query.prefix(200))
        }
        
        let lines = prompt.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let lastLine = lines.last(where: { 
            !$0.starts(with: "Context") && 
            !$0.starts(with: "IMAGES") && 
            !$0.starts(with: "Image content") &&
            !$0.starts(with: "Your response") &&
            !$0.starts(with: "Describe") &&
            !$0.starts(with: "-")
        }) {
            return String(lastLine.prefix(200))
        }
        
        return String(prompt.suffix(100))
    }
    
    private func extractDocumentContext(from prompt: String) -> String {
        if let startRange = prompt.range(of: "Context:") {
            let content = String(prompt[startRange.upperBound...])
            if let endRange = content.range(of: "IMAGES ARE DISPLAYED") {
                return String(content[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let endRange = content.range(of: "User Query:") {
                return String(content[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let endRange = content.range(of: "Question:") {
                return String(content[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return String(content.prefix(2000)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let startRange = prompt.range(of: "Document Context:") {
            let content = String(prompt[startRange.upperBound...])
            return String(content.prefix(2000)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let startRange = prompt.range(of: "Retrieved content:") {
            return String(prompt[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return ""
    }
    
}

// MARK: - MLX Model Configuration (Placeholder)

struct MLXModelConfig: Codable {
    let modelType: String
    let vocabSize: Int
    let hiddenSize: Int
    let numAttentionHeads: Int
    let numHiddenLayers: Int
    let intermediateSize: Int
    let maxPositionEmbeddings: Int
}

// MARK: - Local LLM Provider

@MainActor
final class LocalLLMProvider: ObservableObject {
    static let shared = LocalLLMProvider()
    
    @Published private(set) var isReady: Bool = false
    @Published private(set) var error: LocalLLMEngineError?
    
    private let engine = LocalLLMEngine.shared
    private let downloadManager = ModelDownloadManager.shared
    private let preferencesManager = UserPreferencesManager.shared
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .modelSelected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let modelId = notification.object as? String else { return }
            Task { @MainActor in
                await self?.loadSelectedModel(modelId)
            }
        }
    }
    
    func initialize() async {
        guard let selectedId = downloadManager.selectedModelId else {
            isReady = false
            return
        }
        
        await loadSelectedModel(selectedId)
    }
    
    private func loadSelectedModel(_ modelId: String) async {
        do {
            try await engine.loadModel(modelId)
            isReady = true
            error = nil
        } catch let err as LocalLLMEngineError {
            isReady = false
            error = err
            print("❌ [LocalLLM] Failed to load model: \(err.localizedDescription)")
        } catch {
            isReady = false
            self.error = .generationFailed(error.localizedDescription)
            print("❌ [LocalLLM] Unknown error: \(error)")
        }
    }
    
    func generateResponse(prompt: String) async throws -> AsyncThrowingStream<String, Error> {
        let temperature = preferencesManager.preferences.enableCustomization
            ? preferencesManager.preferences.temperature.value
            : TemperatureSetting.default.value
        
        return try await engine.generate(
            prompt: prompt,
            maxTokens: 1024,
            temperature: temperature
        )
    }
    
    func buildPrompt(userMessage: String, systemPrompt: String? = nil, context: String? = nil) -> String {
        var prompt = ""
        
        // Add system prompt if customization is enabled
        if preferencesManager.preferences.enableCustomization,
           !preferencesManager.preferences.customInstructions.isEmpty {
            prompt += "System: \(preferencesManager.preferences.customInstructions)\n\n"
        } else if let system = systemPrompt {
            prompt += "System: \(system)\n\n"
        }
        
        // Add RAG context if available
        if let ctx = context, !ctx.isEmpty {
            prompt += "Context:\n\(ctx)\n\n"
        }
        
        // Add user message
        prompt += "User: \(userMessage)\n\nAssistant:"
        
        return prompt
    }
}
