//
//  DownloadTaskStateTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

struct DownloadTaskStateTests {
    private func makeTask(state: DownloadState, resumeData: Data? = nil) -> DownloadTask {
        DownloadTask(
            id: UUID(),
            url: URL(string: "https://example.com/archive.zip")!,
            filename: "archive.zip",
            progress: state == .completed ? 1 : 0,
            state: state,
            errorDescription: nil,
            destinationURL: nil,
            bytesWritten: 0,
            totalBytesExpected: nil,
            createdAt: Date(),
            finishedAt: nil,
            resumeData: resumeData,
            resumeRequiresWebKit: false
        )
    }

    @Test func preparingAndDownloadingAreActiveStates() {
        #expect(makeTask(state: .preparing).isActive)
        #expect(makeTask(state: .downloading).isActive)
        #expect(!makeTask(state: .completed).isActive)
        #expect(!makeTask(state: .cancelled).isActive)
    }

    @Test func onlyFailedTasksWithResumeDataCanResume() {
        #expect(!makeTask(state: .failed).canResume)
        #expect(makeTask(state: .failed, resumeData: Data([1, 2, 3])).canResume)
        #expect(!makeTask(state: .completed, resumeData: Data([1])).canResume)
    }

    @Test func failedStatusUsesErrorOrFallbackDescription() {
        var task = makeTask(state: .failed)
        #expect(task.statusDescription == "Download failed")

        task.errorDescription = "Network connection lost"
        #expect(task.statusDescription == "Network connection lost")
    }
}
