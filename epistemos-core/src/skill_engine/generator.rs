// Post-task auto-skill creation.
//
// After an agent completes a task, this module generates a SKILL.md file
// from the task summary. The generated skill can be reused for similar tasks.
//
// Input: TaskSummary (objective, tools used, files touched, outcome)
// Output: well-formed SKILL.md content string with 3-level progressive disclosure

use std::fmt::Write as FmtWrite;
use std::path::Path;

/// Summary of a completed agent task, used to generate a skill.
#[derive(Debug, Clone)]
pub struct TaskSummary {
    /// What the user asked for.
    pub objective: String,
    /// Tools that were invoked during execution.
    pub tools_used: Vec<String>,
    /// File glob patterns that were read or modified.
    pub file_patterns: Vec<String>,
    /// Short description of what was accomplished.
    pub outcome: String,
    /// How many agent turns it took.
    pub turn_count: u32,
    /// Category hint (if known). Auto-detected if empty.
    pub category_hint: String,
}

/// Generate a SKILL.md content string from a completed task summary.
pub fn generate_skill_md(summary: &TaskSummary) -> String {
    let name = derive_skill_name(&summary.objective);
    let description = derive_description(&summary.objective, &summary.outcome);
    let category = if summary.category_hint.is_empty() {
        detect_category(&summary.tools_used, &summary.objective)
    } else {
        summary.category_hint.clone()
    };
    let triggers = derive_triggers(&summary.objective, &name);

    let mut out = String::with_capacity(1024);

    // ── Frontmatter (Level 0) ──
    writeln!(out, "---").ok();
    writeln!(out, "name: {name}").ok();
    writeln!(out, "description: {description}").ok();
    writeln!(out, "category: {category}").ok();
    writeln!(out, "triggers:").ok();
    for trigger in &triggers {
        writeln!(out, "  - {trigger}").ok();
    }
    writeln!(out, "version: 1").ok();
    writeln!(out, "---").ok();
    writeln!(out).ok();

    // ── Instructions (Level 1) ──
    writeln!(out, "## Instructions").ok();
    writeln!(out).ok();
    writeln!(
        out,
        "{}",
        derive_instructions(&summary.objective, &summary.outcome)
    )
    .ok();
    writeln!(out).ok();

    if summary.turn_count > 1 {
        writeln!(out, "### Parameters").ok();
        writeln!(out, "- target: The specific target or scope (required)").ok();
        writeln!(out).ok();
    }

    writeln!(out, "### Examples").ok();
    writeln!(out, "- \"{}\"", summary.objective).ok();
    writeln!(out).ok();

    // ── Resources (Level 2) ──
    writeln!(out, "## Resources").ok();
    writeln!(out).ok();

    if !summary.file_patterns.is_empty() {
        writeln!(out, "### File Patterns").ok();
        for pattern in &summary.file_patterns {
            writeln!(out, "- {pattern}").ok();
        }
        writeln!(out).ok();
    }

    if !summary.tools_used.is_empty() {
        writeln!(out, "### Tools Required").ok();
        for tool in &summary.tools_used {
            writeln!(out, "- {tool}").ok();
        }
        writeln!(out).ok();
    }

    out
}

/// Write a generated SKILL.md to disk in the skills directory.
pub fn write_skill_file(
    skills_dir: &Path,
    summary: &TaskSummary,
) -> Result<std::path::PathBuf, std::io::Error> {
    let name = derive_skill_name(&summary.objective);
    let dir = skills_dir.join(&name);
    std::fs::create_dir_all(&dir)?;
    let path = dir.join("SKILL.md");
    let content = generate_skill_md(summary);
    std::fs::write(&path, &content)?;
    Ok(path)
}

// ── Internal helpers ────────────────────────────────────────────────────────

/// Derive a kebab-case skill name from an objective.
fn derive_skill_name(objective: &str) -> String {
    let lower = objective.to_lowercase();

    // Drop common prefix words
    let stripped = lower
        .trim_start_matches("please ")
        .trim_start_matches("help me ")
        .trim_start_matches("can you ");

    // Take first 4 meaningful words, kebab-case them
    let words: Vec<&str> = stripped
        .split_whitespace()
        .filter(|w| !STOP_WORDS.contains(w))
        .take(4)
        .collect();

    if words.is_empty() {
        return "auto-skill".to_string();
    }

    let name: String = words.join("-");
    // Sanitize: only alphanumeric + hyphens
    name.chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '-' {
                c
            } else {
                '-'
            }
        })
        .collect::<String>()
        .trim_matches('-')
        .to_string()
}

/// Derive a one-line description from objective + outcome.
fn derive_description(objective: &str, outcome: &str) -> String {
    if outcome.len() > 10 {
        // Truncate outcome to ~80 chars for the description
        let truncated = if outcome.len() > 80 {
            format!("{}...", &outcome[..77])
        } else {
            outcome.to_string()
        };
        truncated
    } else {
        // Fall back to objective
        let truncated = if objective.len() > 80 {
            format!("{}...", &objective[..77])
        } else {
            objective.to_string()
        };
        truncated
    }
}

/// Auto-detect category from tools used and objective text.
fn detect_category(tools: &[String], objective: &str) -> String {
    let lower = objective.to_lowercase();

    if tools
        .iter()
        .any(|t| t.contains("search") || t.contains("research"))
        || lower.contains("research")
    {
        return "research".to_string();
    }
    if tools
        .iter()
        .any(|t| t.contains("write") || t.contains("edit"))
        || lower.contains("write")
        || lower.contains("edit")
    {
        return "writing".to_string();
    }
    if tools
        .iter()
        .any(|t| t.contains("bash") || t.contains("terminal"))
        || lower.contains("deploy")
        || lower.contains("build")
    {
        return "development".to_string();
    }
    if lower.contains("review") || lower.contains("analyze") {
        return "analysis".to_string();
    }

    "general".to_string()
}

/// Derive trigger patterns from the objective.
fn derive_triggers(objective: &str, skill_name: &str) -> Vec<String> {
    let mut triggers = vec![format!("/{skill_name}")];

    // Extract the primary verb
    let lower = objective.to_lowercase();
    let verbs = [
        "research",
        "review",
        "analyze",
        "write",
        "build",
        "deploy",
        "search",
        "find",
        "summarize",
        "debug",
        "test",
        "refactor",
    ];

    for verb in verbs {
        if lower.contains(verb) {
            let trigger = verb.to_string();
            if !triggers.contains(&trigger) {
                triggers.push(trigger);
            }
            break; // Only take the first matching verb
        }
    }

    triggers
}

/// Derive instruction text from objective + outcome.
fn derive_instructions(objective: &str, outcome: &str) -> String {
    let mut text = String::new();
    writeln!(text, "Perform the following task: {objective}").ok();
    if !outcome.is_empty() {
        writeln!(text).ok();
        writeln!(text, "Expected outcome: {outcome}").ok();
    }
    text.trim().to_string()
}

const STOP_WORDS: &[&str] = &[
    "a", "an", "the", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had",
    "do", "does", "did", "will", "would", "shall", "should", "may", "might", "must", "can",
    "could", "to", "of", "in", "for", "on", "with", "at", "by", "from", "as", "into", "through",
    "during", "before", "after", "above", "below", "between", "out", "about", "and", "but", "or",
    "nor", "not", "so", "if", "then", "than", "that", "this", "these", "those", "it", "its", "my",
    "your",
];

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_summary() -> TaskSummary {
        TaskSummary {
            objective: "Research quantum computing papers in my vault".to_string(),
            tools_used: vec!["vault_search".to_string(), "vault_read".to_string()],
            file_patterns: vec!["notes/**/*.md".to_string()],
            outcome: "Found and synthesized 5 relevant notes on quantum computing".to_string(),
            turn_count: 3,
            category_hint: String::new(),
        }
    }

    #[test]
    fn test_generate_skill_md_structure() {
        let md = generate_skill_md(&sample_summary());
        assert!(md.starts_with("---\n"));
        assert!(md.contains("name: research-quantum-computing-papers"));
        assert!(md.contains("category: research"));
        assert!(md.contains("## Instructions"));
        assert!(md.contains("## Resources"));
        assert!(md.contains("### Tools Required"));
        assert!(md.contains("- vault_search"));
    }

    #[test]
    fn test_derive_skill_name() {
        assert_eq!(
            derive_skill_name("Research quantum computing"),
            "research-quantum-computing"
        );
        assert_eq!(
            derive_skill_name("Please help me write a draft"),
            "write-draft"
        );
        assert_eq!(derive_skill_name(""), "auto-skill");
        assert_eq!(derive_skill_name("the a an"), "auto-skill");
    }

    #[test]
    fn test_detect_category() {
        assert_eq!(
            detect_category(&["vault_search".into()], "research this"),
            "research"
        );
        assert_eq!(
            detect_category(&["bash".into()], "deploy the app"),
            "development"
        );
        assert_eq!(detect_category(&[], "write a summary"), "writing");
        assert_eq!(detect_category(&[], "hello world"), "general");
    }

    #[test]
    fn test_derive_triggers() {
        let triggers = derive_triggers("Research quantum computing", "research-quantum");
        assert!(triggers.contains(&"/research-quantum".to_string()));
        assert!(triggers.contains(&"research".to_string()));
    }

    #[test]
    fn test_roundtrip_parse() {
        let md = generate_skill_md(&sample_summary());
        let manifest = super::super::manifest::parse_skill_manifest(&md, Path::new("test.md"));
        assert!(manifest.is_ok(), "Generated SKILL.md should be parseable");
        let manifest = manifest.unwrap();
        assert_eq!(manifest.catalog.category, "research");
        assert!(!manifest.catalog.triggers.is_empty());
        assert!(!manifest.resources.required_tools.is_empty());
    }

    #[test]
    fn test_write_skill_file() {
        let tmp = std::env::temp_dir().join("epistemos_test_skills");
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();

        let summary = sample_summary();
        let path = write_skill_file(&tmp, &summary).unwrap();
        assert!(path.exists());

        let content = std::fs::read_to_string(&path).unwrap();
        assert!(content.contains("name: research-quantum-computing-papers"));

        // Verify it's scannable by the registry
        let entries = super::super::manifest::scan_skill_directory(&tmp);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "research-quantum-computing-papers");

        let _ = std::fs::remove_dir_all(&tmp);
    }
}
