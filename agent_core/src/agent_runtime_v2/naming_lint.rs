//! Aegis-name lint — single source of truth for the rejected-name check.
//!
//! The `Aegis` name was explicitly rejected by user direction (see
//! `docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md` §4). This
//! module provides the canonical match function that any CI gate
//! (Rust binary, shell wrapper, pre-commit hook) consumes so the
//! semantics live in ONE place — case-insensitive substring match.
//!
//! Variants the lint MUST catch (Aegis, AEGIS, aegis_runtime,
//! "aegis-platform", "// thinking about Aegis", "Aegisplatform")
//! all reduce to "the lowercase form contains the substring `aegis`".

/// The rejected name, in lowercase, as a stable constant. Production
/// callers should never construct the literal directly — call
/// [`text_contains_rejected_name`] instead so the matching semantics
/// stay in one place.
pub const REJECTED_NAME_LOWERCASE: &str = "aegis";

/// Repo-relative path patterns the Aegis lint MUST skip. These are
/// the docs that legitimately mention "Aegis" in the context of
/// explaining the rejection. Listed in alphabetical order so reviewer
/// diff churn stays minimal. Patterns are exact path-suffix matches
/// for simplicity; path separators are normalized before matching.
pub const AEGIS_LINT_EXEMPT_DOCS: &[&str] = &[
    // This module is exempt because it constructs the rejected name
    // as a constant + tests use it in synthetic strings. The CI
    // driver should not flag the lint's own test fixtures.
    "agent_core/src/agent_runtime_v2/naming_lint.rs",
    "docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md",
    "docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md",
    "docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md",
    "docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md",
    "docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md",
];

/// Return true if the given repo-relative path matches any entry in
/// [`AEGIS_LINT_EXEMPT_DOCS`]. Match is suffix-based: a path
/// `/Users/jojo/Downloads/Epistemos/docs/HERMES_AGENT_CORE_2_0_DESIGN
/// _2026_05_15.md` still matches the exempt entry that ends with the
/// same name.
#[must_use]
pub fn is_path_exempt(path: &str) -> bool {
    if path.contains('\\') {
        let normalized = path.replace('\\', "/");
        return AEGIS_LINT_EXEMPT_DOCS
            .iter()
            .any(|p| normalized.ends_with(p));
    }
    AEGIS_LINT_EXEMPT_DOCS.iter().any(|p| path.ends_with(p))
}

/// One match site: 1-based line number + 0-based byte column of the
/// matched substring inside the source text.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RejectedNameMatch {
    pub line: usize,
    pub column: usize,
}

/// Scan multi-line text for every occurrence of the rejected name.
/// Returns line-and-column positions so a CI driver can produce
/// readable error output ("src/foo.rs:42:18: rejected name 'Aegis'").
/// Case-insensitive; matches every overlapping/non-overlapping
/// occurrence per line.
#[must_use]
pub fn scan_text(text: &str) -> Vec<RejectedNameMatch> {
    let needle_len = REJECTED_NAME_LOWERCASE.len();
    let mut hits = Vec::new();
    for (line_idx, line) in text.lines().enumerate() {
        if line.len() < needle_len {
            continue;
        }
        let lower = line.to_ascii_lowercase();
        let mut start = 0usize;
        while let Some(pos) = lower[start..].find(REJECTED_NAME_LOWERCASE) {
            let column = start + pos;
            hits.push(RejectedNameMatch {
                line: line_idx + 1,
                column,
            });
            // Step past the match (non-overlapping). Overlap on a
            // single 5-char needle is impossible by construction.
            start = column + needle_len;
            if start >= lower.len() {
                break;
            }
        }
    }
    hits
}

/// Count the number of rejected-name matches in `text` without
/// allocating a `Vec`. CI drivers that only need a tally (rather
/// than per-position output) call this for cheaper hot-path
/// scanning. O(n) in `text` length; one `String` allocation for
/// the lowercase fold.
#[must_use]
pub fn count_hits(text: &str) -> usize {
    let needle_len = REJECTED_NAME_LOWERCASE.len();
    if text.len() < needle_len {
        return 0;
    }
    let lower = text.to_ascii_lowercase();
    let mut count = 0usize;
    let mut start = 0usize;
    while let Some(pos) = lower[start..].find(REJECTED_NAME_LOWERCASE) {
        count += 1;
        start += pos + needle_len;
        if start >= lower.len() {
            break;
        }
    }
    count
}

/// Case-insensitive substring check for the rejected agent name.
/// Returns true if `text` contains the substring `"aegis"` in any
/// capitalisation. Matches comments, strings, identifiers, file
/// content; the CI wrapper is responsible for choosing which paths
/// to feed in (the doctrine doc + prior-design doc + dispatch doc
/// + substrate handoff doc + prompt deck are allowed to discuss
/// the rejection).
#[must_use]
pub fn text_contains_rejected_name(text: &str) -> bool {
    // We ASCII-lowercase a stack-bound chunk at a time to stay
    // allocation-free for typical source lines. For very large
    // pasted blobs the implementation still works but produces one
    // `String`; the CI driver bounds input size externally.
    if text.len() < REJECTED_NAME_LOWERCASE.len() {
        return false;
    }
    let lower = text.to_ascii_lowercase();
    lower.contains(REJECTED_NAME_LOWERCASE)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejected_name_match_is_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin for RejectedNameMatch.
        // Companion to the Copy + Clone + Send + Sync sweep across
        // unit-enum and Copy-struct types (mode iter-366 →
        // AgentEventErrorKind iter-374).
        //
        // RejectedNameMatch: 2-field struct (line: usize, column: usize)
        // marked Copy via derive (naming_lint.rs §48). Returned by
        // scan_text inside Vec<RejectedNameMatch>; Copy keeps the
        // Vec ergonomics simple for downstream audit / CI dashboards.
        //
        // Send + Sync are load-bearing because CI lint output crosses
        // thread boundaries when the lint runs over a worker pool of
        // file scans.
        //
        // A future "let me hold a Rc<String> filename inside
        // RejectedNameMatch" refactor would silently break the Copy
        // surface — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<RejectedNameMatch>();

        let m = RejectedNameMatch { line: 5, column: 3 };
        let _a = m;
        let _b = m;
        assert_eq!(m, m);
    }

    #[test]
    fn rejected_name_match_fields_are_pub_per_field_visibility_doctrine() {
        // Phase 1 hardening — field-visibility pin for RejectedNameMatch
        // (companion to the field-visibility pin family iter-505..iter-512).
        //
        // 2 pub fields: line (usize), column (usize). Direct field
        // access is load-bearing for CI lint output rendering and
        // grep-based audit pipelines that consume the per-match
        // position triple.
        let m = RejectedNameMatch { line: 5, column: 3 };
        let _: usize = m.line;
        let _: usize = m.column;
        assert_eq!(m.line, 5);
        assert_eq!(m.column, 3);
    }

    #[test]
    fn rejected_name_match_struct_field_shape_pinned_via_destructure() {
        // Phase 1 hardening — struct-field-shape pin for
        // RejectedNameMatch (companion to the struct destructure pin
        // family iter-464..iter-471).
        //
        // RejectedNameMatch: EXACTLY 2 fields
        //   - line: usize
        //   - column: usize
        //
        // A future "let me add a file_path field" extension would
        // silently change the CI lint output JSON shape — surface
        // here via destructure compile-fail + per-field type assertions.
        let m = RejectedNameMatch { line: 5, column: 3 };
        let RejectedNameMatch { line, column } = m;
        let _: usize = line;
        let _: usize = column;
    }

    #[test]
    fn every_rejected_name_match_field_is_identity_load_bearing() {
        // Phase 1 hardening — thirteenth leg of the identity-pin
        // pattern. RejectedNameMatch is a Copy struct with 2 fields
        // (line, column). CI drivers compare match positions across
        // runs to detect new violations — if either field were
        // silently dropped from PartialEq, two distinct match
        // positions (e.g. line 5 col 3 and line 5 col 17) would
        // collapse into one and the diff-vs-allowlist logic would
        // misreport.
        let base = RejectedNameMatch { line: 5, column: 3 };

        let mut diff_line = base;
        diff_line.line = 6;
        assert_ne!(diff_line, base, "line must participate in PartialEq");

        let mut diff_column = base;
        diff_column.column = 4;
        assert_ne!(diff_column, base, "column must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base, base);
    }

    #[test]
    fn rejected_name_constant_length_is_exactly_five_bytes() {
        // Phase 1 hardening — pin the byte length. A future change to
        // "aegis2" / "aeg" / etc. would silently shift matching
        // semantics (count_hits / scan_text both pivot on
        // REJECTED_NAME_LOWERCASE.len()). The exact value isn't the
        // point — the SAME value across versions is. PR-review-time
        // catch for any future "let me just tweak the keyword"
        // proposal.
        assert_eq!(REJECTED_NAME_LOWERCASE.len(), 5);
        assert_eq!(REJECTED_NAME_LOWERCASE, "aegis");
    }

    #[test]
    fn rejected_name_constant_is_lowercase_only() {
        // Guard against a maintainer accidentally capitalising the
        // constant — the matching algorithm assumes lowercase.
        assert_eq!(
            REJECTED_NAME_LOWERCASE,
            REJECTED_NAME_LOWERCASE.to_ascii_lowercase()
        );
    }

    #[test]
    fn text_contains_rejected_name_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to iter-224 scan_text/count_hits + the broader
        // purity series).
        let hit_input = "Aegis";
        let no_hit_input = "agent_runtime_v2";
        for input in [hit_input, no_hit_input] {
            let r1 = text_contains_rejected_name(input);
            let r2 = text_contains_rejected_name(input);
            let r3 = text_contains_rejected_name(input);
            assert_eq!(r1, r2);
            assert_eq!(r2, r3);
        }
    }

    #[test]
    fn catches_exact_capitalisation_variant() {
        assert!(text_contains_rejected_name("Aegis"));
        assert!(text_contains_rejected_name("AEGIS"));
        assert!(text_contains_rejected_name("aegis"));
        assert!(text_contains_rejected_name("AeGiS"));
    }

    #[test]
    fn catches_identifier_variants() {
        assert!(text_contains_rejected_name("aegis_runtime"));
        assert!(text_contains_rejected_name("AegisRuntime"));
        assert!(text_contains_rejected_name("AEGIS_MODE"));
    }

    #[test]
    fn catches_substring_variants() {
        // "Aegisplatform" / "preAegis" — substring match still trips.
        assert!(text_contains_rejected_name("Aegisplatform"));
        assert!(text_contains_rejected_name("preAegis"));
        assert!(text_contains_rejected_name("aegis-platform"));
    }

    #[test]
    fn catches_in_comments_and_strings() {
        assert!(text_contains_rejected_name("// thinking about Aegis"));
        assert!(text_contains_rejected_name("/// Aegis was rejected"));
        assert!(text_contains_rejected_name("let s = \"Aegis\";"));
        assert!(text_contains_rejected_name("# Aegis (do not use)"));
    }

    #[test]
    fn catches_in_file_path_components() {
        assert!(text_contains_rejected_name("src/aegis/mod.rs"));
        assert!(text_contains_rejected_name("src/AegisExecutor.swift"));
        assert!(text_contains_rejected_name("AEGIS.md"));
    }

    #[test]
    fn does_not_trip_on_unrelated_text() {
        // Sanity guardrail.
        assert!(!text_contains_rejected_name("agent_runtime_v2"));
        assert!(!text_contains_rejected_name("System G"));
        assert!(!text_contains_rejected_name("Invader Agent"));
        assert!(!text_contains_rejected_name("MutationEnvelope"));
        assert!(!text_contains_rejected_name(""));
        // "agis" alone is a 4-char prefix and must NOT trip (no false
        // positive on shorter strings).
        assert!(!text_contains_rejected_name("agis"));
    }

    #[test]
    fn count_hits_scan_text_parity_on_diverse_inputs() {
        // Phase 1 hardening — extend the count_hits ↔ scan_text
        // parity check to a wider set of inputs incl. the edge cases
        // covered by other tests (consecutive matches, multi-line,
        // commit-style, branch-style, unicode mixed). The two impls
        // share REJECTED_NAME_LOWERCASE but walk independently; this
        // pins the contract across the full match surface.
        for input in [
            "",
            "Aegis",
            "AegisAegis",
            "AegisAegisAegis",
            "Aegis Aegis aegis",
            "feature/Aegis-experiments",
            "// thinking about Aegis\nlet x = \"AEGIS\";",
            "日本語 Aegis 中文",
            "🚫 Aegis 🔥 AEGIS 🤖 aegis",
            "AAAaegisAAAaegis",
            "no hits at all here",
        ] {
            assert_eq!(
                count_hits(input),
                scan_text(input).len(),
                "count_hits / scan_text disagreement on {input:?}"
            );
        }
    }

    #[test]
    fn count_hits_returns_match_count_without_allocating_vec() {
        assert_eq!(count_hits(""), 0);
        assert_eq!(count_hits("clean text"), 0);
        assert_eq!(count_hits("Aegis"), 1);
        assert_eq!(count_hits("Aegis Aegis Aegis"), 3);
        assert_eq!(count_hits("Aegis\nAEGIS\naegis"), 3);
        assert_eq!(count_hits("Aegisplatform"), 1);
        assert_eq!(count_hits("Аегис"), 0); // Cyrillic, no ASCII match
    }

    #[test]
    fn text_contains_rejected_name_iff_count_hits_is_nonzero() {
        // Phase 1 hardening — cross-helper consistency pin.
        // text_contains_rejected_name is the cheap boolean-only path
        // for hot loops; count_hits is the per-occurrence tally; both
        // must agree on the binary "is there a match at all" question.
        //
        //   text_contains_rejected_name(t) == (count_hits(t) > 0)
        //
        // A future refactor that diverged the boolean path (e.g., "let
        // me skip the lowercase fold on ASCII-only inputs because
        // contains() can short-circuit on a literal needle") would
        // silently miss case-mixed Aegis variants while count_hits
        // still catches them — CI passes / fails inconsistently
        // depending on which helper the driver picked. Pin the
        // bi-conditional across positive + negative + tricky fixtures.
        for input in [
            // Negative cases (no Aegis).
            "",
            " ",
            "no rejected name here",
            "vault notes May 2026",
            // Positive cases — all 3 capitalisations.
            "Aegis",
            "AEGIS",
            "aegis",
            "Hello Aegis World",
            // Tricky: substring-of-token + multi-line + mixed.
            "before-aegis-after",
            "// comment about Aegis\nlet x = AEGIS;\nfn t() {}",
            "Aegis Aegis AEGIS aegis",
            // Almost-but-not: differ by one character.
            "aegi",
            "egis",
            "aegisX", // still contains "aegis" — positive
            "Xaegis", // still contains "aegis" — positive
            // Pure punctuation / digits with no aegis.
            "12345",
            "()*&^%$#@!",
        ] {
            let contains = text_contains_rejected_name(input);
            let count_nonzero = count_hits(input) > 0;
            assert_eq!(
                contains,
                count_nonzero,
                "text_contains vs count_hits>0 disagreement for input: {input:?} \
                 (contains={contains}, count_hits={})",
                count_hits(input)
            );
        }
    }

    #[test]
    fn count_hits_matches_scan_text_length() {
        // Property: count_hits() must equal scan_text().len() for
        // every input. Pin the contract so the two impls don't drift.
        for input in [
            "no hits here",
            "Aegis",
            "AEGIS Aegis aegis",
            "// thinking about Aegis\nlet x = \"AEGIS\";",
            "feature/Aegis-experiments",
            "",
        ] {
            assert_eq!(
                count_hits(input),
                scan_text(input).len(),
                "count_hits / scan_text disagreement for input: {input:?}"
            );
        }
    }

    #[test]
    fn scan_text_and_count_hits_are_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-223).
        // scan_text and count_hits operate on a &str input and
        // return Vec / usize respectively. Both must produce
        // identical results across repeated calls.
        //
        // A future refactor that introduced thread-local state for
        // "skip-cache" optimisation, or any interior mutability,
        // would silently break determinism that CI drivers
        // depend on for stable diff reports.
        let input = "Aegis here\n  some aegis there\nAEGIS";
        let v1 = scan_text(input);
        let v2 = scan_text(input);
        let v3 = scan_text(input);
        assert_eq!(v1, v2);
        assert_eq!(v2, v3);
        assert_eq!(v1.len(), 3);

        let c1 = count_hits(input);
        let c2 = count_hits(input);
        let c3 = count_hits(input);
        assert_eq!(c1, c2);
        assert_eq!(c2, c3);
        assert_eq!(c1, 3);
    }

    #[test]
    fn scan_text_returns_line_and_column_of_each_match() {
        let src = "fn ok() {}\n\
                   // Aegis was rejected\n\
                   const NAME: &str = \"AEGIS\";\n\
                   let other = true;\n";
        let hits = scan_text(src);
        assert_eq!(hits.len(), 2);
        // Line 2: "// Aegis was rejected" → "Aegis" starts at byte 3
        assert_eq!(hits[0], RejectedNameMatch { line: 2, column: 3 });
        // Line 3: `const NAME: &str = "AEGIS";` → "AEGIS" after 20-char prefix
        assert_eq!(hits[1].line, 3);
        assert_eq!(hits[1].column, 20);
    }

    #[test]
    fn scan_text_finds_rejected_name_inside_multibyte_unicode_line() {
        // Phase 1 hardening — UTF-8 boundary safety. The lint must
        // still detect "aegis" when surrounding bytes are multi-byte
        // (emoji, accented characters, Chinese, Arabic). to_ascii_lowercase
        // operates byte-wise and is a no-op on non-ASCII, so the
        // ASCII needle still matches at its byte offset. Verify:
        //   - no panic on multi-byte boundaries
        //   - match still detected
        //   - byte-column points to first byte of "aegis" substring

        // 🚀 = 4 bytes, é = 2 bytes, 中 = 3 bytes. Construct a line
        // where the needle lives past several multi-byte chars.
        let line = "🚀café中Aegis at end";
        let hits = scan_text(line);
        assert_eq!(hits.len(), 1, "expected exactly one Aegis hit");
        let m = hits[0];
        assert_eq!(m.line, 1);
        // Byte column = 4 (🚀) + 5 (café including é=2) + 3 (中) = 12
        // We re-derive it from the live string to avoid hand-counting drift.
        let expected_col = line.find("Aegis").expect("Aegis present");
        assert_eq!(m.column, expected_col);

        // Sanity: count_hits agrees and text_contains_rejected_name agrees.
        assert_eq!(count_hits(line), 1);
        assert!(text_contains_rejected_name(line));

        // Clean Unicode (no rejected name) must yield zero hits even
        // when full of multi-byte sequences.
        let clean = "🚀café中文 ✅ system-g ✅";
        assert_eq!(scan_text(clean).len(), 0);
        assert_eq!(count_hits(clean), 0);
        assert!(!text_contains_rejected_name(clean));
    }

    #[test]
    fn scan_text_accumulates_correct_per_line_numbering_across_sparse_multiline() {
        // Phase 1 hardening — line-counter accumulator must increment
        // for EVERY line in the text, not only matching lines. A
        // 5-line text with hits on lines 1, 3, 5 (sparse) catches
        // a regression where the counter only advances on matching
        // lines (which would report all three hits as line 1, 2, 3).
        let text = "Aegis here\n\
                    clean line\n\
                    AEGIS again\n\
                    another clean line\n\
                    final aegis";
        let hits = scan_text(text);
        assert_eq!(hits.len(), 3, "expected 3 hits across 5 lines");
        assert_eq!(hits[0].line, 1);
        assert_eq!(hits[1].line, 3);
        assert_eq!(hits[2].line, 5);
        // Column on first line is 0 (line starts with the name).
        assert_eq!(hits[0].column, 0);
        // Total count helper must agree.
        assert_eq!(count_hits(text), 3);
    }

    #[test]
    fn scan_text_returns_empty_on_clean_input() {
        let src = "use crate::agent_runtime_v2::Para;\n\
                   pub struct Foo;\n\
                   // System G / Invader Agent\n";
        assert!(scan_text(src).is_empty());
    }

    #[test]
    fn scan_text_handles_consecutive_matches_without_overlap() {
        // Phase 1 hardening — pin the non-overlapping semantics for
        // back-to-back matches. "AegisAegis" = 2 hits at cols 0 and 5,
        // not overlapping mid-name. The needle is 5 chars; the scan
        // advances by needle_len after each hit (already implemented
        // in scan_text; the test pins the contract).
        let hits = scan_text("AegisAegis");
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].column, 0);
        assert_eq!(hits[1].column, 5);
        // 3-in-a-row.
        let hits3 = scan_text("AegisAegisAegis");
        assert_eq!(hits3.len(), 3);
        assert_eq!(hits3[2].column, 10);
        // count_hits agrees.
        assert_eq!(count_hits("AegisAegisAegis"), 3);
    }

    #[test]
    fn scan_text_finds_multiple_matches_on_one_line() {
        let src = "Aegis and aegis and AEGIS";
        let hits = scan_text(src);
        assert_eq!(hits.len(), 3);
        assert_eq!(hits[0].line, 1);
        assert_eq!(hits[1].line, 1);
        assert_eq!(hits[2].line, 1);
        // Columns are monotonically increasing.
        assert!(hits[0].column < hits[1].column);
        assert!(hits[1].column < hits[2].column);
    }

    #[test]
    fn exempt_docs_list_membership_and_length_pinned_exactly() {
        // Phase 1 hardening — companion to
        // exempt_docs_list_is_alphabetically_ordered. The alphabetical
        // pin would still pass if a maintainer SILENTLY REMOVED an
        // entry from the middle of the list (3 sorted items remain
        // sorted). The is_path_exempt_matches_known_canonical_docs
        // test pins 4 specific paths, but the list has 6 entries
        // and two of them slip past coverage. Without an exact-
        // membership pin, a maintainer could drop the
        // CLAUDE_NO_COMPROMISE or CODEX_AND_CLAUDE doc from the
        // exempt list, re-introducing false-positive Aegis hits in
        // CI for those research artifacts.
        //
        // Pin the FULL list — length + each entry — so the doctrine
        // choice ("which docs may legitimately mention Aegis")
        // is locked at PR review.
        let expected: &[&str] = &[
            "agent_core/src/agent_runtime_v2/naming_lint.rs",
            "docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md",
            "docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md",
            "docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md",
            "docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md",
            "docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md",
        ];
        assert_eq!(
            AEGIS_LINT_EXEMPT_DOCS.len(),
            expected.len(),
            "AEGIS_LINT_EXEMPT_DOCS length drifted — pin must be updated when entries change"
        );
        assert_eq!(AEGIS_LINT_EXEMPT_DOCS, expected);
    }

    #[test]
    fn exempt_docs_list_is_alphabetically_ordered() {
        // Reviewer-diff hygiene: keep the list sorted so unrelated
        // doc additions don't shuffle adjacent rows.
        let mut sorted = AEGIS_LINT_EXEMPT_DOCS.to_vec();
        sorted.sort();
        assert_eq!(AEGIS_LINT_EXEMPT_DOCS, sorted.as_slice());
    }

    #[test]
    fn is_path_exempt_matches_known_canonical_docs() {
        assert!(is_path_exempt(
            "docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md"
        ));
        assert!(is_path_exempt(
            "docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md"
        ));
        // Absolute-path suffix also matches.
        assert!(is_path_exempt(
            "/Users/jojo/Downloads/Epistemos/docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md"
        ));
        // The lint module itself is exempt (constants + test fixtures).
        assert!(is_path_exempt(
            "agent_core/src/agent_runtime_v2/naming_lint.rs"
        ));
    }

    #[test]
    fn is_path_exempt_loops_every_canonical_entry_through_the_matcher() {
        // Phase 1 hardening — completeness companion to
        // is_path_exempt_matches_known_canonical_docs (which exercises
        // only 4 of the 6 entries). Every entry in AEGIS_LINT_EXEMPT_DOCS
        // MUST be reachable through is_path_exempt — both as a raw
        // entry AND as an absolute-path-prefixed suffix.
        //
        // Defends against a future "let me filter exempt paths by
        // file extension first" optimisation that would silently drop
        // a subset of entries (e.g., the .rs entry but not the .md
        // entries) from the matcher's view.
        for &entry in AEGIS_LINT_EXEMPT_DOCS {
            // Raw entry must be self-exempt.
            assert!(
                is_path_exempt(entry),
                "raw exempt entry {entry} must match is_path_exempt"
            );
            // Same suffix under an absolute prefix must also match
            // (production CI feeds absolute paths from `find`).
            let abs = format!("/Users/jojo/Downloads/Epistemos-x/{entry}");
            assert!(
                is_path_exempt(&abs),
                "absolute-prefixed {abs} must match is_path_exempt"
            );
        }
    }

    #[test]
    fn is_path_exempt_preserves_byte_suffix_matching_through_unicode_prefixes() {
        // Phase 1 hardening — Unicode safety pin for the
        // exempt-doc matcher. is_path_exempt uses
        // `path.ends_with(p)` (byte-suffix match); Unicode in the
        // path prefix must NOT confuse the suffix-match check.
        //
        // Companion to iter-203 (vault_persistence_path Unicode pin)
        // and iter-205-209 Unicode preservation pins.
        let exempt_suffix = "docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md";

        // CJK-prefixed path with the same suffix → must match.
        let cjk_prefixed = format!("/Users/jojo/笔记/{exempt_suffix}");
        assert!(
            is_path_exempt(&cjk_prefixed),
            "exempt suffix must match through CJK prefix: {cjk_prefixed}"
        );
        // Emoji-prefixed path with the same suffix → must match.
        let emoji_prefixed = format!("/Users/🚀/{exempt_suffix}");
        assert!(
            is_path_exempt(&emoji_prefixed),
            "exempt suffix must match through emoji prefix: {emoji_prefixed}"
        );
        // CJK-suffixed unrelated path → must NOT match (no exempt
        // entry uses CJK).
        let cjk_unrelated = "/Users/jojo/笔记/notes.md".to_string();
        assert!(
            !is_path_exempt(&cjk_unrelated),
            "non-exempt CJK path must not match: {cjk_unrelated}"
        );
    }

    #[test]
    fn is_path_exempt_normalizes_backslash_separators_before_suffix_match() {
        // Phase 1 hardening — Aegis CI lint exhaustive path coverage.
        // The helper is the canonical exemption contract, so it must
        // own separator normalization instead of relying on every CI
        // caller to remember to pre-normalize paths before scanning.
        //
        // Without this pin, a backslash-separated path to an exempt
        // doctrine doc would miss the allow-list and fail the lint
        // even though the exact same path with slashes is allowed.
        assert!(is_path_exempt(
            r"docs\AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md"
        ));
        assert!(is_path_exempt(
            r"C:\repo\Epistemos\agent_core\src\agent_runtime_v2\naming_lint.rs"
        ));
    }

    #[test]
    fn is_path_exempt_does_not_match_unrelated_paths() {
        assert!(!is_path_exempt("agent_core/src/agent_runtime_v2/mode.rs"));
        assert!(!is_path_exempt("README.md"));
        assert!(!is_path_exempt("docs/some_other_doc.md"));
        assert!(!is_path_exempt(""));
    }

    #[test]
    fn lint_fuzz_inputs_never_panic() {
        // Phase 1 hardening — boundary fuzz. The lint must not panic
        // on any UTF-8 input the harness might feed it, including
        // edge-case bytes (lone CR, lone LF, NUL, very long pure-
        // ASCII, very long mixed UTF-8, surrogate-pair-rich text).
        // We assert that scan_text + text_contains_rejected_name
        // both complete without panic; correctness is only asserted
        // where the expected outcome is unambiguous.
        let mut fuzz_inputs: Vec<String> = vec![
            "\r".repeat(1024),
            "\n".repeat(1024),
            "\0".repeat(1024),
            "\r\n".repeat(512),
            "x".repeat(10_000),                   // long pure-ASCII, no hit
            ("日本語".to_string()).repeat(2_000), // long pure-CJK
            "𐀀𐀁𐀂𐀃".repeat(500),                   // non-BMP code points
            "🚫🔥🤖✓".repeat(500),                // emoji
            "Aegis\0Aegis\0Aegis".to_string(),    // NUL between matches
        ];
        // Long mixed-Unicode line with one Aegis hit.
        fuzz_inputs.push(format!("{}Aegis{}", "日".repeat(500), "本".repeat(500)));
        for input in &fuzz_inputs {
            let _ = text_contains_rejected_name(input);
            let _ = scan_text(input);
        }
        // Sanity: the NUL-separated Aegis case should hit 3 times.
        let hits = scan_text("Aegis\0Aegis\0Aegis");
        assert_eq!(hits.len(), 3);
    }

    #[test]
    fn lint_handles_unicode_surrounding_text_safely() {
        // Phase 1 hardening — Unicode safety: the matching predicate
        // is ASCII-lowercase + substring, so non-ASCII surrounding
        // text must not panic or corrupt indexing.
        //
        // ASCII "Aegis" inside non-ASCII context → must trip.
        assert!(text_contains_rejected_name("see § Aegis below"));
        assert!(text_contains_rejected_name("✗ Aegis was rejected →"));
        assert!(text_contains_rejected_name("日本語 Aegis 中文"));
        // Cyrillic "Аегис" (different code points; all non-ASCII) →
        // must NOT trip. The visual lookalike doesn't count; only
        // the ASCII bytes do.
        assert!(!text_contains_rejected_name("Аегис"));
        assert!(!text_contains_rejected_name("see § Аегис below"));
    }

    #[test]
    fn lint_handles_emoji_and_combining_characters_without_panic() {
        // Combining characters and emoji must not panic the lint.
        for input in [
            "Aegis 🚫",
            "🚫 Aegis 🚫",
            "AEGIS\u{0301}",      // combining acute on the S
            "\u{1F600}\u{1F600}", // pure emoji, no Aegis
            "AÉgis",              // É has accent, breaks ASCII match
        ] {
            // Call must complete without panic. Return values are
            // asserted only where we have a clear expectation.
            let hit = text_contains_rejected_name(input);
            // The first three contain "Aegis"/"AEGIS"/"AEGIS\u{301}"
            // — all match because ASCII bytes are present. AÉgis
            // breaks the ASCII sequence with É so it must NOT match.
            // Pure-emoji string must NOT match.
            if input == "AÉgis" || input == "\u{1F600}\u{1F600}" {
                assert!(!hit, "expected no match for {input:?}");
            } else {
                assert!(hit, "expected match for {input:?}");
            }
        }
    }

    #[test]
    fn lint_catches_aegis_inside_git_commit_message_text() {
        // Phase 1 hardening — user's explicit Aegis-lint list:
        // "git commit messages". Synthetic commit-message style text
        // including a Co-Authored-By trailer. The lint must flag any
        // occurrence regardless of position.
        let commit_msg = "feat: introduce Aegis-style executor stub\n\
                          \n\
                          This commit experiments with the rejected name.\n\
                          \n\
                          Co-Authored-By: someone <x@y.z>\n";
        let hits = scan_text(commit_msg);
        assert!(!hits.is_empty(), "lint must flag Aegis in commit subject");
        assert!(text_contains_rejected_name(commit_msg));
    }

    #[test]
    fn lint_catches_aegis_inside_branch_name_text() {
        // Phase 1 hardening — user's explicit Aegis-lint list:
        // "branch names". A branch name with Aegis in any case must
        // be flagged.
        for branch in [
            "feature/Aegis-experiments",
            "feature/aegis-executor",
            "fix/AEGIS-bug",
            "release/v1.0-aegis",
            "claude/aegis-prep",
        ] {
            assert!(
                text_contains_rejected_name(branch),
                "lint must flag branch name: {branch}"
            );
        }
    }

    #[test]
    fn lint_catches_aegis_inside_doc_filename_variants() {
        // Phase 1 hardening — work-queue item D: Aegis CI lint
        // exhaustive cases — "doc filenames (case-insensitive,
        // every variant)". Companion to:
        //   - catches_in_file_path_components (3 hard-coded file paths)
        //   - lint_catches_aegis_inside_git_commit_message_text
        //   - lint_catches_aegis_inside_branch_name_text
        //
        // Doctrine docs in docs/ have an EXEMPT allow-list at
        // naming_lint.rs §29-33 — those 5 paths are intentionally
        // allowed to discuss Aegis as a rejected name. But any
        // OTHER doc file with Aegis in the name must be flagged so
        // it doesn't sneak into the repo (especially in non-doctrine
        // doc subdirs like docs/sprint-sessions/, docs/audits/,
        // docs/handoff/).
        //
        // Pin a wide variety of doc filename shapes:
        //   - common doc extensions (.md, .rst, .txt, .org, .adoc)
        //   - case variants (Aegis / AEGIS / aegis)
        //   - position variants (leading, trailing, middle of name)
        //   - subdirectory paths
        for path in [
            // Common doc extensions, case-mixed
            "docs/Aegis-rationale.md",
            "docs/aegis-handoff.rst",
            "docs/AEGIS-runtime.txt",
            "docs/aegis_design.org",
            "docs/Aegis-deep-analysis.adoc",
            // Subdirectory positions
            "docs/sprint-sessions/aegis-iter-3.md",
            "docs/audits/Aegis-replay-bug.md",
            "docs/handoff/2026-05-AEGIS-resume.md",
            // Trailing-position name
            "docs/agent_aegis.md",
            // Embedded-position name
            "docs/pre-AEGIS-substrate-2026-05-18.md",
            // Bare README variants
            "docs/aegis/README.md",
            "AEGIS_README.md",
            "docs/Aegis_NOTES.md",
        ] {
            assert!(
                text_contains_rejected_name(path),
                "lint must flag doc filename: {path}"
            );
        }
    }

    #[test]
    fn lint_does_not_flag_legitimate_doc_filename_variants() {
        // Phase 1 hardening — symmetric negative companion to the
        // doc-filename positive pin. Legitimate doctrine + handoff
        // docs that do NOT name Aegis must NOT trip the lint.
        //
        // Defends against a future false-positive regression that
        // widened the matcher beyond the 5-char "aegis" needle.
        for path in [
            "docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md",
            "docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md",
            "docs/audit-progress.md",
            "docs/sprint-sessions/sprint-omega-1-foundation.md",
            "docs/AGENT_PROGRESS.md",
            "docs/EPISTEMOS_FUSED_v3.md",
            "docs/agent-system/AGENT_ARCHITECTURE.md",
            "README.md",
            "AGENTS.md",
            "CLAUDE.md",
            // Adjacent-but-different vocab (no aegis substring)
            "docs/aegean-sea-philosophy.md", // close vowels but no 'gis'
            "docs/age-of-aquarius.md",       // shares 'age' prefix only
        ] {
            assert!(
                !text_contains_rejected_name(path),
                "lint must NOT flag legitimate doc filename: {path}"
            );
        }
    }

    #[test]
    fn lint_does_not_flag_legitimate_branch_names() {
        for branch in [
            "feature/system-g-executor",
            "feature/invader-agent",
            "feature/agent_runtime_v2",
            "claude/t11-agent-runtime-v2-2026-05-18",
            "main",
        ] {
            assert!(
                !text_contains_rejected_name(branch),
                "lint must NOT flag legitimate branch: {branch}"
            );
        }
    }

    #[test]
    fn short_text_path_does_not_match() {
        // Inputs shorter than the rejected name can never contain it.
        assert!(!text_contains_rejected_name("a"));
        assert!(!text_contains_rejected_name("ae"));
        assert!(!text_contains_rejected_name("aeg"));
        assert!(!text_contains_rejected_name("aegi"));
    }

    #[test]
    fn scan_text_and_count_hits_return_zero_for_shorter_than_needle_inputs() {
        // Phase 1 hardening — short-input boundary pin for scan_text +
        // count_hits (companion to short_text_path_does_not_match for
        // text_contains_rejected_name).
        //
        // Inputs whose length is less than REJECTED_NAME_LOWERCASE.len()
        // (= 5) cannot contain the needle. Both scan_text and
        // count_hits MUST return the empty result without panic.
        //
        // count_hits has an explicit early-return; scan_text loops over
        // lines whose length is checked individually. A future
        // refactor that dropped the early-return on either helper
        // would slip past the per-line empty case but would surface
        // here on the under-length probe.
        for short in ["", "a", "ae", "aeg", "aegi"] {
            assert_eq!(
                scan_text(short),
                vec![],
                "scan_text({short:?}) must be empty"
            );
            assert_eq!(count_hits(short), 0, "count_hits({short:?}) must be 0");
        }
    }
}
