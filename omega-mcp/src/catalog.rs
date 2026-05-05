// Built-in tool catalog for Epistemos.
// This is the single source of truth for all agent tool definitions.
// Swift reads from here via `list_tools_json()` instead of maintaining a parallel list.

use crate::types::{SafetyInfo, ToolDefinition};

macro_rules! tool {
    ($name:expr, $agent:expr, $desc:expr, $example:expr, $schema:expr) => {
        ToolDefinition {
            name: $name.to_string(),
            agent: $agent.to_string(),
            description: $desc.to_string(),
            input_schema_json: $schema.to_string(),
            arguments_example: $example.to_string(),
            safety: SafetyInfo {
                destructive: false,
                requires_confirmation: false,
                scoped_to_apps: vec![],
            },
        }
    };
    ($name:expr, $agent:expr, $desc:expr, $example:expr, $schema:expr, destructive) => {
        ToolDefinition {
            name: $name.to_string(),
            agent: $agent.to_string(),
            description: $desc.to_string(),
            input_schema_json: $schema.to_string(),
            arguments_example: $example.to_string(),
            safety: SafetyInfo {
                destructive: true,
                requires_confirmation: true,
                scoped_to_apps: vec![],
            },
        }
    };
}

/// Returns the canonical list of all built-in Epistemos tools.
pub fn builtin_tools() -> Vec<ToolDefinition> {
    let mut tools = vec![
        // ── Safari Agent ──────────────────────────────────────────────────
        tool!(
            "open_url", "safari",
            "Open a URL in Safari",
            r#"{"url": "https://..."}"#,
            r#"{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}"#
        ),
        tool!(
            "get_page_url", "safari",
            "Get the URL of Safari's current tab",
            "{}",
            r#"{"type":"object","properties":{}}"#
        ),
        tool!(
            "get_page_title", "safari",
            "Get the title of Safari's current tab",
            "{}",
            r#"{"type":"object","properties":{}}"#
        ),
        tool!(
            "search_web", "safari",
            "Search the web via Google in Safari",
            r#"{"query": "search terms"}"#,
            r#"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#
        ),
        tool!(
            "readpagecontent", "safari",
            "Extract the visible text content of Safari's current tab. Use after open_url or search_web",
            r#"{"maxLength": 4000}"#,
            r#"{"type":"object","properties":{"maxLength":{"type":"integer","description":"Max characters to return, default 4000"}}}"#
        ),
        tool!(
            "searchpapers", "safari",
            "Search academic papers on Semantic Scholar. Returns titles, authors, year, citation count",
            r#"{"query": "transformer attention mechanisms"}"#,
            r#"{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","description":"Max results, default 5"},"yearMin":{"type":"integer","description":"Minimum publication year"}},"required":["query"]}"#
        ),
        // ── File Agent ────────────────────────────────────────────────────
        tool!(
            "read_file", "file",
            "Read a file from the vault",
            r#"{"path": "relative/path.md"}"#,
            r#"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#
        ),
        tool!(
            "write_file", "file",
            "Write content to a file in the vault",
            r#"{"path": "relative/path.md", "content": "..."}"#,
            r#"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#
        ),
        tool!(
            "list_files", "file",
            "List files in a vault directory",
            r#"{"path": "."}"#,
            r#"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#
        ),
        tool!(
            "move_file", "file",
            "Move a file within the vault",
            r#"{"path": "old.md", "destination": "new.md"}"#,
            r#"{"type":"object","properties":{"path":{"type":"string"},"destination":{"type":"string"}},"required":["path","destination"]}"#
        ),
        tool!(
            "delete_file", "file",
            "Delete a file from the vault",
            r#"{"path": "relative/path.md"}"#,
            r#"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
            destructive
        ),
        // ── Notes Agent ───────────────────────────────────────────────────
        tool!(
            "create_note", "notes",
            "Create a new Epistemos note",
            r#"{"title": "...", "body": "..."}"#,
            r#"{"type":"object","properties":{"title":{"type":"string"},"body":{"type":"string"}},"required":["title"]}"#
        ),
        tool!(
            "edit_note", "notes",
            "Edit an existing note",
            r#"{"id": "page-uuid", "body": "new content"}"#,
            r#"{"type":"object","properties":{"id":{"type":"string"},"body":{"type":"string"}},"required":["id"]}"#
        ),
        tool!(
            "search_notes", "notes",
            "Search notes by content",
            r#"{"query": "search terms"}"#,
            r#"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#
        ),
        tool!(
            "list_notes", "notes",
            "List all notes",
            "{}",
            r#"{"type":"object","properties":{}}"#
        ),
        tool!(
            "collectsnippet", "notes",
            "Save a quoted passage from a source into a research session note",
            r#"{"text": "quoted passage", "sourceUrl": "https://...", "sourceTitle": "Page Title"}"#,
            r#"{"type":"object","properties":{"text":{"type":"string"},"sourceUrl":{"type":"string"},"sourceTitle":{"type":"string"},"sessionNoteId":{"type":"string"}},"required":["text","sourceUrl"]}"#
        ),
        tool!(
            "savecitation", "notes",
            "Save a formal citation to the vault: title, authors, URL, publication date",
            r#"{"title": "Paper Title", "authors": "Smith et al.", "url": "https://..."}"#,
            r#"{"type":"object","properties":{"title":{"type":"string"},"authors":{"type":"string"},"url":{"type":"string"},"date":{"type":"string"},"sessionNoteId":{"type":"string"}},"required":["title","url"]}"#
        ),
        tool!(
            "createresearchnote", "notes",
            "Create a structured research note with question, findings, evidence, contradictions, and citations",
            r#"{"question": "...", "findings": "..."}"#,
            r#"{"type":"object","properties":{"question":{"type":"string"},"findings":{"type":"string"},"evidence":{"type":"array","items":{"type":"string"}},"contradictions":{"type":"array","items":{"type":"string"}},"citations":{"type":"array","items":{"type":"string"}}},"required":["question","findings"]}"#
        ),
        tool!(
            "analyzecontradiction", "notes",
            "Compare two text snippets and return whether they agree, contradict, or are orthogonal",
            r#"{"snippetA": "...", "snippetB": "..."}"#,
            r#"{"type":"object","properties":{"snippetA":{"type":"string"},"snippetB":{"type":"string"},"sessionNoteId":{"type":"string"}},"required":["snippetA","snippetB"]}"#
        ),
        tool!(
            "scoreevidence", "notes",
            "Score the reliability of a source: arxiv preprint, peer-reviewed, news, blog, primary data",
            r#"{"url": "https://arxiv.org/..."}"#,
            r#"{"type":"object","properties":{"url":{"type":"string"},"sourceType":{"type":"string","enum":["arxiv","peer_reviewed","news","blog","primary","unknown"]}},"required":["url"]}"#
        ),
        // ── Terminal Agent ────────────────────────────────────────────────
        tool!(
            "run_command", "terminal",
            "Execute a shell command (allow-listed only, ephemeral)",
            r#"{"command": "ls -la"}"#,
            r#"{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}"#
        ),
        tool!(
            "run_persistent", "terminal",
            "Execute a command in a persistent PTY session. Working directory and environment persist between calls. Supports git, npm, cargo, xcodebuild, and more.",
            r#"{"command": "git status", "timeout_ms": 30000}"#,
            r#"{"type":"object","properties":{"command":{"type":"string","description":"Shell command to execute"},"timeout_ms":{"type":"integer","default":30000,"maximum":120000,"description":"Timeout in milliseconds"}},"required":["command"]}"#
        ),
        // ── Automation Agent ──────────────────────────────────────────────
        tool!(
            "get_ui_tree", "automation",
            "Get the accessibility tree for an app by name or PID",
            r#"{"app": "AppName"}"#,
            r#"{"type":"object","properties":{"app":{"type":"string","description":"App name (case-insensitive)"},"pid":{"type":"integer","description":"Process ID"}}}"#
        ),
        tool!(
            "click_element", "automation",
            "Click a UI element by name or screen coordinates",
            r#"{"app": "AppName", "element": "Button Name"}"#,
            r#"{"type":"object","properties":{"app":{"type":"string","description":"App name for semantic click"},"pid":{"type":"integer","description":"Process ID for semantic click"},"element":{"type":"string","description":"Element name to click"},"x":{"type":"number","description":"Screen X coordinate"},"y":{"type":"number","description":"Screen Y coordinate"}}}"#
        ),
        tool!(
            "type_text", "automation",
            "Type text via simulated keyboard input",
            r#"{"text": "..."}"#,
            r#"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#
        ),
        tool!(
            "press_key", "automation",
            "Press a key with optional modifiers",
            r#"{"key_code": 36, "modifiers": 0}"#,
            r#"{"type":"object","properties":{"key_code":{"type":"integer","description":"macOS virtual key code (e.g. 36=Return, 49=Space)"},"modifiers":{"type":"integer","description":"CGEventFlags bitmask (e.g. 256=Shift, 1048576=Cmd)"}},"required":["key_code"]}"#
        ),
        tool!(
            "run_shortcut", "automation",
            "Execute a named macOS Shortcut",
            r#"{"name": "shortcut-name"}"#,
            r#"{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}"#
        ),
        // ── Computer Agent (Ghost OS-style) ──────────────────────────────
        tool!(
            "see", "computer",
            "View the accessibility tree and screen state of an app. Returns structured JSON with all interactive elements, their roles, titles, and positions. Use before click/type to understand current UI state.",
            r#"{"app": "Safari"}"#,
            r#"{"type":"object","properties":{"app":{"type":"string","description":"App name (case-insensitive)"},"pid":{"type":"integer","description":"Process ID (alternative to app name)"}}}"#
        ),
        tool!(
            "click", "computer",
            "Click a UI element by name (fuzzy match) or screen coordinates. Prefers AX-first semantic click via AXorcist, falls back to coordinate click.",
            r#"{"app": "Safari", "element": "Downloads"}"#,
            r#"{"type":"object","properties":{"app":{"type":"string","description":"Target app name"},"element":{"type":"string","description":"Element title to click (fuzzy matched)"},"x":{"type":"number","description":"Screen X coordinate for direct click"},"y":{"type":"number","description":"Screen Y coordinate for direct click"}}}"#
        ),
        tool!(
            "type", "computer",
            "Type text into the focused element via simulated keyboard input. Focus the target field first with click.",
            r#"{"text": "hello world"}"#,
            r#"{"type":"object","properties":{"text":{"type":"string","description":"Text to type"}},"required":["text"]}"#
        ),
        tool!(
            "scroll", "computer",
            "Scroll a window or element. Direction: up, down, left, right. Amount is in scroll wheel units (default 3).",
            r#"{"direction": "down", "amount": 3}"#,
            r#"{"type":"object","properties":{"direction":{"type":"string","enum":["up","down","left","right"],"description":"Scroll direction"},"amount":{"type":"integer","description":"Scroll units (default 3)"},"x":{"type":"number","description":"X coordinate to scroll at"},"y":{"type":"number","description":"Y coordinate to scroll at"}},"required":["direction"]}"#
        ),
        tool!(
            "keys", "computer",
            "Press keyboard keys with optional modifiers. Supports named keys (return, space, tab, escape, delete, up, down, left, right) or virtual key codes.",
            r#"{"key": "return", "modifiers": ["cmd"]}"#,
            r#"{"type":"object","properties":{"key":{"type":"string","description":"Key name or virtual key code"},"modifiers":{"type":"array","items":{"type":"string","enum":["cmd","shift","option","control"]},"description":"Modifier keys to hold"}},"required":["key"]}"#
        ),
        tool!(
            "screenshot", "computer",
            "Capture a screenshot of a specific app window or the frontmost window. Returns base64-encoded PNG image data.",
            r#"{"app": "Safari"}"#,
            r#"{"type":"object","properties":{"app":{"type":"string","description":"Target app (optional, captures frontmost window if omitted)"}}}"#
        ),
    ];
    tools.extend(crate::graph_tools::builtin_graph_tools());
    tools
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builtin_catalog_has_all_agents() {
        let tools = builtin_tools();
        assert!(
            tools.len() >= 32,
            "expected at least 32 tools, got {}",
            tools.len()
        );

        let agents: std::collections::HashSet<&str> =
            tools.iter().map(|t| t.agent.as_str()).collect();
        assert!(agents.contains("safari"), "missing safari agent");
        assert!(agents.contains("file"), "missing file agent");
        assert!(agents.contains("notes"), "missing notes agent");
        assert!(agents.contains("terminal"), "missing terminal agent");
        assert!(agents.contains("automation"), "missing automation agent");
        assert!(agents.contains("computer"), "missing computer agent");
    }

    #[test]
    fn builtin_tool_names_are_unique() {
        let tools = builtin_tools();
        let mut names = std::collections::HashSet::new();
        for tool in &tools {
            assert!(
                names.insert(tool.name.as_str()),
                "duplicate tool name: {}",
                tool.name
            );
        }
    }

    #[test]
    fn all_schemas_are_valid_json() {
        let tools = builtin_tools();
        for tool in &tools {
            let parsed: Result<serde_json::Value, _> =
                serde_json::from_str(&tool.input_schema_json);
            assert!(
                parsed.is_ok(),
                "invalid schema JSON for tool {}: {}",
                tool.name,
                tool.input_schema_json
            );
        }
    }

    #[test]
    fn destructive_tools_require_confirmation() {
        let tools = builtin_tools();
        for tool in &tools {
            if tool.safety.destructive {
                assert!(
                    tool.safety.requires_confirmation,
                    "destructive tool {} should require confirmation",
                    tool.name
                );
            }
        }
    }

    #[test]
    fn builtin_catalog_exposes_d2_graph_verbs() {
        let tools = builtin_tools();
        let names: std::collections::HashSet<&str> =
            tools.iter().map(|tool| tool.name.as_str()).collect();

        for expected in [
            "graph.search_semantic",
            "graph.search_fulltext",
            "graph.get_node",
            "graph.traverse",
            "graph.create_node",
            "graph.create_edge",
            "graph.commit_session",
        ] {
            assert!(names.contains(expected), "missing D2 graph tool {expected}");
        }
    }
}
