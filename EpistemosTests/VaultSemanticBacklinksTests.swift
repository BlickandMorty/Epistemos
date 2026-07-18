import Testing
import Foundation
@testable import Epistemos

/// Verifies `relatedNotes` drives the retained notes-only Shadow search,
/// excludes the note itself, caps at the limit, and avoids blank-input work.
/// A mock keeps this contract independent of the local index implementation.
@Suite("Vault note backlinks — notes-only search, self-excluded")
struct VaultSemanticBacklinksTests {
    /// Minimal mock conforming to the real protocol — returns canned hits.
    private struct MockShadow: ShadowSearchServicing {
        let hits: [ShadowHit]
        func search(text: String, limit: Int) async -> [ShadowHit] {
            Array(hits.prefix(limit))
        }
        func searchReportingErrors(text: String, limit: Int) async -> (hits: [ShadowHit], errorMessage: String?) {
            (Array(hits.prefix(limit)), nil)
        }
    }

    private func hit(_ id: String, _ score: Float) -> ShadowHit {
        ShadowHit(id: id, title: id, snippet: "", score: score, domain: .notes, source: "notes-only-test", originVaultKey: nil)
    }

    @Test("relatedNotes drives the shadow search, excludes self, caps at limit")
    func relatedNotesExcludesSelfAndCaps() async {
        let mock = MockShadow(hits: [hit("self", 1.0), hit("a", 0.9), hit("b", 0.8), hit("c", 0.7)])
        let svc = VaultSemanticBacklinks(search: mock)
        let related = await svc.relatedNotes(noteID: "self", queryText: "alpha", limit: 2)
        #expect(related.map(\.id) == ["a", "b"])   // self removed, top-2 by engine order
    }

    @Test("empty/blank query yields no related notes (honest, no wasted search)")
    func emptyQueryReturnsEmpty() async {
        let mock = MockShadow(hits: [hit("a", 0.9)])
        let svc = VaultSemanticBacklinks(search: mock)
        #expect(await svc.relatedNotes(noteID: "x", queryText: "   ", limit: 5).isEmpty)
        #expect(await svc.relatedNotes(noteID: "x", queryText: "real", limit: 0).isEmpty)
    }

    @Test("uses the retained notes-only ShadowSearchServicing contract")
    func usesNotesOnlySearch() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/VaultSemanticBacklinks.swift")
        #expect(src.contains("any ShadowSearchServicing"))
        #expect(src.contains("search(text: trimmed, limit: limit + 1)"))
    }
}
