//
//  PasswordService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import Foundation
import SwiftData
import SwiftUI
import Observation

@MainActor
@Observable
final class PasswordService {
    @ObservationIgnored var container: ModelContainer?
    @ObservationIgnored private var activeProfileID: UUID?
    @ObservationIgnored private let authService: AuthenticationServiceProtocol
    @ObservationIgnored private let keychainService: KeychainServiceProtocol
    
    private(set) var isAuthenticated = false
    @ObservationIgnored private var lastAuthTime: Date?
    @ObservationIgnored private let authTimeout: TimeInterval = 300 // 5 minutes

    @MainActor
    init(profileID: UUID? = nil, container: ModelContainer, authService: AuthenticationServiceProtocol, keychainService: KeychainServiceProtocol = KeychainService.shared) {
        self.activeProfileID = profileID
        self.container = container
        self.authService = authService
        self.keychainService = keychainService
    }

    @MainActor
    convenience init(profile: BrowserProfile, container: ModelContainer, authService: AuthenticationServiceProtocol, keychainService: KeychainServiceProtocol = KeychainService.shared) {
        self.init(profileID: profile.id, container: container, authService: authService, keychainService: keychainService)
    }

    @MainActor
    convenience init(profileID: UUID? = nil, container: ModelContainer) {
        self.init(profileID: profileID, container: container, authService: LocalAuthenticationService(), keychainService: KeychainService.shared)
    }

    @MainActor
    convenience init(profile: BrowserProfile, container: ModelContainer) {
        self.init(profileID: profile.id, container: container, authService: LocalAuthenticationService(), keychainService: KeychainService.shared)
    }

    @MainActor
    convenience init(profile: BrowserProfile, container: ModelContainer, authService: AuthenticationServiceProtocol) {
        self.init(profileID: profile.id, container: container, authService: authService, keychainService: KeychainService.shared)
    }
    
    func authenticate() async -> Bool {
        if isAuthenticated, let lastAuth = lastAuthTime, Date().timeIntervalSince(lastAuth) < authTimeout {
            return true
        }
        
        do {
            let success = try await authService.authenticate(reason: "Access saved passwords")
            if success {
                isAuthenticated = true
                lastAuthTime = Date()
            }
            return success
        } catch {
            isAuthenticated = false
            return false
        }
    }

    func lock() {
        isAuthenticated = false
        lastAuthTime = nil
    }
    
    private static let keychainServiceName = "com.MrBlankCoding.Illuminate.passwords"

    private func keychainAccount(for passwordID: UUID) -> String {
        passwordID.uuidString
    }

    private func populateSecret(for password: Password) {
        if let secret = try? keychainService.retrieve(for: keychainAccount(for: password.id), service: Self.keychainServiceName) {
            password.passwordData = secret
        }
    }

    func savePassword(url: String, username: String, email: String? = nil, passwordData: String) {
        guard let context = container?.mainContext, let activeProfileID else { return }
        
        let host = URL(string: url)?.host ?? url
        let normalizedEmail = (email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? nil : email
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host }
        )

        let existingPasswords = (try? context.fetch(descriptor))?.filter {
            ($0.username == username || (normalizedEmail != nil && $0.email == normalizedEmail)) &&
            ($0.profileID == activeProfileID || $0.profileID == nil)
        }

        let targetPassword: Password
        if let existing = existingPasswords?.first {
            existing.profileID = activeProfileID
            existing.passwordData = ""
            if let normalizedEmail {
                existing.email = normalizedEmail
            }
            targetPassword = existing
        } else {
            let newPassword = Password(profileID: activeProfileID, url: host, username: username, email: normalizedEmail, passwordData: "")
            context.insert(newPassword)
            targetPassword = newPassword
        }
        
        try? keychainService.store(
            secret: passwordData,
            for: keychainAccount(for: targetPassword.id),
            service: Self.keychainServiceName
        )
        
        try? context.save()
    }
    
    func deletePassword(_ password: Password) {
        guard let context = container?.mainContext else { return }
        try? keychainService.delete(for: keychainAccount(for: password.id), service: Self.keychainServiceName)
        context.delete(password)
        try? context.save()
    }
    
    func fetchAccountMetadata(for url: String) -> [(username: String, email: String?)] {
        guard let context = container?.mainContext, let activeProfileID else { return [] }
        let host = URL(string: url)?.host ?? url
        
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host }
        )
        
        let passwords = ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }
        
        return passwords.map { ($0.username, $0.email) }
    }
    
    func fetchPasswords(for url: String) -> [Password] {
        guard isAuthenticated, let context = container?.mainContext, let activeProfileID else { return [] }
        let host = URL(string: url)?.host ?? url
        
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host }
        )
        
        let matches = ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }

        for item in matches {
            populateSecret(for: item)
        }
        return matches
    }
    
    func getAllPasswords() -> [Password] {
        guard isAuthenticated, let context = container?.mainContext, let activeProfileID else { return [] }
        let descriptor = FetchDescriptor<Password>(
            sortBy: [SortDescriptor(\.url)]
        )
        let matches = ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }

        for item in matches {
            populateSecret(for: item)
        }
        return matches
    }

    func hasPasswords(for url: String) -> Bool {
        guard let context = container?.mainContext, let _ = activeProfileID else { return false }
        let host = URL(string: url)?.host ?? url
        
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host }
        )
        
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}
