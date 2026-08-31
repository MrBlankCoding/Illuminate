//
//  ImageColorExtractor.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

// I thank the people who have created this before me because i have nooo idea 
import AppKit
import SwiftUI

final class ImageColorExtractor {
    static let shared = ImageColorExtractor()
    
    private init() {}
    
    func extractPalette(from url: URL, count: Int = 6) async -> [Color] {
        let data: Data?
        if url.isFileURL {
            // File reads and all image processing below run off the caller's
            // (usually main) actor to keep the UI responsive.
            data = await Task.detached(priority: .utility) {
                try? Data(contentsOf: url)
            }.value
        } else {
            do {
                let (remoteData, _) = try await Task.detached(priority: .utility) {
                    try await URLSession.shared.data(from: url)
                }.value
                data = remoteData
            } catch {
                return []
            }
        }

        guard let data else { return [] }
        return await Task.detached(priority: .userInitiated) { [self] in
            processPalette(from: data, count: count)
        }.value
    }

    func extractPalette(from image: NSImage, count: Int = 6) async -> [Color] {
        await Task.detached(priority: .userInitiated) { [self] in
            processPalette(from: image, count: count)
        }.value
    }

    private nonisolated func processPalette(from data: Data, count: Int) -> [Color] {
        guard let image = NSImage(data: data) else { return [] }
        return processPalette(from: image, count: count)
    }

    private nonisolated func processPalette(from image: NSImage, count: Int) -> [Color] {
        // Downscale for performance
        let thumbSize = NSSize(width: 40, height: 40)
        guard let thumb = resize(image: image, to: thumbSize) else { return [] }

        guard let cgImage = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorCounts: [ColorBucket: Int] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]

                if a > 128 {
                    // Bucket colors to reduce noise
                    let bucket = ColorBucket(r: r / 12 * 12, g: g / 12 * 12, b: b / 12 * 12)

                    // Filter out extreme blacks/whites
                    let brightness = (Int(r) + Int(g) + Int(b)) / 3
                    if brightness > 20 && brightness < 240 {
                        colorCounts[bucket, default: 0] += 1
                    }
                }
            }
        }

        // Sort by a combination of count and vibrancy
        let sortedBuckets = colorCounts.sorted { b1, b2 in
            return score(bucket: b1.key, count: b1.value) > score(bucket: b2.key, count: b2.value)
        }

        var result: [Color] = []
        for (bucket, _) in sortedBuckets {
            let color = Color(red: Double(bucket.r) / 255.0,
                             green: Double(bucket.g) / 255.0,
                             blue: Double(bucket.b) / 255.0)

            if !result.contains(where: { isSimilar($0, color) }) {
                result.append(color)
            }

            if result.count >= count { break }
        }

        return result
    }
    
    private nonisolated func score(bucket: ColorBucket, count: Int) -> Double {
        let r = Double(bucket.r) / 255.0
        let g = Double(bucket.g) / 255.0
        let b = Double(bucket.b) / 255.0
        
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let saturation = maxVal == 0 ? 0 : (maxVal - minVal) / maxVal
        
        // Vibrancy weight: strongly prefer saturated colors
        return Double(count) * (1.0 + saturation * 5.0)
    }
    
    private nonisolated func isSimilar(_ c1: Color, _ c2: Color) -> Bool {
        let ns1 = NSColor(c1)
        let ns2 = NSColor(c2)
        return abs(ns1.redComponent - ns2.redComponent) < 0.12 &&
               abs(ns1.greenComponent - ns2.greenComponent) < 0.12 &&
               abs(ns1.blueComponent - ns2.blueComponent) < 0.12
    }
    
    func extractDominantColor(from url: URL) async -> Color? {
        let palette = await extractPalette(from: url, count: 1)
        return palette.first
    }
    
    private nonisolated func resize(image: NSImage, to size: NSSize) -> NSImage? {
        let frame = NSRect(origin: .zero, size: size)
        guard let representation = image.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        let imageResized = NSImage(size: size, flipped: false) { (rect) -> Bool in
            return representation.draw(in: rect)
        }
        return imageResized
    }
    
    private struct ColorBucket: Hashable {
        let r, g, b: UInt8
    }
}
