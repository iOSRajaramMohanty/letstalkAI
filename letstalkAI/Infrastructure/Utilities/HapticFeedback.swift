//
//  HapticFeedback.swift
//  letstalkAI
//
//  Haptic feedback utility - Cross-platform (iOS/macOS)
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum HapticFeedback: Sendable {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    
    func trigger() {
        #if os(iOS)
        triggerIOS()
        #elseif os(macOS)
        triggerMacOS()
        #endif
    }
    
    #if os(iOS)
    private func triggerIOS() {
        switch self {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
            
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
    #endif
    
    #if os(macOS)
    private func triggerMacOS() {
        switch self {
        case .light, .medium, .heavy, .selection:
            NSHapticFeedbackManager.defaultPerformer.perform(
                .generic,
                performanceTime: .default
            )
            
        case .success:
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .default
            )
            
        case .warning, .error:
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .default
            )
        }
    }
    #endif
}
