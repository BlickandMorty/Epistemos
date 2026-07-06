// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// THIS IS THE v1 PRESENCE HUB (placement amendment: Swift, not agent_core). It consumes:
//  (a) /host ws frames — add case "presence:state" to ExperimentalHostBridge.handle(kind:) (:84);
//      frames are app-global, which is correct: presence IS app-global.
//  (b) native events (KEELSTONE reconcile states).
// It fans out to: SwiftUI (roster, Epdoc bubble) directly, and BOTH WebViews via per-webview
// bridge routing — NOTE: ExperimentalStateBridge.shared.webView is a SINGLE weak ref today
// (last-set wins, ExperimentalStateBridge.swift:22); the minichat requires per-webview routing
// (registry keyed by webview identity) — K6 work item. Clock guard: apply iff clock strictly
// greater (Yjs rule). DTO mirrors the wire schema in presence.rs/presence-bridge.ts.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  CompanionState.swift
//  EPI-RP-05-KINDRED · D3 presence consumer (BINDING)
//
//  The native @Observable sink for a companion's live presence. Receives CompanionPresence
//  from agent_core over a UniFFI foreign-trait callback, applies the clock guard, and drives
//  the mascot's emote. Also forwards presence into the WebView (main chat + minichat).
//
//  Platform hygiene: @Observable (NOT ObservableObject). The UniFFI callback lands on a
//  Rust thread — we hop DispatchQueue.main.async (NEVER .sync; a .sync hop can deadlock).

#if KINDRED_ENABLED
import Foundation
import Observation

/// Swift mirror of agent_core::companion::CompanionPresence (marshalled via UniFFI).
struct CompanionPresenceDTO {
    let companionId: String
    let emote: String
    let clock: UInt64
    let noteId: String?
    let range: ClosedRange<Int>?
}

@Observable
final class CompanionState {

    private(set) var presence: CompanionPresenceDTO?
    private(set) var animation: CompanionAnimationState = .idle

    /// UniFFI foreign-trait callback entrypoint. Called off the Rust thread.
    func onPresence(_ dto: CompanionPresenceDTO) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Clock guard (Yjs rule): apply iff strictly newer than what we have.
            guard dto.clock > (self.presence?.clock ?? 0) else { return }

            self.presence = dto

            // Skin-over-real-state: only adopt an emote that has a backing case; else keep last.
            if let next = CompanionAnimationState.from(wire: dto.emote) {
                self.animation = next
            }

            // TODO: forward dto into the WebView bridge (presence-bridge.ts) so the main chat
            //       and the Epdoc minichat show the same identity in lock-step.
        }
    }

    // TODO: register self as a PresenceSink via the UniFFI registration call at startup.
}
#endif
