import Testing
import Foundation

@testable import Epistemos

// SS-CHATPICKER P0 (owner: "other models installed but won't let me click them"): the runtime picker
// built rows only from the fixed foundation lineup + 2 static Qwen, never the user's installed/
// advertised models, so installed models outside that lineup were silently absent. Environment now
// carries `additionalPicks` (the panel computes them from installed ∪ advertised); these pin that
// options() includes them per tier, deduped against the lineup + static extras, gated honestly.
@Suite("EpistemosRuntimePicker — additionalPicks (installed/advertised models reach the picker)")
struct EpistemosRuntimePickerAdditionalPicksTests {

    private func env(
        installed: Set<String>,
        freeGB: Int = 64,
        additional: [EpistemosRuntimePicker.ExtraPick]
    ) -> EpistemosRuntimePicker.Environment {
        .init(
            installedModelIDs: installed,
            freeMemoryGB: freeGB,
            appleIntelligenceAvailable: false,
            additionalPicks: additional
        )
    }

    @Test("an installed additional pick appears as a SELECTABLE option in its tier")
    func additionalPickAppearsSelectable() {
        let id = "mlx-community/gemma-3-4b-it-qat-4bit"
        let pick = EpistemosRuntimePicker.ExtraPick(id: id, title: "Gemma 3 4B", tier: .fast, minimumMemoryGB: 6)
        let options = EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [id], additional: [pick]))
        let row = options.first { $0.id == id }
        #expect(row != nil)
        #expect(row?.isSelectable == true)   // installed + fits (64 GB free) → clickable
        #expect(row?.title == "Gemma 3 4B")
    }

    @Test("an additional pick only appears in its own tier")
    func additionalPickTierScoped() {
        let id = "some/think-model"
        let pick = EpistemosRuntimePicker.ExtraPick(id: id, title: "Think Model", tier: .think, minimumMemoryGB: 8)
        let e = env(installed: [id], additional: [pick])
        #expect(EpistemosRuntimePicker.options(for: .think, environment: e).contains { $0.id == id })
        #expect(!EpistemosRuntimePicker.options(for: .fast, environment: e).contains { $0.id == id })
        #expect(!EpistemosRuntimePicker.options(for: .code, environment: e).contains { $0.id == id })
    }

    @Test("an additional pick duplicating a static extra (Qwen 8B) is NOT shown twice")
    func dedupAgainstStaticExtras() {
        let qwen8 = "Qwen/Qwen3-8B-MLX-4bit"  // already a static .think extraPick
        let pick = EpistemosRuntimePicker.ExtraPick(id: qwen8, title: "Dup", tier: .think, minimumMemoryGB: 12)
        let options = EpistemosRuntimePicker.options(for: .think, environment: env(installed: [qwen8], additional: [pick]))
        #expect(options.filter { $0.id == qwen8 }.count == 1)
    }

    @Test("a not-installed additional pick still appears, honestly blocked (never silently absent)")
    func notInstalledAdditionalPickBlocked() {
        let id = "some/not-installed"
        let pick = EpistemosRuntimePicker.ExtraPick(id: id, title: "X", tier: .fast, minimumMemoryGB: 6)
        let row = EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [], additional: [pick])).first { $0.id == id }
        #expect(row != nil)
        #expect(row?.isSelectable == false)
        #expect(row?.blockedReason?.contains("Not installed") == true)
    }

    @Test("empty additionalPicks → today's behavior preserved (lineup + statics + AI, no crash)")
    func emptyAdditionalPreservesBehavior() {
        let baseline = EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [], additional: []))
        #expect(baseline.contains { $0.isAppleIntelligence })
    }

    // MARK: - RuntimePickerExtraPicksBuilder (slice 2 — the panel computes additionalPicks from this)

    @Test("builder maps a known installed non-lineup model to a pick with title + memory")
    func builderResolvesKnownModel() {
        let id = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        let pick = RuntimePickerExtraPicksBuilder.picks(installedIDs: [id], advertised: [], isCustomized: false).first { $0.id == id }
        #expect(pick != nil)
        #expect((pick?.minimumMemoryGB ?? 0) > 0)
        #expect(pick?.title.isEmpty == false)
    }

    @Test("builder skips an unrecognised id (a stray on-disk dir) — never a phantom pick")
    func builderSkipsUnknown() {
        #expect(RuntimePickerExtraPicksBuilder.picks(installedIDs: ["stray/not-a-real-model"], advertised: [], isCustomized: false).isEmpty)
    }

    @Test("builder skips ids already in the fixed lineup / static extras (no cross-tier duplicate)")
    func builderSkipsLineup() {
        let qwen4 = "Qwen/Qwen3-4B-MLX-4bit"  // a static .think extraPick
        #expect(RuntimePickerExtraPicksBuilder.picks(installedIDs: [qwen4], advertised: [], isCustomized: false).isEmpty)
    }

    @Test("advertised filter: when customized, only advertised non-lineup ids are offered")
    func builderAdvertisedFilter() {
        let g3 = LocalTextModelID.gemma3_4BQAT4Bit.rawValue
        let llama = LocalTextModelID.llama32_3BInstruct4Bit.rawValue
        let all = RuntimePickerExtraPicksBuilder.picks(installedIDs: [g3, llama], advertised: [], isCustomized: false)
        #expect(all.contains { $0.id == g3 } && all.contains { $0.id == llama })
        let filtered = RuntimePickerExtraPicksBuilder.picks(installedIDs: [g3, llama], advertised: [g3], isCustomized: true)
        #expect(filtered.contains { $0.id == g3 })
        #expect(!filtered.contains { $0.id == llama })
    }

    @Test("tier heuristic: coder→code, reasoning→think, plain→fast")
    func builderTierHeuristic() {
        #expect(RuntimePickerExtraPicksBuilder.tier(forID: "x/qwen3-coder-next", displayName: "Qwen Coder") == .code)
        #expect(RuntimePickerExtraPicksBuilder.tier(forID: "x/deepseek-r1-distill", displayName: "DeepSeek R1") == .think)
        #expect(RuntimePickerExtraPicksBuilder.tier(forID: "x/some-chat", displayName: "Some Chat") == .fast)
    }
}
