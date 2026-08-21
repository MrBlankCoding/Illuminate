//
//  TrackerBlockingService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/10/26.
//

import Foundation
import Combine

enum TrackerDomainPolicy: String, Codable {
    case allowed
    case blocked
}

@MainActor
final class TrackerBlockingService: ObservableObject {
    @Published var isEnabled: Bool = true {
        didSet {
            guard oldValue != isEnabled else { return }
            persistSettings()
            scheduleUpdate()
        }
    }

    @Published var learnThreshold: Int = 3 {
        didSet {
            let clamped = max(1, learnThreshold)
            if clamped != learnThreshold {
                learnThreshold = clamped
                return
            }
            guard oldValue != learnThreshold else { return }
            persistSettings()
            scheduleUpdate()
        }
    }

    @Published private(set) var domainStats: [DomainStat] = []

    private var seenOn: [String: Set<String>] = [:]
    private var overrides: [String: TrackerDomainPolicy] = [:]
    private let maxOriginsPerDomain = 64

    private let userDefaults: UserDefaults
    private let isPersistenceEnabled: Bool
    private let profileID: UUID?

    private var isLoadingPersistedData = false
    private var pendingUpdateTask: Task<Void, Never>?
    private let updateDebounceNanoseconds: UInt64 = 300_000_000 

    private var enabledKey:   String { scopedKey("trackerBlockingEnabled") }
    private var thresholdKey: String { scopedKey("trackerBlockingThreshold") }
    private var seenOnKey:    String { scopedKey("trackerBlockingSeenOn") }
    private var overridesKey: String { scopedKey("trackerBlockingOverrides") }
    private weak var adBlockService: AdBlockService?

    init(
        profileID: UUID? = nil,
        isPersistenceEnabled: Bool = true,
        userDefaults: UserDefaults = .standard,
        adBlockService: AdBlockService? = nil
    ) {
        self.profileID = profileID
        self.isPersistenceEnabled = isPersistenceEnabled
        self.userDefaults = userDefaults
        self.adBlockService = adBlockService

        loadPersistedData()
        refreshStats()
    }

    deinit {
        pendingUpdateTask?.cancel()
    }

    func prepareForRemoval() {
        pendingUpdateTask?.cancel()
    }

    func record(thirdPartyDomain: String, seenOn firstPartyDomain: String) {
        guard isEnabled else { return }
        guard !thirdPartyDomain.isEmpty, !firstPartyDomain.isEmpty else { return }
        guard !CaptchaCompatibility.isProviderHost(thirdPartyDomain) else { return }
        guard thirdPartyDomain != firstPartyDomain else { return } // same origin, prob not anything? 

        let normalized = thirdPartyDomain.lowercased()
        let origin     = firstPartyDomain.lowercased()

        var sites = seenOn[normalized] ?? []
        if sites.count >= max(maxOriginsPerDomain, learnThreshold) {
            return
        }

        let wasNew = sites.insert(origin).inserted
        seenOn[normalized] = sites

        guard wasNew else { return } // nothing changed

        scheduleUpdate()
    }

    func allow(domain: String) {
        setOverride(.allowed, for: domain)
    }

    func block(domain: String) {
        setOverride(.blocked, for: domain)
    }

    func clearOverride(for domain: String) {
        overrides.removeValue(forKey: domain.lowercased())
        persistOverrides()
        scheduleUpdate()
    }

    func clearLearnedData() {
        seenOn.removeAll()
        userDefaults.removeObject(forKey: seenOnKey)
        scheduleUpdate()
    }

    func setAdBlockService(_ service: AdBlockService) {
        adBlockService = service
        scheduleUpdate()
    }

    func flushPendingUpdates() {
        pendingUpdateTask?.cancel()
        pendingUpdateTask = nil
        persistSeenOn()
        refreshStats()
        rebuildBlockList()
    }

    private func setOverride(_ policy: TrackerDomainPolicy, for domain: String) {
        overrides[domain.lowercased()] = policy
        persistOverrides()
        scheduleUpdate()
    }

    private func scheduleUpdate() {
        pendingUpdateTask?.cancel()
        pendingUpdateTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: self.updateDebounceNanoseconds)
            } catch {
                return 
            }
            guard !Task.isCancelled else { return }
            self.persistSeenOn()
            self.refreshStats()
            self.rebuildBlockList()
        }
    }

    private func rebuildBlockList() {
        guard let adBlockService else { return }

        guard isEnabled else {
            adBlockService.updateTrackerBlockedHosts([])
            return
        }

        var toBlock = Set<String>()

        for (domain, sites) in seenOn {
            switch overrides[domain] {
            case .allowed:
                continue // user says keep it
            case .blocked:
                toBlock.insert(domain)
            case .none:
                if sites.count >= learnThreshold {
                    toBlock.insert(domain)
                }
            }
        }

        for (domain, policy) in overrides where policy == .blocked {
            toBlock.insert(domain)
        }

        adBlockService.updateTrackerBlockedHosts(toBlock)
    }

    private func refreshStats() {
        var stats: [DomainStat] = []
        stats.reserveCapacity(seenOn.count + overrides.count)

        for (domain, sites) in seenOn {
            let override = overrides[domain]
            let isBlocked: Bool
            switch override {
            case .allowed:
                isBlocked = false
            case .blocked:
                isBlocked = true
            case .none:
                isBlocked = isEnabled && sites.count >= learnThreshold
            }
            stats.append(DomainStat(
                domain: domain,
                firstPartyCount: sites.count,
                isBlocked: isBlocked,
                override: override
            ))
        }

        for (domain, policy) in overrides where policy == .blocked && seenOn[domain] == nil {
            stats.append(DomainStat(
                domain: domain,
                firstPartyCount: 0,
                isBlocked: true,
                override: policy
            ))
        }

        domainStats = stats.sorted { $0.firstPartyCount > $1.firstPartyCount }
    }

    private func loadPersistedData() {
        guard isPersistenceEnabled else { return }
        isLoadingPersistedData = true
        defer { isLoadingPersistedData = false }

        if let stored = userDefaults.object(forKey: enabledKey) as? Bool {
            isEnabled = stored
        }
        if let stored = userDefaults.object(forKey: thresholdKey) as? Int {
            learnThreshold = max(1, stored)
        }

        if let raw = userDefaults.object(forKey: seenOnKey) as? [String: [String]] {
            seenOn = raw.mapValues { Set($0) }
        }

        if let raw = userDefaults.object(forKey: overridesKey) as? [String: String] {
            overrides = raw.compactMapValues { TrackerDomainPolicy(rawValue: $0) }
        }
    }

    private func persistSettings() {
        guard isPersistenceEnabled, !isLoadingPersistedData else { return }
        userDefaults.set(isEnabled, forKey: enabledKey)
        userDefaults.set(learnThreshold, forKey: thresholdKey)
    }

    private func persistSeenOn() {
        guard isPersistenceEnabled else { return }
        let raw = seenOn.mapValues { Array($0) }
        userDefaults.set(raw, forKey: seenOnKey)
    }

    private func persistOverrides() {
        guard isPersistenceEnabled else { return }
        let raw = overrides.mapValues { $0.rawValue }
        userDefaults.set(raw, forKey: overridesKey)
    }

    private func scopedKey(_ key: String) -> String {
        guard let profileID else { return key }
        return "profile.\(profileID.uuidString).\(key)"
    }
}

struct DomainStat: Identifiable {
    var id: String { domain }
    let domain: String
    let firstPartyCount: Int
    let isBlocked: Bool
    let override: TrackerDomainPolicy?
}

extension URL {
    var eTLDPlusOne: String? {
        guard let host = self.host?.lowercased(), !host.isEmpty else { return nil }

        if host.hasPrefix("[") {
            return host
        }

        let bare = host.components(separatedBy: ":").first ?? host

        if isIPv4Address(bare) {
            return bare
        }

        let labels = bare.components(separatedBy: ".")
        guard labels.count >= 2 else { return bare }

        let twoPartTLDs: Set<String> = [
            "co.uk", "co.nz", "co.jp", "co.in", "co.za", "co.kr",
            "com.au", "com.br", "com.mx", "com.ar", "com.sg", "com.hk",
            "org.uk", "org.au", "net.au", "gov.uk", "ac.uk",
            "ne.jp", "or.jp", "go.jp", "ac.jp"
        ]

        if labels.count >= 3 {
            let candidate = labels.suffix(2).joined(separator: ".")
            if twoPartTLDs.contains(candidate) {
                return labels.suffix(3).joined(separator: ".")
            }
        }

        return labels.suffix(2).joined(separator: ".")
    }

    private func isIPv4Address(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return value >= 0 && value <= 255
        }
    }
}