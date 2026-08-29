//
//  PasswordService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PasswordService: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    var container: ModelContainer?
    private var activeProfileID: UUID?
    private let authService: AuthenticationServiceProtocol
    
    @Published private(set) var isAuthenticated = false
    private var lastAuthTime: Date?
    private let authTimeout: TimeInterval = 300 // 5 minutes

    init(profileID: UUID? = nil, container: ModelContainer, authService: AuthenticationServiceProtocol = LocalAuthenticationService()) {
        self.activeProfileID = profileID
        self.container = container
        self.authService = authService
    }

    convenience init(profile: BrowserProfile, container: ModelContainer, authService: AuthenticationServiceProtocol = LocalAuthenticationService()) {
        self.init(profileID: profile.id, container: container, authService: authService)
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
    
    func savePassword(url: String, username: String, email: String? = nil, passwordData: String) {
        guard let context = container?.mainContext, let activeProfileID else { return }
        
        let host = URL(string: url)?.host ?? url
        
        // Normalize email: if it's empty string, treat as nil
        let normalizedEmail = (email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? nil : email
        
        // Prevent duplicate logins across sites: check if this exact credential set exists for this host
        // We check for matching host AND (username OR email) to avoid duplicate accounts for the same person
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { 
                $0.url == host && ($0.username == username || (normalizedEmail != nil && $0.email == normalizedEmail))
            }
        )
        
        let existingPasswords = (try? context.fetch(descriptor))?.filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }

        if let existing = existingPasswords?.first {
            // If the credentials match, just update the password if it changed
            existing.profileID = activeProfileID
            existing.passwordData = passwordData
            if let normalizedEmail {
                existing.email = normalizedEmail
            }
        } else {
            let newPassword = Password(profileID: activeProfileID, url: host, username: username, email: normalizedEmail, passwordData: passwordData)
            context.insert(newPassword)
        }
        
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
        
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }
    }
    
    func getAllPasswords() -> [Password] {
        guard isAuthenticated, let context = container?.mainContext, let activeProfileID else { return [] }
        let descriptor = FetchDescriptor<Password>(
            sortBy: [SortDescriptor(\.url)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }
    }

    func hasPasswords(for url: String) -> Bool {
        guard let context = container?.mainContext, let activeProfileID else { return false }
        let host = URL(string: url)?.host ?? url
        
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host }
        )
        
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}
