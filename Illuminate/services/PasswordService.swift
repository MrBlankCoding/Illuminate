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

    init(profileID: UUID? = nil, container: ModelContainer) {
        self.activeProfileID = profileID
        self.container = container
    }

    convenience init(profile: BrowserProfile, container: ModelContainer) {
        self.init(profileID: profile.id, container: container)
    }
    
    func savePassword(url: String, username: String, passwordData: String) {
        guard let context = container?.mainContext, let activeProfileID else { return }
        
        let host = URL(string: url)?.host ?? url
        
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host && $0.username == username }
        )
        
        let existingPassword = (try? context.fetch(descriptor))?.first(where: {
            $0.profileID == activeProfileID || $0.profileID == nil
        })

        if let existing = existingPassword {
            existing.profileID = activeProfileID
            existing.passwordData = passwordData
        } else {
            let newPassword = Password(profileID: activeProfileID, url: host, username: username, passwordData: passwordData)
            context.insert(newPassword)
        }
        
        try? context.save()
    }
    
    func fetchPasswords(for url: String) -> [Password] {
        guard let context = container?.mainContext, let activeProfileID else { return [] }
        let host = URL(string: url)?.host ?? url
        
        let descriptor = FetchDescriptor<Password>(
            predicate: #Predicate<Password> { $0.url == host }
        )
        
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }
    }
    
    func getAllPasswords() -> [Password] {
        guard let context = container?.mainContext, let activeProfileID else { return [] }
        let descriptor = FetchDescriptor<Password>(
            sortBy: [SortDescriptor(\.url)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.profileID == activeProfileID || $0.profileID == nil
        }
    }
}
