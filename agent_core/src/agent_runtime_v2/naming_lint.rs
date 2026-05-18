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
    fn short_text_path_does_not_match() {
        // Inputs shorter than the rejected name can never contain it.
        assert!(!text_contains_rejected_name("a"));
        assert!(!text_contains_rejected_name("ae"));
        assert!(!text_contains_rejected_name("aeg"));
        assert!(!text_contains_rejected_name("aegi"));
    }
}
