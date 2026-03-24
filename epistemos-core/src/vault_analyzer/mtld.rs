use std::collections::HashSet;

/// Default TTR threshold for MTLD factor boundaries.
/// Standard value from Koizumi & In'nami (2012).
pub const DEFAULT_MTLD_THRESHOLD: f64 = 0.720;

/// Bi-directional MTLD (Measure of Textual Lexical Diversity).
/// Port of kristopherkyle/lexical_diversity `ld.mtld_ma_bid()`.
///
/// High MTLD (>100) → high lexical diversity → higher intrinsic dimensionality → more LoRA rank
/// Low MTLD (<50)   → low lexical diversity  → lower intrinsic dimensionality → less rank needed
pub fn mtld_ma_bid(tokens: &[String], threshold: f64) -> f64 {
    if tokens.is_empty() {
        return 0.0;
    }

    let forward = mtld_ma_one_direction(tokens, threshold);
    let reversed: Vec<String> = tokens.iter().rev().cloned().collect();
    let backward = mtld_ma_one_direction(&reversed, threshold);

    (forward + backward) / 2.0
}

fn mtld_ma_one_direction(tokens: &[String], threshold: f64) -> f64 {
    let n = tokens.len();
    if n == 0 {
        return 0.0;
    }

    let mut factor_lengths: Vec<f64> = Vec::new();
    let mut i = 0;

    while i < n {
        let mut types: HashSet<&str> = HashSet::new();
        let mut j = i;

        loop {
            if j >= n {
                // Partial factor at end of text
                let token_count = (j - i) as f64;
                if token_count > 0.0 {
                    let ttr = types.len() as f64 / token_count;
                    if ttr < 1.0 && threshold < 1.0 {
                        let partial = (1.0 - ttr) / (1.0 - threshold);
                        if partial > 0.0 {
                            factor_lengths.push(token_count / partial);
                        }
                    }
                }
                i = j;
                break;
            }

            types.insert(&tokens[j]);
            let token_count = (j - i + 1) as f64;
            let ttr = types.len() as f64 / token_count;

            if ttr <= threshold && token_count > 1.0 {
                factor_lengths.push(token_count);
                i = j + 1;
                break;
            }

            j += 1;
        }

        if i >= n {
            break;
        }
    }

    if factor_lengths.is_empty() {
        return n as f64;
    }

    let sum: f64 = factor_lengths.iter().sum();
    sum / factor_lengths.len() as f64
}

/// Tokenize text for MTLD: lowercase, keep alphanumeric + hyphens + apostrophes.
pub fn tokenize_for_mtld(text: &str) -> Vec<String> {
    text.split_whitespace()
        .map(|w| {
            w.chars()
                .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '\'')
                .collect::<String>()
                .to_lowercase()
        })
        .filter(|w| !w.is_empty())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_input() {
        assert_eq!(mtld_ma_bid(&[], DEFAULT_MTLD_THRESHOLD), 0.0);
    }

    #[test]
    fn test_single_token() {
        let tokens = vec!["hello".to_string()];
        let score = mtld_ma_bid(&tokens, DEFAULT_MTLD_THRESHOLD);
        assert!(score > 0.0);
    }

    #[test]
    fn test_repetitive_low_diversity() {
        // Repeating the same few words → low MTLD
        let tokens: Vec<String> = (0..100)
            .map(|i| ["the", "cat", "sat"][i % 3].to_string())
            .collect();
        let score = mtld_ma_bid(&tokens, DEFAULT_MTLD_THRESHOLD);
        assert!(score < 20.0, "Repetitive text should have low MTLD, got {score}");
    }

    #[test]
    fn test_diverse_high_diversity() {
        // All unique words → high MTLD
        let tokens: Vec<String> = (0..100)
            .map(|i| format!("word{i}"))
            .collect();
        let score = mtld_ma_bid(&tokens, DEFAULT_MTLD_THRESHOLD);
        assert!(score > 50.0, "All unique words should have high MTLD, got {score}");
    }

    #[test]
    fn test_tokenizer_basic() {
        let tokens = tokenize_for_mtld("Hello, World! This is a test.");
        assert_eq!(tokens, vec!["hello", "world", "this", "is", "a", "test"]);
    }

    #[test]
    fn test_tokenizer_preserves_hyphens() {
        let tokens = tokenize_for_mtld("self-contained well-known");
        assert_eq!(tokens, vec!["self-contained", "well-known"]);
    }
}
