import Foundation
import Testing
@testable import Epistemos

// MARK: - RuntimeRouterTests (Phase 2 Terminal T1 — 2026-05-24)
//
// Acceptance gates exercised here (per docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md §Terminal 1):
//   1. `routeProfiles()` returns ≥ 6 non-empty profiles.
//   2. MLX lane flippable OFF without breaking chat — escalation
//      log records the disable + the route(_:) call emits an honest
//      escalation entry (not silent fallback).
//   3. Apple Intelligence lane present (Tier 1) — even if its
//      capability surface is initially narrow.
//   4. The `InferenceState.routeProfiles()` surface returns the same
//      data as `RuntimeRouter.defaultRouteProfiles()` (no drift).
//
// Tests construct routers via `RuntimeRouter(initialLanes:)` to keep
// UserDefaults out of the test path.

@MainActor
@Suite("RuntimeRouter — Phase 2 T1")
struct RuntimeRouterTests {
    @Test("routeProfiles returns the six per-role profiles, all non-empty")
    func routeProfilesReturnsAtLeastSixNonEmptyRows() {
        let profiles = RuntimeRouter.defaultRouteProfiles()

        #expect(profiles.count >= 6, "routeProfiles must publish at least 6 rows; got \(profiles.count)")
        let roles = Set(profiles.map(\.role))
        #expect(roles == Set(RuntimeRole.allCases), "every RuntimeRole must surface a profile")
        for profile in profiles {
            #expect(!profile.preferredLanes.isEmpty, "\(profile.role.rawValue) has empty preferredLanes")
        }
        // Vision role's preference table is light by design (one model);
        // the rest must each list at least 1 candidate.
        for profile in profiles where profile.role != .vision {
            #expect(!profile.preferredModelIDs.isEmpty, "\(profile.role.rawValue) has empty preferredModelIDs")
        }
    }

    @Test("InferenceState.routeProfiles() returns the router-owned data — no drift")
    func inferenceStateRouteProfilesMirrorsRouter() {
        let viaInferenceState = InferenceState.routeProfiles()
        let viaRouter = RuntimeRouter.defaultRouteProfiles()
        #expect(viaInferenceState == viaRouter)
        #expect(viaInferenceState.count >= 6)
    }

    @Test("Apple Intelligence lane is present in defaultStubLanes (acceptance gate §AI)")
    func appleIntelligenceLaneIsPresent() {
        let lanes = RuntimeRouter.defaultStubLanes()
        let laneIDs = Set(lanes.map(\.id))
        #expect(laneIDs.contains(.appleIntelligence))
        let cap = RuntimeRouter.defaultStubCapability(for: .appleIntelligence)
        #expect(cap.tier == .currentApp, "Apple Intelligence is initially CurrentApp tier")
    }

    @Test("router accepts a normal request on the MLX lane")
    func routerAcceptsOnMLXLane() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        let packet = MissionPacket(
            uasAddress: "uas:test:001",
            role: .code,
            objective: "Refactor the foo function.",
            requiresTools: true
        )
        let verdict = router.route(packet)
        if case .accept(let lane, _) = verdict {
            #expect(lane == .mlx, "code role should accept on MLX first; got \(lane.stableID)")
        } else {
            Issue.record("expected .accept, got \(verdict)")
        }
        #expect(router.metrics.tally(for: .mlx).accepts >= 1)
    }

    @Test("flipping MLX off escalates to GGUF — honest log, not silent fallback")
    func mlxFlippedOffEscalatesHonestly() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        router._testResetMetrics()
        router.setLaneEnabled(.mlx, false)

        let packet = MissionPacket(
            uasAddress: "uas:test:002",
            role: .code,
            objective: "Refactor the foo function.",
            requiresTools: true
        )
        let verdict = router.route(packet)

        // Acceptance landed somewhere — but NOT on MLX.
        if case .accept(let lane, _) = verdict {
            #expect(lane != .mlx, "MLX is disabled; verdict accepted on \(lane.stableID)")
            #expect(lane == .gguf, "first fallback for code role is GGUF; got \(lane.stableID)")
        } else {
            Issue.record("expected .accept downstream, got \(verdict)")
        }
        // MLX escalation must be visible.
        let mlxTally = router.metrics.tally(for: .mlx)
        #expect(mlxTally.escalations == 1, "MLX should have exactly one escalation; got \(mlxTally.escalations)")
        #expect(mlxTally.accepts == 0, "MLX must not accept when disabled")
        // The escalation log carries a human-readable entry.
        #expect(!router.escalationLog.isEmpty)
        let laneToggleLogged = router.escalationLog.contains { $0.contains("lane=mlx") && $0.contains("enabled=false") }
        #expect(laneToggleLogged, "lane toggle is logged honestly")
        let routeEscalationLogged = router.escalationLog.contains { $0.contains("from=mlx") && $0.contains("reason=lane_disabled") }
        #expect(routeEscalationLogged, "routing-time escalation logged honestly")

        // Restore for other tests.
        router.setLaneEnabled(.mlx, true)
    }

    @Test("privacy-sensitive request rejects when no local lane is available")
    func privacySensitiveRejectsWhenLocalDisabled() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        for local in [RuntimeLane.mlx, .gguf, .appleIntelligence, .stub] {
            router.setLaneEnabled(local, false)
        }
        defer {
            for local in [RuntimeLane.mlx, .gguf, .appleIntelligence, .stub] {
                router.setLaneEnabled(local, true)
            }
        }
        let packet = MissionPacket(
            uasAddress: "uas:test:003",
            role: .reasoning,
            objective: "Sensitive query.",
            privacySensitive: true
        )
        let verdict = router.route(packet)
        if case .reject(let reason) = verdict {
            #expect(reason == .privacySensitiveNoLocal)
        } else {
            Issue.record("expected .reject, got \(verdict)")
        }
    }

    @Test("metrics ring is bounded to the documented capacity")
    func metricsRingIsBoundedToDocumentedCapacity() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        router._testResetMetrics()
        // Pump 120 verdicts of mixed kinds to ensure the ring trims.
        for i in 0..<120 {
            let packet = MissionPacket(
                uasAddress: "uas:bench:\(i)",
                role: .quick,
                objective: "ping \(i)"
            )
            _ = router.route(packet)
        }
        #expect(router.metrics.totalCount <= RuntimeRouterMetrics.ringCapacity)
        #expect(router.metrics.totalCount == RuntimeRouterMetrics.ringCapacity)
    }

    @Test("RuntimeLane.knownLanes covers MLX + GGUF + Apple Intelligence + ≥ 1 cloud + stub")
    func knownLanesCoverTheArchitecture() {
        let known = Set(RuntimeLane.knownLanes.map(\.stableID))
        #expect(known.contains("mlx"))
        #expect(known.contains("gguf"))
        #expect(known.contains("apple_intelligence"))
        #expect(known.contains("stub"))
        let hasCloud = RuntimeLane.knownLanes.contains { lane in
            if case .cloud = lane { return true }
            return false
        }
        #expect(hasCloud)
    }

    @Test("StubRuntimeExecutor escalates vision requests on non-vision lanes")
    func stubEscalatesVisionRequestsOnNonVisionLanes() {
        let stub = StubRuntimeExecutor(
            lane: .mlx,
            capability: RuntimeRouter.defaultStubCapability(for: .mlx)
        )
        let packet = MissionPacket(
            uasAddress: "uas:vision:001",
            role: .vision,
            objective: "Describe this image.",
            requiresVision: true
        )
        let verdict = stub.canHandle(packet)
        if case .escalate(_, _, let reason) = verdict {
            #expect(reason == .visionUnsupported)
        } else {
            Issue.record("expected vision escalation, got \(verdict)")
        }
    }

    @Test("RuntimeRouterMetrics tally counts accepts and escalations per lane")
    func metricsTallyTracksAcceptsAndEscalations() {
        var m = RuntimeRouterMetrics()
        m.record(.init(role: .code, lane: .mlx, kind: .accept))
        m.record(.init(role: .code, lane: .mlx, kind: .accept))
        m.record(.init(role: .code, lane: .mlx, kind: .escalate, detail: "lane_disabled"))
        let mlxTally = m.tally(for: .mlx)
        #expect(mlxTally.accepts == 2)
        #expect(mlxTally.escalations == 1)
    }

    @Test("router rejects when every lane in the chain is disabled (allLanesDisabled witness)")
    func allLanesDisabledProducesAllLanesDisabledReason() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        for lane in RuntimeLane.knownLanes {
            router.setLaneEnabled(lane, false)
        }
        defer {
            for lane in RuntimeLane.knownLanes {
                router.setLaneEnabled(lane, true)
            }
        }
        let packet = MissionPacket(
            uasAddress: "uas:test:008",
            role: .quick,
            objective: "ping"
        )
        let verdict = router.route(packet)
        if case .reject(let reason) = verdict {
            #expect(reason == .allLanesDisabled)
        } else {
            Issue.record("expected .reject with .allLanesDisabled, got \(verdict)")
        }
    }
}
