//
//  KnowledgeBaseView.swift
//  letstalkAI
//
//  Document management view
//

import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeBaseView: View {
    @StateObject var viewModel: KnowledgeBaseViewModel
    let session: ChatSession?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDocumentPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.documents.isEmpty && !viewModel.isProcessing {
                emptyState
            } else {
                documentsList
            }
        }
        .navigationTitle("Knowledge Base")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDocumentPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.isProcessing)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                Task {
                    await viewModel.addDocument(url: url)
                }
            }
        }
        .onAppear {
            if let session = session {
                viewModel.setSession(session)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Documents")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Upload PDF documents to enhance the AI's knowledge for this conversation.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showDocumentPicker = true
            } label: {
                Label("Upload Document", systemImage: "arrow.up.doc")
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentsList: some View {
        List {
            if viewModel.isProcessing {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processing...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(viewModel.processingFileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section("Uploaded Documents") {
                ForEach(viewModel.documents) { document in
                    documentRow(document)
                }
            }
        }
    }
    
    private func documentRow(_ document: Document) -> some View {
        HStack(spacing: 12) {
            Image(systemName: documentIcon(for: document.type))
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.body)
                    .lineLimit(2)
                
                Text(documentDateFormatter.string(from: document.uploadedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func documentIcon(for type: DocumentType) -> String {
        switch type {
        case .pdf:
            return "doc.fill"
        case .text:
            return "doc.text.fill"
        case .unknown:
            return "doc.questionmark.fill"
        }
    }
    
    private var documentDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}
