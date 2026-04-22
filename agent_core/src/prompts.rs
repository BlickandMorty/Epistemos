/// Compact tool rules — only injected for Code mode. ~100 tokens vs the old ~400.
pub const TOOL_PREFERENCE_RULES: &str = r#"
## Tool Rules
- Use find_symbol/get_function_source before grep/cat
- Prefer rg over grep, fd over find
- Keep tool results under 4096 tokens
- Execute independent tool calls in parallel
- Never destructive operations without user approval
"#;

pub const BASE_SYSTEM_PROMPT: &str = r#"
You are Epistemos, a cognitive operating system for personal knowledge management.
You have access to the user's knowledge vault, shell tooling, and web-backed tools.
Think before acting, preserve reasoning continuity, and respect permission gates.
For vault notes, never guess a filesystem path from a title. Use vault_search to find the note, then vault_read with the returned vault-relative path. Use read_file only for an explicit filesystem path the user provided or a path another tool returned.
Keep provenance explicit: attached notes/files/chats are not the same thing as vault material you had to go find.
If the user asks you to find, open, summarize, copy, or edit a vault note, only say you found or read it after the vault lookup actually succeeded.
If a required tool lookup is blocked, denied, or unreadable, say that plainly and stop instead of pretending the lookup succeeded.
"#;

pub const RESEARCH_PROMPT: &str = r#"
You are in research mode.
1. Use web search first for current or external information.
2. Use vault notes, attachments, or local files only when the user explicitly references them or when relevant local context is already attached.
3. Never guess note titles or file paths. If a local lookup fails, try a better external research step or ask a concise clarification.
4. Cross-reference local context with external results only when that local context is genuinely relevant.
"#;

pub const CODE_PROMPT: &str = r#"
You are in code mode.
1. Understand the codebase structure before editing
2. Read relevant files before changing them
3. Make minimal, targeted changes
4. Verify changes with the right compiler, linter, or tests
"#;

pub const LOCAL_FALLBACK_NOTICE: &str = r#"
This task is being handled by a local model for speed and privacy.
If quality is insufficient, the system may escalate to a cloud model.
"#;

#[derive(Debug, Clone, Copy)]
pub enum PromptMode {
    General,
    Research,
    Code,
    LocalFallback,
}

pub fn build_system_prompt(
    base: Option<&str>,
    context_notes: &[String],
    mode: PromptMode,
) -> String {
    build_system_prompt_with_index(base, context_notes, mode, None)
}

/// Build system prompt with optional knowledge index injected at prefix-cache position.
/// The knowledge index is a compact entity table that enables entity resolution by lookup.
pub fn build_system_prompt_with_index(
    base: Option<&str>,
    context_notes: &[String],
    mode: PromptMode,
    knowledge_index: Option<&str>,
) -> String {
    let mut parts = Vec::with_capacity(6);

    // Knowledge index goes FIRST — prefix-cache position for maximum attention
    if let Some(index) = knowledge_index {
        if !index.is_empty() {
            parts.push(index.to_string());
        }
    }

    parts.push(base.unwrap_or(BASE_SYSTEM_PROMPT).to_string());

    match mode {
        PromptMode::General => {}
        PromptMode::Research => parts.push(RESEARCH_PROMPT.to_string()),
        PromptMode::Code => {
            parts.push(CODE_PROMPT.to_string());
            // Tool rules only injected for code tasks — not for general/research chat
            parts.push(TOOL_PREFERENCE_RULES.to_string());
        }
        PromptMode::LocalFallback => parts.push(LOCAL_FALLBACK_NOTICE.to_string()),
    }

    if !context_notes.is_empty() {
        parts.push(format!(
            "## Relevant vault context\n\n{}",
            context_notes.join("\n\n---\n\n")
        ));
    }

    parts.join("\n\n")
}

#[cfg(test)]
mod tests {
    use super::{build_system_prompt_with_index, PromptMode};

    #[test]
    fn base_prompt_forces_note_lookups_through_vault_tools() {
        let prompt = build_system_prompt_with_index(None, &[], PromptMode::General, None);
        assert!(prompt.contains("never guess a filesystem path from a title"));
        assert!(prompt.contains("Use vault_search to find the note"));
        assert!(prompt.contains("vault_read"));
        assert!(prompt
            .contains("only say you found or read it after the vault lookup actually succeeded"));
        assert!(prompt.contains("If a required tool lookup is blocked, denied, or unreadable"));
    }

    #[test]
    fn research_prompt_prioritizes_external_research_before_vault_lookup() {
        let prompt = build_system_prompt_with_index(None, &[], PromptMode::Research, None);
        assert!(prompt.contains("Use web search first"));
        assert!(prompt.contains("Never guess note titles or file paths"));
        assert!(!prompt.contains("Search the vault first"));
    }
}
