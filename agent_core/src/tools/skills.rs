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
const MAX_DESCRIPTION_LENGTH: usize = 1024;
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
