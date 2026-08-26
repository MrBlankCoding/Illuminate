//
//  PasswordServiceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Testing
import Foundation
import SwiftData
@testable import Illuminate

@MainActor
struct PasswordServiceTests {

    private func createInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Password.self, Bookmark.self,
            configurations: config
        )
    }

    @Test func testSaveAndFetchPassword() async throws {
        let container = try createInMemoryContainer()
        let service = PasswordService(profile: BrowserProfile(name: "Test Profile"), container: container)
        service.savePassword(
            url: "https://example.com",
            username: "testuser",
            passwordData: "encrypted-password-data"
        )
        
        let passwords = service.fetchPasswords(for: "https://example.com")
        
        #expect(passwords.count == 1, "Should have one password saved")
        #expect(passwords.first?.username == "testuser", "Username should match")
        #expect(passwords.first?.passwordData == "encrypted-password-data", "Password data should match")
    }

    @Test func testPasswordUpdate() async throws {
        let container = try createInMemoryContainer()
        let service = PasswordService(profile: BrowserProfile(name: "Test Profile"), container: container)
        
        service.savePassword(
            url: "https://updatesite.com",
            username: "user1",
            passwordData: "old-password"
        )
        
        service.savePassword(
            url: "https://updatesite.com",
            username: "user1",
            passwordData: "new-password"
        )
        
        let passwords = service.fetchPasswords(for: "https://updatesite.com")
        
        #expect(passwords.count == 1, "Should still have only one password (updated)")
        #expect(passwords.first?.passwordData == "new-password", "Password should be updated")
    }

    @Test func testMultiplePasswordsForSameSite() async throws {
        let container = try createInMemoryContainer()
        let service = PasswordService(profile: BrowserProfile(name: "Test Profile"), container: container)
        
        service.savePassword(
            url: "https://multilogin.com",
            username: "user1",
            passwordData: "pass1"
        )
        service.savePassword(
            url: "https://multilogin.com",
            username: "user2",
            passwordData: "pass2"
        )
        service.savePassword(
            url: "https://multilogin.com",
            username: "user3",
            passwordData: "pass3"
        )
        
        let passwords = service.fetchPasswords(for: "https://multilogin.com")
        
        #expect(passwords.count == 3, "Should have three passwords for different usernames")
        
        let usernames = passwords.map(\.username)
        #expect(usernames.contains("user1"), "Should contain user1")
        #expect(usernames.contains("user2"), "Should contain user2")
        #expect(usernames.contains("user3"), "Should contain user3")
    }

    @Test func testHostExtraction() async throws {
        let container = try createInMemoryContainer()
        let service = PasswordService(profile: BrowserProfile(name: "Test Profile"), container: container)
        
        service.savePassword(
            url: "https://login.example.com/signin",
            username: "testuser",
            passwordData: "testpass"
        )
        
        let passwords = service.fetchPasswords(for: "login.example.com")
        
        #expect(passwords.count == 1, "Should find password by host")
        #expect(passwords.first?.url == "login.example.com", "URL should be stored as host only")
    }

    @Test func guestModeDoesNotPersistPasswords() async throws {
        let container = try createInMemoryContainer()
        let service = PasswordService(profileID: nil, container: container)

        service.savePassword(
            url: "https://guest.example",
            username: "guest",
            passwordData: "temporary"
        )

        #expect(service.fetchPasswords(for: "https://guest.example").isEmpty)

        let descriptor = FetchDescriptor<Password>()
        let storedPasswords = try container.mainContext.fetch(descriptor)
        #expect(storedPasswords.isEmpty)
    }
}
