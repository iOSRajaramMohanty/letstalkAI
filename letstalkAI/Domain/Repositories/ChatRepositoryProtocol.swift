//
//  ChatRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol ChatRepositoryProtocol: Sendable {
    func saveMessage(_ message: ChatMessage, sessionId: String) async throws
    func getMessages(for sessionId: String) async throws -> [ChatMessage]
    func deleteMessages(for sessionId: String) async throws
}
