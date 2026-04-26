//
//  LocalLLMModel.swift
//  letstalkAI
//
//  Domain Entity - Local LLM Model definitions
//

import Foundation
import SwiftUI

struct LocalLLMModel: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let familyId: String
    let familyName: String
    let provider: String
    let providerIcon: String
    let description: String
    let sizeBytes: Int64
    let parameterCount: String
    let recommendedDevice: String
    let recommendedDeviceMac: String
    let capabilities: [ModelCapability]
    let tags: [ModelTag]
    let downloadURL: String
    let version: String
    
    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
    
    var isVisionCapable: Bool {
        capabilities.contains(.vision)
    }
    
    var isThinkingCapable: Bool {
        capabilities.contains(.thinking)
    }
    
    var platformRecommendedDevice: String {
        #if os(iOS)
        return recommendedDevice
        #elseif os(macOS)
        return recommendedDeviceMac
        #else
        return recommendedDevice
        #endif
    }
    
    var platformDescription: String {
        #if os(iOS)
        return description
        #elseif os(macOS)
        return description.replacingOccurrences(of: "Recommended for \(recommendedDevice).", with: "Recommended for \(recommendedDeviceMac).")
        #else
        return description
        #endif
    }
}

enum ModelCapability: String, Codable, Sendable, CaseIterable {
    case vision = "vision"
    case thinking = "thinking"
    case multilingual = "multilingual"
    case codeGeneration = "code"
    case rag = "rag"
    case summarization = "summarization"
    
    var displayName: String {
        switch self {
        case .vision: return "Vision"
        case .thinking: return "Thinking"
        case .multilingual: return "Multilingual"
        case .codeGeneration: return "Code"
        case .rag: return "RAG"
        case .summarization: return "Summarization"
        }
    }
    
    var color: Color {
        switch self {
        case .vision: return .yellow
        case .thinking: return .purple
        case .multilingual: return .blue
        case .codeGeneration: return .green
        case .rag: return .orange
        case .summarization: return .cyan
        }
    }
    
    var iconName: String {
        switch self {
        case .vision: return "eye"
        case .thinking: return "lightbulb.fill"
        case .multilingual: return "globe"
        case .codeGeneration: return "chevron.left.forwardslash.chevron.right"
        case .rag: return "doc.text.magnifyingglass"
        case .summarization: return "text.alignleft"
        }
    }
}

enum ModelTag: String, Codable, Sendable, CaseIterable {
    case new = "new"
    case best = "best"
    case recommended = "recommended"
    case experimental = "experimental"
    case legacy = "legacy"
    
    var displayName: String {
        switch self {
        case .new: return "New"
        case .best: return "Best"
        case .recommended: return "Recommended"
        case .experimental: return "Experimental"
        case .legacy: return "Legacy"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .green
        case .best: return .orange
        case .recommended: return .green
        case .experimental: return .purple
        case .legacy: return .gray
        }
    }
}

struct ModelFamily: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let provider: String
    let providerIcon: String
    let description: String
    let models: [LocalLLMModel]
    let category: ModelCategory
    
    var modelCount: Int {
        models.count
    }
    
    var capabilities: [ModelCapability] {
        Array(Set(models.flatMap { $0.capabilities }))
    }
    
    var tags: [ModelTag] {
        Array(Set(models.flatMap { $0.tags }))
    }
}

enum ModelCategory: String, Codable, Sendable, CaseIterable {
    case featured = "featured"
    case legacy = "legacy"
    case experimental = "experimental"
    
    var displayName: String {
        switch self {
        case .featured: return "Featured"
        case .legacy: return "Legacy models"
        case .experimental: return "Experimental models"
        }
    }
    
    var icon: String {
        switch self {
        case .featured: return "star.fill"
        case .legacy: return "clock.arrow.circlepath"
        case .experimental: return "flask.fill"
        }
    }
}

struct DownloadedModel: Identifiable, Codable, Sendable {
    let id: String
    let modelId: String
    let localPath: String
    let downloadedAt: Date
    let sizeBytes: Int64
    var isSelected: Bool
    
    var localURL: URL? {
        URL(string: localPath)
    }
}

enum ModelDownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
}

struct UserPreferences: Codable, Sendable {
    var selectedModelId: String?
    var customInstructions: String
    var enableCustomization: Bool
    var temperature: TemperatureSetting
    var showKeyboardOnLaunch: Bool
    
    static let `default` = UserPreferences(
        selectedModelId: nil,
        customInstructions: "",
        enableCustomization: false,
        temperature: .default,
        showKeyboardOnLaunch: false
    )
}

enum TemperatureSetting: String, Codable, Sendable, CaseIterable, Identifiable {
    case `default` = "Default"
    case precise = "Precise - 0.0"
    case consistent = "Consistent - 0.2"
    case balanced = "Balanced - 0.4"
    case creative = "Creative - 0.6"
    case veryCreative = "Very Creative - 0.8"
    case experimental = "Experimental - 1.0"
    
    var id: String { rawValue }
    
    var value: Double {
        switch self {
        case .default: return 0.7
        case .precise: return 0.0
        case .consistent: return 0.2
        case .balanced: return 0.4
        case .creative: return 0.6
        case .veryCreative: return 0.8
        case .experimental: return 1.0
        }
    }
}
