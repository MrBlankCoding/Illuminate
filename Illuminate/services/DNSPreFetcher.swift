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
    
    private let queue = DispatchQueue(label: "illuminate.dns.prefetch", qos: .utility)
    
    private init() {}
    
    func prefetchLinks(in webView: WKWebView?) {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            try {
                // Limit to first 100 links to avoid performance issues on huge pages
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
    
    private func resolveHosts(_ hosts: [String]) async {
        let uniqueHosts = Array(Set(hosts))
        
        // Parallelize resolution using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for host in uniqueHosts {
                group.addTask(priority: .background) {
                    self.resolve(host: host)
                }
            }
        }
    }
    
    // doesnt need to be run on the main actor
    nonisolated private func resolve(host: String) {
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
}

