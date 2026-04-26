//
//  OnboardingViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel for Onboarding
//

import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var isComplete: Bool = false
    @Published var showModelSelection: Bool = false
    
    let isFromSettings: Bool
    private let onComplete: (() -> Void)?
    
    init(isFromSettings: Bool = false, onComplete: (() -> Void)? = nil) {
        self.isFromSettings = isFromSettings
        self.onComplete = onComplete
    }
    
    let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to letstalkAI",
            description: "Your personal AI assistant powered by Apple Intelligence, running entirely on your device.",
            iconName: "brain.filled.head.profile",
            color: .blue
        ),
        OnboardingStep(
            title: "Chat Naturally",
            description: "Have conversations with AI using text or voice. Get intelligent responses instantly.",
            iconName: "bubble.left.and.bubble.right.fill",
            color: .purple
        ),
        OnboardingStep(
            title: "Knowledge Base",
            description: "Upload PDFs and documents. The AI will use them to provide context-aware answers.",
            iconName: "doc.text.fill",
            color: .orange
        ),
        OnboardingStep(
            title: "Web Search",
            description: "Enable web search to get up-to-date information from the internet.",
            iconName: "globe",
            color: .green
        ),
        OnboardingStep(
            title: "Private & Secure",
            description: "All AI processing happens on your device. Your conversations stay private.",
            iconName: "lock.shield.fill",
            color: .cyan
        )
    ]
    
    func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    func previousStep() {
        if currentStep > 0 {
            withAnimation {
                currentStep -= 1
            }
        }
    }
    
    func skip() {
        completeOnboarding()
    }
    
    func proceedToModelSelection() {
        withAnimation {
            showModelSelection = true
        }
    }
    
    func skipModelSelection() {
        completeOnboarding()
    }
    
    func completeOnboarding() {
        if isFromSettings {
            onComplete?()
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            isComplete = true
            NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        }
    }
}

struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let color: Color
}
