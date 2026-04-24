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
            
            VStack(spacing: 0) {
                skipButton
                
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
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
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
