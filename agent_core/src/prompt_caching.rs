// ── Prompt Caching Breakpoints ─────────────────────────────────────────────
//
// Anthropic's prompt caching allows up to 4 explicit cache_control breakpoints.
// Strategy (matches Hermes agent/prompt_caching.py pattern):
//
//   Breakpoint 1: End of system prompt (largest, most stable block)
//   Breakpoint 2: First user message (the original objective — never changes)
//   Breakpoint 3: Third-to-last message (sliding window of recent context)
//   Breakpoint 4: Last message (the current turn — always fresh)
//
// On a 10-turn agent session with a 4K system prompt:
//   Without caching: ~40K input tokens billed per turn = ~400K total
//   With caching:    ~40K cached reads @ 90% discount = ~44K effective total
//   Savings: ~85% of input token costs

use serde_json::{json, Value};

/// Maximum number of Anthropic cache_control breakpoints per request.
const MAX_CACHE_BREAKPOINTS: usize = 4;

/// Apply cache_control breakpoints to the system prompt.
///
/// Converts a plain string system prompt into a structured system block
/// with an ephemeral cache_control marker. This is breakpoint 1 of 4.
pub fn cache_system_prompt(system_text: &str) -> Value {
    json!([{
        "type": "text",
        "text": system_text,
        "cache_control": { "type": "ephemeral" }
    }])
}

/// Apply cache_control breakpoints to the message array.
///
/// Places breakpoints on strategically chosen messages to maximize cache hits:
///   - First user message (the objective — stable across all turns)
///   - Third-to-last message (sliding context window)
///   - Last message (current turn input)
///
/// This function mutates the messages in-place. It consumes breakpoints 2-4
/// (breakpoint 1 is on the system prompt).
pub fn apply_message_cache_breakpoints(messages: &mut [Value]) {
    if messages.is_empty() {
        return;
    }

    // Breakpoint indices (0-based into the messages array).
    // We budget 3 message breakpoints (system prompt took 1).
    let mut breakpoint_indices = Vec::with_capacity(MAX_CACHE_BREAKPOINTS - 1);

    // Always cache the first message (original objective).
    breakpoint_indices.push(0);

    let len = messages.len();
    if len >= 4 {
        // Third-to-last: sliding window anchor.
        breakpoint_indices.push(len - 3);
    }
    if len >= 2 {
        // Last message: current turn input.
        breakpoint_indices.push(len - 1);
    }

    // Deduplicate (e.g., when len == 1, index 0 appears twice).
    breakpoint_indices.sort_unstable();
    breakpoint_indices.dedup();

    for &idx in &breakpoint_indices {
        stamp_last_content_block(&mut messages[idx]);
    }
}

/// Stamp cache_control on the last content block of a message.
fn stamp_last_content_block(message: &mut Value) {
    // Messages have shape: { "role": "...", "content": [...] }
    let content = match message.get_mut("content") {
        Some(Value::Array(arr)) if !arr.is_empty() => arr,
        _ => return,
    };

    let last = content.last_mut().unwrap();
    if let Value::Object(ref mut map) = last {
        map.insert(
            "cache_control".to_string(),
            json!({ "type": "ephemeral" }),
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn system_prompt_gets_cache_control() {
        let cached = cache_system_prompt("You are Epistemos.");
        let arr = cached.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["cache_control"]["type"], "ephemeral");
        assert_eq!(arr[0]["text"], "You are Epistemos.");
    }

    #[test]
    fn single_message_gets_one_breakpoint() {
        let mut messages = vec![json!({
            "role": "user",
            "content": [{ "type": "text", "text": "hello" }]
        })];
        apply_message_cache_breakpoints(&mut messages);
        assert_eq!(
            messages[0]["content"][0]["cache_control"]["type"],
            "ephemeral"
        );
    }

    #[test]
    fn multi_turn_messages_get_strategic_breakpoints() {
        let mut messages: Vec<Value> = (0..8)
            .map(|i| {
                json!({
                    "role": if i % 2 == 0 { "user" } else { "assistant" },
                    "content": [{ "type": "text", "text": format!("msg-{i}") }]
                })
            })
            .collect();

        apply_message_cache_breakpoints(&mut messages);

        // Breakpoint on first message (objective).
        assert_eq!(
            messages[0]["content"][0]["cache_control"]["type"],
            "ephemeral"
        );
        // Breakpoint on third-to-last (index 5).
        assert_eq!(
            messages[5]["content"][0]["cache_control"]["type"],
            "ephemeral"
        );
        // Breakpoint on last message.
        assert_eq!(
            messages[7]["content"][0]["cache_control"]["type"],
            "ephemeral"
        );
        // Middle messages should NOT have breakpoints.
        assert!(messages[3]["content"][0].get("cache_control").is_none());
    }

    #[test]
    fn two_messages_get_first_and_last() {
        let mut messages = vec![
            json!({ "role": "user", "content": [{ "type": "text", "text": "a" }] }),
            json!({ "role": "assistant", "content": [{ "type": "text", "text": "b" }] }),
        ];
        apply_message_cache_breakpoints(&mut messages);

        assert!(messages[0]["content"][0].get("cache_control").is_some());
        assert!(messages[1]["content"][0].get("cache_control").is_some());
    }

    #[test]
    fn empty_messages_does_not_panic() {
        let mut messages: Vec<Value> = vec![];
        apply_message_cache_breakpoints(&mut messages);
        assert!(messages.is_empty());
    }
}
