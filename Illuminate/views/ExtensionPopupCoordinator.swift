//
//  ExtensionPopupCoordinator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Combine
import Foundation
import SwiftUI
import WebKit

@MainActor
final class ExtensionPopupCoordinator: ObservableObject {

    struct PopupPayload {
        let popupWebView: WKWebView
        let extensionName: String?
        let anchorX: CGFloat
    }

    @Published private(set) var activePopup: PopupPayload?

    func open(_ payload: PopupPayload) {
        activePopup = payload
    }

    func close() {
        activePopup = nil
    }
}
