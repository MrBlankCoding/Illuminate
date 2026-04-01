//
//  URLSynchronizer.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//


import Combine
import Foundation

@MainActor
final class URLSynchronizer: ObservableObject {
    @Published private(set) var currentURL: URL?

    init() {}

    func updateCurrentURL(_ url: URL?) {
        currentURL = url
    }
}
