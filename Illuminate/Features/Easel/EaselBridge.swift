//
//  EaselBridge.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/30/26.
//

import WebKit
import Foundation

enum EaselBridgeMessage: String {
    case easelReady = "easelReady"
    case easelChanged = "easelChanged"
    case easelTitleChanged = "easelTitleChanged"
    case easelPreviewChanged = "easelPreviewChanged"
}

@MainActor
protocol EaselBridgeDelegate: AnyObject {
    func easelDidBecomeReady(_ bridge: EaselBridge)
    func easelDidChange(_ bridge: EaselBridge, json: String)
    func easelDidRequestTitleChange(_ bridge: EaselBridge, title: String)
    func easelDidReceivePreview(_ bridge: EaselBridge, dataURL: String)
}

extension EaselBridgeDelegate {
    func easelDidReceivePreview(_ bridge: EaselBridge, dataURL: String) {}
}

final class EaselBridge: NSObject, WKScriptMessageHandler {
    weak var delegate: EaselBridgeDelegate?
    static let handlerName = "easelBridge"

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.handlerName,
              let body = message.body as? [String: Any],
              let typeRaw = body["type"] as? String,
              let type = EaselBridgeMessage(rawValue: typeRaw) else {
            AppLog.error("EaselBridge: invalid message \(message.body)")
            return
        }
        switch type {
        case .easelReady:
            delegate?.easelDidBecomeReady(self)
        case .easelChanged:
            guard let json = body["json"] as? String else { return }
            delegate?.easelDidChange(self, json: json)
        case .easelTitleChanged:
            if let title = body["title"] as? String {
                delegate?.easelDidRequestTitleChange(self, title: title)
            }
        case .easelPreviewChanged:
            if let dataURL = body["dataURL"] as? String {
                delegate?.easelDidReceivePreview(self, dataURL: dataURL)
            }
        }
    }

    static func install(on controller: WKUserContentController, handler: EaselBridge) {
        let wm = WeakScriptMessageHandler(handler)
        controller.add(wm, name: handlerName)
    }

    static func remove(from controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: handlerName)
    }
}
