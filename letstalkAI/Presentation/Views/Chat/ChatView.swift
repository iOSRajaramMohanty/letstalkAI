//
//  ChatView.swift
//  letstalkAI
//
//  Main chat interface view
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showSidebar: Bool
    @Binding var showKnowledgeBase: Bool
    @Binding var showVoiceConversation: Bool
    @Binding var showWebBrowser: Bool
    @Binding var webBrowserURL: URL?
    
    @State private var messageText = ""
    @State private var isMessageFieldFocused = false
    @FocusState private var textFieldFocus: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                
                inputBar
            }
            .navigationTitle(viewModel.currentSession?.displayTitle ?? "letstalkAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSidebar.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .imageScale(.large)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        webSearchToggle
                        
                        Button {
                            showKnowledgeBase = true
                        } label: {
                            Image(systemName: "doc.badge.plus")
                                .imageScale(.large)
                        }
                    }
                }
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
                                    webBrowserURL = url
                                    showWebBrowser = true
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
            .scrollDismissesKeyboard(.interactively)
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
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .focused($textFieldFocus)
                
                HStack(spacing: 8) {
                    Button {
                        showVoiceConversation = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color(.systemGray6)))
                    }
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty || viewModel.isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    private var webSearchToggle: some View {
        Button {
            Task {
                await viewModel.toggleWebSearch()
            }
        } label: {
            Image(systemName: viewModel.currentSession?.useWebSearch == true ? "globe.badge.chevron.backward" : "globe")
                .imageScale(.large)
                .foregroundStyle(viewModel.currentSession?.useWebSearch == true ? .blue : .primary)
        }
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
