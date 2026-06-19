import Testing
import Foundation
@testable import Epistemos

/// Model-selection fix (1) (ledger AgentCommandCenterState verification 7e70a432a):
/// auto-mode `recommendedBrain` recommended Qwen-first via `[LocalTextModelID]`
/// lists that structurally exclude the foundation GGUF lineup. The
/// `preferredLocalBrainID` policy lets auto-mode prefer an installed foundation
/// model when armed, preserving the legacy behaviour when off. Pure → tested here
/// without constructing the @MainActor state.
@Suite("Foundation-recommend auto-mode policy (model-selection fix 1)")
struct FoundationRecommendPolicyTests {
    let foundation: Set<String> = [
        "google/gemma-4-E2B-it-qat-q4_0-gguf",
        "oussaber/VibeThinker-3B-Q4_K_M-GGUF",
    ]

    @Test("not armed → legacy: the first AVAILABLE legacy-preferred id (byte-identical)")
    func notArmedLegacy() {
        let chosen = AgentCommandCenterState.preferredLocalBrainID(
            foundationIDs: foundation,
            availableLocalIDs: ["qwen3_4B4Bit", "google/gemma-4-E2B-it-qat-q4_0-gguf"],
            legacyPreferred: ["deepseekR1Distill7B", "qwen3_4B4Bit"],
            armed: false
        )
        #expect(chosen == "qwen3_4B4Bit") // deepseek not available → first available legacy pick
    }

    @Test("armed → an installed foundation model is preferred over the legacy Qwen-first list")
    func armedPrefersFoundation() {
        let chosen = AgentCommandCenterState.preferredLocalBrainID(
            foundationIDs: foundation,
            availableLocalIDs: ["qwen3_4B4Bit", "google/gemma-4-E2B-it-qat-q4_0-gguf"],
            legacyPreferred: ["qwen3_4B4Bit"],
            armed: true
        )
        #expect(chosen == "google/gemma-4-E2B-it-qat-q4_0-gguf")
    }

    @Test("armed but NO foundation installed → falls to the legacy preference (honest)")
    func armedNoFoundationFallsToLegacy() {
        let chosen = AgentCommandCenterState.preferredLocalBrainID(
            foundationIDs: foundation,
            availableLocalIDs: ["qwen3_4B4Bit", "deepseekR1Distill7B"],
            legacyPreferred: ["deepseekR1Distill7B", "qwen3_4B4Bit"],
            armed: true
        )
        #expect(chosen == "deepseekR1Distill7B")
    }

    @Test("neither foundation nor legacy available → nil (caller uses its first-local fallback)")
    func neitherAvailableNil() {
        #expect(
            AgentCommandCenterState.preferredLocalBrainID(
                foundationIDs: foundation,
                availableLocalIDs: ["someOtherModel"],
                legacyPreferred: ["qwen3_4B4Bit"],
                armed: true
            ) == nil
        )
    }

    @Test("flag is OFF by default → legacy recommendation behaviour")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_FOUNDATION_RECOMMEND_V0"] == nil {
            #expect(AgentCommandCenterState.foundationRecommendArmed == false)
        }
    }
}
