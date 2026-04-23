//
//  SpeakTextUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol SpeakTextUseCaseProtocol: Sendable {
    var isSpeaking: Bool { get }
    var currentText: String { get }
    
    func execute(text: String) async
    func execute(text: String, completion: @escaping @Sendable () -> Void) async
    func stop()
}

final class SpeakTextUseCase: SpeakTextUseCaseProtocol, @unchecked Sendable {
    private let speechRepository: SpeechRepositoryProtocol
    
    var isSpeaking: Bool {
        speechRepository.isSpeaking
    }
    
    var currentText: String {
        speechRepository.currentSpeakingText
    }
    
    init(speechRepository: SpeechRepositoryProtocol) {
        self.speechRepository = speechRepository
    }
    
    func execute(text: String) async {
        await speechRepository.speak(text)
    }
    
    func execute(text: String, completion: @escaping @Sendable () -> Void) async {
        await speechRepository.speak(text, completion: completion)
    }
    
    func stop() {
        speechRepository.stopSpeaking()
    }
}
