import SwiftUI

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

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) { backChip }
    }

    @ViewBuilder
    private var backChip: some View {
        if title != "Goose" {
            legacyBackChipButton
        }
    }

    private var legacyBackChipButton: some View {
        Button {
            goHome()
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
    }

    private func goHome() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            ui.homeContent = .greeting
        }
    }
}
