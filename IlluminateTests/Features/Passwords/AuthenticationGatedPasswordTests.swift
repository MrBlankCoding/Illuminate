//
//  AuthenticationGatedPasswordTests.swift
//  IlluminateTests
//
//  Created by Trae on 8/29/26.
//

import Testing
import Foundation
import SwiftData
@testable import Illuminate

// TODO
// real implementation for testing?
final class MockAuthenticationService: AuthenticationServiceProtocol {
    var shouldSucceed = true
    var authCount = 0
    var lastReason: String?

    func authenticate(reason: String) async throws -> Bool {
        authCount += 1
        lastReason = reason
        if shouldSucceed {
            return true
        } else {
            throw AuthenticationError.failed
        }
    }
}

@MainActor
struct AuthenticationGatedPasswordTests {

    private func createInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Password.self, configurations: config)
    }

    @Test func testFetchRequiresAuthentication() async throws {
        let container = try createInMemoryContainer()
        let mockAuth = MockAuthenticationService()
        let service = PasswordService(profile: BrowserProfile(name: "Test"), container: container, authService: mockAuth)
        
        service.savePassword(url: "example.com", username: "user", passwordData: "pass")
        let initialFetch = service.fetchPasswords(for: "example.com")
        #expect(initialFetch.isEmpty, "Fetch should be empty when not authenticated")
        
        let success = await service.authenticate()
        #expect(success, "Authentication should succeed")
        #expect(mockAuth.authCount == 1)
        
        let gatedFetch = service.fetchPasswords(for: "example.com")
        #expect(gatedFetch.count == 1, "Fetch should return results after authentication")
        #expect(gatedFetch.first?.username == "user")
    }

    @Test func testFailedAuthentication() async throws {
        let container = try createInMemoryContainer()
        let mockAuth = MockAuthenticationService()
        mockAuth.shouldSucceed = false
        let service = PasswordService(profile: BrowserProfile(name: "Test"), container: container, authService: mockAuth)
        
        service.savePassword(url: "example.com", username: "user", passwordData: "pass")
        
        let success = await service.authenticate()
        #expect(!success, "Authentication should fail")
        
        let passwords = service.fetchPasswords(for: "example.com")
        #expect(passwords.isEmpty, "Fetch should be empty after failed authentication")
    }

    @Test func testAuthenticationTimeout() async throws {
        let container = try createInMemoryContainer()
        let mockAuth = MockAuthenticationService()
        let service = PasswordService(profile: BrowserProfile(name: "Test"), container: container, authService: mockAuth)
        
        service.savePassword(url: "example.com", username: "user", passwordData: "pass")
        
        _ = await service.authenticate()
        #expect(mockAuth.authCount == 1)
    
        _ = service.fetchPasswords(for: "example.com")
        #expect(mockAuth.authCount == 1)
        
        service.lock()
        
        #expect(service.fetchPasswords(for: "example.com").isEmpty)
        
        _ = await service.authenticate()
        #expect(mockAuth.authCount == 2)
    }

    @Test func testHasPasswordsDoesNotRequireAuth() async throws {
        let container = try createInMemoryContainer()
        let mockAuth = MockAuthenticationService()
        let service = PasswordService(profile: BrowserProfile(name: "Test"), container: container, authService: mockAuth)
        
        service.savePassword(url: "example.com", username: "user", passwordData: "pass")
        
        // hasPasswords should return true even if not authenticated
        #expect(service.hasPasswords(for: "example.com") == true)
        #expect(mockAuth.authCount == 0, "hasPasswords should not trigger authentication")
    }
}
