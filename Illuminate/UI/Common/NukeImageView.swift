//
//  NukeImageView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import SwiftUI
import AppKit
import Nuke

struct NukeImageView<Placeholder: View, FailureView: View>: View {
    let url: URL?
    let placeholder: Placeholder
    let failureView: FailureView

    @State private var image: NSImage?
    @State private var failed = false
    @State private var task: Task<Void, Never>?

    init(
        url: URL?,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder failureView: () -> FailureView
    ) {
        self.url = url
        self.placeholder = placeholder()
        self.failureView = failureView()
    }

    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) where FailureView == Placeholder {
        self.url = url
        self.placeholder = placeholder()
        self.failureView = placeholder()
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else if failed {
                failureView
            } else {
                placeholder
            }
        }
        .task(id: url) { await load() }
        .onDisappear { task?.cancel() }
    }

    private func load() async {
        task?.cancel()
        failed = false
        guard let url else { image = nil; failed = true; return }
        if let cached = FaviconCache.shared.memoryImage(for: url) {
            image = cached
            return
        }
        task = Task {
            let loaded = await FaviconLoader.shared.loadFavicon(from: url)
            if Task.isCancelled { return }
            await MainActor.run {
                if let loaded {
                    self.image = loaded
                } else {
                    self.failed = true
                }
            }
        }
        await task?.value
    }
}

struct NukeFaviconView: View {
    let url: URL?
    var size: CGFloat = 16

    @State private var image: NSImage?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.69, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.19, style: .continuous))
        .task(id: url) { await load() }
        .onDisappear { task?.cancel() }
    }

    private func load() async {
        task?.cancel()
        guard let url else { image = nil; return }
        if let cached = FaviconCache.shared.memoryImage(for: url) {
            image = cached
            return
        }
        task = Task {
            let loaded = await FaviconLoader.shared.loadFavicon(from: url)
            if Task.isCancelled { return }
            await MainActor.run { self.image = loaded }
        }
        await task?.value
    }
}

extension NSImageView {
    @discardableResult
    func loadFavicon(from url: URL, placeholder: NSImage? = nil) -> ImageTask? {
        BrowserImageLoader.shared.loadImage(from: url, into: self, placeholder: placeholder)
    }
}
