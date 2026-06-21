import Testing
import Foundation

@testable import Epistemos

// L1134 DEFAULT=QWEN4B REPAIR (owner 2026-06-18: "the picker/chat still DEFAULTS to Qwen 3 4B").
// Root: InferenceState.init seeded preferredLocalTextModelID from the hardware snapshot's
// recommendedLocalTextModelID, which is hardcoded .qwen3_4B4Bit. Under the simplified Fast/Think/Code
// lineup the fresh-install default must instead be a headroom-aware foundation FAST Gemma (E2B/E4B on
// 16 GB), NEVER Qwen — both Qwens stay explicit-only picks. This routing-matrix guard exercises the
// new resolver across a hardware matrix so the default can never silently regress to Qwen (or to a
// memory-tight model). A saved explicit pick is loaded after init and always wins, so this only
// governs the fresh-install / unset default.
@Suite("L1134 — Fast default routing matrix (never Qwen, headroom-aware Gemma)")
struct FastDefaultRoutingMatrixTests {

    /// Hardware sizes spanning the shipped range (owner's M2 Pro 16 GB included).
    private let memoryMatrixGB = [8, 16, 24, 36, 64]

    private func snapshot(_ gb: Int) -> LocalHardwareCapabilitySnapshot {
        LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: UInt64(gb) * 1_000_000_000,
            roundedMemoryGB: gb,
            maxRecommendedLocalContentLength: 4_000
        )
    }

    private var fastFoundationIDs: Set<String> {
        Set(EpistemosFoundationLineup.candidates(for: .fast).map(\.id))
    }

    private func minRec(_ id: String) -> Int? {
        EpistemosFoundationLineup.candidates(for: .fast).first { $0.id == id }?.minimumRecommendedMemoryGB
    }

    @Test("every hardware size defaults to a foundation FAST Gemma — never Qwen, never empty")
    func defaultIsAlwaysFastGemmaNeverQwen() {
        for gb in memoryMatrixGB {
            let id = InferenceState.initialDefaultLocalTextModelID(for: snapshot(gb))
            #expect(!id.isEmpty, "\(gb)GB default must be non-empty")
            #expect(
                id != LocalTextModelID.qwen3_4B4Bit.rawValue,
                "\(gb)GB default must NOT be Qwen 3 4B (the L1134 bug)"
            )
            #expect(
                !id.lowercased().contains("qwen"),
                "\(gb)GB default must not be any Qwen id, got \(id)"
            )
            #expect(
                fastFoundationIDs.contains(id),
                "\(gb)GB default must be a foundation FAST Gemma candidate, got \(id)"
            )
        }
    }

    @Test("the default is headroom-monotonic — more memory never picks a smaller model")
    func defaultIsHeadroomMonotonic() {
        var lastMinRec = Int.min
        for gb in memoryMatrixGB {
            let id = InferenceState.initialDefaultLocalTextModelID(for: snapshot(gb))
            guard let rec = minRec(id) else { continue }
            #expect(rec >= lastMinRec, "\(gb)GB picked a smaller model than a smaller machine did")
            lastMinRec = rec
        }
    }

    @Test("the owner's 16 GB default is a comfortable Gemma (not memory-tight, not the heaviest)")
    func sixteenGBDefaultIsComfortable() {
        let id = InferenceState.initialDefaultLocalTextModelID(for: snapshot(16))
        #expect(fastFoundationIDs.contains(id))
        #expect(id != LocalTextModelID.qwen3_4B4Bit.rawValue)
        if let rec = minRec(id) {
            // Comfortable headroom (the resolver's +4 GB rule) → never the heaviest Fast model.
            #expect(rec + 4 <= 16, "16GB default \(id) (minRec \(rec)) is memory-tight")
        }
        // And it is never the largest Fast candidate (the explicit-only MoE flagship).
        let largest = EpistemosFoundationLineup.candidates(for: .fast)
            .max(by: { ($0.minimumRecommendedMemoryGB) < ($1.minimumRecommendedMemoryGB) })?.id
        if let largest, EpistemosFoundationLineup.candidates(for: .fast).count > 1 {
            #expect(id != largest, "16GB must not default to the heaviest Fast model")
        }
    }

    @Test("init no longer seeds the Qwen recommendation; it routes through the resolver")
    func initWiringUsesResolver() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        #expect(src.contains("Self.initialDefaultLocalTextModelID(for: hardwareCapabilitySnapshot)"))
        // The raw Qwen-seeding line is gone from init's default assignment.
        #expect(!src.contains("self.preferredLocalTextModelID = hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue"))
    }
}
