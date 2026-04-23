//
//  LetsTalkAIApp.swift
//  letstalkAI
//
//  Main entry point for the letstalkAI application
//

import SwiftUI

@main
struct LetsTalkAIApp: App {
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    private let container = DependencyContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainView(
                    chatViewModel: container.makeChatViewModel(),
                    sessionListViewModel: container.makeSessionListViewModel()
                )
                
                if showOnboarding {
                    OnboardingView(viewModel: container.makeOnboardingViewModel())
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showOnboarding)
            .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
                withAnimation {
                    showOnboarding = false
                }
            }
        }
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
