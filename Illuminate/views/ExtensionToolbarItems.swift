//
//  ExtensionToolbarItems.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
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
                        .transition(AnyTransition.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75),
                   value: enabledExtensions.map(\.uniqueIdentifier))
        .animation(.easeInOut(duration: 0.15),
                   value: profileEnvironment.extensionManager.isLoadingExtensions)
    }
}

struct ExtensionToolbarItemView: View {
    let context: WKWebExtensionContext
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @EnvironmentObject var popupCoordinator: ExtensionPopupCoordinator

    @State private var badgeText: String?
    @State private var icon: NSImage?
    @State private var isHovered = false

    private var isShowingPopup: Bool {
        guard let active = popupCoordinator.activePopup else { return false }
        return active.extensionName == context.webExtension.displayName
    }

    var body: some View {
        GeometryReader { geo in
            Button {
                handleTap(buttonFrame: geo.frame(in: .named("browserWindow")))
            } label: {
                buttonLabel
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help(context.webExtension.displayName ?? "Extension")
        }
        .frame(width: 28, height: 28)
        .onAppear(perform: updateActionState)
        .onReceive(profileEnvironment.extensionManager.actionChanges) { updatedContext, updatedTab in
            guard updatedContext === context else { return }
            guard updatedTab == nil || updatedTab === tabManager.activeTab else { return }
            updateActionState()
        }
        .onChange(of: tabManager.activeTabID) { _, _ in updateActionState() }
    }

    private func handleTap(buttonFrame: CGRect) {
        let action = context.action(for: tabManager.activeTab)
        if isShowingPopup {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                popupCoordinator.close()
                action?.closePopup()
            }
            return
        }
        popupCoordinator.close()
        guard action?.presentsPopup == true, let popupWebView = action?.popupWebView else {
            context.performAction(for: tabManager.activeTab)
            return
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            popupCoordinator.open(.init(
                popupWebView: popupWebView,
                extensionName: context.webExtension.displayName,
                anchorX: buttonFrame.midX
            ))
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
                .fill(isHovered || isShowingPopup ? Color.secondary.opacity(0.18) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isShowingPopup)
        .contentShape(Rectangle())
    }

    private func badgeView(_ text: String) -> some View {
        Text(text.count > 3 ? "…" : text)
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

struct ExtensionPopupPanel: View {
    let payload: ExtensionPopupCoordinator.PopupPayload
    let windowWidth: CGFloat
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var profileEnvironment: ProfileEnvironment
    @EnvironmentObject var popupCoordinator: ExtensionPopupCoordinator

    @State private var contentSize: CGSize = CGSize(width: 320, height: 400)

    private let headerHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 12
    private let panelMargin: CGFloat  = 6
    private let edgePad: CGFloat      = 8

    private var panelWidth:  CGFloat { contentSize.width }
    private var panelHeight: CGFloat { contentSize.height + headerHeight }
    private var panelLeading: CGFloat {
        let ideal = payload.anchorX - panelWidth / 2
        let maxX  = windowWidth - panelWidth - edgePad
        return min(max(edgePad, ideal), maxX)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer().frame(width: panelLeading)

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if let name = payload.extensionName {
                        Text(name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            popupCoordinator.close()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.horizontal, 10)
                .frame(height: headerHeight)

                Divider().opacity(0.4)

                ExtensionPopupWebViewRepresentable(
                    popupWebView: payload.popupWebView,
                    tabManager: tabManager,
                    contentSize: $contentSize,
                    onDismiss: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            popupCoordinator.close()
                        }
                    }
                )
                .frame(width: contentSize.width, height: contentSize.height)
            }
            .frame(width: panelWidth, height: panelHeight, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 6)
            .padding(.top, panelMargin)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onKeyPress(.escape) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                popupCoordinator.close()
            }
            return .handled
        }
    }
}

final class ExtensionPopupHostingView: NSView {
    let webView: WKWebView

    init(webView: WKWebView, size: NSSize) {
        self.webView = webView
        super.init(frame: NSRect(origin: .zero, size: size))
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
        webView.frame = bounds
        DispatchQueue.main.async { [weak self] in
            self?.window?.recalculateKeyViewLoop()
        }
    }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }
}

struct ExtensionPopupWebViewRepresentable: NSViewRepresentable {
    let popupWebView: WKWebView
    let tabManager: TabManager
    @Binding var contentSize: CGSize
    var onDismiss: (() -> Void)?

    // TODO 
    // simplify
    private static let fallbackSize = CGSize(width: 320, height: 400)
    private static let minW: CGFloat = 100
    private static let minH: CGFloat = 60
    private static let maxW: CGFloat = 800
    private static let maxH: CGFloat = 700

    func makeCoordinator() -> Coordinator {
        Coordinator(tabManager: tabManager, contentSize: $contentSize, onDismiss: onDismiss)
    }

    func makeNSView(context: NSViewRepresentableContext<Self>) -> ExtensionPopupHostingView {
        let host = ExtensionPopupHostingView(
            webView: popupWebView,
            size: NSSizeFromCGSize(Self.fallbackSize)
        )
        let coordinator = context.coordinator
        coordinator.host = host
        if popupWebView.configuration.userContentController
            .value(forKey: "userScripts") != nil || true {
            try? popupWebView.configuration.userContentController
                .removeScriptMessageHandler(forName: "popupSize")
        }
        popupWebView.configuration.userContentController
            .add(WeakMessageHandler(coordinator), name: "popupSize")

        popupWebView.navigationDelegate = coordinator
        popupWebView.uiDelegate         = coordinator
        coordinator.measurePageSize()

        return host
    }

    func updateNSView(_ host: ExtensionPopupHostingView,
                      context: NSViewRepresentableContext<Self>) {
        let target = NSSizeFromCGSize(contentSize)
        if host.frame.size != target {
            host.setFrameSize(target)
            host.webView.frame = host.bounds
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
                              WKScriptMessageHandler {
        let tabManager: TabManager
        @Binding var contentSize: CGSize
        let onDismiss: (() -> Void)?
        weak var host: ExtensionPopupHostingView?

        init(tabManager: TabManager,
             contentSize: Binding<CGSize>,
             onDismiss: (() -> Void)?) {
            self.tabManager   = tabManager
            self._contentSize = contentSize
            self.onDismiss    = onDismiss
        }

        func measurePageSize() {
            guard let wv = host?.webView else { return }
            let js = """
            (function() {
                function report() {
                    var el = document.documentElement;
                    var w = Math.max(el.scrollWidth, el.offsetWidth,  el.clientWidth);
                    var h = Math.max(el.scrollHeight, el.offsetHeight, el.clientHeight);
                    if (w > 0 && h > 0) {
                        window.webkit.messageHandlers.popupSize.postMessage({w: w, h: h});
                    }
                }
                report();
                if (window.__illuminateResizeObserver) {
                    window.__illuminateResizeObserver.disconnect();
                }
                window.__illuminateResizeObserver = new ResizeObserver(function() { report(); });
                window.__illuminateResizeObserver.observe(document.documentElement);
            })();
            """
            wv.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ ucc: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            guard message.name == "popupSize",
                  let body = message.body as? [String: Any],
                  let w = body["w"] as? CGFloat,
                  let h = body["h"] as? CGFloat,
                  w > 0, h > 0
            else { return }

            let clamped = CGSize(
                width:  min(max(w, 100), 800),
                height: min(max(h,  60), 700)
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.contentSize != clamped {
                    self.contentSize = clamped
                }
                if let host = self.host, host.frame.size != NSSizeFromCGSize(clamped) {
                    host.setFrameSize(NSSizeFromCGSize(clamped))
                    host.webView.frame = host.bounds
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measurePageSize()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                decisionHandler(.cancel)
                DispatchQueue.main.async { [weak self] in self?.openInNewTab(url: url) }
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                DispatchQueue.main.async { [weak self] in self?.openInNewTab(url: url) }
            }
            return nil
        }

        @MainActor
        private func openInNewTab(url: URL) {
            tabManager.createTab(url: url)
            onDismiss?()
        }
    }
}

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (AnyObject & WKScriptMessageHandler)?
    init(_ target: AnyObject & WKScriptMessageHandler) { self.target = target }

    func userContentController(_ ucc: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        target?.userContentController(ucc, didReceive: message)
    }
}
