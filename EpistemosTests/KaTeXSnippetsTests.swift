import Foundation
import Testing

@testable import Epistemos

/// Wave 7.10 source-guard for the KaTeX slash-menu snippet catalogue.
/// Pins the curated entries against future drift + verifies the
/// trigger lookup + prefix-filter helpers behave as the slash-menu
/// expects.
@Suite("KaTeX snippets (Wave 7.10)")
nonisolated struct KaTeXSnippetsTests {

    @Test("Catalogue is non-empty and curated to ≥ 50 canonical entries")
    func catalogueSize() {
        #expect(KaTeXSnippets.all.count >= 50,
                "the curated catalogue MUST stay ≥50 entries; got \(KaTeXSnippets.all.count)")
    }

    @Test("Every snippet has a non-empty trigger / label / template / description")
    func snippetIntegrity() {
        for snippet in KaTeXSnippets.all {
            #expect(!snippet.trigger.isEmpty, "trigger must not be empty for label \(snippet.label)")
            #expect(!snippet.label.isEmpty, "label must not be empty for trigger \(snippet.trigger)")
            #expect(!snippet.template.isEmpty, "template must not be empty for trigger \(snippet.trigger)")
            #expect(!snippet.description.isEmpty, "description must not be empty for trigger \(snippet.trigger)")
        }
    }

    @Test("Triggers are lowercase ASCII (slash-menu shortcut convention)")
    func triggersAreLowercaseASCII() {
        for snippet in KaTeXSnippets.all {
            #expect(snippet.trigger.allSatisfy { $0.isASCII && !$0.isUppercase && !$0.isWhitespace },
                    "trigger '\(snippet.trigger)' must be lowercase ASCII without whitespace")
        }
    }

    @Test("Triggers are unique (no duplicate slash-menu hotkeys)")
    func triggersUnique() {
        let triggers = KaTeXSnippets.all.map(\.trigger)
        let uniqueTriggers = Set(triggers)
        #expect(triggers.count == uniqueTriggers.count,
                "duplicate trigger detected; total \(triggers.count) vs unique \(uniqueTriggers.count)")
    }

    @Test("Templates with placeholders use the canonical ${N} marker convention")
    func placeholderConvention() {
        for snippet in KaTeXSnippets.all where snippet.template.contains("$") {
            // The Tiptap snippet runtime expects `${1}`, `${2}`, ...
            // numeric markers — never `$1` (collides with KaTeX inline
            // delimiters) and never `{0}` / `{}` Python-style.
            // Allow templates that contain `$` only if it's part of `${`.
            let dollars = snippet.template.split(separator: "$", omittingEmptySubsequences: false).count - 1
            let bracedDollars = snippet.template.components(separatedBy: "${").count - 1
            #expect(dollars == bracedDollars,
                    "template '\(snippet.template)' has bare `$` — must use `${N}` markers only")
        }
    }

    @Test("snippet(forTrigger:) is case-insensitive + returns the expected entry")
    func triggerLookup() {
        let sqrt = KaTeXSnippets.snippet(forTrigger: "sqrt")
        #expect(sqrt?.trigger == "sqrt")
        #expect(sqrt?.template == "\\sqrt{${1}}")

        // Case-insensitive
        #expect(KaTeXSnippets.snippet(forTrigger: "SQRT")?.trigger == "sqrt")
        #expect(KaTeXSnippets.snippet(forTrigger: "Sqrt")?.trigger == "sqrt")

        // Unknown trigger
        #expect(KaTeXSnippets.snippet(forTrigger: "definitely-not-real") == nil)
    }

    @Test("snippets(matchingPrefix:) drives the autocomplete dropdown")
    func prefixFilter() {
        // Greek letters: alpha / beta / gamma / delta / epsilon / theta /
        // lambda / mu / pi / sigma / phi / omega → prefix `a` only matches
        // "alpha", `s` only matches "sub", "sum", "sigma", "sqrt".
        let aMatches = KaTeXSnippets.snippets(matchingPrefix: "a")
        let aTriggers = aMatches.map(\.trigger)
        #expect(aTriggers.contains("alpha"), "prefix 'a' must include alpha; got \(aTriggers)")

        let sMatches = KaTeXSnippets.snippets(matchingPrefix: "s")
        let sTriggers = sMatches.map(\.trigger)
        #expect(sTriggers.contains("sqrt"), "prefix 's' must include sqrt; got \(sTriggers)")
        #expect(sTriggers.contains("sum"),  "prefix 's' must include sum; got \(sTriggers)")
        #expect(sTriggers.contains("sigma"), "prefix 's' must include sigma; got \(sTriggers)")

        // Empty prefix returns everything (degenerate case)
        let empty = KaTeXSnippets.snippets(matchingPrefix: "")
        #expect(empty.count == KaTeXSnippets.all.count)

        // Case-insensitive
        let upper = KaTeXSnippets.snippets(matchingPrefix: "SQR").map(\.trigger)
        #expect(upper.contains("sqrt"), "prefix matching MUST be case-insensitive")
    }

    @Test("Catalogue includes the W7.7 must-haves (sqrt / sum / integral / matrix / cases)")
    func smokeMustHaves() {
        let mustHaves = ["sqrt", "frac", "sum", "prod", "integral", "lim", "matrix",
                         "bmatrix", "cases", "vec", "partial", "infty"]
        let triggers = Set(KaTeXSnippets.all.map(\.trigger))
        for needle in mustHaves {
            #expect(triggers.contains(needle),
                    "catalogue MUST contain trigger '\(needle)' (slash-menu must-have); current set: \(triggers.sorted().joined(separator: ", "))")
        }
    }
}
