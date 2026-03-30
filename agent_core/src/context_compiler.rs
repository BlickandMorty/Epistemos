use std::fs;
use std::path::{Path, PathBuf};

use crate::prompts::{build_system_prompt, PromptMode, TOOL_PREFERENCE_RULES};
use crate::vault_registry::VaultIdentity;

const DEFAULT_MAX_CONTEXT_CHARS: usize = 24_000;
const DEFAULT_RAG_LIMIT: usize = 3;
const DEFAULT_EXAMPLE_LIMIT: usize = 3;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompiledContext {
    pub system_prompt: String,
    pub tools: Vec<String>,
    pub skills: Vec<String>,
    pub memory: Vec<String>,
    pub few_shot_examples: Vec<String>,
    pub rag_context: Vec<String>,
    pub conversation_history: Vec<String>,
    pub current_user_message: String,
    pub cache_breakpoints: Vec<usize>,
}

impl CompiledContext {
    pub fn assembled_prompt(&self) -> String {
        let mut sections = Vec::with_capacity(8);
        sections.push(format!("## Tool Definitions\n{}", self.tools.join("\n")));
        sections.push(format!("## System Prompt\n{}", self.system_prompt));

        if !self.skills.is_empty() {
            sections.push(format!("## Skill Context\n{}", self.skills.join("\n\n")));
        }
        if !self.memory.is_empty() {
            sections.push(format!("## Memory Context\n{}", self.memory.join("\n\n")));
        }
        if !self.few_shot_examples.is_empty() {
            sections.push(format!(
                "## Few-Shot Examples\n{}",
                self.few_shot_examples.join("\n\n---\n\n")
            ));
        }
        if !self.rag_context.is_empty() {
            sections.push(format!("## RAG Context\n{}", self.rag_context.join("\n\n")));
        }
        if !self.conversation_history.is_empty() {
            sections.push(format!(
                "## Conversation History\n{}",
                self.conversation_history.join("\n\n")
            ));
        }
        sections.push(format!("## User Message\n{}", self.current_user_message));
        sections.join("\n\n")
    }
}

#[derive(Debug, Clone)]
pub struct ContextCompiler {
    vault_identity: VaultIdentity,
    max_context_chars: usize,
}

#[derive(Debug, thiserror::Error)]
pub enum ContextCompilerError {
    #[error("vault path does not exist: {0}")]
    MissingVault(PathBuf),
    #[error("failed to read context file {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
}

impl ContextCompiler {
    pub fn new(vault_identity: VaultIdentity) -> Self {
        Self {
            vault_identity,
            max_context_chars: DEFAULT_MAX_CONTEXT_CHARS,
        }
    }

    pub fn with_max_context_chars(mut self, max_context_chars: usize) -> Self {
        self.max_context_chars = max_context_chars.max(1_024);
        self
    }

    pub fn compile(
        &self,
        query: &str,
        model: &str,
        vault_path: &Path,
    ) -> Result<CompiledContext, ContextCompilerError> {
        if !vault_path.exists() {
            return Err(ContextCompilerError::MissingVault(vault_path.to_path_buf()));
        }

        let tools = vec![TOOL_PREFERENCE_RULES.trim().to_string()];
        let system_prompt = load_optional_file(vault_path.join("SYSTEM.md"))?
            .filter(|content| !content.trim().is_empty())
            .unwrap_or_else(|| build_system_prompt(None, &[], PromptMode::General));
        let skills = load_skill_summaries(vault_path)?;
        let memory = split_sections(
            &load_optional_file(vault_path.join("MEMORY.md"))?.unwrap_or_default(),
            12,
        );
        let few_shot_examples = load_examples(vault_path, DEFAULT_EXAMPLE_LIMIT)?;
        let rag_context = load_rag_context(vault_path, query, DEFAULT_RAG_LIMIT)?;
        let conversation_history = split_sections(
            &load_optional_file(vault_path.join("CONVERSATION.md"))?.unwrap_or_default(),
            10,
        );
        let current_user_message = format!(
            "[vault:{} | model:{}]\n{}",
            display_identity(&self.vault_identity),
            model,
            query.trim()
        );

        let mut compiled = CompiledContext {
            system_prompt,
            tools,
            skills,
            memory,
            few_shot_examples,
            rag_context,
            conversation_history,
            current_user_message,
            cache_breakpoints: vec![4, 5],
        };

        self.compress_if_needed(&mut compiled);
        compiled.cache_breakpoints = cache_breakpoints_for(&compiled);
        Ok(compiled)
    }

    fn compress_if_needed(&self, compiled: &mut CompiledContext) {
        if compiled.assembled_prompt().len() <= self.max_context_chars {
            return;
        }

        trim_whitespace(compiled);
        if compiled.assembled_prompt().len() <= self.max_context_chars {
            return;
        }

        summarize_conversation(compiled);
        if compiled.assembled_prompt().len() <= self.max_context_chars {
            return;
        }

        reduce_memory(compiled);
        if compiled.assembled_prompt().len() <= self.max_context_chars {
            return;
        }

        reduce_examples(compiled);
        if compiled.assembled_prompt().len() <= self.max_context_chars {
            return;
        }

        hard_cap(compiled, self.max_context_chars);
    }
}

fn load_optional_file(path: PathBuf) -> Result<Option<String>, ContextCompilerError> {
    if !path.exists() {
        return Ok(None);
    }
    fs::read_to_string(&path)
        .map(Some)
        .map_err(|source| ContextCompilerError::Io { path, source })
}

fn load_skill_summaries(vault_path: &Path) -> Result<Vec<String>, ContextCompilerError> {
    let skills_dir = vault_path.join("skills");
    if !skills_dir.exists() {
        return Ok(Vec::new());
    }

    let mut skill_paths = fs::read_dir(&skills_dir)
        .map_err(|source| ContextCompilerError::Io {
            path: skills_dir.clone(),
            source,
        })?
        .filter_map(|entry| entry.ok().map(|item| item.path()))
        .filter(|path| path.extension().and_then(|ext| ext.to_str()) == Some("md"))
        .collect::<Vec<_>>();
    skill_paths.sort();

    skill_paths
        .into_iter()
        .map(|path| {
            let content = fs::read_to_string(&path)
                .map_err(|source| ContextCompilerError::Io { path: path.clone(), source })?;
            let summary = content
                .lines()
                .filter(|line| !line.trim().is_empty())
                .take(6)
                .collect::<Vec<_>>()
                .join("\n");
            Ok(summary)
        })
        .collect()
}

fn load_examples(vault_path: &Path, limit: usize) -> Result<Vec<String>, ContextCompilerError> {
    let examples_path = vault_path.join("EXAMPLES.md");
    let content = load_optional_file(examples_path)?.unwrap_or_default();
    let mut examples = split_sections(&content, limit);
    if examples.len() > 1 {
        examples.sort_by_key(|example| example.len());
    }
    Ok(examples)
}

fn load_rag_context(
    vault_path: &Path,
    query: &str,
    limit: usize,
) -> Result<Vec<String>, ContextCompilerError> {
    let query_terms = query
        .split_whitespace()
        .map(|term| term.to_lowercase())
        .collect::<Vec<_>>();

    let mut ranked = Vec::new();
    for path in markdown_files(vault_path)? {
        let is_special = matches!(
            path.file_name().and_then(|name| name.to_str()),
            Some("SYSTEM.md" | "MEMORY.md" | "EXAMPLES.md" | "CONVERSATION.md")
        );
        if is_special {
            continue;
        }

        let content = fs::read_to_string(&path).map_err(|source| ContextCompilerError::Io {
            path: path.clone(),
            source,
        })?;
        let lowered = content.to_lowercase();
        let score = query_terms
            .iter()
            .filter(|term| lowered.contains(term.as_str()))
            .count();
        if score == 0 {
            continue;
        }

        let relative = path
            .strip_prefix(vault_path)
            .unwrap_or(&path)
            .display()
            .to_string();
        ranked.push((score, relative, excerpt(&content, 400)));
    }

    ranked.sort_by(|left, right| right.0.cmp(&left.0).then_with(|| left.1.cmp(&right.1)));
    Ok(ranked
        .into_iter()
        .take(limit)
        .map(|(_, relative, summary)| format!("## {relative}\n{summary}"))
        .collect())
}

fn markdown_files(root: &Path) -> Result<Vec<PathBuf>, ContextCompilerError> {
    let mut files = Vec::new();
    let mut pending = vec![root.to_path_buf()];

    while let Some(dir) = pending.pop() {
        for entry in fs::read_dir(&dir).map_err(|source| ContextCompilerError::Io {
            path: dir.clone(),
            source,
        })? {
            let entry = entry.map_err(|source| ContextCompilerError::Io {
                path: dir.clone(),
                source,
            })?;
            let path = entry.path();
            if path.is_dir() {
                pending.push(path);
            } else if path.extension().and_then(|ext| ext.to_str()) == Some("md") {
                files.push(path);
            }
        }
    }

    files.sort();
    Ok(files)
}

fn split_sections(content: &str, limit: usize) -> Vec<String> {
    content
        .split("\n---\n")
        .flat_map(|section| {
            if section.contains("\n## ") {
                section
                    .split("\n## ")
                    .enumerate()
                    .map(|(index, chunk)| {
                        if index == 0 {
                            chunk.to_string()
                        } else {
                            format!("## {chunk}")
                        }
                    })
                    .collect::<Vec<_>>()
            } else {
                vec![section.to_string()]
            }
        })
        .map(|section| section.trim().to_string())
        .filter(|section| !section.is_empty())
        .take(limit)
        .collect()
}

fn excerpt(content: &str, max_chars: usize) -> String {
    let trimmed = content.trim();
    if trimmed.chars().count() <= max_chars {
        trimmed.to_string()
    } else {
        let candidate = trimmed.chars().take(max_chars).collect::<String>();
        let boundary = candidate
            .rfind(char::is_whitespace)
            .unwrap_or(candidate.len());
        format!("{}…", &candidate[..boundary])
    }
}

fn trim_whitespace(compiled: &mut CompiledContext) {
    compiled.system_prompt = compiled.system_prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    for section in [
        &mut compiled.tools,
        &mut compiled.skills,
        &mut compiled.memory,
        &mut compiled.few_shot_examples,
        &mut compiled.rag_context,
        &mut compiled.conversation_history,
    ] {
        for entry in section.iter_mut() {
            *entry = entry.split_whitespace().collect::<Vec<_>>().join(" ");
        }
    }
    compiled.current_user_message = compiled
        .current_user_message
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
}

fn summarize_conversation(compiled: &mut CompiledContext) {
    if compiled.conversation_history.len() <= 2 {
        return;
    }
    let first = compiled.conversation_history.first().cloned().unwrap_or_default();
    let last = compiled.conversation_history.last().cloned().unwrap_or_default();
    compiled.conversation_history = vec![
        first,
        format!(
            "[summary of {} earlier turns omitted for budget]",
            compiled.conversation_history.len().saturating_sub(2)
        ),
        last,
    ];
}

fn reduce_memory(compiled: &mut CompiledContext) {
    if compiled.memory.len() <= 3 {
        return;
    }
    let original = compiled.memory.clone();
    compiled.memory.retain(|entry| {
        entry.contains("[strength:high]") || entry.contains("[strength:critical]")
    });
    if compiled.memory.is_empty() {
        compiled.memory = original
            .iter()
            .take(3)
            .cloned()
            .collect::<Vec<_>>();
    }
}

fn reduce_examples(compiled: &mut CompiledContext) {
    if compiled.few_shot_examples.len() > 1 {
        compiled.few_shot_examples.truncate(1);
    }
}

fn hard_cap(compiled: &mut CompiledContext, max_chars: usize) {
    if compiled.assembled_prompt().len() <= max_chars {
        return;
    }

    compiled.rag_context.truncate(1);
    if let Some(first) = compiled.rag_context.first_mut() {
        *first = excerpt(first, 120);
    }

    if compiled.conversation_history.len() > 1 {
        let last = compiled.conversation_history.last().cloned().unwrap_or_default();
        compiled.conversation_history = vec![
            format!(
                "[summary of {} earlier turns omitted for budget]",
                compiled.conversation_history.len().saturating_sub(1)
            ),
            excerpt(&last, 120),
        ];
    } else if let Some(first) = compiled.conversation_history.first_mut() {
        *first = excerpt(first, 120);
    }

    compiled.memory.truncate(1);
    if let Some(first) = compiled.memory.first_mut() {
        *first = excerpt(first, 100);
    }

    compiled.few_shot_examples.truncate(1);
    if let Some(first) = compiled.few_shot_examples.first_mut() {
        *first = excerpt(first, 100);
    }

    compiled.system_prompt = excerpt(&compiled.system_prompt, 160);
    compiled.tools = vec![excerpt(&compiled.tools.join("\n"), 160)];
    compiled.current_user_message = excerpt(&compiled.current_user_message, 160);

    if compiled.assembled_prompt().len() > max_chars {
        compiled.rag_context.clear();
        compiled.conversation_history.clear();
        compiled.few_shot_examples.clear();
        compiled.memory.clear();
    }
}

fn cache_breakpoints_for(compiled: &CompiledContext) -> Vec<usize> {
    let mut breakpoints = vec![4];
    if !compiled.few_shot_examples.is_empty() {
        breakpoints.push(5);
    }
    breakpoints
}

fn display_identity(identity: &VaultIdentity) -> String {
    match identity {
        VaultIdentity::Model(name) => format!("model:{name}"),
        VaultIdentity::Agent(name) => format!("agent:{name}"),
        VaultIdentity::Team(names) => format!("team:{}", names.join(",")),
        VaultIdentity::UseCase(name) => format!("use-case:{name}"),
        VaultIdentity::Personal => "personal".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::ContextCompiler;
    use crate::vault_registry::VaultIdentity;
    use std::fs;
    use std::path::PathBuf;

    #[test]
    fn context_compiler_respects_cache_optimal_order() {
        let root = temp_root("context-compiler-order");
        fs::write(root.join("SYSTEM.md"), "System rules").unwrap();
        fs::write(root.join("MEMORY.md"), "## Durable Facts\n[strength:high] Memory A").unwrap();
        fs::write(
            root.join("EXAMPLES.md"),
            "Example one\n---\nA longer example that should appear after the shorter one",
        )
        .unwrap();
        fs::create_dir_all(root.join("skills")).unwrap();
        fs::write(root.join("skills/research.md"), "# Research\nUse primary sources").unwrap();
        fs::write(root.join("topic.md"), "Primary sources are preferred for evidence review.").unwrap();

        let compiled = ContextCompiler::new(VaultIdentity::Personal)
            .compile("primary sources", "claude-sonnet", &root)
            .unwrap();
        let prompt = compiled.assembled_prompt();

        assert!(prompt.find("## Tool Definitions").unwrap() < prompt.find("## System Prompt").unwrap());
        assert!(prompt.find("## System Prompt").unwrap() < prompt.find("## Skill Context").unwrap());
        assert!(prompt.find("## Skill Context").unwrap() < prompt.find("## Memory Context").unwrap());
        assert_eq!(compiled.cache_breakpoints, vec![4, 5]);
    }

    #[test]
    fn context_compiler_compresses_when_over_budget() {
        let root = temp_root("context-compiler-budget");
        let long_history = (0..12)
            .map(|index| format!("Turn {index}: {}", "lorem ipsum ".repeat(40)))
            .collect::<Vec<_>>()
            .join("\n---\n");
        fs::write(root.join("CONVERSATION.md"), long_history).unwrap();
        fs::write(
            root.join("MEMORY.md"),
            "## Durable Facts\n[strength:low] old note\n---\n[strength:high] anchor fact",
        )
        .unwrap();
        fs::write(root.join("EXAMPLES.md"), "Example A\n---\nExample B\n---\nExample C").unwrap();

        let compiled = ContextCompiler::new(VaultIdentity::Personal)
            .with_max_context_chars(900)
            .compile("budget test", "claude-haiku", &root)
            .unwrap();

        assert!(compiled.assembled_prompt().len() <= 900);
        assert!(compiled.conversation_history.iter().any(|entry| entry.contains("summary")));
        assert!(compiled.few_shot_examples.len() <= 1);
    }

    #[test]
    fn context_compiler_ranks_matching_markdown_for_rag() {
        let root = temp_root("context-compiler-rag");
        fs::write(root.join("alpha.md"), "graph graph graph context").unwrap();
        fs::write(root.join("beta.md"), "graph context").unwrap();
        fs::write(root.join("gamma.md"), "unrelated").unwrap();

        let compiled = ContextCompiler::new(VaultIdentity::Model("claude".into()))
            .compile("graph context", "claude-sonnet", &root)
            .unwrap();

        assert_eq!(compiled.rag_context.len(), 2);
        assert!(compiled.rag_context[0].contains("alpha.md"));
    }

    fn temp_root(prefix: &str) -> PathBuf {
        let root = std::env::temp_dir().join(format!("{prefix}-{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&root).unwrap();
        root
    }
}
