//
//  DownloadManager+Transfers.swift
//  Illuminate
//

import AppKit
import Foundation
import WebKit

extension DownloadManager {
    func startDownload(from url: URL, to destinationURL: URL) {
        let resolvedDestination = resolvedExplicitDestination(for: destinationURL)
        AppLog.download("Starting URLSession download source=\(url.absoluteString) explicitDestination=\(resolvedDestination.path)")
        let item = makeTask(
            url: url,
            filename: resolvedDestination.lastPathComponent,
            destinationURL: resolvedDestination,
            safetyLevel: safetyLevel(for: resolvedDestination.lastPathComponent)
        )

        insertTask(item)

        let task = session.downloadTask(with: URLRequest(url: url))
        sessionTaskIDs[task.taskIdentifier] = item.id
        sessionTasksByID[item.id] = task
        task.resume()
    }

    func startDownload(from url: URL, suggestedFilename: String? = nil) {
        let resolvedFilename = resolvedFilename(
            suggestedFilename,
            fallbackURL: url,
            mimeType: nil
        )
        AppLog.download("Starting URLSession download source=\(url.absoluteString) suggestedFilename=\(suggestedFilename ?? "<nil>") resolvedFilename=\(resolvedFilename) defaultDirectory=\(downloadDirectoryURL.path)")
        let item = makeTask(
            url: url,
            filename: resolvedFilename,
            destinationURL: nil,
            safetyLevel: safetyLevel(for: resolvedFilename)
        )

        insertTask(item)

        let task = session.downloadTask(with: URLRequest(url: url))
        sessionTaskIDs[task.taskIdentifier] = item.id
        sessionTasksByID[item.id] = task
        task.resume()
    }

    func startDownload(using request: URLRequest, suggestedFilename: String? = nil) {
        guard let url = request.url else { return }

        let resolvedFilename = resolvedFilename(
            suggestedFilename,
            fallbackURL: url,
            mimeType: nil
        )
        AppLog.download("Starting request-based URLSession download source=\(url.absoluteString) method=\(request.httpMethod ?? "GET") suggestedFilename=\(suggestedFilename ?? "<nil>") resolvedFilename=\(resolvedFilename)")
        let item = makeTask(
            url: url,
            filename: resolvedFilename,
            destinationURL: nil,
            safetyLevel: safetyLevel(for: resolvedFilename)
        )

        insertTask(item)

        let task = session.downloadTask(with: request)
        sessionTaskIDs[task.taskIdentifier] = item.id
        sessionTasksByID[item.id] = task
        task.resume()
    }

    func addDownload(_ download: WKDownload) {
        let url = download.originalRequest?.url ?? URL(string: "about:blank")!
        let filename = resolvedFilename(nil, fallbackURL: url, mimeType: nil)
        AppLog.download("Tracking WebKit-managed download source=\(url.absoluteString) resolvedFilename=\(filename)")
        let item = makeTask(
            url: url,
            filename: filename,
            destinationURL: nil,
            safetyLevel: safetyLevel(for: filename)
        )

        insertTask(item)
        webKitDownloadIDs[ObjectIdentifier(download)] = item.id
        webKitDownloadsByID[item.id] = download
        download.delegate = self
    }

    func saveDownloadedData(
        _ data: Data,
        from sourceURL: URL?,
        suggestedFilename: String? = nil,
        mimeType: String? = nil
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
            mimeType: mimeType
        )
    }

    func saveDownloadedData(
        _ data: Data,
        from sourceURL: URL?,
        to destinationURL: URL,
        suggestedFilename: String? = nil,
        mimeType: String? = nil
    ) {
        let resolvedDestination = resolvedExplicitDestination(for: destinationURL)
        let filename = resolvedFilename(
            suggestedFilename ?? resolvedDestination.lastPathComponent,
            fallbackURL: sourceURL,
            mimeType: mimeType
        )
        let level = safetyLevel(for: filename)
        let item = makeTask(
            url: sourceURL ?? resolvedDestination,
            filename: resolvedDestination.lastPathComponent,
            destinationURL: resolvedDestination,
            safetyLevel: level
        )

        insertTask(item)

        guard shouldAllowDownload(filename: filename, mimeType: mimeType, destinationURL: resolvedDestination) else {
            AppLog.download("Blocked in-memory download source=\(sourceURL?.absoluteString ?? "<local>") filename=\(filename) destination=\(resolvedDestination.path)")
            markBlocked(
                id: item.id,
                message: "Blocked because the file type may be unsafe."
            )
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.ensureParentDirectoryExists(for: resolvedDestination)
                try data.write(to: resolvedDestination, options: .atomic)
                self.finishDownload(id: item.id, destinationURL: resolvedDestination)
            } catch {
                self.failDownload(id: item.id, error: error)
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
    }

    func revealDownload(_ task: DownloadTask) {
        guard let destinationURL = task.destinationURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
    }

    func openDownload(_ task: DownloadTask) {
        guard task.state == .completed, let destinationURL = task.destinationURL else { return }
        NSWorkspace.shared.open(destinationURL)
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

        guard shouldAllowDownload(
            filename: filename,
            mimeType: response.mimeType,
            destinationURL: nil
        ) else {
            markBlocked(id: id, message: "Blocked because the file type may be unsafe.")
            webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(download))
            webKitDownloadsByID.removeValue(forKey: id)
            completionHandler(nil)
            return
        }

        let finalDestinationURL = uniqueDestinationURL(
            in: downloadDirectoryURL,
            preferredFilename: filename
        )
        let stagingDestinationURL = uniqueDestinationURL(
            in: downloadStagingDirectoryURL(),
            preferredFilename: filename
        )

        webKitStagingURLsByID[id] = stagingDestinationURL
        AppLog.download("WebKit destination resolved id=\(id.uuidString) source=\(download.originalRequest?.url?.absoluteString ?? "<nil>") staging=\(stagingDestinationURL.path) final=\(finalDestinationURL.path) mimeType=\(response.mimeType ?? "<nil>")")

        updateTask(id) { task in
            task.filename = finalDestinationURL.lastPathComponent
            task.destinationURL = finalDestinationURL
            task.totalBytesExpected = response.expectedContentLength > 0 ? response.expectedContentLength : nil
            task.state = .downloading
            task.safetyLevel = self.safetyLevel(for: finalDestinationURL.lastPathComponent, mimeType: response.mimeType, destinationURL: finalDestinationURL)
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
            failDownload(id: id, error: error)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let id = webKitDownloadIDs.removeValue(forKey: ObjectIdentifier(download)) else { return }
        webKitDownloadsByID.removeValue(forKey: id)
        if let stagingURL = webKitStagingURLsByID.removeValue(forKey: id) {
            try? fileManager.removeItem(at: stagingURL)
        }
        failDownload(id: id, error: error)
    }

    func download(
        _ download: WKDownload,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    func download(
        _ download: WKDownload,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(.performDefaultHandling, nil)
    }
}

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = sessionTaskIDs[downloadTask.taskIdentifier] else { return }

        updateTask(id) { task in
            task.state = .downloading
            task.bytesWritten = totalBytesWritten
            task.totalBytesExpected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
            if totalBytesExpectedToWrite > 0 {
                task.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = sessionTaskIDs[downloadTask.taskIdentifier] else { return }

        let response = downloadTask.response
        let sourceURL = downloadTask.originalRequest?.url
        let currentTask = downloads.first(where: { $0.id == id })
        let filename = resolvedFilename(
            response?.suggestedFilename ?? currentTask?.filename,
            fallbackURL: sourceURL,
            mimeType: response?.mimeType
        )

        let destinationURL: URL
        if let explicitDestination = currentTask?.destinationURL {
            destinationURL = explicitDestination
        } else {
            destinationURL = uniqueDestinationURL(
                in: downloadDirectoryURL,
                preferredFilename: filename
            )
        }

        AppLog.download("URLSession finished temporary download id=\(id.uuidString) tempLocation=\(location.path) source=\(sourceURL?.absoluteString ?? "<nil>") destination=\(destinationURL.path) mimeType=\(response?.mimeType ?? "<nil>")")

        guard shouldAllowDownload(
            filename: destinationURL.lastPathComponent,
            mimeType: response?.mimeType,
            destinationURL: destinationURL
        ) else {
            try? fileManager.removeItem(at: location)
            AppLog.download("Removed temporary file for blocked URLSession download id=\(id.uuidString) tempLocation=\(location.path)")
            markBlocked(id: id, message: "Blocked because the file type may be unsafe.")
            sessionTaskIDs.removeValue(forKey: downloadTask.taskIdentifier)
            sessionTasksByID.removeValue(forKey: id)
            return
        }

        do {
            try moveDownload(at: location, to: destinationURL)
            finishDownload(id: id, destinationURL: destinationURL)
        } catch {
            failDownload(id: id, error: error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let id = sessionTaskIDs.removeValue(forKey: task.taskIdentifier) else { return }
        sessionTasksByID.removeValue(forKey: id)

        guard let error else { return }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            AppLog.download("URLSession download cancelled by system id=\(id.uuidString) taskIdentifier=\(task.taskIdentifier)")
            updateTask(id) { task in
                if task.state == .completed || task.state == .blocked {
                    return
                }
                task.state = .cancelled
                task.finishedAt = Date()
            }
            return
        }

        failDownload(id: id, error: error)
    }
}
