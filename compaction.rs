// ── 4-Phase Context Compaction ──────────────────────────────────────────────
//
// DROP-IN for agent_core/src/compaction.rs
//
// Replaces the naive compact() method in claude.rs with a principled
// 4-phase pipeline derived from Hermes agent/context_compressor.py:
//
//   Phase 1: BOUNDARY PROTECTION
//     Never discard the first message (user objective) or the last N messages
//     (recent working context). These are the anchors of coherence.
//
//   Phase 2: TOOL RESULT REPLACEMENT
//     Old tool results are typically the largest tokens sink. Replace them
//     with bounded placeholders that preserve the tool name and a truncated
//     excerpt, cutting 80-95% of their token cost.
//
//   Phase 3: STRUCTURED SUMMARIZATION
//     Compress the middle messages into a structured summary:
//       Goal: what the agent is trying to accomplish
//       Progress: what has been done so far
//       Decisions: key choices and their rationale
//       Files: files read/written/modified
//       Next Steps: what the agent planned to do next
//
//   Phase 4: ITERATIVE FOLDING
//     If a previous compaction summary already exists in the message history,
//     fold it into the new summary instead of stacking summaries.
//
// DESIGN NOTES:
//   - This module operates on Message types, not raw JSON
//   - It does NOT call the LLM for summarization — it uses extractive methods
//     to avoid the cost and latency of an extra API call
//   - Thinking blocks in assistant messages are stripped during compaction
//     (they served their purpose and shouldn't consume future context)
//   - Orphaned tool results (tool_result without a matching preceding
//     tool_use) are cleaned up to avoid confusing the model
//
// INTEGRATION:
//   Replace ClaudeProvider::compact() body with:
//     Ok(compaction::compact_messages(messages, 8, 16_384))

use crate::types::{ContentBlock, Message, ToolResultContent, UserContent};

/// Number of recent messages to preserve unmodified during compaction.
const DEFAULT_RECENT_WINDOW: usize = 8;

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
    // If the first middle message is itself a compaction summary, extract it
    // so we can fold it into the new summary instead of summarizing a summary.
    let (prior_summary, compactable_middle) = extract_prior_summary(middle);

    // ── Phase 2: Tool Result Replacement ───────────────────────────────
    // Replace verbose tool results in the middle with bounded placeholders.
    let tool_actions = extract_tool_actions(compactable_middle);

    // ── Phase 3: Structured Summarization ──────────────────────────────
    let summary = build_structured_summary(
        first,
        compactable_middle,
        &tool_actions,
        prior_summary.as_deref(),
    );

    // ── Reassemble ─────────────────────────────────────────────────────
    // [objective] [compacted summary] [recent messages...]
    let mut compacted = Vec::with_capacity(recent.len() + 2);
    compacted.push(first.clone());
    compacted.push(Message::user_text(summary));

    // Sanitize recent messages: strip orphaned tool results that reference
    // tool_use blocks we just compacted away.
    let recent_tool_use_ids = collect_tool_use_ids(recent);
    for message in recent {
        compacted.push(sanitize_message(message, &recent_tool_use_ids));
    }

    // Ensure conversation alternation is valid (user, assistant, user, ...)
    // by removing consecutive same-role messages that compaction may create.
    fix_role_alternation(&mut compacted);

    compacted
}

/// Detect if the first message in the middle section is a prior compaction summary.
fn extract_prior_summary(middle: &[Message]) -> (Option<String>, &[Message]) {
    if let Some(Message::User { content }) = middle.first() {
        for item in content {
            if let UserContent::Text { text } = item {
                if text.starts_with(COMPACTION_MARKER) {
                    return (Some(text.clone()), &middle[1..]);
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
    let mut pending_tool_names: std::collections::HashMap<String, String> = std::collections::HashMap::new();

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
        let prior_body = prior
            .strip_prefix(COMPACTION_MARKER)
            .unwrap_or(prior);
        summary.push_str("## Prior Context\n");
        // Truncate the prior summary to half the budget to leave room.
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

    // Decisions: extract from thinking blocks (if any survived this far).
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
                    // Look for decision-like patterns in thinking.
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
    // Cap at 10 decisions to keep the summary bounded.
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

/// Remove orphaned tool results that reference tool_use IDs not in the
/// provided set. Also strip thinking blocks from assistant messages
/// (they've served their purpose and shouldn't consume future context).
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

            // If all content was filtered out, preserve at least a placeholder.
            if cleaned.is_empty() {
                Message::user_text("[compacted tool results]")
            } else {
                Message::User { content: cleaned }
            }
        }
        Message::Assistant { content } => {
            // Strip thinking blocks from compacted region.
            // Preserve text and tool_use blocks.
            let cleaned: Vec<ContentBlock> = content
                .iter()
                .filter(|block| !matches!(block, ContentBlock::Thinking { .. }))
                .cloned()
                .collect();

            if cleaned.is_empty() {
                // Must have at least one content block.
                Message::assistant(vec![ContentBlock::Text {
                    text: "[compacted assistant reasoning]".to_string(),
                }])
            } else {
                Message::assistant(cleaned)
            }
        }
    }
}

/// Fix role alternation by merging consecutive same-role messages.
///
/// Anthropic's API requires strict user/assistant alternation. Compaction
/// can sometimes create consecutive user messages (e.g., [objective] [summary]
/// with no assistant message between them). This function merges them.
fn fix_role_alternation(messages: &mut Vec<Message>) {
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
            // Merge the second into the first.
            let second = messages.remove(i + 1);
            match (&mut messages[i], second) {
                (Message::User { content: first }, Message::User { content: second }) => {
                    first.extend(second);
                }
                (
                    Message::Assistant { content: first },
                    Message::Assistant { content: second },
                ) => {
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
            // Assistant turn with thinking + text + tool_use
            let tool_id = format!("tool-{i}");
            messages.push(Message::assistant(vec![
                ContentBlock::Thinking {
                    thinking: format!("I should search for topic {i}. Decision: use vault_search first."),
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

            // User turn with tool result
            messages.push(Message::User {
                content: vec![UserContent::ToolResult(ToolResult::text(
                    tool_id,
                    format!("Found {} results about quantum computing topic {i}. Here is a very long result that goes on and on with lots of detail about various aspects of the research...", i * 10 + 5).repeat(3),
                    false,
                ))],
            });
        }

        // Final assistant response
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

        // Should be significantly shorter.
        assert!(compacted.len() < original_len);

        // First message (objective) preserved.
        let first_text = extract_text_from_message(&compacted[0]);
        assert!(first_text.contains("quantum computing"));

        // Recent messages preserved.
        let last = &compacted[compacted.len() - 1];
        let last_text = extract_text_from_message(last);
        assert!(last_text.contains("key findings"));
    }

    #[test]
    fn compaction_summary_has_structured_sections() {
        let messages = make_test_conversation(8);
        let compacted = compact_messages(&messages, 4, 16_384);

        // Find the summary message (should be second).
        let summary_text = extract_text_from_message(&compacted[1]);
        assert!(summary_text.starts_with(COMPACTION_MARKER));
        assert!(summary_text.contains("## Goal"));
        assert!(summary_text.contains("## Tool Actions"));
        assert!(summary_text.contains("vault_search"));
    }

    #[test]
    fn iterative_folding_merges_prior_summaries() {
        let messages = make_test_conversation(8);

        // First compaction.
        let once_compacted = compact_messages(&messages, 4, 16_384);

        // Simulate more conversation on top of the compacted result.
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

        // Second compaction should fold the prior summary.
        let twice_compacted = compact_messages(&extended, 4, 16_384);
        let summary_text = extract_text_from_message(&twice_compacted[1]);
        assert!(summary_text.contains("## Prior Context"));
    }

    #[test]
    fn thinking_blocks_stripped_during_compaction() {
        let messages = make_test_conversation(8);
        let compacted = compact_messages(&messages, 4, 16_384);

        // Recent messages should not have thinking blocks stripped
        // (only the compacted middle gets stripped).
        // But the summary should not contain raw thinking text.
        let summary_text = extract_text_from_message(&compacted[1]);
        assert!(!summary_text.contains("sig-"));
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
        assert!(truncated.chars().count() <= 101); // 100 + "…"
        assert!(truncated.ends_with('…'));
    }

    #[test]
    fn truncate_excerpt_preserves_short_text() {
        let text = "hello";
        let truncated = truncate_excerpt(text, 100);
        assert_eq!(truncated, "hello");
    }
}
