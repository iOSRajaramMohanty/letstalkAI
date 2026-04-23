//
//  VoiceConversationView.swift
//  letstalkAI
//
//  Full-screen voice conversation interface - Cross-platform (iOS/macOS)
//

import SwiftUI

struct VoiceConversationView: View {
    @StateObject var viewModel: VoiceConversationViewModel
    let session: ChatSession?
    
    @Environment(\.dismiss) private var dismiss
    @State private var hasPermission = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    visualizer
                    
                    transcriptView
                    
                    Spacer()
                    
                    controlButton
                    
                    statusText
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding()
                
                closeButton
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
        .onAppear {
            if let session = session {
                viewModel.setSession(session)
            }
            
            Task {
                hasPermission = await viewModel.requestPermissions()
            }
        }
        .onDisappear {
            viewModel.exitContinuousMode()
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: viewModel.conversationState)
    }
    
    private var gradientColors: [Color] {
        switch viewModel.conversationState {
        case .idle:
            return [backgroundColor, secondaryBackgroundColor]
        case .listening:
            return [.blue.opacity(0.3), .purple.opacity(0.3)]
        case .processing:
            return [.orange.opacity(0.3), .yellow.opacity(0.3)]
        case .speaking:
            return [.green.opacity(0.3), .cyan.opacity(0.3)]
        }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var secondaryBackgroundColor: Color {
        #if os(iOS)
        Color(.systemGray6)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    private var visualizer: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(lineWidth: 2)
                    .foregroundStyle(visualizerColor.opacity(0.3 - Double(index) * 0.1))
                    .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                    .scaleEffect(viewModel.isListening || viewModel.isSpeaking ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: viewModel.isListening || viewModel.isSpeaking
                    )
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [visualizerColor.opacity(0.8), visualizerColor.opacity(0.4)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .overlay {
                    Image(systemName: stateIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
        }
    }
    
    private var visualizerColor: Color {
        switch viewModel.conversationState {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .speaking:
            return .green
        }
    }
    
    private var stateIcon: String {
        switch viewModel.conversationState {
        case .idle:
            return "mic.fill"
        case .listening:
            return "waveform"
        case .processing:
            return "brain.fill"
        case .speaking:
            return "speaker.wave.2.fill"
        }
    }
    
    private var transcriptView: some View {
        VStack(spacing: 16) {
            if !viewModel.recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You said:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.recognizedText)
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
            
            if !viewModel.aiResponse.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Response:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.aiResponse)
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .frame(maxHeight: 300)
    }
    
    private var controlButton: some View {
        Button {
            handleControlTap()
        } label: {
            Circle()
                .fill(controlButtonColor)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: controlButtonIcon)
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                .shadow(color: controlButtonColor.opacity(0.5), radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!hasPermission)
    }
    
    private var controlButtonColor: Color {
        switch viewModel.conversationState {
        case .idle:
            return .blue
        case .listening:
            return .red
        case .processing:
            return .orange
        case .speaking:
            return .green
        }
    }
    
    private var controlButtonIcon: String {
        switch viewModel.conversationState {
        case .idle:
            return "mic.fill"
        case .listening:
            return "stop.fill"
        case .processing:
            return "hourglass"
        case .speaking:
            return "stop.fill"
        }
    }
    
    private var statusText: some View {
        Text(statusMessage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    
    private var statusMessage: String {
        if !hasPermission {
            return "Microphone permission required"
        }
        
        switch viewModel.conversationState {
        case .idle:
            return "Tap to start speaking"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing your request..."
        case .speaking:
            return "Speaking response..."
        }
    }
    
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding()
            }
            
            Spacer()
        }
    }
    
    private func handleControlTap() {
        switch viewModel.conversationState {
        case .idle:
            Task {
                await viewModel.startListening()
            }
        case .listening:
            viewModel.stopListening()
        case .processing:
            break
        case .speaking:
            viewModel.stopSpeaking()
        }
    }
}
