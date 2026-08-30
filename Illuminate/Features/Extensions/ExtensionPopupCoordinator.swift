//
//  ExtensionPopupCoordinator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import SwiftUI
import WebKit
import Observation

@MainActor
@Observable
final class ExtensionPopupCoordinator {

    struct PopupPayload {
        let popupWebView: WKWebView
        let extensionName: String?
        let anchorX: CGFloat
    }

    private(set) var activePopup: PopupPayload?

    func open(_ payload: PopupPayload) {
        activePopup = payload
    }

    func close() {
        activePopup = nil
    }
}
