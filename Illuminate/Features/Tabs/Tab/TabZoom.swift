//
//  TabZoom.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import WebKit

extension Tab {

    static let zoomLevelKey = "level"

    enum ZoomBounds {
        static let min: Double = 0.25
        static let max: Double = 5.0
        static let step: Double = 0.1
        static let `default`: Double = 1.0
    }

    func zoomIn() {
        applyZoom((webView.map { Double($0.pageZoom) } ?? ZoomBounds.default) + ZoomBounds.step)
    }

    func zoomOut() {
        applyZoom((webView.map { Double($0.pageZoom) } ?? ZoomBounds.default) - ZoomBounds.step)
    }

    func resetZoom() {
        applyZoom(ZoomBounds.default)
    }

    private func applyZoom(_ newLevel: Double) {
        guard let webView else { return }

        let clamped = min(max(newLevel, ZoomBounds.min), ZoomBounds.max)

        // Round to 2 decimal places to eliminate binary floating-point drift
        // from repeated +/- step arithmetic (e.g. 1.2000000000000002 -> 1.2).
        let rounded = (clamped * 100).rounded() / 100
        let final = min(max(rounded, ZoomBounds.min), ZoomBounds.max)

        webView.pageZoom = CGFloat(final)
        zoomLevel = final

        NotificationCenter.default.post(
            name: .zoomChanged,
            object: nil,
            userInfo: [Self.zoomLevelKey: final]
        )
    }
}