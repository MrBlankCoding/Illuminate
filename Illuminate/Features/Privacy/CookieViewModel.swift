//
//  CookieViewModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import SwiftUI
import WebKit
import Observation

@Observable
final class CookieViewModel {
    var cookies: [HTTPCookie] = []
    var searchText = ""
    var isLoading = true
    var currentDomain: String?

    init(domain: String? = nil) {
        self.currentDomain = domain
    }

    var filteredCookies: [HTTPCookie] {
        let domainFiltered: [HTTPCookie]
        if let domain = currentDomain?.lowercased() {
            domainFiltered = cookies.filter { $0.domain.lowercased().contains(domain) || domain.contains($0.domain.lowercased()) }
        } else {
            domainFiltered = cookies
        }

        if searchText.isEmpty {
            return domainFiltered
        } else {
            return domainFiltered.filter { 
                $0.domain.lowercased().contains(searchText.lowercased()) || 
                $0.name.lowercased().contains(searchText.lowercased()) 
            }
        }
    }

    func clearAllCookies(with manager: WebKitManager) {
        let dataStore = manager.activeWebsiteDataStore()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: dateFrom) { [weak self] in
            self?.fetchCookies(with: manager)
        }
    }

    var groupedCookies: [String: [HTTPCookie]] {
        Dictionary(grouping: filteredCookies, by: { $0.domain })
    }

    var sortedDomains: [String] {
        groupedCookies.keys.sorted()
    }

    func fetchCookies(with manager: WebKitManager) {
        isLoading = true
        manager.activeWebsiteDataStore().httpCookieStore.getAllCookies { fetchedCookies in
            DispatchQueue.main.async {
                self.cookies = fetchedCookies
                self.isLoading = false
            }
        }
    }

    func deleteCookie(_ cookie: HTTPCookie, with manager: WebKitManager) {
        manager.activeWebsiteDataStore().httpCookieStore.delete(cookie) { [weak self] in
            self?.fetchCookies(with: manager)
        }
    }

    func deleteCookies(for domain: String, with manager: WebKitManager) {
        let cookiesToDelete = cookies.filter { $0.domain == domain }
        let group = DispatchGroup()
        
        for cookie in cookiesToDelete {
            group.enter()
            manager.activeWebsiteDataStore().httpCookieStore.delete(cookie) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.fetchCookies(with: manager)
        }
    }
}
