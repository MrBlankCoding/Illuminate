//
//  FaviconCache.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import AppKit
import Foundation

// THis works for now but I think I want to build on this later

final class FaviconCache {
    static let shared = FaviconCache(capacity: 128)

    private let capacity: Int
    private var storage: [URL: NSImage] = [:]
    private var order: [URL] = []
    private let lock = NSLock()
    private let fileManager = FileManager.default
    private let cacheURL: URL

    init(capacity: Int, cacheDirectory: URL? = nil) {
        self.capacity = max(8, capacity)
        
        if let customDir = cacheDirectory {
            self.cacheURL = customDir
        } else {
            let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let appSupport = paths[0].appendingPathComponent("Illuminate", isDirectory: true)
            cacheURL = appSupport.appendingPathComponent("Favicons", isDirectory: true)
        }
        
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }

    func image(for key: URL) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[key] {
            touch(key)
            return cached
        }
        
        // Try disk cache
        if let diskImage = loadFromDisk(key) {
            storage[key] = diskImage
            touch(key)
            return diskImage
        }

        return nil
    }

    func fetchImage(for url: URL) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                set(image, for: url)
                return image
            }
        } catch {
            AppLog.info("Failed to fetch favicon for \(url.absoluteString): \(error.localizedDescription)")
        }
        return nil
    }

    func set(_ image: NSImage, for key: URL) {
        lock.lock()
        defer { lock.unlock() }

        storage[key] = image
        touch(key)
        saveToDisk(image, key: key)
        evictIfNeeded()
    }

    private func touch(_ key: URL) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    private func evictIfNeeded() {
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
            removeFromDisk(oldest)
        }
    }
    
    private func diskURL(for key: URL) -> URL {
        let name = key.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return cacheURL.appendingPathComponent(name).appendingPathExtension("png")
    }
    
    private func saveToDisk(_ image: NSImage, key: URL) {
        let url = diskURL(for: key)
        let data = image.pngData()
        Task.detached(priority: .background) {
            if let data = data {
                try? data.write(to: url)
            }
        }
    }
    
    private func loadFromDisk(_ key: URL) -> NSImage? {
        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }
    
    private func removeFromDisk(_ key: URL) {
        let url = diskURL(for: key)
        try? fileManager.removeItem(at: url)
    }
}
