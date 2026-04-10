//! Skills Tool — Agent-Managed Procedural Memory (Ported from Hermes Agent v0.7.0)
//!
//! Skills are the agent's procedural memory: they capture *how to do a specific
//! type of task* based on proven experience. Different from general memory (MEMORY.md)
//! which is broad and declarative — skills are narrow and actionable.
//!
//! Directory layout:
//!   ~/.hermes/skills/          (or vault_path/skills/)
//!   ├── my-skill/
//!   │   ├── SKILL.md           (frontmatter + instructions)
//!   │   ├── references/
//!   │   ├── templates/
//!   │   └── scripts/
//!   └── category/
//!       └── another-skill/
//!           └── SKILL.md
//!
//! Actions: create, edit, patch, delete, list

use std::fs;
use std::path::{Path, PathBuf};

use serde_json::{json, Value};

use super::registry::ToolHandler;

const MAX_NAME_LENGTH: usize = 64;
const ALLOWED_SUBDIRS: &[&str] = &["references", "templates", "scripts", "assets"];

// MARK: - Validation

fn validate_name(name: &str) -> Option<String> {
    if name.is_empty() {
        return Some("Skill name is required.".to_string());
    }
    if name.len() > MAX_NAME_LENGTH {
        return Some(format!("Skill name exceeds {} characters.", MAX_NAME_LENGTH));
    }
    if !name.chars().next().map_or(false, |c| c.is_ascii_alphanumeric()) {
        return Some("Skill name must start with a letter or digit.".to_string());
    }
    if !name.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-' || c == '_' || c == '.') {
        return Some("Skill name must use lowercase letters, numbers, hyphens, dots, underscores.".to_string());
    }
    None
}

fn validate_frontmatter(content: &str) -> Option<String> {
    let content = content.trim();
    if content.is_empty() {
        return Some("Content cannot be empty.".to_string());
    }
    if !content.starts_with("---") {
        return Some("SKILL.md must start with YAML frontmatter (---).".to_string());
    }
    // Find closing ---
    if let Some(end) = content[3..].find("\n---") {
        let yaml_section = &content[3..3 + end];
        // Basic validation: must contain name and description
        if !yaml_section.contains("name:") {
            return Some("Frontmatter must include 'name' field.".to_string());
        }
        if !yaml_section.contains("description:") {
            return Some("Frontmatter must include 'description' field.".to_string());
        }
        // Check body after frontmatter
        let body_start = 3 + end + 4; // skip past \n---
        if body_start >= content.len() || content[body_start..].trim().is_empty() {
            return Some("SKILL.md must have content after the frontmatter.".to_string());
        }
        None
    } else {
        Some("Frontmatter not closed. Ensure you have a closing '---' line.".to_string())
    }
}

// MARK: - Skills Store

pub struct SkillsStore {
    skills_dir: PathBuf,
}

impl SkillsStore {
    pub fn new(skills_dir: PathBuf) -> Self {
        Self { skills_dir }
    }

    /// List all available skills with name + description.
    pub fn list(&self) -> Value {
        let mut skills = Vec::new();

        if let Ok(entries) = fs::read_dir(&self.skills_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    // Direct skill: skills/name/SKILL.md
                    let skill_md = path.join("SKILL.md");
                    if skill_md.exists() {
                        if let Some(info) = self.parse_skill_info(&path) {
                            skills.push(info);
                        }
                    } else {
                        // Category directory: skills/category/name/SKILL.md
                        if let Ok(sub_entries) = fs::read_dir(&path) {
                            for sub_entry in sub_entries.flatten() {
                                let sub_path = sub_entry.path();
                                if sub_path.is_dir() && sub_path.join("SKILL.md").exists() {
                                    if let Some(info) = self.parse_skill_info(&sub_path) {
                                        skills.push(info);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        json!({
            "skills": skills,
            "count": skills.len(),
            "skills_dir": self.skills_dir.display().to_string(),
        })
    }

    /// Create a new skill with SKILL.md content.
    pub fn create(&self, name: &str, content: &str, category: Option<&str>) -> Value {
        if let Some(err) = validate_name(name) {
            return json!({"success": false, "error": err});
        }
        if let Some(err) = validate_frontmatter(content) {
            return json!({"success": false, "error": err});
        }

        let skill_dir = if let Some(cat) = category {
            if let Some(err) = validate_name(cat) {
                return json!({"success": false, "error": format!("Invalid category: {}", err)});
            }
            self.skills_dir.join(cat).join(name)
        } else {
            self.skills_dir.join(name)
        };

        if skill_dir.exists() {
            return json!({"success": false, "error": format!("Skill '{}' already exists.", name)});
        }

        if fs::create_dir_all(&skill_dir).is_err() {
            return json!({"success": false, "error": "Failed to create skill directory."});
        }

        let skill_md = skill_dir.join("SKILL.md");
        if fs::write(&skill_md, content).is_err() {
            return json!({"success": false, "error": "Failed to write SKILL.md."});
        }

        // Create standard subdirectories
        for subdir in ALLOWED_SUBDIRS {
            let _ = fs::create_dir_all(skill_dir.join(subdir));
        }

        json!({
            "success": true,
            "action": "create",
            "name": name,
            "path": skill_dir.display().to_string(),
        })
    }

    /// Replace entire SKILL.md content.
    pub fn edit(&self, name: &str, content: &str) -> Value {
        if let Some(err) = validate_frontmatter(content) {
            return json!({"success": false, "error": err});
        }

        let Some(skill_dir) = self.find_skill(name) else {
            return json!({"success": false, "error": format!("Skill '{}' not found.", name)});
        };

        let skill_md = skill_dir.join("SKILL.md");
        if fs::write(&skill_md, content).is_err() {
            return json!({"success": false, "error": "Failed to write SKILL.md."});
        }

        json!({"success": true, "action": "edit", "name": name})
    }

    /// Targeted find-and-replace within SKILL.md.
    pub fn patch(&self, name: &str, find: &str, replace: &str) -> Value {
        if find.is_empty() {
            return json!({"success": false, "error": "Find string cannot be empty."});
        }

        let Some(skill_dir) = self.find_skill(name) else {
            return json!({"success": false, "error": format!("Skill '{}' not found.", name)});
        };

        let skill_md = skill_dir.join("SKILL.md");
        let content = match fs::read_to_string(&skill_md) {
            Ok(c) => c,
            Err(_) => return json!({"success": false, "error": "Failed to read SKILL.md."}),
        };

        let count = content.matches(find).count();
        if count == 0 {
            return json!({"success": false, "error": format!("'{}' not found in SKILL.md.", find)});
        }

        let patched = content.replace(find, replace);
        if fs::write(&skill_md, &patched).is_err() {
            return json!({"success": false, "error": "Failed to write patched SKILL.md."});
        }

        json!({"success": true, "action": "patch", "name": name, "replacements": count})
    }

    /// Delete an entire skill directory.
    pub fn delete(&self, name: &str) -> Value {
        let Some(skill_dir) = self.find_skill(name) else {
            return json!({"success": false, "error": format!("Skill '{}' not found.", name)});
        };

        // Safety: only delete if under skills_dir
        if !skill_dir.starts_with(&self.skills_dir) {
            return json!({"success": false, "error": "Skill path is outside skills directory."});
        }

        if fs::remove_dir_all(&skill_dir).is_err() {
            return json!({"success": false, "error": "Failed to delete skill directory."});
        }

        json!({"success": true, "action": "delete", "name": name})
    }

    // MARK: - Helpers

    fn find_skill(&self, name: &str) -> Option<PathBuf> {
        if !self.skills_dir.exists() {
            return None;
        }
        // Walk skills directory looking for a directory with matching name containing SKILL.md
        for entry in walkdir::WalkDir::new(&self.skills_dir).max_depth(2).into_iter().flatten() {
            let path = entry.path();
            if path.is_dir()
                && path.file_name().map_or(false, |n| n == name)
                && path.join("SKILL.md").exists()
            {
                return Some(path.to_path_buf());
            }
        }
        None
    }

    fn parse_skill_info(&self, skill_dir: &Path) -> Option<Value> {
        let skill_md = skill_dir.join("SKILL.md");
        let content = fs::read_to_string(&skill_md).ok()?;
        let name = skill_dir.file_name()?.to_str()?;

        // Extract description from frontmatter
        let description = if content.starts_with("---") {
            if let Some(end) = content[3..].find("\n---") {
                let yaml = &content[3..3 + end];
                yaml.lines()
                    .find(|l| l.starts_with("description:"))
                    .map(|l| l.trim_start_matches("description:").trim().trim_matches('"').to_string())
            } else {
                None
            }
        } else {
            None
        };

        Some(json!({
            "name": name,
            "description": description.unwrap_or_default(),
            "path": skill_dir.display().to_string(),
        }))
    }

    /// Returns skill content for system prompt injection (all skills as context).
    pub fn skills_context(&self) -> String {
        let list = self.list();
        let skills = list["skills"].as_array();
        match skills {
            Some(arr) if !arr.is_empty() => {
                let lines: Vec<String> = arr.iter().map(|s| {
                    format!("- {}: {}", s["name"].as_str().unwrap_or("?"), s["description"].as_str().unwrap_or(""))
                }).collect();
                format!("<available-skills>\n{}\n</available-skills>", lines.join("\n"))
            }
            _ => String::new(),
        }
    }
}

// MARK: - Tool Handler

pub struct SkillsTool {
    store: std::sync::Mutex<SkillsStore>,
}

impl SkillsTool {
    pub fn new(skills_dir: PathBuf) -> Self {
        Self {
            store: std::sync::Mutex::new(SkillsStore::new(skills_dir)),
        }
    }
}

#[async_trait::async_trait]
impl ToolHandler for SkillsTool {
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        let action = input["action"].as_str().unwrap_or("list");
        let name = input["name"].as_str().unwrap_or("");
        let content = input["content"].as_str().unwrap_or("");
        let category = input["category"].as_str();
        let find = input["find"].as_str().unwrap_or("");
        let replace = input["replace"].as_str().unwrap_or("");

        let store = self.store.lock().map_err(|e| {
            super::registry::ToolError::ExecutionFailed(format!("Skills lock poisoned: {e}"))
        })?;

        let result = match action {
            "create" => store.create(name, content, category),
            "edit" => store.edit(name, content),
            "patch" => store.patch(name, find, replace),
            "delete" => store.delete(name),
            "list" => store.list(),
            _ => json!({"success": false, "error": format!("Unknown action: {action}")}),
        };

        Ok(serde_json::to_string_pretty(&result).unwrap_or_default())
    }
}

/// Returns the tool schema for registration.
pub fn skills_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "skills".to_string(),
        description: "Manage reusable skills (procedural memory). Skills capture how to do specific tasks. Actions: create (new skill with SKILL.md), edit (replace SKILL.md), patch (find-and-replace in SKILL.md), delete (remove skill), list (show all skills).".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "edit", "patch", "delete", "list"],
                    "description": "The operation to perform."
                },
                "name": {
                    "type": "string",
                    "description": "Skill name (lowercase, hyphens, dots, underscores)."
                },
                "content": {
                    "type": "string",
                    "description": "SKILL.md content with YAML frontmatter (for create/edit)."
                },
                "category": {
                    "type": "string",
                    "description": "Optional category directory for create."
                },
                "find": {
                    "type": "string",
                    "description": "Text to find in SKILL.md (for patch)."
                },
                "replace": {
                    "type": "string",
                    "description": "Replacement text (for patch)."
                }
            },
            "required": ["action"],
        }),
    }
}

// MARK: - Progressive Disclosure Skills Tools
//
// The existing `skills` tool bundles CRUD behind a single action enum. Phase 1
// adds three focused tools so the agent can cheaply discover skills (tier 0:
// name + description) without paying the full body load cost until a skill is
// actually needed (tier 1: full SKILL.md via skill_view).
//
// All three share the same underlying scan logic — they differ in the shape
// of their output.

const MAX_SKILL_BYTES: usize = 15_360; // 15KB hard cap per SKILL.md

fn default_skills_dir() -> PathBuf {
    if let Ok(override_path) = std::env::var("EPISTEMOS_SKILLS_DIR") {
        return PathBuf::from(override_path);
    }
    let mut base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.push(".epistemos");
    base.push("skills");
    let _ = fs::create_dir_all(&base);
    base
}

/// Tier-0 metadata: name + one-line description + path.
#[derive(Debug, Clone)]
struct SkillMetadata {
    name: String,
    description: String,
    category: Option<String>,
    tags: Vec<String>,
    requires_tools: Vec<String>,
    path: PathBuf,
}

fn parse_frontmatter(content: &str) -> SkillMetadata {
    let default = SkillMetadata {
        name: String::new(),
        description: String::new(),
        category: None,
        tags: Vec::new(),
        requires_tools: Vec::new(),
        path: PathBuf::new(),
    };
    if !content.starts_with("---") {
        return default;
    }
    let Some(end) = content[3..].find("\n---") else {
        return default;
    };
    let yaml_body = &content[3..3 + end];
    let parsed: Result<serde_yaml::Value, _> = serde_yaml::from_str(yaml_body);
    let Ok(root) = parsed else { return default };

    let name = root
        .get("name")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let description = root
        .get("description")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    let metadata_block = root.get("metadata").and_then(|v| v.get("epistemos"));

    let category = metadata_block
        .and_then(|m| m.get("category"))
        .and_then(|v| v.as_str())
        .map(String::from);

    let tags = metadata_block
        .and_then(|m| m.get("tags"))
        .and_then(|v| v.as_sequence())
        .map(|seq| {
            seq.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_default();

    let requires_tools = metadata_block
        .and_then(|m| m.get("requires_tools"))
        .and_then(|v| v.as_sequence())
        .map(|seq| {
            seq.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_default();

    SkillMetadata {
        name,
        description,
        category,
        tags,
        requires_tools,
        path: PathBuf::new(),
    }
}

fn scan_skills(root: &Path) -> Vec<SkillMetadata> {
    let mut out = Vec::new();
    if !root.exists() {
        return out;
    }
    // Walk at most 3 levels deep: root / [category /] skill / SKILL.md
    for entry in walkdir::WalkDir::new(root)
        .max_depth(3)
        .into_iter()
        .flatten()
    {
        if !entry.file_type().is_file() {
            continue;
        }
        if entry.file_name() != "SKILL.md" {
            continue;
        }
        let path = entry.path().to_path_buf();
        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let mut metadata = parse_frontmatter(&content);
        metadata.path = path.clone();
        if metadata.name.is_empty() {
            if let Some(parent) = path.parent() {
                if let Some(name) = parent.file_name().and_then(|n| n.to_str()) {
                    metadata.name = name.to_string();
                }
            }
        }
        out.push(metadata);
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    out
}

fn metadata_to_json(metadata: &SkillMetadata) -> Value {
    json!({
        "name": metadata.name,
        "description": metadata.description,
        "category": metadata.category,
        "tags": metadata.tags,
        "requires_tools": metadata.requires_tools,
        "path": metadata.path.display().to_string(),
    })
}

/// `skills_list` — tier-0 metadata only.
pub struct SkillsListHandler {
    skills_dir: PathBuf,
}

impl SkillsListHandler {
    pub fn new() -> Self {
        Self {
            skills_dir: default_skills_dir(),
        }
    }
}

impl Default for SkillsListHandler {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait::async_trait]
impl ToolHandler for SkillsListHandler {
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        let filter = input.get("tag").and_then(Value::as_str);
        let metadata = scan_skills(&self.skills_dir);
        let skills: Vec<Value> = metadata
            .iter()
            .filter(|m| {
                filter.is_none_or(|tag| m.tags.iter().any(|t| t == tag))
            })
            .map(metadata_to_json)
            .collect();
        Ok(json!({
            "count": skills.len(),
            "skills_dir": self.skills_dir.display().to_string(),
            "skills": skills,
        })
        .to_string())
    }
}

pub fn skills_list_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "skills_list".to_string(),
        description: "List available skills (tier-0 progressive disclosure: name + description + \
             tags only, no body). Use 'skill_view' to load a full SKILL.md. Optional 'tag' filter."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "tag": { "type": "string", "description": "Filter skills to those tagged with this value." }
            }
        }),
    }
}

/// `skill_view` — tier-1 full SKILL.md body.
pub struct SkillViewHandler {
    skills_dir: PathBuf,
}

impl SkillViewHandler {
    pub fn new() -> Self {
        Self {
            skills_dir: default_skills_dir(),
        }
    }
}

impl Default for SkillViewHandler {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait::async_trait]
impl ToolHandler for SkillViewHandler {
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        let name = input
            .get("name")
            .and_then(Value::as_str)
            .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'name'".into()))?;
        let metadata_list = scan_skills(&self.skills_dir);
        let metadata = metadata_list
            .iter()
            .find(|m| m.name == name)
            .ok_or_else(|| super::registry::ToolError::NotFound(format!("skill '{name}'")))?;
        let body = fs::read_to_string(&metadata.path).map_err(|e| {
            super::registry::ToolError::ExecutionFailed(format!("read SKILL.md: {e}"))
        })?;
        Ok(json!({
            "name": metadata.name,
            "description": metadata.description,
            "path": metadata.path.display().to_string(),
            "content": body,
            "bytes": body.len(),
        })
        .to_string())
    }
}

pub fn skill_view_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "skill_view".to_string(),
        description: "Load the full SKILL.md body for a specific skill (tier-1 progressive \
             disclosure). Use 'skills_list' to discover names first."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "name": { "type": "string", "description": "Skill name as shown by skills_list." }
            },
            "required": ["name"]
        }),
    }
}

/// `skill_manage` — create/edit/delete with a 15KB cap and frontmatter validation.
pub struct SkillManageHandler {
    skills_dir: PathBuf,
}

impl SkillManageHandler {
    pub fn new() -> Self {
        Self {
            skills_dir: default_skills_dir(),
        }
    }
}

impl Default for SkillManageHandler {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait::async_trait]
impl ToolHandler for SkillManageHandler {
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| {
                super::registry::ToolError::InvalidArguments("missing 'action'".into())
            })?;
        match action {
            "create" => create_skill(&self.skills_dir, input),
            "edit" => edit_skill(&self.skills_dir, input),
            "delete" => delete_skill(&self.skills_dir, input),
            "install_from_github" => install_skill_from_github(&self.skills_dir, input).await,
            "install_from_url" => install_skill_from_url(&self.skills_dir, input).await,
            other => Err(super::registry::ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: create|edit|delete|install_from_github|install_from_url)"
            ))),
        }
    }
}

pub fn skill_manage_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "skill_manage".to_string(),
        description: "Create, edit, delete, or INSTALL a skill. Each SKILL.md must have YAML \
             frontmatter with 'name' and 'description'. 15KB hard cap per SKILL.md. \
             Actions: \n\
             - create: write a brand-new skill with the supplied content.\n\
             - edit: overwrite an existing skill's SKILL.md.\n\
             - delete: remove the skill directory.\n\
             - install_from_github: clone a GitHub repo (git URL) into the skills \
               directory, run the 40-rule security scanner on every SKILL.md, and \
               land it under a quarantine/ subdirectory. The agent must explicitly \
               call this action again with {approve: true} to promote it.\n\
             - install_from_url: fetch a single SKILL.md over HTTPS and land it \
               under quarantine/, same security scan pass."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "edit", "delete", "install_from_github", "install_from_url"]
                },
                "name": { "type": "string", "description": "Skill identifier (required for create/edit/delete)." },
                "content": { "type": "string", "description": "Full SKILL.md content (required for create/edit)." },
                "category": { "type": "string", "description": "Optional category subdirectory." },
                "git_url": { "type": "string", "description": "Git URL (install_from_github). Must be https://github.com/...." },
                "url": { "type": "string", "description": "HTTPS URL to a raw SKILL.md (install_from_url)." },
                "approve": { "type": "boolean", "description": "Set to true to promote an already-quarantined install.", "default": false }
            },
            "required": ["action"]
        }),
    }
}

fn create_skill(
    skills_dir: &Path,
    input: &Value,
) -> Result<String, super::registry::ToolError> {
    let name = input
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'name'".into()))?;
    if let Some(err) = validate_name(name) {
        return Err(super::registry::ToolError::InvalidArguments(err));
    }
    let content = input
        .get("content")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'content'".into()))?;
    if content.len() > MAX_SKILL_BYTES {
        return Err(super::registry::ToolError::InvalidArguments(format!(
            "SKILL.md exceeds {MAX_SKILL_BYTES} byte cap"
        )));
    }
    if let Some(err) = validate_frontmatter(content) {
        return Err(super::registry::ToolError::InvalidArguments(err));
    }

    let target_dir = if let Some(category) = input.get("category").and_then(Value::as_str) {
        if let Some(err) = validate_name(category) {
            return Err(super::registry::ToolError::InvalidArguments(format!(
                "category: {err}"
            )));
        }
        skills_dir.join(category).join(name)
    } else {
        skills_dir.join(name)
    };
    if target_dir.exists() {
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "skill '{name}' already exists"
        )));
    }
    fs::create_dir_all(&target_dir).map_err(|e| {
        super::registry::ToolError::ExecutionFailed(format!("mkdir: {e}"))
    })?;
    let file = target_dir.join("SKILL.md");
    fs::write(&file, content).map_err(|e| {
        super::registry::ToolError::ExecutionFailed(format!("write: {e}"))
    })?;
    Ok(json!({
        "success": true,
        "action": "create",
        "name": name,
        "path": file.display().to_string(),
    })
    .to_string())
}

fn edit_skill(
    skills_dir: &Path,
    input: &Value,
) -> Result<String, super::registry::ToolError> {
    let name = input
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'name'".into()))?;
    let content = input
        .get("content")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'content'".into()))?;
    if content.len() > MAX_SKILL_BYTES {
        return Err(super::registry::ToolError::InvalidArguments(format!(
            "SKILL.md exceeds {MAX_SKILL_BYTES} byte cap"
        )));
    }
    if let Some(err) = validate_frontmatter(content) {
        return Err(super::registry::ToolError::InvalidArguments(err));
    }

    let metadata_list = scan_skills(skills_dir);
    let metadata = metadata_list
        .iter()
        .find(|m| m.name == name)
        .ok_or_else(|| super::registry::ToolError::NotFound(format!("skill '{name}'")))?;
    fs::write(&metadata.path, content)
        .map_err(|e| super::registry::ToolError::ExecutionFailed(format!("write: {e}")))?;
    Ok(json!({
        "success": true,
        "action": "edit",
        "name": name,
        "path": metadata.path.display().to_string(),
    })
    .to_string())
}

fn delete_skill(
    skills_dir: &Path,
    input: &Value,
) -> Result<String, super::registry::ToolError> {
    let name = input
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'name'".into()))?;
    let metadata_list = scan_skills(skills_dir);
    let metadata = metadata_list
        .iter()
        .find(|m| m.name == name)
        .ok_or_else(|| super::registry::ToolError::NotFound(format!("skill '{name}'")))?;
    let skill_dir = metadata
        .path
        .parent()
        .ok_or_else(|| {
            super::registry::ToolError::ExecutionFailed("SKILL.md has no parent".into())
        })?;
    // Safety: refuse to delete anything outside the managed skills dir.
    if !skill_dir.starts_with(skills_dir) {
        return Err(super::registry::ToolError::ExecutionFailed(
            "skill path is outside managed skills directory".into(),
        ));
    }
    fs::remove_dir_all(skill_dir)
        .map_err(|e| super::registry::ToolError::ExecutionFailed(format!("rmdir: {e}")))?;
    Ok(json!({
        "success": true,
        "action": "delete",
        "name": name,
    })
    .to_string())
}

// ── Skill Marketplace: install_from_github + install_from_url ──────────────
//
// Both actions land the fetched SKILL.md under a `quarantine/` subdirectory
// of the managed skills root. The agent (or a human through the UI) must
// re-invoke the action with `approve: true` to move the skill out of
// quarantine into the active directory. Quarantine is the line of defence
// against a malicious upstream skill hijacking the model mid-session.

const GITHUB_HOSTS: &[&str] = &["github.com", "www.github.com"];

async fn install_skill_from_github(
    skills_dir: &Path,
    input: &Value,
) -> Result<String, super::registry::ToolError> {
    let approve = input.get("approve").and_then(Value::as_bool).unwrap_or(false);
    let git_url = input
        .get("git_url")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'git_url'".into()))?;
    // Scheme + host allowlist so we only clone from github.com over https.
    if !git_url.starts_with("https://") {
        return Err(super::registry::ToolError::InvalidArguments(
            "git_url must be https://".into(),
        ));
    }
    let host_ok = GITHUB_HOSTS.iter().any(|h| {
        git_url
            .strip_prefix("https://")
            .map(|rest| rest.starts_with(h))
            .unwrap_or(false)
    });
    if !host_ok {
        return Err(super::registry::ToolError::InvalidArguments(format!(
            "git_url must be on github.com (got: {git_url})"
        )));
    }

    // Derive a safe directory name from the repo URL.
    let repo_slug: String = git_url
        .trim_end_matches(".git")
        .rsplit('/')
        .take(2)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect::<Vec<_>>()
        .join("-")
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || matches!(*c, '-' | '_'))
        .collect();
    if repo_slug.is_empty() {
        return Err(super::registry::ToolError::InvalidArguments(
            "could not derive safe repo slug from git_url".into(),
        ));
    }

    let quarantine_root = skills_dir.join("quarantine");
    let target_dir = quarantine_root.join(&repo_slug);

    // If already quarantined and approve=true, promote it.
    if target_dir.exists() && approve {
        return promote_quarantined(skills_dir, &target_dir, &repo_slug);
    }
    if target_dir.exists() {
        return Ok(json!({
            "success": true,
            "action": "install_from_github",
            "status": "already_quarantined",
            "quarantine_path": target_dir.display().to_string(),
            "next_step": "call again with approve=true to promote out of quarantine",
        })
        .to_string());
    }

    fs::create_dir_all(&quarantine_root).map_err(|e| {
        super::registry::ToolError::ExecutionFailed(format!("mkdir quarantine: {e}"))
    })?;

    // Use git2 which is already a dep (for vault git integration). A full
    // `git clone` via the library avoids shelling out and keeps credential
    // handling off the subprocess environment.
    let clone_result = tokio::task::spawn_blocking({
        let url = git_url.to_string();
        let target = target_dir.clone();
        move || git2::Repository::clone(&url, &target)
    })
    .await
    .map_err(|e| super::registry::ToolError::ExecutionFailed(format!("clone task: {e}")))?;
    if let Err(e) = clone_result {
        // Clean up any partial clone.
        let _ = fs::remove_dir_all(&target_dir);
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "git clone failed: {e}"
        )));
    }

    // Scan every SKILL.md in the cloned tree against the 40-rule security
    // scanner. Any Critical hit halts the install.
    let scan_result = scan_quarantined_tree(&target_dir);
    if scan_result.critical_count > 0 {
        // Leave the quarantined tree on disk so the user can inspect it,
        // but clearly surface the block.
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "security scan blocked install: {} critical threats, {} high; quarantined at {}",
            scan_result.critical_count,
            scan_result.high_count,
            target_dir.display()
        )));
    }

    Ok(json!({
        "success": true,
        "action": "install_from_github",
        "status": "quarantined",
        "quarantine_path": target_dir.display().to_string(),
        "skill_count": scan_result.skill_count,
        "high_severity_warnings": scan_result.high_count,
        "next_step": "call again with approve=true to promote out of quarantine",
    })
    .to_string())
}

async fn install_skill_from_url(
    skills_dir: &Path,
    input: &Value,
) -> Result<String, super::registry::ToolError> {
    let approve = input.get("approve").and_then(Value::as_bool).unwrap_or(false);
    let url = input
        .get("url")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'url'".into()))?;
    let skill_name = input
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| super::registry::ToolError::InvalidArguments("missing 'name'".into()))?;
    if let Some(err) = validate_name(skill_name) {
        return Err(super::registry::ToolError::InvalidArguments(err));
    }
    if !url.starts_with("https://") {
        return Err(super::registry::ToolError::InvalidArguments(
            "url must be https://".into(),
        ));
    }
    if let Err(threat) = crate::security::validate_url_safe(url, false) {
        return Err(super::registry::ToolError::ExecutionFailed(
            threat.description,
        ));
    }

    let quarantine_dir = skills_dir.join("quarantine").join(skill_name);

    if quarantine_dir.exists() && approve {
        return promote_quarantined(skills_dir, &quarantine_dir, skill_name);
    }

    fs::create_dir_all(&quarantine_dir).map_err(|e| {
        super::registry::ToolError::ExecutionFailed(format!("mkdir quarantine: {e}"))
    })?;

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .user_agent("Epistemos/1.0 (SkillInstaller)")
        .build()
        .map_err(|e| super::registry::ToolError::ExecutionFailed(format!("http init: {e}")))?;

    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| super::registry::ToolError::ExecutionFailed(format!("http fetch: {e}")))?;
    if !resp.status().is_success() {
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "http {}",
            resp.status()
        )));
    }
    let body = resp
        .text()
        .await
        .map_err(|e| super::registry::ToolError::ExecutionFailed(format!("http body: {e}")))?;
    if body.len() > MAX_SKILL_BYTES {
        let _ = fs::remove_dir_all(&quarantine_dir);
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "SKILL.md exceeds {MAX_SKILL_BYTES} byte cap"
        )));
    }
    if let Some(err) = validate_frontmatter(&body) {
        let _ = fs::remove_dir_all(&quarantine_dir);
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "frontmatter: {err}"
        )));
    }
    fs::write(quarantine_dir.join("SKILL.md"), &body).map_err(|e| {
        super::registry::ToolError::ExecutionFailed(format!("write: {e}"))
    })?;

    let scan = crate::security::scan_tool_output(&body);
    let critical = scan
        .threats
        .iter()
        .filter(|t| t.severity >= crate::security::Severity::Critical)
        .count();
    let high = scan
        .threats
        .iter()
        .filter(|t| t.severity >= crate::security::Severity::High)
        .count();
    if critical > 0 {
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "security scan blocked install: {critical} critical threats; quarantined at {}",
            quarantine_dir.display()
        )));
    }

    Ok(json!({
        "success": true,
        "action": "install_from_url",
        "status": "quarantined",
        "quarantine_path": quarantine_dir.display().to_string(),
        "high_severity_warnings": high,
        "next_step": "call again with approve=true to promote out of quarantine",
    })
    .to_string())
}

struct QuarantineScanReport {
    skill_count: usize,
    critical_count: usize,
    high_count: usize,
}

fn scan_quarantined_tree(root: &Path) -> QuarantineScanReport {
    let mut report = QuarantineScanReport {
        skill_count: 0,
        critical_count: 0,
        high_count: 0,
    };
    for entry in walkdir::WalkDir::new(root).into_iter().flatten() {
        if !entry.file_type().is_file() {
            continue;
        }
        let name = entry
            .file_name()
            .to_str()
            .unwrap_or("");
        if !name.eq_ignore_ascii_case("SKILL.md") && !name.ends_with(".md") {
            continue;
        }
        let Ok(content) = fs::read_to_string(entry.path()) else {
            continue;
        };
        report.skill_count += 1;
        let scan = crate::security::scan_tool_output(&content);
        for threat in &scan.threats {
            if threat.severity >= crate::security::Severity::Critical {
                report.critical_count += 1;
            } else if threat.severity >= crate::security::Severity::High {
                report.high_count += 1;
            }
        }
    }
    report
}

fn promote_quarantined(
    skills_dir: &Path,
    quarantine_path: &Path,
    name: &str,
) -> Result<String, super::registry::ToolError> {
    let target = skills_dir.join(name);
    if target.exists() {
        return Err(super::registry::ToolError::ExecutionFailed(format!(
            "a skill named '{name}' already exists in the active directory"
        )));
    }
    fs::rename(quarantine_path, &target).map_err(|e| {
        super::registry::ToolError::ExecutionFailed(format!("promote: {e}"))
    })?;
    Ok(json!({
        "success": true,
        "action": "promote",
        "name": name,
        "path": target.display().to_string(),
    })
    .to_string())
}

#[cfg(test)]
mod progressive_tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    fn make_skill_file(dir: &Path, name: &str, description: &str) {
        let skill_dir = dir.join(name);
        fs::create_dir_all(&skill_dir).unwrap();
        let md = format!(
            "---\nname: {name}\ndescription: {description}\nmetadata:\n  epistemos:\n    category: test\n    tags: [example, test]\n    requires_tools: [terminal]\n---\n# {name}\n\nBody content.\n"
        );
        fs::write(skill_dir.join("SKILL.md"), md).unwrap();
    }

    #[tokio::test]
    async fn skills_list_returns_tier_zero_metadata() {
        let dir = tempdir().unwrap();
        make_skill_file(dir.path(), "alpha", "alpha skill");
        make_skill_file(dir.path(), "beta", "beta skill");

        let handler = SkillsListHandler {
            skills_dir: dir.path().to_path_buf(),
        };
        let result = handler.execute(&json!({})).await.unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(2));
        let skills = parsed["skills"].as_array().unwrap();
        assert!(skills.iter().any(|s| s["name"] == "alpha"));
        assert!(skills.iter().any(|s| s["name"] == "beta"));
        assert!(skills[0]["tags"].as_array().unwrap().contains(&json!("test")));
    }

    #[tokio::test]
    async fn skill_view_returns_full_body() {
        let dir = tempdir().unwrap();
        make_skill_file(dir.path(), "gamma", "gamma skill");

        let handler = SkillViewHandler {
            skills_dir: dir.path().to_path_buf(),
        };
        let result = handler
            .execute(&json!({ "name": "gamma" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["name"], json!("gamma"));
        assert!(parsed["content"]
            .as_str()
            .unwrap()
            .contains("# gamma"));
    }

    #[tokio::test]
    async fn skill_view_errors_on_missing_name() {
        let dir = tempdir().unwrap();
        let handler = SkillViewHandler {
            skills_dir: dir.path().to_path_buf(),
        };
        let err = handler
            .execute(&json!({ "name": "ghost" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("ghost"));
    }

    #[tokio::test]
    async fn skill_manage_create_edit_delete_roundtrip() {
        let dir = tempdir().unwrap();
        let handler = SkillManageHandler {
            skills_dir: dir.path().to_path_buf(),
        };
        let content = "---\nname: zeta\ndescription: zeta skill\n---\n# zeta\nbody\n";
        let created = handler
            .execute(&json!({
                "action": "create",
                "name": "zeta",
                "content": content,
            }))
            .await
            .unwrap();
        assert!(created.contains("\"success\":true"));

        let new_content = "---\nname: zeta\ndescription: zeta skill v2\n---\n# zeta v2\nbody\n";
        let edited = handler
            .execute(&json!({
                "action": "edit",
                "name": "zeta",
                "content": new_content,
            }))
            .await
            .unwrap();
        assert!(edited.contains("\"success\":true"));

        let deleted = handler
            .execute(&json!({ "action": "delete", "name": "zeta" }))
            .await
            .unwrap();
        assert!(deleted.contains("\"success\":true"));
        assert!(!dir.path().join("zeta").exists());
    }

    #[tokio::test]
    async fn skill_manage_rejects_missing_frontmatter() {
        let dir = tempdir().unwrap();
        let handler = SkillManageHandler {
            skills_dir: dir.path().to_path_buf(),
        };
        let err = handler
            .execute(&json!({
                "action": "create",
                "name": "bad",
                "content": "# no frontmatter"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("frontmatter"));
    }

    #[tokio::test]
    async fn skill_manage_enforces_size_cap() {
        let dir = tempdir().unwrap();
        let handler = SkillManageHandler {
            skills_dir: dir.path().to_path_buf(),
        };
        let big_body = "x".repeat(MAX_SKILL_BYTES);
        let content = format!("---\nname: big\ndescription: too big\n---\n{big_body}\n");
        let err = handler
            .execute(&json!({
                "action": "create",
                "name": "big",
                "content": content,
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("cap"));
    }
}
