// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA over the LIVE Farm file of the same name (Epistemos/Views/Landing/Farm/ has 8 live files
// incl. CompanionRoamingField + Delete/Restore sheets). Extend in place; the Rive render path
// replaces the glyph INTERNALS, not the view seams. rive-ios is NOT yet a dependency — add the
// RiveRuntime SPM product to project.yml packages and attach it to the EPISTEMOS TARGET ONLY
// (never Epistemos-AppStore), then xcodegen generate.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  CompanionView.swift
//  EPI-RP-05-KINDRED · a single roster cell (BINDING)
//
//  One companion in the Farm. Shows the mascot (Rive), its name, and its "currently
//  <doing X>" line pulled from live presence — e.g. "editing daily-note.md".

#if KINDRED_ENABLED
import SwiftUI

struct CompanionView: View {
    let companion: CompanionModel

    // One presence consumer per visible companion; driven by agent_core.
    @State private var state = CompanionState()

    var body: some View {
        VStack(spacing: 6) {
            CompanionAvatarGlyph(bodyKind: companion.bodyKind, animation: state.animation)
                .frame(width: 96, height: 96)

            Text(companion.name).font(.caption).lineLimit(1)

            if let note = state.presence?.noteId {
                Text("editing \(note)").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(companion.tagline).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .onTapGesture {
            // TODO: open the profile + the minimal select-to-query relay chat.
        }
    }
}
#endif
