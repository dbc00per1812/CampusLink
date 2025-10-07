//
//  CriticalFlowsUITests.swift
//  CampusLinkUITests
//
//  Created on October 7, 2025.
//

import XCTest

final class CriticalFlowsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Authentication Flow Tests
    
    @MainActor
    func testLoginFlow() throws {
        // Check if we're on welcome screen
        let welcomeTitle = app.staticTexts["Buy & Sell with Your Campus Community"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5))
        
        // Tap Sign In button
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists)
        signInButton.tap()
        
        // Verify login screen appears
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        
        // Enter credentials
        emailField.tap()
        emailField.typeText("test@university.edu")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("TestPassword123!")
        
        // Tap login button
        let loginButton = app.buttons["Login"]
        loginButton.tap()
        
        // Verify successful login (should see main tab bar)
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
    }
    
    @MainActor
    func testSignUpFlow() throws {
        // Navigate to sign up
        let welcomeTitle = app.staticTexts["Buy & Sell with Your Campus Community"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5))
        
        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()
        
        // Fill sign up form
        let nameField = app.textFields["Full Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Test User")
        
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("newuser\(Int.random(in: 1000...9999))@university.edu")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("TestPassword123!")
        
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        confirmPasswordField.tap()
        confirmPasswordField.typeText("TestPassword123!")
        
        // Agree to terms and sign up
        let agreeSwitch = app.switches["I agree to the Terms of Service and Privacy Policy"]
        if !agreeSwitch.isSelected {
            agreeSwitch.tap()
        }
        
        let createAccountButton = app.buttons["Create Account"]
        createAccountButton.tap()
        
        // Verify email verification screen appears
        let verificationTitle = app.staticTexts["Verify Your Email"]
        XCTAssertTrue(verificationTitle.waitForExistence(timeout: 5))
    }
    
    // MARK: - Product Listing Flow Tests
    
    @MainActor
    func testCreateListingFlow() throws {
        // Assume user is logged in
        skipToMainApp()
        
        // Navigate to create listing
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        
        // Look for sell button
        let sellButton = app.buttons["Sell"]
        if sellButton.exists {
            sellButton.tap()
        } else {
            // Alternative: tap + button in navigation
            let addButton = app.navigationBars.buttons["Add"]
            if addButton.exists {
                addButton.tap()
            }
        }
        
        // Fill listing form
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Test iPhone 13")
        
        let descriptionTextView = app.textViews["Description"]
        descriptionTextView.tap()
        descriptionTextView.typeText("Great condition iPhone 13, no scratches")
        
        let priceField = app.textFields["Price"]
        priceField.tap()
        priceField.typeText("500")
        
        // Select category
        let categoryPicker = app.buttons["Select Category"]
        if categoryPicker.exists {
            categoryPicker.tap()
            let electronicsOption = app.buttons["Electronics"]
            electronicsOption.tap()
        }
        
        // Post listing
        let postButton = app.buttons["Post Listing"]
        postButton.tap()
        
        // Verify success
        let successMessage = app.staticTexts["Listing posted successfully"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testBrowseAndSearchFlow() throws {
        skipToMainApp()
        
        // Verify home screen loads
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        homeTab.tap()
        
        // Test search
        let searchField = app.searchFields["Search marketplace..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("textbook")
        
        // Wait for search results
        let firstResult = app.cells.firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5))
        
        // Tap on a result
        firstResult.tap()
        
        // Verify product detail view
        let priceLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$'")).firstMatch
        XCTAssertTrue(priceLabel.waitForExistence(timeout: 3))
        
        // Test back navigation
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tap()
        
        // Verify we're back to search results
        XCTAssertTrue(searchField.exists)
    }
    
    // MARK: - Purchase Flow Tests
    
    @MainActor
    func testPurchaseWithWalletFlow() throws {
        skipToMainApp()
        
        // Navigate to a product
        navigateToFirstProduct()
        
        // Tap buy button
        let buyButton = app.buttons["Buy Now"]
        XCTAssertTrue(buyButton.waitForExistence(timeout: 5))
        buyButton.tap()
        
        // Select wallet payment
        let walletOption = app.buttons["Campus Wallet"]
        if walletOption.waitForExistence(timeout: 3) {
            walletOption.tap()
        }
        
        // Confirm purchase
        let confirmButton = app.buttons["Confirm Purchase"]
        confirmButton.tap()
        
        // Enter password if required
        let passwordField = app.secureTextFields["Password"]
        if passwordField.waitForExistence(timeout: 2) {
            passwordField.tap()
            passwordField.typeText("TestPassword123!")
            app.buttons["Confirm"].tap()
        }
        
        // Verify success
        let successMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Success'")).firstMatch
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10))
    }
    
    // MARK: - Messaging Flow Tests
    
    @MainActor
    func testMessagingFlow() throws {
        skipToMainApp()
        
        // Navigate to messages tab
        let messagesTab = app.tabBars.buttons["Messages"]
        XCTAssertTrue(messagesTab.waitForExistence(timeout: 5))
        messagesTab.tap()
        
        // Check if there are any conversations
        let conversationCell = app.cells.firstMatch
        if conversationCell.waitForExistence(timeout: 3) {
            // Open existing conversation
            conversationCell.tap()
        } else {
            // Navigate to a product and message seller
            app.tabBars.buttons["Home"].tap()
            navigateToFirstProduct()
            
            let messageSellerButton = app.buttons["Message Seller"]
            if messageSellerButton.exists {
                messageSellerButton.tap()
            }
        }
        
        // Send a message
        let messageField = app.textFields["Type a message..."]
        XCTAssertTrue(messageField.waitForExistence(timeout: 5))
        messageField.tap()
        messageField.typeText("Hi, is this still available?")
        
        let sendButton = app.buttons["Send"]
        sendButton.tap()
        
        // Verify message appears
        let sentMessage = app.staticTexts["Hi, is this still available?"]
        XCTAssertTrue(sentMessage.waitForExistence(timeout: 3))
    }
    
    // MARK: - Profile and Settings Flow Tests
    
    @MainActor
    func testProfileUpdateFlow() throws {
        skipToMainApp()
        
        // Navigate to profile
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        
        // Tap edit profile
        let editButton = app.buttons["Edit Profile"]
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
            
            // Update name
            let nameField = app.textFields["Name"]
            nameField.tap()
            nameField.clearText()
            nameField.typeText("Updated Name")
            
            // Update bio
            let bioTextView = app.textViews["Bio"]
            if bioTextView.exists {
                bioTextView.tap()
                bioTextView.clearText()
                bioTextView.typeText("Updated bio for testing")
            }
            
            // Save changes
            let saveButton = app.buttons["Save"]
            saveButton.tap()
            
            // Verify changes saved
            let successMessage = app.staticTexts["Profile updated successfully"]
            XCTAssertTrue(successMessage.waitForExistence(timeout: 5))
        }
    }
    
    @MainActor
    func testNotificationSettingsFlow() throws {
        skipToMainApp()
        
        // Navigate to profile then settings
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        
        // Navigate to notifications
        let notificationsCell = app.cells["Notifications"]
        if notificationsCell.waitForExistence(timeout: 3) {
            notificationsCell.tap()
            
            // Toggle some settings
            let orderNotificationsSwitch = app.switches["Order Updates"]
            if orderNotificationsSwitch.exists {
                orderNotificationsSwitch.tap()
            }
            
            let messageNotificationsSwitch = app.switches["New Messages"]
            if messageNotificationsSwitch.exists {
                messageNotificationsSwitch.tap()
            }
            
            // Save settings
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func skipToMainApp() {
        // Helper to skip onboarding/login if needed
        let homeTab = app.tabBars.buttons["Home"]
        if !homeTab.exists {
            // Try to login with test credentials
            if app.buttons["Sign In"].exists {
                app.buttons["Sign In"].tap()
                
                let emailField = app.textFields["Email"]
                emailField.tap()
                emailField.typeText("test@university.edu")
                
                let passwordField = app.secureTextFields["Password"]
                passwordField.tap()
                passwordField.typeText("TestPassword123!")
                
                app.buttons["Login"].tap()
            }
        }
    }
    
    private func navigateToFirstProduct() {
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()
        
        // Wait for products to load and tap the first one
        let firstProductCell = app.cells.firstMatch
        XCTAssertTrue(firstProductCell.waitForExistence(timeout: 5))
        firstProductCell.tap()
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else { return }
        
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
