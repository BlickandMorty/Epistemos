import Testing
import Foundation

@testable import Epistemos

// L1128 PICKER — owner verbatim "i dont see the low medium high on fast mode". Fast effort was
// auto-derived per-query from complexity and never user-visible/settable. This feature surfaces a
// low/med/high SIZE override in the runtime picker (Fast has no thinking-budget tiers) that pins the
// Gemma band (E2B/E4B/12B), behind EPISTEMOS_FAST_EFFORT_PICKER_V0 (default OFF → byte-identical
// per-query auto). These execute the pure sizing override + pin the flag + the routing/UI wiring.
@Suite("L1128 — Fast effort override sizing")
struct FastEffortOverrideTests {

    typealias FastEffort = EpistemosFastEffortSizing.FastEffort

    @Test("forEffort maps low→smallest, medium→middle, high→largest band")
    func effortBandsMapToAscendingIndices() {
        #expect(EpistemosFastEffortSizing.candidateIndex(forEffort: .low, candidateCount: 3) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forEffort: .medium, candidateCount: 3) == 1)
        #expect(EpistemosFastEffortSizing.candidateIndex(forEffort: .high, candidateCount: 3) == 2)
    }

    @Test("forEffort clamps to the available candidate count (never out of range)")
    func effortIndexClamps() {
        // Only 2 candidates installed → High clamps to the last (index 1), not 2.
        #expect(EpistemosFastEffortSizing.candidateIndex(forEffort: .high, candidateCount: 2) == 1)
        // <2 candidates → nothing to size between → always 0.
        #expect(EpistemosFastEffortSizing.candidateIndex(forEffort: .high, candidateCount: 1) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forEffort: .low, candidateCount: 0) == 0)
    }

    @Test("a pinned effort lands on the SAME band a matching-complexity query auto-sizes to")
    func overrideMatchesComplexityBands() {
        // The override and the auto path must agree on band → index, so pinning "High" gives the same
        // model a high-complexity query would have auto-selected (no surprise divergence).
        let count = 3
        for (effort, complexity) in [(FastEffort.low, 0.10), (.medium, 0.45), (.high, 0.80)] {
            #expect(
                EpistemosFastEffortSizing.candidateIndex(forEffort: effort, candidateCount: count)
                == EpistemosFastEffortSizing.candidateIndex(forComplexity: complexity, candidateCount: count),
                "pinned \(effort) should match the auto band for complexity \(complexity)"
            )
        }
    }

    @Test("the override picker flag defaults OFF (per-query auto stays byte-identical until opt-in)")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_FAST_EFFORT_PICKER_V0"] == nil {
            #expect(EpistemosFastEffortSizing.pickerOverrideEnabled == false)
        }
    }

    @Test("FastEffort exposes exactly low/medium/high for the picker to enumerate")
    func fastEffortCasesAreStable() {
        #expect(FastEffort.allCases == [.low, .medium, .high])
        #expect(FastEffort.low.rawValue == "low")
        #expect(FastEffort.high.displayName == "High")
    }

    @Test("InferenceState gates the override behind the flag and only on the auto-size path")
    func sizingWiringIsFlagGated() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // The override is consulted inside the Fast auto-sizer, guarded by the flag — so flag-off is
        // byte-identical (the complexity branch) and the override never fires behind the user's back.
        #expect(src.contains("EpistemosFastEffortSizing.pickerOverrideEnabled, let pinned = fastEffortOverride"))
        #expect(src.contains("forEffort: pinned"))
        // Persisted setter exists (survives relaunch) and clears to auto on nil.
        #expect(src.contains("func setFastEffortOverride"))
    }

    @Test("the picker mounts the Fast effort selector only behind the flag")
    func pickerMountsBehindFlag() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/InlineRuntimePickerPanel.swift")
        #expect(src.contains("EpistemosFastEffortSizing.pickerOverrideEnabled"))
        #expect(src.contains("fastEffortSection"))
        #expect(src.contains("setFastEffortOverride"))
    }

    @Test("each effort row shows the Gemma it resolves to, via the same band as sizing")
    func effortRowShowsResolvedModel() throws {
        // The resolver shares comfortableInstalledFastCandidatesAscending + candidateIndex(forEffort:)
        // with sizedFastLocalTextModelID, so the picker label never disagrees with what runs.
        let state = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        #expect(state.contains("func fastEffortResolvedModelName"))
        #expect(state.contains("forEffort: effort"))
        #expect(state.contains("comfortableInstalledFastCandidatesAscending()"))
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Chat/InlineRuntimePickerPanel.swift")
        #expect(picker.contains("inference.fastEffortResolvedModelName(for: effort)"))
    }
}
