//
//  FinderRevealNoOpTests.swift
//  IlluminateTests
//
//  Exercises the guard paths that must not touch NSWorkspace:
//  a missing file whose parent folder is also missing is a pure no-op.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct FinderRevealNoOpTests {

    @Test func revealWithMissingFileAndParentIsSafeNoOp() {
        let missing = URL(fileURLWithPath: "/nonexistent-illuminate-test/\(UUID().uuidString).pdf")
        // Must not crash or open Finder — the parent doesn't exist either.
        FinderReveal.reveal(missing)
    }

    @Test func openWithMissingFileIsSafeNoOp() {
        let missing = URL(fileURLWithPath: "/nonexistent-illuminate-test/\(UUID().uuidString)-2.bin")
        FinderReveal.open(missing)
    }

    @Test func existingTempFileRevealDoesNotThrow() {
        // Reveal on an existing file exercises the security-scope + activate
        // path; activateFileViewerSelecting is fire-and-forget and safe in tests.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("illuminate-reveal-\(UUID().uuidString).txt")
        try? Data("probe".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        FinderReveal.reveal(url)
        FinderReveal.open(url)
    }
}
