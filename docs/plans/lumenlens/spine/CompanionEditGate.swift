//
//  CompanionEditGate.swift
//  Epistemos — LUMENLENS spine (authored from Spine S1 + amendment L1)
//
//  The gating keystone for the KINDRED companion-edit layer. Mirrors — and is
//  subordinate to — KEELSTONE's AppSurface schema:
//
//    EPISTEMOS_APP_STORE      → June / MAS        (NO companion, ever)
//    EPISTEMOS_EXPERIMENTAL   → 1Code             (companion allowed)
//    KINDRED_ENABLED          → feature flag, defined ONLY alongside
//                               EPISTEMOS_EXPERIMENTAL on the Epistemos target
//
//  Wiring rule (project.yml): add KINDRED_ENABLED to the Epistemos target's
//  SWIFT_ACTIVE_COMPILATION_CONDITIONS (all its configs), NEVER to
//  Epistemos-AppStore, NEVER to shared base ($(inherited) would leak it — the
//  exact ghost-surface mechanism KEELSTONE §6 kills).
//
//  ⚠️ The research draft's guard `#if !KINDRED_ENABLED && <companion symbol>`
//  is NOT valid Swift — #if conditions test flags, not symbols. The correct,
//  repo-proven pattern (see ExperimentalRuntimeSupervisor.swift:1):
//    1. Every companion-edit source file is WRAPPED in `#if KINDRED_ENABLED`.
//    2. This file carries the combo #errors below.
//    3. CI row B builds Epistemos-AppStore and asserts zero companion symbols
//       in the binary (nm/strings scan) — the leak DETECTOR, not just intent.
//

import Foundation

// Guard 1 — the companion can never ride into the MAS surface.
#if KINDRED_ENABLED && EPISTEMOS_APP_STORE
#error("""
LUMENLENS: KINDRED_ENABLED must never be defined together with \
EPISTEMOS_APP_STORE. The companion-edit layer is Experimental/1Code-only. \
Check SWIFT_ACTIVE_COMPILATION_CONDITIONS — the flag has leaked into the \
AppStore target or shared base settings.
""")
#endif

// Guard 2 — the flag is subordinate to the surface: KINDRED requires the
// Experimental surface. A KINDRED-without-surface build is a config error.
#if KINDRED_ENABLED && !EPISTEMOS_EXPERIMENTAL
#error("""
LUMENLENS: KINDRED_ENABLED requires EPISTEMOS_EXPERIMENTAL. The companion \
feature flag is defined on a target that is not the Experimental surface.
""")
#endif

/// Runtime capability mirror — UI-affordance ONLY. Derived from the compile
/// flag; never an independent source of truth (Spine S1.5). SwiftUI uses this
/// to hide companion affordances; the compiler has already removed the code.
public enum CompanionEditCapabilities {
    /// True only in KINDRED-enabled (1Code/Experimental) builds.
    public static var companionAvailable: Bool {
        #if KINDRED_ENABLED
        return true
        #else
        return false
        #endif
    }
}
