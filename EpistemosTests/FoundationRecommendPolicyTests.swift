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
    // Cloud-only migration: fix-(1) auto-mode local-brain recommendation tests were
    // removed — AgentCommandCenterState.preferredLocalBrainID and
    // .foundationRecommendArmed were deleted with the local-model routing stack.
    // The fix-(2) stored-brain classification below is a KEPT surface
    // (classifyStoredBrain / honestUnavailableSpecialistPickArmed still exist).

    // MARK: - fix (2): stored-brain classification (honest unavailable pick)

    @Test("classifyStoredBrain: nil / \"auto\" → .auto")
    func classifyAuto() {
        #expect(AgentCommandCenterState.classifyStoredBrain(storedID: nil, availableIDs: ["local:x"]) == .auto)
        #expect(AgentCommandCenterState.classifyStoredBrain(storedID: "auto", availableIDs: ["local:x"]) == .auto)
    }

    @Test("classifyStoredBrain: explicit pick that IS available → .available")
    func classifyAvailable() {
        #expect(
            AgentCommandCenterState.classifyStoredBrain(
                storedID: "local:gemma", availableIDs: ["local:gemma", "local:qwen"]
            ) == .available
        )
    }

    @Test("classifyStoredBrain: explicit pick NOT available → .unavailableExplicitPick (no silent Qwen)")
    func classifyUnavailable() {
        #expect(
            AgentCommandCenterState.classifyStoredBrain(
                storedID: "local:gemma", availableIDs: ["local:qwen"]
            ) == .unavailableExplicitPick
        )
    }

    @Test("honest-unavailable-specialist-pick flag is OFF by default (today's behaviour)")
    func honestFlagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_HONEST_UNAVAILABLE_SPECIALIST_PICK_V0"] == nil {
            #expect(AgentCommandCenterState.honestUnavailableSpecialistPickArmed == false)
        }
    }
}
