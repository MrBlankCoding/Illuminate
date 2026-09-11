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

    private final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
        var storage: [String: String] = [:]

        func key(_ account: String, _ service: String) -> String {
            "\(service)|\(account)"
        }

        func store(secret: String, for account: String, service: String) throws {
            storage[key(account, service)] = secret
        }

        func retrieve(for account: String, service: String) throws -> String? {
            storage[key(account, service)]
        }

        func delete(for account: String, service: String) throws {
            storage.removeValue(forKey: key(account, service))
        }
    }

    private struct SuccessfulAuthenticationService: AuthenticationServiceProtocol {
        func authenticate(reason: String) async throws -> Bool { true }
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Password.self, Bookmark.self,
            configurations: config
        )
    }

    @Test func testSaveAndFetchPassword() async throws {
        let container = try createInMemoryContainer()
        let keychain = MockKeychainService()
        let service = PasswordService(
            profile: BrowserProfile(name: "Test Profile"),
            container: container,
            authService: SuccessfulAuthenticationService(),
            keychainService: keychain
        )
        service.savePassword(
            url: "https://example.com",
            username: "testuser",
            passwordData: "encrypted-password-data"
        )
        
        let initialStored = try container.mainContext.fetch(FetchDescriptor<Password>()).first
        #expect(initialStored?.passwordData == "", "SwiftData store should not retain raw plaintext password")

        _ = await service.authenticate()
        let passwords = service.fetchPasswords(for: "https://example.com")
        
        #expect(passwords.count == 1, "Should have one password saved")
        #expect(passwords.first?.username == "testuser", "Username should match")
        #expect(passwords.first?.passwordData == "encrypted-password-data", "Password data should match")
        #expect(!keychain.storage.isEmpty, "Password data should be stored in keychain")
    }

    @Test func testPasswordUpdate() async throws {
        let container = try createInMemoryContainer()
        let keychain = MockKeychainService()
        let service = PasswordService(
            profile: BrowserProfile(name: "Test Profile"),
            container: container,
            authService: SuccessfulAuthenticationService(),
            keychainService: keychain
        )
        
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
        
        _ = await service.authenticate()
        let passwords = service.fetchPasswords(for: "https://updatesite.com")
        
        #expect(passwords.count == 1, "Should still have only one password (updated)")
        #expect(passwords.first?.passwordData == "new-password", "Password should be updated")
    }

    @Test func testMultiplePasswordsForSameSite() async throws {
        let container = try createInMemoryContainer()
        let keychain = MockKeychainService()
        let service = PasswordService(
            profile: BrowserProfile(name: "Test Profile"),
            container: container,
            authService: SuccessfulAuthenticationService(),
            keychainService: keychain
        )
        
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
        
        _ = await service.authenticate()
        let passwords = service.fetchPasswords(for: "https://multilogin.com")
        
        #expect(passwords.count == 3, "Should have three passwords for different usernames")
        
        let usernames = passwords.map { $0.username }
        #expect(usernames.contains("user1"), "Should contain user1")
        #expect(usernames.contains("user2"), "Should contain user2")
        #expect(usernames.contains("user3"), "Should contain user3")
    }

    @Test func testHostExtraction() async throws {
        let container = try createInMemoryContainer()
        let keychain = MockKeychainService()
        let service = PasswordService(
            profile: BrowserProfile(name: "Test Profile"),
            container: container,
            authService: SuccessfulAuthenticationService(),
            keychainService: keychain
        )
        
        service.savePassword(
            url: "https://login.example.com/signin",
            username: "testuser",
            passwordData: "testpass"
        )
        
        _ = await service.authenticate()
        let passwords = service.fetchPasswords(for: "login.example.com")
        
        #expect(passwords.count == 1, "Should find password by host")
        #expect(passwords.first?.url == "login.example.com", "URL should be stored as host only")
    }

    @Test func testDeletePasswordClearsKeychain() async throws {
        let container = try createInMemoryContainer()
        let keychain = MockKeychainService()
        let service = PasswordService(
            profile: BrowserProfile(name: "Test Profile"),
            container: container,
            authService: SuccessfulAuthenticationService(),
            keychainService: keychain
        )

        service.savePassword(
            url: "https://delete.example.com",
            username: "deleteuser",
            passwordData: "deletepass"
        )

        _ = await service.authenticate()
        guard let saved = service.fetchPasswords(for: "delete.example.com").first else {
            Issue.record("Password should exist")
            return
        }

        #expect(!keychain.storage.isEmpty)
        service.deletePassword(saved)
        #expect(keychain.storage.isEmpty, "Deleting password must remove secret from keychain")
        #expect(service.fetchPasswords(for: "delete.example.com").isEmpty)
    }

    @Test func guestModeDoesNotPersistPasswords() async throws {
        let container = try createInMemoryContainer()
        let keychain = MockKeychainService()
        let service = PasswordService(
            profileID: nil,
            container: container,
            authService: SuccessfulAuthenticationService(),
            keychainService: keychain
        )

        service.savePassword(
            url: "https://guest.example",
            username: "guest",
            passwordData: "temporary"
        )

        #expect(service.fetchPasswords(for: "https://guest.example").isEmpty)

        let descriptor = FetchDescriptor<Password>()
        let storedPasswords = try container.mainContext.fetch(descriptor)
        #expect(storedPasswords.isEmpty)
        #expect(keychain.storage.isEmpty)
    }
}