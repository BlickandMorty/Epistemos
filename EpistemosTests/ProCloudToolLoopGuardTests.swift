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
///   - Pro mode + cloud → chat_pro tier (bounded 3 turns + 8 tools)
///   - Fast/Thinking + anything → existing Swift pipeline
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
        let source = try loadMirroredSourceTextFile(
            "Epistemos/App/ChatCoordinator.swift"
        )
        // The Pro+cloud branch must hand `chat_pro` as the tool tier.
        #expect(source.contains("toolTier: \"chat_pro\""),
            "ChatCoordinator must pass toolTier: \"chat_pro\" for Pro+cloud requests so the Rust agent_core dispatches with the bounded tool budget — see RCA-P1-005")
        // The bounded-turn budget (3) is part of the doctrine — too
        // many turns and Pro behaves like Agent; too few and tool
        // use is impossible. Pin the value here so accidental
        // budget drift fails CI.
        #expect(source.contains("maxTurns: 3"),
            "ChatCoordinator must keep maxTurns: 3 for the chat_pro branch so the tool budget matches research-3 + ResolvedExecutionPolicy")
        // The doctrine comment must retain the explicit reason for
        // the chat_pro override so future refactors can't innocently
        // delete it without realizing they're re-introducing the
        // research-3 bug.
        #expect(source.contains("note lookups / writes actually hit tools"),
            "ChatCoordinator Pro+cloud doctrine comment must retain its tool-truth justification — see RCA-P1-005")
    }

    @Test("ChatCoordinator's managedAgentSession route is reachable for Agent mode")
    func agentModeReachesManagedAgentSession() throws {
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
        // The Pro+cloud fallback path emits a warning when the Rust
        // agent path fails and the fallback to direct stream fires.
        // The audit acceptance — "Users see when tools were used,
        // denied, or unavailable" — depends on this log line + the
        // chat_pro tier symbol staying present.
        #expect(source.contains("Pro-mode Rust agent path unavailable, falling back to direct stream"),
            "ChatCoordinator must keep the Pro-mode-fallback warning log so silent tool-loop degradation surfaces in diagnostics — see RCA-P1-005")
    }
}
