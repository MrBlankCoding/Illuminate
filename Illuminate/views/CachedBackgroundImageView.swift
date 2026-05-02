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
            image = nil
            Task {
                await loadImage(for: newURL)
            }
        }
    }
    
    private func loadImage(for targetURL: URL) async {
        let fileManager = FileManager.default
        let appSupport = fileManager.illuminateAppSupportDirectory()
        let cacheDirectory = appSupport.appendingPathComponent("Backgrounds", isDirectory: true)
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        var hasher = Hasher()
        hasher.combine(targetURL.absoluteString)
        let fileName = "\(hasher.finalize()).jpg"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL), let cachedImage = NSImage(data: data) {
                await MainActor.run {
                    if self.url == targetURL {
                        self.image = cachedImage
                    }
                }
                return
            }
        }
        
        do {
            let data: Data
            if targetURL.isFileURL {
                data = try Data(contentsOf: targetURL)
            } else {
                let (remoteData, response) = try await URLSession.shared.data(from: targetURL)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                data = remoteData
            }

            if let downloadedImage = NSImage(data: data) {
                let downsampled = downloadedImage.downsampled(toWidth: 1920)
                if let processedData = downsampled.jpegData(compressionQuality: 0.8) {
                    try? processedData.write(to: fileURL)
                }
                await MainActor.run {
                    if self.url == targetURL {
                        self.image = downsampled
                    }
                }
            }
        } catch { }
    }
}
