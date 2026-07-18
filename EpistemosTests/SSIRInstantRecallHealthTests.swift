import Testing
import Foundation

@testable import Epistemos

// SS-IR (owner 2026-06-20): "I don't see Instant Recall anymore — is it still working?" The recall
// feature is wired + on by default, but invisible when it has no hits, and the most common cause is
// an install precondition (no active vault → no search service → no chrome). This slice records
// those preconditions so the ShadowSearchHealthRow answers "why is it empty?" without Console.
@Suite("SS-IR instant-recall health: install preconditions")
struct SSIRInstantRecallHealthTests {

    @Test("a fresh diagnostics snapshot reports recall not-yet-installed")
    func emptyDefaults() {
        let diag = ShadowSearchDiagnostics()
        let s = diag.snapshot()
        #expect(s.vaultPresent == false)
        #expect(s.serviceInstalled == false)
        #expect(s.indexedDocumentCount == nil)
    }

    @Test("recordInstall surfaces vault present + service installed + index size")
    func recordInstallSetsFields() {
        let diag = ShadowSearchDiagnostics()
        diag.recordInstall(vaultPresent: true, serviceInstalled: true, indexedDocumentCount: 42)
        let s = diag.snapshot()
        #expect(s.vaultPresent)
        #expect(s.serviceInstalled)
        #expect(s.indexedDocumentCount == 42)
    }

    // The install truth must survive a later telemetry write — otherwise a post-install init failure
    // would clobber "vault present / installed" and the row would lie about preconditions.
    @Test("install preconditions carry forward through a later init failure")
    func installCarriesThroughInitFailure() {
        let diag = ShadowSearchDiagnostics()
        diag.recordInstall(vaultPresent: true, serviceInstalled: true, indexedDocumentCount: 7)
        diag.recordInitFailure(class: .handleOpen)
        let s = diag.snapshot()
        #expect(s.vaultPresent)
        #expect(s.serviceInstalled)
        #expect(s.indexedDocumentCount == 7)
        #expect(s.lastInitFailureClass != nil)
    }

    @Test("no-vault install records as not-present + not-installed (the #1 invisible cause)")
    func noVaultState() {
        let diag = ShadowSearchDiagnostics()
        diag.recordInstall(vaultPresent: false, serviceInstalled: false, indexedDocumentCount: nil)
        let s = diag.snapshot()
        #expect(!s.vaultPresent)
        #expect(!s.serviceInstalled)
    }
}
