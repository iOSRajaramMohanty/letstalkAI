//
//  ChatView.swift
//  letstalkAI
//
//  Main chat interface view - Cross-platform (iOS/macOS)
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showSidebar: Bool
    @Binding var showKnowledgeBase: Bool
    @Binding var showVoiceConversation: Bool
    @Binding var showWebBrowser: Bool
    @Binding var webBrowserURL: URL?
    @Binding var showSettings: Bool
    
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @State private var messageText = ""
    @State private var isMessageFieldFocused = false
    @State private var showModelSelector = false
    @State private var showModelManagement = false
    @FocusState private var textFieldFocus: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let suggestionChips = [
        "Organize my finances",
        "Boost my productivity",
        "Discover my next book",
        "Design a workout routine",
        "Start learning French",
        "Write professionally",
        "Explain a complex topic simply"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if downloadManager.downloadedModels.isEmpty {
                    noModelSelectedView
                } else if viewModel.messages.isEmpty {
                    emptyStateView
                } else {
                    messagesList
                }
                
                inputBar
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSidebar.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Circle().fill(Color.gray.opacity(0.15)))
                        }
                        
                        if let model = downloadManager.selectedModel {
                            modelSelectorButton(model)
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    webSearchToggle
                    
                    Button {
                        showVoiceConversation = true
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
                #elseif os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    if let model = downloadManager.selectedModel {
                        modelSelectorButton(model)
                    }
                    
                    webSearchToggle
                    
                    Button {
                        showKnowledgeBase = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .imageScale(.large)
                    }
                }
                #endif
            }
        }
        .onChange(of: viewModel.currentSession) { _, session in
            if let session = session {
                Task {
                    await viewModel.loadSession(session)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showModelManagement) {
            ModelManagementView()
        }
        .confirmationDialog("Select Model", isPresented: $showModelSelector) {
            ForEach(downloadManager.downloadedModels, id: \.modelId) { downloaded in
                if let model = ModelCatalog.model(withId: downloaded.modelId) {
                    Button(model.displayName) {
                        downloadManager.selectModel(model.id)
                    }
                }
            }
            
            Button("Manage models") {
                showModelManagement = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - No Model Selected View
    
    private var noModelSelectedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Model Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Download and select a model in Settings to start chatting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showModelManagement = true
            } label: {
                Text("Select a Model")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let model = downloadManager.selectedModel {
                VStack(spacing: 16) {
                    Text("Meet \(model.familyName)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Run \(model.provider)'s \(model.parameterCount) parameters model locally — built for fast on-device performance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            suggestionChipsView
        }
    }
    
    // MARK: - Suggestion Chips
    
    private var suggestionChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestionChips.shuffled().prefix(5), id: \.self) { suggestion in
                    Button {
                        messageText = suggestion
                        sendMessage()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.components(separatedBy: " ").first ?? "")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text(suggestion.components(separatedBy: " ").dropFirst().joined(separator: " "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Model Selector Button
    
    private func modelSelectorButton(_ model: LocalLLMModel) -> some View {
        Button {
            showModelSelector = true
        } label: {
            HStack(spacing: 4) {
                Text(model.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
        }
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(
                            message: message,
                            onSpeakTap: {
                                Task {
                                    await viewModel.speakMessage(message.text)
                                }
                            },
                            onSourceTap: { source in
                                if let url = URL(string: source.url) {
                                    #if os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #else
                                    webBrowserURL = url
                                    showWebBrowser = true
                                    #endif
                                }
                            }
                        )
                        .id(message.id)
                    }
                    
                    if viewModel.isLoading {
                        TypingIndicatorView(currentText: viewModel.currentResponse)
                            .id("typing")
                    }
                }
                .padding()
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.currentResponse) { _, _ in
                withAnimation {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                Menu {
                    Button {
                        showKnowledgeBase = true
                    } label: {
                        Label("Attach file", systemImage: "doc.fill")
                    }
                    
                    Button {
                        // Camera action - requires vision model
                    } label: {
                        Label("Take photo", systemImage: "camera.fill")
                    }
                    
                    Button {
                        // Photo library action - requires vision model
                    } label: {
                        Label("Attach photo", systemImage: "photo.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
                
                TextField("Ask anything", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(inputBackgroundColor)
                    )
                    .focused($textFieldFocus)
                    .onSubmit {
                        sendMessage()
                    }
                    #if os(macOS)
                    .onKeyPress(.return, action: {
                        sendMessage()
                        return .handled
                    })
                    #endif
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(messageText.isEmpty ? .gray.opacity(0.5) : .primary)
                }
                .buttonStyle(.plain)
                .disabled(messageText.isEmpty || viewModel.isLoading || downloadManager.downloadedModels.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    private var inputBackgroundColor: Color {
        #if os(iOS)
        Color(.systemGray6)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    private var webSearchToggle: some View {
        Button {
            Task {
                await viewModel.toggleWebSearch()
            }
        } label: {
            Image(systemName: viewModel.currentSession?.useWebSearch == true ? "globe.badge.chevron.backward" : "globe")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(viewModel.currentSession?.useWebSearch == true ? .blue : .secondary)
                .padding(8)
                .background(
                    Circle().fill(viewModel.currentSession?.useWebSearch == true ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        textFieldFocus = false
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
}
