//
//  letstalkAIUITests.swift
//  letstalkAIUITests
//
//  UI tests for critical user flows
//

import XCTest

final class letstalkAIUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func testOnboardingFlow_CompletesSuccessfully() {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        
        let continueButton = app.buttons["Continue"]
        let getStartedButton = app.buttons["Get Started"]
        
        for _ in 0..<4 {
            if continueButton.waitForExistence(timeout: 2) {
                continueButton.tap()
            }
        }
        
        if getStartedButton.waitForExistence(timeout: 2) {
            getStartedButton.tap()
        }
        
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5))
    }
    
    func testChatFlow_SendMessageAndReceiveResponse() {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        
        let messageField = app.textFields["Message"]
        XCTAssertTrue(messageField.waitForExistence(timeout: 5))
        
        messageField.tap()
        messageField.typeText("Hello, AI!")
        
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 2))
        sendButton.tap()
        
        let userBubble = app.staticTexts["Hello, AI!"]
        XCTAssertTrue(userBubble.waitForExistence(timeout: 5))
    }
    
    func testSidebarFlow_OpenAndCloseSidebar() {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        
        let sidebarButton = app.buttons["sidebar.left"]
        XCTAssertTrue(sidebarButton.waitForExistence(timeout: 5))
        
        sidebarButton.tap()
        
        let chatsTitle = app.staticTexts["Chats"]
        XCTAssertTrue(chatsTitle.waitForExistence(timeout: 2))
        
        let overlay = app.otherElements["SidebarOverlay"]
        if overlay.exists {
            overlay.tap()
        }
    }
    
    func testKnowledgeBaseFlow_OpensKnowledgeBaseSheet() {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        
        let knowledgeBaseButton = app.buttons["doc.badge.plus"]
        XCTAssertTrue(knowledgeBaseButton.waitForExistence(timeout: 5))
        
        knowledgeBaseButton.tap()
        
        let knowledgeBaseTitle = app.staticTexts["Knowledge Base"]
        XCTAssertTrue(knowledgeBaseTitle.waitForExistence(timeout: 2))
    }
    
    func testVoiceConversationFlow_OpensVoiceInterface() {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        
        let micButton = app.buttons["mic.fill"]
        XCTAssertTrue(micButton.waitForExistence(timeout: 5))
        
        micButton.tap()
        
        let tapToStartText = app.staticTexts["Tap to start speaking"]
        XCTAssertTrue(tapToStartText.waitForExistence(timeout: 2))
    }
    
    func testSettingsFlow_OpensAndClosesSettings() {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        
        let sidebarButton = app.buttons["sidebar.left"]
        XCTAssertTrue(sidebarButton.waitForExistence(timeout: 5))
        sidebarButton.tap()
        
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()
        
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2))
        
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2))
        doneButton.tap()
    }
    
    func testWebSearchToggle_TogglesWebSearchMode() {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        
        let webSearchButton = app.buttons["globe"]
        XCTAssertTrue(webSearchButton.waitForExistence(timeout: 5))
        
        webSearchButton.tap()
        
        let activeWebSearch = app.buttons["globe.badge.chevron.backward"]
        XCTAssertTrue(activeWebSearch.waitForExistence(timeout: 2))
    }
}
