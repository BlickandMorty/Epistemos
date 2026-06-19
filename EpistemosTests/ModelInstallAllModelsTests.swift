import Testing
import Foundation
@testable import Epistemos

/// MODEL DOWNLOAD/INSTALL repair (owner 2026-06-19): under the simplified lineup the
/// individual-model install rows used to be HIDDEN (`if !simplifiedLineupActive { … }`),
/// so the owner could only install the one-tap foundation package. They are now RETAINED
/// and reachable in an "All models (advanced)" disclosure — advertise canon, retain + keep
/// downloadable everything, delete nothing.
@Suite("Model install — all advertised + retained models reachable")
struct ModelInstallAllModelsTests {

    @Test("the Settings install UI keeps every model downloadable (canon advertised, rest retained)")
    func allModelsReachable() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        // The canon foundation lineup is the advertised one-tap install.
        #expect(src.contains("epistemosFoundationSection"))
        // The retained (non-foundation) models are now reachable under an advanced disclosure
        // EVEN WHEN the simplified lineup is active — not hidden.
        #expect(src.contains("All models (advanced)"))
        #expect(src.contains("DisclosureGroup"))
        // Their install rows are present (download path intact) — nothing deleted.
        #expect(src.contains("ForEach(curatedBaselineDescriptors"))
        #expect(src.contains("ForEach(optionalBaselineDescriptors"))
        // The retained-models surface shows under the simplified lineup (the previously-hidden
        // branch), not only when the full legacy lineup is forced on.
        #expect(src.contains("if EpistemosFoundationLineup.simplifiedLineupActive {"))
    }

    @Test("the foundation lineup still curates the canon (advertised) set without deleting models")
    func canonAdvertisedRetainAll() {
        // Advertise = canon foundation ids; retain = all (the curated/optional baseline
        // descriptors remain in the catalog, just un-advertised in the simple picker).
        #expect(!EpistemosFoundationLineup.foundationModelIDs.isEmpty)
        #expect(!LocalModelCatalog.optionalBaselineModelIDs.isEmpty)
        #expect(!LocalModelCatalog.curatedBaselineModelIDs.isEmpty)
    }
}
