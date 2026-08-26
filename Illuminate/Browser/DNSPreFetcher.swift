//
//  DNSPreFetcher.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import WebKit
import Darwin

@MainActor
final class DNSPreFetcher {
    static let shared = DNSPreFetcher()
    
    private var inFlightHosts = Set<String>()
    private var lastResolvedAt: [String: Date] = [:]
    private let cooldown: TimeInterval = 120
    private let maxResolvedHosts = 512
    
    private init() {}
    
    func prefetchLinks(in webView: WKWebView?) {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            try {
                const anchors = Array.from(document.querySelectorAll('a[href]')).slice(0, 100);
                const urls = anchors.map(a => a.href).filter(Boolean);
                const hosts = Array.from(new Set(urls.map(u => {
                    try {
                        return new URL(u, document.baseURI).hostname;
                    } catch (e) {
                        return null;
                    }
                }).filter(h => h && h !== window.location.hostname)));
                return hosts;
            } catch (e) {
                return [];
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                AppLog.info("DNS prefetch JS error: \(error.localizedDescription)")
                return
            }
            
            guard let hosts = result as? [String], !hosts.isEmpty else { return }
            
            Task {
                await self.resolveHosts(hosts)
            }
        }
    }

    func prefetchHost(_ host: String) {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }

        let now = Date()
        if let lastResolved = lastResolvedAt[normalized], now.timeIntervalSince(lastResolved) < cooldown {
            return
        }
        guard inFlightHosts.insert(normalized).inserted else { return }

        Task.detached(priority: .background) { [normalized] in
            Self.resolve(host: normalized)
            await DNSPreFetcher.shared.markPrefetchComplete(for: normalized)
        }
    }
    
    private func resolveHosts(_ hosts: [String]) async {
        let uniqueHosts = Array(Set(hosts))

        for host in uniqueHosts {
            prefetchHost(host)
        }
    }
    
    // doesnt need to be run on the main actor
    nonisolated private static func resolve(host: String) {
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        var res: UnsafeMutablePointer<addrinfo>?
        let error = getaddrinfo(host, "https", &hints, &res)
        if error == 0, let res = res {
            freeaddrinfo(res)
        }
    }

    private func markPrefetchComplete(for host: String) {
        lastResolvedAt[host] = Date()
        inFlightHosts.remove(host)

        if lastResolvedAt.count > maxResolvedHosts {
            let evictCount = lastResolvedAt.count - maxResolvedHosts
            for (staleHost, _) in lastResolvedAt.sorted(by: { $0.value < $1.value }).prefix(evictCount) {
                lastResolvedAt.removeValue(forKey: staleHost)
            }
        }
    }
}
