//
//  WebSearchRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol WebSearchRepositoryProtocol: Sendable {
    func searchAndScrape(query: String) async throws -> [WebSearchResult]
    func chunkText(_ text: String, maxLength: Int, overlapTokens: Int) -> [String]
}
