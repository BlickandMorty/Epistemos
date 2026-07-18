import Foundation
import Testing

@testable import Epistemos

// SS-SH slice 1 — the single shared substrate-health clock + the collapse of
// the per-row high-frequency timers onto it. The clock's tick logic is witnessed purely;
// the collapse itself is witnessed by a source guard (no live panel needed,
// since the app-hosted UI can't run headless).
@Suite("SS-SH substrate-health clock (slice 1)")
@MainActor
struct SubstrateHealthClockTests {

    @Test("the shared clock starts at zero and advances monotonically")
    func clockAdvancesMonotonically() {
        let clock = SubstrateHealthClock()
        #expect(clock.tick == 0)
        clock.advance()
        clock.advance()
        clock.advance()
        #expect(clock.tick == 3)
    }

    @Test("the panel drives exactly one shared clock and injects it into the rows")
    func panelHostsSingleSharedClock() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        #expect(panel.contains("SubstrateHealthClock()"))
        #expect(panel.contains("healthClock.tickWithUnifiedRefresh()"))
        #expect(panel.contains(".environment(healthClock)"))
        #expect(panel.contains("SubstrateHealthClock.defaultPollInterval"))
        // The driver is a single .task loop, not one timer per row.
        let refreshCount = panel.components(separatedBy: "healthClock.tickWithUnifiedRefresh()").count - 1
        #expect(refreshCount == 1, "the panel must drive the shared clock from exactly one place")
    }

    @Test("the mounted polling rows no longer own a per-row 1 Hz timer")
    func mountedPollingRowsHaveNoSelfTimer() throws {
        let migrated = [
            "Epistemos/Views/Settings/EidosHealthRow.swift",
            "Epistemos/Views/Settings/VaultRecallHealthRow.swift",
            "Epistemos/Views/Settings/EditorBundleHealthRow.swift",
            "Epistemos/Views/Settings/AnswerPacketHealthRow.swift",
        ]
        for path in migrated {
            let row = try loadMirroredSourceTextFile(path)
            #expect(!row.contains("startTimer"),
                    "\(path) still has a per-row startTimer() — it must use the shared clock")
            #expect(!row.contains("Task.sleep(for: .seconds(1))"),
                    "\(path) still runs a per-row 1 Hz Task.sleep loop")
            #expect(!row.contains("Task.sleep(nanoseconds: 1_000_000_000)"),
                    "\(path) still runs a per-row 1 Hz .task poll")
            #expect(row.contains(".substrateHealthPoll {"),
                    "\(path) must subscribe to the shared clock via .substrateHealthPoll")
        }
    }

    @Test("the 3 timer-bearing rows outside the collapse are NOT SubstrateHealthPanel rows")
    func nonCollapsedTimerRowsAreNotPanelRows() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        // Timer-bearing rows may exist elsewhere, but none may silently re-enter
        // the foundation panel's shared-clock contention set.
        #expect(!panel.contains("CognitiveDagHealthRow()"))
        #expect(!panel.contains("CognitiveDagCountsHealthRow()"))
        #expect(!panel.contains("HyperdynamicLoopHealthRow()"))
        #expect(!panel.contains("BackgroundIndexingHealthRow()"))
        #expect(panel.contains("EidosHealthRow()"))
    }

    @Test("the foundation panel keeps one off-main unified fetcher and no legacy unified rows")
    func foundationPanelKeepsOneUnifiedFetcherAndNoLegacyRows() throws {
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        for name in [
            "EmlObservatoryHealthRow",
            "CognitiveDagCountsHealthRow",
            "SubstrateDriftMonitorHealthRow",
            "PlanePlacementHealthRow",
            "CognitiveWeightClassHealthRow",
            "UasAcsHealthRow",
        ] {
            #expect(!panel.contains("\(name)()"), "\(name) should stay out of the simplified foundation panel")
        }
        let clock = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthClock.swift")
        #expect(clock.contains("private(set) var unified"))
        #expect(clock.contains("func tickWithUnifiedRefresh()"))
        #expect(panel.contains("tickWithUnifiedRefresh()"),
                "the panel driver must fetch the unified snapshot once per tick")
    }
}
