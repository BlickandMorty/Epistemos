//! Title Generator — Heuristic conversation title from first message
//!
//! Reference: Hermes `agent/title_generator.py`
//! Generates a 3-7 word title from the first user message without LLM calls.
//! This is a fast heuristic; the Hermes version uses an LLM but we avoid the
//! extra API call for latency and cost reasons.

/// Maximum title length in characters.
const MAX_TITLE_LEN: usize = 50;

/// Prefixes to strip from the user message before title extraction.
const STRIP_PREFIXES: &[&str] = &[
    "can you ",
    "could you ",
    "please ",
    "help me ",
    "i want to ",
    "i need to ",
    "i'd like to ",
    "i would like to ",
    "let's ",
    "let me ",
    "hey, ",
    "hi, ",
    "hello, ",
];

/// Generate a short title from the first user message.
///
/// Algorithm:
/// 1. Take the first sentence (up to `.`, `?`, `!`, or newline).
/// 2. Strip common prefixes ("Can you", "Please", etc.).
/// 3. Capitalize the first letter.
/// 4. Truncate to MAX_TITLE_LEN chars at a word boundary.
/// 5. Return None if the result is too short (<3 chars).
pub fn generate_title(first_message: &str) -> Option<String> {
    let text = first_message.trim();
    if text.is_empty() {
        return None;
    }

    // Take first sentence (delimited by sentence-ending punctuation or newline).
    let first_sentence = text
        .split(|c: char| c == '.' || c == '?' || c == '!' || c == '\n')
        .next()
        .unwrap_or(text)
        .trim();

    if first_sentence.is_empty() {
        return None;
    }

    // Strip common prefixes (case-insensitive).
    let mut cleaned = first_sentence.to_string();
    let lower = cleaned.to_lowercase();
    for prefix in STRIP_PREFIXES {
        if lower.starts_with(prefix) {
            cleaned = cleaned[prefix.len()..].to_string();
            break;
        }
    }
    let cleaned = cleaned.trim().to_string();

    if cleaned.len() < 3 {
        return None;
    }

    // Capitalize first letter.
    let mut chars = cleaned.chars();
    let title = match chars.next() {
        Some(c) => {
            let mut s = c.to_uppercase().to_string();
            s.push_str(chars.as_str());
            s
        }
        None => return None,
    };

    // Truncate at word boundary.
    if title.len() <= MAX_TITLE_LEN {
        return Some(title);
    }

    // Find the last space before the limit.
    let truncation_point = title[..MAX_TITLE_LEN]
        .rfind(' ')
        .unwrap_or(MAX_TITLE_LEN);

    let mut truncated = title[..truncation_point].to_string();
    truncated.push_str("...");
    Some(truncated)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generates_title_from_simple_message() {
        let title = generate_title("Fix the login button bug").unwrap();
        assert_eq!(title, "Fix the login button bug");
    }

    #[test]
    fn strips_please_prefix() {
        let title = generate_title("Please fix the login button").unwrap();
        assert_eq!(title, "Fix the login button");
    }

    #[test]
    fn strips_can_you_prefix() {
        let title = generate_title("Can you help me debug this test?").unwrap();
        assert_eq!(title, "Help me debug this test");
    }

    #[test]
    fn takes_first_sentence_only() {
        let title = generate_title("Fix the bug. Then add tests. Also refactor.").unwrap();
        assert_eq!(title, "Fix the bug");
    }

    #[test]
    fn truncates_long_titles() {
        let title = generate_title(
            "Implement a comprehensive distributed caching layer with Redis sentinel failover and automatic cache invalidation across multiple data centers"
        ).unwrap();
        assert!(title.len() <= MAX_TITLE_LEN + 3); // +3 for "..."
        assert!(title.ends_with("..."));
    }

    #[test]
    fn capitalizes_first_letter() {
        let title = generate_title("i need to fix the parser").unwrap();
        assert!(title.starts_with('F'));
    }

    #[test]
    fn returns_none_for_empty() {
        assert!(generate_title("").is_none());
        assert!(generate_title("   ").is_none());
    }

    #[test]
    fn returns_none_for_too_short() {
        assert!(generate_title("hi").is_none());
    }

    #[test]
    fn handles_question_marks() {
        let title = generate_title("How do I configure the database? I need help.").unwrap();
        assert_eq!(title, "How do I configure the database");
    }

    #[test]
    fn handles_newlines() {
        let title = generate_title("Fix the API endpoint\nAlso update the docs").unwrap();
        assert_eq!(title, "Fix the API endpoint");
    }
}
