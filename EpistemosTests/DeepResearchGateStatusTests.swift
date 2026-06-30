import Testing
import Foundation
@testable import Epistemos

/// DeerFlow slice 5b (visible surface) — locks that the deep-research surface
/// reads the SAME env flag the in-process Rust run (deep_research::
/// deep_research_enabled) reads, with the SAME opt-in truth table, so the
/// SubstrateHealthPanel row never claims a capability the runtime isn't offering.
@Suite("Deep research gate status")
struct DeepResearchGateStatusTests {

    @Test("flag name matches the Rust runtime flag")
    func flagNameMatchesRuntime() {
        #expect(DeepResearchGateStatus.flagName == "EPISTEMOS_DEEP_RESEARCH_V0")
    }

    @Test("opt-in truth table mirrors Rust deep_research_flag_value")
    func optInTruthTable() {
        for on in ["1", "true", "TRUE", "Yes", "on", " on ", "  1  "] {
            #expect(DeepResearchGateStatus.isEnabled(on), "\(on) should enable")
        }
        for off in ["0", "false", "no", "off", "", "2", "enable", nil] {
            #expect(!DeepResearchGateStatus.isEnabled(off), "\(off ?? "nil") should be off")
        }
    }

    @Test("status reflects the flag honestly + is Pro-scoped")
    func statusReflectsFlag() {
        let on = DeepResearchGateStatus.status(environment: ["EPISTEMOS_DEEP_RESEARCH_V0": "1"])
        #expect(on.isActive)
        #expect(on.headline.contains("ON"))
        // Case-insensitive: the copy says "IN PARALLEL" — the intent is "the detail mentions
        // parallel sub-agent research", which a case-sensitive match brittly broke on a copy edit.
        #expect(on.detail.localizedCaseInsensitiveContains("parallel"))

        let off = DeepResearchGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.detail.contains("EPISTEMOS_DEEP_RESEARCH_V0"))
    }

    /// Slice 5d — the honest no-hidden-route gate. Deep research's sub-agents are
    /// tool/web users (a cloud capability), so `DeepResearchService.run` runs
    /// ONLY on a recognized cloud provider. This is an explicit ALLOWLIST so it
    /// can never silently fire on a route the user didn't pick (owner #1).
    @Test("cloud-provider allowlist recognizes the real resolveRustProviderName strings")
    func cloudProviderAllowlistMatchesProviderNames() {
        // Every cloud string the agent route resolver can emit.
        for cloud in [
            "claude_sonnet", "claude_opus", "claude_haiku",
            "openai_gpt54", "openai_gpt54_mini",
            "gemini_flash", "gemini_pro",
            "zai", "kimi_coding", "minimax", "deepseek",
        ] {
            #expect(DeepResearchGateStatus.isCloudProvider(cloud), "\(cloud) is cloud")
        }
    }

    @Test("local / on-device providers are NOT cloud (no hidden-route fallback)")
    func localProvidersAreNotCloud() {
        for local in ["ollama", "mlx", "gguf", "apple", "local", "localOnly", "", "   "] {
            #expect(!DeepResearchGateStatus.isCloudProvider(local), "\(local) must not be cloud")
        }
    }

    @Test("runtime diagnostics cap FFI errors without leaking raw localized text")
    func runtimeDiagnosticsCapFFIErrorsWithoutLeakingRawLocalizedText() throws {
        #if !EPISTEMOS_APP_STORE
        let bridge = try loadMirroredSourceTextFile("Epistemos/Bridge/DeepResearchBridge.swift")
        let raw = String(repeating: "e", count: DeepResearchRuntimeDiagnostics.maxRuntimeErrorCharacters + 41)
        let privatePath = "/Users/example/private-vault/deep-research.db"
        let external = NSError(
            domain: "DeepResearchPathLeak",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "failed while opening \(privatePath)"]
        )
        let description = DeepResearchRuntimeDiagnostics.externalErrorDescription(external)

        #expect(DeepResearchServiceError.runtime(raw).localizedDescription.count == DeepResearchRuntimeDiagnostics.maxRuntimeErrorCharacters + 3)
        #expect(description.contains("DeepResearchPathLeak"))
        #expect(description.contains("42"))
        #expect(description.contains(privatePath) == false)
        #expect(description.count <= DeepResearchRuntimeDiagnostics.maxRuntimeErrorCharacters)
        #expect(bridge.contains("DeepResearchRuntimeDiagnostics"))
        #expect(bridge.contains("maxRuntimeErrorCharacters"))
        #expect(bridge.contains("externalErrorDescription"))
        #expect(!bridge.contains("runtime(error.localizedDescription)"))
        #else
        #expect(true)
        #endif
    }
}
