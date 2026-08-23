//
//  ExtensionPackageDownloader.swift
//  Illuminate
//

import Foundation

enum ExtensionPackageSource: Hashable, Codable {
    case githubRelease(repository: String, assetNameContains: String)
}

enum ExtensionPackageDownloader {
    static func downloadUnpackedPackage(from source: ExtensionPackageSource) async throws -> URL {
        switch source {
        case .githubRelease(let repository, let assetNameContains):
            let downloadURL = try await latestGitHubAssetURL(repository: repository, assetNameContains: assetNameContains)
            return try await downloadAndUnpack(from: downloadURL)
        }
    }

    static func latestReleaseVersion(for source: ExtensionPackageSource) async throws -> String {
        switch source {
        case .githubRelease(let repository, _):
            return try await latestGitHubReleaseTag(repository: repository)
        }
    }

    private static func latestGitHubReleaseTag(repository: String) async throws -> String {
        guard let apiURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw packageError("Invalid GitHub repository: \(repository)")
        }

        var request = URLRequest(url: apiURL)
        request.setValue("Illuminate", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, fallback: "Could not look up the latest release.")

        let release = try JSONDecoder().decode(GitHubReleaseTag.self, from: data)
        let tag = release.tagName
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private static func latestGitHubAssetURL(repository: String, assetNameContains: String) async throws -> URL {
        guard let apiURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw packageError("Invalid GitHub repository: \(repository)")
        }

        var request = URLRequest(url: apiURL)
        request.setValue("Illuminate", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, fallback: "Could not look up the latest release.")

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let needle = assetNameContains.lowercased()
        guard let asset = release.assets.first(where: { $0.name.lowercased().contains(needle) }) else {
            throw packageError("No downloadable package matching \"\(assetNameContains)\" was found for \(repository).")
        }
        return asset.browserDownloadURL
    }

    private static func downloadAndUnpack(from remoteURL: URL) async throws -> URL {
        var request = URLRequest(url: remoteURL)
        request.setValue("Illuminate", forHTTPHeaderField: "User-Agent")

        let (downloadedURL, response) = try await URLSession.shared.download(for: request)
        try validateHTTPResponse(response, fallback: "The extension package could not be downloaded.")

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IlluminateExtensionDownloads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let zipURL = workDirectory.appendingPathComponent("package.zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try FileManager.default.moveItem(at: downloadedURL, to: zipURL)

        let unpackedURL = workDirectory.appendingPathComponent("unpacked", isDirectory: true)
        try unpackZip(zipURL, to: unpackedURL)

        if let root = findManifestDirectory(in: unpackedURL) {
            return root
        }

        // WKWebExtension can load a zip that already has manifest.json at the archive root.
        return zipURL
    }

    private static func unpackZip(_ zipURL: URL, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, destinationURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw packageError("The extension archive could not be unpacked.")
        }
    }

    private static func findManifestDirectory(in root: URL) -> URL? {
        let manifestName = "manifest.json"
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: root.appendingPathComponent(manifestName).path) {
            return root
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for child in children {
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory, fileManager.fileExists(atPath: child.appendingPathComponent(manifestName).path) {
                return child
            }
        }
        return nil
    }

    private static func validateHTTPResponse(_ response: URLResponse, fallback: String) throws {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw packageError("\(fallback) (HTTP \(http.statusCode))")
        }
    }

    private static func packageError(_ message: String) -> NSError {
        NSError(domain: "ExtensionPackageDownloader", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - GitHub API models

private struct GitHubReleaseTag: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
