//
//  UserPreferencesManager.swift
//  letstalkAI
//
//  Manages user preferences and personalization settings
//

import Foundation

@MainActor
final class UserPreferencesManager: ObservableObject {
    static let shared = UserPreferencesManager()
    
    @Published var preferences: UserPreferences
    
    private let preferencesKey = "userPreferences"
    
    private init() {
        self.preferences = Self.loadPreferences()
    }
    
    private static func loadPreferences() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: "userPreferences"),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: preferencesKey)
    }
    
    func updateCustomInstructions(_ instructions: String) {
        preferences.customInstructions = String(instructions.prefix(1000))
        save()
    }
    
    func updateTemperature(_ temperature: TemperatureSetting) {
        preferences.temperature = temperature
        save()
    }
    
    func toggleCustomization(_ enabled: Bool) {
        preferences.enableCustomization = enabled
        save()
    }
    
    func toggleKeyboardOnLaunch(_ enabled: Bool) {
        preferences.showKeyboardOnLaunch = enabled
        save()
    }
    
    func reset() {
        preferences = .default
        save()
    }
}
