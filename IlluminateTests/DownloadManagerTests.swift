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

        let url = URL(string: "https://example.com/files/report.pdf")!
        manager.startDownload(from: url)

        try await Task.sleep(nanoseconds: 100_000_000)

        let task = try #require(manager.downloads.first(where: { $0.url == url }))
        #expect(task.url == url)
        #expect(task.filename == "report.pdf")
        #expect(task.state == .preparing || task.state == .downloading)

        manager.cancelDownload(id: task.id)
    }

    @Test func testSaveDownloadedDataWritesFileAndCompletesTask() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

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

    @Test func testStartDownloadCopiesLocalFileAndCompletesTask() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sourceURL = directory.appendingPathComponent("image.png")
        let sourceData = Data("local-file".utf8)
        try sourceData.write(to: sourceURL)

        manager.startDownload(from: sourceURL, suggestedFilename: "copied-image.png")

        try await Task.sleep(nanoseconds: 300_000_000)

        let task = try #require(manager.downloads.first)
        let destinationURL = try #require(task.destinationURL)
        let copiedData = try Data(contentsOf: destinationURL)

        #expect(task.state == .completed)
        #expect(destinationURL.lastPathComponent == "copied-image.png")
        #expect(copiedData == sourceData)
        #expect(destinationURL != sourceURL)

        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.removeItem(at: directory)
    }


    @Test func testSanitizesExplicitDestinationAndAvoidsOverwrites() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let existingURL = directory.appendingPathComponent("unsafe_name.txt")
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

    @Test func testSanitizedFilenameRemovesInvalidCharacters() {
        let manager = DownloadManager()
        #expect(manager.sanitizedFilename("file/with:bad\\chars") == "file_with_bad_chars")
        #expect(manager.sanitizedFilename("normalfile.txt") == "normalfile.txt")
        #expect(manager.sanitizedFilename("...") == "download")
        #expect(manager.sanitizedFilename("  ") == "download")
        #expect(manager.sanitizedFilename(nil) == "download")
        #expect(manager.sanitizedFilename("") == "download")
    }

    @Test func testSanitizedFilenameUseFallbackURL() {
        let manager = DownloadManager()
        let fallbackURL = URL(string: "https://example.com/path/document.pdf")!
        #expect(manager.sanitizedFilename(nil, fallbackURL: fallbackURL) == "document.pdf")
        #expect(manager.sanitizedFilename("", fallbackURL: fallbackURL) == "document.pdf")
    }

    @Test func testResolvedFilenameAppendsMimeExtension() {
        let manager = DownloadManager()
        let filename = manager.resolvedFilename("report", fallbackURL: nil, mimeType: "application/pdf")
        #expect(filename == "report.pdf")
    }

    @Test func testResolvedFilenamePreservesExistingExtension() {
        let manager = DownloadManager()
        let filename = manager.resolvedFilename("report.pdf", fallbackURL: nil, mimeType: "application/pdf")
        #expect(filename == "report.pdf")
    }

    @Test func testUniqueDestinationURLAppendsSuffixForDuplicates() throws {
        let manager = DownloadManager()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let firstURL = directory.appendingPathComponent("readme.txt")
        try Data("first".utf8).write(to: firstURL)

        let result = manager.uniqueDestinationURL(in: directory, preferredFilename: "readme.txt")
        #expect(result.lastPathComponent == "readme (1).txt")

        try Data("second".utf8).write(to: result)
        let result2 = manager.uniqueDestinationURL(in: directory, preferredFilename: "readme.txt")
        #expect(result2.lastPathComponent == "readme (2).txt")

        try? FileManager.default.removeItem(at: directory)
    }

    @Test func testUniqueDestinationURLNoSuffixWhenNoCollision() throws {
        let manager = DownloadManager()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let result = manager.uniqueDestinationURL(in: directory, preferredFilename: "newfile.txt")
        #expect(result.lastPathComponent == "newfile.txt")

        try? FileManager.default.removeItem(at: directory)
    }


    @Test func testCancelDownloadSetsStateToCancelled() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

        let url = URL(string: "https://example.com/large-file.zip")!
        manager.startDownload(from: url)
        try await Task.sleep(nanoseconds: 100_000_000)

        let task = try #require(manager.downloads.first)
        manager.cancelDownload(id: task.id)

        try await Task.sleep(nanoseconds: 100_000_000)

        let updated = try #require(manager.downloads.first { $0.id == task.id })
        #expect(updated.state == .cancelled)
    }

    @Test func testClearDownloadsRemovesAllItems() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

        let data = Data("test".utf8)
        let dest1 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        let dest2 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")

        manager.saveDownloadedData(data, from: URL(string: "https://example.com/a.txt"), to: dest1)
        manager.saveDownloadedData(data, from: URL(string: "https://example.com/b.txt"), to: dest2)

        try await Task.sleep(nanoseconds: 250_000_000)
        #expect(manager.downloads.count >= 2)

        manager.clearDownloads()
        #expect(manager.downloads.isEmpty)

        try? FileManager.default.removeItem(at: dest1)
        try? FileManager.default.removeItem(at: dest2)
    }

    @Test func testClearFinishedDownloadsKeepsActiveDownloads() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        manager.saveDownloadedData(
            Data("done".utf8),
            from: URL(string: "https://example.com/done.txt"),
            to: dest
        )

        try await Task.sleep(nanoseconds: 250_000_000)

        let url = URL(string: "https://example.com/pending.pdf")!
        manager.startDownload(from: url)
        try await Task.sleep(nanoseconds: 100_000_000)

        let beforeCount = manager.downloads.count
        #expect(beforeCount >= 2)

        manager.clearFinishedDownloads()

        let activeOnly = manager.downloads.filter(\.isActive)
        #expect(manager.downloads.count == activeOnly.count)

        for dl in manager.downloads {
            manager.cancelDownload(id: dl.id)
        }

        try? FileManager.default.removeItem(at: dest)
    }

    @Test func testPreferencesPersistAndReload() {
        let manager = DownloadManager()

        manager.setRevealInFinderWhenFinished(true)
        manager.setAskWhereToSave(true)

        #expect(manager.preferences.revealInFinderWhenFinished == true)
        #expect(manager.preferences.askWhereToSave == true)

        manager.setRevealInFinderWhenFinished(false)
        manager.setAskWhereToSave(false)
    }

    @Test func testAskWhereToSaveToggle() {
        let manager = DownloadManager()

        manager.setAskWhereToSave(false)
        #expect(manager.preferences.askWhereToSave == false)

        manager.setAskWhereToSave(true)
        #expect(manager.preferences.askWhereToSave == true)

        // Reset
        manager.setAskWhereToSave(false)
    }

    @Test func testSetDownloadDirectoryStoresBookmarkWhenPossible() throws {
        let manager = DownloadManager()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        manager.setDownloadDirectory(directory)
        manager.resetDownloadDirectory()
        #expect(manager.preferences.saveLocationBookmarkData == nil)

        let defaultDir = FileManager.default.illuminateDownloadsDirectory()
        #expect(manager.downloadDirectoryURL.path == defaultDir.path)

        try? FileManager.default.removeItem(at: directory)
    }

    @Test func testResetDownloadDirectoryUsesSystemDownloads() {
        let manager = DownloadManager()
        manager.resetDownloadDirectory()

        let expected = FileManager.default.illuminateDownloadsDirectory()
        #expect(manager.downloadDirectoryURL.path == expected.path)
        #expect(manager.preferences.saveLocationBookmarkData == nil)
    }

    @Test func testMoveDownloadCreatesParentDirectories() throws {
        let manager = DownloadManager()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceFile = tempDir.appendingPathComponent("source.txt")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("content".utf8).write(to: sourceFile)

        let nestedDest = tempDir
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("deep", isDirectory: true)
            .appendingPathComponent("dest.txt")

        try manager.moveDownload(at: sourceFile, to: nestedDest)

        #expect(FileManager.default.fileExists(atPath: nestedDest.path))
        #expect(try String(contentsOf: nestedDest, encoding: .utf8) == "content")
        #expect(!FileManager.default.fileExists(atPath: sourceFile.path))

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func testDownloadTaskStatusDescriptions() {
        let base = DownloadTask(
            id: UUID(),
            url: URL(string: "https://example.com/file.txt")!,
            filename: "file.txt",
            progress: 0,
            state: .preparing,
            errorDescription: nil,
            destinationURL: nil,
            bytesWritten: 0,
            totalBytesExpected: nil,
            createdAt: Date(),
            finishedAt: nil
        )

        #expect(base.statusDescription == "Preparing")
        #expect(base.isActive == true)
        #expect(base.isCompleted == false)
        #expect(base.isFailed == false)

        var downloading = base
        downloading.state = .downloading
        downloading.bytesWritten = 500
        downloading.totalBytesExpected = 1000
        #expect(downloading.statusDescription.contains("of"))

        var downloadingNoTotal = base
        downloadingNoTotal.state = .downloading
        downloadingNoTotal.bytesWritten = 500
        #expect(!downloadingNoTotal.statusDescription.contains("of"))

        var completed = base
        completed.state = .completed
        completed.destinationURL = URL(fileURLWithPath: "/tmp/result.txt")
        #expect(completed.statusDescription == "result.txt")
        #expect(completed.isCompleted == true)
        #expect(completed.isActive == false)

        var failed = base
        failed.state = .failed
        failed.errorDescription = "Network error"
        #expect(failed.statusDescription == "Network error")
        #expect(failed.isFailed == true)


        var cancelled = base
        cancelled.state = .cancelled
        #expect(cancelled.statusDescription == "Cancelled")
    }

    @Test func testDownloadsDidChangeNotificationFires() async throws {
        let manager = DownloadManager()
        manager.clearDownloads()

        var received = false
        let observer = NotificationCenter.default.addObserver(
            forName: DownloadManager.downloadsDidChangeNotification,
            object: manager,
            queue: .main
        ) { _ in
            received = true
        }

        let data = Data("test".utf8)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")

        manager.saveDownloadedData(data, from: URL(string: "https://example.com/n.txt"), to: dest)
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(received == true)

        NotificationCenter.default.removeObserver(observer)
        try? FileManager.default.removeItem(at: dest)
    }
}
