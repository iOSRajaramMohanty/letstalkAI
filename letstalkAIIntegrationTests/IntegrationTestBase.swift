//
//  IntegrationTestBase.swift
//  letstalkAIIntegrationTests
//
//  Base class for integration tests
//

import XCTest
@testable import letstalkAI

class IntegrationTestBase: XCTestCase {
    var databaseManager: DatabaseManager!
    
    override func setUp() {
        super.setUp()
        databaseManager = DatabaseManager(inMemory: true)
    }
    
    override func tearDown() {
        databaseManager = nil
        super.tearDown()
    }
}
