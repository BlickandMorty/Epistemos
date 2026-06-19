import Foundation

/// Fix #2 STAGE 1 (research STOP_REINVENTING_AUDIT 2026-06-19 — `RuntimeRouter` is
/// BUILT but DEAD: `RuntimeRouter.route(_:)` has zero production callers, so the
/// live lane decision fell to crude heuristics; this is the audit's "Qwen-pin
/// root" at the LANE level). This is the SAFE first step toward wiring it: pure,
/// testable machinery to build a `MissionPacket` from a live chat request, extract
/// the chosen lane from a `RouteVerdict`, and compare it to the lane the live path
/// actually used — all behind a flag, all OBSERVE-ONLY (no behaviour change).
///
/// Staged rollout (each a separate flag-gated, build-verified, owner-confirmed slice):
/// - STAGE 1 (this): shadow machinery — build packet, extract lane, parity-compare.
/// - STAGE 1b: call it at the live lane-decision seam (`CommandCenterRequestCompiler`
///   `ResolvedRuntime`) behind `armed`, recording parity via `RuntimeRouterMetrics`,
///   returning the SAME lane (still observe-only).
/// - STAGE 2: promote — flag ON makes `route` authoritative for the lane.
/// - STAGE 3: fold R2 (`TriageService.preferredAutomaticLocalModel` priority list)
///   into the router's preference table; keep honest "no local → nil".
/// - STAGE 4: delete the dead R4 routers (`ConfidenceRouter`/`DualBrainRouter`/
///   `HybridRouter`) after rehosting the diagnostic `routeProfiles()` adapter.
///
/// NOTE `RuntimeRouter.route` is the intra-LANE chooser (which RUNTIME: mlx / gguf /
/// cloud / stub), NOT the model-id picker — so it does NOT replace the
/// `sanitizedInteractiveLocalTextModelID` model-pin fix (commit a645e6623); the two
/// are complementary (lane vs model-within-lane).
nonisolated enum RuntimeRouterShadow {
    /// `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`. OFF (default): the router is NOT consulted
    /// on the live path (today's behaviour, zero overhead). ON: the live path MAY
    /// compute the router's shadow verdict for parity logging (STAGE 1b) — still
    /// observe-only until STAGE 2 promotes it.
    static var armed: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_RUNTIMEROUTER_LIVE_V0"] == "1"
    }

    /// Map a chat operating mode to the router's role taxonomy. Pure.
    static func role(forOperatingMode mode: EpistemosOperatingMode) -> RuntimeRole {
        switch mode {
        case .fast: .quick
        case .thinking: .reasoning
        case .pro: .code
        case .agent: .toolCaller
        }
    }

    /// The lane a verdict resolves to: an `accept` yields its lane, an `escalate`
    /// yields its target lane (the router's next hop), a `reject` yields nil (no
    /// lane — an honest failure, never a silent fallback). Pure.
    static func acceptedLane(from verdict: RouteVerdict) -> RuntimeLane? {
        switch verdict {
        case .accept(let lane, _): lane
        case .escalate(_, let to, _): to
        case .reject: nil
        }
    }

    /// Whether the router's chosen lane matches the lane the live path used — the
    /// STAGE-1 parity signal. Compared by `stableID` so `cloud(provider:)` matches
    /// exactly. A nil router lane (reject) never matches a live lane. Pure.
    static func parityMatches(routerLane: RuntimeLane?, liveLane: RuntimeLane) -> Bool {
        routerLane?.stableID == liveLane.stableID
    }

    /// STAGE 1b — map the live `ResolvedBrainDescriptor` (what dispatch will
    /// actually run on, from `CommandCenterRequestCompiler.ResolvedRuntime`) to the
    /// `RuntimeLane` it represents, for the parity comparison against the router's
    /// verdict. `local` needs a mlx-vs-gguf classification — injected as a closure
    /// so the mapper stays PURE + unit-testable (the live caller passes the real
    /// `LocalTextModelID.runtimeKind` classifier); cloud + Apple Intelligence map
    /// directly; `unavailable` → nil (no lane — honest, never a silent fallback).
    static func liveLane(
        from resolved: ResolvedBrainDescriptor,
        localLaneForModelID: (String) -> RuntimeLane
    ) -> RuntimeLane? {
        switch resolved {
        case .local(let modelId, _): localLaneForModelID(modelId)
        case .appleIntelligence: .appleIntelligence
        case .cloud(let provider, _): .cloud(provider: provider)
        case .unavailable: nil
        }
    }

    /// Build a `MissionPacket` from the signals a live chat turn carries. Pure
    /// (maps inputs to the packet shape); STAGE 1b calls this then
    /// `router.route(packet)` behind `armed`.
    static func missionPacket(
        operatingMode: EpistemosOperatingMode,
        objective: String,
        requiresTools: Bool,
        privacySensitive: Bool,
        preferredLane: RuntimeLane?
    ) -> MissionPacket {
        MissionPacket(
            uasAddress: "chat.dispatch",
            role: role(forOperatingMode: operatingMode),
            objective: objective,
            requiresTools: requiresTools,
            privacySensitive: privacySensitive,
            preferredLane: preferredLane
        )
    }
}
