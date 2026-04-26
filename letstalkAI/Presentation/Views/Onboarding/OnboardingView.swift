//
//  OnboardingView.swift
//  letstalkAI
//
//  Onboarding flow for new users - Cross-platform (iOS/macOS)
//

import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel
    
    init(viewModel: OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    init(isFromSettings: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(isFromSettings: isFromSettings, onComplete: onComplete))
    }
    
    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()
            
            if viewModel.showModelSelection && !viewModel.isFromSettings {
                ModelSelectionOnboardingView(viewModel: viewModel)
            } else {
                standardOnboardingView
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 600)
        #endif
    }
    
    private var standardOnboardingView: some View {
        VStack(spacing: 0) {
            if viewModel.isFromSettings {
                skipButton
            }
            
            if viewModel.currentStep == 0 && !viewModel.isFromSettings {
                WelcomeOnboardingView(viewModel: viewModel)
            } else {
                TabView(selection: $viewModel.currentStep) {
                    ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                        OnboardingStepView(step: step)
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                
                pageIndicator
                
                navigationButtons
            }
        }
    }
    
    private var backgroundView: some View {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var skipButton: some View {
        HStack {
            Spacer()
            
            Button(viewModel.isFromSettings ? "Close" : "Skip") {
                viewModel.skip()
            }
            .foregroundStyle(.secondary)
            .padding()
        }
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.steps.count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if viewModel.currentStep > 0 {
                Button {
                    viewModel.previousStep()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 60, height: 50)
                }
                .buttonStyle(.bordered)
            }
            
            Button {
                viewModel.nextStep()
            } label: {
                Text(viewModel.currentStep == viewModel.steps.count - 1 ? (viewModel.isFromSettings ? "Done" : "Get Started") : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

// MARK: - Welcome Onboarding View (First Screen)

struct WelcomeOnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("letstalkAI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }
            
            Spacer()
            
            VStack(spacing: 20) {
                featureRow(
                    icon: "sparkles",
                    title: "Offline AI Assistant",
                    description: "Your AI assistant that runs completely on your device. No login or internet needed."
                )
                
                featureRow(
                    icon: "lock.fill",
                    title: "Private and Secure",
                    description: "Your data stays on your device. No cloud processing, no data collection, just privacy."
                )
                
                featureRow(
                    icon: "cpu.fill",
                    title: "Optimized for Apple Silicon",
                    description: "Leverage powerful language and vision models optimized for Apple Silicon chips."
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button {
                viewModel.proceedToModelSelection()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Model Selection Onboarding View

struct ModelSelectionOnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @State private var selectedModelId: String?
    
    private let onboardingModels = ModelCatalog.onboardingModels
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            downloadIcon
            
            VStack(spacing: 8) {
                Text("Choose a Model")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select your first model to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                ForEach(onboardingModels) { model in
                    modelSelectionCard(model)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Text("Please keep the app open during download.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            downloadButton
            
            Button("Skip") {
                viewModel.skipModelSelection()
            }
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.bottom, 40)
        }
    }
    
    private var downloadIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                .frame(width: 80, height: 80)
            
            Image(systemName: "arrow.down")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
    
    private func modelSelectionCard(_ model: LocalLLMModel) -> some View {
        let isSelected = selectedModelId == model.id
        let isDownloading = downloadManager.downloadState(for: model.id) == .downloading(progress: 0)
        
        return Button {
            if !isDownloading {
                selectedModelId = model.id
            }
        } label: {
            HStack(spacing: 12) {
                providerIcon(model.provider)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(shortDescription(for: model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var downloadButton: some View {
        Group {
            if let modelId = selectedModelId,
               let model = ModelCatalog.model(withId: modelId) {
                
                let state = downloadManager.downloadState(for: modelId)
                
                switch state {
                case .downloading(let progress):
                    ProgressView(value: progress) {
                        Text("Downloading... \(Int(progress * 100))%")
                            .font(.subheadline)
                    }
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 24)
                    .frame(height: 56)
                    
                case .downloaded:
                    Button {
                        downloadManager.selectModel(modelId)
                        viewModel.completeOnboarding()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    
                default:
                    Button {
                        Task {
                            await downloadManager.downloadModel(model)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download (\(model.sizeFormatted))")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                Button { } label: {
                    Text("Select a model")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
                .disabled(true)
                .padding(.horizontal, 24)
            }
        }
    }
    
    private func providerIcon(_ provider: String) -> some View {
        Group {
            if provider == "Google" {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .red, .yellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if provider == "Liquid AI" {
                Image(systemName: "drop.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
            } else if provider == "Qwen" {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(.purple)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func shortDescription(for model: LocalLLMModel) -> String {
        switch model.provider {
        case "Liquid AI":
            return "Vision-language model from Liquid AI. Reliable for chat and vision."
        case "Google":
            return "Fast model from Google. Efficient memory use for everyday chat."
        case "Qwen":
            return "Small Qwen 3.5 model from Qwen. Fast and lightweight."
        default:
            return model.platformDescription
        }
    }
}

struct OnboardingStepView: View {
    let step: OnboardingStep
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.2))
                    .frame(width: 160, height: 160)
                
                Image(systemName: step.iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(step.color)
            }
            
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
}
