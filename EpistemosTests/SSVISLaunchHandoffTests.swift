import Testing
import Foundation

@testable import Epistemos

// SS-VIS step-2 (owner 2026-06-20): the capability launcher surfaces
// tools/cowork from Landing. The remaining piece is "start off using a tool" —
// which operating mode the AgentClone/fusion run begins in. These pin that
// decision: a plain tool keeps the current mode (it's already armed via the
// shared command center), while a cowork/Act selection starts in Act mode so a
// multi-step run is enabled from the first turn. Pure + total over every mode.
@Suite("SS-VIS step-2 — capability launch handoff")
struct SSVISLaunchHandoffTests {

    @Test("a plain tool selection keeps the current mode for every mode (no redundant mode write)")
    func toolKeepsMode() {
        for mode in EpistemosOperatingMode.allCases {
            #expect(AgentLaunchHandoff.startMode(for: .tool, current: mode) == mode)
            #expect(!AgentLaunchHandoff.changesMode(for: .tool, current: mode))
        }
    }

    @Test("a cowork / Act selection starts the run in Act mode (.agent) from any current mode")
    func coworkStartsAct() {
        for mode in EpistemosOperatingMode.allCases {
            #expect(AgentLaunchHandoff.startMode(for: .coworkOrAct, current: mode) == .agent)
        }
    }

    @Test("changesMode is true only when cowork/Act flips a non-Act mode (skip the redundant write)")
    func changesModeOnlyWhenFlipping() {
        #expect(AgentLaunchHandoff.changesMode(for: .coworkOrAct, current: .fast))
        #expect(AgentLaunchHandoff.changesMode(for: .coworkOrAct, current: .thinking))
        #expect(AgentLaunchHandoff.changesMode(for: .coworkOrAct, current: .pro))
        #expect(!AgentLaunchHandoff.changesMode(for: .coworkOrAct, current: .agent)) // already Act
    }
}
