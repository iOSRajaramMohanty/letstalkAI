//
//  LLMRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation using Apple FoundationModels
//  Cross-platform (iOS/macOS)
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

final class LLMRepository: LLMRepositoryProtocol, @unchecked Sendable {
    private var respondingState = false
    private var hasLoggedDeviceSupport = false
    
    var isResponding: Bool {
        respondingState
    }
    
    private func logDeviceSupport() {
        guard !hasLoggedDeviceSupport else { return }
        hasLoggedDeviceSupport = true
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🤖 [LLM] Apple Intelligence Support Check")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        #if os(iOS)
        let osName = "iOS"
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(currentVersion.majorVersion).\(currentVersion.minorVersion).\(currentVersion.patchVersion)"
        print("   📱 Platform: iOS")
        print("   📱 Current Version: \(versionString)")
        print("   📱 Required Version: iOS 26.0+")
        #elseif os(macOS)
        let osName = "macOS"
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(currentVersion.majorVersion).\(currentVersion.minorVersion).\(currentVersion.patchVersion)"
        print("   💻 Platform: macOS")
        print("   💻 Current Version: \(versionString)")
        print("   💻 Required Version: macOS 26.0+")
        #endif
        
        #if canImport(FoundationModels)
        print("   ✅ FoundationModels framework: Available")
        if #available(iOS 26.0, macOS 26.0, *) {
            print("   ✅ OS version: Supported")
            print("   ✅ Apple Intelligence: Should be available")
            print("   ℹ️  Note: Actual availability depends on device hardware and settings")
        } else {
            print("   ❌ OS version: Not supported (need iOS/macOS 26.0+)")
            print("   ❌ Apple Intelligence: Not available")
        }
        #else
        print("   ❌ FoundationModels framework: Not available")
        print("   ❌ Apple Intelligence: Not supported on this platform")
        #endif
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    func getOrCreateSession(sessionId: String) async {
        logDeviceSupport()
        
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            print("🤖 [LLM] Creating/getting session: \(sessionId.prefix(20))...")
            await LLMSessionStore.shared.createSession(sessionId)
            print("✅ [LLM] Session ready")
        } else {
            print("❌ [LLM] Cannot create session - OS version not supported")
        }
        #else
        print("❌ [LLM] Cannot create session - FoundationModels not available")
        #endif
    }
    
    func generateResponse(prompt: String, sessionId: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish(throwing: LLMError.sessionNotFound)
                    return
                }
                
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("🤖 [LLM] Generating response...")
                print("   📝 Prompt length: \(prompt.count) characters")
                print("   📋 Session: \(sessionId.prefix(20))...")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                self.respondingState = true
                
                let selectedLocalModelId = await MainActor.run {
                    ModelDownloadManager.shared.selectedModelId
                }
                
                let hasDownloadedModels = await MainActor.run {
                    !ModelDownloadManager.shared.downloadedModels.isEmpty
                }
                
                if let localModelId = selectedLocalModelId, hasDownloadedModels {
                    print("🤖 [LLM] Using Local Model: \(localModelId)")
                    await self.generateWithLocalModel(
                        prompt: prompt,
                        modelId: localModelId,
                        continuation: continuation
                    )
                    return
                }
                
                self.logDeviceSupport()
                
                #if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, *) {
                    print("🤖 [LLM] Using Apple Intelligence (FoundationModels)...")
                    do {
                        try await LLMSessionStore.shared.streamResponse(
                            prompt: prompt,
                            sessionId: sessionId
                        ) { text in
                            continuation.yield(text)
                        }
                        
                        self.respondingState = false
                        print("✅ [LLM] Response streaming complete")
                        continuation.finish()
                    } catch {
                        self.respondingState = false
                        print("❌ [LLM] Generation failed: \(error.localizedDescription)")
                        let mappedError = self.mapError(error)
                        continuation.finish(throwing: mappedError)
                    }
                } else {
                    self.respondingState = false
                    print("❌ [LLM] OS version not supported")
                    #if os(iOS)
                    continuation.finish(throwing: LLMError.generationFailed("Apple Intelligence requires iOS 26 or newer. Download a local model from Settings > Manage models to use offline AI."))
                    #elseif os(macOS)
                    continuation.finish(throwing: LLMError.generationFailed("Apple Intelligence requires macOS 26 or newer. Download a local model from Settings > Manage models to use offline AI."))
                    #endif
                }
                #else
                self.respondingState = false
                print("❌ [LLM] FoundationModels not available on this platform")
                continuation.finish(throwing: LLMError.generationFailed("Apple Intelligence is not available on this device. Download a local model from Settings > Manage models to use offline AI."))
                #endif
            }
        }
    }
    
    @MainActor
    private func generateWithLocalModel(
        prompt: String,
        modelId: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        let engine = LocalLLMEngine.shared
        
        do {
            if !engine.isModelLoaded || engine.currentModelId != modelId {
                print("🤖 [LLM] Loading local model: \(modelId)")
                try await engine.loadModel(modelId)
            }
            
            let userPrefs = UserPreferencesManager.shared
            let temperature = userPrefs.preferences.temperature.value
            let customInstructions = userPrefs.preferences.enableCustomization ? userPrefs.preferences.customInstructions : nil
            
            var fullPrompt = prompt
            if let instructions = customInstructions, !instructions.isEmpty {
                fullPrompt = "System Instructions: \(instructions)\n\nUser Query: \(prompt)"
            }
            
            print("🤖 [LLM] Generating with temperature: \(temperature)")
            
            let stream = try await engine.generate(
                prompt: fullPrompt,
                maxTokens: 1024,
                temperature: temperature
            )
            
            for try await text in stream {
                continuation.yield(text)
            }
            
            respondingState = false
            print("✅ [LLM] Local model response complete")
            continuation.finish()
            
        } catch {
            respondingState = false
            print("❌ [LLM] Local model generation failed: \(error.localizedDescription)")
            continuation.finish(throwing: LLMError.generationFailed("Local model error: \(error.localizedDescription)"))
        }
    }
    
    private func mapError(_ error: Error) -> LLMError {
        let errorDescription = error.localizedDescription.lowercased()
        
        print("🔍 [LLM] Analyzing error: \(error.localizedDescription)")
        
        if errorDescription.contains("guardrail") {
            print("⚠️ [LLM] Error type: Safety guardrail triggered")
            return .safetyGuardrail
        } else if errorDescription.contains("rate") || errorDescription.contains("limit") {
            print("⚠️ [LLM] Error type: Rate limited")
            return .rateLimited
        } else if errorDescription.contains("context") || errorDescription.contains("window") || errorDescription.contains("exceeded") {
            print("⚠️ [LLM] Error type: Context window exceeded")
            return .contextWindowExceeded
        } else if errorDescription.contains("not available") || errorDescription.contains("missing") || errorDescription.contains("-1") || errorDescription.contains("model") || errorDescription.contains("asset") {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("⚠️ [LLM] Error type: Apple Intelligence not available")
            print("   This could be because:")
            print("   • Device doesn't support Apple Intelligence")
            print("   • Apple Intelligence is not enabled in Settings")
            print("   • Model assets are not downloaded")
            print("   • Running on Simulator (not supported)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #if os(iOS)
            return .generationFailed("Apple Intelligence is not available. Please ensure you're running on a device with Apple Intelligence enabled (iPhone 15 Pro or newer with iOS 26+).")
            #elseif os(macOS)
            return .generationFailed("Apple Intelligence is not available. Please ensure you're running on an Apple Silicon Mac with macOS 26+ and Apple Intelligence enabled.")
            #endif
        }
        
        print("⚠️ [LLM] Error type: Unknown - \(error.localizedDescription)")
        return .generationFailed("AI response failed: \(error.localizedDescription)")
    }
    
    func generateTitle(from response: String, sessionId: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await LLMSessionStore.shared.generateTitle(from: response)
        }
        #endif
        
        let snippet = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
        let words = snippet.split(separator: " ")
        let truncated = words.prefix(5).joined(separator: " ")
        return truncated.isEmpty ? "New Chat" : String(truncated)
    }
    
    func saveTranscript(sessionId: String) async throws -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await LLMSessionStore.shared.saveTranscript(sessionId: sessionId)
        }
        #endif
        return nil
    }
    
    func loadTranscript(_ transcriptJSON: String, sessionId: String) async throws {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await LLMSessionStore.shared.loadTranscript(transcriptJSON, sessionId: sessionId)
        }
        #endif
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
actor LLMSessionStore {
    static let shared = LLMSessionStore()
    
    private var sessions: [String: LanguageModelSession] = [:]
    
    func createSession(_ sessionId: String) {
        if sessions[sessionId] == nil {
            sessions[sessionId] = LanguageModelSession()
        }
    }
    
    func resetSession(_ sessionId: String) {
        print("🔄 [LLM] Resetting session due to context limit...")
        sessions[sessionId] = LanguageModelSession()
    }
    
    func streamResponse(
        prompt: String,
        sessionId: String,
        onPartial: @Sendable (String) -> Void
    ) async throws {
        guard var session = sessions[sessionId] else {
            throw LLMError.sessionNotFound
        }
        
        do {
            let responseStream = session.streamResponse(to: prompt, generating: String.self)
            
            for try await partialResponse in responseStream {
                onPartial(partialResponse.content)
            }
        } catch {
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("context") || errorDesc.contains("exceeded") || errorDesc.contains("window") {
                print("⚠️ [LLM] Context exceeded, resetting session and retrying...")
                
                sessions[sessionId] = LanguageModelSession()
                session = sessions[sessionId]!
                
                print("🔄 [LLM] Retrying with fresh session")
                let retryStream = session.streamResponse(to: prompt, generating: String.self)
                for try await partialResponse in retryStream {
                    onPartial(partialResponse.content)
                }
            } else {
                throw error
            }
        }
    }
    
    func generateTitle(from response: String) async -> String {
        let session = LanguageModelSession()
        
        let promptText = """
        Based on the following conversation response, generate a very short title (2-5 words maximum) that captures the main topic. 
        Only respond with the title, nothing else. Do not use quotes or punctuation.
        
        Response: \(response.prefix(500))
        
        Title:
        """
        
        do {
            let result = try await session.respond(
                to: promptText,
                generating: String.self
            )
            
            let title = result.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .components(separatedBy: "\n").first ?? ""
            
            let words = title.split(separator: " ")
            let truncatedTitle = words.prefix(5).joined(separator: " ")
            
            return truncatedTitle.isEmpty ? "New Chat" : truncatedTitle
        } catch {
            return "New Chat"
        }
    }
    
    func saveTranscript(sessionId: String) -> String? {
        guard let session = sessions[sessionId] else {
            return nil
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(session.transcript) {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    func loadTranscript(_ transcriptJSON: String, sessionId: String) {
        guard !transcriptJSON.isEmpty,
              let data = transcriptJSON.data(using: .utf8) else {
            sessions[sessionId] = LanguageModelSession()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let transcript = try decoder.decode(Transcript.self, from: data)
            sessions[sessionId] = LanguageModelSession(transcript: transcript)
        } catch {
            sessions[sessionId] = LanguageModelSession()
        }
    }
}
#endif
