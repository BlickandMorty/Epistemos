/// Dual-bound token estimation heuristic.
/// Uses max(chars/3.5, words*1.33) per document.
///
/// - chars/3.5 accounts for subword tokenization of dense text (code, math)
/// - words*1.33 accounts for natural language with longer words
///
/// The EXISTING DocumentChunker uses `Double(words) * 1.3` — this is the upgrade.
pub fn estimate_tokens(content: &str) -> usize {
    let char_estimate = (content.len() as f64 / 3.5).ceil() as usize;
    let word_count = content.split_whitespace().count();
    let word_estimate = (word_count as f64 * 1.33).ceil() as usize;
    char_estimate.max(word_estimate)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty() {
        assert_eq!(estimate_tokens(""), 0);
    }

    #[test]
    fn test_prose() {
        // "Hello world" = 11 chars, 2 words
        // chars/3.5 = 3.14 → 4, words*1.33 = 2.66 → 3
        let tokens = estimate_tokens("Hello world");
        assert_eq!(tokens, 4); // char estimate wins for short text
    }

    #[test]
    fn test_code_dense() {
        // Code is char-dense: lots of symbols, short "words"
        let code = "fn main() { let x = vec![1,2,3]; x.iter().map(|i| i*2).collect::<Vec<_>>(); }";
        let tokens = estimate_tokens(code);
        // chars/3.5 should dominate for code
        let char_est = (code.len() as f64 / 3.5).ceil() as usize;
        assert_eq!(tokens, char_est);
    }

    #[test]
    fn test_always_gte_old_formula() {
        // Verify dual-bound ≥ old formula (words * 1.3) for typical text
        let text = "The quick brown fox jumps over the lazy dog near the riverbank";
        let old = (text.split_whitespace().count() as f64 * 1.3).ceil() as usize;
        let new = estimate_tokens(text);
        assert!(new >= old, "New estimate ({new}) should be ≥ old ({old})");
    }
}
