import Foundation
import Testing
@testable import Epistemos

// Wiring #4 (T11 System G / Agent Runtime v2 → LocalAgentLoop)
// Swift integration test.
//
// Verifies the WRV "Verified" bar:
//   - `SystemGBridge.status()` returns a decoded `SystemGRuntimeStatus`
//     from the Rust FFI.
//   - The build-tier-locked mode contract: MAS bundle observes
//     `disabled`, Pro observes `ipcBounded`. (Test build matches the
//     compile feature; we just assert the relationship.)
//   - `SystemGMetrics.shared.recordRead` fires; the health row will
//     repaint via `didChangeNotification`.
//   - `SystemGFlags` UserDefaults + env-var fallback semantics.

@Suite("System G Wiring #4")
struct SystemGWiringTests {

    @Test("SystemGBridge.status returns mode and capability gates")
    func systemGBridgeReturnsModeAndGates() throws {
        SystemGMetrics.shared.reset()

        let status = try #require(SystemGBridge.status(),
                                  "FFI must not fail under normal conditions")
        // Mode must be one of the three canonical variants.
        let validModes: Set<SystemGMode> = [.disabled, .ipcBounded, .subprocess]
        #expect(validModes.contains(status.mode))
        // Build tier must align with the mode's tier-lock.
        if status.buildTier == "mas" {
            #expect(status.mode == .disabled, "MAS build must observe Disabled")
            #expect(!status.allowsExecution, "MAS Disabled never allows execution")
            #expect(!status.allowsSubprocess, "MAS Disabled never allows subprocess")
        }
    }

    @Test("SystemGMetrics records the read into the shared snapshot")
    func systemGMetricsRecordsRead() throws {
        SystemGMetrics.shared.reset()

        _ = try #require(SystemGBridge.status())
        let snap = SystemGMetrics.shared.snapshot()
        #expect(snap.totalReads == 1)
        #expect(snap.lastStatus != nil)
        #expect(snap.lastReadAt != nil)
        #expect(snap.lastErrorDescription == nil)
    }

    @Test("SystemGFlags.isEnabled reads UserDefaults + env-var fallback")
    func systemGFlagsToggle() {
        let saved = UserDefaults.standard.bool(forKey: SystemGFlags.userDefaultsKey)
        defer { UserDefaults.standard.set(saved, forKey: SystemGFlags.userDefaultsKey) }

        UserDefaults.standard.set(false, forKey: SystemGFlags.userDefaultsKey)
        let envIsSet = ProcessInfo.processInfo.environment[SystemGFlags.userDefaultsKey] == "1"
        if !envIsSet {
            #expect(!SystemGFlags.isEnabled, "flag should default to OFF")
        }

        UserDefaults.standard.set(true, forKey: SystemGFlags.userDefaultsKey)
        #expect(SystemGFlags.isEnabled)
    }
}
