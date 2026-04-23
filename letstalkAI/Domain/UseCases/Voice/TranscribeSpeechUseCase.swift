//
//  TranscribeSpeechUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol TranscribeSpeechUseCaseProtocol: Sendable {
    var isRecording: Bool { get }
    var recognizedText: String { get }
    
    func startRecording() async throws
    func startContinuousRecording(onAutoStop: @escaping @Sendable () -> Void) async throws
    func stopRecording()
    func exitContinuousMode()
    func clearRecognizedText()
    func requestPermissions() async -> Bool
}

final class TranscribeSpeechUseCase: TranscribeSpeechUseCaseProtocol, @unchecked Sendable {
    private let speechRepository: SpeechRepositoryProtocol
    
    var isRecording: Bool {
        speechRepository.isRecording
    }
    
    var recognizedText: String {
        speechRepository.recognizedText
    }
    
    init(speechRepository: SpeechRepositoryProtocol) {
        self.speechRepository = speechRepository
    }
    
    func startRecording() async throws {
        try await speechRepository.startRecording()
    }
    
    func startContinuousRecording(onAutoStop: @escaping @Sendable () -> Void) async throws {
        try await speechRepository.startContinuousRecording(onAutoStop: onAutoStop)
    }
    
    func stopRecording() {
        speechRepository.stopRecording()
    }
    
    func exitContinuousMode() {
        speechRepository.exitContinuousMode()
    }
    
    func clearRecognizedText() {
        speechRepository.clearRecognizedText()
    }
    
    func requestPermissions() async -> Bool {
        await speechRepository.requestPermissions()
    }
}
