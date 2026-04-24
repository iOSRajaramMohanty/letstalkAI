//
//  KnowledgeBaseViewModel.swift
//  letstalkAI
//
//  Presentation Layer ViewModel for Document Management
//

import Foundation
import SwiftUI

@MainActor
final class KnowledgeBaseViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var isLoading: Bool = false
    @Published var isProcessing: Bool = false
    @Published var processingFileName: String = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let addDocumentUseCase: AddDocumentUseCaseProtocol
    
    private var session: ChatSession?
    
    init(addDocumentUseCase: AddDocumentUseCaseProtocol) {
        self.addDocumentUseCase = addDocumentUseCase
    }
    
    func setSession(_ session: ChatSession) {
        self.session = session
        Task {
            await loadDocuments()
        }
    }
    
    func loadDocuments() async {
        guard let session = session else { return }
        
        isLoading = true
        
        do {
            documents = try await addDocumentUseCase.getDocuments(for: session.id)
        } catch {
            errorMessage = "Failed to load documents: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addDocument(url: URL) async {
        guard let session = session else {
            print("❌ [KnowledgeBase] No session available")
            return
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📥 [KnowledgeBase] Starting document upload...")
        print("   Session: \(session.id)")
        print("   File: \(url.lastPathComponent)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        isProcessing = true
        processingFileName = url.lastPathComponent
        errorMessage = nil
        successMessage = nil
        
        do {
            let success = try await addDocumentUseCase.execute(url: url, session: session)
            
            if success {
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("✅ [KnowledgeBase] Document upload successful!")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                successMessage = "Document added successfully"
                await loadDocuments()
            }
        } catch {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("❌ [KnowledgeBase] Document upload failed!")
            print("   Error: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
        processingFileName = ""
    }
    
    func deleteDocument(_ document: Document) async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🗑️ [KnowledgeBase] Deleting document...")
        print("   Document: \(document.name)")
        print("   ID: \(document.id)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        errorMessage = nil
        successMessage = nil
        
        do {
            try await addDocumentUseCase.deleteDocument(document.id)
            
            print("✅ [KnowledgeBase] Document deleted successfully")
            successMessage = "Document deleted"
            
            withAnimation {
                documents.removeAll { $0.id == document.id }
            }
        } catch {
            print("❌ [KnowledgeBase] Delete failed: \(error.localizedDescription)")
            errorMessage = "Failed to delete document: \(error.localizedDescription)"
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
