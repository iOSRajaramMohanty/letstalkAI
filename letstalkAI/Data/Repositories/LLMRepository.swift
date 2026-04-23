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
    
    var isResponding: Bool {
        respondingState
    }
    
    func getOrCreateSession(sessionId: String) async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await LLMSessionStore.shared.createSession(sessionId)
        }
        #endif
    }
    
    func generateResponse(prompt: String, sessionId: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish(throwing: LLMError.sessionNotFound)
                    return
                }
                
                self.respondingState = true
                
                #if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, *) {
                    do {
                        try await LLMSessionStore.shared.streamResponse(
                            prompt: prompt,
                            sessionId: sessionId
                        ) { text in
                            continuation.yield(text)
                        }
                        
                        self.respondingState = false
                        continuation.finish()
                    } catch {
                        self.respondingState = false
                        let mappedError = self.mapError(error)
                        continuation.finish(throwing: mappedError)
                    }
                } else {
                    self.respondingState = false
                    #if os(iOS)
                    continuation.finish(throwing: LLMError.generationFailed("Apple Intelligence requires iOS 26 or newer."))
                    #elseif os(macOS)
                    continuation.finish(throwing: LLMError.generationFailed("Apple Intelligence requires macOS 26 or newer."))
                    #endif
                }
                #else
                self.respondingState = false
                continuation.finish(throwing: LLMError.generationFailed("Apple Intelligence is not available on this device."))
                #endif
            }
        }
    }
    
    private func mapError(_ error: Error) -> LLMError {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("guardrail") {
            return .safetyGuardrail
        } else if errorDescription.contains("rate") || errorDescription.contains("limit") {
            return .rateLimited
        } else if errorDescription.contains("context") || errorDescription.contains("window") || errorDescription.contains("exceeded") {
            return .contextWindowExceeded
        } else if errorDescription.contains("not available") || errorDescription.contains("missing") || errorDescription.contains("-1") {
            #if os(iOS)
            return .generationFailed("Apple Intelligence is not available. Please ensure you're running on a device with Apple Intelligence enabled (iPhone 15 Pro or newer with iOS 26+).")
            #elseif os(macOS)
            return .generationFailed("Apple Intelligence is not available. Please ensure you're running on an Apple Silicon Mac with macOS 26+ and Apple Intelligence enabled.")
            #endif
        }
        
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
    
    func streamResponse(
        prompt: String,
        sessionId: String,
        onPartial: @Sendable (String) -> Void
    ) async throws {
        guard let session = sessions[sessionId] else {
            throw LLMError.sessionNotFound
        }
        
        let responseStream = session.streamResponse(to: prompt, generating: String.self)
        
        for try await partialResponse in responseStream {
            onPartial(partialResponse.content)
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
