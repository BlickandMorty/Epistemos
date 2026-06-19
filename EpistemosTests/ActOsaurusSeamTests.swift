import Testing
import Foundation
@testable import Epistemos

/// Osaurus P3.0 Act import — Seam A / S2 guard. Locks the smallest real vendored
/// seam: ProvenanceGate (MIT direct_import), the MAS/Pro boundary (vendored Osaurus
/// + the runtime bridge are Pro-only; the gate + row are always-compiled), and the
/// honest INERT posture (no fake runtime).
@Suite("Osaurus Act seam (P3.0 S2) — vendored, Pro-gated, boundary intact")
struct ActOsaurusSeamTests {

    @Test("gate flag is honest + off by default")
    func gateHonest() {
        #expect(ActOsaurusGateStatus.flagName == "EPISTEMOS_ACT_OSAURUS_V0")
        #expect(ActOsaurusGateStatus.isEnabled("1"))
        #expect(ActOsaurusGateStatus.isEnabled(" On "))
        #expect(!ActOsaurusGateStatus.isEnabled(nil))
        #expect(!ActOsaurusGateStatus.isEnabled("0"))
        let off = ActOsaurusGateStatus.status(environment: [:])
        #expect(!off.isActive)
        // Honest copy either names the flag (Pro build) or says "Pro only" (MAS).
        #expect(off.detail.contains("EPISTEMOS_ACT_OSAURUS_V0") || off.headline.contains("Pro only"))
    }

    @Test("ProvenanceGate: vendored Osaurus carries MIT direct_import provenance")
    func provenancePresent() throws {
        let prov = try loadMirroredSourceTextFile("Epistemos/Vendor/Osaurus/OsaurusVendorProvenance.swift")
        #expect(prov.contains("MIT License"))
        #expect(prov.contains("osaurus-ai/osaurus"))
        #expect(prov.contains("direct_import"))
        #expect(prov.contains("Copyright (c) 2026 Osaurus, Inc."))
    }

    @Test("MAS/Pro boundary: vendored Osaurus + the runtime bridge are Pro-gated")
    func boundaryIntact() throws {
        // The vendored Osaurus source never compiles into the MAS build.
        let serverHealth = try loadMirroredSourceTextFile("Epistemos/Vendor/Osaurus/ServerHealth.swift")
        #expect(serverHealth.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(serverHealth.contains("osaurus-ai/osaurus"))     // provenance header
        #expect(serverHealth.contains("VERBATIM"))               // verbatim markers
        // The bridge (drives the Osaurus runtime) is Pro-gated + honestly inert.
        let bridge = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        #expect(bridge.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(bridge.contains("protocol ActOsaurusBridge"))
        #expect(bridge.contains("var isLive: Bool { false }"))   // never fakes a runtime
    }

    @Test("the gate status + health row are ALWAYS-compiled (MAS can show the honest state)")
    func gateAndRowAlwaysCompiled() throws {
        let gate = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusGateStatus.swift")
        #expect(gate.contains("nonisolated enum ActOsaurusGateStatus"))
        // The enum itself is NOT wrapped in the Pro-only boundary (so MAS compiles it).
        #expect(!gate.contains("#if !EPISTEMOS_APP_STORE\nnonisolated enum ActOsaurusGateStatus"))
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActOsaurusHealthRow.swift")
        #expect(row.contains("struct ActOsaurusHealthRow: View"))
        #expect(row.contains("ActOsaurusGateStatus.status()"))
        // Mounted in the visible substrate health panel.
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("ActOsaurusHealthRow()"))
    }
}
