//
//  DownloadManagerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Testing
import Foundation
@testable import Illuminate

@MainActor
struct DownloadManagerTests {

    @Test func testDownloadTaskCreation() async throws {
        let manager = DownloadManager.shared
        manager.clearDownloads()
        let url = URL(string: "https://raw.githubusercontent.com/LierB/dotfiles/master/wallpapers/moody-flowers.png")!
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("moody-flowers.png")
        
        manager.startDownload(from: url, to: destination)
        
        #expect(manager.downloads.count == 1, "Download task should be added")
        
        let task = manager.downloads.first { $0.url == url }
        #expect(task != nil, "Task should exist")
        #expect(task?.filename == "moody-flowers.png", "Filename should match destination")
        
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        let updatedTask = manager.downloads.first { $0.url == url }
        if let updatedTask = updatedTask {
            #expect(updatedTask.isCompleted == true || updatedTask.isFailed == true, "Download should have reached terminal state")
        }
    }

    @Test func testDownloadTaskWithSuggestedFilename() async throws {
        let manager = DownloadManager.shared
        manager.clearDownloads()
        
        let url = URL(string: "https://example.com/custom.pdf")!
        
        manager.startDownload(from: url, suggestedFilename: "custom-name.pdf")
        
        #expect(manager.downloads.count == 1, "Download task should be added")
        
        let task = manager.downloads.first { $0.url == url }
        #expect(task?.filename == "custom-name.pdf", "Should use suggested filename")
    }

    @Test func testDownloadTaskDefaultFilename() async throws {
        let manager = DownloadManager.shared
        manager.clearDownloads()
        
        let url = URL(string: "https://example.com/myfile.dmg")!
        
        manager.startDownload(from: url)
        
        #expect(manager.downloads.count == 1, "Download task should be added")
        
        let task = manager.downloads.first { $0.url == url }
        #expect(task?.filename == "myfile.dmg", "Should extract filename from URL path")
    }

    @Test func testDownloadTaskFallsBackWhenSuggestedFilenameIsEmpty() async throws {
        let manager = DownloadManager.shared
        manager.clearDownloads()

        let url = URL(string: "https://example.com/")!

        manager.startDownload(from: url, suggestedFilename: "")

        #expect(manager.downloads.count == 1, "Download task should be added")

        let task = manager.downloads.first { $0.url == url }
        #expect(task?.filename == "download", "Should fall back to a safe default filename")
    }
}
