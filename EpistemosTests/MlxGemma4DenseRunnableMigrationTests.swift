import Testing
import Foundation

@testable import Epistemos

// SS-CHATMODEL P0 (owner 2026-06-21, "make chat WORK BY DEFAULT with NO flag"): the owner is stuck on
// a persisted GGUF Gemma (`google/gemma-4-E2B-it-qat-q4_0-gguf`) that can't run while the GGUF lane is
// off, so resolution substitutes Qwen. The fix migrates the persisted GGUF Gemma → a PROVEN-RUNNABLE
// MLX model DEFAULT-ON (no env var): `gemma3_4BQAT4Bit`, the Gemma with a stable native MLX loader
// (registered "gemma3" → Gemma3TextModel, NOT awaiting-loader, NOT held out of automatic routing, and
// a real LocalTextModelID the persisted load accepts). The separate gemma4-dense improvement stays
// behind EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0 and only changes the migration TARGET, never whether
// the migration runs. These pin the default-on real-state migration (→ Gemma 3, no Qwen, no manual
// step), the flag-on target (→ dense gemma4), the no-remap of deliberate non-Gemma picks, and the
// once-only key. The migration only sets the *preferred* pick (resolver still enforces runnability),
// so it carries no SS-CR risk.
@Suite("SS-CHATMODEL P0 — GGUF Gemma → proven-runnable MLX (DEFAULT-ON, owner NO-FALLBACKS)")
struct MlxGemma4DenseRunnableMigrationTests {

    private func makeDefaults(_ name: String) -> UserDefaults {
        let suite = "test.ggufGemmaToMlx.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test("DEFAULT (no flag): a persisted GGUF Gemma maps to the proven-runnable MLX Gemma 3")
    func ggufMapsToGemma3ByDefault() {
        let gemma3 = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        for id in [
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "google/gemma-4-E4B-it-qat-q4_0-gguf",
            "google/gemma-4-12B-it-qat-q4_0-gguf"
        ] {
            #expect(InferenceState.mlxEquivalent(forGgufGemmaID: id, denseGemma4Enabled: false) == gemma3)
        }
    }

    @Test("dense flag ON (separate improvement): GGUF E2B/E4B map to the same-size dense MLX gemma4")
    func ggufMapsToGemma4WhenFlagOn() {
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: "google/gemma-4-E2B-it-qat-q4_0-gguf",
                                             denseGemma4Enabled: true) == LocalTextModelID.gemma4_2B4Bit.rawValue)
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: "google/gemma-4-E4B-it-qat-q4_0-gguf",
                                             denseGemma4Enabled: true) == LocalTextModelID.gemma4_4B4Bit.rawValue)
        // 12B GGUF has no dense gemma4 MLX tier → still falls back to the proven Gemma 3.
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: "google/gemma-4-12B-it-qat-q4_0-gguf",
                                             denseGemma4Enabled: true) == LocalTextModelID.gemma3_4BQAT4Bit.rawValue)
    }

    @Test("non-Gemma / non-GGUF / already-MLX ids are NOT remapped (deliberate picks preserved)")
    func nonMatchingPreserved() {
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: LocalTextModelID.qwen3_4B4Bit.rawValue,
                                             denseGemma4Enabled: false) == nil)
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: LocalTextModelID.gemma3_4BQAT4Bit.rawValue,
                                             denseGemma4Enabled: false) == nil)
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: LocalTextModelID.gemma4_2B4Bit.rawValue,
                                             denseGemma4Enabled: true) == nil)
    }

    @Test("real-state DEFAULT-ON: persisted GGUF E2B + dense flag OFF → running MLX Gemma 3, never Qwen, no manual step")
    func ownerGgufMigratesToRunnableGemma3ByDefault() {
        let defaults = makeDefaults("default")
        let ownerGguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        defaults.set(ChatModelSelection.localMLX(ownerGguf).rawValue, forKey: "epistemos.preferredChatModelSelection")

        // dense flag OFF — no env var, no manual step (the whole point of this firing).
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, denseGemma4Enabled: false)

        let gemma3 = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == gemma3)
        #expect(defaults.string(forKey: "epistemos.preferredChatModelSelection")
                == ChatModelSelection.localMLX(gemma3).rawValue)
        let resolved = defaults.string(forKey: "epistemos.preferredLocalTextModelID") ?? ""
        #expect(!resolved.lowercased().contains("qwen"))
        #expect(!resolved.lowercased().contains("gguf"))
        // Gemma 3 genuinely runs on the live MLX path (stable loader, not awaiting), so the
        // migrated pick actually generates — no flag, no substitution.
        #expect(!LocalTextModelID.gemma3_4BQAT4Bit.isAwaitingSwiftRuntimeLoader)
    }

    @Test("a CLOUD / non-Gemma selection is untouched (no SS-CR regression)")
    func cloudSelectionUntouched() {
        let defaults = makeDefaults("cloud")
        let cloudRaw = ChatModelSelection.localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue).rawValue
        defaults.set(cloudRaw, forKey: "epistemos.preferredChatModelSelection")
        defaults.set(LocalTextModelID.qwen3_4B4Bit.rawValue, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, denseGemma4Enabled: false)
        #expect(defaults.string(forKey: "epistemos.preferredChatModelSelection") == cloudRaw)
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == LocalTextModelID.qwen3_4B4Bit.rawValue)
    }

    @Test("the migration runs ONCE (keyed) — a re-picked GGUF Gemma after migration is preserved")
    func migrationRunsOnce() {
        let defaults = makeDefaults("once")
        let ownerGguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, denseGemma4Enabled: false)
        #expect(defaults.bool(forKey: "epistemos.ggufGemmaToMlxMigratedV1"))

        // The owner deliberately re-picks the GGUF Gemma after the one-time migration — not re-stomped.
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, denseGemma4Enabled: false)
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == ownerGguf)
    }

    @Test("dense MLX gemma4 gate defaults to awaiting-loader when its flag is OFF; MoE/31B always gated")
    func gateDefaultsAwaitingWhenFlagOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0"] == nil {
            #expect(LocalTextModelID.gemma4_2B4Bit.isAwaitingSwiftRuntimeLoader)
            #expect(LocalTextModelID.gemma4_4B4Bit.isAwaitingSwiftRuntimeLoader)
            #expect(LocalTextModelID.mlxGemma4DenseRunnableEnabled == false)
        }
        #expect(LocalTextModelID.gemma4_27BA4B4Bit.isAwaitingSwiftRuntimeLoader)
        #expect(LocalTextModelID.gemma4_31BJANG.isAwaitingSwiftRuntimeLoader)
        // Gemma 3 is the proven-runnable MLX Gemma — never awaiting a loader regardless of any flag.
        #expect(!LocalTextModelID.gemma3_4BQAT4Bit.isAwaitingSwiftRuntimeLoader)
    }

    // The migration only REACHES chat if its target survives the resolver. `migrateGgufGemmaDefaultToMlx`
    // sets the preferred pick to gemma3_4BQAT4Bit, but `sanitizedInteractiveLocalTextModelID` only honors
    // a pick that `supportedInteractiveLocalTextModels` (InferenceState.swift:4168) admits — otherwise it
    // is swapped back toward Qwen and the owner-facing fix silently stops reaching. These pin exactly the
    // predicates that filter (4173-4177) + the shipped-models preference (4184), so if any later flips the
    // regression is caught here rather than as another "chat still defaults to Qwen" report.
    @Test("the gemma3 migration target survives the resolver (release-validated + shipped + MLX + not awaiting) — so the fix reaches chat")
    func gemma3MigrationTargetSurvivesResolver() {
        let g3 = LocalTextModelID.gemma3_4BQAT4Bit
        #expect(g3.isReleaseValidatedForInteractiveChat)  // passes the release-validation filter (not Qwen3.5 / gemma4 / experimental)
        #expect(g3.isEpistemosShippedLocalModel)          // wins the shipped-models preference (4184)
        #expect(!g3.isAwaitingSwiftRuntimeLoader)         // genuinely runnable (stable native gemma3 loader)
        #expect(g3.runtimeKind == .mlx)                   // ∈ availableLocalGenerationRuntimeKinds ([.mlx]) when the GGUF lane is off
        #expect(!g3.isExperimentalForEpistemos)           // not hidden behind the experimental gate
    }

    // The POST-LOAD repair (owner computer-use proof 2026-06-21) is the robust half: the pre-load
    // migration's rewrite did not land on a real launch (the GGUF-id persisted load is
    // LocalTextModelID-gated → falls back to the GGUF foundation default), so the unrunnable GGUF
    // arrives in-memory AFTER migration. `repairedGgufGemmaSelection` re-checks the FINAL values.

    @Test("post-load repair: a GGUF Gemma selection (lane off) → runnable MLX Gemma 3 in BOTH fields")
    func postLoadRepairFixesGgufDefault() {
        let gguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        let repaired = InferenceState.repairedGgufGemmaSelection(
            localID: gguf,
            selection: .localMLX(gguf),
            ggufLaneAvailable: false,
            denseGemma4Enabled: false
        )
        let gemma3 = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        #expect(repaired?.localID == gemma3)
        #expect(repaired?.selection.rawValue == ChatModelSelection.localMLX(gemma3).rawValue)
    }

    @Test("post-load repair is a NO-OP when the GGUF lane IS available (deliberate GGUF pick honored)")
    func postLoadRepairNoOpWhenLaneAvailable() {
        let gguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        #expect(InferenceState.repairedGgufGemmaSelection(
            localID: gguf, selection: .localMLX(gguf),
            ggufLaneAvailable: true, denseGemma4Enabled: false) == nil)
    }

    @Test("post-load repair is idempotent — an already-runnable MLX Gemma 3 / Qwen pick is untouched")
    func postLoadRepairIdempotent() {
        let gemma3 = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        #expect(InferenceState.repairedGgufGemmaSelection(
            localID: gemma3, selection: .localMLX(gemma3),
            ggufLaneAvailable: false, denseGemma4Enabled: false) == nil)
        let qwen = LocalTextModelID.qwen3_4B4Bit.rawValue
        #expect(InferenceState.repairedGgufGemmaSelection(
            localID: qwen, selection: .localMLX(qwen),
            ggufLaneAvailable: false, denseGemma4Enabled: false) == nil)
    }
}
