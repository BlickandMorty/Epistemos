import Testing
import Foundation

@testable import Epistemos

// SS-CHATMODEL P0 — VERIFICATION CEILING (owner 2026-06-21): a Debug launch CANNOT verify the
// POST-LOAD repair, because a Debug build carries the GGUF subprocess lane → `.gguf` is present in
// `availableLocalGenerationRuntimeKinds` → the owner's persisted GGUF pick is "runnable", the bug does
// not reproduce, and `repairUnrunnableGgufGemmaSelection` no-ops. Only the MAS condition (the
// subprocess is sandbox-blocked → `.gguf` absent) triggers the repair. So computer-use on a Debug
// build proves nothing.
//
// This is the deterministic, HEADLESS integration test that FORCES the MAS condition through the FULL
// model-selection init. In a test process `availableLocalGenerationRuntimeKinds` keeps its `[.mlx]`
// default (the setter is never called in init) — exactly the MAS condition — so we replicate the
// owner's EXACT real state: persisted GGUF-E2B in both keys PLUS the polluted `ggufGemmaToMlxMigratedV1`
// flag, so the pre-load migration's once-only guard SKIPS and only the post-load repair can fix it.
// Then we construct InferenceState (the real init: load → post-load repair) and assert BOTH persisted
// UserDefaults keys (what `defaults read` shows) AND the in-memory selection (what the chat surface
// reads) become the runnable MLX Gemma 3 — never Qwen, never GGUF. The pure-mapping test was not
// enough; this proves the repair RUNS + PERSISTS under the owner condition.
@Suite("SS-CHATMODEL P0 — POST-LOAD repair integration (MAS condition)", .serialized)
@MainActor
struct GgufGemmaPostLoadRepairIntegrationTests {

    private static let localKey = "epistemos.preferredLocalTextModelID"
    private static let selectionKey = "epistemos.preferredChatModelSelection"
    private static let migratedV1Key = "epistemos.ggufGemmaToMlxMigratedV1"
    private static let touchedKeys = [localKey, selectionKey, migratedV1Key]

    @Test("owner MAS state (persisted GGUF-E2B + polluted V1, gguf lane off) → full init persists gemma3 in BOTH keys")
    func fullInitRepairsGgufToGemma3UnderMASCondition() {
        let defaults = UserDefaults.standard
        // Save + clear the keys this test mutates; restore after so there is no global pollution leak.
        let saved = Self.touchedKeys.reduce(into: [String: Any?]()) { acc, key in
            acc[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in Self.touchedKeys {
                if let value = saved[key] ?? nil { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        // Seed the owner's EXACT real persisted state: GGUF-E2B in both keys + the polluted migratedV1
        // flag — so the pre-load migration SKIPS (once-only guard) and only the post-load repair fixes it.
        let ownerGguf = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        defaults.set(ownerGguf, forKey: Self.localKey)
        defaults.set(ChatModelSelection.localMLX(ownerGguf).rawValue, forKey: Self.selectionKey)
        defaults.set(true, forKey: Self.migratedV1Key)

        // Run the FULL model-selection init on a 16 GB rig (the owner's hardware); keychain stubbed.
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 16_000_000_000,
                roundedMemoryGB: 16,
                maxRecommendedLocalContentLength: 4_000
            ),
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        // Precondition: the MAS condition holds — the GGUF lane is NOT available, so the repair MUST fire.
        #expect(inference.availableLocalGenerationRuntimeKinds == [.mlx])

        let gemma3 = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        // The PERSISTED keys are rewritten — a `defaults read` after launch shows gemma3 (the owner's check).
        #expect(defaults.string(forKey: Self.localKey) == gemma3)
        #expect(defaults.string(forKey: Self.selectionKey) == ChatModelSelection.localMLX(gemma3).rawValue)
        // And the live in-memory selection the chat surface reads is the runnable Gemma 3, never Qwen/GGUF.
        #expect(inference.preferredLocalTextModelID == gemma3)
        #expect(inference.preferredChatModelSelection.rawValue == ChatModelSelection.localMLX(gemma3).rawValue)
    }
}
