//! Deterministic concept canonicalization recovered from the Quick Capture
//! salvage track.

use std::sync::OnceLock;

use deunicode::deunicode;
use rust_stemmers::{Algorithm, Stemmer};

pub mod alias;

pub use alias::{
    classify_alias_cosine, AliasDecision, AliasEntry, AliasProvenance, AliasTable,
    ALIAS_DEFER_BAND_LOWER, ALIAS_PROPOSE_MERGE_THRESHOLD, ALIAS_V1_ID,
};

const STOPWORDS: &[&str] = &[
    "a", "an", "the", "and", "or", "but", "if", "then", "of", "in", "on", "at", "to", "for",
    "with", "about", "as", "by", "from", "is", "are", "was", "were", "be", "been", "being", "have",
    "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must",
    "shall", "can", "this", "that", "these", "those", "it", "its", "am", "we", "us", "our", "you",
    "your", "i", "me", "my", "he", "she", "him", "her", "his", "hers", "they", "them", "their",
    "what", "which", "who", "whom", "whose", "where", "when", "why", "how", "all", "any", "both",
    "each", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own",
    "same", "so", "than", "too", "very",
];

pub fn canonicalize(input: &str) -> String {
    static STEMMER: OnceLock<Stemmer> = OnceLock::new();
    let stemmer = STEMMER.get_or_init(|| Stemmer::create(Algorithm::English));

    let folded = deunicode(input);
    let lowered: String = folded
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || character.is_ascii_whitespace() {
                character.to_ascii_lowercase()
            } else {
                ' '
            }
        })
        .collect();

    let mut stems: Vec<String> = lowered
        .split_whitespace()
        .filter(|token| !STOPWORDS.contains(token))
        .map(|token| stemmer.stem(token).into_owned())
        .filter(|stem| !stem.is_empty())
        .collect();

    stems.sort();
    stems.dedup();
    stems.join("-")
}

pub(crate) fn is_canonical_name(value: &str) -> bool {
    !value.is_empty()
        && value.split('-').all(|part| {
            !part.is_empty()
                && part
                    .bytes()
                    .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
        })
}
