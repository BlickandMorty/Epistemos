import Testing
import Foundation

@testable import Epistemos

// SS-MV (1, owner 2026-06-20): the model-vault rows showed green "Compiled" regardless of
// AGE — `status` only reflected completeness — so a vault that froze days ago read fresh
// ("outdated even with one model"). This adds an honest age-staleness flag, surfaced in the
// row (amber dot + "Compiled · stale") so the user knows to Rebuild. The on-note-change
// debounced auto-recompile is the follow-on; this is the visible half.
@Suite("SS-MV (1) model-vault staleness badge")
struct SSMVStalenessTests {

    @Test("a freshly-compiled vault is NOT stale; an old one IS (advisory max-age)")
    func staleAfterMaxAge() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(!ModelVaultStaleness.isStale(lastCompiledAt: now, now: now))                      // just compiled
        #expect(!ModelVaultStaleness.isStale(lastCompiledAt: now.addingTimeInterval(-3600), now: now))  // 1h → fresh
        #expect(ModelVaultStaleness.isStale(lastCompiledAt: now.addingTimeInterval(-25 * 3600), now: now)) // 25h → stale
        #expect(!ModelVaultStaleness.isStale(lastCompiledAt: nil, now: now))                       // never compiled
    }

    @Test("the model-vault row surfaces staleness honestly (amber + 'Compiled · stale')")
    func rowSurfacesStaleness() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ModelVaultsSettingsView.swift")
        #expect(src.contains("Compiled · stale"))
        #expect(src.contains("row.isStale"))
    }
}
