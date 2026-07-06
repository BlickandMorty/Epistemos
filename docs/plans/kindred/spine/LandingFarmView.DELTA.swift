// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA over the LIVE Farm file of the same name (Epistemos/Views/Landing/Farm/ has 8 live files
// incl. CompanionRoamingField + Delete/Restore sheets). Extend in place; the Rive render path
// replaces the glyph INTERNALS, not the view seams. rive-ios is NOT yet a dependency — add the
// RiveRuntime SPM product to project.yml packages and attach it to the EPISTEMOS TARGET ONLY
// (never Epistemos-AppStore), then xcodegen generate.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  LandingFarmView.swift
//  EPI-RP-05-KINDRED · the roster (BINDING)
//
//  The Farm: the tamagotchi roster the owner watches. Keeps the existing stub + the `+`
//  affordance. Landing is view/select/query (handoff option "c" — see D5 open question);
//  the `+` deep-links into the 1Code creator. Select-to-query opens a minimal relay chat.

#if KINDRED_ENABLED
import SwiftUI

struct LandingFarmView: View {
    let companions: [CompanionModel]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                ForEach(companions.filter(\.isActive), id: \.identityHash) { companion in
                    CompanionView(companion: companion)
                }
                CreateCompanionAffordance()   // the `+`
            }
            .padding()
        }
    }
}

/// The `+` cell. Deep-links into the 1Code creator (D5 recommendation: 1Code-primary).
private struct CreateCompanionAffordance: View {
    var body: some View {
        Button {
            // TODO: deep-link into the 1Code "Create Companion" flow.
        } label: {
            Image(systemName: "plus")
                .frame(width: 96, height: 96)
        }
        .buttonStyle(.plain)
    }
}
#endif
