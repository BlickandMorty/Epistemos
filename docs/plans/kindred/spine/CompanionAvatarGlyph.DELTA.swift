// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA over the LIVE Farm file of the same name (Epistemos/Views/Landing/Farm/ has 8 live files
// incl. CompanionRoamingField + Delete/Restore sheets). Extend in place; the Rive render path
// replaces the glyph INTERNALS, not the view seams. rive-ios is NOT yet a dependency — add the
// RiveRuntime SPM product to project.yml packages and attach it to the EPISTEMOS TARGET ONLY
// (never Epistemos-AppStore), then xcodegen generate.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  CompanionAvatarGlyph.swift
//  EPI-RP-05-KINDRED · D4b mascot render, NATIVE path (BINDING: Rive)
//
//  Native render path = rive-ios (RiveViewModel + data binding). The WebView path uses the
//  SAME companion.riv via @rive-app/canvas, so the creature is visually identical across
//  both. Rive's vector rig kills the demo-grade artifacts (seams, sub-pixel misalignment,
//  transform-origin drift, HiDPI jaggies) that a layered-PNG compositor produces.

#if KINDRED_ENABLED
import SwiftUI
// import RiveRuntime   // TODO: add the rive-ios SwiftPM dependency (confirm licensing — open Q)

struct CompanionAvatarGlyph: View {
    let bodyKind: String
    let animation: CompanionAnimationState

    var body: some View {
        // TODO: RiveViewModel(fileName: "companion", stateMachineName: bodyKind)
        //         .view()
        //         .onChange(of: animation) { _, new in
        //             viewModel.setInput(new.riveInput, value: true)  // bind emote -> rig
        //         }
        // Placeholder until the rig is wired:
        Circle()
            .fill(Color.accentColor.opacity(animation == .idle ? 0.2 : 0.5))
    }
}
#endif
