//
//  WebSearchRepository.swift
//  letstalkAI
//
//  Data Layer Repository Implementation
//

import Foundation

final class WebSearchRepository: WebSearchRepositoryProtocol, @unchecked Sendable {
    private let webScrapingService: WebScrapingService
    
    init(webScrapingService: WebScrapingService) {
        self.webScrapingService = webScrapingService
    }
    
    func searchAndScrape(query: String) async throws -> [WebSearchResult] {
        try await webScrapingService.searchAndScrape(query: query)
    }
    
    func chunkText(_ text: String, maxLength: Int, overlapTokens: Int) -> [String] {
        webScrapingService.chunkText(text, maxLength: maxLength, overlapTokens: overlapTokens)
    }
}
