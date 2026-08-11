//
//  WebsitePermissionService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import Combine
import Foundation

enum WebsitePermissionType: String, CaseIterable, Codable, Identifiable {
    case camera
    case microphone
    case location

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .location: "Location"
        }
    }

    var icon: String {
        switch self {
        case .camera: "video.fill"
        case .microphone: "mic.fill"
        case .location: "location.fill"
        }
    }
}

enum WebsitePermissionDecision: String, Codable {
    case prompt
    case allow
    case deny
}

struct WebsitePermissionSite: Identifiable, Hashable {
    let origin: String
    let decisions: [WebsitePermissionType: WebsitePermissionDecision]

    var id: String { origin }
}

struct PendingWebsitePermission: Identifiable {
    let id = UUID()
    let origin: String
    let types: [WebsitePermissionType]
}

@MainActor
final class WebsitePermissionService: ObservableObject {
    @Published var pendingRequest: PendingWebsitePermission?
    @Published private(set) var sites: [WebsitePermissionSite] = []

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let persists: Bool
    private var decisions: [String: [WebsitePermissionType: WebsitePermissionDecision]] = [:]
    private var pendingCompletion: ((WebsitePermissionDecision) -> Void)?

    init(profileID: UUID?, userDefaults: UserDefaults = .standard, persists: Bool = true) {
        self.userDefaults = userDefaults
        self.persists = persists
        self.storageKey = profileID.map { "profile.\($0.uuidString).websitePermissions" } ?? "websitePermissions"
        if persists,
           let data = userDefaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([String: [String: WebsitePermissionDecision]].self, from: data) {
            self.decisions = stored.reduce(into: [:]) { result, item in
                result[item.key] = Dictionary(uniqueKeysWithValues: item.value.compactMap { key, value in
                    WebsitePermissionType(rawValue: key).map { ($0, value) }
                })
            }
        }
        refreshSites()
    }

    func decision(for origin: String, type: WebsitePermissionType) -> WebsitePermissionDecision {
        decisions[origin]?[type] ?? .prompt
    }

    func requestPermission(
        for origin: String,
        types: [WebsitePermissionType],
        completion: @escaping (WebsitePermissionDecision) -> Void
    ) {
        let existing = types.map { decision(for: origin, type: $0) }
        if existing.allSatisfy({ $0 == .allow }) { completion(.allow); return }
        if existing.contains(.deny) { completion(.deny); return }

        // WebKit serializes permission prompts. Reject a second simultaneous request.
        guard pendingRequest == nil else { completion(.deny); return }
        pendingRequest = PendingWebsitePermission(origin: origin, types: types)
        pendingCompletion = completion
    }

    func resolvePendingRequest(as decision: WebsitePermissionDecision) {
        guard let pendingRequest else { return }
        for type in pendingRequest.types {
            set(decision, for: pendingRequest.origin, type: type)
        }
        let completion = pendingCompletion
        pendingCompletion = nil
        self.pendingRequest = nil
        completion?(decision)
    }

    func set(_ decision: WebsitePermissionDecision, for origin: String, type: WebsitePermissionType) {
        var siteDecisions = decisions[origin] ?? [:]
        if decision == .prompt {
            siteDecisions.removeValue(forKey: type)
        } else {
            siteDecisions[type] = decision
        }
        if siteDecisions.isEmpty {
            decisions.removeValue(forKey: origin)
        } else {
            decisions[origin] = siteDecisions
        }
        persist()
        refreshSites()
    }

    func clearPermissions(for origin: String) {
        decisions.removeValue(forKey: origin)
        persist()
        refreshSites()
    }

    private func refreshSites() {
        sites = decisions.keys.sorted().map { WebsitePermissionSite(origin: $0, decisions: decisions[$0] ?? [:]) }
    }

    private func persist() {
        guard persists else { return }
        let stored = decisions.mapValues { values in
            Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
