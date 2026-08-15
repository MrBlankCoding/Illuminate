//
//  PerformanceBenchmarks.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//


import Foundation
import XCTest
@testable import Illuminate

final class PerformanceBenchmarks: XCTestCase {

    @discardableResult
    private func bench<T>(
        _ name: String,
        iterations: Int = 1000,
        warmup: Int = 10,
        file: StaticString = #file,
        line: UInt = #line,
        _ body: () throws -> T
    ) rethrows -> (mean: Double, median: Double, p95: Double, count: Int) {
        for _ in 0..<warmup { _ = try body() }

        var times: [Double] = []
        times.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            _ = try body()
            let end = CFAbsoluteTimeGetCurrent()
            times.append(end - start)
        }

        times.sort()
        let total = times.reduce(0.0, +)
        let mean = total / Double(times.count)
        let median = times[times.count / 2]
        let p95Index = max(0, Int(Double(times.count) * 0.95) - 1)
        let p95 = times[p95Index]

        let nsPerOp = mean * 1_000_000_000
        print(String(
            format: "[BENCH] %-40@  n=%-6lld  mean=%.1lfns  median=%.1lfns  p95=%.1lfns",
            name, iterations, nsPerOp, median * 1_000_000_000, p95 * 1_000_000_000
        ))

        return (mean, median, p95, times.count)
    }


    func testFaviconCacheLRUTouch() throws {
        let cache = FaviconCache(capacity: 128)
        let urls = (0..<128).map { URL(string: "https://site\($0).com/favicon.ico")! }
        let testImage = NSImage(size: NSSize(width: 16, height: 16))

        for (i, url) in urls.enumerated() {
            let fake = NSImage(size: NSSize(width: 16, height: 16))
            cache.performInline_set(fake, for: url)
            if i == 0 { _ = testImage } // suppress unused
        }

        let accessPattern = (0..<1000).map { urls[$0 % urls.count] }

        bench("FaviconCache.image() hot-hit (128-elem LRU)", iterations: 5000) {
            for url in accessPattern {
                _ = cache.image(for: url)
            }
        }
    }

    @MainActor func testTabIDIndexLookup() throws {
        let urlSync = URLSynchronizer()
        let tabMgr = TabManager(
            urlSynchronizer: urlSync,
            isPersistenceEnabled: false
        )

        let tabCount = 50
        var createdIDs: [UUID] = []
        for _ in 0..<tabCount {
            let t = tabMgr.createTab()
            createdIDs.append(t.id)
        }

        bench("TabMgr: tab+index lookup, \(tabCount) tabs (full render pass)", iterations: 200) {
            for tid in createdIDs {
                _ = tabMgr.tabByID(tid)
                _ = tabMgr.indexOfTabByID(tid)
            }
        }
    }

    func testEasyListParserParseLineAllocation() throws {
        var corpus = ""
        for i in 0..<10_000 {
            switch i % 7 {
            case 0: corpus += "||tracker\(i).com^\n"
            case 1: corpus += "! this is a comment line \(i)\n"
            case 2: corpus += "site\(i).com##.banner-ad\n"
            case 3: corpus += "@@||allowed\(i).com^\n"
            case 4: corpus += "||ads\(i).cdn.net/pixel*.png\n"
            case 5: corpus += "[Adblock Plus]\n"
            default: corpus += "||tracking\(i).pixel$image,third-party\n"
            }
        }

        bench("EasyListParser.parse 10K lines", iterations: 50) {
            _ = EasyListParser.parse(content: corpus)
        }
    }


    func testKeyboardShortcutLookup() throws {
        let handler = KeyboardShortcutHandler(notificationCenter: .default)

        bench("Shortcut dispatch ⌘T (hot key)", iterations: 10_000) {
            handler.performInline_handleCharacter("t", modifiers: .command)
        }
        
        bench("Shortcut dispatch ⌘→ (keyCode)", iterations: 10_000) {
            handler.performInline_handleKeyCode(124, modifiers: .command)
        }
    }


    func testFaviconCacheEvictionRate() throws {
        let cache = FaviconCache(capacity: 128)
        let urls = (0..<10_000).map { URL(string: "https://evict\($0).com/favicon.ico")! }

        bench("FaviconCache: 10K inserts (LRU churn, cap=128)", iterations: 10) {
            for url in urls {
                cache.performInline_set(NSImage(size: NSSize(width: 16, height: 16)), for: url)
            }
        }
    }
}

extension TabManager {
    @MainActor func tabByID(_ id: UUID) -> Tab? {
        tab(forID: id)
    }

    @MainActor func indexOfTabByID(_ id: UUID) -> Int? {
        indexOfTab(withID: id)
    }
}

extension KeyboardShortcutHandler {
    nonisolated func performInline_handleCharacter(_ char: String, modifiers: NSEvent.ModifierFlags) {
        _ = lookupShortcutBy(character: char, modifiers: modifiers)
    }

    nonisolated func performInline_handleKeyCode(_ code: UInt16, modifiers: NSEvent.ModifierFlags) {
        _ = lookupShortcutBy(keyCode: code, modifiers: modifiers)
    }
}
