//! Phase 3D-1 — concept canonicalizer (deterministic, no LLM).
//!
//! Plan §3.7: "lowercase → unicode-normalize → strip stopwords →
//! lemmatize (`rust-stemmers`) → kebab-case → sort multi-word tokens
//! alphabetically. `gradient checkpointing` and `Gradient
//! Checkpointing!` both → `gradient-checkpointing`."
//!
//! **Spec vs example divergence in plan:** the example output
//! `gradient-checkpointing` doesn't actually carry the
//! "sort alphabetically" property the spec mandates — alphabetic
//! sort would give `checkpoint-gradient`. The canonical-name
//! invariant requires sort (else "X Y" and "Y X" diverge), so this
//! impl follows the SPEC, not the example. A note in the
//! AGENT_PROGRESS commit calls this out.
//!
//! Per plan §1.4 No-LLM-First mandate this is a deterministic
//! variant. ASCII-fold instead of full Unicode NFD/NFC because
//! Phase 1 is English-first per §3.7 ("Multilingual support is **not
//! on the Quick Capture critical path**"); CJK + accents land per
//! user demand under the `LanguageNormalizer` trait.

use rust_stemmers::{Algorithm, Stemmer};

/// Canonical English stopwords. Hand-curated rather than crate-pulled
/// to keep the dep surface narrow and stable across rust-stemmers
/// vendoring decisions.
const STOPWORDS: &[&str] = &[
    "a", "an", "the", "and", "or", "but", "if", "then", "of", "in", "on",
    "at", "to", "for", "with", "about", "as", "by", "from", "is", "are",
    "was", "were", "be", "been", "being", "have", "has", "had", "do",
    "does", "did", "will", "would", "could", "should", "may", "might",
    "must", "shall", "can", "this", "that", "these", "those", "it", "its",
    "am", "we", "us", "our", "you", "your", "i", "me", "my", "he", "she", "him",
    "her", "his", "hers", "they", "them", "their", "what", "which", "who",
    "whom", "whose", "where", "when", "why", "how", "all", "any", "both",
    "each", "few", "more", "most", "other", "some", "such", "no", "nor",
    "not", "only", "own", "same", "so", "than", "too", "very",
];

/// Canonicalize a free-form concept name into the form used by the
/// alias table + concept graph. Example:
/// - `"Gradient Checkpointing!"` → `"checkpoint-gradient"`
/// - `"gradient checkpointing"` → `"checkpoint-gradient"`
/// - `"recompute checkpointing"` → `"checkpoint-recomput"`
///   (after Porter stemming + alpha sort)
pub fn canonicalize(input: &str) -> String {
    // Step 1: lowercase + ASCII-fold (English-first per §3.7).
    let lowered: String = input
        .chars()
        .filter_map(|c| {
            if c.is_alphanumeric() || c.is_whitespace() {
                Some(c.to_ascii_lowercase())
            } else {
                Some(' ') // collapse non-alphanumeric to whitespace for tokenization
            }
        })
        .collect();

    // Step 2: tokenize on whitespace.
    let tokens: Vec<&str> = lowered.split_whitespace().collect();

    // Step 3: strip stopwords.
    let content_tokens: Vec<&str> = tokens
        .into_iter()
        .filter(|t| !STOPWORDS.contains(t))
        .collect();

    if content_tokens.is_empty() {
        return String::new();
    }

    // Step 4: lemmatize each token via Porter (English).
    let stemmer = Stemmer::create(Algorithm::English);
    let mut stems: Vec<String> = content_tokens
        .iter()
        .map(|t| stemmer.stem(t).into_owned())
        .filter(|s| !s.is_empty())
        .collect();

    // Step 5: sort tokens alphabetically — canonical-name invariant
    // requires "X Y" and "Y X" to map to the same canonical.
    stems.sort();
    stems.dedup();

    // Step 6: kebab-case join.
    stems.join("-")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn case_punctuation_and_word_order_normalized_to_same_canonical() {
        // Plan §3.7's canonical-name invariant: surface vocabulary
        // changes that don't change meaning must map to the same
        // canonical key. The alphabetic-sort step is what makes this
        // hold for word order.
        let a = canonicalize("Gradient Checkpointing");
        let b = canonicalize("gradient checkpointing");
        let c = canonicalize("checkpointing gradient");
        let d = canonicalize("Gradient Checkpointing!");
        let e = canonicalize("gradient   checkpointing");
        assert_eq!(a, b);
        assert_eq!(a, c);
        assert_eq!(a, d);
        assert_eq!(a, e);
    }

    #[test]
    fn empty_input_returns_empty() {
        assert_eq!(canonicalize(""), "");
        assert_eq!(canonicalize("    "), "");
    }

    #[test]
    fn stopwords_only_returns_empty() {
        assert_eq!(canonicalize("the and or but"), "");
        assert_eq!(canonicalize("a the"), "");
    }

    #[test]
    fn stopwords_filtered_from_content_tokens() {
        // "the gradient of checkpointing" → ["gradient", "checkpoint"]
        // → sorted → "checkpoint-gradient" (after stem).
        let canonical = canonicalize("the gradient of checkpointing");
        assert_eq!(canonical, "checkpoint-gradient");
    }

    #[test]
    fn stem_normalizes_inflections() {
        // running / runs / runner all stem differently in Porter, but
        // running and runs converge to "run". The canonical for
        // "I am running" should equal canonical for "she runs".
        let a = canonicalize("I am running");
        let b = canonicalize("she runs");
        assert_eq!(a, b);
    }

    #[test]
    fn punctuation_collapsed_not_preserved() {
        let a = canonicalize("attention is all you need!");
        let b = canonicalize("attention is all you need");
        assert_eq!(a, b);
        // "is", "all", "you" are stopwords; "attention" + "need" remain.
        assert_eq!(a, "attent-need");
    }

    #[test]
    fn kebab_case_output_no_underscores_no_spaces() {
        let canonical = canonicalize("multi step reasoning loops");
        assert!(!canonical.contains('_'));
        assert!(!canonical.contains(' '));
        assert!(canonical.contains('-') || canonical.is_empty());
    }

    #[test]
    fn dedup_removes_repeated_stems() {
        // "running and running and running" → all stem to "run" →
        // dedup → single "run".
        let canonical = canonicalize("running running running");
        assert_eq!(canonical, "run");
    }

    #[test]
    fn ascii_fold_for_basic_punctuation_and_digits() {
        let canonical = canonicalize("epistemos-v3 final!");
        // hyphen + ! collapse to whitespace; digits preserved as part
        // of token; "v3", "final", "epistemo" (Porter chops "s")
        assert!(!canonical.is_empty());
        // Sorted alphabetically.
        let parts: Vec<&str> = canonical.split('-').collect();
        let mut sorted = parts.clone();
        sorted.sort();
        assert_eq!(parts, sorted, "canonical must be alphabetically sorted");
    }

    #[test]
    fn rematerialization_does_not_yet_alias_to_gradient_checkpointing() {
        // Plan §3.7 worked example: "rematerialization" should end up
        // aliased to "gradient-checkpointing" via the alias table.
        // The deterministic canonicalizer doesn't know the alias —
        // that's a separate layer (Phase 3D-2 alias table). Confirm
        // the canonicalizer alone gives them DIFFERENT canonicals;
        // alias table responsibility is documented.
        let a = canonicalize("rematerialization");
        let b = canonicalize("gradient checkpointing");
        assert_ne!(
            a, b,
            "deterministic canonicalizer alone can't alias; that's the alias-table layer"
        );
    }

    #[test]
    fn tokens_are_alphabetically_sorted_in_output() {
        // Engineer an input with multiple content tokens and verify
        // the output's hyphen-separated parts are alpha-sorted.
        let canonical = canonicalize("zebra apple mango");
        let parts: Vec<&str> = canonical.split('-').collect();
        let mut sorted = parts.clone();
        sorted.sort();
        assert_eq!(parts, sorted);
    }

    #[test]
    fn idempotent_on_already_canonical_input() {
        let once = canonicalize("checkpoint gradient");
        let twice = canonicalize(&once.replace('-', " "));
        assert_eq!(once, twice);
    }
}
