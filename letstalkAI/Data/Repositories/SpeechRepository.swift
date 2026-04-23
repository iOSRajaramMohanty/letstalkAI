//
//  SpeechRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation for Speech services
//

import Foundation
import Speech
import AVFoundation
import UIKit

final class SpeechRepository: SpeechRepositoryProtocol, @unchecked Sendable {
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var speechDelegate: SpeechDelegateHandler?
    
    private var _isRecording = false
    private var _isSpeaking = false
    private var _recognizedText = ""
    private var _currentSpeakingText = ""
    
    private var silenceTimer: Timer?
    private var continuousMode = false
    private var onAutoStopCallback: (() -> Void)?
    
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    
    var isRecording: Bool { _isRecording }
    var isSpeaking: Bool { speechSynthesizer.isSpeaking }
    var recognizedText: String { _recognizedText }
    var currentSpeakingText: String { _currentSpeakingText }
    
    init() {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    }
    
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            return false
        }
        
        let audioStatus = await AVAudioApplication.requestRecordPermission()
        return audioStatus
    }
    
    func startRecording() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognitionFailed("Speech recognizer not available")
        }
        
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw SpeechError.notAuthorized
        }
        
        cancelPreviousTask()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionFailed("Could not create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        await MainActor.run {
            feedbackGenerator?.prepare()
            feedbackGenerator?.impactOccurred()
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self._recognizedText = result.bestTranscription.formattedString
                
                if self.continuousMode {
                    self.resetSilenceTimer()
                }
                
                if result.isFinal {
                    self.finishRecording()
                }
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
                self.finishRecording()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        _isRecording = true
    }
    
    func startContinuousRecording(onAutoStop: @escaping @Sendable () -> Void) async throws {
        continuousMode = true
        onAutoStopCallback = onAutoStop
        try await startRecording()
    }
    
    func stopRecording() {
        finishRecording()
        onAutoStopCallback = nil
    }
    
    func exitContinuousMode() {
        continuousMode = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        onAutoStopCallback = nil
        stopRecording()
    }
    
    func clearRecognizedText() {
        _recognizedText = ""
    }
    
    private func cancelPreviousTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func finishRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        _isRecording = false
        
        Task { @MainActor in
            feedbackGenerator?.impactOccurred()
        }
        
        if continuousMode {
            onAutoStopCallback?()
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.continuousMode else { return }
            self.finishRecording()
        }
    }
    
    // MARK: - Text to Speech
    
    func speak(_ text: String) async {
        await speak(text, completion: {})
    }
    
    func speak(_ text: String, completion: @escaping @Sendable () -> Void) async {
        stopSpeaking()
        
        _currentSpeakingText = text
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let handler = SpeechDelegateHandler(onFinish: {
                completion()
                continuation.resume()
            })
            
            self.speechDelegate = handler
            self.speechSynthesizer.delegate = handler
            self.speechSynthesizer.speak(utterance)
        }
    }
    
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        _currentSpeakingText = ""
    }
}

private final class SpeechDelegateHandler: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}
