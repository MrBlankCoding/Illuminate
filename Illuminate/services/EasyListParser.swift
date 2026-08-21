//
//  EasyListParser.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/18/26.
//

import Foundation

final class EasyListParser {

    private static let supportedResourceTypes: Set<String> = [
        "document",
        "font",
        "image",
        "media",
        "ping",
        "popup",
        "raw",
        "script",
        "style-sheet"
    ]

    private static let typeMap: [String: String] = [
        "font": "font",
        "image": "image",
        "media": "media",
        "other": "raw",
        "ping": "ping",
        "popup": "popup",
        "script": "script",
        "stylesheet": "style-sheet",
        "subdocument": "document",
        "websocket": "raw",
        "xmlhttprequest": "raw"
    ]

    static func parse(content: String, limit: Int = 120_000) -> String {
        var rules: [Rule] = []

        for rawLine in content.components(separatedBy: .newlines) {
            guard rules.count < limit else { break }

            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty,
                  !trimmedLine.hasPrefix("!"),
                  !trimmedLine.hasPrefix("[Adblock") else {
                continue
            }

            guard !trimmedLine.hasPrefix("@@") else {
                continue
            }

            if let rule = makeElementHidingRule(from: trimmedLine) {
                rules.append(rule)
                continue
            }

            guard let rule = makeBlockingRule(from: trimmedLine) else {
                continue
            }

            rules.append(rule)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        guard let data = try? encoder.encode(rules),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }

    private static func makeElementHidingRule(from line: String) -> Rule? {
        let separator: String
        if line.contains("#@#") {
            return nil
        } else if line.contains("##") {
            separator = "##"
        } else {
            return nil
        }

        let parts = line.components(separatedBy: separator)
        guard parts.count == 2 else {
            return nil
        }

        let domainText = parts[0]
        let selector = parts[1].trimmingCharacters(in: .whitespaces)
        guard !selector.isEmpty else {
            return nil
        }

        let domains = domainText
            .components(separatedBy: ",")
            .map { normalizedDomain($0) }
            .filter { !$0.isEmpty }

        let splitDomains = splitDomains(domains)
        let trigger = Trigger(
            urlFilter: ".*",
            ifDomain: splitDomains.ifDomains,
            unlessDomain: splitDomains.unlessDomains
        )

        return Rule(
            trigger: trigger,
            action: .cssDisplayNone(selector: selector)
        )
    }

    private static func makeBlockingRule(from line: String) -> Rule? {
        let parts = line.components(separatedBy: "$")
        guard let filter = parts.first?.trimmingCharacters(in: .whitespaces),
              !filter.isEmpty else {
            return nil
        }

        var loadTypes: [String]?
        var includedResourceTypes = Set<String>()
        var excludedResourceTypes = Set<String>()

        if parts.count > 1 {
            let options = parts[1].components(separatedBy: ",")

            for option in options {
                let trimmedOption = option.trimmingCharacters(in: .whitespaces)
                guard !trimmedOption.isEmpty else {
                    continue
                }

                switch true {
                case trimmedOption == "third-party":
                    loadTypes = ["third-party"]
                case trimmedOption == "first-party":
                    loadTypes = ["first-party"]
                case trimmedOption.hasPrefix("domain="):
                    continue
                default:
                    let isExclusion = trimmedOption.hasPrefix("~")
                    let normalizedOption = isExclusion
                        ? String(trimmedOption.dropFirst())
                        : trimmedOption

                    guard let safariType = typeMap[normalizedOption] else {
                        continue
                    }

                    if isExclusion {
                        excludedResourceTypes.insert(safariType)
                    } else {
                        includedResourceTypes.insert(safariType)
                    }
                }
            }
        }

        let resourceTypes: [String]?
        if !includedResourceTypes.isEmpty {
            resourceTypes = includedResourceTypes.sorted()
        } else if !excludedResourceTypes.isEmpty {
            let translatedTypes = supportedResourceTypes.subtracting(excludedResourceTypes)
            resourceTypes = translatedTypes.isEmpty ? nil : translatedTypes.sorted()
        } else {
            resourceTypes = nil
        }

        let trigger = Trigger(
            urlFilter: convertToRegex(filter),
            ifDomain: nil,
            unlessDomain: nil,
            resourceType: resourceTypes,
            loadType: loadTypes
        )

        return Rule(trigger: trigger, action: .block)
    }

    private static func splitDomains(_ domains: [String]) -> (ifDomains: [String]?, unlessDomains: [String]?) {
        var ifDomains: [String] = []
        var unlessDomains: [String] = []

        for domain in domains {
            if domain.hasPrefix("~") {
                let normalized = normalizedDomain(String(domain.dropFirst()))
                if !normalized.isEmpty {
                    unlessDomains.append(normalized)
                }
            } else {
                let normalized = normalizedDomain(domain)
                if !normalized.isEmpty {
                    ifDomains.append(normalized)
                }
            }
        }

        if !ifDomains.isEmpty {
            return (ifDomains, nil)
        } else if !unlessDomains.isEmpty {
            return (nil, unlessDomains)
        } else {
            return (nil, nil)
        }
    }

    private static func normalizedDomain(_ domain: String) -> String {
        domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func convertToRegex(_ filter: String) -> String {
        guard !filter.isEmpty else {
            return ".*"
        }

        if filter.count > 1, filter.hasPrefix("/"), filter.hasSuffix("/") {
            let startIndex = filter.index(after: filter.startIndex)
            let endIndex = filter.index(before: filter.endIndex)
            var regex = String(filter[startIndex..<endIndex])
            
            regex = regex.replacingOccurrences(of: "\\w", with: "[A-Za-z0-9_]")
            regex = regex.replacingOccurrences(of: "\\d", with: "[0-9]")
            regex = regex.replacingOccurrences(of: "\\s", with: "[ \t\r\n\u{000C}]")
            regex = regex.replacingOccurrences(of: "\\{\\d+,\\d*\\}", with: "+", options: .regularExpression)
            regex = regex.replacingOccurrences(of: "\\{\\d+\\}", with: "+", options: .regularExpression)

            return regex
        }

        var pattern = filter
        var isAnchoredAtStart = false
        var isAnchoredAtEnd = false
        var matchesHostnameBoundary = false

        if pattern.hasPrefix("||") {
            matchesHostnameBoundary = true
            pattern.removeFirst(2)
        } else if pattern.hasPrefix("|") {
            isAnchoredAtStart = true
            pattern.removeFirst()
        }

        if pattern.hasSuffix("|") {
            isAnchoredAtEnd = true
            pattern.removeLast()
        }

        let translatedPattern = translatePattern(pattern)

        if matchesHostnameBoundary {
            let prefix = "^[^:]+:(//)?([^/]+\\.)?"
            return prefix + translatedPattern + (isAnchoredAtEnd ? "$" : "")
        }

        let startAnchor = isAnchoredAtStart ? "^" : ""
        let endAnchor = isAnchoredAtEnd ? "$" : ""
        return startAnchor + translatedPattern + endAnchor
    }

    private static func translatePattern(_ pattern: String) -> String {
        let hostnameBoundaryClass = "[^A-Za-z0-9._%-]"
        var translated = ""

        for character in pattern {
            switch character {
            case "*":
                translated += ".*"
            case "^":
                translated += hostnameBoundaryClass
            default:
                translated += escapedRegexLiteral(for: character)
            }
        }

        return translated
    }

    private static func escapedRegexLiteral(for character: Character) -> String {
        let scalar = String(character)
        switch character {
        case "\\", ".", "+", "?", "(", ")", "[", "]", "{", "}", "|", "$":
            return "\\" + scalar
        default:
            return scalar
        }
    }
}

private struct Rule: Encodable {
    let trigger: Trigger
    let action: Action
}

private struct Trigger: Encodable {
    let urlFilter: String
    let ifDomain: [String]?
    let unlessDomain: [String]?
    let resourceType: [String]?
    let loadType: [String]?
    let urlFilterIsCaseSensitive = false

    init(
        urlFilter: String,
        ifDomain: [String]? = nil,
        unlessDomain: [String]? = nil,
        resourceType: [String]? = nil,
        loadType: [String]? = nil
    ) {
        self.urlFilter = urlFilter
        self.ifDomain = ifDomain
        self.unlessDomain = unlessDomain
        self.resourceType = resourceType
        self.loadType = loadType
    }

    enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
        case ifDomain = "if-domain"
        case unlessDomain = "unless-domain"
        case resourceType = "resource-type"
        case loadType = "load-type"
        case urlFilterIsCaseSensitive = "url-filter-is-case-sensitive"
    }
}

private struct Action: Encodable {
    let type: String
    let selector: String?

    static let block = Action(type: "block", selector: nil)

    static func cssDisplayNone(selector: String) -> Action {
        Action(type: "css-display-none", selector: selector)
    }
}
