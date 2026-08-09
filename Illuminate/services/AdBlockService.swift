//
//  AdBlockService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import Foundation
import Combine
import WebKit

final class AdBlockService: ObservableObject {

    // this should be improved
    // instead of using a downloaded list we could fetch a new one monthly?

    private static let sharedRuleListIdentifier = "IlluminateAdBlockRules"
    @Published var isEnabled: Bool = true {
        didSet {
            guard !isLoadingProfile else { return }
            if isPersistenceEnabled {
                userDefaults.set(isEnabled, forKey: scopedKey("adBlockEnabled"))
            }
            if isEnabled {
                prepareIfNeeded()
            } else {
                clearContentRuleList()
            }
        }
    }
    
    @Published private(set) var contentRuleList: WKContentRuleList?
    
    private var blockedHosts: Set<String> = []
    private var blockedURLKeywords: Set<String> = []
    private var allowlistedHosts: Set<String> = []
    private let userDefaults: UserDefaults
    private let baseRuleListIdentifier: String
    private let isPersistenceEnabled: Bool
    private var hasPreparedRuleList = false
    private var isPreparingRuleList = false
    private var activeProfileID: UUID?
    private var isLoadingProfile = false

    init(
        profileID: UUID? = nil,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true,
        ruleListIdentifier: String = "IlluminateAdBlockRules-\(UUID().uuidString)"
    ) {
        self.userDefaults = userDefaults
        self.activeProfileID = profileID
        self.baseRuleListIdentifier = ruleListIdentifier
        self.isPersistenceEnabled = isPersistenceEnabled
        self.isEnabled = isPersistenceEnabled
            ? (userDefaults.object(forKey: scopedKey("adBlockEnabled")) as? Bool ?? true)
            : true
        loadDefaultRules()
        
        if self.isEnabled {
            self.prepareIfNeeded()
        }
    }

    convenience init(
        profile: BrowserProfile,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true,
        ruleListIdentifier: String = "IlluminateAdBlockRules-\(UUID().uuidString)"
    ) {
        self.init(
            profileID: profile.id,
            userDefaults: userDefaults,
            isPersistenceEnabled: isPersistenceEnabled,
            ruleListIdentifier: ruleListIdentifier
        )
    }
    func prepareIfNeeded() {
        guard isEnabled, !hasPreparedRuleList, !isPreparingRuleList else { return }
        isPreparingRuleList = true
        let ruleListIdentifier = scopedRuleListIdentifier()

        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: ruleListIdentifier) { [weak self] list, _ in
            guard let self else { return }
            if let list = list {
                DispatchQueue.main.async {
                    self.contentRuleList = list
                    self.hasPreparedRuleList = true
                    self.isPreparingRuleList = false
                }
            } else {
                self.updateContentRuleList()
            }
        }
    }

    private func updateContentRuleList() {
        guard isEnabled else {
            clearContentRuleList()
            return
        }

        let rules = generateRulesJSON()
        let ruleListIdentifier = scopedRuleListIdentifier()
        
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: ruleListIdentifier, encodedContentRuleList: rules) { [weak self] (list: WKContentRuleList?, error: Error?) in
            if let error = error {
                print("AdBlockService: Failed to compile rules: \(error)")
                DispatchQueue.main.async {
                    self?.isPreparingRuleList = false
                }
                return
            }
            
            if let contentList = list {
                print("AdBlockService: Successfully compiled rules")
                DispatchQueue.main.async {
                    self?.contentRuleList = contentList
                    self?.hasPreparedRuleList = true
                    self?.isPreparingRuleList = false
                }
            }
        }
    }

    private var cachedBundledRules: [[String: Any]]?

    private func generateRulesJSON() -> String {
        var rulesArray: [[String: Any]] = []
        if let cached = cachedBundledRules {
            rulesArray.append(contentsOf: cached)
        } else if let bundlePath = Bundle(for: AdBlockService.self).path(forResource: "EasyList", ofType: "txt") ?? Bundle.main.path(forResource: "EasyList", ofType: "txt"),
           let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            let parsedJSON = EasyListParser.parse(content: content)
            if let data = parsedJSON.data(using: .utf8),
               let parsedRules = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                cachedBundledRules = parsedRules
                rulesArray.append(contentsOf: parsedRules)
            }
        }
        for host in allowlistedHosts {
            rulesArray.insert([
                "trigger": [
                    "url-filter": ".*\(host.replacingOccurrences(of: ".", with: "\\.")).*",
                    "url-filter-is-case-sensitive": false
                ],
                "action": [
                    "type": "ignore-previous-rules"
                ]
            ], at: 0)
        }

        for host in blockedHosts {
            rulesArray.append([
                "trigger": [
                    "url-filter": ".*\(host.replacingOccurrences(of: ".", with: "\\.")).*",
                    "url-filter-is-case-sensitive": false
                ],
                "action": [
                    "type": "block"
                ]
            ])
        }

        for keyword in blockedURLKeywords {
            rulesArray.append([
                "trigger": [
                    "url-filter": ".*\(NSRegularExpression.escapedPattern(for: keyword)).*",
                    "url-filter-is-case-sensitive": false
                ],
                "action": [
                    "type": "block"
                ]
            ])
        }

        let hasBlockingRule = rulesArray.contains { rule in
            let action = rule["action"] as? [String: Any]
            let type = action?["type"] as? String
            return type != nil && type != "ignore-previous-rules"
        }

        // WebKit rejects rule lists that only contain allowlist entries.
        if !hasBlockingRule {
            rulesArray.append([
                "trigger": ["url-filter": "https://illuminate-internal-dummy-rule-to-prevent-error-6.com"],
                "action": ["type": "block"]
            ])
        }

        if let data = try? JSONSerialization.data(withJSONObject: rulesArray, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        
        return "[]"
    }

    private func loadDefaultRules() {
        allowlistedHosts = ["browserbench.org"]
    }

    func updateBlockedHosts(_ hosts: Set<String>) {
        self.blockedHosts = hosts
        self.updateContentRuleList()
    }

    func addAllowlistHost(_ host: String) {
        self.allowlistedHosts.insert(host.lowercased())
        self.updateContentRuleList()
    }

    private func clearContentRuleList() {
        DispatchQueue.main.async { [weak self] in
            self?.contentRuleList = nil
            self?.hasPreparedRuleList = false
            self?.isPreparingRuleList = false
        }
    }

    private func scopedKey(_ key: String) -> String {
        guard let activeProfileID else { return key }
        return "profile.\(activeProfileID.uuidString).\(key)"
    }

    private func scopedRuleListIdentifier() -> String {
        guard let activeProfileID else { return baseRuleListIdentifier }
        return "\(baseRuleListIdentifier).\(activeProfileID.uuidString)"
    }
}
