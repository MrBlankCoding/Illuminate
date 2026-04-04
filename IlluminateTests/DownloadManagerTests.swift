//
//  DownloadManagerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

@Suite(.serialized)
@MainActor
struct DownloadManagerTests {
    @Test func testStartDownloadCreatesTrackedItem() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()
        manager.setSafeDownloadsOnly(true)

        let url = URL(string: "https://example.com/files/report.pdf")!
        manager.startDownload(from: url)

        try await Task.sleep(nanoseconds: 100_000_000)

        let task = try #require(manager.downloads.first)
        #expect(task.url == url)
        #expect(task.filename == "report.pdf")
        #expect(task.state == .preparing || task.state == .downloading)

        manager.cancelDownload(id: task.id)
    }

    @Test func testSaveDownloadedDataWritesFileAndCompletesTask() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()
        manager.setSafeDownloadsOnly(true)

        let data = Data("hello".utf8)
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        manager.saveDownloadedData(
            data,
            from: URL(string: "https://example.com/file.txt"),
            to: destinationURL
        )

        try await Task.sleep(nanoseconds: 250_000_000)

        let savedData = try Data(contentsOf: destinationURL)
        let task = try #require(manager.downloads.first { $0.destinationURL == destinationURL })

        #expect(savedData == data)
        #expect(task.isCompleted == true)
        #expect(task.state == .completed)

        try? FileManager.default.removeItem(at: destinationURL)
    }

    @Test func testDangerousDownloadsAreBlockedWhenProtectionIsEnabled() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()
        manager.setSafeDownloadsOnly(true)

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dmg")

        manager.saveDownloadedData(
            Data("disk image".utf8),
            from: URL(string: "https://example.com/installer.dmg"),
            to: destinationURL
        )

        try await Task.sleep(nanoseconds: 150_000_000)

        let task = try #require(manager.downloads.first { $0.url.absoluteString == "https://example.com/installer.dmg" })
        #expect(task.state == .blocked)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path) == false)
    }

    @Test func testDangerousDownloadsCanProceedWhenProtectionIsDisabled() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()
        manager.setSafeDownloadsOnly(false)

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dmg")
        let data = Data("disk image".utf8)

        manager.saveDownloadedData(
            data,
            from: URL(string: "https://example.com/installer.dmg"),
            to: destinationURL
        )

        try await Task.sleep(nanoseconds: 250_000_000)

        let task = try #require(manager.downloads.first { $0.destinationURL == destinationURL })
        let savedData = try Data(contentsOf: destinationURL)

        #expect(task.state == .completed)
        #expect(savedData == data)

        try? FileManager.default.removeItem(at: destinationURL)
    }

    @Test func testSanitizesExplicitDestinationAndAvoidsOverwrites() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()
        manager.setSafeDownloadsOnly(true)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let existingURL = directory.appendingPathComponent("unsafe:name.txt")
        try Data("existing".utf8).write(to: existingURL)

        let requestedURL = directory.appendingPathComponent("unsafe:name.txt")
        manager.saveDownloadedData(
            Data("new".utf8),
            from: URL(string: "https://example.com/unsafe:name.txt"),
            to: requestedURL
        )

        try await Task.sleep(nanoseconds: 250_000_000)

        let task = try #require(manager.downloads.first(where: { $0.destinationURL?.deletingLastPathComponent() == directory }))
        let finalURL = try #require(task.destinationURL)

        #expect(finalURL.lastPathComponent == "unsafe_name (1).txt")
        #expect((try? Data(contentsOf: existingURL)) == Data("existing".utf8))
        #expect((try? Data(contentsOf: finalURL)) == Data("new".utf8))

        try? FileManager.default.removeItem(at: directory)
    }
}
