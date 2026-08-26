//
//  DownloadRecordMappingTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Testing
import Foundation
@testable import Illuminate

struct DownloadRecordMappingTests {

    private func makeTask(
        state: DownloadState = .completed,
        destination: URL? = nil,
        error: String? = nil,
        resumeData: Data? = nil
    ) -> DownloadTask {
        DownloadTask(
            id: UUID(),
            url: URL(string: "https://example.com/file.zip")!,
            filename: "file.zip",
            progress: state == .completed ? 1 : 0.5,
            state: state,
            errorDescription: error,
            destinationURL: destination,
            bytesWritten: 512,
            totalBytesExpected: 1024,
            createdAt: Date(),
            finishedAt: state == .completed ? Date() : nil,
            resumeData: resumeData,
            resumeRequiresWebKit: false
        )
    }

    @Test func recordRoundTripsTaskFields() {
        let task = makeTask(destination: URL(fileURLWithPath: "/tmp/file.zip"))
        let record = DownloadRecord(task: task, profileID: nil)

        #expect(record.sourceURL == task.url)
        #expect(record.destinationURL?.path == "/tmp/file.zip")
        #expect(record.stateRawValue == DownloadState.completed.rawValue)
        #expect(record.bytesWritten == 512)
        #expect(record.totalBytesExpected == 1024)
    }

    @Test func applyOverwritesMutableFields() {
        var task = makeTask(state: .downloading)
        let record = DownloadRecord(task: task, profileID: UUID())

        task.state = .completed
        task.filename = "renamed.zip"
        task.bytesWritten = 1024
        task.finishedAt = Date()
        record.apply(task)

        #expect(record.stateRawValue == DownloadState.completed.rawValue)
        #expect(record.filename == "renamed.zip")
        #expect(record.bytesWritten == 1024)
        #expect(record.finishedAt != nil)
    }

    @Test func destinationURLEmptyPathIsNil() {
        let record = DownloadRecord(
            id: UUID(), profileID: nil, sourceURLString: "https://example.com/f.pdf",
            filename: "f.pdf", destinationPathString: "", stateRawValue: "completed",
            createdAt: Date(), finishedAt: nil, bytesWritten: 0,
            totalBytesExpected: nil, errorDescription: nil, resumeData: nil,
            resumeRequiresWebKit: false
        )
        #expect(record.destinationURL == nil)
    }

    @Test func statusDescriptionReflectsStates() {
        var task = makeTask(state: .preparing)
        #expect(task.statusDescription == "Preparing")

        task.state = .downloading
        task.totalBytesExpected = 2048
        task.bytesWritten = 1024
        #expect(task.statusDescription.contains("of"))

        task.state = .cancelled
        #expect(task.statusDescription == "Cancelled")

        task.state = .failed
        task.errorDescription = "disk full"
        #expect(task.statusDescription == "disk full")

        task.errorDescription = nil
        #expect(task.statusDescription == "Download failed")

        task = makeTask(state: .completed, destination: URL(fileURLWithPath: "/tmp/done.zip"))
        #expect(task.statusDescription == "done.zip")

        var noDestination = makeTask(state: .completed)
        noDestination.destinationURL = nil
        #expect(noDestination.statusDescription == "Completed")

        noDestination.state = .downloading
        noDestination.totalBytesExpected = nil
        noDestination.bytesWritten = 0
        #expect(noDestination.statusDescription == "Starting")
    }

    @Test func taskFlagsMatchStates() {
        var task = makeTask(state: .preparing)
        #expect(task.isActive && !task.isCompleted && !task.canResume)

        task.state = .failed
        #expect(task.isFailed && !task.isActive)
        #expect(!task.canResume)

        task.resumeData = Data([1])
        #expect(task.canResume)
    }
}
