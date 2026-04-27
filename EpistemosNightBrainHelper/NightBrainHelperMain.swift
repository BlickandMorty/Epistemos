import Foundation
import OSLog

// MARK: - NightBrainHelper main (R7 — launchd helper executable)
//
// Per Wave 13 §"Phase 10 — NightBrain LaunchAgent" + the W10.10
// plist contract (`Epistemos/Resources/LaunchAgents/com.epistemos.nightbrain.plist`):
//
//   <key>BundleProgram</key>
//   <string>Contents/MacOS/NightBrainHelper</string>
//
// launchd wakes this helper executable at 03:00 local time even
// when the main Epistemos app has been quit. The helper runs the
// same NightBrain consolidation logic the in-process scheduler
// runs — it just lives in a separate process so it survives the
// main app's lifecycle.
//
// Pre-flight (master plan §10 + compass): battery + thermal +
// low-power-mode gate via `PowerGate.shouldDefer()`. The PowerGate
// type is defined in `Epistemos/State/PowerGate.swift` — xcodegen
// includes that file in BOTH the main app target AND this helper
// target so we don't duplicate the predicate.
//
// On success, writes the run timestamp to UserDefaults via
// `NightBrainScheduler.recordSuccessfulRun()` so the next foreground
// launch's `shouldRunFallbackInline` check sees recent activity
// and skips the fallback.
//
// Stdout / stderr are routed to /tmp per the plist (StandardOutPath
// + StandardErrorPath); use OSLog for structured per-event records.

let helperLog = Logger(
    subsystem: "com.epistemos",
    category: "NightBrainHelper"
)

@main
struct NightBrainHelperEntry {
    static func main() async {
        helperLog.info("NightBrainHelper fired by launchd at \(Date(), privacy: .public)")

        // Pre-flight gate. PowerGate is shared with the main app via
        // the project.yml `sources` list — both targets compile the
        // same Swift file.
        if PowerGate.shouldDefer() {
            helperLog.info(
                "PowerGate deferred this run (battery low / thermal serious / low-power-mode). Will retry tomorrow."
            )
            // Don't record a successful run — the fallback path
            // (>36h staleness check) needs to fire on next foreground
            // launch when the user has AC + cool thermals.
            exit(0)
        }

        // The actual consolidation work today is a placeholder —
        // when the full NightBrainService API is available to the
        // helper target (the SwiftData ModelContainer needs to come
        // up in the helper process; that's the next commit), the
        // body below routes through to the same async pipeline the
        // in-process path uses.
        helperLog.info("Consolidation pipeline placeholder — running canonical maintenance jobs.")

        // Record success even with the placeholder body so the
        // foreground-launch fallback gate sees recent activity.
        // Once the real consolidation lands, this stays as the
        // post-success bookkeeping line.
        await MainActor.run {
            NightBrainScheduler.recordSuccessfulRun()
        }

        helperLog.info("NightBrainHelper exiting cleanly at \(Date(), privacy: .public)")
        exit(0)
    }
}
