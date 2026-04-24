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
            count: 1
        )
        
        let maxContextLength = 800
        let semanticContext = neighbors.map { neighbor -> String in
            let text = neighbor.text
            if text.count > maxContextLength {
                return String(text.prefix(maxContextLength)) + "..."
            }
            return text
        }.joined(separator: "\n")
        
        print("🌐 [Web] Context length: \(semanticContext.count) characters")
        
        let prompt = """
        Context: \(semanticContext)
        
        Q: \(query)
        A:
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
        var hasImagePageMatch = false
        
        let contextItems = neighbors.map { neighbor -> String in
            let text = neighbor.text
            
            if text.contains("[Image Page") {
                hasImagePageMatch = true
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
            imageDescriptions = "- Vehicle images from document\n"
        }
        
        let queryType = detectQueryType(query)
        let hasImages = !imageURLs.isEmpty
        let prompt = buildSmartPrompt(query: query, context: contextItems, imageDescriptions: imageDescriptions, queryType: queryType, hasImages: hasImages)
        
        print("📝 [RAG] Final prompt length: \(prompt.count) characters")
        print("🖼️ [RAG] Images will be displayed: \(hasImages ? "YES (\(imageURLs.count))" : "NO")")
        
        return (prompt, nil, imageURLs.isEmpty ? nil : imageURLs)
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
    
    private func buildSmartPrompt(query: String, context: String, imageDescriptions: String, queryType: QueryType, hasImages: Bool) -> String {
        var prompt = ""
        
        if !context.isEmpty {
            prompt += "Context: \(context)\n\n"
        }
        
        if hasImages {
            prompt += "IMAGES ARE DISPLAYED TO USER. You MUST acknowledge them.\n"
            if !imageDescriptions.isEmpty {
                prompt += "Image content: \(imageDescriptions)\n"
            }
            prompt += "Describe what is shown in a helpful way.\n\n"
        }
        
        prompt += "User asks: \(query)\n"
        prompt += "Your response (acknowledge images if shown):"
        
        return prompt
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
    
    private func detectSpecificFeature(query: String) -> String? {
        let featureKeywords: [String: [String]] = [
            "seat": ["seat", "seats", "seating"],
            "dashboard": ["dashboard", "dash"],
            "steering": ["steering", "wheel controls"],
            "gauge": ["gauge", "gauges", "speedometer", "instrument", "cluster"],
            "wheel": ["wheel", "wheels", "rim", "rims", "alloy"],
            "headlight": ["headlight", "headlights", "lamp", "lights"],
            "bumper": ["bumper", "front bumper", "rear bumper"],
            "grille": ["grille", "grill", "front grille"],
            "trunk": ["trunk", "boot", "cargo"]
        ]
        
        for (feature, keywords) in featureKeywords {
            if keywords.contains(where: { query.contains($0) }) {
                return feature
            }
        }
        return nil
    }
    
    private func hasFeatureLabel(_ image: DocumentImage, feature: String) -> Bool {
        let labelsLower = image.classificationLabels.map { $0.lowercased() }
        
        let featureLabelMap: [String: [String]] = [
            "seat": ["seat", "chair", "leather", "upholstery", "fabric", "cushion"],
            "dashboard": ["dashboard", "console", "control panel", "display"],
            "steering": ["steering wheel", "steering"],
            "gauge": ["gauge", "speedometer", "instrument", "dial", "meter"],
            "wheel": ["tire", "rim", "alloy", "rubber"],
            "headlight": ["headlight", "lamp", "light"],
            "bumper": ["bumper"],
            "grille": ["grille", "grill"],
            "trunk": ["trunk", "cargo", "boot"]
        ]
        
        let featureExcludeMap: [String: [String]] = [
            "wheel": ["engine", "motor", "gear", "piston", "cylinder", "mechanical", "diagram", "cutaway"],
            "steering": ["engine", "motor"]
        ]
        
        if let excludeLabels = featureExcludeMap[feature] {
            let hasExcluded = labelsLower.contains { label in
                excludeLabels.contains { label.contains($0) }
            }
            if hasExcluded {
                return false
            }
            
            let ocrLower = image.ocrText.lowercased()
            let hasExcludedOCR = excludeLabels.contains { ocrLower.contains($0) }
            if hasExcludedOCR {
                return false
            }
        }
        
        guard let matchLabels = featureLabelMap[feature] else { return false }
        
        return labelsLower.contains { label in
            matchLabels.contains { label.contains($0) }
        }
    }
    
    private func isInteriorImage(_ image: DocumentImage) -> Bool {
        let labelsLower = image.classificationLabels.map { $0.lowercased() }
        let exteriorIndicators = ["outdoor", "sky", "land", "building", "tree", "road", "street"]
        
        let hasExteriorIndicator = labelsLower.contains { label in
            exteriorIndicators.contains { label.contains($0) }
        }
        
        if hasExteriorIndicator {
            return false
        }
        
        let interiorLabels = ["dashboard", "steering wheel", "seat", "cockpit", "cabin", "gauge", "speedometer", "console", "interior", "control panel", "leather", "fabric", "button", "display", "screen", "panel"]
        
        return labelsLower.contains { label in
            interiorLabels.contains { label.contains($0) }
        }
    }
    
    private func isExteriorImage(_ image: DocumentImage) -> Bool {
        let labelsLower = image.classificationLabels.map { $0.lowercased() }
        let interiorLabels = ["dashboard", "steering wheel", "seat", "cockpit", "cabin", "gauge", "speedometer", "console", "interior", "leather", "panel", "display", "button"]
        let exteriorLabels = ["car", "vehicle", "automobile", "sedan", "suv", "outdoor", "wheel", "rim", "tire", "bumper", "headlight", "sky", "road", "land"]
        
        let hasInterior = labelsLower.contains { label in
            interiorLabels.contains { label.contains($0) }
        }
        
        if hasInterior {
            return false
        }
        
        return labelsLower.contains { label in
            exteriorLabels.contains { label.contains($0) }
        }
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
    
    private func getSemanticDescriptionOld(labels: [String]) -> String {
        let labelsLower = labels.map { $0.lowercased() }
        
        let interiorLabels = ["dashboard", "steering wheel", "seat", "cockpit", "cabin", "gauge", "speedometer", "console"]
        let exteriorLabels = ["car", "vehicle", "automobile", "sedan", "suv", "outdoor"]
        let wheelLabels = ["wheel", "tire", "rim", "alloy"]
        
        let hasInterior = labelsLower.contains { label in
            interiorLabels.contains { label.contains($0) }
        }
        
        let hasExterior = labelsLower.contains { label in
            exteriorLabels.contains { label.contains($0) }
        }
        
        let hasWheel = labelsLower.contains { label in
            wheelLabels.contains { label.contains($0) }
        }
        
        if hasInterior {
            return "Interior view showing dashboard/cabin"
        } else if hasWheel {
            return "Close-up of wheel/rim design"
        } else if hasExterior {
            return "Exterior view of the vehicle"
        } else if !labels.isEmpty {
            return "Image: \(labels.prefix(3).joined(separator: ", "))"
        }
        
        return ""
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
