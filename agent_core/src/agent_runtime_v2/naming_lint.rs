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
    fn rejected_name_constant_is_lowercase_only() {
        // Guard against a maintainer accidentally capitalising the
        // constant — the matching algorithm assumes lowercase.
        assert_eq!(
            REJECTED_NAME_LOWERCASE,
            REJECTED_NAME_LOWERCASE.to_ascii_lowercase()
        );
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
    fn scan_text_returns_empty_on_clean_input() {
        let src = "use crate::agent_runtime_v2::Para;\n\
                   pub struct Foo;\n\
                   // System G / Invader Agent\n";
        assert!(scan_text(src).is_empty());
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
    fn short_text_path_does_not_match() {
        // Inputs shorter than the rejected name can never contain it.
        assert!(!text_contains_rejected_name("a"));
        assert!(!text_contains_rejected_name("ae"));
        assert!(!text_contains_rejected_name("aeg"));
        assert!(!text_contains_rejected_name("aegi"));
    }
}
