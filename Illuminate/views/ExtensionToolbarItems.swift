//
//  ExtensionToolbarItems.swift
//  Illuminate
//

import SwiftUI
import WebKit

struct ExtensionToolbarItems: View {
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    private var enabledExtensions: [WKWebExtensionContext] {
        let _ = profileEnvironment.extensionManager.enabledStateVersion
        return profileEnvironment.extensionManager.installedExtensions.filter {
            profileEnvironment.extensionManager.isEnabled($0)
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            if profileEnvironment.extensionManager.isLoadingExtensions {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
                    .transition(.opacity)
            } else {
                ForEach(enabledExtensions, id: \.self) { context in
                    ExtensionToolbarItemView(context: context)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: enabledExtensions.map(\.uniqueIdentifier))
        .animation(.easeInOut(duration: 0.15), value: profileEnvironment.extensionManager.isLoadingExtensions)
    }
}

struct ExtensionToolbarItemView: View {
    let context: WKWebExtensionContext
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var profileEnvironment: ProfileEnvironment

    @State private var isShowingPopup = false
    @State private var badgeText: String?
    @State private var icon: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button {
            let action = context.action(for: tabManager.activeTab)
            if action?.presentsPopup == true {
                isShowingPopup.toggle()
            } else {
                context.performAction(for: tabManager.activeTab)
            }
        } label: {
            buttonLabel
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(context.webExtension.displayName ?? "Extension")
        .popover(isPresented: $isShowingPopup, arrowEdge: .bottom) {
            if let action = context.action(for: tabManager.activeTab),
               let popupWebView = action.popupWebView {
                ExtensionPopupView(action: action, popupWebView: popupWebView)
            }
        }
        .onChange(of: isShowingPopup) { _, isShowing in
            if !isShowing {
                context.action(for: tabManager.activeTab)?.closePopup()
            }
        }
        .onAppear(perform: updateActionState)
        .onReceive(profileEnvironment.extensionManager.actionChanges) { updatedContext, updatedTab in
            guard updatedContext === context else { return }
            guard updatedTab == nil || updatedTab === tabManager.activeTab else { return }
            updateActionState()
        }
        .onChange(of: tabManager.activeTabID) { _, _ in
            updateActionState()
        }
    }

    private var buttonLabel: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                }
            }

            if let badge = badgeText, !badge.isEmpty {
                badgeView(badge)
            }
        }
        .frame(width: 28, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.secondary.opacity(0.18) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .contentShape(Rectangle())
    }

    private func badgeView(_ text: String) -> some View {
        Text(text.count > 3 ? "…" : text)   // cap runaway badge text
            .font(.system(size: 7.5, weight: .bold, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 3)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.red))
            .foregroundColor(.white)
            .offset(x: 5, y: 5)
    }

    private func updateActionState() {
        let action = context.action(for: tabManager.activeTab)
        icon      = action?.icon(for: CGSize(width: 16, height: 16))
        badgeText = action?.badgeText
    }
}

// MARK: - Popup presentation

struct ExtensionPopupView: View {
    let action: WKWebExtension.Action
    let popupWebView: WKWebView

    var body: some View {
        ExtensionPopupWebViewRepresentable(popupWebView: popupWebView)
    }
}

final class ExtensionPopupHostingView: NSView {
    let webView: WKWebView

    init(webView: WKWebView, initialSize: NSSize) {
        self.webView = webView
        super.init(frame: NSRect(origin: .zero, size: initialSize))
        wantsLayer = true
        webView.wantsLayer = true
        webView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        webView.frame = bounds
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        webView.frame = bounds
        window.recalculateKeyViewLoop()
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }
}

struct ExtensionPopupWebViewRepresentable: NSViewRepresentable {
    let popupWebView: WKWebView

    private var initialSize: CGSize {
        let intrinsic = popupWebView.intrinsicContentSize
        if intrinsic.width > 0, intrinsic.height > 0 { return clamp(intrinsic) }
        return CGSize(width: 320, height: 400)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: NSViewRepresentableContext<Self>) -> ExtensionPopupHostingView {
        let host = ExtensionPopupHostingView(webView: popupWebView,
                                             initialSize: NSSizeFromCGSize(initialSize))
        context.coordinator.startObserving(popupWebView, host: host)
        return host
    }

    func updateNSView(_ host: ExtensionPopupHostingView,
                      context: NSViewRepresentableContext<Self>) {}

    private func clamp(_ size: CGSize) -> CGSize {
        CGSize(width:  min(max(size.width,  180), 800),
               height: min(max(size.height, 100), 700))
    }

    final class Coordinator: NSObject {
        private var observation: NSKeyValueObservation?

        func startObserving(_ webView: WKWebView, host: ExtensionPopupHostingView) {
            observation = webView.observe(\.intrinsicContentSize, options: [.new]) { [weak host] wv, _ in
                let size = wv.intrinsicContentSize
                guard size.width > 0, size.height > 0 else { return }
                let w = min(max(size.width,  180), 800)
                let h = min(max(size.height, 100), 700)
                DispatchQueue.main.async {
                    guard let host else { return }
                    let newSize = NSSize(width: w, height: h)
                    guard host.frame.size != newSize else { return }
                    host.setFrameSize(newSize)
                    host.webView.frame = host.bounds
                    if let win = host.window {
                        var frame = win.frame
                        frame.size = newSize
                        win.setFrame(frame, display: true, animate: false)
                    }
                }
            }
        }

        deinit { observation?.invalidate() }
    }
}
