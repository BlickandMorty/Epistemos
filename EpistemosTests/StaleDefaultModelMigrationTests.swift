import Testing
import Foundation

@testable import Epistemos

// SS-CHATMODEL P0 (owner 2026-06-21, 5th report) — the EXISTING-install path. The prior fix
// (89ef5a206) only set the FRESH-install default to Gemma; an existing install with a persisted
// Qwen kept Qwen (saved pick loads after init + wins). These exercise the one-time migration that
// reaches existing installs: a persisted Qwen DEFAULT → the headroom-aware Gemma, while a deliberate
// larger/explicit Qwen pick is preserved and the migration runs exactly once.
@Suite("SS-CHATMODEL P0 — existing-install stale-Qwen → Gemma migration")
struct StaleDefaultModelMigrationTests {

    private func makeDefaults(_ name: String) -> UserDefaults {
        let suite = "test.staleDefaultModel.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private var snapshot: LocalHardwareCapabilitySnapshot {
        LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 16_000_000_000,
            roundedMemoryGB: 16,
            maxRecommendedLocalContentLength: 4_000
        )
    }

    @Test("an existing install with a persisted Qwen DEFAULT is migrated to Gemma (the reaching fix)")
    func existingQwenDefaultMigratesToGemma() {
        let defaults = makeDefaults("qwen")
        let staleQwen = LocalTextModelID.qwen3_4B4Bit.rawValue
        defaults.set(staleQwen, forKey: "epistemos.preferredLocalTextModelID")
        defaults.set(ChatModelSelection.localMLX(staleQwen).rawValue, forKey: "epistemos.preferredChatModelSelection")

        InferenceState.migrateStaleDefaultModel(defaults: defaults, snapshot: snapshot)

        let gemma = InferenceState.initialDefaultLocalTextModelID(for: snapshot)
        // The chat surface's source of truth flips to Gemma — this is what reaches the owner.
        #expect(defaults.string(forKey: "epistemos.preferredChatModelSelection")
                == ChatModelSelection.localMLX(gemma).rawValue)
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == gemma)
        #expect(gemma != staleQwen)
        #expect(!gemma.lowercased().contains("qwen"))
    }

    @Test("a deliberate larger Qwen pick (8B) is PRESERVED — only the old 4B default migrates")
    func deliberateQwen8BPreserved() {
        let defaults = makeDefaults("qwen8b")
        let qwen8B = LocalTextModelID.qwen3_8B4Bit.rawValue
        defaults.set(qwen8B, forKey: "epistemos.preferredLocalTextModelID")
        defaults.set(ChatModelSelection.localMLX(qwen8B).rawValue, forKey: "epistemos.preferredChatModelSelection")

        InferenceState.migrateStaleDefaultModel(defaults: defaults, snapshot: snapshot)

        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == qwen8B)
        #expect(defaults.string(forKey: "epistemos.preferredChatModelSelection")
                == ChatModelSelection.localMLX(qwen8B).rawValue)
    }

    @Test("the migration runs ONCE (gated by epistemos.modelDefaultMigratedV2) — re-picked Qwen survives")
    func migrationRunsOnce() {
        let defaults = makeDefaults("once")
        let staleQwen = LocalTextModelID.qwen3_4B4Bit.rawValue
        defaults.set(staleQwen, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateStaleDefaultModel(defaults: defaults, snapshot: snapshot)
        #expect(defaults.bool(forKey: "epistemos.modelDefaultMigratedV2"))

        // The owner deliberately re-picks Qwen after the one-time migration — must NOT be re-stomped.
        defaults.set(staleQwen, forKey: "epistemos.preferredLocalTextModelID")
        InferenceState.migrateStaleDefaultModel(defaults: defaults, snapshot: snapshot)
        #expect(defaults.string(forKey: "epistemos.preferredLocalTextModelID") == staleQwen)
    }

    @Test("a CLOUD selection is untouched (no SS-CR regression)")
    func cloudSelectionUntouched() {
        let defaults = makeDefaults("cloud")
        // Seed a non-local (cloud-ish) selection raw value; the migration only matches .localMLX(qwen4B).
        let cloudRaw = ChatModelSelection.localMLX("some-other-model").rawValue
        defaults.set(cloudRaw, forKey: "epistemos.preferredChatModelSelection")
        InferenceState.migrateStaleDefaultModel(defaults: defaults, snapshot: snapshot)
        #expect(defaults.string(forKey: "epistemos.preferredChatModelSelection") == cloudRaw)
    }

    @Test("Reset Everything re-seeds the Gemma default, never the hardcoded-Qwen recommendation")
    func resetSeedsGemmaNotQwen() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        // The reset path resolves the headroom-aware Gemma, not recommendedLocalTextModelID (Qwen).
        #expect(src.contains("resetDefaultModelID = InferenceState.initialDefaultLocalTextModelID"))
        #expect(src.contains("setPreferredChatModelSelection(.localMLX(resetDefaultModelID))"))
        // The Qwen re-seed on reset is gone.
        #expect(!src.contains(".localMLX(inferenceState.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue)"))
    }
}
