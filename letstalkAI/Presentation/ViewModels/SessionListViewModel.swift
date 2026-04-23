//
//  SessionListViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel
//

import Foundation
import SwiftUI

@MainActor
final class SessionListViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var selectedSession: ChatSession?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isEditMode: Bool = false
    @Published var selectedSessionIds: Set<String> = []
    
    private let getSessionsUseCase: GetSessionsUseCaseProtocol
    private let createSessionUseCase: CreateSessionUseCaseProtocol
    private let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    
    init(
        getSessionsUseCase: GetSessionsUseCaseProtocol,
        createSessionUseCase: CreateSessionUseCaseProtocol,
        deleteSessionUseCase: DeleteSessionUseCaseProtocol
    ) {
        self.getSessionsUseCase = getSessionsUseCase
        self.createSessionUseCase = createSessionUseCase
        self.deleteSessionUseCase = deleteSessionUseCase
    }
    
    func loadSessions() async {
        isLoading = true
        
        do {
            let allSessions = try await getSessionsUseCase.execute()
            
            var displayedSessions: [ChatSession] = []
            let chatRepository = DependencyContainer.shared.chatRepository
            
            for session in allSessions {
                let messages = try await chatRepository.getMessages(for: session.id)
                if !messages.isEmpty {
                    displayedSessions.append(session)
                }
            }
            
            sessions = displayedSessions
            
            if selectedSession == nil && !sessions.isEmpty {
                selectedSession = sessions.first
            }
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createNewSession() async -> ChatSession? {
        do {
            let allSessions = try await getSessionsUseCase.execute()
            let session = try await createSessionUseCase.getOrCreateEmptySession(existingSessions: allSessions)
            selectedSession = session
            await loadSessions()
            return session
        } catch {
            errorMessage = "Failed to create session: \(error.localizedDescription)"
            return nil
        }
    }
    
    func deleteSession(_ session: ChatSession) async {
        do {
            try await deleteSessionUseCase.execute(sessionId: session.id)
            sessions.removeAll { $0.id == session.id }
            
            if selectedSession?.id == session.id {
                selectedSession = sessions.first
            }
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
        }
    }
    
    func deleteSelectedSessions() async {
        guard !selectedSessionIds.isEmpty else { return }
        
        do {
            try await deleteSessionUseCase.executeMultiple(sessionIds: selectedSessionIds)
            sessions.removeAll { selectedSessionIds.contains($0.id) }
            
            if let selected = selectedSession, selectedSessionIds.contains(selected.id) {
                selectedSession = sessions.first
            }
            
            selectedSessionIds.removeAll()
            isEditMode = false
        } catch {
            errorMessage = "Failed to delete sessions: \(error.localizedDescription)"
        }
    }
    
    func updateSessionTitle(_ sessionId: String, title: String) async -> Bool {
        do {
            let success = try await getSessionsUseCase.updateSessionTitle(
                sessionId: sessionId,
                title: title,
                existingSessions: sessions
            )
            
            if success {
                if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                    sessions[index].title = title
                }
                if selectedSession?.id == sessionId {
                    selectedSession?.title = title
                }
            }
            
            return success
        } catch {
            errorMessage = "Failed to update title: \(error.localizedDescription)"
            return false
        }
    }
    
    func selectSession(_ session: ChatSession) {
        selectedSession = session
    }
    
    func toggleSelection(_ sessionId: String) {
        if selectedSessionIds.contains(sessionId) {
            selectedSessionIds.remove(sessionId)
        } else {
            selectedSessionIds.insert(sessionId)
        }
    }
    
    func selectAll() {
        selectedSessionIds = Set(sessions.map { $0.id })
    }
    
    func deselectAll() {
        selectedSessionIds.removeAll()
    }
    
    func toggleEditMode() {
        isEditMode.toggle()
        if !isEditMode {
            selectedSessionIds.removeAll()
        }
    }
}
