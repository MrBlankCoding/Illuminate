//
//  WebScriptBridgeTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Testing
import WebKit
@testable import Illuminate

@MainActor
struct WebScriptBridgeTests {
    @Test func bridgeNamesAndJavaScriptLiteralsAreStable() {
        #expect(BridgeName.allCases.count == 4)
        #expect(BridgeName.metadata.jsAccessor.contains("metadataBridge"))
        #expect(BridgeName.notification.jsAccessor.contains("notificationBridge"))
        #expect(MetadataMessageKind.hover.rawValue == "hover")
        #expect(WebScriptBridge.jsStringLiteral("quote\"slash\\") == "\"quote\\\"slash\\\\\"")
        #expect(WebScriptBridge.jsStringLiteral("value", fallback: "fallback") == "\"value\"")
    }

    @Test func installScriptsHandlesProtectionModesAndRemoval() {
        let controller = WKUserContentController()
        let handler = TestScriptMessageHandler()
        let bridge = WebScriptBridge.shared
        bridge.installScripts(
            on: controller,
            handler: handler,
            colorScheme: "dark",
            canvasFingerprintingProtectionEnabled: true
        )
        #expect(controller.userScripts.count == 7)
        bridge.installScripts(
            on: controller,
            handler: handler,
            colorScheme: "dark",
            canvasFingerprintingProtectionEnabled: true
        )
        #expect(controller.userScripts.count == 7)
        bridge.installScripts(
            on: controller,
            handler: handler,
            colorScheme: "light",
            canvasFingerprintingProtectionEnabled: false
        )
        #expect(controller.userScripts.count == 6)
        bridge.removeAll(from: controller)
        #expect(controller.userScripts.isEmpty)
    }
}

private final class TestScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
