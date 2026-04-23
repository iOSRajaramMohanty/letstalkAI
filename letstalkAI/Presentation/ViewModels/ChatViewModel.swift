//
//  ChatViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel
//

import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentResponse: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentSession: ChatSession?
    @Published var showSources: Bool = false
    @Published var currentSources: [WebSearchResult] = []
    
    private let sendMessageUseCase: SendMessageUseCaseProtocol
    private let getChatHistoryUseCase: GetChatHistoryUseCaseProtocol
    private let generateTitleUseCase: GenerateTitleUseCaseProtocol
    private let speakTextUseCase: SpeakTextUseCaseProtocol
    
    init(
        sendMessageUseCase: SendMessageUseCaseProtocol,
        getChatHistoryUseCase: GetChatHistoryUseCaseProtocol,
        generateTitleUseCase: GenerateTitleUseCaseProtocol,
        speakTextUseCase: SpeakTextUseCaseProtocol
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.getChatHistoryUseCase = getChatHistoryUseCase
        self.generateTitleUseCase = generateTitleUseCase
        self.speakTextUseCase = speakTextUseCase
    }
    
    func loadSession(_ session: ChatSession) async {
        currentSession = session
        
        do {
            messages = try await getChatHistoryUseCase.execute(sessionId: session.id)
            
            if let transcriptJSON = try await DependencyContainer.shared.sessionRepository.loadTranscript(for: session.id) {
                try await DependencyContainer.shared.llmRepository.loadTranscript(transcriptJSON, sessionId: session.id)
            }
        } catch {
            addErrorMessage("Failed to load chat history: \(error.localizedDescription)")
        }
    }
    
    func sendMessage(_ text: String) async {
        guard let session = currentSession, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        currentResponse = ""
        errorMessage = nil
        
        do {
            let response = try await sendMessageUseCase.execute(
                message: text,
                session: session
            ) { @Sendable [weak self] partial in
                Task { @MainActor in
                    self?.currentResponse = partial
                }
            }
            
            messages.append(response)
            currentResponse = ""
            
            if let sources = response.sources, !sources.isEmpty {
                currentSources = sources
            }
            
            if session.title.isEmpty && messages.count == 2 {
                await generateSessionTitle(from: response.text)
            }
            
        } catch let error as LLMError {
            handleLLMError(error)
        } catch {
            addErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func handleLLMError(_ error: LLMError) {
        switch error {
        case .contextWindowExceeded:
            addErrorMessage("The conversation has exceeded the context limit. Starting a new session.")
            
        case .rateLimited:
            addErrorMessage(error.errorDescription ?? "The AI is currently rate limited. Please wait a moment and try again.")
            
        case .safetyGuardrail:
            addErrorMessage(error.errorDescription ?? "Unable to respond to this query due to safety guidelines.")
            
        case .generationFailed(let message):
            addErrorMessage(message)
            
        case .sessionNotFound:
            addErrorMessage(error.errorDescription ?? "Chat session not found. Please start a new conversation.")
        }
    }
    
    private func addErrorMessage(_ text: String) {
        let errorChatMessage = ChatMessage(
            text: text,
            isUser: false
        )
        messages.append(errorChatMessage)
    }
    
    private func generateSessionTitle(from response: String) async {
        guard let session = currentSession, session.title.isEmpty else { return }
        
        do {
            let title = try await generateTitleUseCase.execute(from: response, sessionId: session.id)
            _ = try await DependencyContainer.shared.sessionRepository.updateSessionTitle(session.id, title: title)
            currentSession?.title = title
        } catch {
            print("Failed to generate title: \(error)")
        }
    }
    
    func speakMessage(_ text: String) async {
        await speakTextUseCase.execute(text: text)
    }
    
    func stopSpeaking() {
        speakTextUseCase.stop()
    }
    
    func toggleWebSearch() async {
        guard var session = currentSession else { return }
        
        session.useWebSearch.toggle()
        currentSession = session
        
        do {
            try await DependencyContainer.shared.sessionRepository.updateSessionWebSearch(
                session.id,
                useWebSearch: session.useWebSearch
            )
        } catch {
            print("Failed to update web search setting: \(error)")
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
