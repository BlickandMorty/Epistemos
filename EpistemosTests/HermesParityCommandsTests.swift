import Foundation
import Testing
@testable import Epistemos

/// Validation of the `/help`, `/status`, `/tokens`, `/cost`, `/think`
/// Hermes-parity Core-native commands per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md`.
///
/// All five are Core-safe: no network, no subprocess, no provider call.
/// Each uses the established `HermesTodoCommand` / `HermesCalcCommand`
/// shape (struct + parse + render/snapshot).

// MARK: - /help

@Suite("Hermes /help Command")
struct HermesHelpCommandTests {

    @Test("parse rejects non-/help input")
    func parseRejectsNonHelpInput() {
        #expect(HermesHelpCommand.parse("/todo") == nil)
        #expect(HermesHelpCommand.parse("help") == nil)
        #expect(HermesHelpCommand.parse("") == nil)
    }

    @Test("bare /help defaults to .all filter")
    func bareHelpDefaultsToAll() {
        let cmd = HermesHelpCommand.parse("/help")
        #expect(cmd?.filter == .all)
    }

    @Test("/help <tier> filters by tier")
    func helpFiltersByTier() {
        #expect(HermesHelpCommand.parse("/help core")?.filter == .tier(.core))
        #expect(HermesHelpCommand.parse("/help pro")?.filter == .tier(.pro))
        #expect(HermesHelpCommand.parse("/help research")?.filter == .tier(.research))
    }

    @Test("/help <surface> filters by surface")
    func helpFiltersBySurface() {
        #expect(HermesHelpCommand.parse("/help session")?.filter == .surface(.session))
        #expect(HermesHelpCommand.parse("/help configuration")?.filter == .surface(.configuration))
    }

    @Test("/help with unknown filter falls back to .all")
    func helpUnknownFilterFallsBackToAll() {
        #expect(HermesHelpCommand.parse("/help nonsense")?.filter == .all)
    }

    @Test("renderText includes at least one Core command and groups by surface")
    func renderTextGroupsBySurface() {
        let text = HermesHelpCommand(filter: .all).renderText()
        #expect(text.contains("/help"), "rendered help must include itself")
        #expect(text.contains("[session]"), "rendered help must group session commands")
    }

    @Test("renderText empty filter case shows clear no-match message")
    func renderTextEmptyFilterShowsMessage() {
        // Synthesize an empty registry to force the no-match branch.
        let text = HermesHelpCommand(filter: .all).renderText(registry: [])
        #expect(text == "No commands match the selected filter.")
    }

    @Test("requiresApproval is false")
    func helpDoesNotRequireApproval() {
        #expect(!HermesHelpCommand(filter: .all).requiresApproval)
    }
}

// MARK: - /status

@Suite("Hermes /status Command")
struct HermesStatusCommandTests {

    @Test("parse only matches exact /status")
    func parseExactOnly() {
        #expect(HermesStatusCommand.parse("/status") != nil)
        #expect(HermesStatusCommand.parse("/status arg") == nil)
        #expect(HermesStatusCommand.parse("status") == nil)
    }

    @Test("snapshot fills missing fields with sensible defaults")
    func snapshotFillsMissingFields() {
        let snap = HermesStatusCommand().snapshot(from: HermesSessionStatusInput())
        #expect(snap.providerLabel == "—")
        #expect(snap.modelLabel == "—")
        #expect(snap.sessionID == "—")
        #expect(snap.turnsThisSession == 0)
        #expect(snap.totalTokensUsed == 0)
    }

    @Test("snapshot computes totalTokensUsed from input + output")
    func snapshotComputesTotalTokens() {
        let input = HermesSessionStatusInput(
            inputTokensUsed: 1000,
            outputTokensUsed: 250
        )
        let snap = HermesStatusCommand().snapshot(from: input)
        #expect(snap.inputTokensUsed == 1000)
        #expect(snap.outputTokensUsed == 250)
        #expect(snap.totalTokensUsed == 1250)
    }

    @Test("renderText includes every declared row")
    func renderTextIncludesEveryRow() {
        let snap = HermesStatusCommand().snapshot(from: HermesSessionStatusInput(
            providerLabel: "openai",
            modelLabel: "gpt-5.5",
            sessionID: "s-123"
        ))
        let text = snap.renderText()
        #expect(text.contains("Provider:"))
        #expect(text.contains("Model:"))
        #expect(text.contains("Session ID:"))
        #expect(text.contains("Turns:"))
        #expect(text.contains("Tokens (in/out):"))
        #expect(text.contains("Cost (USD):"))
        #expect(text.contains("Sovereign grace:"))
    }

    @Test("singular vs plural Sovereign-grace label")
    func sovereignGraceLabelPluralization() {
        let one = HermesStatusCommand().snapshot(from: HermesSessionStatusInput(
            sovereignGraceCategoriesActive: 1
        ))
        let many = HermesStatusCommand().snapshot(from: HermesSessionStatusInput(
            sovereignGraceCategoriesActive: 3
        ))
        #expect(one.renderText().contains("1 active category"))
        #expect(many.renderText().contains("3 active categories"))
    }
}

// MARK: - /tokens

@Suite("Hermes /tokens Command")
struct HermesTokensCommandTests {

    @Test("parse only matches exact /tokens")
    func parseExactOnly() {
        #expect(HermesTokensCommand.parse("/tokens") != nil)
        #expect(HermesTokensCommand.parse("/tokens 1") == nil)
        #expect(HermesTokensCommand.parse("tokens") == nil)
    }

    @Test("snapshot computes totalTokens correctly")
    func snapshotComputesTotal() {
        let input = HermesTokenStatsInput(inputTokens: 500, outputTokens: 200)
        let snap = HermesTokensCommand().snapshot(from: input)
        #expect(snap.totalTokens == 700)
    }

    @Test("snapshot computes context utilization percent")
    func snapshotComputesContextUtilization() {
        let input = HermesTokenStatsInput(
            contextWindowSize: 200_000,
            messagesInContextTokens: 50_000
        )
        let snap = HermesTokensCommand().snapshot(from: input)
        #expect(snap.contextUtilizationPercent != nil)
        #expect(abs((snap.contextUtilizationPercent ?? 0) - 25.0) < 0.0001)
    }

    @Test("snapshot returns nil utilization when no context window declared")
    func snapshotNilUtilizationWithoutWindow() {
        let snap = HermesTokensCommand().snapshot(from: HermesTokenStatsInput(
            messagesInContextTokens: 10
        ))
        #expect(snap.contextUtilizationPercent == nil)
    }

    @Test("renderText hides cache rows when zero")
    func renderHidesCacheRowsWhenZero() {
        let snap = HermesTokensCommand().snapshot(from: HermesTokenStatsInput(
            inputTokens: 10,
            outputTokens: 5
        ))
        let text = snap.renderText()
        #expect(!text.contains("Cache read"))
        #expect(!text.contains("Cache write"))
    }

    @Test("renderText shows cache rows when non-zero")
    func renderShowsCacheRowsWhenNonZero() {
        let snap = HermesTokensCommand().snapshot(from: HermesTokenStatsInput(
            inputTokens: 10,
            outputTokens: 5,
            cacheReadTokens: 100
        ))
        let text = snap.renderText()
        #expect(text.contains("Cache read"))
    }
}

// MARK: - /cost

@Suite("Hermes /cost Command")
struct HermesCostCommandTests {

    @Test("parse only matches exact /cost")
    func parseExactOnly() {
        #expect(HermesCostCommand.parse("/cost") != nil)
        #expect(HermesCostCommand.parse("/cost arg") == nil)
        #expect(HermesCostCommand.parse("cost") == nil)
    }

    @Test("snapshot computes cumulative cost from per-provider sum + local extra")
    func snapshotComputesCumulative() {
        let input = HermesCostStatsInput(
            sessionCostUSD: 0.5,
            perProviderUSD: ["openai": 1.0, "anthropic": 2.0],
            localOnlyExtraUSD: 0.25
        )
        let snap = HermesCostCommand().snapshot(from: input)
        #expect(abs(snap.cumulativeCostUSD - 3.25) < 0.0001)
    }

    @Test("snapshot identifies the most expensive provider")
    func snapshotIdentifiesMostExpensiveProvider() {
        let input = HermesCostStatsInput(
            perProviderUSD: ["openai": 0.5, "anthropic": 5.0, "google": 1.0]
        )
        let snap = HermesCostCommand().snapshot(from: input)
        #expect(snap.mostExpensiveProvider == "anthropic")
        #expect(abs(snap.mostExpensiveProviderUSD - 5.0) < 0.0001)
    }

    @Test("snapshot handles empty provider map")
    func snapshotHandlesEmptyProviderMap() {
        let snap = HermesCostCommand().snapshot(from: HermesCostStatsInput())
        #expect(snap.mostExpensiveProvider == nil)
        #expect(snap.cumulativeCostUSD == 0)
    }

    @Test("renderText omits local-extra row when zero")
    func renderOmitsLocalExtraWhenZero() {
        let snap = HermesCostCommand().snapshot(from: HermesCostStatsInput(
            sessionCostUSD: 0.1
        ))
        #expect(!snap.renderText().contains("Local extra"))
    }
}

// MARK: - /think

@Suite("Hermes /think Command")
struct HermesThinkCommandTests {

    @Test("parse rejects non-/think input")
    func parseRejectsNonThinkInput() {
        #expect(HermesThinkCommand.parse("/todo") == nil)
        #expect(HermesThinkCommand.parse("think") == nil)
        #expect(HermesThinkCommand.parse("") == nil)
    }

    @Test("parse rejects bare /think with no prompt")
    func parseRejectsBareThink() {
        #expect(HermesThinkCommand.parse("/think") == nil)
        #expect(HermesThinkCommand.parse("/think   ") == nil)
    }

    @Test("parse extracts the prompt body")
    func parseExtractsPrompt() {
        let cmd = HermesThinkCommand.parse("/think why is the sky blue?")
        #expect(cmd?.prompt == "why is the sky blue?")
    }

    @Test("wrappedPrompt appends the canonical reasoning cue")
    func wrappedPromptAppendsCanonicalCue() {
        let cmd = HermesThinkCommand(prompt: "demo")
        let wrapped = cmd.wrappedPrompt()
        #expect(wrapped.hasPrefix("demo"))
        #expect(wrapped.contains("Think step by step"))
        #expect(wrapped.contains("Show your reasoning before the conclusion"))
    }

    @Test("wrappedPrompt is deterministic")
    func wrappedPromptIsDeterministic() {
        let cmd = HermesThinkCommand(prompt: "x")
        #expect(cmd.wrappedPrompt() == cmd.wrappedPrompt())
    }

    @Test("suggestedModelPreset defaults to localReasoningCapable")
    func suggestedModelPresetDefaultsToLocal() {
        let cmd = HermesThinkCommand(prompt: "x")
        #expect(cmd.suggestedModelPreset == .localReasoningCapable)
    }

    @Test("requiresApproval is false (Trivial action class)")
    func requiresApprovalIsFalse() {
        #expect(!HermesThinkCommand(prompt: "x").requiresApproval)
    }
}
