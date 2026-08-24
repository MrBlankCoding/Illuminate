//
//  DownloadRecord.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import SwiftData

@Model
final class DownloadRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var profileID: UUID?
    var sourceURLString: String
    var filename: String
    var destinationPathString: String?
    var stateRawValue: String
    var createdAt: Date
    var finishedAt: Date?
    var bytesWritten: Int64
    var totalBytesExpected: Int64?
    var errorDescription: String?

    var sourceURL: URL? { URL(string: sourceURLString) }
    var destinationURL: URL? {
        guard let destinationPathString, !destinationPathString.isEmpty else { return nil }
        return URL(fileURLWithPath: destinationPathString)
    }

    init(
        id: UUID,
        profileID: UUID?,
        sourceURLString: String,
        filename: String,
        destinationPathString: String?,
        stateRawValue: String,
        createdAt: Date,
        finishedAt: Date?,
        bytesWritten: Int64,
        totalBytesExpected: Int64?,
        errorDescription: String?
    ) {
        self.id = id
        self.profileID = profileID
        self.sourceURLString = sourceURLString
        self.filename = filename
        self.destinationPathString = destinationPathString
        self.stateRawValue = stateRawValue
        self.createdAt = createdAt
        self.finishedAt = finishedAt
        self.bytesWritten = bytesWritten
        self.totalBytesExpected = totalBytesExpected
        self.errorDescription = errorDescription
    }

    convenience init(task: DownloadTask, profileID: UUID?) {
        self.init(
            id: task.id,
            profileID: profileID,
            sourceURLString: task.url.absoluteString,
            filename: task.filename,
            destinationPathString: task.destinationURL?.path,
            stateRawValue: task.state.rawValue,
            createdAt: task.createdAt,
            finishedAt: task.finishedAt,
            bytesWritten: task.bytesWritten,
            totalBytesExpected: task.totalBytesExpected,
            errorDescription: task.errorDescription
        )
    }

    func apply(_ task: DownloadTask) {
        filename = task.filename
        destinationPathString = task.destinationURL?.path
        stateRawValue = task.state.rawValue
        finishedAt = task.finishedAt
        bytesWritten = task.bytesWritten
        totalBytesExpected = task.totalBytesExpected
        errorDescription = task.errorDescription
    }
}
