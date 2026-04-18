//
//  RedirectProtectionService.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import Combine
import Foundation

@MainActor
final class RedirectProtectionService: ObservableObject {

    struct AllowedRedirectRule: Codable, Hashable, Identifiable {
        let id: UUID
        let sourceIdentifier: String
        let targetIdentifier: String

        init(id: UUID = UUID(), sourceIdentifier: String, targetIdentifier: String) {
            self.id = id
            self.sourceIdentifier = sourceIdentifier
            self.targetIdentifier = targetIdentifier
        }
    }

    struct BlockedRedirectPrompt: Identifiable {
        let id = UUID()
        let tabID: UUID
        let sourceURL: URL?
        let targetURL: URL
        fileprivate let proceedHandler: @MainActor () -> Void

        var sourceLabel: String {
            Self.displayLabel(for: sourceURL)
        }

        var targetLabel: String {
            Self.displayLabel(for: targetURL)
        }

        private static func displayLabel(for url: URL?) -> String {
            guard let url else { return "this page" }
            return url.host(percentEncoded: false) ?? url.absoluteString
        }
    }

    let chainDepthThreshold: Int
    let chainTimeWindow: TimeInterval

    @Published var isEnabled: Bool = true {
        didSet {
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            userDefaults.set(isEnabled, forKey: scopedKey("redirectProtectionEnabled"))
        }
    }

    @Published private(set) var allowedRedirectRules: [AllowedRedirectRule] = [] {
        didSet {
            guard !isLoadingProfile, isPersistenceEnabled else { return }
            persistAllowedRedirectRules()
        }
    }

    @Published private(set) var activeBlockedRedirect: BlockedRedirectPrompt?
    private let userDefaults: UserDefaults
    private let isPersistenceEnabled: Bool
    private let activeProfileID: UUID?
    private var isLoadingProfile = false
    private var dismissalTask: Task<Void, Never>?
    private var redirectChains: [UUID: [(date: Date, site: String)]] = [:]
    private var stableURLs: [UUID: URL] = [:]
    // this could be extended. [TODO]
    private static let wellKnownRedirectProviders: Set<String> = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "auth0.com",
        "appleid.apple.com",
        "github.com",
        "api.github.com",
        "checkout.stripe.com",
        "paypal.com",
        "www.paypal.com",
        "login.live.com",
        "oauth.reddit.com",
        "discord.com",
        "id.twitch.tv",
    ]

    init(
        profileID: UUID? = nil,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true,
        chainDepthThreshold: Int = 2,
        chainTimeWindow: TimeInterval = 1.5
    ) {
        self.userDefaults = userDefaults
        self.isPersistenceEnabled = isPersistenceEnabled
        self.activeProfileID = profileID
        self.chainDepthThreshold = chainDepthThreshold
        self.chainTimeWindow = chainTimeWindow

        isLoadingProfile = true
        isEnabled = isPersistenceEnabled
            ? (userDefaults.object(forKey: scopedKey("redirectProtectionEnabled")) as? Bool ?? true)
            : true
        allowedRedirectRules = loadAllowedRedirectRules()
        isLoadingProfile = false
    }

    func shouldBlockNavigation(
        from sourceURL: URL?,
        to targetURL: URL,
        tabID: UUID,
        isServerRedirect: Bool,
        now: Date = Date()
    ) -> Bool {
        guard isEnabled else { return false }
        guard let sourceURL else { return false }

        let sourceSite = effectiveSite(for: sourceURL)
        let targetSite = effectiveSite(for: targetURL)

        // Same effective site → always allow (covers subdomains).
        guard sourceSite != targetSite else { return false }

        // Scheme-only changes (http→https) with same host → always allow.
        if sourceURL.host(percentEncoded: false)?.lowercased()
            == targetURL.host(percentEncoded: false)?.lowercased()
        {
            return false
        }

        let sourceHost = sourceURL.host(percentEncoded: false)?.lowercased() ?? ""
        let targetHost = targetURL.host(percentEncoded: false)?.lowercased() ?? ""
        if Self.isWellKnownProvider(sourceHost) || Self.isWellKnownProvider(targetHost) {
            return false
        }

        if allowedRedirectRules.contains(where: {
            $0.sourceIdentifier == sourceSite && $0.targetIdentifier == targetSite
        }) {
            return false
        }

        pruneChain(for: tabID, before: now.addingTimeInterval(-chainTimeWindow))
        appendToChain(tabID: tabID, site: targetSite, at: now)

        let chainLength = redirectChains[tabID]?.count ?? 0
        if isServerRedirect {
            return true
        }

        return chainLength >= chainDepthThreshold
    }

    /// Legacy convenience that matches the old API surface.
    /// Kept for backward compatibility; prefers `shouldBlockNavigation` for new call sites.
    func shouldBlockRedirect(from sourceURL: URL?, to targetURL: URL) -> Bool {
        guard isEnabled else { return false }
        guard let sourceURL else { return false }

        let sourceSite = effectiveSite(for: sourceURL)
        let targetSite = effectiveSite(for: targetURL)

        guard sourceSite != targetSite else { return false }

        if sourceURL.host(percentEncoded: false)?.lowercased()
            == targetURL.host(percentEncoded: false)?.lowercased()
        {
            return false
        }

        let sourceHost = sourceURL.host(percentEncoded: false)?.lowercased() ?? ""
        let targetHost = targetURL.host(percentEncoded: false)?.lowercased() ?? ""
        if Self.isWellKnownProvider(sourceHost) || Self.isWellKnownProvider(targetHost) {
            return false
        }

        return !allowedRedirectRules.contains {
            $0.sourceIdentifier == sourceSite && $0.targetIdentifier == targetSite
        }
    }

    func recordUserNavigation(to url: URL, tabID: UUID) {
        stableURLs[tabID] = url
        redirectChains[tabID] = nil
    }

    func recordCommittedNavigation(to url: URL, tabID: UUID) {
        stableURLs[tabID] = url
        redirectChains[tabID] = nil
        dismissPrompt()
    }

    func stableURL(for tabID: UUID) -> URL? {
        stableURLs[tabID]
    }
    func cleanupTab(_ tabID: UUID) {
        stableURLs.removeValue(forKey: tabID)
        redirectChains.removeValue(forKey: tabID)
        if activeBlockedRedirect?.tabID == tabID {
            activeBlockedRedirect = nil
        }
    }

    func presentBlockedRedirect(
        tabID: UUID,
        sourceURL: URL?,
        targetURL: URL,
        proceedHandler: @escaping @MainActor () -> Void
    ) {
        dismissalTask?.cancel()
        
        let prompt = BlockedRedirectPrompt(
            tabID: tabID,
            sourceURL: sourceURL,
            targetURL: targetURL,
            proceedHandler: proceedHandler
        )
        activeBlockedRedirect = prompt
        
        dismissalTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.activeBlockedRedirect?.id == prompt.id {
                     self.dismissPrompt()
                }
            }
        }
    }

    func dismissPrompt() {
        dismissalTask?.cancel()
        dismissalTask = nil
        activeBlockedRedirect = nil
    }

    func proceedWithBlockedRedirect() {
        guard let prompt = activeBlockedRedirect else { return }
        activeBlockedRedirect = nil
        recordUserNavigation(to: prompt.targetURL, tabID: prompt.tabID)
        prompt.proceedHandler()
    }

    func allowBlockedRedirectAndProceed() {
        guard let prompt = activeBlockedRedirect else { return }
        addAllowedRedirect(from: prompt.sourceURL, to: prompt.targetURL)
        activeBlockedRedirect = nil
        recordUserNavigation(to: prompt.targetURL, tabID: prompt.tabID)
        prompt.proceedHandler()
    }

    func removeAllowedRedirectRule(id: UUID) {
        allowedRedirectRules.removeAll { $0.id == id }
    }

    func clearAllAllowedRedirectRules() {
        allowedRedirectRules.removeAll()
    }

    private func addAllowedRedirect(from sourceURL: URL?, to targetURL: URL) {
        guard let sourceURL else { return }

        let sourceIdentifier = effectiveSite(for: sourceURL)
        let targetIdentifier = effectiveSite(for: targetURL)

        guard !allowedRedirectRules.contains(where: {
            $0.sourceIdentifier == sourceIdentifier && $0.targetIdentifier == targetIdentifier
        }) else { return }

        let rule = AllowedRedirectRule(
            sourceIdentifier: sourceIdentifier,
            targetIdentifier: targetIdentifier
        )
        allowedRedirectRules.append(rule)
        AppLog.security(
            "Allow-listed redirect source=\(sourceURL.absoluteString) target=\(targetURL.absoluteString)"
        )
    }

    private func pruneChain(for tabID: UUID, before cutoff: Date) {
        guard var chain = redirectChains[tabID] else { return }
        chain.removeAll { $0.date < cutoff }
        redirectChains[tabID] = chain.isEmpty ? nil : chain
    }

    private func appendToChain(tabID: UUID, site: String, at date: Date) {
        var chain = redirectChains[tabID] ?? []
        chain.append((date: date, site: site))
        redirectChains[tabID] = chain
    }

    func effectiveSite(for url: URL) -> String {
        guard let host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else {
            return url.absoluteString.lowercased()
        }

        if host.contains(":") || host.allSatisfy({ $0.isNumber || $0 == "." }) || host == "localhost" {
            return host
        }

        return eTLDPlusOne(host) ?? host
    }

    private func eTLDPlusOne(_ host: String) -> String? {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return host }
        if labels.count >= 3 {
            let possibleTwoPartTLD = "\(labels[labels.count - 2]).\(labels[labels.count - 1])"
            if Self.twoPartTLDs.contains(possibleTwoPartTLD) {
                return "\(labels[labels.count - 3]).\(possibleTwoPartTLD)"
            }
        }

        return "\(labels[labels.count - 2]).\(labels[labels.count - 1])"
    }

    private static let twoPartTLDs: Set<String> = [
        "co.uk", "co.jp", "co.kr", "co.nz", "co.za", "co.in", "co.id",
        "com.au", "com.br", "com.cn", "com.mx", "com.sg", "com.tw", "com.hk",
        "org.uk", "org.au",
        "net.au", "net.nz",
        "ac.uk", "ac.jp",
        "gov.uk", "gov.au",
        "edu.au",
    ]

    private static func isWellKnownProvider(_ host: String) -> Bool {
        wellKnownRedirectProviders.contains(where: { provider in
            host == provider || host.hasSuffix(".\(provider)")
        })
    }

    private func loadAllowedRedirectRules() -> [AllowedRedirectRule] {
        guard isPersistenceEnabled else { return [] }
        guard let data = userDefaults.data(forKey: scopedKey("allowedRedirectRules")) else { return [] }
        return (try? JSONDecoder().decode([AllowedRedirectRule].self, from: data)) ?? []
    }

    private func persistAllowedRedirectRules() {
        let data = try? JSONEncoder().encode(allowedRedirectRules)
        userDefaults.set(data, forKey: scopedKey("allowedRedirectRules"))
    }

    private func scopedKey(_ key: String) -> String {
        guard let activeProfileID else { return key }
        return "profile.\(activeProfileID.uuidString).\(key)"
    }
}
