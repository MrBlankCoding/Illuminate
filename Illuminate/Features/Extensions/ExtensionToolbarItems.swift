//
//  ExtensionToolbarItems.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import WebKit

struct ExtensionToolbarItems: View {
    @Environment(ProfileEnvironment.self) var profileEnvironment: ProfileEnvironment

    private var filteredExtensions: [WKWebExtensionContext] {
        profileEnvironment.extensionManager.installedExtensions.filter { context in
            profileEnvironment.extensionManager.isEnabled(context) &&
            profileEnvironment.extensionManager.isPinned(context)
        }
    }

    var body: some View {
        HStack(spacing: MacDesign.Spacing.micro) {
            if profileEnvironment.extensionManager.isLoadingExtensions {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: MacDesign.Spacing.roomy, height: MacDesign.Spacing.roomy)
                    .transition(.opacity)
            } else {
                ForEach(filteredExtensions, id: \.self) { context in
                    ExtensionToolbarItemView(context: context)
                        .transition(AnyTransition.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .animation(MacDesign.springAnimation,
                   value: filteredExtensions.map(\.uniqueIdentifier))
        .animation(MacDesign.fastAnimation,
                   value: profileEnvironment.extensionManager.isLoadingExtensions)
    }
}

struct ExtensionToolbarItemView: View {
    let context: WKWebExtensionContext
    @Environment(TabManager.self) var tabManager: TabManager
    @Environment(ProfileEnvironment.self) var profileEnvironment: ProfileEnvironment
    @Environment(ExtensionPopupCoordinator.self) var popupCoordinator: ExtensionPopupCoordinator

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
        .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
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
            withAnimation(MacDesign.popupAnimation) {
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
        withAnimation(MacDesign.popupAnimation) {
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
                        .frame(width: MacDesign.Spacing.roomy, height: MacDesign.Spacing.roomy)
                } else {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.webCaption)
                        .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)
                }
            }
            if let badge = badgeText, !badge.isEmpty {
                badgeView(badge)
            }
        }
        .frame(width: MacDesign.Size.iconButton, height: MacDesign.Size.iconButton)
        .background(
            RoundedRectangle(cornerRadius: MacDesign.Radius.groupHeader, style: .continuous)
                .fill(isHovered || isShowingPopup ? Color.textSecondary.opacity(0.18) : Color.clear)
        )
        .animation(MacDesign.fastAnimation, value: isHovered)
        .animation(MacDesign.fastAnimation, value: isShowingPopup)
        .contentShape(Rectangle())
    }

    private func badgeView(_ text: String) -> some View {
        Text(text.count > 3 ? "…" : text)
            .font(.webBadge)
            .lineLimit(1)
            .padding(.horizontal, MacDesign.Spacing.tiny)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.red))
            .foregroundColor(.white)
            .offset(x: MacDesign.Spacing.mini, y: MacDesign.Spacing.mini)
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
    @Environment(TabManager.self) var tabManager: TabManager
    @Environment(ProfileEnvironment.self) var profileEnvironment: ProfileEnvironment
    @Environment(ExtensionPopupCoordinator.self) var popupCoordinator: ExtensionPopupCoordinator

    @State private var contentSize: CGSize = CGSize(width: 320, height: 400)

    private let headerHeight: CGFloat = MacDesign.Size.largeIconButton
    private let cornerRadius: CGFloat = MacDesign.Radius.medium
    private let panelMargin: CGFloat  = MacDesign.Spacing.tight
    private let edgePad: CGFloat      = MacDesign.Spacing.control

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
                HStack(spacing: MacDesign.Spacing.tight) {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.webSmall)
                        .foregroundStyle(.tertiary)
                    if let name = payload.extensionName {
                        Text(name)
                            .font(.webSmallRegularMedium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(MacDesign.popupAnimation) {
                            popupCoordinator.close()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.webTinyBold)
                            .foregroundStyle(.secondary)
                            .frame(width: MacDesign.Spacing.roomy, height: MacDesign.Spacing.roomy)
                            .background(Circle().fill(Color.textSecondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.horizontal, MacDesign.Spacing.medium)
                .frame(height: headerHeight)

                Divider().opacity(0.4)

                ExtensionPopupWebViewRepresentable(
                    popupWebView: payload.popupWebView,
                    tabManager: tabManager,
                    contentSize: $contentSize,
                    onDismiss: {
                        withAnimation(MacDesign.popupAnimation) {
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
                            .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: MacDesign.Spacing.tight)
            .padding(.top, panelMargin)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onKeyPress(.escape) {
            withAnimation(MacDesign.popupAnimation) {
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
            popupWebView.configuration.userContentController
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
