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

    @Test("local policy table gates MLX/GGUF before cloud fallback")
    func localPolicyTableGatesLocalLanesBeforeCloudFallback() {
        guard let policy = RuntimeRouter.localPolicyTable[.code] else {
            Issue.record("code role must have a local policy row")
            return
        }
        let cases: [(MissionPacket, RouteVerdict.EscalationReason)] = [
            (
                MissionPacket(
                    uasAddress: "uas:test:policy-confidence",
                    role: .code,
                    objective: "Refactor the foo function.",
                    requiresTools: true,
                    classificationConfidence: policy.minimumConfidence - 0.01
                ),
                .classificationUncertain
            ),
            (
                MissionPacket(
                    uasAddress: "uas:test:policy-complexity",
                    role: .code,
                    objective: "Refactor the foo function.",
                    requiresTools: true,
                    estimatedComplexity: policy.maximumComplexity + 0.01
                ),
                .taskTooComplex
            ),
            (
                MissionPacket(
                    uasAddress: "uas:test:policy-tools",
                    role: .code,
                    objective: "Refactor the foo function.",
                    requiresTools: true,
                    toolCountEstimate: policy.maximumToolCount + 1
                ),
                .tooManyToolCalls
            ),
        ]

        for (packet, reason) in cases {
            let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
            router._testResetMetrics()
            let verdict = router.route(packet)

            if case .accept(let lane, _) = verdict {
                #expect(lane == .cloud(provider: "claude"), "policy-gated code request should fall through to Claude; got \(lane.stableID)")
            } else {
                Issue.record("expected .accept on cloud fallback, got \(verdict)")
            }

            #expect(router.metrics.tally(for: .mlx).escalations == 1)
            #expect(router.metrics.tally(for: .gguf).escalations == 1)
            #expect(router.metrics.tally(for: .cloud(provider: "claude")).accepts == 1)

            let localEscalationReasons = router.metrics.ring
                .filter { $0.lane == .mlx || $0.lane == .gguf }
                .compactMap(\.detail)
            #expect(localEscalationReasons == [reason.rawValue, reason.rawValue])
        }
    }

    @Test("malformed policy hints reject before any fallback lane accepts")
    func malformedPolicyHintsRejectBeforeFallback() {
        let cases: [(String, MissionPacket)] = [
            (
                "nan-confidence",
                MissionPacket(
                    uasAddress: "uas:test:invalid-confidence",
                    role: .code,
                    objective: "Refactor this.",
                    classificationConfidence: Double.nan
                )
            ),
            (
                "infinite-complexity",
                MissionPacket(
                    uasAddress: "uas:test:invalid-complexity",
                    role: .code,
                    objective: "Refactor this.",
                    estimatedComplexity: Double.infinity
                )
            ),
            (
                "negative-tool-count",
                MissionPacket(
                    uasAddress: "uas:test:invalid-tool-count",
                    role: .code,
                    objective: "Refactor this.",
                    toolCountEstimate: -1
                )
            ),
            (
                "negative-input-tokens",
                MissionPacket(
                    uasAddress: "uas:test:invalid-input-tokens",
                    role: .code,
                    objective: "Refactor this.",
                    estimatedInputTokens: -1
                )
            ),
        ]

        for (label, packet) in cases {
            let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
            router._testResetMetrics()
            let verdict = router.route(packet)

            if case .reject(let reason) = verdict {
                #expect(reason == .invalidPolicyInput, "\(label) should reject as invalid policy input")
            } else {
                Issue.record("\(label) expected .reject, got \(verdict)")
            }

            #expect(router.metrics.ring.count == 1, "\(label) should record one reject event")
            #expect(router.metrics.ring.first?.kind == .reject)
            #expect(router.metrics.ring.first?.detail == RouteVerdict.RejectReason.invalidPolicyInput.rawValue)
            #expect(router.metrics.tally(for: .cloud(provider: "claude")).accepts == 0)
        }
    }

    @Test("estimated input tokens gate small-context lanes before fallback")
    func estimatedInputTokensGateSmallContextLane() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        router._testResetMetrics()
        let appleContext = RuntimeRouter.defaultStubCapability(for: .appleIntelligence).contextWindow
        let packet = MissionPacket(
            uasAddress: "uas:test:policy-context-window",
            role: .quick,
            objective: "Summarize this context.",
            estimatedInputTokens: appleContext + 1
        )

        let verdict = router.route(packet)

        if case .accept(let lane, _) = verdict {
            #expect(lane == .mlx, "quick request should skip Apple Intelligence and accept on MLX; got \(lane.stableID)")
        } else {
            Issue.record("expected .accept on MLX fallback, got \(verdict)")
        }

        #expect(router.metrics.tally(for: .appleIntelligence).escalations == 1)
        let reasons = router.metrics.ring
            .filter { $0.lane == .appleIntelligence }
            .compactMap(\.detail)
        #expect(reasons == [RouteVerdict.EscalationReason.contextWindowExceeded.rawValue])
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

    @Test("tool-caller requests exhaust GGUF before cloud when MLX is disabled")
    func toolCallerKeepsGGUFBeforeCloudFallback() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        router._testResetMetrics()
        router.setLaneEnabled(.mlx, false)
        defer {
            router.setLaneEnabled(.mlx, true)
        }

        let packet = MissionPacket(
            uasAddress: "uas:test:tool-caller-local-first",
            role: .toolCaller,
            objective: "Call vault.search for related notes.",
            requiresTools: true,
            requiresGrammar: true
        )
        let verdict = router.route(packet)

        if case .accept(let lane, _) = verdict {
            #expect(lane == .gguf, "tool-caller fallback must use GGUF before cloud; got \(lane.stableID)")
        } else {
            Issue.record("expected .accept on GGUF fallback, got \(verdict)")
        }

        #expect(router.metrics.tally(for: .mlx).escalations == 1)
        #expect(router.metrics.tally(for: .gguf).accepts == 1)
        #expect(router.metrics.tally(for: .cloud(provider: "claude")).accepts == 0)
        #expect(router.metrics.tally(for: .cloud(provider: "openai")).accepts == 0)
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

    @Test("privacy-sensitive request ignores enabled stub when all executable local lanes are disabled")
    func privacySensitiveIgnoresEnabledStubLane() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        for local in [RuntimeLane.mlx, .gguf, .appleIntelligence] {
            router.setLaneEnabled(local, false)
        }
        defer {
            for local in [RuntimeLane.mlx, .gguf, .appleIntelligence] {
                router.setLaneEnabled(local, true)
            }
        }
        let packet = MissionPacket(
            uasAddress: "uas:test:privacy-stub",
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

    @Test("agent badge data is derived from router lane capability evidence")
    func agentBadgeDataComesFromRuntimeRouterLaneCapabilities() {
        let verified = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.qwen3_8B4Bit.rawValue
        )
        #expect(verified.state == .honest)
        #expect(verified.title == "HONEST")
        #expect(verified.lane == .mlx)
        #expect(verified.witness.contains("RuntimeRouter"))
        #expect(verified.falsifier == "F-LocalToolUse")

        let experimental = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.devstralSmall2505_4Bit.rawValue
        )
        #expect(experimental.state == .experimental)
        #expect(experimental.title == "EXPERIMENTAL")
        #expect(experimental.falsifier == "F-LocalToolUse pending")

        let off = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.smolLM3_3B4Bit.rawValue
        )
        #expect(off.state == .off)
        #expect(off.title == "OFF")
        #expect(off.toolCallMode == .none)
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
