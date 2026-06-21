import Testing
import Foundation

@testable import Epistemos

// SS-CHATMODEL / SS-HF (owner 2026-06-21): the chat-composer honesty note must state the REAL
// reason a picked local model can't run as-selected. The owner's actual persisted pick (verified
// via `defaults read com.epistemos.app`) is a GGUF Gemma — `google/gemma-4-E2B-it-qat-q4_0-gguf`
// — which IS installed but can't run because the GGUF runtime lane is off on the MAS build
// (availableLocalGenerationRuntimeKinds defaults to [.mlx]; the llama-cli subprocess is
// sandbox-blocked, Pro/dev-gated). Before this fix, `localPickUnavailableReason` reported
// `.notInstalled` for it — false — because the runtime check only ran inside
// `if let model = LocalTextModelID(rawValue:)` and a GGUF candidate id is not a LocalTextModelID,
// so it fell through to the `.notInstalled` default. These pin the corrected reason via the pure
// nonisolated seam, exercised with the owner's exact persisted pick. The seam is display-only
// (its result flows only into the `.substituted` / `.noLocalModel` honesty states); routing is
// untouched, so this guard adds no SS-CR risk.
@Suite("SS-CHATMODEL — GGUF Gemma honest unavailability reason")
struct LocalGgufPickReasonTests {

    /// The owner's actual persisted pick (verified via `defaults read`, 2026-06-21).
    private let ownerGgufPick = "google/gemma-4-E2B-it-qat-q4_0-gguf"

    @Test("the owner's installed GGUF Gemma reports .runtimeUnavailable when the GGUF lane is off")
    func ownerGgufPickIsRuntimeUnavailableNotNotInstalled() {
        // Real state: GGUF lane off (the default MLX-only runtime set on a MAS build).
        let reason = InferenceState.ggufGemmaCandidateRuntimeReason(
            pickID: ownerGgufPick,
            availableRuntimeKinds: [.mlx]
        )
        #expect(reason == .runtimeUnavailable)
        // The exact bug this guards: it must NOT be the false "not installed".
        #expect(reason != .notInstalled)
    }

    @Test("the same GGUF Gemma is not flagged when the GGUF lane IS available (Pro/dev build)")
    func ggufPickRunnableWhenLaneAvailable() {
        let reason = InferenceState.ggufGemmaCandidateRuntimeReason(
            pickID: ownerGgufPick,
            availableRuntimeKinds: [.mlx, .gguf]
        )
        #expect(reason == nil)
    }

    @Test("a non-Gemma pick (Qwen MLX id) is not claimed by the GGUF reason seam")
    func nonGemmaPickReturnsNil() {
        let reason = InferenceState.ggufGemmaCandidateRuntimeReason(
            pickID: LocalTextModelID.qwen3_4B4Bit.rawValue,
            availableRuntimeKinds: [.mlx]
        )
        #expect(reason == nil)
    }

    @Test("every staged GGUF Gemma candidate id resolves the same honest runtime reason")
    func allGgufGemmaCandidatesRuntimeUnavailable() {
        for id in [
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "google/gemma-4-E4B-it-qat-q4_0-gguf",
            "google/gemma-4-12B-it-qat-q4_0-gguf"
        ] {
            #expect(
                InferenceState.ggufGemmaCandidateRuntimeReason(pickID: id, availableRuntimeKinds: [.mlx])
                    == .runtimeUnavailable
            )
        }
    }
}
