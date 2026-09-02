//
//  WebScriptBridge.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import WebKit

enum BridgeName: String, CaseIterable {
    case metadata = "metadataBridge"
    case password = "passwordBridge"
    case permission = "permissionBridge"
    case notification = "notificationBridge"
    var jsAccessor: String {
        "window.webkit.messageHandlers.\(rawValue)"
    }
}

enum MetadataMessageKind: String {
    case hover
    case page
}

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: (any WKScriptMessageHandler)?

    init(_ delegate: some WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

@MainActor
final class WebScriptBridge {

    static let shared = WebScriptBridge()
    private init() {}

    var metadataBridgeName: String { BridgeName.metadata.rawValue }
    var passwordBridgeName: String { BridgeName.password.rawValue }
    var permissionBridgeName: String { BridgeName.permission.rawValue }
    var notificationBridgeName: String { BridgeName.notification.rawValue }
    private struct InstalledConfiguration: Equatable {
        let colorScheme: String
        let canvasFingerprintingProtectionEnabled: Bool
    }

    private let installedConfigurations = NSMapTable<WKUserContentController, NSObject>.weakToStrongObjects()

    func installScripts(
        on contentController: WKUserContentController,
        handler: some WKScriptMessageHandler,
        colorScheme: String,
        canvasFingerprintingProtectionEnabled: Bool
    ) {
        let desired = InstalledConfiguration(
            colorScheme: colorScheme,
            canvasFingerprintingProtectionEnabled: canvasFingerprintingProtectionEnabled
        )

        if let box = installedConfigurations.object(forKey: contentController) as? Box<InstalledConfiguration>,
           box.value == desired {
            return
        }

        removeAll(from: contentController)

        let weakHandler = WeakScriptMessageHandler(handler)
        for bridge in BridgeName.allCases {
            contentController.add(weakHandler, name: bridge.rawValue)
        }

        for script in allScripts(
            colorScheme: colorScheme,
            canvasFingerprintingProtectionEnabled: canvasFingerprintingProtectionEnabled
        ) {
            contentController.addUserScript(script)
        }

        installedConfigurations.setObject(Box(desired), forKey: contentController)
    }

    func removeAll(from contentController: WKUserContentController) {
        contentController.removeAllUserScripts()
        for bridge in BridgeName.allCases {
            contentController.removeScriptMessageHandler(forName: bridge.rawValue)
        }
        installedConfigurations.removeObject(forKey: contentController)
    }

    private func allScripts(
        colorScheme: String,
        canvasFingerprintingProtectionEnabled: Bool
    ) -> [WKUserScript] {
        var scripts = [
            hoverTrackingScript(),
            passwordScript(colorScheme: colorScheme),
            locationPermissionScript(),
            notificationScript(),
            metadataExtractionScript()
        ]
        if canvasFingerprintingProtectionEnabled {
            scripts.append(canvasFingerprintingProtectionScript())
        }
        return scripts
    }

    static func jsStringLiteral(_ value: String, fallback: String = "\"\"") -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8)
        else {
            return fallback
        }
        return literal
    }

}

private final class Box<Value>: NSObject {
    let value: Value
    init(_ value: Value) { self.value = value }
}
