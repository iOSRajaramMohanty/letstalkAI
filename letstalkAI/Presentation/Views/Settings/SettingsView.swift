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
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTutorial = false
    @State private var showModelManagement = false
    @State private var showPersonalization = false
    @State private var showDeleteConversationsAlert = false
    @State private var showMLXInfoAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                siriShortcutsCard
                
                appSection
                
                developerSection
                
                appearanceSection
                
                helpSection
                
                communitySection
                
                legalSection
                
                versionFooter
            }
            .padding()
        }
        .background(backgroundColor.ignoresSafeArea())
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                Divider()
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        #endif
        #if os(iOS)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color.gray.opacity(0.15)))
                }
            }
        }
        #elseif os(macOS)
        .frame(minWidth: 450, minHeight: 700)
        #endif
        .preferredColorScheme(viewModel.colorScheme)
        .sheet(isPresented: $showTutorial) {
            OnboardingView(isFromSettings: true) {
                showTutorial = false
            }
        }
        .sheet(isPresented: $showModelManagement) {
            ModelManagementView()
        }
        .sheet(isPresented: $showPersonalization) {
            PersonalizationView()
        }
        .alert("Delete Conversation History", isPresented: $showDeleteConversationsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                viewModel.deleteAllConversations()
            }
        } message: {
            Text("This will permanently delete all your conversation history. This action cannot be undone.")
        }
        .alert("MLX Status", isPresented: $showMLXInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let hasMLXFiles = MLXModelRunner.shared.hasMLXFilesAvailable
            let isRealMLXActive = LocalLLMEngine.shared.isUsingRealMLX
            
            if isRealMLXActive {
                if let modelName = LocalLLMEngine.shared.currentModelId {
                    Text("Real MLX inference is active!\n\nModel: \(modelName)\nFramework: Apple MLX\nDevice: GPU (Apple Silicon)\n\nYour conversations are processed entirely on-device with real AI inference.")
                } else {
                    Text("Real MLX inference is active. Your local LLM model is using Apple's MLX framework for GPU-accelerated inference.")
                }
            } else if hasMLXFiles {
                Text("MLX model files are ready!\n\nThe model files have been downloaded successfully. Full MLX inference integration is pending.\n\nCurrently using intelligent placeholder responses while MLX inference is being finalized.")
            } else {
                Text("Placeholder mode is active.\n\nResponses are generated using intelligent keyword matching instead of real AI inference.\n\nTo enable real MLX:\n1. Enable 'Real MLX Downloads'\n2. Download a model with the MLX badge\n3. The status will update automatically")
            }
        }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    // MARK: - Siri Shortcuts Card
    
    private var siriShortcutsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Siri Shortcuts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Ask a question using your voice with Siri. Activate Siri and say \"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                + Text("Hey letstalkAI")
                    .font(.caption)
                    .fontWeight(.semibold)
                + Text("\" to ask.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("App")
            
            VStack(spacing: 0) {
                settingsLinkRow(
                    icon: "arrow.down.circle.fill",
                    iconColor: .green,
                    title: "Manage models",
                    subtitle: downloadManager.downloadedModels.isEmpty ? nil : "\(downloadManager.downloadedModels.count) downloaded",
                    showChevron: true
                ) {
                    showModelManagement = true
                }
                
                Divider()
                    .padding(.leading, 56)
                
                settingsLinkRow(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: "Personalization",
                    showChevron: true
                ) {
                    showPersonalization = true
                }
                
                Divider()
                    .padding(.leading, 56)
                
                HStack {
                    settingsIcon("keyboard.fill", color: .gray)
                    
                    Text("Show keyboard on launch")
                        .font(.body)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { preferencesManager.preferences.showKeyboardOnLaunch },
                        set: { preferencesManager.toggleKeyboardOnLaunch($0) }
                    ))
                    .labelsHidden()
                    .tint(.green)
                }
                .padding()
                .background(cardBackground)
                
                Divider()
                    .padding(.leading, 56)
                
                Button {
                    showDeleteConversationsAlert = true
                } label: {
                    HStack {
                        settingsIcon("trash.fill", color: .red)
                        
                        Text("Delete conversation history")
                            .font(.body)
                            .foregroundStyle(.red)
                        
                        Spacer()
                    }
                    .padding()
                    .background(cardBackground)
                }
                .buttonStyle(.plain)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Developer Section
    
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Developer")
            
            VStack(spacing: 0) {
                HStack {
                    settingsIcon("cpu.fill", color: .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Real MLX Downloads")
                            .font(.body)
                        
                        Text(downloadManager.useRealMLXDownload ? "Downloads real AI models (500MB-4GB)" : "Uses placeholder mode (instant)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { downloadManager.useRealMLXDownload },
                        set: { newValue in
                            downloadManager.useRealMLXDownload = newValue
                            UserDefaults.standard.set(newValue, forKey: "useRealMLXDownload")
                        }
                    ))
                    .labelsHidden()
                    .tint(.orange)
                }
                .padding()
                .background(cardBackground)
                
                Divider()
                    .padding(.leading, 56)
                
                HStack {
                    settingsIcon("arrow.trianglehead.2.clockwise.rotate.90.circle.fill", color: .cyan)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resilient Downloader")
                            .font(.body)
                        
                        Text(downloadManager.useResilientDownloader ? "Parallel chunks, auto-resume (recommended)" : "Standard download (single connection)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { downloadManager.useResilientDownloader },
                        set: { newValue in
                            downloadManager.useResilientDownloader = newValue
                            UserDefaults.standard.set(newValue, forKey: "useResilientDownloader")
                        }
                    ))
                    .labelsHidden()
                    .tint(.cyan)
                }
                .padding()
                .background(cardBackground)
                
                Divider()
                    .padding(.leading, 56)
                
                HStack {
                    settingsIcon("bolt.fill", color: .purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MLX Status")
                            .font(.body)
                        
                        let mlxStatus = MLXModelRunner.shared.mlxStatusDescription
                        let hasMLXFiles = MLXModelRunner.shared.hasMLXFilesAvailable
                        
                        HStack(spacing: 4) {
                            Text(mlxStatus)
                                .font(.caption)
                                .foregroundStyle(hasMLXFiles ? .green : .orange)
                            if MLXModelRunner.shared.tokensPerSecond > 0 {
                                Text("• \(String(format: "%.1f", MLXModelRunner.shared.tokensPerSecond)) tok/s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showMLXInfoAlert = true
                    } label: {
                        let hasMLXFiles = MLXModelRunner.shared.hasMLXFilesAvailable
                        Image(systemName: hasMLXFiles ? "checkmark.circle.fill" : "info.circle.fill")
                            .foregroundStyle(hasMLXFiles ? .green : .orange)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
            sectionHeader("About")
            
            VStack(spacing: 0) {
                settingsLinkRow(
                    icon: "doc.text.fill",
                    iconColor: .gray,
                    title: "Term & Conditions",
                    showChevron: true
                ) {
                    viewModel.openURL(viewModel.termsURL)
                }
                
                Divider()
                    .padding(.leading, 56)
                
                settingsLinkRow(
                    icon: "lock.fill",
                    iconColor: .gray,
                    title: "Privacy Policy",
                    showChevron: true
                ) {
                    viewModel.openURL(viewModel.privacyURL)
                }
                
                Divider()
                    .padding(.leading, 56)
                
                settingsLinkRow(
                    icon: "doc.plaintext.fill",
                    iconColor: .gray,
                    title: "Licenses",
                    showChevron: true
                ) {
                    viewModel.openURL(viewModel.licensesURL)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            sectionHeader("Help")
            
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
    }
    
    // MARK: - Version Footer
    
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Version \(viewModel.appVersion) (\(viewModel.buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Powered by Apple Intelligence & Local LLMs")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
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
        subtitle: String? = nil,
        showChevron: Bool = false,
        showExternalLink: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                settingsIcon(icon, color: iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
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
