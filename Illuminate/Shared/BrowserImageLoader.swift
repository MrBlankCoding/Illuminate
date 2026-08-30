//
//  BrowserImageLoader.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26
//

import AppKit
import Foundation
import Nuke

final class BrowserImageLoader: Sendable {
    static let shared = BrowserImageLoader()

    private let pipeline: ImagePipeline
    private let maxPixelSize: CGFloat

    init(pipeline: ImagePipeline = BrowserImagePipeline.shared, maxPixelSize: CGFloat = 64) {
        self.pipeline = pipeline
        self.maxPixelSize = maxPixelSize
    }

    func loadImage(
        from url: URL,
        priority: ImageRequest.Priority = .normal
    ) async throws -> NSImage {
        if url.scheme?.lowercased() == "data" {
            guard let decoded = Self.decodeDataURL(url.absoluteString),
                  let image = await Self.decodeAndDownsample(data: decoded, maxPixel: maxPixelSize) else {
                throw URLError(.badURL)
            }
            return image
        }

        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw URLError(.unsupportedURL)
        }

        let request = ImageRequest(
            url: url,
            processors: [ImageProcessors.Resize(size: CGSize(width: maxPixelSize, height: maxPixelSize), contentMode: .aspectFit)],
            priority: priority
        )

        let image = try await pipeline.image(for: request)
        return image
    }

    func loadImage(
        from url: URL,
        processors: [any ImageProcessing],
        priority: ImageRequest.Priority = .normal
    ) async throws -> NSImage {
        if url.scheme?.lowercased() == "data" {
            guard let decoded = Self.decodeDataURL(url.absoluteString),
                  let image = await Self.decodeAndDownsample(data: decoded, maxPixel: maxPixelSize) else {
                throw URLError(.badURL)
            }
            return image
        }
        let request = ImageRequest(url: url, processors: processors, priority: priority)
        return try await pipeline.image(for: request)
    }


    @discardableResult
    func loadImage(
        from url: URL,
        into imageView: NSImageView,
        placeholder: NSImage? = nil,
        priority: ImageRequest.Priority = .normal
    ) -> ImageTask? {
        if let placeholder { imageView.image = placeholder }
        let request = ImageRequest(
            url: url,
            processors: [ImageProcessors.Resize(size: CGSize(width: maxPixelSize, height: maxPixelSize), contentMode: .aspectFit)],
            priority: priority
        )
        return pipeline.loadImage(with: request) { result in
            DispatchQueue.main.async {
                if case .success(let response) = result {
                    imageView.image = response.image
                }
            }
        }
    }


    static func decodeDataURL(_ raw: String) -> Data? {
        guard raw.hasPrefix("data:"), let comma = raw.firstIndex(of: ",") else { return nil }
        let meta = raw[..<comma]
        let payload = String(raw[raw.index(after: comma)...])
        if meta.localizedCaseInsensitiveContains(";base64") {
            let clean = payload.removingPercentEncoding ?? payload
            return Data(base64Encoded: clean, options: .ignoreUnknownCharacters)
        }
        return (payload.removingPercentEncoding ?? payload).data(using: .utf8)
    }

    private static func decodeAndDownsample(data: Data, maxPixel: CGFloat) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard let img = NSImage(data: data) else { return nil }
            return await downsampled(img, maxPixel: maxPixel)
        }.value
    }

    private static func downsampled(_ image: NSImage, maxPixel: CGFloat) async -> NSImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxPixel, largest > 0 else { return image }
        let scale = maxPixel / largest
        let w = max(1, Int((image.size.width * scale).rounded(.down)))
        let h = max(1, Int((image.size.height * scale).rounded(.down)))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return image }
        rep.size = NSSize(width: w, height: h)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h),
                   from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: NSSize(width: w, height: h))
        out.addRepresentation(rep)
        return out
    }
}

