import Testing
import Foundation

@testable import Epistemos

// SS-CHATMODEL P0 (owner 2026-06-21, NO-FALLBACKS — "the substitution still HAPPENS"): the owner is
// stuck on a persisted GGUF Gemma (`google/gemma-4-E2B-it-qat-q4_0-gguf`) that can't run while the
// GGUF lane is off, so resolution substitutes Qwen. The fix makes the dense Gemma 4 E2B/E4B MLX
// tiers runnable (their native Apple loader is vendored + registered; the gate that called them
// "awaiting loader" is the stale half of a contradiction the code itself flags in
// `isHeldOutOfAutomaticLocalRouting`) and migrates the persisted GGUF Gemma → the same-size MLX
// Gemma so the picked model actually RUNS with NO substitution. Both are gated behind
// EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0 (default OFF, reversible) pending the owner's on-device
// confirmation — headless `swift test` can't load the MLX metallib to prove generation here, but
// the owner's real app bundle can. These pin the pure mapping, the real-state migration (flag ON),
// the no-op safety (flag OFF), and the conservative default gate.
@Suite("SS-CHATMODEL P0 — GGUF Gemma → runnable MLX Gemma (owner NO-FALLBACKS)")
struct MlxGemma4DenseRunnableMigrationTests {

    private func makeDefaults(_ name: String) -> UserDefaults {
        let suite = "test.ggufGemmaToMlx.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test("the owner's GGUF E2B/E4B map to the dense MLX gemma4 ids (pure mapping)")
    func ggufMapsToMlx() {
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: "google/gemma-4-E2B-it-qat-q4_0-gguf")
                == LocalTextModelID.gemma4_2B4Bit.rawValue)
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: "google/gemma-4-E4B-it-qat-q4_0-gguf")
                == LocalTextModelID.gemma4_4B4Bit.rawValue)
    }

    @Test("non-Gemma / non-GGUF / already-MLX / 12B ids are NOT remapped (deliberate picks preserved)")
    func nonMatchingPreserved() {
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: LocalTextModelID.qwen3_4B4Bit.rawValue) == nil)
        // Already an MLX id (not GGUF) → not remapped.
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: LocalTextModelID.gemma4_2B4Bit.rawValue) == nil)
        // 12B GGUF has no dense MLX equivalent → left as-is.
        #expect(InferenceState.mlxEquivalent(forGgufGemmaID: "google/gemma-4-12B-it-qat-q4_0-gguf") == nil)
    }

    @Test("real-state: persisted GGUF E2B + flag ON → MLX E2B, never Qwen, never GGUF")
    func ownerGgufStateMigratesToRunnableMlx() {
        let defaults = makeDefaults("on")
        let ownerGguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        defaults.set(ChatModelSelection.localMLX(ownerGguf).rawValue, forKey: "epistemos.preferredChatModelSelection")

        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, enabled: true)

        let mlxE2B = LocalTextModelID.gemma4_2B4Bit.rawValue
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == mlxE2B)
        #expect(defaults.string(forKey: "epistemos.preferredChatModelSelection")
                == ChatModelSelection.localMLX(mlxE2B).rawValue)
        let resolved = defaults.string(forKey: "epistemos.preferredLocalTextModelID") ?? ""
        #expect(!resolved.lowercased().contains("qwen"))
        #expect(!resolved.lowercased().contains("gguf"))
    }

    @Test("flag OFF → no migration (byte-identical persisted state, provably safe / no SS-CR risk)")
    func flagOffNoMigration() {
        let defaults = makeDefaults("off")
        let ownerGguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, enabled: false)
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == ownerGguf)
    }

    @Test("the migration runs ONCE (keyed) — a re-picked GGUF Gemma after migration is preserved")
    func migrationRunsOnce() {
        let defaults = makeDefaults("once")
        let ownerGguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, enabled: true)
        #expect(defaults.bool(forKey: "epistemos.ggufGemmaToMlxMigratedV0"))

        // The owner deliberately re-picks the GGUF Gemma after the one-time migration — not re-stomped.
        defaults.set(ownerGguf, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateGgufGemmaDefaultToMlx(defaults: defaults, enabled: true)
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == ownerGguf)
    }

    @Test("dense MLX gemma4 gate defaults to awaiting-loader when the flag is OFF; MoE/31B always gated")
    func gateDefaultsAwaitingWhenFlagOff() {
        // The test process sets no env var → flag OFF → dense tiers stay awaiting-loader, preserving
        // the conservative contract TriageServiceTests pins (all 4 tiers gated by default).
        if ProcessInfo.processInfo.environment["EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0"] == nil {
            #expect(LocalTextModelID.gemma4_2B4Bit.isAwaitingSwiftRuntimeLoader)
            #expect(LocalTextModelID.gemma4_4B4Bit.isAwaitingSwiftRuntimeLoader)
            #expect(LocalTextModelID.mlxGemma4DenseRunnableEnabled == false)
        }
        // MoE + 31B are unconditionally awaiting — no flag flips them.
        #expect(LocalTextModelID.gemma4_27BA4B4Bit.isAwaitingSwiftRuntimeLoader)
        #expect(LocalTextModelID.gemma4_31BJANG.isAwaitingSwiftRuntimeLoader)
    }
}
