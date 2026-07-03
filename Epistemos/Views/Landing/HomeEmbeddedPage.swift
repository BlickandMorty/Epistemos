import SwiftUI

/// Set by an embedded surface (e.g. the meeting page) to signal it currently
/// holds unsaved work. `HomeEmbeddedPage`'s back-to-home chip reads it and
/// confirms before tearing the surface down. Default `false` → no confirmation
/// (arXiv / browser have nothing to lose on navigation). MEET-4.
struct HomeEmbeddedLeaveGuardKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// Wraps a feature surface (Meeting, arXiv, Goose, …) embedded as a PAGE inside
/// the home window — the owner's "press a feature → it animates to a page in the
/// home window, like the old chat" model. Provides a lightweight, consistent
/// back-to-home affordance so every embedded surface returns the same way.
///
/// Notes / HTML-Workspace / editor deliberately DO NOT use this — they live in the
/// utility note-workspace window and are not home pages.
struct HomeEmbeddedPage<Content: View>: View {
    @Environment(UIState.self) private var ui
    let title: String
    @ViewBuilder var content: Content

    /// Presented when the embedded surface reports unsaved work via
    /// `HomeEmbeddedLeaveGuardKey` and the user taps the back chip (MEET-4).
    @State private var showingLeaveConfirmation = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlayPreferenceValue(HomeEmbeddedLeaveGuardKey.self) { needsLeaveConfirmation in
                backChip(needsLeaveConfirmation: needsLeaveConfirmation)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
    }

    @ViewBuilder
    private func backChip(needsLeaveConfirmation: Bool) -> some View {
        if title != "Goose" {
            legacyBackChipButton(needsLeaveConfirmation: needsLeaveConfirmation)
        }
    }

    private func legacyBackChipButton(needsLeaveConfirmation: Bool) -> some View {
        Button {
            // MEET-4: don't silently destroy an active recording / unsaved
            // transcript. Confirm first when the surface reports unsaved work.
            if needsLeaveConfirmation {
                showingLeaveConfirmation = true
            } else {
                goHome()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Home")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.leading, 14)
        .padding(.top, 12)
        .accessibilityLabel("Back to Home")
        .help("Back to Home (\(title))")
        .confirmationDialog(
            "Leave \(title)?",
            isPresented: $showingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave and Discard", role: .destructive) { goHome() }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("A recording or unsaved transcript is in progress on this page. Leaving will discard it.")
        }
    }

    private func goHome() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            ui.homeContent = .greeting
        }
    }
}
