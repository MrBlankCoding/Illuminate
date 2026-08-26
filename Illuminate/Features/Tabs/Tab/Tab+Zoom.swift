//
//  Tab+Zoom.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import WebKit

extension Tab {

    static let zoomLevelKey = "level"

    enum ZoomBounds {
        static let min: CGFloat = 0.25
        static let max: CGFloat = 5.0
        static let step: CGFloat = 0.1
        static let `default`: CGFloat = 1.0
    }


    func zoomIn() {
        applyZoom((webView?.pageZoom ?? ZoomBounds.default) + ZoomBounds.step)
    }

    func zoomOut() {
        applyZoom((webView?.pageZoom ?? ZoomBounds.default) - ZoomBounds.step)
    }

    func resetZoom() {
        applyZoom(ZoomBounds.default)
    }

    private func applyZoom(_ newLevel: CGFloat) {
        guard let webView else { return }
        let clamped = min(max(newLevel, ZoomBounds.min), ZoomBounds.max)
        webView.pageZoom = clamped
        zoomLevel = clamped
        NotificationCenter.default.post(
            name: .zoomChanged,
            object: nil,
            userInfo: [Self.zoomLevelKey: zoomLevel]
        )
    }
}
