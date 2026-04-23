//
//  SettingsView.swift
//  letstalkAI
//
//  App settings view
//

import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                appInfoHeader
            }
            
            Section("Appearance") {
                colorSchemePicker
            }
            
            Section("Links") {
                linkRow(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right", url: viewModel.githubURL)
                linkRow(title: "Discord", icon: "message.fill", url: viewModel.discordURL)
                linkRow(title: "Privacy Policy", icon: "hand.raised.fill", url: viewModel.privacyURL)
                linkRow(title: "Terms of Service", icon: "doc.text.fill", url: viewModel.termsURL)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("letstalkAI")
                        .font(.headline)
                    
                    Text("Powered by Apple Foundation Models. All AI processing happens on your device for maximum privacy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .preferredColorScheme(viewModel.colorScheme)
    }
    
    private var appInfoHeader: some View {
        HStack(spacing: 16) {
            DynamicLogoView()
                .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("letstalkAI")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your Private AI Assistant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var colorSchemePicker: some View {
        Picker("Color Scheme", selection: Binding(
            get: { colorSchemeOption },
            set: { viewModel.setColorScheme($0.colorScheme) }
        )) {
            ForEach(ColorSchemeOption.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var colorSchemeOption: ColorSchemeOption {
        if let scheme = viewModel.colorScheme {
            return scheme == .light ? .light : .dark
        }
        return .system
    }
    
    private func linkRow(title: String, icon: String, url: String) -> some View {
        Button {
            viewModel.openURL(url)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
