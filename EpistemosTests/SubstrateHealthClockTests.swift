import Foundation
import Testing

@testable import Epistemos

// SS-SH slice 1 — the single shared substrate-health clock + the collapse of
// the per-row 1 Hz timers onto it. The clock's tick logic is witnessed purely;
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
        #expect(panel.contains("healthClock.advance()"))
        #expect(panel.contains(".environment(healthClock)"))
        // The driver is a single .task loop, not one timer per row.
        let advanceCount = panel.components(separatedBy: "healthClock.advance()").count - 1
        #expect(advanceCount == 1, "the panel must drive the shared clock from exactly one place")
    }

    @Test("the migrated rows no longer own a per-row 1 Hz timer")
    func migratedRowsHaveNoSelfTimer() throws {
        let migrated = [
            // Slice 1
            "Epistemos/Views/Settings/EmlObservatoryHealthRow.swift",
            "Epistemos/Views/Settings/CognitiveDagCountsHealthRow.swift",
            "Epistemos/Views/Settings/SubstrateDriftMonitorHealthRow.swift",
            // Slice 2 — completes the unified-snapshot cluster
            "Epistemos/Views/Settings/PlanePlacementHealthRow.swift",
            "Epistemos/Views/Settings/CognitiveWeightClassHealthRow.swift",
            "Epistemos/Views/Settings/UasAcsHealthRow.swift",
            // Slice 3 — the canonical non-unified rows (keep their .onReceive)
            "Epistemos/Views/Settings/EidosHealthRow.swift",
            "Epistemos/Views/Settings/VaultRecallHealthRow.swift",
            "Epistemos/Views/Settings/FUlpHealthRow.swift",
            "Epistemos/Views/Settings/EditorBundleHealthRow.swift",
            // Slice 4 — the deviating rows (bridge pre-call / dual-task / .task{})
            "Epistemos/Views/Settings/ACSAdmissionHealthRow.swift",
            "Epistemos/Views/Settings/AnswerPacketHealthRow.swift",
            "Epistemos/Views/Settings/LocalAgentDiagnosticsHealthRow.swift",
            "Epistemos/Views/Settings/LatticeWBOHealthRow.swift",
            "Epistemos/Views/Settings/FalsifierArtifactsHealthRow.swift",
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

    @Test("the tick-based ActiveConstellation row reads the shared clock, not a self-timer")
    func activeConstellationUsesSharedClock() throws {
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/ActiveConstellationRow.swift"
        )
        // No refresh()/snapshot — it re-renders by reading the shared clock's
        // tick directly in its computed props (not via .substrateHealthPoll).
        // With this row, all 17 substrate-health timer rows are on the one clock.
        #expect(!row.contains("startTimer"))
        #expect(!row.contains("Task.sleep(for: .seconds(1))"))
        #expect(!row.contains("refreshTick"))
        #expect(row.contains("@Environment(SubstrateHealthClock.self)"))
        #expect(row.contains("_ = healthClock?.tick"))
    }

    @Test("the 3 timer-bearing rows outside the collapse are NOT SubstrateHealthPanel rows")
    func nonCollapsedTimerRowsAreNotPanelRows() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        // A grep of startTimer/Task.sleep still matches 3 *HealthRow files, but none is
        // a panel row, so the collapse is genuinely complete for every mounted row:
        //  - CognitiveDagHealthRow + HyperdynamicLoopHealthRow: dead orphans (0 mounts).
        //    (Distinct from the migrated CognitiveDagCountsHealthRow, which IS in the panel.)
        //  - BackgroundIndexingHealthRow: a separate live row in SettingsView, own cadence.
        // None may silently re-enter the panel's shared-clock contention set.
        #expect(!panel.contains("CognitiveDagHealthRow()"))
        #expect(!panel.contains("HyperdynamicLoopHealthRow()"))
        #expect(!panel.contains("BackgroundIndexingHealthRow()"))
        // Sanity: the migrated counts row IS still mounted (we didn't break the panel).
        #expect(panel.contains("CognitiveDagCountsHealthRow()"))
    }

    @Test("the 6 unified rows read the shared clock snapshot, not a per-tick FFI call each")
    func unifiedRowsReadSharedSnapshotNotPerRowFFI() throws {
        let unifiedRows = [
            "EmlObservatoryHealthRow", "CognitiveDagCountsHealthRow",
            "SubstrateDriftMonitorHealthRow", "PlanePlacementHealthRow",
            "CognitiveWeightClassHealthRow", "UasAcsHealthRow",
        ]
        for name in unifiedRows {
            let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/\(name).swift")
            #expect(!row.contains("snapshotAsync()"),
                    "\(name) still calls snapshotAsync() every tick — must read the shared clock snapshot")
            #expect(row.contains("healthClock?.unified"),
                    "\(name) must read the shared SubstrateHealthClock.unified snapshot")
        }
        // The shared clock is the SINGLE owner of the per-tick async unified fetch
        // (6 identical FFI round-trips/sec collapsed to 1).
        let clock = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthClock.swift")
        #expect(clock.contains("private(set) var unified"))
        #expect(clock.contains("func tickWithUnifiedRefresh()"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("tickWithUnifiedRefresh()"),
                "the panel driver must fetch the unified snapshot once per tick")
    }
}
