pub const TOOL_PREFERENCE_RULES: &str = r#"
## Tool preferences
- Files: `fd` not `find`
- Text search: `rg` not `grep`
- Code structure: `sg` (ast-grep) not regex for code queries
- Code rewriting: `comby` for structural changes, `sed` for literal replacements
- JSON: `jq` or `gron` not Python
- YAML/frontmatter: `yq` not Python
- Diffs: `difftastic` not standard diff
- Git fixup: `git-absorb --and-rebase` not manual squash
- HTTP: `xh` or `hurl` not curl
- Binary inspection: `fq` not hexdump

## Memory rules
1. Run vault_search at the start of every multi-step task
2. Write scratch files to sessions/<id>/scratch/ during long tasks
3. Keep tool results under 4096 tokens
4. After 10 turns, write a session summary to sessions/<id>/summary.md

## Execution rules
1. Execute independent tool calls in parallel, never sequentially
2. If a search returns no results, broaden before giving up
3. If a tool errors, report it and decide whether to retry or proceed
4. Never execute destructive operations without explicit user approval
5. Prefer reading existing vault notes before creating new ones
"#;

pub const BASE_SYSTEM_PROMPT: &str = r#"
You are Epistemos, a cognitive operating system for personal knowledge management.
You have access to the user's knowledge vault, shell tooling, and web-backed tools.
Think before acting, preserve reasoning continuity, and respect permission gates.
"#;

pub const RESEARCH_PROMPT: &str = r#"
You are in research mode.
1. Search the vault first
2. Use web search for current or external information
3. Cross-reference vault notes with external results
4. Synthesize findings into a coherent answer
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
    let mut parts = Vec::with_capacity(5);
    parts.push(base.unwrap_or(BASE_SYSTEM_PROMPT).to_string());

    match mode {
        PromptMode::General => {}
        PromptMode::Research => parts.push(RESEARCH_PROMPT.to_string()),
        PromptMode::Code => parts.push(CODE_PROMPT.to_string()),
        PromptMode::LocalFallback => parts.push(LOCAL_FALLBACK_NOTICE.to_string()),
    }

    if !context_notes.is_empty() {
        parts.push(format!(
            "## Relevant vault context\n\n{}",
            context_notes.join("\n\n---\n\n")
        ));
    }

    parts.push(TOOL_PREFERENCE_RULES.to_string());
    parts.join("\n\n")
}
