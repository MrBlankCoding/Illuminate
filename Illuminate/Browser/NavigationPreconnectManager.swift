//
//  NavigationPreconnectManager.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/18/26.
//

import Foundation
import WebKit

@MainActor
final class NavigationPreconnectManager {
    static let shared = NavigationPreconnectManager()

    private var lastDNSPrefetchAt: [String: Date] = [:]
    private var lastInjectedAt: [ObjectIdentifier: [String: Date]] = [:]

    private let dnsCooldown: TimeInterval = 20
    private let injectionCooldown: TimeInterval = 5
    private let maxTrackedHosts = 128

    private init() {}

    func preconnect(to url: URL, in webView: WKWebView?) {
        guard
            let webView,
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host?.lowercased(),
            !host.isEmpty
        else { return }

        let origin = originString(for: url)
        let now = Date()

        throttledDNSPrefetch(host: host, now: now)
        injectPreconnectHintsIfNeeded(origin: origin, host: host, webView: webView, now: now)
    }

    private func throttledDNSPrefetch(host: String, now: Date) {
        if let last = lastDNSPrefetchAt[host], now.timeIntervalSince(last) < dnsCooldown {
            return
        }
        lastDNSPrefetchAt[host] = now
        pruneDNSCacheIfNeeded(now: now)
        DNSPreFetcher.shared.prefetchHost(host)
    }

    private func pruneDNSCacheIfNeeded(now: Date) {
        guard lastDNSPrefetchAt.count > maxTrackedHosts else { return }
        lastDNSPrefetchAt = lastDNSPrefetchAt.filter { now.timeIntervalSince($0.value) < dnsCooldown }
        guard lastDNSPrefetchAt.count > maxTrackedHosts else { return }
        let overflow = lastDNSPrefetchAt.count - maxTrackedHosts
        let oldest = lastDNSPrefetchAt.sorted { $0.value < $1.value }.prefix(overflow).map(\.key)
        oldest.forEach { lastDNSPrefetchAt.removeValue(forKey: $0) }
    }

    private func injectPreconnectHintsIfNeeded(origin: String, host: String, webView: WKWebView, now: Date) {
        let webViewID = ObjectIdentifier(webView)
        if let last = lastInjectedAt[webViewID]?[origin], now.timeIntervalSince(last) < injectionCooldown {
            return
        }
        lastInjectedAt[webViewID, default: [:]][origin] = now
        pruneStaleWebViews(now: now)

        guard let script = preconnectScript(origin: origin, host: host) else { return }
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                AppLog.debug("Preconnect injection failed for \(origin): \(error.localizedDescription)")
            }
        }
    }

    private func pruneStaleWebViews(now: Date) {
        guard lastInjectedAt.count > maxTrackedHosts else { return }
        for (id, origins) in lastInjectedAt {
            let pruned = origins.filter { now.timeIntervalSince($0.value) < injectionCooldown * 4 }
            if pruned.isEmpty {
                lastInjectedAt.removeValue(forKey: id)
            } else {
                lastInjectedAt[id] = pruned
            }
        }
    }

    private func preconnectScript(origin: String, host: String) -> String? {
        guard
            let originJSON = jsonStringLiteral(origin),
            let dnsJSON = jsonStringLiteral("//\(host)")
        else { return nil }

        return """
        (() => {
            const head = document.head || document.documentElement;
            const ensure = (rel, href, crossOrigin) => {
                const key = `${rel}:${href}`;
                let el = head.querySelector(`link[data-illuminate-preconnect="${key}"]`);
                if (!el) {
                    el = document.createElement('link');
                    el.dataset.illuminatePreconnect = key;
                    el.rel = rel;
                    el.href = href;
                    if (crossOrigin) el.crossOrigin = 'anonymous';
                    head.appendChild(el);
                }
            };
            ensure('dns-prefetch', \(dnsJSON), false);
            ensure('preconnect', \(originJSON), true);
        })();
        """
    }

    private func originString(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.string ?? url.absoluteString
    }

    private func jsonStringLiteral(_ string: String) -> String? {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [string]),
            let json = String(data: data, encoding: .utf8)
        else { return nil }
        return String(json.dropFirst().dropLast())
    }
}
