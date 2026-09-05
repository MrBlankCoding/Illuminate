//
//  FinderRevealNoOpTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 4/8/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct FinderRevealNoOpTests {

    @Test func revealWithMissingFileAndParentIsSafeNoOp() {
        let missing = URL(fileURLWithPath: "/nonexistent-illuminate-test/\(UUID().uuidString).pdf")
        FinderReveal.reveal(missing)
    }

    @Test func openWithMissingFileIsSafeNoOp() {
        let missing = URL(fileURLWithPath: "/nonexistent-illuminate-test/\(UUID().uuidString)-2.bin")
        FinderReveal.open(missing)
    }

    @Test func existingTempFileRevealDoesNotThrow() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("illuminate-reveal-\(UUID().uuidString).txt")
        try? Data("probe".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        FinderReveal.reveal(url)
        FinderReveal.open(url)
    }
}
