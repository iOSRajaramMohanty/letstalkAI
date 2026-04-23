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
        guard let session = session else { return }
        
        isProcessing = true
        processingFileName = url.lastPathComponent
        errorMessage = nil
        successMessage = nil
        
        do {
            let success = try await addDocumentUseCase.execute(url: url, session: session)
            
            if success {
                successMessage = "Document added successfully"
                await loadDocuments()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
        processingFileName = ""
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
