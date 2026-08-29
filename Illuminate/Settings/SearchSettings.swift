//
//  SearchSettings.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/29/26.
//

import Foundation

enum SearchEngine: String, CaseIterable, Identifiable, Codable {
    case google = "google"
    case bing = "bing"
    case duckDuckGo = "duckduckgo"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .duckDuckGo: return "DuckDuckGo"
        }
    }

    var searchURL: String {
        switch self {
        case .google: return "https://www.google.com/search"
        case .bing: return "https://www.bing.com/search"
        case .duckDuckGo: return "https://duckduckgo.com/"
        }
    }

    var queryParameterName: String {
        switch self {
        case .google, .bing, .duckDuckGo: return "q"
        }
    }

    func searchURL(for query: String) -> URL? {
        var components = URLComponents(string: searchURL)
        components?.queryItems = [URLQueryItem(name: queryParameterName, value: query)]
        return components?.url
    }

    var suggestionURL: String {
        switch self {
        case .google:
            return "https://suggestqueries.google.com/complete/search?client=chrome&q="
        case .bing:
            return "https://api.bing.com/osjson.aspx?query="
        case .duckDuckGo:
            return "https://duckduckgo.com/ac/?q="
        }
    }

    func suggestionURL(for query: String) -> URL? {
        guard let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "\(suggestionURL)\(escaped)")
    }
}
