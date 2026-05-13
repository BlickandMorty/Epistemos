import Testing
import Foundation
@testable import Epistemos

/// RCA-P1-014 verdict-pin guard.
///
/// **Verdict** (per `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
/// + `epistemos_code_verdict.md` §1 + §3):
///
/// 1. The production live code editor (`Epistemos/Views/Notes/CodeEditorView.swift`)
///    uses `CodeEditSourceEditor`'s built-in tree-sitter highlight path,
///    which supports every language `CodeArtifactKind` exports.
/// 2. `SyntaxCoreLiveHighlighter` (Rust-FFI) and `SwiftTreeSitterLiveHighlighter`
///    (Swift-direct) are TWO **non-production** alternative implementations
///    kept in the source tree as scaffolding for the W9.6 follow-up.
///    Neither is wired into the production live editor today.
/// 3. `LiveCodeEditorController` is the W9.6 base controller; it has
///    NO production caller — only tests instantiate it.
///
/// The acceptance criterion ("Users never select a highlighter path
/// that silently drops expected language highlighting") is met today
/// because no user-facing toggle exposes these alternative paths. This
/// guard pins that reality: if a future commit wires
/// `LiveCodeEditorController` into the production view tree without
/// FIRST resolving the per-language gap in `SyntaxCoreLiveHighlighter`,
/// these tests fail and force an explicit deliberation.
///
/// To lift this gate, a follow-up commit must either:
///   a) ship per-language `.scm` queries for syntax-core (closing the
///      Rust-FFI implementation's "Rust-only tokens" gap), OR
///   b) wire `SwiftTreeSitterLiveHighlighter` as the canonical path
///      (no per-language gap), OR
///   c) ship a Settings toggle that surfaces the choice with the
///      Rust-only limitation in the label.
///
/// Doctrine §7 lane: graph/editor track — live highlighter drift gate.
@Suite("RCA-P1-014 Live Highlighter Verdict Guard")
struct LiveHighlighterVerdictGuardTests {

    /// Production source files that must NOT instantiate
    /// `LiveCodeEditorController`. If any of these imports it without
    /// first updating the verdict, the test fails. This protects users
    /// from accidentally selecting a partial-language highlighter path.
    private static let candidateProductionFiles = [
        "Epistemos/Views/Notes/CodeEditorView.swift",
        "Epistemos/Views/Notes/ProseEditorView.swift",
        "Epistemos/Views/Epdoc/EpdocEditorChromeView.swift",
    ]

    /// Two highlighter implementations covered by the verdict.
    private static let alternativeHighlighters = [
        "SyntaxCoreLiveHighlighter",
        "SwiftTreeSitterLiveHighlighter",
    ]

    @Test("LiveCodeEditorController has no production instantiation")
    func liveCodeEditorControllerHasNoProductionCaller() throws {
        // The doctrine note on SyntaxCoreLiveHighlighter explicitly
        // states "LiveCodeEditorController has no production caller."
        // Lock that with a source-grep across the candidate production
        // editor files. Test files (where it's instantiated) are not
        // checked.
        for relativePath in Self.candidateProductionFiles {
            let source = try loadMirroredSourceTextFile(relativePath)
            #expect(!source.contains("LiveCodeEditorController("),
                "\(relativePath) must not instantiate LiveCodeEditorController without first closing the RCA-P1-014 verdict — see LiveHighlighterVerdictGuardTests for the lift conditions")
        }
    }

    @Test("SyntaxCoreLiveHighlighter retains the V1.5 Rust-only doctrine note")
    func syntaxCoreHighlighterRetainsLimitationDoctrine() throws {
        // If someone removes the explicit doctrine comment without
        // shipping per-language .scm queries, the file's gap becomes
        // invisible. Pin the note so a renaming/refactor commit
        // surfaces in code review.
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/SyntaxCoreLiveHighlighter.swift"
        )
        #expect(source.contains("V1.5 LIMITATION"),
            "SyntaxCoreLiveHighlighter must retain its V1.5 LIMITATION header documenting the Rust-only token gap")
        #expect(source.contains("only Rust source produces semantic tokens"),
            "SyntaxCoreLiveHighlighter must retain its explicit Rust-only acknowledgement")
        #expect(source.contains("RCA13 P1-014") || source.contains("RCA-P1-014"),
            "SyntaxCoreLiveHighlighter must cross-reference the RCA-P1-014 verdict")
    }

    @Test("SyntaxCoreLiveHighlighter highlights only Rust source today; non-Rust returns empty")
    func syntaxCoreReturnsEmptyTokensForNonRustLanguages() {
        // Runtime verification of the doctrine: invoke the highlighter
        // against representative non-Rust source and confirm the empty
        // token contract holds. If a future commit ships per-language
        // .scm queries (lifting the limitation), this test breaks and
        // the gate can be removed — see Suite-level doc for the lift
        // conditions.
        let highlighter = SyntaxCoreLiveHighlighter()
        let swiftSource = "func main() { print(\"hi\") }"
        let pythonSource = "def main(): print('hi')"
        let typescriptSource = "function main() { console.log('hi'); }"

        let swiftTokens = highlighter.highlight(text: swiftSource, language: .swift)
        let pythonTokens = highlighter.highlight(text: pythonSource, language: .python)
        let typescriptTokens = highlighter.highlight(text: typescriptSource, language: .typescript)

        // Non-Rust languages either return [] (no grammar / no .scm
        // query) or are silently dropped. The acceptance criterion is
        // "user never selects a path that silently drops" — proved by
        // the fact that no production code wires this highlighter at
        // all (`liveCodeEditorControllerHasNoProductionCaller` above).
        #expect(swiftTokens.isEmpty,
            "non-Rust Swift source must produce empty tokens until per-language .scm queries ship")
        #expect(pythonTokens.isEmpty,
            "non-Rust Python source must produce empty tokens until per-language .scm queries ship")
        #expect(typescriptTokens.isEmpty,
            "non-Rust TypeScript source must produce empty tokens until per-language .scm queries ship")
    }

    @Test("Alternative-highlighter classes are scaffolding, not production-wired")
    func alternativeHighlightersAreOnlyReferencedByTestsAndSelf() throws {
        // Walk the active production tree (excluding the two
        // highlighter files themselves and the LiveCodeEditorController
        // base file) and assert neither alternative-highlighter class
        // name appears as a constructor call. The audit doc + tests
        // are exempt.
        let productionRoot = try sourceMirrorURL(for: "Epistemos")
        let enumerator = FileManager.default.enumerator(
            at: productionRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let exemptPaths: Set<String> = [
            "Epistemos/Engine/SyntaxCoreLiveHighlighter.swift",
            "Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift",
            "Epistemos/Engine/LiveCodeEditorController.swift",
        ]

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            // Compute the path relative to the source mirror root so we
            // can match against the exempt list.
            let absolute = url.standardizedFileURL.path
            // Look for "Epistemos/Engine/..." style suffix.
            guard let range = absolute.range(of: "/Epistemos/") else { continue }
            let relativeWithLeadingSlash = String(absolute[range.lowerBound...])
            let relative = String(relativeWithLeadingSlash.dropFirst())
            if exemptPaths.contains(relative) { continue }

            let source: String
            do {
                source = try String(contentsOf: url, encoding: .utf8)
            } catch {
                continue
            }
            for className in Self.alternativeHighlighters {
                // Constructor invocation = "ClassName(" pattern. The
                // doctrine comment in SyntaxCoreLiveHighlighter
                // mentions `SwiftTreeSitterLiveHighlighter` by name but
                // doesn't instantiate it, so we look for the
                // constructor pattern specifically.
                let pattern = "\(className)("
                #expect(!source.contains(pattern),
                    "\(relative) must not instantiate \(className) until RCA-P1-014 is closed — see LiveHighlighterVerdictGuardTests for the lift conditions")
            }
        }
    }
}
