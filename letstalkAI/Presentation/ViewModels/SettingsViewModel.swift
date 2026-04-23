//
//  SettingsViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel for Settings
//

import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var appVersion: String = ""
    @Published var buildNumber: String = ""
    
    init() {
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
    
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    var githubURL: String {
        "https://github.com/letstalkAI"
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
}
