//
//  ProfileManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import Combine
import Foundation
import SwiftData
import os

@MainActor
final class ProfileManager: ObservableObject {
    nonisolated static let defaultIconName = "person.crop.circle"

    @Published private(set) var profiles: [BrowserProfile] = []
    let profileDeleted = PassthroughSubject<UUID, Never>()

    private var environments: [UUID: ProfileEnvironment] = [:]
    private var guestEnvironments: [UUID: ProfileEnvironment] = [:]

    private let fileManager: FileManager
    private let profilesURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.profilesURL = fileManager.illuminateProfilesCatalogURL()
        Task {
            await loadProfilesAsync()
        }
    }

    @discardableResult
    func createProfile(named rawName: String, iconName: String = ProfileManager.defaultIconName) -> BrowserProfile {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "Profile \(profiles.count + 1)" : trimmedName
        let name = uniqueName(baseName)
        let profile = BrowserProfile(name: name, iconName: iconName)
        profiles.append(profile)
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveProfiles()
        return profile
    }

    func renameProfile(_ profile: BrowserProfile, to rawName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }

        let name = uniqueName(trimmedName, excluding: profile.id)
        profiles[index].name = name
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveProfiles()
    }

    func updateIcon(for profile: BrowserProfile, iconName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].iconName = iconName
        saveProfiles()
    }

    func deleteProfile(_ profile: BrowserProfile) {
        guard profiles.count > 1 else { return }
        guard profiles.contains(where: { $0.id == profile.id }) else { return }

        profiles.removeAll { $0.id == profile.id }

        if let env = environments.removeValue(forKey: profile.id) {
            env.prepareForRemoval()
        }

        saveProfiles()

        let directory = fileManager.illuminateProfileDirectory(profileID: profile.id)
        do {
            try fileManager.removeItem(at: directory)
        } catch {
            AppLog.error("Failed to remove profile directory for \(profile.id.uuidString)", error: error)
        }

        profileDeleted.send(profile.id)
    }

    func environment(for route: BrowserWindowRoute, container: ModelContainer) -> ProfileEnvironment? {
        switch route {
        case let .profile(profileID):
            if let env = environments[profileID] { return env }
            guard let profile = profiles.first(where: { $0.id == profileID }) else { return nil }
            let env = ProfileEnvironment(profile: profile, modelContainer: container)
            environments[profileID] = env
            return env
        case let .guest(sessionID):
            if let env = guestEnvironments[sessionID] { return env }
            let guestProfile = BrowserProfile(
                id: sessionID,
                name: "Guest",
                iconName: "person.fill.questionmark"
            )
            let env = ProfileEnvironment(
                profile: guestProfile,
                modelContainer: container,
                isGuestSession: true,
                sessionIdentifier: sessionID
            )
            guestEnvironments[sessionID] = env
            return env
        }
    }

    func endGuestSession(_ sessionID: UUID) {
        guard let env = guestEnvironments.removeValue(forKey: sessionID) else { return }
        env.prepareForRemoval()
    }

    private func loadProfilesAsync() async {
        let url = profilesURL
        let loadedProfiles: [BrowserProfile]
        
        if let data = try? Data(contentsOf: url),
           let savedProfiles = try? JSONDecoder().decode([BrowserProfile].self, from: data),
           !savedProfiles.isEmpty {
            loadedProfiles = savedProfiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            loadedProfiles = [BrowserProfile(name: "Personal")]
        }
        
        await MainActor.run {
            self.profiles = loadedProfiles
            if loadedProfiles.count == 1 && loadedProfiles[0].name == "Personal" {
                saveProfiles()
            }
        }
    }

    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: profilesURL, options: .atomic)
        } catch {
            AppLog.error("Failed to save profiles", error: error)
        }
    }
    
    private func uniqueName(_ desiredName: String, excluding excludedID: UUID? = nil) -> String {
        let existingNames = Set(
            profiles
                .filter { $0.id != excludedID }
                .map { $0.name.lowercased() }
        )
        guard existingNames.contains(desiredName.lowercased()) else { return desiredName }

        var suffix = 2
        var candidate = "\(desiredName) \(suffix)"
        while existingNames.contains(candidate.lowercased()) {
            suffix += 1
            candidate = "\(desiredName) \(suffix)"
        }
        return candidate
    }
}