//
//  Toast.swift
//  Illuminate
//
//  Created by MrBlankCoding on 9/5/26.
//

import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let message: String
    let duration: TimeInterval

    init(icon: String, message: String, duration: TimeInterval = 1.6) {
        self.icon = icon
        self.message = message
        self.duration = duration
    }
}

@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var current: Toast?

    func show(_ toast: Toast) {
        current = toast
    }

    func dismiss() {
        current = nil
    }
}

extension Notification.Name {
    static let showToast = Notification.Name("app.showToast")
}

enum ToastEvent {
    static func post(icon: String, message: String, duration: TimeInterval = 1.6) {
        let toast = Toast(icon: icon, message: message, duration: duration)
        NotificationCenter.default.post(name: .showToast, object: toast)
    }
}

struct ToastOverlay: View {
    @State private var toast: Toast?
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let toast {
                ToastBubble(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast?.id)
        .onReceive(NotificationCenter.default.publisher(for: .showToast)) { output in
            guard let next = output.object as? Toast else { return }
            present(next)
        }
    }

    private func present(_ next: Toast) {
        dismissTask?.cancel()
        toast = next
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(next.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if toast?.id == next.id { toast = nil }
        }
    }
}

private struct ToastBubble: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(false), in: .capsule)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(.top, 14)
    }
}
