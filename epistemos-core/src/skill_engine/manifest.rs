// SKILL.md progressive disclosure parser.
//
// Skills are markdown files with YAML frontmatter. Content is parsed into
// three disclosure levels to minimize context window usage:
//
//   Level 0 (Catalog): name, description, category, triggers — always loaded
//   Level 1 (Activation): instructions, parameters, examples — loaded on selection
//   Level 2 (Execution): resource paths, context injection, required tools — loaded on run

use std::collections::HashMap;
use std::path::{Path, PathBuf};

// ── Disclosure Level Types ──────────────────────────────────────────────────

/// Level 0: minimal metadata for catalog listing. Always in memory.
#[derive(Debug, Clone)]
pub struct SkillCatalogEntry {
    pub name: String,
    pub description: String,
    pub category: String,
    pub triggers: Vec<String>,
    pub version: u32,
    pub source_path: PathBuf,
}

/// Level 1: instructions loaded on skill activation.
#[derive(Debug, Clone)]
pub struct SkillInstructions {
    pub prompt: String,
    pub parameters: Vec<SkillParameter>,
    pub examples: Vec<String>,
}

/// A typed skill parameter.
#[derive(Debug, Clone)]
pub struct SkillParameter {
    pub name: String,
    pub description: String,
    pub required: bool,
    pub default_value: Option<String>,
}

/// Level 2: resources loaded during execution.
#[derive(Debug, Clone)]
pub struct SkillResources {
    pub file_patterns: Vec<String>,
    pub context_rules: Vec<String>,
    pub required_tools: Vec<String>,
    pub optional_tools: Vec<String>,
}

/// Full parsed skill manifest (all 3 levels).
#[derive(Debug, Clone)]
pub struct SkillManifest {
    pub catalog: SkillCatalogEntry,
    pub instructions: SkillInstructions,
    pub resources: SkillResources,
}

// ── Parsing ─────────────────────────────────────────────────────────────────

/// Parse a SKILL.md file into a full SkillManifest.
pub fn parse_skill_manifest(content: &str, source_path: &Path) -> Result<SkillManifest, SkillParseError> {
    let (frontmatter, body) = split_frontmatter(content)?;
    let catalog = parse_frontmatter(&frontmatter, source_path)?;
    let instructions = parse_instructions_section(&body);
    let resources = parse_resources_section(&body);

    Ok(SkillManifest {
        catalog,
        instructions,
        resources,
    })
}

/// Parse only Level 0 (catalog entry) from a SKILL.md file.
/// Used by the registry to index skills without loading full content.
pub fn parse_catalog_entry(content: &str, source_path: &Path) -> Result<SkillCatalogEntry, SkillParseError> {
    let (frontmatter, _) = split_frontmatter(content)?;
    parse_frontmatter(&frontmatter, source_path)
}

/// Parse Level 1 (instructions) from a SKILL.md body.
pub fn parse_instructions_from_body(content: &str) -> SkillInstructions {
    let (_, body) = split_frontmatter(content).unwrap_or_default();
    parse_instructions_section(&body)
}

/// Parse Level 2 (resources) from a SKILL.md body.
pub fn parse_resources_from_body(content: &str) -> SkillResources {
    let (_, body) = split_frontmatter(content).unwrap_or_default();
    parse_resources_section(&body)
}

// ── Error Type ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub enum SkillParseError {
    NoFrontmatter,
    MissingField(String),
    MalformedYaml(String),
}

impl std::fmt::Display for SkillParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NoFrontmatter => write!(f, "no YAML frontmatter found (expected --- delimiters)"),
            Self::MissingField(field) => write!(f, "required field missing: {field}"),
            Self::MalformedYaml(detail) => write!(f, "malformed YAML: {detail}"),
        }
    }
}

impl std::error::Error for SkillParseError {}

// ── Internal Parsing Helpers ────────────────────────────────────────────────

fn split_frontmatter(content: &str) -> Result<(String, String), SkillParseError> {
    let trimmed = content.trim_start();
    if !trimmed.starts_with("---") {
        return Err(SkillParseError::NoFrontmatter);
    }

    // Find the closing ---
    let after_first = &trimmed[3..];
    let close_pos = after_first.find("\n---");
    match close_pos {
        Some(pos) => {
            let fm = after_first[..pos].trim().to_string();
            let body_start = pos + 4; // skip \n---
            let body = if body_start < after_first.len() {
                after_first[body_start..].trim().to_string()
            } else {
                String::new()
            };
            Ok((fm, body))
        }
        None => Err(SkillParseError::NoFrontmatter),
    }
}

fn parse_frontmatter(yaml_text: &str, source_path: &Path) -> Result<SkillCatalogEntry, SkillParseError> {
    // Simple YAML key-value parser (no serde_yaml dependency for frontmatter parsing).
    // Handles: name, description, category, version (scalars) and triggers (list).
    let mut map: HashMap<String, String> = HashMap::new();
    let mut triggers: Vec<String> = Vec::new();
    let mut in_triggers = false;

    for line in yaml_text.lines() {
        let trimmed = line.trim();

        if in_triggers {
            if trimmed.starts_with("- ") {
                let value = trimmed[2..].trim().trim_matches('"').trim_matches('\'');
                triggers.push(value.to_string());
                continue;
            } else if !trimmed.is_empty() {
                in_triggers = false;
                // Fall through to parse this line as a key-value
            } else {
                continue;
            }
        }

        if let Some((key, value)) = trimmed.split_once(':') {
            let key = key.trim().to_string();
            let value = value.trim().trim_matches('"').trim_matches('\'').to_string();

            if key == "triggers" && value.is_empty() {
                in_triggers = true;
            } else {
                map.insert(key, value);
            }
        }
    }

    let name = map.get("name")
        .filter(|s| !s.is_empty())
        .ok_or_else(|| SkillParseError::MissingField("name".to_string()))?
        .clone();

    let description = map.get("description")
        .filter(|s| !s.is_empty())
        .ok_or_else(|| SkillParseError::MissingField("description".to_string()))?
        .clone();

    let category = map.get("category")
        .cloned()
        .unwrap_or_else(|| "general".to_string());

    let version = map.get("version")
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(1);

    Ok(SkillCatalogEntry {
        name,
        description,
        category,
        triggers,
        version,
        source_path: source_path.to_path_buf(),
    })
}

fn parse_instructions_section(body: &str) -> SkillInstructions {
    let section = extract_section(body, "Instructions");
    let prompt = extract_prose(&section);
    let parameters = parse_parameters_block(&section);
    let examples = parse_examples_block(&section);

    SkillInstructions {
        prompt,
        parameters,
        examples,
    }
}

fn parse_resources_section(body: &str) -> SkillResources {
    let section = extract_section(body, "Resources");
    let file_patterns = extract_list_under_heading(&section, "File Patterns");
    let context_rules = extract_list_under_heading(&section, "Context Injection");
    let required_tools = extract_list_under_heading(&section, "Tools Required");
    let optional_tools = extract_list_under_heading(&section, "Optional Tools");

    SkillResources {
        file_patterns,
        context_rules,
        required_tools,
        optional_tools,
    }
}

/// Extract content between `## {heading}` and the next `## ` or end of string.
fn extract_section(body: &str, heading: &str) -> String {
    let target = format!("## {heading}");
    let mut found = false;
    let mut lines = Vec::new();

    for line in body.lines() {
        if found {
            // Stop at next ## heading
            if line.starts_with("## ") {
                break;
            }
            lines.push(line);
        } else if line.trim().eq_ignore_ascii_case(&target) || line.trim().starts_with(&target) {
            found = true;
        }
    }

    lines.join("\n").trim().to_string()
}

/// Extract prose text (lines that aren't headings or list items) from a section.
fn extract_prose(section: &str) -> String {
    let mut prose_lines = Vec::new();
    let mut in_sub_section = false;

    for line in section.lines() {
        if line.starts_with("### ") {
            in_sub_section = true;
            continue;
        }
        if !in_sub_section && !line.trim().is_empty() {
            prose_lines.push(line);
        }
        // Reset when hitting another heading level
        if in_sub_section && line.starts_with("### ") {
            continue;
        }
    }

    prose_lines.join("\n").trim().to_string()
}

/// Parse `### Parameters` block into typed parameters.
fn parse_parameters_block(section: &str) -> Vec<SkillParameter> {
    let params_section = extract_sub_section(section, "Parameters");
    let mut params = Vec::new();

    for line in params_section.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with("- ") {
            continue;
        }
        let entry = &trimmed[2..];

        // Format: "name: description (required)" or "name: description (default: value)"
        if let Some((name_part, desc_part)) = entry.split_once(':') {
            let name = name_part.trim().to_string();
            let desc_raw = desc_part.trim();

            let required = desc_raw.contains("(required)");
            let default_value = extract_parenthesized(desc_raw, "default:");
            let description = desc_raw
                .replace("(required)", "")
                .replace(&format!("(default: {})", default_value.as_deref().unwrap_or("")), "")
                .trim()
                .to_string();

            params.push(SkillParameter {
                name,
                description,
                required,
                default_value,
            });
        }
    }

    params
}

/// Parse `### Examples` block into example strings.
fn parse_examples_block(section: &str) -> Vec<String> {
    let examples_section = extract_sub_section(section, "Examples");
    examples_section
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if trimmed.starts_with("- ") {
                Some(trimmed[2..].trim().to_string())
            } else {
                None
            }
        })
        .collect()
}

/// Extract content between `### {heading}` and the next `### ` or end.
fn extract_sub_section(section: &str, heading: &str) -> String {
    let target = format!("### {heading}");
    let mut found = false;
    let mut lines = Vec::new();

    for line in section.lines() {
        if found {
            if line.starts_with("### ") {
                break;
            }
            lines.push(line);
        } else if line.trim().eq_ignore_ascii_case(&target) || line.trim().starts_with(&target) {
            found = true;
        }
    }

    lines.join("\n").trim().to_string()
}

/// Extract list items under a `### {heading}` in a section.
fn extract_list_under_heading(section: &str, heading: &str) -> Vec<String> {
    let sub = extract_sub_section(section, heading);
    sub.lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if trimmed.starts_with("- ") {
                let value = trimmed[2..].trim();
                // Strip bold markers
                let cleaned = value.replace("**", "");
                Some(cleaned.trim().to_string())
            } else {
                None
            }
        })
        .collect()
}

/// Extract a value from parenthesized content like "(default: medium)".
fn extract_parenthesized(text: &str, prefix: &str) -> Option<String> {
    let search = format!("({prefix}");
    if let Some(start) = text.find(&search) {
        let after = &text[start + search.len()..];
        if let Some(end) = after.find(')') {
            return Some(after[..end].trim().to_string());
        }
    }
    None
}

// ── Registry ────────────────────────────────────────────────────────────────

/// Scan a directory for SKILL.md files and return Level 0 catalog entries.
pub fn scan_skill_directory(dir: &Path) -> Vec<SkillCatalogEntry> {
    let mut entries = Vec::new();

    let Ok(read_dir) = std::fs::read_dir(dir) else {
        return entries;
    };

    for entry in read_dir.flatten() {
        let path = entry.path();

        // Accept both SKILL.md files and directories containing SKILL.md
        let skill_path = if path.is_file() && path.file_name().map_or(false, |n| {
            let name = n.to_string_lossy();
            name == "SKILL.md" || name.ends_with(".skill.md")
        }) {
            path.clone()
        } else if path.is_dir() {
            let nested = path.join("SKILL.md");
            if nested.is_file() { nested } else { continue }
        } else {
            continue;
        };

        if let Ok(content) = std::fs::read_to_string(&skill_path) {
            match parse_catalog_entry(&content, &skill_path) {
                Ok(entry) => entries.push(entry),
                Err(e) => {
                    tracing::warn!("Skipping malformed skill {}: {}", skill_path.display(), e);
                }
            }
        }
    }

    // Sort by name for deterministic ordering
    entries.sort_by(|a, b| a.name.cmp(&b.name));
    entries
}

/// Match a user input against skill triggers. Returns matching skill names.
pub fn match_triggers(input: &str, catalog: &[SkillCatalogEntry]) -> Vec<String> {
    let lower = input.to_lowercase();
    catalog
        .iter()
        .filter(|entry| {
            entry.triggers.iter().any(|trigger| {
                let t = trigger.to_lowercase();
                lower.starts_with(&t) || lower.contains(&t)
            })
        })
        .map(|entry| entry.name.clone())
        .collect()
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE_SKILL: &str = r#"---
name: research-notes
description: Deep research on a topic using vault notes
category: research
triggers:
  - /research
  - investigate
version: 2
---

## Instructions

You are a research assistant. Given a topic, search the user's vault for relevant notes and synthesize findings.

### Parameters
- topic: The research subject (required)
- depth: shallow, medium, or deep (default: medium)

### Examples
- "/research quantum computing" searches vault for quantum notes
- "/research --deep ML trends" does a deep dive

## Resources

### File Patterns
- **/*.md
- notes/**/*.txt

### Context Injection
- Include vault search results for {topic}
- Include related graph nodes within 2 hops

### Tools Required
- vault_search
- vault_read
"#;

    #[test]
    fn test_parse_full_manifest() {
        let manifest = parse_skill_manifest(SAMPLE_SKILL, Path::new("test/SKILL.md")).unwrap();
        assert_eq!(manifest.catalog.name, "research-notes");
        assert_eq!(manifest.catalog.description, "Deep research on a topic using vault notes");
        assert_eq!(manifest.catalog.category, "research");
        assert_eq!(manifest.catalog.triggers, vec!["/research", "investigate"]);
        assert_eq!(manifest.catalog.version, 2);
    }

    #[test]
    fn test_parse_catalog_only() {
        let entry = parse_catalog_entry(SAMPLE_SKILL, Path::new("test/SKILL.md")).unwrap();
        assert_eq!(entry.name, "research-notes");
        assert_eq!(entry.triggers.len(), 2);
    }

    #[test]
    fn test_parse_instructions() {
        let manifest = parse_skill_manifest(SAMPLE_SKILL, Path::new("test/SKILL.md")).unwrap();
        assert!(manifest.instructions.prompt.contains("research assistant"));
        assert_eq!(manifest.instructions.parameters.len(), 2);
        assert!(manifest.instructions.parameters[0].required);
        assert_eq!(manifest.instructions.parameters[1].default_value.as_deref(), Some("medium"));
        assert_eq!(manifest.instructions.examples.len(), 2);
    }

    #[test]
    fn test_parse_resources() {
        let manifest = parse_skill_manifest(SAMPLE_SKILL, Path::new("test/SKILL.md")).unwrap();
        assert_eq!(manifest.resources.file_patterns.len(), 2);
        assert!(manifest.resources.file_patterns[0].contains("*.md"));
        assert_eq!(manifest.resources.required_tools, vec!["vault_search", "vault_read"]);
        assert_eq!(manifest.resources.context_rules.len(), 2);
    }

    #[test]
    fn test_no_frontmatter_error() {
        let result = parse_skill_manifest("No frontmatter here", Path::new("bad.md"));
        assert!(matches!(result, Err(SkillParseError::NoFrontmatter)));
    }

    #[test]
    fn test_missing_name_error() {
        let content = "---\ndescription: test\n---\n\n## Instructions\nDo stuff\n";
        let result = parse_skill_manifest(content, Path::new("bad.md"));
        assert!(matches!(result, Err(SkillParseError::MissingField(_))));
    }

    #[test]
    fn test_minimal_skill() {
        let content = "---\nname: simple\ndescription: A simple skill\n---\n";
        let manifest = parse_skill_manifest(content, Path::new("simple.md")).unwrap();
        assert_eq!(manifest.catalog.name, "simple");
        assert_eq!(manifest.catalog.category, "general");
        assert_eq!(manifest.catalog.version, 1);
        assert!(manifest.instructions.prompt.is_empty());
        assert!(manifest.resources.required_tools.is_empty());
    }

    #[test]
    fn test_trigger_matching() {
        let catalog = vec![
            SkillCatalogEntry {
                name: "research".to_string(),
                description: "Research".to_string(),
                category: "research".to_string(),
                triggers: vec!["/research".to_string(), "investigate".to_string()],
                version: 1,
                source_path: PathBuf::from("test.md"),
            },
            SkillCatalogEntry {
                name: "review".to_string(),
                description: "Review".to_string(),
                category: "review".to_string(),
                triggers: vec!["/review".to_string()],
                version: 1,
                source_path: PathBuf::from("test2.md"),
            },
        ];

        let matches = match_triggers("/research quantum computing", &catalog);
        assert_eq!(matches, vec!["research"]);

        let matches = match_triggers("please investigate this topic", &catalog);
        assert_eq!(matches, vec!["research"]);

        let matches = match_triggers("/review this PR", &catalog);
        assert_eq!(matches, vec!["review"]);

        let matches = match_triggers("hello world", &catalog);
        assert!(matches.is_empty());
    }

    #[test]
    fn test_scan_empty_directory() {
        // Non-existent directory returns empty
        let entries = scan_skill_directory(Path::new("/nonexistent/path"));
        assert!(entries.is_empty());
    }
}
