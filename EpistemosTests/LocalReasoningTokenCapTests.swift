import Foundation
import Testing
@testable import Epistemos

/// Master Fusion Plan §B.4 — pin the per-model reasoning-token cap
/// doctrine table at `LocalTextModelID.reasoningTokenCap`.
///
/// The Brief-Is-Better study (cited in
/// `docs/fusion/jordan's research/deterministicapp.md` §1 and the
/// `helios v3.md` study) reports that tiny / small local models drift
/// rapidly when allowed unbounded reasoning chains. The §B.4
/// acceptance bar fixes per-tier caps:
///   - Tiny (≤2B):      16 tokens
///   - Small (3-4B):    32 tokens (the canonical "Brief Is Better" floor)
///   - Mid (7-9B):      64 tokens
///   - Larger / MoE:    256 tokens (doctrine default; headroom but not
///                                  runaway)
///
/// These tests pin a representative model from each tier so any future
/// rebalancing trips CI before user-visible regressions land.
@Suite("RCA-LOCAL-AGENT-REASONING-CAP-001 — Master Fusion §B.4 per-model caps")
struct LocalReasoningTokenCapTests {

    @Test("Tiny tier (≤2B) caps at 16 tokens")
    func tinyTierCapIs16() {
        #expect(LocalTextModelID.qwen35_0_8B4Bit.reasoningTokenCap == 16)
        #expect(LocalTextModelID.qwen35_2B4Bit.reasoningTokenCap == 16)
        #expect(LocalTextModelID.lfm2_2B4Bit.reasoningTokenCap == 16)
        #expect(LocalTextModelID.mamba2_2B4Bit.reasoningTokenCap == 16)
        #expect(LocalTextModelID.falconH1_1B4Bit.reasoningTokenCap == 16)
    }

    @Test("Small tier (3-4B) caps at the canonical 32-token Brief-Is-Better floor")
    func smallTierCapIs32() {
        #expect(LocalTextModelID.qwen35_4B4Bit.reasoningTokenCap == 32)
        #expect(LocalTextModelID.qwen3_4B4Bit.reasoningTokenCap == 32)
        #expect(LocalTextModelID.gemma4_4B4Bit.reasoningTokenCap == 32)
        #expect(LocalTextModelID.gemma3_4BQAT4Bit.reasoningTokenCap == 32)
        #expect(LocalTextModelID.llama32_3BInstruct4Bit.reasoningTokenCap == 32)
        #expect(LocalTextModelID.smolLM3_3B4Bit.reasoningTokenCap == 32)
        #expect(LocalTextModelID.jamba3B.reasoningTokenCap == 32)
    }

    @Test("Mid tier (7-9B) caps at 64 tokens")
    func midTierCapIs64() {
        #expect(LocalTextModelID.qwen35_9B4Bit.reasoningTokenCap == 64)
        #expect(LocalTextModelID.qwen3_8B4Bit.reasoningTokenCap == 64)
        #expect(LocalTextModelID.falconH1R_7B4Bit.reasoningTokenCap == 64)
        #expect(LocalTextModelID.deepseekR1Distill7B.reasoningTokenCap == 64)
        #expect(LocalTextModelID.qwen25Coder7B.reasoningTokenCap == 64)
    }

    @Test("Larger / MoE / dense agent-tier caps at the canonical 256-token doctrine default")
    func largerTierCapIs256() {
        #expect(LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.reasoningTokenCap == 256)
        #expect(LocalTextModelID.qwen3Coder30BA3B4Bit.reasoningTokenCap == 256)
        #expect(LocalTextModelID.qwqFlagship32B4Bit.reasoningTokenCap == 256)
        #expect(LocalTextModelID.gemma3_27BQAT4Bit.reasoningTokenCap == 256)
        #expect(LocalTextModelID.gemma4_27BA4B4Bit.reasoningTokenCap == 256)
        #expect(LocalTextModelID.mistralSmall31_24B4Bit.reasoningTokenCap == 256)
        #expect(LocalTextModelID.llama4Scout17B16E4Bit.reasoningTokenCap == 256)
    }

    @Test("Every model returns a positive cap — exhaustiveness gate")
    func everyModelHasPositiveCap() {
        // Source-guard: if a future case is added without a tier
        // assignment, the switch is non-exhaustive and the build
        // breaks. If it IS assigned but to zero / negative, this test
        // catches a doctrine drift (the cap surface contract is "0 =
        // unbounded; positive = enforced cap"; the §B.4 doctrine
        // says NO model is unbounded today).
        for model in LocalTextModelID.allCases {
            let cap = model.reasoningTokenCap
            #expect(
                cap > 0,
                "Model \(model.rawValue) returned cap \(cap); B.4 doctrine says no model is unbounded — either assign a positive cap OR (with audit row) opt the model into an unbounded sentinel (0) explicitly."
            )
        }
    }

    @Test("Cap monotonically increases with model size class")
    func capMonotonicallyIncreases() {
        // Doctrine invariant: a model in a smaller tier MUST have a
        // cap ≤ the cap of any model in a larger tier. This is a
        // representative-pair check; a full pairwise check would
        // explode combinatorially. The pairs picked here represent
        // the four tier boundaries.
        #expect(LocalTextModelID.qwen35_0_8B4Bit.reasoningTokenCap
                <= LocalTextModelID.qwen35_4B4Bit.reasoningTokenCap)
        #expect(LocalTextModelID.qwen35_4B4Bit.reasoningTokenCap
                <= LocalTextModelID.qwen3_8B4Bit.reasoningTokenCap)
        #expect(LocalTextModelID.qwen3_8B4Bit.reasoningTokenCap
                <= LocalTextModelID.qwen3Coder30BA3B4Bit.reasoningTokenCap)
    }
}
