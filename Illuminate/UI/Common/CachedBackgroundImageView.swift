//
//  CachedBackgroundImageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/19/26.
//

import SwiftUI
import AppKit

struct CachedBackgroundImageView: View {
    let url: URL
    
    @State private var image: NSImage?
    
    var body: some View {
        GeometryReader { geo in
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Color.clear
                    .onAppear {
                        Task {
                            await loadImage(for: url)
                        }
                    }
            }
        }
        .onChange(of: url) { _, newURL in
            Task {
                await loadImage(for: newURL)
            }
        }
    }
    
    private func loadImage(for targetURL: URL) async {
        // All file I/O, JPEG decoding/encoding, and disk writes happen off the
        // main thread; only the final image assignment hops back to MainActor.
        let processedImage: NSImage? = await Task.detached(priority: .utility) { () -> NSImage? in
            let fileManager = FileManager.default
            let appSupport = fileManager.illuminateAppSupportDirectory()
            let cacheDirectory = appSupport.appendingPathComponent("Backgrounds", isDirectory: true)

            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            let urlBytes = targetURL.absoluteString.utf8
            var hash: UInt64 = 5381
            for byte in urlBytes {
                hash = (hash &* 33) ^ UInt64(byte)
            }
            let stableKey = String(format: "%016x", hash)
            let fileURL = cacheDirectory.appendingPathComponent("\(stableKey).jpg")

            if fileManager.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL),
               let cachedImage = NSImage(data: data) {
                return cachedImage
            }

            let data: Data
            if targetURL.isFileURL {
                guard let fileData = try? Data(contentsOf: targetURL) else { return nil }
                data = fileData
            } else {
                do {
                    let (remoteData, response) = try await Task.detached(priority: .utility) {
                        try await URLSession.shared.data(from: targetURL)
                    }.value
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
                    data = remoteData
                } catch {
                    return nil
                }
            }

            guard let downloadedImage = NSImage(data: data) else { return nil }
            let downsampled = downloadedImage.downsampled(toWidth: 1920)
            if let processedData = downsampled.jpegData(compressionQuality: 0.8) {
                try? processedData.write(to: fileURL)
            }
            return downsampled
        }.value

        if let processedImage {
            await MainActor.run {
                if self.url == targetURL {
                    self.image = processedImage
                }
            }
        }
    }
}
