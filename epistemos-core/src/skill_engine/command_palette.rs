// Slash-command palette.
//
// Maps slash commands (/plan, /research, /review, etc.) to skill activations.
// Provides command parsing, argument extraction, and registry lookup.
//
// Commands are registered from two sources:
//   1. Built-in commands (hardcoded, always available)
//   2. Skill-derived commands (from SKILL.md trigger patterns)

use std::collections::HashMap;

/// A registered slash command.
#[derive(Debug, Clone)]
pub struct SlashCommand {
    /// Command name without the leading slash (e.g., "research").
    pub name: String,
    /// Short description shown in the palette.
    pub description: String,
    /// Category for grouping in the UI.
    pub category: CommandCategory,
    /// The skill name this command activates (if skill-backed).
    pub skill_name: Option<String>,
    /// Whether this command requires arguments.
    pub requires_args: bool,
    /// Placeholder text for the argument input.
    pub arg_placeholder: String,
}

/// Command categories for UI grouping.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CommandCategory {
    Agent,
    Research,
    Writing,
    Development,
    Navigation,
}

impl CommandCategory {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Agent => "Agent",
            Self::Research => "Research",
            Self::Writing => "Writing",
            Self::Development => "Development",
            Self::Navigation => "Navigation",
        }
    }

    pub fn all() -> &'static [CommandCategory] {
        &[
            CommandCategory::Agent,
            CommandCategory::Research,
            CommandCategory::Writing,
            CommandCategory::Development,
            CommandCategory::Navigation,
        ]
    }
}

/// Parsed slash command from user input.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedCommand {
    /// Command name without slash.
    pub command: String,
    /// Everything after the command name.
    pub args: String,
    /// Named flags (e.g., --deep → "deep": "true").
    pub flags: HashMap<String, String>,
}

/// The command palette registry.
pub struct CommandPalette {
    commands: HashMap<String, SlashCommand>,
}

impl CommandPalette {
    /// Create a new palette with built-in commands.
    pub fn new() -> Self {
        let mut palette = Self {
            commands: HashMap::new(),
        };
        palette.register_builtins();
        palette
    }

    /// Register a command.
    pub fn register(&mut self, cmd: SlashCommand) {
        self.commands.insert(cmd.name.clone(), cmd);
    }

    /// Register commands from skill catalog entries.
    pub fn register_from_skills(&mut self, skills: &[super::manifest::SkillCatalogEntry]) {
        for skill in skills {
            for trigger in &skill.triggers {
                let name = trigger.trim_start_matches('/');
                if name.is_empty() {
                    continue;
                }
                // Don't overwrite built-in commands
                if self.commands.contains_key(name) {
                    continue;
                }
                self.register(SlashCommand {
                    name: name.to_string(),
                    description: skill.description.clone(),
                    category: category_from_skill(&skill.category),
                    skill_name: Some(skill.name.clone()),
                    requires_args: true,
                    arg_placeholder: format!("What to {}...", name),
                });
            }
        }
    }

    /// Look up a command by name.
    pub fn get(&self, name: &str) -> Option<&SlashCommand> {
        self.commands.get(name)
    }

    /// List all commands, optionally filtered by category.
    pub fn list(&self, category: Option<CommandCategory>) -> Vec<&SlashCommand> {
        let mut cmds: Vec<&SlashCommand> = self
            .commands
            .values()
            .filter(|cmd| category.is_none_or(|cat| cmd.category == cat))
            .collect();
        cmds.sort_by(|a, b| a.name.cmp(&b.name));
        cmds
    }

    /// Fuzzy-match commands by prefix.
    pub fn search(&self, prefix: &str) -> Vec<&SlashCommand> {
        let lower = prefix.to_lowercase();
        let mut matches: Vec<&SlashCommand> = self
            .commands
            .values()
            .filter(|cmd| {
                cmd.name.starts_with(&lower) || cmd.description.to_lowercase().contains(&lower)
            })
            .collect();
        matches.sort_by(|a, b| {
            // Prefer exact prefix matches
            let a_prefix = a.name.starts_with(&lower) as u8;
            let b_prefix = b.name.starts_with(&lower) as u8;
            b_prefix.cmp(&a_prefix).then(a.name.cmp(&b.name))
        });
        matches
    }

    /// Number of registered commands.
    pub fn count(&self) -> usize {
        self.commands.len()
    }

    // ── Built-in Commands ──

    fn register_builtins(&mut self) {
        let builtins = vec![
            SlashCommand {
                name: "plan".into(),
                description: "Create a structured plan for a task".into(),
                category: CommandCategory::Agent,
                skill_name: None,
                requires_args: true,
                arg_placeholder: "Describe what to plan...".into(),
            },
            SlashCommand {
                name: "research".into(),
                description: "Deep research on a topic using vault and web".into(),
                category: CommandCategory::Research,
                skill_name: None,
                requires_args: true,
                arg_placeholder: "What to research...".into(),
            },
            SlashCommand {
                name: "review".into(),
                description: "Review and analyze notes or code".into(),
                category: CommandCategory::Research,
                skill_name: None,
                requires_args: true,
                arg_placeholder: "What to review...".into(),
            },
            SlashCommand {
                name: "summarize".into(),
                description: "Summarize notes or documents".into(),
                category: CommandCategory::Writing,
                skill_name: None,
                requires_args: true,
                arg_placeholder: "What to summarize...".into(),
            },
            SlashCommand {
                name: "draft".into(),
                description: "Draft new content based on vault knowledge".into(),
                category: CommandCategory::Writing,
                skill_name: None,
                requires_args: true,
                arg_placeholder: "What to draft...".into(),
            },
            SlashCommand {
                name: "debug".into(),
                description: "Debug an issue with agent assistance".into(),
                category: CommandCategory::Development,
                skill_name: None,
                requires_args: true,
                arg_placeholder: "Describe the issue...".into(),
            },
            SlashCommand {
                name: "status".into(),
                description: "Show agent status, cost, and session info".into(),
                category: CommandCategory::Navigation,
                skill_name: None,
                requires_args: false,
                arg_placeholder: String::new(),
            },
            SlashCommand {
                name: "help".into(),
                description: "List available commands".into(),
                category: CommandCategory::Navigation,
                skill_name: None,
                requires_args: false,
                arg_placeholder: String::new(),
            },
        ];

        for cmd in builtins {
            self.register(cmd);
        }
    }
}

impl Default for CommandPalette {
    fn default() -> Self {
        Self::new()
    }
}

/// Parse user input into a command if it starts with "/".
pub fn parse_slash_command(input: &str) -> Option<ParsedCommand> {
    let trimmed = input.trim();
    if !trimmed.starts_with('/') {
        return None;
    }

    let without_slash = &trimmed[1..];
    let mut parts = without_slash.splitn(2, char::is_whitespace);
    let command = parts.next()?.to_lowercase();
    let rest = parts.next().unwrap_or("").trim().to_string();

    if command.is_empty() {
        return None;
    }

    // Extract flags (--key value or --flag)
    let mut flags = HashMap::new();
    let mut args_parts = Vec::new();
    let words = rest.split_whitespace().peekable();

    for word in words {
        if let Some(eq_pos) = word
            .strip_prefix("--")
            .and_then(|w| w.find('=').map(|p| p + 2))
        {
            // --key=value form
            let key = word[2..eq_pos].to_string();
            let value = word[eq_pos + 1..].to_string();
            flags.insert(key, value);
        } else if let Some(stripped) = word.strip_prefix("--") {
            // --flag form (boolean, don't consume next word)
            let key = stripped.to_string();
            if !key.is_empty() {
                flags.insert(key, "true".to_string());
            }
        } else {
            args_parts.push(word);
        }
    }

    let args = args_parts.join(" ");

    Some(ParsedCommand {
        command,
        args,
        flags,
    })
}

/// Map a skill category string to a CommandCategory.
fn category_from_skill(skill_category: &str) -> CommandCategory {
    match skill_category.to_lowercase().as_str() {
        "research" => CommandCategory::Research,
        "writing" | "draft" => CommandCategory::Writing,
        "development" | "dev" | "code" => CommandCategory::Development,
        _ => CommandCategory::Agent,
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_command() {
        let parsed = parse_slash_command("/research quantum computing").unwrap();
        assert_eq!(parsed.command, "research");
        assert_eq!(parsed.args, "quantum computing");
        assert!(parsed.flags.is_empty());
    }

    #[test]
    fn test_parse_command_with_flags() {
        let parsed = parse_slash_command("/research --deep quantum computing").unwrap();
        assert_eq!(parsed.command, "research");
        assert_eq!(parsed.args, "quantum computing");
        assert_eq!(parsed.flags.get("deep"), Some(&"true".to_string()));
    }

    #[test]
    fn test_parse_command_with_value_flag() {
        let parsed = parse_slash_command("/plan --depth=medium fix the bug").unwrap();
        assert_eq!(parsed.command, "plan");
        assert_eq!(parsed.args, "fix the bug");
        assert_eq!(parsed.flags.get("depth"), Some(&"medium".to_string()));
    }

    #[test]
    fn test_parse_no_args() {
        let parsed = parse_slash_command("/status").unwrap();
        assert_eq!(parsed.command, "status");
        assert_eq!(parsed.args, "");
    }

    #[test]
    fn test_parse_not_a_command() {
        assert!(parse_slash_command("hello world").is_none());
        assert!(parse_slash_command("").is_none());
        assert!(parse_slash_command("/ ").is_none());
    }

    #[test]
    fn test_palette_builtins() {
        let palette = CommandPalette::new();
        assert!(palette.count() >= 8);
        assert!(palette.get("plan").is_some());
        assert!(palette.get("research").is_some());
        assert!(palette.get("review").is_some());
        assert!(palette.get("help").is_some());
    }

    #[test]
    fn test_palette_list_by_category() {
        let palette = CommandPalette::new();
        let research_cmds = palette.list(Some(CommandCategory::Research));
        assert!(research_cmds.len() >= 2); // research + review
        assert!(research_cmds
            .iter()
            .all(|c| c.category == CommandCategory::Research));
    }

    #[test]
    fn test_palette_search() {
        let palette = CommandPalette::new();
        let matches = palette.search("res");
        assert!(!matches.is_empty());
        assert!(matches[0].name.starts_with("res")); // "research" should be first
    }

    #[test]
    fn test_palette_search_by_description() {
        let palette = CommandPalette::new();
        let matches = palette.search("vault");
        assert!(!matches.is_empty()); // "research" mentions vault
    }

    #[test]
    fn test_register_from_skills() {
        use super::super::manifest::SkillCatalogEntry;
        use std::path::PathBuf;

        let mut palette = CommandPalette::new();
        let skills = vec![SkillCatalogEntry {
            name: "custom-analysis".into(),
            description: "Custom data analysis".into(),
            category: "research".into(),
            triggers: vec!["/analyze".into()],
            version: 1,
            source_path: PathBuf::from("test.md"),
        }];

        palette.register_from_skills(&skills);
        let cmd = palette.get("analyze");
        assert!(cmd.is_some());
        assert_eq!(cmd.unwrap().skill_name.as_deref(), Some("custom-analysis"));
    }

    #[test]
    fn test_skill_commands_dont_overwrite_builtins() {
        use super::super::manifest::SkillCatalogEntry;
        use std::path::PathBuf;

        let mut palette = CommandPalette::new();
        let skills = vec![SkillCatalogEntry {
            name: "custom-research".into(),
            description: "My custom research".into(),
            category: "research".into(),
            triggers: vec!["/research".into()], // Same as builtin
            version: 1,
            source_path: PathBuf::from("test.md"),
        }];

        palette.register_from_skills(&skills);
        let cmd = palette.get("research").unwrap();
        // Should still be the builtin (no skill_name)
        assert!(cmd.skill_name.is_none());
    }

    #[test]
    fn test_command_category_as_str() {
        assert_eq!(CommandCategory::Agent.as_str(), "Agent");
        assert_eq!(CommandCategory::Research.as_str(), "Research");
        assert_eq!(CommandCategory::Writing.as_str(), "Writing");
    }

    #[test]
    fn test_command_category_all() {
        assert_eq!(CommandCategory::all().len(), 5);
    }

    #[test]
    fn test_parse_case_insensitive() {
        let parsed = parse_slash_command("/RESEARCH quantum").unwrap();
        assert_eq!(parsed.command, "research");
    }
}
