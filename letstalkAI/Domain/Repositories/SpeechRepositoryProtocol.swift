//
//  SpeechRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol SpeechRepositoryProtocol: Sendable {
    var isRecording: Bool { get }
    var isSpeaking: Bool { get }
    var recognizedText: String { get }
    var currentSpeakingText: String { get }
    
    func startRecording() async throws
    func startContinuousRecording(onAutoStop: @escaping @Sendable () -> Void) async throws
    func stopRecording()
    func exitContinuousMode()
    func clearRecognizedText()
    
    func speak(_ text: String) async
    func speak(_ text: String, completion: @escaping @Sendable () -> Void) async
    func stopSpeaking()
    
    func requestPermissions() async -> Bool
}

enum SpeechError: Error, LocalizedError, Sendable {
    case notAuthorized
    case microphoneAccessDenied
    case recognitionFailed(String)
    case speechSynthesisFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .microphoneAccessDenied:
            return "Microphone permission denied"
        case .recognitionFailed(let message):
            return "Speech recognition error: \(message)"
        case .speechSynthesisFailed(let message):
            return "Text-to-speech error: \(message)"
        }
    }
}
