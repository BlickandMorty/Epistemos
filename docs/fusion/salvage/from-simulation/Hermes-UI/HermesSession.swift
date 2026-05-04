//
//  HermesSession.swift
//  Simulation Mode S9 — Swift state holder pairing the
//  registry-side Hermes companion with the active landing-ritual
//  / chat surface state.
//
//  Per DOCTRINE §8.1 the graph faculty is privileged + singular.
//  This struct owns the in-flight pairing (companion id ↔ ritual
//  view state) so the host view can resume / dismiss the ritual
//  cleanly.
//
//  The actual session lifecycle (SessionStarted / Completed
//  events, conflict detection vs. another Hermes companion)
//  lives Rust-side in `agent_core::hermes::HermesSession`. This
//  Swift holder is the UI-side companion to that Rust authority.
//

import Foundation
import Observation

/// One in-flight Hermes session bound to the visible ritual.
///
/// Lifecycle:
///   1. Host calls `HermesSessionHolder.begin(name:)` —
///      runs `epistemos_companions_create_hermes` (registry
///      transaction) + AppKit-side opens the ritual view.
///   2. The 7-phase ritual plays (§8.2.2). When phase 7
///      completes, `onRitualComplete` fires.
///   3. Host calls `end()` to clean up.
///
/// Pre-S5.7 the actual SessionStarted/Completed wire-up to the
/// Rust `agent_core::hermes::HermesSession` happens via
/// `processEventJson` on the simulation handle (the host owns
/// the simulation handle separately from the registry handle).
@MainActor
@Observable
public final class HermesSessionHolder {
    /// Companion id minted by the registry transaction. `nil`
    /// before `begin(name:)` succeeds.
    public private(set) var companionId: CompanionId?

    /// `true` while the 7-phase ritual is animating; `false`
    /// before `begin(name:)` and after `onRitualComplete` fires.
    public private(set) var ritualInProgress: Bool = false

    /// `true` once the chat surface has emerged. The host can
    /// gate input on this so the user doesn't type during the
    /// opulent treatment.
    public private(set) var chatReady: Bool = false

    /// Surfaced if creation fails — the registry / transaction
    /// returned a typed error and the ritual was never started.
    public private(set) var lastError: String?

    private let bridge: CompanionRegistryBridge

    public init(bridge: CompanionRegistryBridge) {
        self.bridge = bridge
    }

    /// Begin a Hermes faculty session: create the companion via
    /// the registry transaction, then start the ritual. The
    /// caller observes `ritualInProgress` / `chatReady` to drive
    /// its UI.
    public func begin(name: String) async {
        lastError = nil
        do {
            let entry = try await bridge.createHermes(name: name)
            companionId = entry.id
            ritualInProgress = true
        } catch {
            lastError = "\(error)"
        }
    }

    /// Called by the ritual view when phase 7 (chat surface
    /// emerged) completes. Hands control back to the host.
    public func ritualDidComplete() {
        ritualInProgress = false
        chatReady = true
    }

    /// End the session. Doesn't archive the companion — it
    /// stays in the registry so the user can re-summon Hermes
    /// (the second `⌘⇧H` press resumes the same companion).
    public func end() {
        ritualInProgress = false
        chatReady = false
    }

    /// Reset for a fresh session (used by the preview shell to
    /// re-trigger the ritual without re-creating the companion).
    public func resetForReplay() {
        ritualInProgress = false
        chatReady = false
        lastError = nil
        // companionId intentionally retained.
    }
}
