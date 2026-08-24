//
//  DownloadManager+Transfers.swift
//  Illuminate
//
// Created by MrBlankCoding on 4/4/26.
//

import AppKit
import Foundation
import UniformTypeIdentifiers
import WebKit

extension DownloadManager {
    func startDownload(from url: URL, to destinationURL: URL, profileID: UUID? = nil) {
        if url.isFileURL {
            startLocalFileDownload(from: url, explicitDestinationURL: destinationURL, profileID: profileID)
            return
        }

        let resolvedDestination = resolvedExplicitDestination(for: destinationURL)
        AppLog.download("Starting URLSession download source=\(AppLog.sanitizedURL(url)) explicitDestination=\(resolvedDestination.path)")
        let item = makeTask(
            url: url,
            filename: resolvedDestination.lastPathComponent,
            destinationURL: resolvedDestination
        )

        taskProfileIDs[item.id] = profileID
        insertTask(item)

        let task = session.downloadTask(with: URLRequest(url: url))
        sessionTaskIDs[task.taskIdentifier] = item.id
        sessionTasksByID[item.id] = task
        task.resume()
    }

    func startDownload(from url: URL, suggestedFilename: String? = nil, profileID: UUID? = nil) {
        if url.isFileURL {
            startLocalFileDownload(from: url, suggestedFilename: suggestedFilename, profileID: profileID)
            return
        }

        let resolvedFilename = resolvedFilename(
            suggestedFilename,
            fallbackURL: url,
            mimeType: nil
        )

        if preferences.askWhereToSave {
            presentSavePanel(
                suggestedFilename: resolvedFilename,
                defaultDirectory: resolvedLastPickedDirectory() ?? downloadDirectoryURL
            ) { [weak self] chosenURL in
                guard let self else { return }
                if let chosenURL {
                    self.setLastPickedDirectory(chosenURL.deletingLastPathComponent())
                    self.startDownload(from: url, to: chosenURL, profileID: profileID)
                }
            }
            return
        }

        AppLog.download("Starting URLSession download source=\(AppLog.sanitizedURL(url)) suggestedFilename=\(suggestedFilename ?? "<nil>") resolvedFilename=\(resolvedFilename) defaultDirectory=\(downloadDirectoryURL.path)")
        let item = makeTask(
            url: url,
            filename: resolvedFilename,
            destinationURL: nil
        )

        taskProfileIDs[item.id] = profileID
        insertTask(item)

        let task = session.downloadTask(with: URLRequest(url: url))
        sessionTaskIDs[task.taskIdentifier] = item.id
        sessionTasksByID[item.id] = task
        task.resume()
    }

    func startDownload(using request: URLRequest, suggestedFilename: String? = nil, profileID: UUID? = nil) {
        guard let url = request.url else { return }

        if url.isFileURL {
            startLocalFileDownload(from: url, suggestedFilename: suggestedFilename, profileID: profileID)
            return
        }

        let resolvedFilename = resolvedFilename(
            suggestedFilename,
            fallbackURL: url,
            mimeType: nil
        )
        AppLog.download("Starting request-based URLSession download source=\(AppLog.sanitizedURL(url)) method=\(request.httpMethod ?? "GET") suggestedFilename=\(suggestedFilename ?? "<nil>") resolvedFilename=\(resolvedFilename)")
        let item = makeTask(
            url: url,
            filename: resolvedFilename,
            destinationURL: nil
        )

        taskProfileIDs[item.id] = profileID
        insertTask(item)

        let task = session.downloadTask(with: request)
        sessionTaskIDs[task.taskIdentifier] = item.id
        sessionTasksByID[item.id] = task
        task.resume()
    }

    private func startLocalFileDownload(
        from sourceURL: URL,
        suggestedFilename: String? = nil,
        explicitDestinationURL: URL? = nil,
        profileID: UUID? = nil
    ) {
        let resolvedDestination: URL
        if let explicitDestinationURL {
            resolvedDestination = resolvedExplicitDestination(for: explicitDestinationURL)
        } else {
            let filename = resolvedFilename(
                suggestedFilename,
                fallbackURL: sourceURL,
                mimeType: nil
            )
            resolvedDestination = uniqueDestinationURL(
                in: downloadDirectoryURL,
                preferredFilename: filename
            )
        }

        AppLog.download(
            "Starting local file download source=\(sourceURL.path) destination=\(resolvedDestination.path)"
        )

        let item = makeTask(
            url: sourceURL,
            filename: resolvedDestination.lastPathComponent,
            destinationURL: resolvedDestination
        )
        taskProfileIDs[item.id] = profileID
        insertTask(item)

        Task.detached(priority: .userInitiated) {
            do {
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    throw CocoaError(.fileNoSuchFile)
                }

                let temporaryURL = try self.prepareLocalFileTransferSource(at: sourceURL)
                defer { try? FileManager.default.removeItem(at: temporaryURL) }

                try self.moveDownload(at: temporaryURL, to: resolvedDestination)
                await self.finishDownload(id: item.id, destinationURL: resolvedDestination)
            } catch {
                await self.failDownload(id: item.id, error: error)
            }
        }
    }

    private nonisolated func prepareLocalFileTransferSource(at sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        let stagingDirectory = baseDirectory
            .appendingPathComponent("Illuminate", isDirectory: true)
            .appendingPathComponent("DownloadStaging", isDirectory: true)
        try ensureDirectoryExists(at: stagingDirectory)

        let stagedURL = stagingDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        try fileManager.copyItem(at: sourceURL, to: stagedURL)
        return stagedURL
    }

    func addDownload(_ download: WKDownload, profileID: UUID? = nil) {
        let url = download.originalRequest?.url ?? URL(string: "about:blank")!
        let filename = resolvedFilename(nil, fallbackURL: url, mimeType: nil)
        AppLog.download("Tracking WebKit-managed download source=\(AppLog.sanitizedURL(url)) resolvedFilename=\(filename)")
        let item = makeTask(
            url: url,
            filename: filename,
            destinationURL: nil
        )

        taskProfileIDs[item.id] = profileID
        insertTask(item)
        webKitDownloadIDs[ObjectIdentifier(download)] = item.id
        webKitDownloadsByID[item.id] = download
        download.delegate = self
    }

    func saveDownloadedData(
        _ data: Data,
        from sourceURL: URL?,
        suggestedFilename: String? = nil,
        mimeType: String? = nil,
        profileID: UUID? = nil
    ) {
        let destinationURL = uniqueDestinationURL(
            in: downloadDirectoryURL,
            preferredFilename: resolvedFilename(
                suggestedFilename,
                fallbackURL: sourceURL,
                mimeType: mimeType
            )
        )

        saveDownloadedData(
            data,
            from: sourceURL,
            to: destinationURL,
            suggestedFilename: suggestedFilename,
            mimeType: mimeType,
            profileID: profileID
        )
    }

    func saveDownloadedData(
        _ data: Data,
        from sourceURL: URL?,
        to destinationURL: URL,
        suggestedFilename: String? = nil,
        mimeType: String? = nil,
        profileID: UUID? = nil
    ) {
        let resolvedDestination = resolvedExplicitDestination(for: destinationURL)
        let filename = resolvedFilename(
            suggestedFilename ?? resolvedDestination.lastPathComponent,
            fallbackURL: sourceURL,
            mimeType: mimeType
        )
        let item = makeTask(
            url: sourceURL ?? resolvedDestination,
            filename: filename,
            destinationURL: resolvedDestination
        )

        taskProfileIDs[item.id] = profileID
        insertTask(item)

        Task.detached(priority: .userInitiated) {
            do {
                try self.ensureParentDirectoryExists(for: resolvedDestination)
                try data.write(to: resolvedDestination, options: .atomic)
                await self.finishDownload(id: item.id, destinationURL: resolvedDestination)
            } catch {
                await self.failDownload(id: item.id, error: error)
            }
        }
    }

    func cancelDownload(id: UUID) {
        if let task = sessionTasksByID.removeValue(forKey: id) {
            sessionTaskIDs.removeValue(forKey: task.taskIdentifier)
            task.cancel()
            AppLog.download("Cancelled URLSession download id=\(id.uuidString) taskIdentifier=\(task.taskIdentifier)")
        }

        if let webKitDownload = webKitDownloadsByID.removeValue(forKey: id) {
            webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(webKitDownload))
            webKitDownload.cancel()
            AppLog.download("Cancelled WebKit download id=\(id.uuidString)")
        }

        updateTask(id) { task in
            task.state = .cancelled
            task.finishedAt = Date()
            task.errorDescription = nil
        }
        if let updated = downloads.first(where: { $0.id == id }) {
            recordInProfileHistory(updated)
        }
    }

    func revealDownload(_ task: DownloadTask) {
        guard let destinationURL = task.destinationURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
    }

    func openDownload(_ task: DownloadTask) {
        guard task.state == .completed, let destinationURL = task.destinationURL else { return }
        NSWorkspace.shared.open(destinationURL)
    }

    func presentSavePanel(
        suggestedFilename: String,
        defaultDirectory: URL,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = suggestedFilename
            panel.directoryURL = defaultDirectory

            let ext = (suggestedFilename as NSString).pathExtension
            if !ext.isEmpty, let contentType = UTType(filenameExtension: ext) {
                panel.allowedContentTypes = [contentType]
            }

            if panel.runModal() == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}

extension DownloadManager: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard let id = webKitDownloadIDs[ObjectIdentifier(download)] else {
            completionHandler(nil)
            return
        }

        let filename = resolvedFilename(
            suggestedFilename,
            fallbackURL: download.originalRequest?.url,
            mimeType: response.mimeType
        )

        let finalDestinationURL = uniqueDestinationURL(
            in: downloadDirectoryURL,
            preferredFilename: filename
        )
        let stagingDestinationURL = uniqueDestinationURL(
            in: downloadStagingDirectoryURL(),
            preferredFilename: filename
        )

        webKitStagingURLsByID[id] = stagingDestinationURL
        AppLog.download("WebKit destination resolved id=\(id.uuidString) source=\(AppLog.sanitizedURL(download.originalRequest?.url)) staging=\(stagingDestinationURL.path) final=\(finalDestinationURL.path) mimeType=\(response.mimeType ?? "<nil>")")

        updateTask(id) { task in
            task.filename = finalDestinationURL.lastPathComponent
            task.destinationURL = finalDestinationURL
            task.totalBytesExpected = response.expectedContentLength > 0 ? response.expectedContentLength : nil
            task.state = .downloading
        }

        completionHandler(stagingDestinationURL)
    }

    func download(
        _ download: WKDownload,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = webKitDownloadIDs[ObjectIdentifier(download)] else { return }

        updateTask(id) { task in
            task.state = .downloading
            task.bytesWritten = totalBytesWritten
            task.totalBytesExpected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
            if totalBytesExpectedToWrite > 0 {
                task.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let id = webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(download)) else { return }
        webKitDownloadsByID.removeValue(forKey: id)

        guard let finalDestinationURL = downloads.first(where: { $0.id == id })?.destinationURL else {
            failDownload(
                id: id,
                error: NSError(
                    domain: "DownloadManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Download finished without a destination."]
                )
            )
            return
        }

        guard let stagingURL = webKitStagingURLsByID.removeValue(forKey: id) else {
            failDownload(
                id: id,
                error: NSError(
                    domain: "DownloadManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Download finished without staged file access."]
                )
            )
            return
        }

        do {
            AppLog.download("Moving staged WebKit download id=\(id.uuidString) staging=\(stagingURL.path) final=\(finalDestinationURL.path)")
            try moveDownload(at: stagingURL, to: finalDestinationURL)
            finishDownload(id: id, destinationURL: finalDestinationURL)
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            failDownload(id: id, error: error)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let id = webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(download)) else { return }
        webKitDownloadsByID.removeValue(forKey: id)
        if let stagingURL = webKitStagingURLsByID.removeValue(forKey: id) {
            try? FileManager.default.removeItem(at: stagingURL)
        }
        failDownload(id: id, error: error)
    }

    func download(
        _ download: WKDownload,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void
    ) {
        if let url = request.url {
            AppLog.info("WebKit download redirected to \(url.absoluteString) (status=\(response.statusCode))")
        }
        decisionHandler(.allow)
    }

    func download(
        _ download: WKDownload,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        AppLog.info("WebKit download received auth challenge: \(challenge.protectionSpace.authenticationMethod)")
        completionHandler(.performDefaultHandling, nil)
    }
}

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard let id = self.sessionTaskIDs[downloadTask.taskIdentifier] else { return }

            self.updateTask(id) { task in
                task.state = .downloading
                task.bytesWritten = totalBytesWritten
                task.totalBytesExpected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
                if totalBytesExpectedToWrite > 0 {
                    task.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                }
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let stagingURL = self.stageDownloadedFile(at: location)

        Task { @MainActor in
            guard let id = self.sessionTaskIDs[downloadTask.taskIdentifier] else {
                if let stagingURL {
                    try? FileManager.default.removeItem(at: stagingURL)
                }
                return
            }

            let response = downloadTask.response
            let sourceURL = downloadTask.originalRequest?.url
            let currentTask = self.downloads.first(where: { $0.id == id })
            let filename = self.resolvedFilename(
                response?.suggestedFilename ?? currentTask?.filename,
                fallbackURL: sourceURL,
                mimeType: response?.mimeType
            )

            let destinationURL: URL
            if let explicitDestination = currentTask?.destinationURL {
                destinationURL = explicitDestination
            } else {
                destinationURL = self.uniqueDestinationURL(
                    in: self.downloadDirectoryURL,
                    preferredFilename: filename
                )
            }

            let finalLocation = stagingURL ?? location
            AppLog.download("URLSession finished temporary download id=\(id.uuidString) stagingLocation=\(stagingURL?.path ?? "<nil>") source=\(AppLog.sanitizedURL(sourceURL)) destination=\(destinationURL.path) mimeType=\(response?.mimeType ?? "<nil>")")

            do {
                try self.moveDownload(at: finalLocation, to: destinationURL)
                self.finishDownload(id: id, destinationURL: destinationURL)
            } catch {
                if let stagingURL {
                    try? FileManager.default.removeItem(at: stagingURL)
                }
                self.failDownload(id: id, error: error)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { @MainActor in
            guard let id = self.sessionTaskIDs.removeValue(forKey: task.taskIdentifier) else { return }
            self.sessionTasksByID.removeValue(forKey: id)

            guard let error else { return }

            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                AppLog.download("URLSession download cancelled by system id=\(id.uuidString) taskIdentifier=\(task.taskIdentifier)")
                self.updateTask(id) { task in
                    if task.state == .completed {
                        return
                    }
                    task.state = .cancelled
                    task.finishedAt = Date()
                }
                if let updated = self.downloads.first(where: { $0.id == id }) {
                    self.recordInProfileHistory(updated)
                }
                return
            }

            self.failDownload(id: id, error: error)
        }
    }
}
