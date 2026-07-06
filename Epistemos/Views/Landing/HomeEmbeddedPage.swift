import SwiftUI

/// Wraps a feature surface (Meeting, arXiv, Browser, and related rooms) embedded as a PAGE
/// inside the home window — the owner's "press a feature → it animates to a page
/// in the home window, like the old chat" model.
///
/// Owner request 2026-07-03: the shared floating "← Home" back chip that used to
/// live here was RETIRED. Each surface now provides its OWN in-toolbar Home button
/// — arXiv and meeting (the meeting's carries the unsaved-transcript confirm) —
/// or none (the browser has no Home button, by design). This wrapper is now just
/// a consistent full-bleed frame around the embedded surface.
///
/// Notes / HTML-Workspace / editor deliberately DO NOT use this — they live in the
/// utility note-workspace window and are not home pages.
struct HomeEmbeddedPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
