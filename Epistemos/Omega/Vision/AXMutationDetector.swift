import AppKit
import Foundation

/// Lightweight post-action AX tree mutation detector.
///
/// Captures before/after snapshots using `Screen2AXFusion.perceiveQuick(pid:)`
/// and compares interactive element counts, window counts, and a title hash
/// to determine if the UI changed significantly after an action.
///
/// This is intentionally cheaper than `VisualVerifyLoop` (no LLM inference,
/// no screenshots). It answers "did the UI change?" not "did the action succeed?"
@MainActor
enum AXMutationDetector {

    struct Snapshot: Sendable {
        let interactiveCount: Int
        /// FNV-1a hash of the concatenated titles of interactive elements.
        let topElementHash: UInt64
        /// Number of windows for the target app.
        let windowCount: Int
        let capturedAt: ContinuousClock.Instant
    }

    struct MutationResult: Sendable {
        let mutated: Bool
        let elementCountDelta: Int
        let newWindowDetected: Bool
        let latencyMs: Double
    }

    // MARK: - Snapshot

    /// Capture a lightweight AX snapshot for the given process.
    static func captureSnapshot(
        pid: Int32,
        using perception: Screen2AXFusion
    ) -> Snapshot {
        let result = perception.perceiveQuick(pid: pid)
        let hash = fnv1aHash(of: result.axTreeJson)
        let windowCount = Self.windowCount(forPID: pid)
        return Snapshot(
            interactiveCount: result.interactiveCount,
            topElementHash: hash,
            windowCount: windowCount,
            capturedAt: .now
        )
    }

    // MARK: - Compare

    /// Compare two snapshots and determine if the UI mutated.
    static func compare(before: Snapshot, after: Snapshot) -> MutationResult {
        let start = ContinuousClock.now
        let countDelta = after.interactiveCount - before.interactiveCount
        let newWindow = after.windowCount > before.windowCount

        // Mutation criteria:
        // 1. New window appeared
        // 2. Interactive element count changed by >20% (or >5 absolute)
        // 3. Element title hash changed (different visible content)
        let countThreshold = max(5, before.interactiveCount / 5)
        let significantCountChange = abs(countDelta) >= countThreshold
        let hashChanged = before.topElementHash != after.topElementHash

        let mutated = newWindow || significantCountChange || hashChanged
        let elapsed = start.duration(to: ContinuousClock.now)

        return MutationResult(
            mutated: mutated,
            elementCountDelta: countDelta,
            newWindowDetected: newWindow,
            latencyMs: elapsed.omegaMilliseconds
        )
    }

    // MARK: - Helpers

    /// Count windows belonging to a given PID via NSWorkspace.
    private static func windowCount(forPID pid: Int32) -> Int {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.processIdentifier == pid }) else {
            return 0
        }
        // CGWindowListCopyWindowInfo gives us actual window count for the PID.
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return app.isActive ? 1 : 0
        }
        return windowList.filter { info in
            (info[kCGWindowOwnerPID as String] as? Int32) == pid
        }.count
    }

    /// FNV-1a 64-bit hash of a string. Fast, no allocation.
    private static func fnv1aHash(of string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0100_0000_01b3 // FNV prime
        }
        return hash
    }
}
