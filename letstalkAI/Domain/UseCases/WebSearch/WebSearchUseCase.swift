//
//  WebSearchUseCase.swift
//  letstalkAI
//
//  Domain Use Case
//

import Foundation

protocol WebSearchUseCaseProtocol: Sendable {
    func execute(query: String) async throws -> [WebSearchResult]
}

final class WebSearchUseCase: WebSearchUseCaseProtocol, @unchecked Sendable {
    private let webSearchRepository: WebSearchRepositoryProtocol
    
    init(webSearchRepository: WebSearchRepositoryProtocol) {
        self.webSearchRepository = webSearchRepository
    }
    
    func execute(query: String) async throws -> [WebSearchResult] {
        try await webSearchRepository.searchAndScrape(query: query)
    }
}
