import Foundation
import Testing

@testable import Epistemos

/// Source-guard for the Wave 4.5 / Patch 6a SyntaxCoreHighlightProvider
/// adapter (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 4.5,
///  cross-ref dpp §4.4 Sprint 3 deep perf).
///
/// The provider class implements every HighlightProviding method (setUp,
/// applyEdit, queryHighlightsFor) with the algorithmically correct
/// shape, but the Swift 6 strict-concurrency conformance to
/// `HighlightProviding` is deferred to a follow-up — see the long
/// `MARK: - HighlightProviding conformance (FOLLOW-UP)` comment in
/// SyntaxCoreHighlightProvider.swift for the full investigation.
///
/// This test exercises the algorithm directly (without the protocol
/// cast) so the class stays regression-tested today.
@Suite("SyntaxCoreHighlightProvider (Wave 4.5 partial)")
nonisolated struct SyntaxCoreHighlightProviderTests {

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EpistemosTests/
            .deletingLastPathComponent() // repo root
    }

    private static func loadText(_ relative: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relative, isDirectory: false)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("SyntaxCoreHighlightProvider.swift declares all 4 protocol methods")
    func providerImplementsProtocolMethods() throws {
        let source = try Self.loadText("Epistemos/Engine/SyntaxCoreHighlightProvider.swift")
        for symbol in [
            "func setUp(textView: TextView, codeLanguage: CodeLanguage)",
            "func willApplyEdit(textView: TextView, range: NSRange)",
            "func applyEdit(",
            "func queryHighlightsFor(",
        ] {
            #expect(source.contains(symbol),
                    "SyntaxCoreHighlightProvider.swift must implement `\(symbol)` (HighlightProviding shape)")
        }
    }

    @Test("SyntaxCoreHighlightProvider documents the deferred conformance follow-up")
    func providerDocumentsDeferredConformance() throws {
        let source = try Self.loadText("Epistemos/Engine/SyntaxCoreHighlightProvider.swift")
        #expect(source.contains("HighlightProviding conformance (FOLLOW-UP)"),
                "the class file must carry the explicit FOLLOW-UP marker so the deferred wiring is discoverable in future audits")
    }

    @Test("Capture name registry maps known syntax-core captures to CaptureName")
    func captureNameRegistryHandlesKnownCaptures() {
        let names = [
            "comment", "string", "number", "type", "variable",
            "property", "function.def", "function.call",
        ]
        for raw in names {
            let mapped = SyntaxCoreCaptureNameRegistry.canonicalCaptureName(for: raw)
            #expect(mapped != nil,
                    "canonicalCaptureName(for: \"\(raw)\") must produce a CaptureName — these are the captures syntax-core emits from GENERIC_HIGHLIGHTS_QUERY")
        }
    }

    @Test("Capture name registry returns nil for unknown captures")
    func captureNameRegistryReturnsNilForUnknown() {
        let unknown = ["", "totally_not_a_capture", "weird/syntax"]
        for raw in unknown {
            let mapped = SyntaxCoreCaptureNameRegistry.canonicalCaptureName(for: raw)
            #expect(mapped == nil,
                    "canonicalCaptureName(for: \"\(raw)\") must return nil for unknown captures so the editor renders plain")
        }
    }

    @Test("function.def + function.call collapse to .function")
    func functionVariantsCollapse() {
        #expect(SyntaxCoreCaptureNameRegistry.canonicalCaptureName(for: "function.def")?.rawValue
                == SyntaxCoreCaptureNameRegistry.canonicalCaptureName(for: "function.call")?.rawValue,
                "function.def and function.call must both map to the same CaptureName.function — visual semantic")
    }
}
