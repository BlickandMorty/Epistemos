import Testing
import Foundation
@testable import Epistemos

/// Regression coverage for the agent harness scaffolding (Epistemos/Engine/
/// AgentHarness). These tests exercise the types in isolation — nothing here
/// spins up a real backend or hits Rust FFI, so the suite stays fast and
/// stable under CI.
struct AgentHarnessTests {
    // MARK: - AgentUsageLedger

    @Test
    func usageLedgerMergesPerModelCountsWithoutMixingFamilies() {
        var ledger = UsageLedger.empty
        ledger.add(
            model: "claude-opus-4-7",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.01)
        )
        ledger.add(
            model: "qwen3.5-4b-4bit",
            usage: TokenUsage(inputTokens: 400, outputTokens: 80)
        )

        #expect(ledger.byModel["claude-opus-4-7"]?.inputTokens == 100)
        #expect(ledger.byModel["qwen3.5-4b-4bit"]?.outputTokens == 80)
        #expect(ledger.totalCostUSD == 0.01)
    }

    @Test
    func mergingTwoLedgersPreservesPerModelAttribution() {
        var first = UsageLedger.empty
        first.add(model: "claude-opus-4-7", usage: TokenUsage(inputTokens: 10, costUSD: 0.001))

        var second = UsageLedger.empty
        second.add(model: "claude-opus-4-7", usage: TokenUsage(outputTokens: 5, costUSD: 0.002))
        second.add(model: "gemini-2.5-pro", usage: TokenUsage(inputTokens: 20))

        first.mergeUsage(second)

        #expect(first.byModel["claude-opus-4-7"]?.inputTokens == 10)
        #expect(first.byModel["claude-opus-4-7"]?.outputTokens == 5)
        #expect(first.byModel["gemini-2.5-pro"]?.inputTokens == 20)
        #expect(first.totalCostUSD == 0.003)
    }

    // MARK: - AgentNameSanitizer

    @Test
    func sanitizerCollapsesInvalidCharactersAndCapsLength() {
        let raw = "Legal Research / 2026 🚀 !!!"
        let sanitized = AgentNameSanitizer.toolName(for: raw)

        #expect(sanitized.count <= 50)
        #expect(sanitized.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" })
        #expect(!sanitized.isEmpty)
    }

    @Test
    func sanitizerFallsBackToDefaultWhenInputStripsToEmpty() {
        #expect(AgentNameSanitizer.toolName(for: "   ___   ") == "agent_handoff")
    }

    // MARK: - AgentHandoff

    @Test
    func pipelineHandoffTrimsHistoryToDefaultWindow() {
        let handoff = AgentHandoff(
            targetAgentID: "summary_agent",
            contextType: .pipeline
        )
        let longHistory = (0..<25).map { "entry \($0)" }
        let input = HandoffInputData(inputHistory: longHistory)

        let filtered = handoff.inputFilter(input)

        #expect(filtered.inputHistory.count == HandoffContextType.pipeline.defaultHistoryWindow)
        #expect(filtered.inputHistory.first == "entry 15")
    }

    @Test
    func pipelineContextMessageContainsStepAndTotal() {
        let body = PipelineContextMessageBuilder.message(
            pipelineName: "research-then-write",
            currentStep: 1,
            totalSteps: 3
        )

        #expect(body.contains("Step: 2/3"))
        #expect(body.contains("research-then-write"))
        #expect(body.contains("Continue"))
    }

    // MARK: - AgentAuthorityDefaults

    @Test
    func systemProtectedCategoryDefaultsToNeverAllow() {
        #expect(AgentAuthorityDefaults.decision(for: .systemProtected) == .neverAllow)
    }

    @Test
    @MainActor
    func storeRefusesToAutoAllowSystemProtectedCategory() {
        let store = AgentAuthorityStore(persistence: InMemoryAgentAuthorityPersistence())

        store.setDecision(.autoAllow, for: .systemProtected)

        #expect(store.snapshot.decision(for: .systemProtected) == .neverAllow)
    }

    @Test
    func vaultCategoriesDefaultToAutoAllow() {
        #expect(AgentAuthorityDefaults.decision(for: .vaultRead) == .autoAllow)
        #expect(AgentAuthorityDefaults.decision(for: .vaultWrite) == .autoAllow)
    }

    @Test
    func installCategoriesDefaultToAskFirst() {
        #expect(AgentAuthorityDefaults.decision(for: .packageInstall) == .askFirst)
        #expect(AgentAuthorityDefaults.decision(for: .runDownloadedScript) == .askFirst)
        #expect(AgentAuthorityDefaults.decision(for: .externalAppAutomation) == .askFirst)
    }

    @Test
    func defaultPolicyCoversEveryCategory() {
        let policy = AgentAuthorityDefaults.defaultPolicy()
        for category in AgentAuthorityCategory.allCases {
            #expect(policy[category] != nil, "missing default for \(category.rawValue)")
        }
    }

    @Test
    @MainActor
    func storeRoundTripsDecisionsThroughPersistence() {
        let persistence = InMemoryAgentAuthorityPersistence()
        let store = AgentAuthorityStore(persistence: persistence)

        store.setDecision(.autoAllow, for: .packageInstall)

        let reloaded = AgentAuthorityStore(persistence: persistence)
        #expect(reloaded.snapshot.decision(for: .packageInstall) == .autoAllow)
    }

    // MARK: - RuntimeBootstrapWriter

    @Test
    func runtimeFilenameMapsClaudeToClaudeMd() {
        #expect(RuntimeBootstrapWriter.TargetFile.fileName(forBackendID: "claude") == "CLAUDE.md")
        #expect(RuntimeBootstrapWriter.TargetFile.fileName(forBackendID: "anthropic") == "CLAUDE.md")
    }

    @Test
    func runtimeFilenameMapsGeminiToGeminiMd() {
        #expect(RuntimeBootstrapWriter.TargetFile.fileName(forBackendID: "gemini") == "GEMINI.md")
    }

    @Test
    func runtimeFilenameFallsBackToAgentsMdForUnknownBackend() {
        #expect(RuntimeBootstrapWriter.TargetFile.fileName(forBackendID: "opencode") == "AGENTS.md")
        #expect(RuntimeBootstrapWriter.TargetFile.fileName(forBackendID: "codex") == "AGENTS.md")
    }

    @Test
    func runtimeWriterPreservesExistingFileWhenOverwriteDisabled() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let existing = tempDir.appendingPathComponent("CLAUDE.md")
        try "original".write(to: existing, atomically: true, encoding: .utf8)

        try RuntimeBootstrapWriter.inject(
            workDir: tempDir,
            backendID: "claude",
            content: "injected",
            overwriteExisting: false
        )

        let contents = try String(contentsOf: existing)
        #expect(contents == "original")
    }
}
