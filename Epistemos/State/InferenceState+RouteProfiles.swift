import Foundation

// MARK: - InferenceState.routeProfiles (Phase 2 Terminal T1 — 2026-05-24)
//
// The Phase 2 spec (`docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md`
// §Terminal 1, acceptance gate) requires
// `InferenceState.routeProfiles()` to return ≥ 6 non-empty per-role
// profiles (code · reasoning · quick · toolCaller · trivial · vision).
//
// The previous incarnation on `ConfidenceRouter.routeProfiles()`
// (Epistemos/LocalAgent/ConfidenceRouter.swift:99) returns `[]` as a
// salvage placeholder. The new multi-lane router
// (`Epistemos/LocalAgent/RuntimeRouter.swift`) owns the lane-aware
// profile data; this extension is the InferenceState-namespaced
// surface the diagnostics layer reads.
//
// Lives in its own file to keep the 5,451-line `InferenceState.swift`
// hub untouched while still exposing the symbol on the type.

nonisolated extension InferenceState {
    /// **Acceptance gate (Phase 2 Terminal T1 — 2026-05-24):** returns
    /// the canonical per-role routing profiles published by the
    /// multi-lane `RuntimeRouter`. Always returns ≥ 6 non-empty rows —
    /// one per `RuntimeRole` (code · reasoning · quick · toolCaller ·
    /// trivial · vision). The data is sourced from
    /// `RuntimeRouter.defaultRouteProfiles()` so the InferenceState
    /// surface and the router-owned surface cannot drift.
    static func routeProfiles() -> [RouteProfile] {
        RuntimeRouter.defaultRouteProfiles()
    }
}
