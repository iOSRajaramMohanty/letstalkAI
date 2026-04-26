//
//  SettingsViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel for Settings - Cross-platform (iOS/macOS)
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var appVersion: String = ""
    @Published var buildNumber: String = ""
    
    private let sessionRepository: SessionRepositoryProtocol
    
    init(sessionRepository: SessionRepositoryProtocol? = nil) {
        self.sessionRepository = sessionRepository ?? DependencyContainer.shared.sessionRepository
        loadAppInfo()
        loadColorSchemePreference()
    }
    
    private func loadAppInfo() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
    }
    
    private func loadColorSchemePreference() {
        let scheme = UserDefaults.standard.string(forKey: "colorScheme")
        switch scheme {
        case "light":
            colorScheme = .light
        case "dark":
            colorScheme = .dark
        default:
            colorScheme = nil
        }
    }
    
    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        
        if let scheme = scheme {
            UserDefaults.standard.set(scheme == .light ? "light" : "dark", forKey: "colorScheme")
        } else {
            UserDefaults.standard.removeObject(forKey: "colorScheme")
        }
    }
    
    func deleteAllConversations() {
        Task {
            do {
                let sessions = try await sessionRepository.getAllSessions()
                for session in sessions {
                    try await sessionRepository.deleteSession(session.id)
                }
                NotificationCenter.default.post(name: .conversationsDeleted, object: nil)
                print("✅ [Settings] All conversations deleted")
            } catch {
                print("❌ [Settings] Failed to delete conversations: \(error)")
            }
        }
    }
    
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    var githubURL: String {
        "https://github.com/iOSRajaramMohanty/letstalkAI"
    }
    
    var discordURL: String {
        "https://discord.gg/letstalkAI"
    }
    
    var privacyURL: String {
        "https://letstalkAI.app/privacy"
    }
    
    var termsURL: String {
        "https://letstalkAI.app/terms"
    }
    
    var licensesURL: String {
        "https://letstalkAI.app/licenses"
    }
}
