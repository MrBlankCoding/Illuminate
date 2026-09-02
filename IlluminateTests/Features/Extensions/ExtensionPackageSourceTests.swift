//
//  ExtensionPackageSourceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

struct ExtensionPackageSourceTests {
    @Test func githubReleaseSourcePreservesRepositoryAndAssetFilter() throws {
        let source = ExtensionPackageSource.githubRelease(
            repository: "owner/repository",
            assetNameContains: "safari"
        )

        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ExtensionPackageSource.self, from: data)

        #expect(decoded == source)
        #expect(decoded.hashValue == source.hashValue)
    }

    @Test func differentGitHubReleaseSourcesAreNotEqual() {
        let first = ExtensionPackageSource.githubRelease(
            repository: "owner/one",
            assetNameContains: "browser"
        )
        let second = ExtensionPackageSource.githubRelease(
            repository: "owner/two",
            assetNameContains: "browser"
        )

        #expect(first != second)
    }

    @Test func sourceCanBeUsedAsDictionaryKey() {
        let source = ExtensionPackageSource.githubRelease(
            repository: "owner/repository",
            assetNameContains: "extension"
        )
        var versions: [ExtensionPackageSource: String] = [:]
        versions[source] = "1.2.3"

        #expect(versions[source] == "1.2.3")
    }
}
