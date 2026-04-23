//
//  SessionRepositoryProtocol.swift
//  letstalkAI
//
//  Domain Repository Protocol
//

import Foundation

protocol SessionRepositoryProtocol: Sendable {
    func createSession(_ session: ChatSession) async throws -> ChatSession
    func getAllSessions() async throws -> [ChatSession]
    func getSession(by id: String) async throws -> ChatSession?
    func updateSession(_ session: ChatSession) async throws
    func deleteSession(_ sessionId: String) async throws
    func deleteSessions(_ sessionIds: Set<String>) async throws
    func updateSessionTitle(_ sessionId: String, title: String) async throws -> Bool
    func updateSessionWebSearch(_ sessionId: String, useWebSearch: Bool) async throws
    func saveTranscript(_ transcriptJSON: String, sessionId: String) async throws
    func loadTranscript(for sessionId: String) async throws -> String?
}
