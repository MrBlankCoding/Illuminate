//
//  BrowserImagePipeline.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26
//

import Foundation
import Nuke

enum BrowserImagePipeline {
    static let shared: ImagePipeline = makePipeline()

    private static func makePipeline() -> ImagePipeline {
        var config = ImagePipeline.Configuration()

        let imageCache = ImageCache()
        imageCache.costLimit = 64 * 1024 * 1024
        imageCache.countLimit = 1024
        config.imageCache = imageCache

        if let dataCache = try? DataCache(name: "com.MrBlankCoding.Illuminate.Nuke") {
            dataCache.sizeLimit = 50 * 1024 * 1024
            config.dataCache = dataCache
            config.dataCachePolicy = .automatic
        }

        let urlConfig = URLSessionConfiguration.default
        urlConfig.timeoutIntervalForRequest = 10
        urlConfig.timeoutIntervalForResource = 15
        urlConfig.requestCachePolicy = .returnCacheDataElseLoad
        urlConfig.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024)
        config.dataLoader = DataLoader(configuration: urlConfig)

        config.isTaskCoalescingEnabled = true
        config.isRateLimiterEnabled = false

        return ImagePipeline(configuration: config)
    }
}
