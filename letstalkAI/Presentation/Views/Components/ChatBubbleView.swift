//
//  ChatBubbleView.swift
//  letstalkAI
//
//  Chat message bubble component
//

import SwiftUI
import MarkdownUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let onSpeakTap: () -> Void
    let onSourceTap: (WebSearchResult) -> Void
    
    @State private var showSources = false
    @State private var isSpeaking = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                bubbleContent
                
                if !message.isUser {
                    actionButtons
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .sheet(isPresented: $showSources) {
            sourcesSheet
        }
    }
    
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isUser {
                Text(message.text)
                    .foregroundStyle(.white)
            } else {
                Markdown(message.text)
                    .markdownTheme(colorScheme == .dark ? .gitHub : .basic)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bubbleBackground)
        .textSelection(.enabled)
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            if !message.isUser {
                Button {
                    onSpeakTap()
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
            }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.isUser {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                isSpeaking.toggle()
                onSpeakTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 14))
                    Text("Listen")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(.systemGray6))
                )
            }
            
            if let sources = message.sources, !sources.isEmpty {
                Button {
                    showSources = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                        Text("Sources (\(sources.count))")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
    }
    
    private var sourcesSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let sources = message.sources {
                        ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                            SourceCardView(
                                index: index + 1,
                                source: source,
                                onTap: {
                                    showSources = false
                                    onSourceTap(source)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showSources = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SourceCardView: View {
    let index: Int
    let source: WebSearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                    
                    Text("\(index).")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Text(source.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(source.url)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                
                if !source.content.isEmpty {
                    Text(String(source.content.prefix(200)) + (source.content.count > 200 ? "..." : ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        ChatBubbleView(
            message: ChatMessage(text: "Hello, how can I help you today?", isUser: false),
            onSpeakTap: {},
            onSourceTap: { _ in }
        )
        
        ChatBubbleView(
            message: ChatMessage(text: "What's the weather like?", isUser: true),
            onSpeakTap: {},
            onSourceTap: { _ in }
        )
        
        ChatBubbleView(
            message: ChatMessage(
                text: "Based on web search results, here's what I found...",
                isUser: false,
                sources: [
                    WebSearchResult(title: "Weather.com", url: "https://weather.com", content: "Current weather conditions..."),
                    WebSearchResult(title: "AccuWeather", url: "https://accuweather.com", content: "Forecast for today...")
                ]
            ),
            onSpeakTap: {},
            onSourceTap: { _ in }
        )
    }
    .padding()
}
