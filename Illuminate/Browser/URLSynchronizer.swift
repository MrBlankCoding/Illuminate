//
//  URLSynchronizer.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Foundation
import Observation

@MainActor
@Observable
final class URLSynchronizer {
    private(set) var currentURL: URL?

    init() {}

    func updateCurrentURL(_ url: URL?) {
        guard currentURL != url else { return }
        currentURL = url
    }
}
