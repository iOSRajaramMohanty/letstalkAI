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
    
    init() {
        // Load MLX download preference from UserDefaults
        // Default is FALSE for development (placeholder mode - faster for testing)
        // Toggle ON in Settings → Developer → Real MLX Downloads for actual AI
        let useRealMLX = UserDefaults.standard.bool(forKey: "useRealMLXDownload")
        ModelDownloadManager.shared.useRealMLXDownload = useRealMLX
        
        // Load Resilient Downloader preference
        // Default is TRUE - enables parallel chunk downloads with auto-resume
        // Recommended for poor network connections and large model downloads
        let useResilientDefault = UserDefaults.standard.object(forKey: "useResilientDownloader") == nil
        let useResilient = useResilientDefault ? true : UserDefaults.standard.bool(forKey: "useResilientDownloader")
        ModelDownloadManager.shared.useResilientDownloader = useResilient
        
        // Check NLEmbedding availability for RAG
        checkEmbeddingAvailability()
    }
    
    private func checkEmbeddingAvailability() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 [Startup] NLEmbedding Availability Check")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let description = VectorDatabaseManager.embeddingDescription()
        
        if VectorDatabaseManager.isEmbeddingAvailable() {
            print("✅ NLEmbedding: Available")
            print("   Type: \(description)")
            print("   RAG with vector search will work normally")
        } else {
            print("⚠️ NLEmbedding: NOT Available")
            print("   Possible reasons:")
            print("   - Embedding model not downloaded to device")
            print("   - Running on iOS Simulator (limited NL support)")
            print("   - Memory pressure preventing model load")
            print("   - First launch - system may download assets")
            print("   Web search will use raw text fallback")
        }
        
        #if targetEnvironment(simulator)
        print("📱 Running on Simulator - NLEmbedding may be limited")
        #endif
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
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
    static let conversationsDeleted = Notification.Name("conversationsDeleted")
    static let modelSelected = Notification.Name("modelSelected")
}
