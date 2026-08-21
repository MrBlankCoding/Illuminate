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
    private static let staticRuleListIdentifier = "IlluminateStaticAdBlockRules-v6"
    private static let sharedRuleListIdentifier = "IlluminateDynamicAdBlockRules"
    private static let debounceInterval: TimeInterval = 0.25
    private static let easyListURL = URL(string: "https://easylist.to/easylist/easylist.txt")!
    private static let easyListRefreshInterval: TimeInterval = 30 * 24 * 60 * 60
    private static let easyListCacheFileName = "easylist.txt"

    @Published var isEnabled: Bool = true {
        didSet {
            guard !isLoadingProfile, oldValue != isEnabled else { return }
            AppLog.info("AdBlockService: Setting changed isEnabled=\(isEnabled)")
            if isPersistenceEnabled {
                userDefaults.set(isEnabled, forKey: scopedKey("adBlockEnabled"))
            }
            if isEnabled {
                prepareStaticRuleListIfNeeded()
                scheduleDynamicRuleListUpdate()
            } else {
                clearContentRuleLists()
            }
        }
    }

    @Published private(set) var contentRuleLists: [WKContentRuleList] = []

    var contentRuleList: WKContentRuleList? {
        guard isEnabled else { return nil }
        return contentRuleLists.first
    }

    private var staticRuleList: WKContentRuleList?
    private var dynamicRuleList: WKContentRuleList?

    private var blockedHosts: Set<String> = []
    private var trackerBlockedHosts: Set<String> = []
    private var blockedURLKeywords: Set<String> = []
    private var allowlistedHosts: Set<String> = []

    private let userDefaults: UserDefaults
    private let baseRuleListIdentifier: String
    private let isPersistenceEnabled: Bool
    private var activeProfileID: UUID?
    private var isLoadingProfile = false

    private var isPreparingStaticRuleList = false
    private var isPreparingDynamicRuleList = false
    private var pendingDynamicUpdateWorkItem: DispatchWorkItem?
    private let ruleGenerationQueue = DispatchQueue(label: "com.illuminate.adblock.rulegen", qos: .utility)
    private let easyListDownloadQueue = DispatchQueue(label: "com.illuminate.adblock.easylist", qos: .utility)
    private var cachedStaticRulesJSON: String?
    #if DEBUG
    // Test hooks
    var debug_lastGeneratedStaticJSON: String?
    var debug_lastGeneratedDynamicJSON: String?
    #endif

    init(
        profileID: UUID? = nil,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true,
        ruleListIdentifier: String = AdBlockService.sharedRuleListIdentifier
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
            prepareStaticRuleListIfNeeded()
        }
    }

    convenience init(
        profile: BrowserProfile,
        userDefaults: UserDefaults = .standard,
        isPersistenceEnabled: Bool = true,
        ruleListIdentifier: String = AdBlockService.sharedRuleListIdentifier
    ) {
        self.init(
            profileID: profile.id,
            userDefaults: userDefaults,
            isPersistenceEnabled: isPersistenceEnabled,
            ruleListIdentifier: ruleListIdentifier
        )
    }

    func prepareForRemoval() {
        clearContentRuleLists()
        
        let identifier = scopedDynamicRuleListIdentifier()
        WKContentRuleListStore.default().removeContentRuleList(forIdentifier: identifier) { _ in
            AppLog.info("AdBlockService: Removed dynamic rule list for \(identifier)")
        }
    }

    func effectiveRuleLists(for host: String?) -> [WKContentRuleList] {
        guard isEnabled, !isHostAllowlisted(host) else { return [] }
        return contentRuleLists
    }

    func prepareIfNeeded() {
        guard isEnabled else { return }
        prepareStaticRuleListIfNeeded()
    }

    func isHostAllowlisted(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return allowlistedHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    func updateBlockedHosts(_ hosts: Set<String>) {
        guard blockedHosts != hosts else { return }
        blockedHosts = hosts
        scheduleDynamicRuleListUpdate()
    }

    func updateTrackerBlockedHosts(_ hosts: Set<String>) {
        guard trackerBlockedHosts != hosts else { return }
        trackerBlockedHosts = hosts
        scheduleDynamicRuleListUpdate()
    }

    func addAllowlistHost(_ host: String) {
        let normalized = host.lowercased()
        guard !allowlistedHosts.contains(normalized) else { return }
        allowlistedHosts.insert(normalized)
        objectWillChange.send()
    }

    private func prepareStaticRuleListIfNeeded() {
        guard staticRuleList == nil, !isPreparingStaticRuleList else { return }
        isPreparingStaticRuleList = true

        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: Self.staticRuleListIdentifier) { [weak self] list, _ in
            guard let self else { return }
            let hasCompiledList = list != nil

            if let list {
                #if DEBUG
                let json = self.generateStaticRulesJSON(includeEasyList: true)
                self.debug_lastGeneratedStaticJSON = json
                #endif
                DispatchQueue.main.async {
                    self.staticRuleList = list
                    self.publishCombinedRuleLists()
                }
            } else {
                self.compileStaticRuleList()
            }

            self.refreshEasyListCacheIfNeeded { [weak self] didUpdateCache in
                guard let self else { return }
                if didUpdateCache {
                    self.cachedStaticRulesJSON = nil
                    self.compileStaticRuleList()
                } else if hasCompiledList {
                    DispatchQueue.main.async {
                        self.isPreparingStaticRuleList = false
                    }
                }
            }
        }
    }

    private func compileStaticRuleList(includeEasyList: Bool = true) {
        ruleGenerationQueue.async { [weak self] in
            guard let self else { return }
            let json = self.generateStaticRulesJSON(includeEasyList: includeEasyList)

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: Self.staticRuleListIdentifier,
                encodedContentRuleList: json
            ) { [weak self] list, error in
                guard let self else { return }
                if let error {
                    let message = String(describing: error)
                    let isExpectedUnsupportedRegex = message.lowercased().contains("unsupported regular expression")
                        || message.lowercased().contains("disjunctions are not supported yet")
                        || message.lowercased().contains("invalid or unsupported regular expression")

                    if isExpectedUnsupportedRegex {
                        if includeEasyList {
                            AppLog.info("AdBlockService: Retrying static rule compilation without EasyList due to unsupported regex features")
                            self.compileStaticRuleList(includeEasyList: false)
                        } else {
                            DispatchQueue.main.async { self.isPreparingStaticRuleList = false }
                        }
                        return
                    }

                    AppLog.error("AdBlockService: Failed to compile static rules", error: error)
                    if includeEasyList {
                        AppLog.info("AdBlockService: Retrying with built-in ad/privacy rules only")
                        self.compileStaticRuleList(includeEasyList: false)
                    } else {
                        DispatchQueue.main.async { self.isPreparingStaticRuleList = false }
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.staticRuleList = list
                    self.isPreparingStaticRuleList = false
                    self.publishCombinedRuleLists()
                }
            }
        }
    }

    private func refreshEasyListCacheIfNeeded(completion: @escaping (Bool) -> Void) {
        easyListDownloadQueue.async { [weak self] in
            guard let self else {
                completion(false)
                return
            }

            guard self.isEasyListCacheRefreshNeeded() else {
                completion(false)
                return
            }

            URLSession.shared.dataTask(with: Self.easyListURL) { [weak self] data, response, error in
                guard let self else {
                    completion(false)
                    return
                }

                if let error {
                    AppLog.error("AdBlockService: Failed to download EasyList", error: error)
                    completion(false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let data,
                      self.isValidEasyListData(data) else {
                    AppLog.error("AdBlockService: EasyList download returned an invalid response (status=\((response as? HTTPURLResponse)?.statusCode ?? -1))")
                    completion(false)
                    return
                }

                do {
                    try self.writeEasyListCache(data)
                    AppLog.info("AdBlockService: Successfully updated and cached EasyList")
                    completion(true)
                } catch {
                    AppLog.error("AdBlockService: Failed to cache EasyList", error: error)
                    completion(false)
                }
            }.resume()
        }
    }

    private func isEasyListCacheRefreshNeeded() -> Bool {
        guard let cacheURL = easyListCacheURL() else { return true }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return true
        }

        return Date().timeIntervalSince(modifiedAt) >= Self.easyListRefreshInterval
    }

    private func easyListCacheURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Illuminate", isDirectory: true)
            .appendingPathComponent("EasyList", isDirectory: true)
            .appendingPathComponent(Self.easyListCacheFileName, isDirectory: false)
    }

    private func writeEasyListCache(_ data: Data) throws {
        guard let cacheURL = easyListCacheURL() else { return }
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
    }

    private func cachedEasyListContent() -> String? {
        guard let cacheURL = easyListCacheURL() else { return nil }
        return try? String(contentsOf: cacheURL, encoding: .utf8)
    }

    private func easyListContentForStaticRules() -> String? {
        if let cachedContent = cachedEasyListContent() {
            return cachedContent
        }

        guard let bundleURL = bundledEasyListURL() else { return nil }
        return try? String(contentsOf: bundleURL, encoding: .utf8)
    }

    private func bundledEasyListURL() -> URL? {
        let bundles = [Bundle(for: AdBlockService.self), Bundle.main]

        for bundle in bundles {
            if let resourceURL = bundle.url(forResource: "EasyList", withExtension: "txt", subdirectory: "Resources") {
                return resourceURL
            }

            if let resourceURL = bundle.url(forResource: "EasyList", withExtension: "txt") {
                return resourceURL
            }
        }

        return nil
    }

    private func isValidEasyListData(_ data: Data) -> Bool {
        guard let content = String(data: data.prefix(2048), encoding: .utf8) else { return false }
        return content.contains("EasyList") || content.contains("Adblock Plus")
    }

    private struct DynamicRuleSnapshot {
        let blockedHosts: Set<String>
        let trackerBlockedHosts: Set<String>
        let blockedURLKeywords: Set<String>
    }

    private func scheduleDynamicRuleListUpdate() {
        guard isEnabled else {
            clearContentRuleLists()
            return
        }

        pendingDynamicUpdateWorkItem?.cancel()
        isPreparingDynamicRuleList = true

        let snapshot = DynamicRuleSnapshot(
            blockedHosts: blockedHosts,
            trackerBlockedHosts: trackerBlockedHosts,
            blockedURLKeywords: blockedURLKeywords
        )

#if DEBUG
        debug_lastGeneratedDynamicJSON = generateDynamicRulesJSON(snapshot: snapshot)
#endif

        let workItem = DispatchWorkItem { [weak self] in
            self?.compileDynamicRuleList(snapshot: snapshot)
        }
        pendingDynamicUpdateWorkItem = workItem
        ruleGenerationQueue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: workItem)
    }

    private func compileDynamicRuleList(snapshot: DynamicRuleSnapshot) {
        let json = generateDynamicRulesJSON(snapshot: snapshot)
        let identifier = scopedDynamicRuleListIdentifier()

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: json
        ) { [weak self] list, error in
            guard let self else { return }
            if let error {
                // fail silently 
                let message = String(describing: error)
                let isExpectedUnsupportedRegex = message.lowercased().contains("unsupported regular expression")
                    || message.lowercased().contains("disjunctions are not supported yet")
                    || message.lowercased().contains("invalid or unsupported regular expression")

                if isExpectedUnsupportedRegex {
                    AppLog.info("AdBlockService: Skipping dynamic rule list update due to unsupported regex features")
                    DispatchQueue.main.async { self.isPreparingDynamicRuleList = false }
                    return
                }

                AppLog.error("AdBlockService: Failed to compile dynamic rules", error: error)
                DispatchQueue.main.async { self.isPreparingDynamicRuleList = false }
                return
            }
            DispatchQueue.main.async {
                self.dynamicRuleList = list
                self.isPreparingDynamicRuleList = false
                self.publishCombinedRuleLists()
            }
        }
    }

    private func publishCombinedRuleLists() {
        Task { @MainActor in
            self.contentRuleLists = [staticRuleList, dynamicRuleList].compactMap { $0 }
            AppLog.info("AdBlockService: Publishing combined rule lists (count=\(contentRuleLists.count))")
        }
    }

    private func clearContentRuleLists() {
        pendingDynamicUpdateWorkItem?.cancel()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.staticRuleList = nil
            self.dynamicRuleList = nil
            self.contentRuleLists = []
            self.isPreparingStaticRuleList = false
            self.isPreparingDynamicRuleList = false
        }
    }

    private func generateStaticRulesJSON(includeEasyList: Bool = true) -> String {
        if includeEasyList, let cached = cachedStaticRulesJSON { return cached }

        var rulesArray: [[String: Any]] = []

        if includeEasyList, let content = easyListContentForStaticRules() {
            let parsedJSON = EasyListParser.parse(content: content)
            if let data = parsedJSON.data(using: .utf8),
               let parsedRules = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                rulesArray.append(contentsOf: parsedRules)
            }
        }

        for domain in Self.supplementaryAdDomains {
            rulesArray.append(Self.blockRule(urlFilter: Self.domainAnchoredPattern(for: domain)))
        }
        rulesArray.append(contentsOf: Self.supplementaryAdScriptRules)
        rulesArray.append(contentsOf: Self.youTubeAdRequestRules)
        rulesArray.append(Self.youTubeCosmeticRule)
        rulesArray.append(Self.genericAdCosmeticRule)
        rulesArray.append(Self.adBlockTestCosmeticRule)

        for domain in CaptchaCompatibility.providerDomains {
            rulesArray.append(Self.allowRule(for: domain))
        }

        let json = Self.serialize(rulesArray)
        if includeEasyList {
            cachedStaticRulesJSON = json
        }
#if DEBUG
        debug_lastGeneratedStaticJSON = json
#endif
        return json
    }

    private func generateDynamicRulesJSON(snapshot: DynamicRuleSnapshot) -> String {
        var rulesArray: [[String: Any]] = []

        for host in snapshot.blockedHosts {
            rulesArray.append(Self.blockRule(urlFilter: Self.domainAnchoredPattern(for: host)))
        }

        for host in snapshot.trackerBlockedHosts {
            rulesArray.append(Self.blockRule(urlFilter: Self.domainAnchoredPattern(for: host), thirdPartyOnly: true))
        }

        for keyword in snapshot.blockedURLKeywords {
            rulesArray.append(Self.blockRule(urlFilter: NSRegularExpression.escapedPattern(for: keyword)))
        }

        if rulesArray.isEmpty {
            rulesArray.append([
                "trigger": ["url-filter": "https://illuminate-internal-dummy-rule-to-prevent-error-6.com"],
                "action": ["type": "block"]
            ])
        }

        let json = Self.serialize(rulesArray)
    #if DEBUG
        debug_lastGeneratedDynamicJSON = json
    #endif
        return json
    }

    private static func domainAnchoredPattern(for host: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: host.lowercased())
        return ".*\(escaped).*"
    }

    private static func allowRule(for domain: String) -> [String: Any] {
        [
            "trigger": [
                "url-filter": domainAnchoredPattern(for: domain),
                "url-filter-is-case-sensitive": false
            ],
            "action": ["type": "ignore-previous-rules"]
        ]
    }

    private static func blockRule(urlFilter: String, thirdPartyOnly: Bool = false) -> [String: Any] {
        var trigger: [String: Any] = [
            "url-filter": urlFilter,
            "url-filter-is-case-sensitive": false
        ]
        if thirdPartyOnly {
            trigger["load-type"] = ["third-party"]
        }
        return ["trigger": trigger, "action": ["type": "block"]]
    }

    private static func serialize(_ rulesArray: [[String: Any]]) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: rulesArray, options: []),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    // not good that its hard coded
    // this will have to work for now
    private static let supplementaryAdDomains: [String] = [
        "doubleclick.net",
        "stats.g.doubleclick.net",
        "ad.doubleclick.net",
        "static.doubleclick.net",
        "m.doubleclick.net",
        "mediavisor.doubleclick.net",
        "googlesyndication.com",
        "pagead2.googlesyndication.com",
        "afs.googlesyndication.com",
        "googleadservices.com",
        "pagead2.googleadservices.com",
        "adservice.google.com",
        "googletagservices.com",
        "amazon-adsystem.com",
        "adtago.s3.amazonaws.com",
        "analyticsengine.s3.amazonaws.com",
        "analytics.s3.amazonaws.com",
        "advice-ads.s3.amazonaws.com",
        "media.net",
        "static.media.net",
        "adservetx.media.net",
        "adcolony.com",
        "ads30.adcolony.com",
        "adc3-launch.adcolony.com",
        "events3alt.adcolony.com",
        "wd.adcolony.com",
        "google-analytics.com",
        "ssl.google-analytics.com",
        "analytics.google.com",
        "click.googleanalytics.com",
        "mouseflow.com",
        "cdn.mouseflow.com",
        "o2.mouseflow.com",
        "gtm.mouseflow.com",
        "api.mouseflow.com",
        "tools.mouseflow.com",
        "cdn-test.mouseflow.com",
        "luckyorange.com",
        "api.luckyorange.com",
        "realtime.luckyorange.com",
        "cdn.luckyorange.com",
        "w1.luckyorange.com",
        "upload.luckyorange.net",
        "cs.luckyorange.net",
        "settings.luckyorange.net",
        "hotjar.com",
        "adm.hotjar.com",
        "identify.hotjar.com",
        "insights.hotjar.com",
        "script.hotjar.com",
        "surveys.hotjar.com",
        "careers.hotjar.com",
        "events.hotjar.io",
        "freshmarketer.com",
        "claritybt.freshmarketer.com",
        "fwtracks.freshmarketer.com",
        "stats.wp.com",
        "notify.bugsnag.com",
        "sessions.bugsnag.com",
        "api.bugsnag.com",
        "app.bugsnag.com",
        "browser.sentry-cdn.com",
        "app.getsentry.com",
        "pixel.facebook.com",
        "an.facebook.com",
        "ads.linkedin.com",
        "analytics.pointdrive.linkedin.com",
        "events.reddit.com",
        "events.redditmedia.com",
        "ads-api.tiktok.com",
        "analytics.tiktok.com",
        "ads-sg.tiktok.com",
        "analytics-sg.tiktok.com",
        "business-api.tiktok.com",
        "ads.tiktok.com",
        "log.byteoversea.com",
        "static.ads-twitter.com",
        "ads-api.twitter.com",
        "ads.pinterest.com",
        "log.pinterest.com",
        "trk.pinterest.com",
        "ads.youtube.com",
        "ads.yahoo.com",
        "analytics.yahoo.com",
        "geo.yahoo.com",
        "udcm.yahoo.com",
        "analytics.query.yahoo.com",
        "partnerads.ysm.yahoo.com",
        "log.fc.yahoo.com",
        "gemini.yahoo.com",
        "adtech.yahooinc.com",
        "auction.unityads.unity3d.com",
        "webview.unityads.unity3d.com",
        "config.unityads.unity3d.com",
        "adserver.unityads.unity3d.com",
        "extmaps-api.yandex.net",
        "appmetrica.yandex.ru",
        "adfstat.yandex.ru",
        "metrika.yandex.ru",
        "offerwall.yandex.net",
        "adfox.yandex.ru",
        "iot-eu-logser.realme.com",
        "iot-logser.realme.com",
        "bdapi-ads.realmemobile.com",
        "bdapi-in-ads.realmemobile.com",
        "adsfs.oppomobile.com",
        "adx.ads.oppomobile.com",
        "ck.ads.oppomobile.com",
        "data.ads.oppomobile.com",
        "click.oneplus.cn",
        "iadsdk.apple.com",
        "metrics.icloud.com",
        "metrics.mzstatic.com",
        "api-adservices.apple.com",
        "books-analytics-events.apple.com",
        "weather-analytics-events.apple.com",
        "notes-analytics-events.apple.com",
        "api.ad.xiaomi.com",
        "data.mistat.xiaomi.com",
        "data.mistat.india.xiaomi.com",
        "data.mistat.rus.xiaomi.com",
        "sdkconfig.ad.xiaomi.com",
        "sdkconfig.ad.intl.xiaomi.com",
        "tracking.rus.miui.com",
        "metrics.data.hicloud.com",
        "metrics2.data.hicloud.com",
        "grs.hicloud.com",
        "logservice.hicloud.com",
        "logservice1.hicloud.com",
        "logbak.hicloud.com",
        "samsungads.com",
        "smetrics.samsung.com",
        "nmetrics.samsung.com",
        "samsung-com.112.2o7.net",
        "analytics-api.samsunghealthcn.com",
        "adnxs.com",
        "criteo.com",
        "taboola.com",
        "outbrain.com",
        "pubmatic.com",
        "rubiconproject.com",
        "casalemedia.com",
        "moatads.com",
        "adsafeprotected.com",
        "smartadserver.com",
        "advertising.com"
    ]

    private static let supplementaryAdScriptRules: [[String: Any]] = [
        blockRule(urlFilter: ".*[/. ]ads\\.js.*"),
        blockRule(urlFilter: ".*[/. ]pagead\\.js.*"),
        blockRule(urlFilter: ".*[/. ]adsbygoogle\\.js.*"),
        blockRule(urlFilter: ".*[/. ]show_ads_impl.*\\.js.*")
    ]

    private static let youTubeAdRequestRules: [[String: Any]] = [
        blockRule(urlFilter: ".*youtube\\.com/pagead/"),
        blockRule(urlFilter: ".*youtube\\.com/ptracking"),
        blockRule(urlFilter: ".*youtube\\.com/api/stats/ads"),
        blockRule(urlFilter: ".*s\\.youtube\\.com/api/stats/ads"),
        blockRule(urlFilter: ".*youtube\\.com/get_midroll_")
    ]

    private static let youTubeCosmeticRule: [String: Any] = [
        "trigger": [
            "url-filter": ".*",
            "if-domain": ["*youtube.com"]
        ],
        "action": [
            "type": "css-display-none",
            "selector": ".video-ads, .ytp-ad-overlay-container, .ytp-ad-image-overlay, "
                + "ytd-display-ad-renderer, ytd-promoted-sparkles-web-renderer, ytd-promoted-video-renderer, "
                + "ytd-in-feed-ad-layout-renderer, ytd-ad-slot-renderer, ytd-companion-slot-renderer, "
                + "#player-ads, #masthead-ad"
        ]
    ]

    private static let genericAdCosmeticRule: [String: Any] = [
        "trigger": ["url-filter": ".*"],
        "action": [
            "type": "css-display-none",
            "selector": "ins.adsbygoogle, iframe[id^='google_ads_iframe'], div[id^='div-gpt-ad']"
        ]
    ]


    private static let adBlockTestCosmeticRule: [String: Any] = [
        "trigger": ["url-filter": ".*"],
        "action": [
            "type": "css-display-none",
            "selector": ".ad, .ads, .adsbox, .adbox, .ad-banner, .ad-banner-container, "
                + ".banner-ad, .text-ad, .advertisement, #ad, #ads, #ad-banner, #adblock-test-ad"
        ]
    ]


    private func loadDefaultRules() {
        allowlistedHosts = Set(["browserbench.org"]).union(CaptchaCompatibility.providerDomains)
    }

    private func scopedKey(_ key: String) -> String {
        guard let activeProfileID else { return key }
        return "profile.\(activeProfileID.uuidString).\(key)"
    }

    private func scopedDynamicRuleListIdentifier() -> String {
        guard let activeProfileID else { return baseRuleListIdentifier }
        return "\(baseRuleListIdentifier).\(activeProfileID.uuidString)"
    }
}