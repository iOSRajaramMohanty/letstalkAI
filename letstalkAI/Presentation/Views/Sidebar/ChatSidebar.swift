//
//  ChatSidebar.swift
//  letstalkAI
//
//  Sidebar for session management
//

import SwiftUI

struct ChatSidebar: View {
    @ObservedObject var viewModel: SessionListViewModel
    @Binding var showSettings: Bool
    @Binding var isVisible: Bool
    
    let onSessionSelect: (ChatSession) -> Void
    
    @State private var editingSessionId: String?
    @State private var editingTitle: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            sessionsList
            
            Divider()
            
            footer
        }
        .background(Color(.systemBackground))
    }
    
    private var header: some View {
        HStack {
            Text("Chats")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            if viewModel.isEditMode {
                Button("Done") {
                    viewModel.toggleEditMode()
                }
            } else {
                Button {
                    Task {
                        if let session = await viewModel.createNewSession() {
                            onSessionSelect(session)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
    }
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.sessions) { session in
                    sessionRow(session)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func sessionRow(_ session: ChatSession) -> some View {
        HStack(spacing: 12) {
            if viewModel.isEditMode {
                Image(systemName: viewModel.selectedSessionIds.contains(session.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.selectedSessionIds.contains(session.id) ? .blue : .gray)
                    .onTapGesture {
                        viewModel.toggleSelection(session.id)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if editingSessionId == session.id {
                    TextField("Title", text: $editingTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task {
                                let _ = await viewModel.updateSessionTitle(session.id, title: editingTitle)
                                editingSessionId = nil
                            }
                        }
                } else {
                    Text(session.displayTitle)
                        .font(.body)
                        .lineLimit(2)
                    
                    Text(session.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if session.useWebSearch {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.selectedSession?.id == session.id ? Color.blue.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isEditMode {
                viewModel.toggleSelection(session.id)
            } else {
                onSessionSelect(session)
            }
        }
        .contextMenu {
            Button {
                editingSessionId = session.id
                editingTitle = session.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteSession(session)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteSession(session)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var footer: some View {
        VStack(spacing: 12) {
            if viewModel.isEditMode && !viewModel.selectedSessionIds.isEmpty {
                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteSelectedSessions()
                    }
                } label: {
                    Label("Delete Selected (\(viewModel.selectedSessionIds.count))", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            HStack {
                Button {
                    viewModel.toggleEditMode()
                } label: {
                    Image(systemName: "checklist")
                        .font(.title3)
                }
                
                Spacer()
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.title3)
                }
            }
        }
        .padding()
    }
}
