//
//  DependencyContainer.swift
//  letstalkAI
//
//  Dependency Injection container for Clean Architecture
//

import Foundation

@MainActor
final class DependencyContainer: Sendable {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Data Sources
    
    private(set) lazy var databaseManager: DatabaseManager = {
        DatabaseManager()
    }()
    
    private(set) lazy var vectorDatabaseManager: VectorDatabaseManager = {
        VectorDatabaseManager()
    }()
    
    private(set) lazy var webScrapingService: WebScrapingService = {
        WebScrapingService()
    }()
    
    private(set) lazy var fileStorageManager: FileStorageManager = {
        FileStorageManager()
    }()
    
    // MARK: - Mappers
    
    private(set) lazy var sessionMapper: ChatSessionMapper = {
        ChatSessionMapper()
    }()
    
    private(set) lazy var messageMapper: ChatMessageMapper = {
        ChatMessageMapper()
    }()
    
    private(set) lazy var documentMapper: DocumentMapper = {
        DocumentMapper()
    }()
    
    // MARK: - Repositories
    
    private(set) lazy var chatRepository: ChatRepositoryProtocol = {
        ChatRepository(databaseManager: databaseManager, messageMapper: messageMapper)
    }()
    
    private(set) lazy var sessionRepository: SessionRepositoryProtocol = {
        SessionRepository(databaseManager: databaseManager, sessionMapper: sessionMapper)
    }()
    
    private(set) lazy var ragRepository: RAGRepositoryProtocol = {
        RAGRepository(vectorDatabaseManager: vectorDatabaseManager)
    }()
    
    private(set) lazy var llmRepository: LLMRepositoryProtocol = {
        LLMRepository()
    }()
    
    private(set) lazy var webSearchRepository: WebSearchRepositoryProtocol = {
        WebSearchRepository(webScrapingService: webScrapingService)
    }()
    
    private(set) lazy var documentRepository: DocumentRepositoryProtocol = {
        DocumentRepository(
            databaseManager: databaseManager,
            fileStorageManager: fileStorageManager,
            documentMapper: documentMapper
        )
    }()
    
    private(set) lazy var speechRepository: SpeechRepositoryProtocol = {
        SpeechRepository()
    }()
    
    // MARK: - Use Cases
    
    nonisolated func makeSendMessageUseCase() -> SendMessageUseCaseProtocol {
        SendMessageUseCase(
            chatRepository: MainActor.assumeIsolated { Self.shared.chatRepository },
            llmRepository: MainActor.assumeIsolated { Self.shared.llmRepository },
            ragRepository: MainActor.assumeIsolated { Self.shared.ragRepository },
            webSearchRepository: MainActor.assumeIsolated { Self.shared.webSearchRepository },
            documentRepository: MainActor.assumeIsolated { Self.shared.documentRepository }
        )
    }
    
    nonisolated func makeGetChatHistoryUseCase() -> GetChatHistoryUseCaseProtocol {
        GetChatHistoryUseCase(chatRepository: MainActor.assumeIsolated { Self.shared.chatRepository })
    }
    
    nonisolated func makeGenerateTitleUseCase() -> GenerateTitleUseCaseProtocol {
        GenerateTitleUseCase(llmRepository: MainActor.assumeIsolated { Self.shared.llmRepository })
    }
    
    nonisolated func makeCreateSessionUseCase() -> CreateSessionUseCaseProtocol {
        CreateSessionUseCase(sessionRepository: MainActor.assumeIsolated { Self.shared.sessionRepository })
    }
    
    nonisolated func makeDeleteSessionUseCase() -> DeleteSessionUseCaseProtocol {
        DeleteSessionUseCase(sessionRepository: MainActor.assumeIsolated { Self.shared.sessionRepository })
    }
    
    nonisolated func makeGetSessionsUseCase() -> GetSessionsUseCaseProtocol {
        GetSessionsUseCase(sessionRepository: MainActor.assumeIsolated { Self.shared.sessionRepository })
    }
    
    nonisolated func makeQueryRAGUseCase() -> QueryRAGUseCaseProtocol {
        QueryRAGUseCase(ragRepository: MainActor.assumeIsolated { Self.shared.ragRepository })
    }
    
    nonisolated func makeAddDocumentUseCase() -> AddDocumentUseCaseProtocol {
        AddDocumentUseCase(
            documentRepository: MainActor.assumeIsolated { Self.shared.documentRepository },
            ragRepository: MainActor.assumeIsolated { Self.shared.ragRepository }
        )
    }
    
    nonisolated func makeWebSearchUseCase() -> WebSearchUseCaseProtocol {
        WebSearchUseCase(webSearchRepository: MainActor.assumeIsolated { Self.shared.webSearchRepository })
    }
    
    nonisolated func makeTranscribeSpeechUseCase() -> TranscribeSpeechUseCaseProtocol {
        TranscribeSpeechUseCase(speechRepository: MainActor.assumeIsolated { Self.shared.speechRepository })
    }
    
    nonisolated func makeSpeakTextUseCase() -> SpeakTextUseCaseProtocol {
        SpeakTextUseCase(speechRepository: MainActor.assumeIsolated { Self.shared.speechRepository })
    }
    
    // MARK: - ViewModels
    
    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            sendMessageUseCase: makeSendMessageUseCase(),
            getChatHistoryUseCase: makeGetChatHistoryUseCase(),
            generateTitleUseCase: makeGenerateTitleUseCase(),
            speakTextUseCase: makeSpeakTextUseCase()
        )
    }
    
    func makeSessionListViewModel() -> SessionListViewModel {
        SessionListViewModel(
            getSessionsUseCase: makeGetSessionsUseCase(),
            createSessionUseCase: makeCreateSessionUseCase(),
            deleteSessionUseCase: makeDeleteSessionUseCase()
        )
    }
    
    func makeVoiceConversationViewModel() -> VoiceConversationViewModel {
        VoiceConversationViewModel(
            sendMessageUseCase: makeSendMessageUseCase(),
            transcribeSpeechUseCase: makeTranscribeSpeechUseCase(),
            speakTextUseCase: makeSpeakTextUseCase()
        )
    }
    
    func makeKnowledgeBaseViewModel() -> KnowledgeBaseViewModel {
        KnowledgeBaseViewModel(addDocumentUseCase: makeAddDocumentUseCase())
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel()
    }
    
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel()
    }
}
