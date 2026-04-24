//
//  SettingsView.swift
//  letstalkAI
//
//  App settings view - Cross-platform (iOS/macOS)
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showTutorial = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                appHeader
                
                appearanceSection
                
                helpSection
                
                communitySection
                
                legalSection
                
                versionFooter
            }
            .padding()
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        #elseif os(macOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .frame(minWidth: 450, minHeight: 600)
        #endif
        .preferredColorScheme(viewModel.colorScheme)
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    // MARK: - App Header
    
    private var appHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("letstalkAI")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Private On-Device AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Appearance")
            
            VStack(spacing: 0) {
                HStack {
                    settingsIcon("paintpalette.fill", color: .blue)
                    
                    Text("Color Scheme")
                        .font(.body)
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { colorSchemeOption },
                        set: { viewModel.setColorScheme($0.colorScheme) }
                    )) {
                        ForEach(ColorSchemeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.blue)
                }
                .padding()
                .background(cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Help & Tutorial")
            
            VStack(spacing: 0) {
                settingsLinkRow(
                    icon: "graduationcap.fill",
                    iconColor: .purple,
                    title: "View Tutorial",
                    showChevron: true
                ) {
                    showTutorial = true
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showTutorial) {
            OnboardingView(isFromSettings: true) {
                showTutorial = false
            }
        }
    }
    
    // MARK: - Community Section
    
    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Community & Support")
            
            VStack(spacing: 0) {
                settingsLinkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    iconColor: .gray,
                    title: "GitHub",
                    showExternalLink: true
                ) {
                    viewModel.openURL(viewModel.githubURL)
                }
                
                Divider()
                    .padding(.leading, 56)
                
                settingsLinkRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .indigo,
                    title: "Discord",
                    showExternalLink: true
                ) {
                    viewModel.openURL(viewModel.discordURL)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Legal")
            
            VStack(spacing: 0) {
                settingsLinkRow(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: "Privacy Policy",
                    showExternalLink: true
                ) {
                    viewModel.openURL(viewModel.privacyURL)
                }
                
                Divider()
                    .padding(.leading, 56)
                
                settingsLinkRow(
                    icon: "doc.text.fill",
                    iconColor: .green,
                    title: "Terms of Service",
                    showExternalLink: true
                ) {
                    viewModel.openURL(viewModel.termsURL)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Version Footer
    
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Version \(viewModel.appVersion) (\(viewModel.buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Powered by Apple Intelligence")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
    
    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func settingsLinkRow(
        icon: String,
        iconColor: Color,
        title: String,
        showChevron: Bool = false,
        showExternalLink: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                settingsIcon(icon, color: iconColor)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                
                if showExternalLink {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }
    
    private var cardBackground: some View {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    private var colorSchemeOption: ColorSchemeOption {
        if let scheme = viewModel.colorScheme {
            return scheme == .light ? .light : .dark
        }
        return .system
    }
}

enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel())
    }
}
