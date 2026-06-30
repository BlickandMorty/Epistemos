import Testing
import Foundation
@testable import Epistemos

/// SS-SH (owner: "the substrate health page is still glitched, it is not working in
/// settings"). Verified root: ~15 per-row high-frequency pollers each ran a SYNCHRONOUS Rust
/// FFI round-trip ON the MainActor — a single slow/contended call froze the whole
/// panel ("never block @MainActor"). This slice moves the 6 rows that share the
/// unified snapshot off the MainActor (the FFI + decode run on a detached task);
/// the remaining bridge-specific rows are a documented follow-on.
@Suite("Substrate health off-MainActor poll (SS-SH)")
struct SubstrateHealthOffMainTests {

    @Test("the unified client exposes an off-MainActor snapshot fetch")
    func clientHasOffMainSnapshot() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthSupport.swift"
        )
        #expect(src.contains("static func snapshotAsync() async -> SubstrateHealthUnifiedSnapshot"))
        #expect(src.contains("SubstrateHealthDiagnostics.statusMessage(for: error)"))
        #expect(!src.contains("String(describing: error)"))
        // FFI + JSON decode run on a detached background task (off the MainActor).
        #expect(src.contains("await Task.detached { snapshot() }.value"))
    }

    @Test("unified client diagnostics redact path-leaking external errors")
    func unifiedClientDiagnosticsRedactPathLeakingExternalErrors() {
        let privatePath = "/Users/example/private-vault/substrate.json"
        let error = NSError(
            domain: privatePath,
            code: 12,
            userInfo: [NSLocalizedDescriptionKey: "decode failed at \(privatePath)"]
        )
        let message = SubstrateHealthDiagnostics.statusMessage(for: error)

        #expect(message.contains("substrate health unavailable"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=12"))
        #expect(message.count <= SubstrateHealthDiagnostics.maxStatusMessageCharacters + 3)
        #expect(!message.contains(privatePath))
        #expect(!message.contains("decode failed"))
    }

    // SS-SH dedup (corrected 2026-06-21): the 6 rows no longer each fetch — they read ONE shared
    // snapshot from SubstrateHealthClock, and the single off-MainActor fetch lives
    // in the clock driver. (The prior assertion that each ROW calls `snapshotAsync()` went stale
    // after the clock migration — compiled, but failed when run; a DONE-RE-AUDIT catch.)
    @Test("the shared clock owns the only unified off-MainActor fetch")
    func sharedClockOwnsUnifiedOffMainFetch() throws {
        let clock = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthClock.swift")
        #expect(clock.contains("unified = await SubstrateHealthUnifiedClient.snapshotAsync()"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("await healthClock.tickWithUnifiedRefresh()"))
    }

    @Test("LatticeWBO health row fetches its Rust FFI off the MainActor (phase 2)")
    func latticeOffMain() throws {
        let lattice = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/LatticeWBOHealthRow.swift"
        )
        #expect(lattice.contains("await Task.detached { LatticeWBOBridge.snapshot() }.value"))
        #expect(!lattice.contains("if let snap = LatticeWBOBridge.snapshot() {"))
    }
}
