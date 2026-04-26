//
//  PersonalizationView.swift
//  letstalkAI
//
//  Personalization settings - Custom instructions and temperature
//

import SwiftUI

struct PersonalizationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @State private var customInstructions: String = ""
    @State private var enableCustomization: Bool = false
    @State private var selectedTemperature: TemperatureSetting = .default
    @State private var hasChanges: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    customizationToggle
                    
                    customInstructionsSection
                    
                    temperatureSection
                }
                .padding()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Personalization")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
            .frame(minWidth: 450, minHeight: 500)
            #endif
            .onAppear {
                loadCurrentSettings()
            }
            .onChange(of: customInstructions) { _, _ in
                hasChanges = true
            }
            .onChange(of: enableCustomization) { _, _ in
                hasChanges = true
            }
            .onChange(of: selectedTemperature) { _, _ in
                hasChanges = true
            }
        }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    // MARK: - Customization Toggle
    
    private var customizationToggle: some View {
        HStack {
            Text("Enable customization")
                .font(.body)
            
            Spacer()
            
            Toggle("", isOn: $enableCustomization)
                .labelsHidden()
                .tint(.green)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Custom Instructions Section
    
    private var customInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Instructions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            
            VStack(alignment: .trailing, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $customInstructions)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .disabled(!enableCustomization)
                        .opacity(enableCustomization ? 1 : 0.5)
                    
                    if customInstructions.isEmpty {
                        Text("Customize how the AI responds")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text("\(customInstructions.count)/1,000")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
        }
    }
    
    // MARK: - Temperature Section
    
    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Temperature")
                    .font(.body)
                
                Spacer()
                
                Menu {
                    ForEach(TemperatureSetting.allCases) { temp in
                        Button {
                            selectedTemperature = temp
                        } label: {
                            HStack {
                                Text(temp.rawValue)
                                if selectedTemperature == temp {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedTemperature.rawValue)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(!enableCustomization)
                .opacity(enableCustomization ? 1 : 0.5)
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Text("Controls randomness in responses. Lower values make the AI more focused and deterministic, while higher values make it more creative and unpredictable.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentSettings() {
        customInstructions = preferencesManager.preferences.customInstructions
        enableCustomization = preferencesManager.preferences.enableCustomization
        selectedTemperature = preferencesManager.preferences.temperature
        hasChanges = false
    }
    
    private func saveChanges() {
        preferencesManager.toggleCustomization(enableCustomization)
        preferencesManager.updateCustomInstructions(customInstructions)
        preferencesManager.updateTemperature(selectedTemperature)
    }
}

#Preview {
    PersonalizationView()
}
