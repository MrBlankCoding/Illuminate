//
//  ProfileManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/22/26.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class ProfileManager: ObservableObject {
    @Published private(set) var profiles: [BrowserProfile] = []
    
    private var environments: [UUID: ProfileEnvironment] = [:]

    private let fileManager: FileManager
    private let profilesURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.profilesURL = fileManager.illuminateProfilesCatalogURL()
        loadProfiles()
    }

    func createProfile(named rawName: String, iconName: String = "person.crop.circle") -> BrowserProfile {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "Profile \(profiles.count + 1)" : trimmedName
        let profile = BrowserProfile(name: name, iconName: iconName)
        profiles.append(profile)
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveProfiles()
        return profile
    }

    func environment(for profileID: UUID, container: ModelContainer) -> ProfileEnvironment? {
        if let env = environments[profileID] { return env }
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return nil }
        let env = ProfileEnvironment(profile: profile, modelContainer: container)
        environments[profileID] = env
        return env
    }

    func renameProfile(_ profile: BrowserProfile, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }

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

        profiles.removeAll { $0.id == profile.id }
        environments.removeValue(forKey: profile.id)
        saveProfiles()
        try? fileManager.removeItem(at: fileManager.illuminateProfileDirectory(profileID: profile.id))
    }

    private func loadProfiles() {
        if let data = try? Data(contentsOf: profilesURL),
           let savedProfiles = try? JSONDecoder().decode([BrowserProfile].self, from: data),
           !savedProfiles.isEmpty {
            profiles = savedProfiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return
        }

        profiles = [BrowserProfile(name: "Personal")]
        saveProfiles()
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: profilesURL, options: .atomic)
    }
}
