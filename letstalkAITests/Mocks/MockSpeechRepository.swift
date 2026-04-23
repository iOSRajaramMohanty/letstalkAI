//
//  MockSpeechRepository.swift
//  letstalkAITests
//
//  Mock implementation for testing
//

import Foundation
@testable import letstalkAI

final class MockSpeechRepository: SpeechRepositoryProtocol {
    var _isRecording = false
    var _isSpeaking = false
    var _recognizedText = ""
    var _currentSpeakingText = ""
    var shouldThrowError = false
    var errorToThrow: Error = SpeechError.notAuthorized
    var mockPermissionGranted = true
    
    var isRecording: Bool { _isRecording }
    var isSpeaking: Bool { _isSpeaking }
    var recognizedText: String { _recognizedText }
    var currentSpeakingText: String { _currentSpeakingText }
    
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var speakCalled = false
    
    func startRecording() async throws {
        startRecordingCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        _isRecording = true
    }
    
    func startContinuousRecording(onAutoStop: @escaping () -> Void) async throws {
        startRecordingCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        _isRecording = true
    }
    
    func stopRecording() {
        stopRecordingCalled = true
        _isRecording = false
    }
    
    func exitContinuousMode() {
        _isRecording = false
    }
    
    func clearRecognizedText() {
        _recognizedText = ""
    }
    
    func speak(_ text: String) async {
        speakCalled = true
        _currentSpeakingText = text
        _isSpeaking = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        _isSpeaking = false
    }
    
    func speak(_ text: String, completion: @escaping () -> Void) async {
        speakCalled = true
        _currentSpeakingText = text
        _isSpeaking = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        _isSpeaking = false
        completion()
    }
    
    func stopSpeaking() {
        _isSpeaking = false
        _currentSpeakingText = ""
    }
    
    func requestPermissions() async -> Bool {
        return mockPermissionGranted
    }
    
    func simulateRecognizedText(_ text: String) {
        _recognizedText = text
    }
    
    func reset() {
        _isRecording = false
        _isSpeaking = false
        _recognizedText = ""
        _currentSpeakingText = ""
        shouldThrowError = false
        mockPermissionGranted = true
        startRecordingCalled = false
        stopRecordingCalled = false
        speakCalled = false
    }
}
