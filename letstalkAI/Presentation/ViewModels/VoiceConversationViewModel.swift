//
//  VoiceConversationViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel for Voice Conversation
//

import Foundation
import SwiftUI

@MainActor
final class VoiceConversationViewModel: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var aiResponse: String = ""
    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var conversationState: ConversationState = .idle
    
    enum ConversationState: Sendable {
        case idle
        case listening
        case processing
        case speaking
    }
    
    private let sendMessageUseCase: SendMessageUseCaseProtocol
    private let transcribeSpeechUseCase: TranscribeSpeechUseCaseProtocol
    private let speakTextUseCase: SpeakTextUseCaseProtocol
    
    private var session: ChatSession?
    private var recognitionTimer: Timer?
    
    init(
        sendMessageUseCase: SendMessageUseCaseProtocol,
        transcribeSpeechUseCase: TranscribeSpeechUseCaseProtocol,
        speakTextUseCase: SpeakTextUseCaseProtocol
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.transcribeSpeechUseCase = transcribeSpeechUseCase
        self.speakTextUseCase = speakTextUseCase
    }
    
    func setSession(_ session: ChatSession) {
        self.session = session
    }
    
    func requestPermissions() async -> Bool {
        await transcribeSpeechUseCase.requestPermissions()
    }
    
    func startListening() async {
        guard !isListening else { return }
        
        errorMessage = nil
        conversationState = .listening
        isListening = true
        recognizedText = ""
        
        do {
            try await transcribeSpeechUseCase.startContinuousRecording { @Sendable [weak self] in
                Task { @MainActor in
                    await self?.handleAutoStop()
                }
            }
            
            startObservingRecognition()
            
        } catch {
            errorMessage = error.localizedDescription
            conversationState = .idle
            isListening = false
        }
    }
    
    func stopListening() {
        stopObservingRecognition()
        transcribeSpeechUseCase.stopRecording()
        isListening = false
        
        if !recognizedText.isEmpty {
            Task {
                await processUserInput()
            }
        } else {
            conversationState = .idle
        }
    }
    
    private func handleAutoStop() async {
        stopObservingRecognition()
        recognizedText = transcribeSpeechUseCase.recognizedText
        isListening = false
        
        if !recognizedText.isEmpty {
            await processUserInput()
        } else {
            conversationState = .idle
        }
    }
    
    private func startObservingRecognition() {
        stopObservingRecognition()
        
        recognitionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if !self.isListening {
                    self.stopObservingRecognition()
                    return
                }
                
                self.recognizedText = self.transcribeSpeechUseCase.recognizedText
            }
        }
    }
    
    private func stopObservingRecognition() {
        recognitionTimer?.invalidate()
        recognitionTimer = nil
    }
    
    private func processUserInput() async {
        guard !recognizedText.isEmpty, let session = session else { return }
        
        conversationState = .processing
        isProcessing = true
        aiResponse = ""
        
        do {
            let response = try await sendMessageUseCase.execute(
                message: recognizedText,
                session: session
            ) { @Sendable [weak self] partial in
                Task { @MainActor in
                    self?.aiResponse = partial
                }
            }
            
            aiResponse = response.text
            
            await speakResponse()
            
        } catch {
            errorMessage = error.localizedDescription
            conversationState = .idle
        }
        
        isProcessing = false
    }
    
    private func speakResponse() async {
        guard !aiResponse.isEmpty else { return }
        
        conversationState = .speaking
        isSpeaking = true
        
        await speakTextUseCase.execute(text: aiResponse) { @Sendable [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
                self?.conversationState = .idle
            }
        }
    }
    
    func stopSpeaking() {
        speakTextUseCase.stop()
        isSpeaking = false
        conversationState = .idle
    }
    
    func reset() {
        stopObservingRecognition()
        stopSpeaking()
        transcribeSpeechUseCase.stopRecording()
        transcribeSpeechUseCase.clearRecognizedText()
        
        recognizedText = ""
        aiResponse = ""
        isListening = false
        isSpeaking = false
        isProcessing = false
        conversationState = .idle
    }
    
    func exitContinuousMode() {
        transcribeSpeechUseCase.exitContinuousMode()
        reset()
    }
}
