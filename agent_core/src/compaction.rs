// ── 4-Phase Context Compaction ──────────────────────────────────────────────
//
// Replaces the naive compact() method in claude.rs with a principled
// 4-phase pipeline derived from Hermes agent/context_compressor.py:
//
//   Phase 1: BOUNDARY PROTECTION — never discard first or last N messages
//   Phase 2: TOOL RESULT REPLACEMENT — replace verbose old tool results
//   Phase 3: STRUCTURED SUMMARIZATION — compress middle into structured format
//   Phase 4: ITERATIVE FOLDING — fold prior compaction summaries

use crate::types::{ContentBlock, Message, ToolResultContent, UserContent};

/// Maximum characters for a tool result placeholder excerpt.
const TOOL_RESULT_EXCERPT_LIMIT: usize = 200;

/// Maximum characters for the structured summary block.
const SUMMARY_BUDGET: usize = 8_000;

/// Marker prefix for compaction summaries so Phase 4 can detect them.
const COMPACTION_MARKER: &str = "[Compacted Context]\n";

/// Run the full 4-phase compaction pipeline.
///
/// Returns a new message vec with reduced token footprint while preserving
/// the semantic coherence needed for the agent to continue its work.
pub fn compact_messages(
    messages: &[Message],
    recent_window: usize,
    _max_context_chars: usize,
) -> Vec<Message> {
    let recent_window = recent_window.min(messages.len());

    // If the conversation is short enough, no compaction needed.
    if messages.len() <= recent_window + 2 {
        return messages.to_vec();
    }

    // ── Phase 1: Boundary Protection ───────────────────────────────────
    // Split into: [objective] [middle...] [recent_window...]
    let (first, rest) = messages.split_first().expect("messages is non-empty");
    let split_point = rest.len().saturating_sub(recent_window);
    let (middle, recent) = rest.split_at(split_point);

    // ── Phase 4 (early): Detect and extract existing compaction summaries
    let (prior_summary, compactable_middle) = extract_prior_summary(middle);

    // ── Phase 2: Tool Result Replacement ───────────────────────────────
    let tool_actions = extract_tool_actions(compactable_middle);

    // ── Phase 3: Structured Summarization ──────────────────────────────
    let summary = build_structured_summary(
        first,
        compactable_middle,
        &tool_actions,
        prior_summary.as_deref(),
    );

    // ── Reassemble ─────────────────────────────────────────────────────
    // [objective] [bridge assistant] [summary] [bridge assistant if needed] [recent...]
    let mut compacted = Vec::with_capacity(recent.len() + 4);
    compacted.push(first.clone());
    compacted.push(Message::assistant(vec![ContentBlock::Text {
        text: "[continuing from compacted context]".to_string(),
    }]));
    compacted.push(Message::user_text(summary));

    // If the first recent message is also User, insert an assistant bridge
    // to maintain strict alternation before fix_role_alternation runs.
    if matches!(recent.first(), Some(Message::User { .. })) {
        compacted.push(Message::assistant(vec![ContentBlock::Text {
            text: "[prior tool interactions compacted]".to_string(),
        }]));
    }

    // Sanitize recent messages: strip orphaned tool results that reference
    // tool_use blocks we just compacted away.
    let recent_tool_use_ids = collect_tool_use_ids(recent);
    for message in recent {
        compacted.push(sanitize_message(message, &recent_tool_use_ids));
    }

    // Ensure conversation alternation is valid (user, assistant, user, ...)
    fix_role_alternation(&mut compacted);

    compacted
}

/// Detect and extract a prior compaction summary from the middle section.
/// Scans the first few messages (up to 3) since bridge messages may precede the summary.
fn extract_prior_summary(middle: &[Message]) -> (Option<String>, &[Message]) {
    for (idx, message) in middle.iter().enumerate().take(3) {
        if let Message::User { content } = message {
            for item in content {
                if let UserContent::Text { text } = item {
                    if text.starts_with(COMPACTION_MARKER) {
                        return (Some(text.clone()), &middle[idx + 1..]);
                    }
                }
            }
        }
    }
    (None, middle)
}

/// Extract a structured record of tool calls and their (truncated) results.
struct ToolAction {
    name: String,
    excerpt: String,
    is_error: bool,
}

fn extract_tool_actions(messages: &[Message]) -> Vec<ToolAction> {
    let mut actions = Vec::new();
    let mut pending_tool_names: std::collections::HashMap<String, String> =
        std::collections::HashMap::new();

    for message in messages {
        match message {
            Message::Assistant { content } => {
                for block in content {
                    if let ContentBlock::ToolUse { id, name, .. } = block {
                        pending_tool_names.insert(id.clone(), name.clone());
                    }
                }
            }
            Message::User { content } => {
                for item in content {
                    if let UserContent::ToolResult(result) = item {
                        let name = pending_tool_names
                            .remove(&result.tool_use_id)
                            .unwrap_or_else(|| "unknown_tool".to_string());
                        let text = result
                            .content
                            .iter()
                            .filter_map(|c| match c {
                                ToolResultContent::Text { text } => Some(text.as_str()),
                                ToolResultContent::Image { .. } => None,
                            })
                            .collect::<Vec<_>>()
                            .join("");
                        let excerpt = truncate_excerpt(&text, TOOL_RESULT_EXCERPT_LIMIT);
                        actions.push(ToolAction {
                            name,
                            excerpt,
                            is_error: result.is_error,
                        });
                    }
                }
            }
        }
    }
    actions
}

/// Build the structured summary from the compactable middle section.
fn build_structured_summary(
    objective_message: &Message,
    middle: &[Message],
    tool_actions: &[ToolAction],
    prior_summary: Option<&str>,
) -> String {
    let mut summary = String::with_capacity(SUMMARY_BUDGET);
    summary.push_str(COMPACTION_MARKER);

    // Fold prior summary if present (Phase 4: Iterative Folding).
    if let Some(prior) = prior_summary {
        let prior_body = prior.strip_prefix(COMPACTION_MARKER).unwrap_or(prior);
        summary.push_str("## Prior Context\n");
        let truncated = truncate_excerpt(prior_body, SUMMARY_BUDGET / 2);
        summary.push_str(&truncated);
        summary.push_str("\n\n");
    }

    // Goal: extract from the first message.
    summary.push_str("## Goal\n");
    let goal_text = extract_text_from_message(objective_message);
    summary.push_str(&truncate_excerpt(&goal_text, 500));
    summary.push('\n');

    // Progress: extract key assistant text responses from the middle.
    let progress_lines = extract_progress(middle);
    if !progress_lines.is_empty() {
        summary.push_str("\n## Progress\n");
        for line in &progress_lines {
            if summary.len() + line.len() > SUMMARY_BUDGET - 1000 {
                summary.push_str("(earlier progress truncated)\n");
                break;
            }
            summary.push_str("- ");
            summary.push_str(line);
            summary.push('\n');
        }
    }

    // Tool Actions: compact record of what tools were called.
    if !tool_actions.is_empty() {
        summary.push_str("\n## Tool Actions\n");
        for action in tool_actions {
            if summary.len() > SUMMARY_BUDGET - 200 {
                summary.push_str("(earlier tool actions truncated)\n");
                break;
            }
            let status = if action.is_error { "ERROR" } else { "ok" };
            summary.push_str(&format!(
                "- {}(…) → [{}] {}\n",
                action.name, status, action.excerpt
            ));
        }
    }

    // Decisions: extract from thinking blocks.
    let decisions = extract_decisions(middle);
    if !decisions.is_empty() {
        summary.push_str("\n## Key Decisions\n");
        for decision in &decisions {
            if summary.len() > SUMMARY_BUDGET - 100 {
                break;
            }
            summary.push_str("- ");
            summary.push_str(decision);
            summary.push('\n');
        }
    }

    summary
}

/// Extract plain text from any message type.
fn extract_text_from_message(message: &Message) -> String {
    match message {
        Message::User { content } => content
            .iter()
            .filter_map(|c| match c {
                UserContent::Text { text } => Some(text.as_str()),
                _ => None,
            })
            .collect::<Vec<_>>()
            .join(" "),
        Message::Assistant { content } => content
            .iter()
            .filter_map(|c| match c {
                ContentBlock::Text { text } => Some(text.as_str()),
                _ => None,
            })
            .collect::<Vec<_>>()
            .join(" "),
    }
}

/// Extract progress lines from assistant text responses.
fn extract_progress(messages: &[Message]) -> Vec<String> {
    let mut lines = Vec::new();
    for message in messages {
        if let Message::Assistant { content } = message {
            for block in content {
                if let ContentBlock::Text { text } = block {
                    let truncated = truncate_excerpt(text, 200);
                    if !truncated.trim().is_empty() {
                        lines.push(truncated);
                    }
                }
            }
        }
    }
    lines
}

/// Extract key decisions from thinking blocks.
fn extract_decisions(messages: &[Message]) -> Vec<String> {
    let mut decisions = Vec::new();
    for message in messages {
        if let Message::Assistant { content } = message {
            for block in content {
                if let ContentBlock::Thinking { thinking, .. } = block {
                    for line in thinking.lines() {
                        let trimmed = line.trim();
                        if (trimmed.starts_with("I should")
                            || trimmed.starts_with("I'll ")
                            || trimmed.starts_with("Decision:")
                            || trimmed.starts_with("Plan:")
                            || trimmed.starts_with("Strategy:"))
                            && trimmed.len() > 10
                        {
                            decisions.push(truncate_excerpt(trimmed, 150));
                        }
                    }
                }
            }
        }
    }
    decisions.truncate(10);
    decisions
}

/// Collect all tool_use IDs from a message slice.
fn collect_tool_use_ids(messages: &[Message]) -> std::collections::HashSet<String> {
    let mut ids = std::collections::HashSet::new();
    for message in messages {
        if let Message::Assistant { content } = message {
            for block in content {
                if let ContentBlock::ToolUse { id, .. } = block {
                    ids.insert(id.clone());
                }
            }
        }
    }
    ids
}

/// Remove orphaned tool results from retained history after compaction.
fn sanitize_message(
    message: &Message,
    valid_tool_use_ids: &std::collections::HashSet<String>,
) -> Message {
    match message {
        Message::User { content } => {
            let cleaned: Vec<UserContent> = content
                .iter()
                .filter(|item| match item {
                    UserContent::ToolResult(result) => {
                        valid_tool_use_ids.contains(&result.tool_use_id)
                    }
                    _ => true,
                })
                .cloned()
                .collect();

            if cleaned.is_empty() {
                Message::user_text("[compacted tool results]")
            } else {
                Message::User { content: cleaned }
            }
        }
        Message::Assistant { content } => Message::assistant(content.clone()),
    }
}

/// Fix role alternation by merging consecutive same-role messages.
pub fn fix_role_alternation(messages: &mut Vec<Message>) {
    if messages.len() < 2 {
        return;
    }

    let mut i = 0;
    while i + 1 < messages.len() {
        let same_role = match (&messages[i], &messages[i + 1]) {
            (Message::User { .. }, Message::User { .. }) => true,
            (Message::Assistant { .. }, Message::Assistant { .. }) => true,
            _ => false,
        };

        if same_role {
            let second = messages.remove(i + 1);
            match (&mut messages[i], second) {
                (Message::User { content: first }, Message::User { content: second }) => {
                    first.extend(second);
                }
                (Message::Assistant { content: first }, Message::Assistant { content: second }) => {
                    first.extend(second);
                }
                _ => unreachable!(),
            }
        } else {
            i += 1;
        }
    }
}

/// Truncate text to a character limit, appending "…" if truncated.
fn truncate_excerpt(text: &str, max_chars: usize) -> String {
    let count = text.chars().count();
    if count <= max_chars {
        return text.to_string();
    }
    let mut truncated: String = text.chars().take(max_chars).collect();
    truncated.push('…');
    truncated
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{ContentBlock, Message, ToolResult, UserContent};

    fn make_test_conversation(turn_count: usize) -> Vec<Message> {
        let mut messages = vec![Message::user_text("Research quantum computing advances")];

        for i in 0..turn_count {
            let tool_id = format!("tool-{i}");
            messages.push(Message::assistant(vec![
                ContentBlock::Thinking {
                    thinking: format!(
                        "I should search for topic {i}. Decision: use vault_search first."
                    ),
                    signature: format!("sig-{i}"),
                },
                ContentBlock::Text {
                    text: format!("Let me look into aspect {i} of this topic."),
                },
                ContentBlock::ToolUse {
                    id: tool_id.clone(),
                    name: "vault_search".to_string(),
                    input: serde_json::json!({"query": format!("quantum computing {i}")}),
                },
            ]));

            messages.push(Message::User {
                content: vec![UserContent::ToolResult(ToolResult::text(
                    tool_id,
                    format!(
                        "Found {} results about quantum computing topic {i}. \
                         Here is a very long result that goes on and on with lots of detail \
                         about various aspects of the research...",
                        i * 10 + 5
                    )
                    .repeat(3),
                    false,
                ))],
            });
        }

        messages.push(Message::assistant(vec![ContentBlock::Text {
            text: "Based on my research, here are the key findings...".to_string(),
        }]));

        messages
    }

    #[test]
    fn short_conversation_not_compacted() {
        let messages = make_test_conversation(2);
        let compacted = compact_messages(&messages, 8, 16_384);
        assert_eq!(compacted.len(), messages.len());
    }

    #[test]
    fn long_conversation_compacted_preserves_boundaries() {
        let messages = make_test_conversation(10);
        let original_len = messages.len();
        let compacted = compact_messages(&messages, 8, 16_384);

        assert!(compacted.len() < original_len);

        let first_text = extract_text_from_message(&compacted[0]);
        assert!(first_text.contains("quantum computing"));

        let last = &compacted[compacted.len() - 1];
        let last_text = extract_text_from_message(last);
        assert!(last_text.contains("key findings"));
    }

    #[test]
    fn compaction_summary_has_structured_sections() {
        let messages = make_test_conversation(8);
        let compacted = compact_messages(&messages, 4, 16_384);

        // Find the summary message by content (index varies due to bridge messages).
        let summary_text = compacted
            .iter()
            .map(|m| extract_text_from_message(m))
            .find(|t| t.contains(COMPACTION_MARKER))
            .expect("summary message with compaction marker not found");
        assert!(summary_text.contains("## Goal"));
        assert!(summary_text.contains("## Tool Actions"));
        assert!(summary_text.contains("vault_search"));
    }

    #[test]
    fn iterative_folding_merges_prior_summaries() {
        let messages = make_test_conversation(8);
        let once_compacted = compact_messages(&messages, 4, 16_384);

        let mut extended = once_compacted;
        for i in 20..24 {
            let tool_id = format!("tool-{i}");
            extended.push(Message::assistant(vec![
                ContentBlock::Text {
                    text: format!("Continuing research on aspect {i}"),
                },
                ContentBlock::ToolUse {
                    id: tool_id.clone(),
                    name: "vault_search".to_string(),
                    input: serde_json::json!({"query": "more research"}),
                },
            ]));
            extended.push(Message::User {
                content: vec![UserContent::ToolResult(ToolResult::text(
                    tool_id,
                    "More results here".to_string(),
                    false,
                ))],
            });
        }

        let twice_compacted = compact_messages(&extended, 4, 16_384);
        // Find summary by content marker.
        let summary_text = twice_compacted
            .iter()
            .map(|m| extract_text_from_message(m))
            .find(|t| t.contains(COMPACTION_MARKER))
            .expect("summary message with compaction marker not found");
        assert!(summary_text.contains("## Prior Context"));
    }

    #[test]
    fn compaction_summary_omits_thinking_signatures() {
        let messages = make_test_conversation(8);
        let compacted = compact_messages(&messages, 4, 16_384);

        let summary_text = compacted
            .iter()
            .map(|m| extract_text_from_message(m))
            .find(|t| t.contains(COMPACTION_MARKER))
            .expect("summary message with compaction marker not found");
        assert!(!summary_text.contains("sig-"));
    }

    #[test]
    fn recent_thinking_blocks_survive_compaction() {
        let messages = make_test_conversation(8);
        let compacted = compact_messages(&messages, 4, 16_384);

        let retained_thinking = compacted.iter().rev().find_map(|message| match message {
            Message::Assistant { content } => content.iter().find_map(|block| match block {
                ContentBlock::Thinking { thinking, .. } => Some(thinking.as_str()),
                ContentBlock::RedactedThinking { .. } => None,
                _ => None,
            }),
            _ => None,
        });

        assert_eq!(
            retained_thinking,
            Some("I should search for topic 7. Decision: use vault_search first.")
        );
    }

    #[test]
    fn role_alternation_maintained() {
        let messages = make_test_conversation(8);
        let compacted = compact_messages(&messages, 4, 16_384);

        for window in compacted.windows(2) {
            let same_role = match (&window[0], &window[1]) {
                (Message::User { .. }, Message::User { .. }) => true,
                (Message::Assistant { .. }, Message::Assistant { .. }) => true,
                _ => false,
            };
            assert!(
                !same_role,
                "Consecutive same-role messages found after compaction"
            );
        }
    }

    #[test]
    fn truncate_excerpt_respects_limit() {
        let text = "a".repeat(1000);
        let truncated = truncate_excerpt(&text, 100);
        assert!(truncated.chars().count() <= 101);
        assert!(truncated.ends_with('…'));
    }

    #[test]
    fn truncate_excerpt_preserves_short_text() {
        let text = "hello";
        let truncated = truncate_excerpt(text, 100);
        assert_eq!(truncated, "hello");
    }
}
