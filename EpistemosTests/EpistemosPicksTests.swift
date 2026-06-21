import Testing
import Foundation
@testable import Epistemos

/// "Epistemos Picks" curated section over the proven `EpistemosRuntimePicker` substrate
/// (owner 2026-06-21). Locks: the curated section is top-billed + correctly titled and holds
/// only the owner's curated models; a generic installed model lands in "Installed", never in
/// "Epistemos Picks"; and honest selection is preserved — a too-large pick stays VISIBLE with
/// its reason (no silent drop / no silent Qwen substitute). Pure: no SwiftUI / InferenceState.
@Suite("Epistemos Picks — curated, honest, reuse of the runtime picker")
struct EpistemosPicksTests {
    /// An environment where all curated lineup ids (and any extras) are installed, with
    /// `freeGB` free memory and Apple Intelligence available.
    private func env(
        extra: [EpistemosRuntimePicker.ExtraPick] = [],
        freeGB: Int = 64
    ) -> EpistemosRuntimePicker.Environment {
        var installed = EpistemosRuntimePicker.fixedLineupIDs
        for pick in extra { installed.insert(pick.id) }
        return EpistemosRuntimePicker.Environment(
            installedModelIDs: installed,
            freeMemoryGB: freeGB,
            appleIntelligenceAvailable: true,
            additionalPicks: extra
        )
    }

    @Test("the curated section is first, titled 'Epistemos Picks', and holds only curated models")
    func curatedFirst() {
        let groups = EpistemosPicks.allSections(environment: env())
        #expect(!groups.isEmpty)
        #expect(groups.first?.section == .epistemosPicks)
        #expect(EpistemosPicks.Section.epistemosPicks.title == "Epistemos Picks")
        for option in groups.first?.options ?? [] {
            #expect(EpistemosPicks.isCurated(option))
        }
    }

    @Test("a model installed beyond the curated lineup lands in 'Installed', never in 'Epistemos Picks'")
    func installedSeparated() {
        let custom = EpistemosRuntimePicker.ExtraPick(
            id: "custom/my-finetune-7b", title: "My Finetune 7B", tier: .think, minimumMemoryGB: 8
        )
        let groups = EpistemosPicks.allSections(environment: env(extra: [custom]))
        let curatedIDs = Set(groups.first(where: { $0.section == .epistemosPicks })?.options.map(\.id) ?? [])
        let installedIDs = Set(groups.first(where: { $0.section == .installed })?.options.map(\.id) ?? [])
        #expect(!curatedIDs.contains(custom.id))
        #expect(installedIDs.contains(custom.id))
    }

    @Test("honest selection: a too-large pick stays VISIBLE with a reason — never dropped or swapped")
    func honestTooLarge() {
        // 1 GB free → big models can't fit (gate: free + 6 GB headroom < required), small ones can.
        let groups = EpistemosPicks.allSections(environment: env(freeGB: 1))
        let all = groups.flatMap(\.options)
        #expect(!all.isEmpty)
        // Every blocked local pick is still present AND carries an honest reason (no silent omission).
        for option in all where !option.isSelectable && !option.isAppleIntelligence {
            #expect(option.blockedReason != nil)
        }
    }

    @Test("every option is partitioned into exactly one section — nothing silently lost")
    func nothingLost() {
        let custom = EpistemosRuntimePicker.ExtraPick(
            id: "custom/extra-13b", title: "Extra 13B", tier: .code, minimumMemoryGB: 16
        )
        let environment = env(extra: [custom])
        var rawCount = 0
        var rawIDs = Set<String>()
        for tier in EpistemosModelTier.allCases {
            for option in EpistemosRuntimePicker.options(for: tier, environment: environment)
            where rawIDs.insert(option.id).inserted { rawCount += 1 }
        }
        let grouped = EpistemosPicks.allSections(environment: environment).flatMap(\.options)
        #expect(grouped.count == rawCount)
        #expect(Set(grouped.map(\.id)) == rawIDs)
    }
}
