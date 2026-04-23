//
//  MainView.swift
//  letstalkAI
//
//  Main container view combining chat and sidebar
//

import SwiftUI

struct MainView: View {
    @StateObject var chatViewModel: ChatViewModel
    @StateObject var sessionListViewModel: SessionListViewModel
    
    @State private var showSidebar = false
    @State private var sidebarOffset: CGFloat = 0
    @State private var showKnowledgeBase = false
    @State private var showVoiceConversation = false
    @State private var showSettings = false
    @State private var showWebBrowser = false
    @State private var webBrowserURL: URL?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private let sidebarWidth: CGFloat = 280
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ChatView(
                    viewModel: chatViewModel,
                    showSidebar: $showSidebar,
                    showKnowledgeBase: $showKnowledgeBase,
                    showVoiceConversation: $showVoiceConversation,
                    showWebBrowser: $showWebBrowser,
                    webBrowserURL: $webBrowserURL
                )
                .offset(x: showSidebar ? sidebarWidth : 0)
                
                if showSidebar {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .offset(x: showSidebar ? sidebarWidth : 0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSidebar = false
                            }
                        }
                }
                
                ChatSidebar(
                    viewModel: sessionListViewModel,
                    showSettings: $showSettings,
                    isVisible: $showSidebar,
                    onSessionSelect: { session in
                        Task {
                            await chatViewModel.loadSession(session)
                            withAnimation {
                                showSidebar = false
                            }
                        }
                    }
                )
                .frame(width: sidebarWidth)
                .offset(x: showSidebar ? 0 : -sidebarWidth)
            }
            .gesture(sidebarDragGesture)
        }
        .sheet(isPresented: $showKnowledgeBase) {
            NavigationStack {
                KnowledgeBaseView(
                    viewModel: DependencyContainer.shared.makeKnowledgeBaseViewModel(),
                    session: chatViewModel.currentSession
                )
            }
        }
        .fullScreenCover(isPresented: $showVoiceConversation) {
            VoiceConversationView(
                viewModel: DependencyContainer.shared.makeVoiceConversationViewModel(),
                session: chatViewModel.currentSession
            )
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(viewModel: DependencyContainer.shared.makeSettingsViewModel())
            }
        }
        .sheet(isPresented: $showWebBrowser) {
            if let url = webBrowserURL {
                WebBrowserView(url: url)
            }
        }
        .task {
            await sessionListViewModel.loadSessions()
            
            var sessionToLoad: ChatSession? = sessionListViewModel.selectedSession
            if sessionToLoad == nil {
                sessionToLoad = await sessionListViewModel.createNewSession()
            }
            
            if let session = sessionToLoad {
                await chatViewModel.loadSession(session)
            }
        }
    }
    
    private var sidebarDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let translation = value.translation.width
                
                if showSidebar {
                    sidebarOffset = min(0, max(-sidebarWidth, translation))
                } else {
                    if translation > 0 {
                        sidebarOffset = min(sidebarWidth, translation)
                    }
                }
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let shouldOpen = velocity > 100 || sidebarOffset > sidebarWidth / 2
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSidebar = shouldOpen
                    sidebarOffset = 0
                }
            }
    }
}
