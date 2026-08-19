//
//  OnboardingView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 4/1/26.
//

import SwiftUI

struct OnboardingView: View {
    static let windowID = "onboarding-window"

    private struct Step: Identifiable {
        let id: Int
        let symbol: String
        let title: String
        let summary: String
        let highlights: [Highlight]
    }

    private struct Highlight: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private static let steps = [
        Step(
            id: 0,
            symbol: "safari",
            title: "Welcome to Illuminate",
            summary: "A focused browser built around the way you already work on your Mac.",
            highlights: [
                Highlight(symbol: "square.stack.3d.up", title: "Tabs that stay organized",
                          detail: "Create, group, and reopen tabs without losing your place."),
                Highlight(symbol: "person.crop.circle.badge.checkmark", title: "Profiles and private windows",
                          detail: "Keep browsing contexts separate when you need to.")
            ]
        ),
        Step(
            id: 1,
            symbol: "rectangle.on.rectangle",
            title: "Move quickly between tabs",
            summary: "Use the shortcuts below to keep your hands on the keyboard.",
            highlights: [
                Highlight(symbol: "arrow.uturn.backward", title: "Switch to your last tab",
                          detail: "Press ⌃⇥ to return to the most recently used tab. Press it again to switch back."),
                Highlight(symbol: "arrow.up.arrow.down", title: "Cycle through tabs",
                          detail: "Press ⌘↓ or ⌘↑ to move forward or backward through open tabs.")
            ]
        ),
        Step(
            id: 2,
            symbol: "command",
            title: "Navigate and share",
            summary: "A few shortcuts cover the actions you use most often.",
            highlights: [
                Highlight(symbol: "location.magnifyingglass", title: "Focus the address bar",
                          detail: "Press ⌘L to start typing a new address or search."),
                Highlight(symbol: "doc.on.clipboard", title: "Copy the current URL",
                          detail: "Press ⌘⇧C to copy the active page address to the clipboard."),
                Highlight(symbol: "questionmark.circle", title: "Find more shortcuts",
                          detail: "Open Settings → Shortcuts whenever you need a refresher.")
            ]
        )
    ]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss
    @Namespace private var stepTransition
    @State private var currentStep = 0
    @State private var direction: Edge = .trailing

    private var isLastStep: Bool {
        currentStep == Self.steps.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                stepContent(Self.steps[currentStep])
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: direction).combined(with: .opacity),
                        removal: .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
            .frame(maxHeight: .infinity)

            progressDots
                .padding(.bottom, 28)

            Divider()

            controls
        }
        .frame(width: 560, height: 480)
        .background(.ultraThinMaterial)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Self.steps) { step in
                Capsule()
                    .fill(step.id == currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: step.id == currentStep ? 24 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStep)
                    .onTapGesture { goTo(step.id) }
                    .accessibilityLabel("Step \(step.id + 1) of \(Self.steps.count)")
            }
        }
    }

    private var controls: some View {
        HStack {
            Button("Skip", action: finish)
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Spacer()

            if currentStep > 0 {
                Button("Back") { goTo(currentStep - 1) }
                    .buttonStyle(.bordered)
            }

            Button(isLastStep ? "Get Started" : "Continue") {
                if isLastStep {
                    finish()
                } else {
                    goTo(currentStep + 1)
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(24)
    }

    private func stepContent(_ step: Step) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: step.symbol)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.tint)
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(step.title)
                    .font(.title.bold())
                Text(step.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(step.highlights) { highlight in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: highlight.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 28, height: 28)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(highlight.title)
                                .font(.headline)
                            Text(highlight.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
            .padding(20)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 40)
        .padding(.top, 44)
        .padding(.bottom, 8)
    }

    private func goTo(_ step: Int) {
        direction = step >= currentStep ? .trailing : .leading
        currentStep = step
    }

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }
}