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

    /// Map a local model's `BackendRuntimeKind` to the local `RuntimeLane` it runs
    /// on — the classifier the live site injects into `liveLane(from:localLaneFor
    /// ModelID:)` for a `.local` descriptor (a GGUF model → `.gguf`, an MLX model →
    /// `.mlx`). `.remote` only appears for non-local descriptors, so it falls back
    /// to `.mlx`. Pure → unit-testable. The live composition is:
    /// `liveLane(from: resolved) { id in lane(forRuntimeKind:
    /// LocalTextModelID(rawValue: id)?.runtimeKind ?? .gguf) }` — where an id that
    /// is NOT a `LocalTextModelID` enum case is a foundation GGUF descriptor, hence
    /// the `.gguf` default at the live site.
    static func lane(forRuntimeKind kind: BackendRuntimeKind) -> RuntimeLane {
        switch kind {
        case .gguf: .gguf
        case .mlx: .mlx
        case .remote: .mlx
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

    // MARK: - STAGE 1b: observe-only parity orchestration

    /// Compose the shadow pieces into one parity outcome: build the packet from the live turn's
    /// signals, ask `router.route` for its verdict, and compare its lane to the lane the live path
    /// resolved to. `matched` is true when both pick the same lane (or both pick "no lane"). The
    /// live path's resolution is passed as `preferredLane`, so a parity match means "the router
    /// would honor what the live path chose." `@MainActor` because `route` is; the router metrics
    /// are mutated by `route` (the intended observe-only recording).
    @MainActor
    static func parityOutcome(
        operatingMode: EpistemosOperatingMode,
        objective: String,
        requiresTools: Bool,
        privacySensitive: Bool,
        resolved: ResolvedBrainDescriptor,
        router: RuntimeRouter,
        localLaneForModelID: (String) -> RuntimeLane
    ) -> (routerLane: RuntimeLane?, liveLane: RuntimeLane?, matched: Bool) {
        let live = liveLane(from: resolved, localLaneForModelID: localLaneForModelID)
        let packet = missionPacket(
            operatingMode: operatingMode,
            objective: objective,
            requiresTools: requiresTools,
            privacySensitive: privacySensitive,
            preferredLane: live)
        let routerLane = acceptedLane(from: router.route(packet))
        let matched: Bool = {
            if let live { return parityMatches(routerLane: routerLane, liveLane: live) }
            return routerLane == nil   // both resolved to "no lane" → they agree
        }()
        return (routerLane, live, matched)
    }

    /// The live dispatch-seam call (STAGE 1b). Flag OFF (default) → PURE NO-OP: returns
    /// immediately, the router is never consulted, zero overhead on the hot path. Flag ON →
    /// compute the parity outcome and RECORD it into the router's metrics; this NEVER alters the
    /// live decision (the caller keeps using its own resolution — observe-only). The local
    /// classifier mirrors the live site (`LocalTextModelID.runtimeKind`; a non-enum id is a
    /// foundation GGUF descriptor → `.gguf`).
    @MainActor
    static func recordLiveParity(
        operatingMode: EpistemosOperatingMode,
        objective: String,
        requiresTools: Bool,
        privacySensitive: Bool,
        resolved: ResolvedBrainDescriptor,
        router: RuntimeRouter = .shared
    ) {
        guard armed else { return }
        let outcome = parityOutcome(
            operatingMode: operatingMode,
            objective: objective,
            requiresTools: requiresTools,
            privacySensitive: privacySensitive,
            resolved: resolved,
            router: router,
            localLaneForModelID: { id in
                lane(forRuntimeKind: LocalTextModelID(rawValue: id)?.runtimeKind ?? .gguf)
            })
        router.recordParity(matched: outcome.matched)
    }
}
