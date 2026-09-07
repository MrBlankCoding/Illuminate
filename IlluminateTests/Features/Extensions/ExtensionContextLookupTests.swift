//
//  ExtensionContextLookupTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

struct ExtensionContextLookupTests {

    @Test("parseExtensionID extracts the ID from a webkit-extension URL")
    func parseExtensionIDBasic() {
        let url = URL(string: "webkit-extension://my-ext/dashboard/dashboard.html")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "my-ext")
    }

    @Test("parseExtensionID handles UUID-style identifiers")
    func parseExtensionIDUUIDStyle() {
        let url = URL(string: "webkit-extension://7b649fcb-1c73-426e-99de-3ea5a996056d/dashboard/dashboard.html")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "7b649fcb-1c73-426e-99de-3ea5a996056d")
    }

    @Test("parseExtensionID handles bundle-identifier-style IDs")
    func parseExtensionIDBundleIdentifier() {
        let url = URL(string: "webkit-extension://com.example.MyExtension/icon.png")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "com.example.MyExtension")
    }

    @Test("parseExtensionID returns nil for non-webkit-extension schemes")
    func parseExtensionIDRejectsOtherSchemes() {
        let urls = [
            URL(string: "https://example.com/path")!,
            URL(string: "http://localhost:8080/")!,
            URL(string: "file:///icon.png")!,
            URL(string: "about:blank")!,
        ]
        for url in urls {
            #expect(ExtensionManager.parseExtensionID(from: url) == nil)
        }
    }

    @Test("parseExtensionID extracts ID even without a path component")
    func parseExtensionIDNoPath() {
        let url = URL(string: "webkit-extension://my-ext")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "my-ext")
    }

    @Test("parseExtensionID returns nil for URL with only the bare scheme")
    func parseExtensionIDBareScheme() {
        // "webkit-extension://" with no host → no slash after host → nil
        let url = URL(string: "webkit-extension://")!
        #expect(ExtensionManager.parseExtensionID(from: url) == nil)
    }

    @Test("parseExtensionID preserves case in the ID")
    func parseExtensionIDCasePreserved() {
        let url = URL(string: "webkit-extension://My-Extension-Name/dashboard/dashboard.html")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "My-Extension-Name")
    }

    @Test("parseExtensionID handles IDs with special characters")
    func parseExtensionIDSpecialChars() {
        let url = URL(string: "webkit-extension://com.example.extension_v2/dashboard.html")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "com.example.extension_v2")
    }

    @Test("parseExtensionID returns only the ID, not the path")
    func parseExtensionIDOnlyIDNoPath() {
        let url = URL(string: "webkit-extension://ext/page/sub/deep.html")!
        #expect(ExtensionManager.parseExtensionID(from: url) == "ext")
    }
}
