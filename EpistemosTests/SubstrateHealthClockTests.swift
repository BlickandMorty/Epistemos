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
        ]
        for path in migrated {
            let row = try loadMirroredSourceTextFile(path)
            #expect(!row.contains("startTimer()"),
                    "\(path) still defines/calls a per-row startTimer() — it must use the shared clock")
            #expect(!row.contains("Task.sleep(for: .seconds(1))"),
                    "\(path) still runs a per-row 1 Hz Task.sleep loop")
            #expect(!row.contains("refreshTask"),
                    "\(path) still holds a per-row refresh Task")
            #expect(row.contains(".substrateHealthPoll { refresh() }"),
                    "\(path) must subscribe to the shared clock via .substrateHealthPoll")
        }
    }
}
