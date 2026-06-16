import Testing
import Foundation
@testable import Epistemos

/// RCA-P1-005 drift gate — Pro + cloud requests MUST route through
/// the Rust managed-agent tool loop (`chat_pro` tier), not silently
/// degrade to a zero-tools direct stream.
///
/// Background: research-3 surfaced "Pro+cloud fell through to a
/// zero-tools direct stream" as the load-bearing tool-truth bug.
/// The fix lives in `ChatCoordinator`'s execution-plan branch:
///   - Agent mode + cloud → managedAgentSession (full tool surface)
///   - Pro mode + cloud → chat_pro tier, including promoted managed plans
///   - Fast/Thinking + cloud direct branch → chat_lite
///   - Fast/Thinking + promoted managed plan → full Agent tier
///
/// Without this gate a future refactor that re-orders the branches
/// or drops the `chat_pro` toolTier argument could silently
/// re-introduce the original bug. The audit acceptance — "Tool-
/// required cloud requests do not silently degrade to zero-tool
/// direct streams" — depends on these symbols staying in place.
@Suite("RCA-P1-005 Pro+Cloud Tool Loop Guard")
struct ProCloudToolLoopGuardTests {

    @Test("ChatCoordinator routes Pro+cloud through runRustAgentPath with chat_pro tier")
    func proCloudUsesChatProTier() throws {
        let managedBudget = try #require(ChatCoordinator.cloudToolBudget(
            for: .pro,
            isCloudSelectedSurface: true,
            supportsAgentTier: true,
            managedAgentSession: true
        ))
        #expect(managedBudget.toolTier == .chatPro)
        // Pro turn ceiling is a SAFETY RAIL, not a schedule: the model ends
        // simple turns early via stop_reason==end_turn, so this ceiling only
        // enables genuine multi-step tool loops (the "feels agentic" lever).
        // Stays under DEFAULT_AGENT_MAX_TURNS (25) for the bounded-execution
        // review posture. Was 3 (effectively single-shot for real work).
        #expect(managedBudget.maxTurns == 15)

        let directBudget = try #require(ChatCoordinator.cloudToolBudget(
            for: .pro,
            isCloudSelectedSurface: true,
            supportsAgentTier: true,
            managedAgentSession: false
        ))
        #expect(directBudget.toolTier == .chatPro)
        #expect(directBudget.maxTurns == 15)

        let source = try loadMirroredSourceTextFile(
            "Epistemos/App/ChatCoordinator.swift"
        )
        #expect(source.contains("let managedCloudToolBudget = Self.cloudToolBudget("),
            "ChatCoordinator must compute the cloud tier override before the managedAgentSession branch so Pro+cloud promoted plans do not default to the full Agent tier — see RCA-P1-005")
        #expect(source.contains("toolTier: managedToolTier"),
            "ChatCoordinator must pass the computed Pro+cloud tool tier into runRustAgentPath for promoted managed plans — see RCA-P1-005")
        #expect(source.contains("maxTurns: managedMaxTurns"),
            "ChatCoordinator must pass the computed Pro+cloud turn budget into runRustAgentPath for promoted managed plans — see RCA-P1-005")
        // The doctrine comment must retain the explicit reason for
        // the chat_pro override so future refactors can't innocently
        // delete it without realizing they're re-introducing the
        // research-3 bug.
        #expect(source.contains("note lookups / writes actually hit tools"),
            "ChatCoordinator Pro+cloud doctrine comment must retain its tool-truth justification — see RCA-P1-005")
    }

    @Test("ChatCoordinator keeps Fast and Thinking cloud tiers deterministic")
    func cloudFastThinkingBudgetsStayDeterministic() throws {
        // Fast and Thinking both stay on the read-only chat_lite tier (no
        // writes), but get distinct LOOP ceilings so the everyday cloud chat
        // can do multi-step research instead of single-shot Q&A. Ceilings are
        // safety rails — stop_reason==end_turn ends simple turns immediately.
        let expectedTurns: [EpistemosOperatingMode: UInt32] = [.fast: 5, .thinking: 10]
        for (mode, turns) in expectedTurns {
            let directBudget = try #require(ChatCoordinator.cloudToolBudget(
                for: mode,
                isCloudSelectedSurface: true,
                supportsAgentTier: true,
                managedAgentSession: false
            ))
            #expect(directBudget.toolTier == .chatLite)
            #expect(directBudget.maxTurns == turns)
            // A tool-capable loop ceiling means > 1 (the old single-shot value).
            #expect(directBudget.maxTurns > 1)

            #expect(ChatCoordinator.cloudToolBudget(
                for: mode,
                isCloudSelectedSurface: true,
                supportsAgentTier: true,
                managedAgentSession: true
            ) == nil)
        }
    }

    @Test("ChatCoordinator's managedAgentSession route is reachable for Agent mode")
    func agentModeReachesManagedAgentSession() throws {
        #expect(ChatCoordinator.cloudToolBudget(
            for: .agent,
            isCloudSelectedSurface: true,
            supportsAgentTier: true,
            managedAgentSession: true
        ) == nil)

        let source = try loadMirroredSourceTextFile(
            "Epistemos/App/ChatCoordinator.swift"
        )
        // The Agent mode branch must call runRustAgentPath without
        // a toolTier override (full tool surface, not chat_pro).
        // Pin the branch existence + the `executionPlan.route ==
        // .managedAgentSession` precondition.
        #expect(source.contains(".managedAgentSession"),
            "ChatCoordinator must keep the managedAgentSession route case so Agent-mode requests reach the full Rust tool loop — see RCA-P1-005")
        #expect(source.contains("executionPlan.route == .managedAgentSession"),
            "ChatCoordinator must gate the full-tool path on `executionPlan.route == .managedAgentSession` — see RCA-P1-005")
    }

    @Test("ChatCoordinator preserves fallback log line so silent degradation is visible")
    func fallbackPathIsObservable() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/App/ChatCoordinator.swift"
        )
        // The cloud fallback paths emit warnings when the Rust agent
        // path fails and fallback is allowed.
        // The audit acceptance — "Users see when tools were used,
        // denied, or unavailable" — depends on this log line + the
        // chat_pro tier symbol staying present.
        #expect(source.contains("Managed agent path unavailable (mode="),
            "ChatCoordinator must keep the managed-agent fallback warning log so silent tool-loop degradation surfaces in diagnostics — see RCA-P1-005")
        #expect(source.contains("Cloud Rust agent path unavailable (mode="),
            "ChatCoordinator must keep the direct cloud fallback warning log so silent tool-loop degradation surfaces in diagnostics — see RCA-P1-005")
    }
}
