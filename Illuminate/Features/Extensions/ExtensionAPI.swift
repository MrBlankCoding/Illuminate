//
//  ExtensionAPI.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import Combine
import Foundation
import WebKit

enum Extensions {}
@MainActor
protocol ExtensionManaging: AnyObject, ObservableObject {
    var installedExtensions: [WKWebExtensionContext] { get }
    var isLoadingExtensions: Bool { get }
    var loadingErrors: [ExtensionManager.ExtensionLoadingError] { get }
    var pinnedExtensions: Set<String> { get }
    var isCheckingForUpdates: Bool { get }
    var activePermissionRequest: Extensions.PermissionPrompt? { get }
    var actionChanges: AnyPublisher<(WKWebExtensionContext, (any WKWebExtensionTab)?), Never> { get }

    func isEnabled(_ context: WKWebExtensionContext) -> Bool
    func isPinned(_ context: WKWebExtensionContext) -> Bool
    func isBundled(_ context: WKWebExtensionContext) -> Bool
    func matchesCatalogItem(_ item: any Extensions.CatalogItem, context: WKWebExtensionContext) -> Bool
    func setEnabled(_ context: WKWebExtensionContext, enabled: Bool)
    func setPinned(_ context: WKWebExtensionContext, pinned: Bool)

    @discardableResult
    func installExtension(
        from url: URL,
        preferredIdentifier: String?,
        initiallyEnabled: Bool,
        source: Extensions.Source?
    ) async throws -> WKWebExtensionContext

    func uninstallExtension(_ context: WKWebExtensionContext)
    func checkForUpdates() async
    func openOptionsPage(for context: WKWebExtensionContext)
    func resolvePermissionRequest(_ prompt: Extensions.PermissionPrompt, granted: Bool)
    func dismissPermissionRequest()
}

extension Extensions {
    protocol CatalogItem: Identifiable {
        var id: String { get }
        var name: String { get }
    }

    typealias Source = ExtensionPackageSource
    struct PermissionPrompt: Identifiable {
        public let id: UUID
        public let extensionName: String?
        public let icon: NSImage?
        public let permissions: Set<WKWebExtension.Permission>?
        public let matchPatterns: Set<WKWebExtension.MatchPattern>?
        public let urls: Set<URL>?
        let resolve: (Bool) -> Void

        init(
            id: UUID,
            extensionName: String?,
            icon: NSImage?,
            permissions: Set<WKWebExtension.Permission>?,
            matchPatterns: Set<WKWebExtension.MatchPattern>?,
            urls: Set<URL>?,
            resolve: @escaping (Bool) -> Void
        ) {
            self.id = id
            self.extensionName = extensionName
            self.icon = icon
            self.permissions = permissions
            self.matchPatterns = matchPatterns
            self.urls = urls
            self.resolve = resolve
        }
    }
}
