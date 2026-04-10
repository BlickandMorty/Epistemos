# Skill Implementation Plan — For Codex/Claude

> This document is designed to be read by an AI coding agent. It contains everything needed
> to implement the full tool/skill system for Epistemos without asking clarifying questions.
>
> **Before writing any code, read these files in this exact order:**
> 1. `agent_core/src/tools/registry.rs` — tool registration patterns
> 2. `agent_core/src/tools/think.rs` — simplest tool example
> 3. `agent_core/src/tools/delegate_task.rs` — complex tool example
> 4. `agent_core/src/bridge.rs` — FFI bridge to Swift (UniFFI)
> 5. `agent_core/src/agent_loop.rs` — how tools are dispatched
> 6. `agent_core/src/storage/vault.rs` — VaultBackend trait
> 7. `agent_core/Cargo.toml` — existing dependencies
>
> **Reference docs:**
> - `docs/SKILL_PORT_MASTER_REFERENCE.md` — every skill from Hermes + OpenClaw with porting notes
> - `docs/EPISTEMOS_SPECIALTIES.md` — 19 unique abilities with tool schemas

---

## Part 0: Architecture Conventions (MUST follow)

### How tools work in this codebase

```
Swift UI → (UniFFI) → run_agent_session() → agent_loop → provider.stream_message(tools: Vec<ToolSchema>)
                                                          ↓ StopReason::ToolUse
                                                          → extract_tool_calls()
                                                          → execute_one_tool()
                                                          → tool_registry.execute(name, input)
                                                          → handler.execute(&Value) → Result<String, ToolError>
                                                          → delegate.on_tool_completed()
                                                          → Message::user_tool_results(results)
                                                          → next turn
```

### To add a new tool, you MUST:

1. Create a file in `agent_core/src/tools/` (e.g., `filesystem.rs`)
2. Define a handler struct implementing `ToolHandler`:
   ```rust
   use async_trait::async_trait;
   use serde_json::Value;
   use crate::tools::registry::{ToolHandler, ToolError};

   pub struct ReadFileHandler;

   #[async_trait]
   impl ToolHandler for ReadFileHandler {
       async fn execute(&self, input: &Value) -> Result<String, ToolError> {
           let path = input["path"].as_str()
               .ok_or_else(|| ToolError::InvalidArguments("missing 'path'".into()))?;
           // ... implementation ...
           Ok(serde_json::json!({ "content": content, "total_lines": total }).to_string())
       }
   }
   ```

3. Define the tool schema (OpenAI function-format):
   ```rust
   use serde_json::json;
   use crate::types::ToolSchema;

   pub fn read_file_schema() -> ToolSchema {
       ToolSchema {
           name: "read_file".to_string(),
           description: "Read a text file with line numbers and pagination".to_string(),
           parameters: json!({
               "type": "object",
               "properties": {
                   "path": { "type": "string", "description": "File path (absolute or relative)" },
                   "offset": { "type": "integer", "description": "Start line (1-indexed)", "default": 1 },
                   "limit": { "type": "integer", "description": "Max lines to read", "default": 500 }
               },
               "required": ["path"]
           }),
       }
   }
   ```

4. Add a `register_*` method on `ToolRegistry` in `registry.rs`:
   ```rust
   fn register_read_file(&mut self) {
       self.register(RegisteredTool {
           name: "read_file".to_string(),
           description: "Read a text file with line numbers and pagination".to_string(),
           parameters: read_file_schema().parameters,
           handler: Box::new(ReadFileHandler),
           risk_level: RiskLevel::ReadOnly,
       });
   }
   ```

5. Call it from `register_default_tools()` in `registry.rs`
6. Add `pub mod filesystem;` to `agent_core/src/tools/mod.rs` (or `lib.rs` tools module)

### Error handling rules
- Tool input validation: `ToolError::InvalidArguments("description".into())`
- Execution failures: `ToolError::ExecutionFailed("what went wrong".into())`
- NEVER panic in a tool handler. Use `Result` everywhere.
- Return JSON strings from `execute()`. Use `serde_json::json!({...}).to_string()`

### Risk levels
- `RiskLevel::ReadOnly` — auto-approved (search, read, query)
- `RiskLevel::Modification` — configurable (write, edit, create)
- `RiskLevel::Destructive` — always requires permission (delete, shell exec)

### FFI bridge for Swift-dependent tools
Some tools need Swift capabilities (AX, ScreenCaptureKit, MLX, EventKit). These work via
the `AgentEventDelegate` callback interface. Currently `execute_computer_action` is the only
Swift callback for tool execution. To add more:

1. Add a new method to `AgentEventDelegate` trait in `bridge.rs`:
   ```rust
   fn execute_vault_recall(&self, query_json: String) -> String;
   ```
2. Implement it in Swift's `StreamingDelegate.swift`
3. Pass the delegate `Arc` into the tool handler struct
4. Call it from the handler: `self.delegate.execute_vault_recall(json)`

### Output format
Tool results are truncated to 16,384 chars by the agent loop (`agent_loop.rs`).
Credential redaction runs on all outputs (`security::redact_credentials`).
Return structured JSON strings, not plain text.

---

## Part 1: Phase 1 — Core Tools (Sprint 1, ~2 weeks)

**Goal:** 12 foundational tools that every agent needs. Most are pure Rust with no Swift dependency.

### 1.1 `read_file`

**File:** `agent_core/src/tools/filesystem.rs`
**Risk:** ReadOnly
**Deps:** `std::fs`, `std::io::BufRead`

**Implementation:**
```rust
pub struct ReadFileHandler;

#[async_trait]
impl ToolHandler for ReadFileHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path = input["path"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("missing 'path'".into()))?;
        let offset = input["offset"].as_u64().unwrap_or(1).max(1) as usize;
        let limit = input["limit"].as_u64().unwrap_or(500).min(2000) as usize;

        // Resolve ~ to home directory
        let resolved = if path.starts_with("~/") {
            dirs::home_dir()
                .map(|h| h.join(&path[2..]))
                .unwrap_or_else(|| PathBuf::from(path))
        } else {
            PathBuf::from(path)
        };

        // Reject binary files (check first 8KB for null bytes)
        let mut probe = std::fs::File::open(&resolved)
            .map_err(|e| ToolError::ExecutionFailed(format!("Cannot open: {e}")))?;
        let mut buf = [0u8; 8192];
        let n = std::io::Read::read(&mut probe, &mut buf)
            .map_err(|e| ToolError::ExecutionFailed(format!("Read error: {e}")))?;
        if buf[..n].contains(&0) {
            return Err(ToolError::ExecutionFailed("Binary file — cannot read as text".into()));
        }
        drop(probe);

        // Read with pagination
        let file = std::fs::File::open(&resolved)
            .map_err(|e| ToolError::ExecutionFailed(format!("Cannot open: {e}")))?;
        let reader = std::io::BufReader::new(file);
        let mut lines: Vec<String> = Vec::new();
        let mut total_lines: usize = 0;
        for (i, line) in reader.lines().enumerate() {
            total_lines = i + 1;
            let line_num = i + 1; // 1-indexed
            if line_num >= offset && line_num < offset + limit {
                let text = line.map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;
                lines.push(format!("{line_num}\t{text}"));
            } else if line_num >= offset + limit {
                // Still count total but stop collecting
                let _ = line;
            }
        }

        Ok(serde_json::json!({
            "content": lines.join("\n"),
            "total_lines": total_lines,
            "showing": { "from": offset, "to": offset + lines.len().min(limit) - 1 }
        }).to_string())
    }
}
```

**Schema:** See Part 0 example above.

---

### 1.2 `write_file`

**File:** `agent_core/src/tools/filesystem.rs`
**Risk:** Modification
**Deps:** `std::fs`

**Implementation notes:**
- `std::fs::create_dir_all(parent)` before write
- Path validation blocklist:
  ```rust
  const BLOCKED_PREFIXES: &[&str] = &[
      "/etc/", "/usr/", "/System/", "/Library/",
      "/bin/", "/sbin/", "/var/",
  ];
  const BLOCKED_HOMES: &[&str] = &[".ssh/", ".gnupg/", ".aws/"];
  ```
- Return `{ "success": true, "bytes_written": N, "path": "resolved_path" }`
- Generate a 3-line unified diff preview if file existed before

---

### 1.3 `patch`

**File:** `agent_core/src/tools/filesystem.rs`
**Risk:** Modification

**Implementation notes — 5-strategy fuzzy match (simplified from Hermes's 9):**
1. Exact match
2. Whitespace-normalized (collapse runs of whitespace to single space)
3. Leading/trailing whitespace trimmed per line
4. Indent-stripped (remove common leading indent)
5. Best substring match (find longest common subsequence)

Try in order, first match wins. On match, replace and return diff preview.

---

### 1.4 `search_files`

**File:** `agent_core/src/tools/filesystem.rs`
**Risk:** ReadOnly
**Deps:** `grep-regex`, `grep-searcher`, `globset`

**Add to Cargo.toml:**
```toml
grep-regex = "0.1"
grep-searcher = "0.1"
grep-matcher = "0.1"
globset = "0.4"
```

**Implementation:** Use ripgrep library crates directly. Build a `RegexMatcher`, configure a `Searcher` with context lines, walk directory with `walkdir` (already in deps), filter by glob.

---

### 1.5 `terminal` (bash/exec)

**File:** `agent_core/src/tools/terminal.rs`
**Risk:** Destructive
**Deps:** `tokio::process`

**Implementation notes:**
- `tokio::process::Command::new("sh").arg("-c").arg(&command)`
- Sanitize environment: remove `*_KEY`, `*_TOKEN`, `*_SECRET`, `*_PASSWORD` from child env
- Timeout via `tokio::time::timeout(Duration::from_secs(timeout_secs), child.wait_with_output())`
- Output cap: truncate stdout+stderr to 100,000 chars
- Background mode: spawn with `tokio::spawn`, return `{ "session_id": uuid }`, store handle in a `ProcessRegistry`

---

### 1.6 `process` (background process manager)

**File:** `agent_core/src/tools/terminal.rs`
**Risk:** ReadOnly (for list/poll/log), Destructive (for kill)

**Implementation notes:**
```rust
pub struct ProcessRegistry {
    processes: tokio::sync::RwLock<HashMap<String, ProcessHandle>>,
}

struct ProcessHandle {
    child: tokio::process::Child,           // or JoinHandle if already waited
    output_buffer: tokio::sync::Mutex<VecDeque<u8>>,  // rolling 200KB
    started_at: Instant,
    command: String,
    status: ProcessStatus,
}

enum ProcessStatus { Running, Completed(i32), Failed(String) }
```

Actions: `list`, `poll`, `log` (with offset/limit), `kill` (SIGTERM then SIGKILL after 5s), `write` (stdin).

---

### 1.7 `todo`

**File:** `agent_core/src/tools/todo.rs`
**Risk:** ReadOnly

Trivial: `Vec<TodoItem>` with serde. See Hermes `todo` tool. Already partially exists — check if `tools/` has it.

---

### 1.8 `clarify`

**File:** `agent_core/src/tools/clarify.rs`
**Risk:** ReadOnly

**Implementation notes:**
- Add to `AgentEventDelegate` in `bridge.rs`:
  ```rust
  fn ask_user_question(&self, question_json: String) -> String;
  ```
- Handler sends question JSON to Swift, blocks on response
- Swift shows a sheet/popover with the question + choices
- Returns user's answer as JSON string
- **Must be added to UniFFI callback interface** — this is the key FFI change

---

### 1.9 `delegate_task`

**Already exists:** `agent_core/src/tools/delegate_task.rs`
**Status:** Verify it's registered in `register_default_tools()` and working.

---

### 1.10 `cronjob`

**File:** `agent_core/src/tools/scheduling.rs`
**Risk:** Modification
**Deps:** Add `cron = "0.13"` to Cargo.toml

**Implementation notes:**
- SQLite table for job persistence: `CREATE TABLE cron_jobs (id TEXT PRIMARY KEY, name TEXT, prompt TEXT, schedule TEXT, enabled INTEGER, created_at TEXT, last_run TEXT)`
- `CronScheduler` runs a `tokio::time::interval(Duration::from_secs(60))` checking for due jobs
- Each job runs in a fresh `run_agent_loop()` call with a `SilentDelegate`
- Actions: create, list, update, pause, resume, remove, run (manual trigger)

---

### 1.11 `think`

**Already exists:** `agent_core/src/tools/think.rs`
**Status:** Done.

---

### 1.12 `skills_list` / `skill_view` / `skill_manage`

**File:** `agent_core/src/tools/skills.rs`
**Risk:** ReadOnly (list/view), Modification (manage)
**Deps:** `serde_yaml` (add to Cargo.toml)

**Implementation notes:**
```rust
pub struct SkillsRegistry {
    skill_dirs: Vec<PathBuf>,  // ~/.epistemos/skills/, project-local, etc.
    index: RwLock<Vec<SkillMetadata>>,  // tier-0 cache
}

pub struct SkillMetadata {
    pub name: String,
    pub description: String,
    pub category: Option<String>,
    pub tags: Vec<String>,
    pub requires_tools: Vec<String>,
    pub requires_env: Vec<String>,
    pub path: PathBuf,
}
```

- `skills_list`: return Vec<SkillMetadata> (tier 0, ~100 tokens each)
- `skill_view`: read full SKILL.md body (tier 1, <5000 tokens)
- `skill_manage`: create/edit/delete with 15KB size limit, YAML frontmatter validation
- Parse frontmatter with `serde_yaml` from the `---` fenced section

---

## Part 2: Phase 2 — Knowledge & Memory Tools (Sprint 2, ~2 weeks)

**Goal:** 8 tools that leverage the vault. These are your differentiators.

### 2.1 `vault_recall` (Specialty B1)

**File:** `agent_core/src/tools/memory.rs`
**Risk:** ReadOnly

**Implementation:**
This wraps the existing `VaultBackend::hybrid_search()`. If `NeuralCache` is available,
route through it for the hot layer first.

```rust
pub struct VaultRecallHandler {
    vault: Arc<dyn VaultBackend>,
    cache: Option<Arc<NeuralCache>>,
}

#[async_trait]
impl ToolHandler for VaultRecallHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input["query"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
        let top_k = input["top_k"].as_u64().unwrap_or(5) as usize;
        let tag_filter: Vec<String> = input["note_filter"]
            .as_array()
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default();

        let start = std::time::Instant::now();
        let results = self.vault.hybrid_search(query, top_k, &tag_filter).await
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;
        let latency_ms = start.elapsed().as_secs_f64() * 1000.0;

        Ok(serde_json::json!({
            "results": results.iter().map(|r| serde_json::json!({
                "path": r.path,
                "snippet": r.excerpt,
                "score": r.score,
                "tags": r.tags,
            })).collect::<Vec<_>>(),
            "latency_ms": latency_ms,
        }).to_string())
    }
}
```

---

### 2.2 `vault_write`

**File:** `agent_core/src/tools/memory.rs`
**Risk:** Modification

**Implementation:**
Wraps `VaultBackend::write()`. Before writing, run `contradiction_detector::detect_contradictions()`.
If contradictions found with confidence > 0.8, include them in the response (don't block the write,
but surface them).

```rust
pub struct VaultWriteHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultWriteHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path = input["path"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("missing 'path'".into()))?;
        let content = input["content"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("missing 'content'".into()))?;
        let append = input["append"].as_bool().unwrap_or(false);
        let tags: Option<Vec<String>> = input["tags"].as_array()
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect());

        // Run contradiction check
        let existing = self.vault.hybrid_search(content, 10, &[]).await.unwrap_or_default();
        let facts: Vec<VaultFact> = existing.iter().map(|r| VaultFact::new(
            r.path.clone(), "".into(), r.excerpt.clone(), r.score, Utc::now()
        )).collect();
        let contradictions = detect_contradictions(content, &facts);

        // Write
        self.vault.write(path, content, tags.as_deref(), append).await
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;

        let mut result = serde_json::json!({ "success": true, "path": path });
        if !contradictions.is_empty() {
            result["warnings"] = serde_json::json!(contradictions.iter().map(|c| {
                serde_json::json!({
                    "type": format!("{:?}", c.conflict_type),
                    "existing": c.existing_fact.content,
                    "confidence": c.confidence,
                    "source": c.existing_fact.file_path,
                })
            }).collect::<Vec<_>>());
        }
        Ok(result.to_string())
    }
}
```

---

### 2.3 `graph_query` (Specialty B2)

**File:** `agent_core/src/tools/graph.rs`
**Risk:** ReadOnly

**Implementation notes:**
- Needs FFI bridge to graph-engine crate OR direct Rust import if graph-engine is in the workspace
- Check: does `agent_core/Cargo.toml` have a `graph-engine` dependency? If not, add:
  ```toml
  graph-engine = { path = "../graph-engine" }
  ```
- Modes: `related` (text search on node labels), `path` (BFS shortest path), `communities` (Louvain clusters), `god_nodes` (top-k by centrality), `spatial` (radius query on SpatialIndex)
- Read `graph-engine/src/engine.rs` for the actual query API

---

### 2.4 `contradiction_check` (Specialty B3)

**File:** `agent_core/src/tools/memory.rs`
**Risk:** ReadOnly

**Implementation:** Thin wrapper around `contradiction_detector::detect_contradictions()`.
Load existing facts from vault via `hybrid_search`, run detector, return typed conflicts.

---

### 2.5 `memory` (persistent cross-session)

**File:** `agent_core/src/tools/memory.rs`
**Risk:** Modification

**Implementation notes (follow Hermes pattern):**
- Two files: `~/.epistemos/agent/MEMORY.md` (2200 char limit) and `~/.epistemos/agent/USER.md` (1375 char limit)
- Actions: `add` (append entry), `replace` (find old_text, replace with content), `remove` (find old_text, delete)
- File locking via `fs2::FileExt::lock_exclusive()`
- Injection scanning: reject entries containing "ignore previous", base64 blobs, or URL patterns that look like exfiltration
- Add `fs2 = "0.4"` to Cargo.toml

---

### 2.6 `session_search`

**File:** `agent_core/src/tools/memory.rs`
**Risk:** ReadOnly

**Implementation:** Query `session_store.rs` transcript JSONL files via Tantivy FTS.
Already have the infrastructure in `storage/session_store.rs`.

---

### 2.7 `neural_recall` (Specialty B5)

**File:** `agent_core/src/tools/memory.rs`
**Risk:** ReadOnly

**Implementation:** Thin wrapper around `NeuralCache`. Add a `lookup` method to NeuralCache
that queries through the 4 layers and returns `Vec<CachedResult>` with layer/latency info.

---

### 2.8 `vault_navigate` (Specialty B4)

**File:** `agent_core/src/tools/graph.rs`
**Risk:** ReadOnly

**Implementation:** Thin wrapper around `hyperbolic_topology.rs`. Call the Poincaré distance
function to find the geodesic path from start to semantic target.

---

## Part 3: Phase 3 — Web & Browser Tools (Sprint 3, ~2 weeks)

### 3.1 `web_search`

**File:** `agent_core/src/tools/web.rs`
**Risk:** ReadOnly
**Deps:** `reqwest` (already in deps)

**Implementation notes:**
- Support 3 backends: Tavily, Brave, Perplexity
- Backend selected by config or env var (`TAVILY_API_KEY`, `BRAVE_API_KEY`)
- Tavily: `POST https://api.tavily.com/search` with `{ query, max_results, search_depth: "basic" }`
- Brave: `GET https://api.search.brave.com/res/v1/web/search?q={query}&count={limit}` with `X-Subscription-Token` header
- Return normalized: `{ results: [{ url, title, description, position }] }`

---

### 3.2 `web_extract`

**File:** `agent_core/src/tools/web.rs`
**Risk:** ReadOnly
**Deps:** Add `scraper = "0.20"`, `html2md = "0.2"` to Cargo.toml

**Implementation:**
- Fetch URL with `reqwest::get(url).await`
- Parse HTML with `scraper::Html::parse_document`
- Extract main content (look for `<article>`, `<main>`, or largest `<div>`)
- Convert to markdown with `html2md::parse_html`
- If content > 50,000 chars and `use_llm_processing` is true, chunk and summarize via LLM

---

### 3.3 `web_crawl`

**File:** `agent_core/src/tools/web.rs`
**Risk:** ReadOnly
**Deps:** Add `spider = "2"` to Cargo.toml (optional — can implement BFS with reqwest)

---

### 3.4-3.14 Browser tools

**Implemented:** `agent_core/src/tools/browser.rs`

The browser tier now ships as an `agent-browser` CLI wrapper instead of a direct
`chromiumoxide`/`headless_chrome` embed. That keeps the Rust agent loop aligned
with Hermes's operational model while reusing Epistemos's existing `vision_analyze`
tool for screenshot inspection.

Implemented tools:
- `browser_navigate`
- `browser_snapshot`
- `browser_click`
- `browser_type`
- `browser_scroll`
- `browser_back`
- `browser_press`
- `browser_close`
- `browser_get_images`
- `browser_vision`
- `browser_console`

Implementation notes:
- Shared session state is held in `BrowserManager` so navigate/snapshot/click reuse
  one browser session.
- Local mode uses `agent-browser --session <id> --json ...`.
- If `BROWSER_CDP_URL` is set, the same handlers connect through `--cdp <url>`.
- Browser screenshots flow back through `vision_analyze` instead of duplicating
  provider-specific vision code.
- URL validation reuses the same SSRF protection as `web_fetch`.

---

## Part 4: Phase 4 — macOS Native Specialties (Sprint 4, ~2 weeks)

These all require Swift implementations exposed via FFI callbacks.

### 4.1 `perceive` (Specialty A1)

**Rust side:** `agent_core/src/tools/macos.rs`
**Swift side:** Already exists in `Screen2AXFusion.swift` + `AXorcistBridge.swift`

**FFI bridge needed:**
1. Add to `AgentEventDelegate` in `bridge.rs`:
   ```rust
   fn perceive_app(&self, app_name: String, depth: String) -> String;
   ```
2. Implement in Swift `StreamingDelegate.swift`:
   ```swift
   func perceiveApp(appName: String, depth: String) -> String {
       // Call Screen2AXFusion.perceive(appName:depth:)
       // Return JSON string of elements
   }
   ```
3. Rust handler calls `self.delegate.perceive_app(app_name, depth)`

**Risk:** ReadOnly

---

### 4.2 `interact` (Specialty A2)

**FFI bridge needed:**
```rust
fn interact_with_app(&self, action_json: String) -> String;
```

Similar pattern to existing `execute_computer_action`. May be able to reuse that callback
with a different action type in the JSON.

---

### 4.3 `apple_notes`, `apple_reminders`, `apple_calendar`, `apple_mail`

**Two implementation paths:**
1. **Quick (subprocess):** Shell out to `osascript` with JXA/AppleScript via `terminal` tool
2. **Proper (FFI):** Add Swift implementations using EventKit/AppleScript and expose via UniFFI

For v1, use the subprocess path. It's less elegant but ships faster.

---

## Part 5: Phase 5 — Inference Specialties (Sprint 5, ~2 weeks)

### 5.1 `ssm_resume` (Specialty C1)

**Rust side:** `agent_core/src/storage/ssm_state.rs` (serialization exists)
**Swift side:** `SSMStateService.swift` + `MetalRuntimeManager.swift`

**FFI bridge needed:**
```rust
fn save_ssm_state(&self, session_id: String, label: String) -> String;
fn load_ssm_state(&self, session_id: String) -> String;
fn list_ssm_states(&self) -> String;
```

---

### 5.2 `constrained_generate` (Specialty C2)

**FFI bridge needed:**
```rust
fn generate_constrained(&self, prompt: String, grammar_json: String) -> String;
```

This calls into `ConstrainedDecodingService.swift` which hooks into the MLX sampling loop.

---

### 5.3 `route_private` (Specialty C3)

**Rust side:** `agent_core/src/routing.rs` (already exists)

**Implementation:** Wrap `ConfidenceRouter::route()` as a tool. The agent can explicitly
query the router to inspect privacy classification before acting.

```rust
pub struct RoutePrivateHandler {
    router: ConfidenceRouter,
}

#[async_trait]
impl ToolHandler for RoutePrivateHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let objective = input["objective"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("missing 'objective'".into()))?;
        let classification = self.router.classifier.classify(objective);
        let decision = self.router.route(objective);
        Ok(serde_json::json!({
            "route": format!("{:?}", decision),
            "classification": {
                "complexity": classification.complexity,
                "privacy_sensitive": classification.privacy_sensitive,
                "tool_count_estimate": classification.tool_count_estimate,
                "requires_current_info": classification.requires_current_info,
                "shell_required": classification.shell_required,
            }
        }).to_string())
    }
}
```

---

## Part 6: Phase 6 — Communication & Media (Sprint 6, ~2 weeks)

### 6.1 `send_message` (multi-platform)

**File:** `agent_core/src/tools/communication.rs`
**Risk:** Destructive (sending messages is irreversible)

**Implementation notes:**
- Define a `MessagePlatform` trait:
  ```rust
  #[async_trait]
  pub trait MessagePlatform: Send + Sync {
      fn platform_name(&self) -> &str;
      async fn send(&self, target: &str, message: &str, media: Option<&str>) -> Result<String, ToolError>;
      async fn list_targets(&self) -> Result<Vec<String>, ToolError>;
  }
  ```
- Start with 3 platforms: Email (SMTP), Slack (webhook), Telegram (bot API)
- Add `lettre = "0.11"` for email, rest via `reqwest`
- Each platform reads credentials from env vars or Keychain (via Swift FFI callback)

### 6.2 `vision_analyze`

**File:** `agent_core/src/tools/media.rs`
**Risk:** ReadOnly

Send image + question to Claude/Gemini vision API. Use `base64` crate for encoding.
Add `base64 = "0.22"` to Cargo.toml.

### 6.3 `image_generate`

**File:** `agent_core/src/tools/media.rs`
**Risk:** ReadOnly

`reqwest` POST to FAL.ai or DALL-E API. Return image URL.

### 6.4 `text_to_speech`

**File:** `agent_core/src/tools/media.rs`
**Risk:** ReadOnly

For v1: use macOS `NSSpeechSynthesizer` via Swift FFI callback.
For v2: add cloud TTS (ElevenLabs, OpenAI).

---

## Part 7: Phase 7 — Intelligence Layer (Sprint 7, ~2 weeks)

### 7.1 `nightbrain_trigger` (Specialty D1)

**FFI bridge needed:**
```rust
fn trigger_nightbrain_job(&self, job_type: String, priority: String) -> String;
```

### 7.2 `self_evolve` (Specialty D3)

**File:** `agent_core/src/tools/skills.rs`
**Risk:** Modification

Port the core GEPA logic from `SkillEvolutionService.swift` to Rust:
1. Load trace events from session `trace.json` files (already in `session_store.rs`)
2. Detect failure patterns: frequent retries (same tool called >3x), slow execution (p95), consistent errors
3. Build mutation proposal (call LLM with failure analysis + current skill content)
4. Validate constraints: size <=15KB, semantic similarity to original >0.7
5. Write new skill version if approved

### 7.3 `mixture_of_minds` (Specialty D4)

**File:** `agent_core/src/tools/reasoning.rs`
**Risk:** ReadOnly

```rust
pub struct MixtureOfMindsHandler {
    providers: Vec<Arc<dyn AgentProvider>>,
}

#[async_trait]
impl ToolHandler for MixtureOfMindsHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let problem = input["problem"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("missing 'problem'".into()))?;

        // Run all providers in parallel
        let futures: Vec<_> = self.providers.iter().map(|p| {
            let problem = problem.to_string();
            let provider = Arc::clone(p);
            tokio::spawn(async move {
                // Call provider with problem, return (provider_name, response)
                provider.stream_message(/* ... */).await
            })
        }).collect();

        let results = futures::future::join_all(futures).await;

        // Aggregate via best provider (configurable)
        // ...
        Ok(serde_json::json!({ "answer": aggregated, "contributions": contributions }).to_string())
    }
}
```

---

## Part 8: New Cargo.toml Dependencies

Add these to `agent_core/Cargo.toml` as needed per phase:

```toml
# Phase 1: Core tools
grep-regex = "0.1"
grep-searcher = "0.1"
grep-matcher = "0.1"
globset = "0.4"
fs2 = "0.4"
dirs = "5.0"

# Phase 2: Knowledge (mostly existing deps)
# No new deps needed

# Phase 3: Web
scraper = "0.20"
html2md = "0.2"

# Phase 5: Inference
# No new deps (uses FFI to Swift)

# Phase 6: Communication
lettre = { version = "0.11", features = ["tokio1-rustls-tls"] }
base64 = "0.22"

# Phase 7: Intelligence
serde_yaml = "0.9"
cron = "0.13"
```

---

## Part 9: New UniFFI Callback Methods

All Swift-dependent tools need callback methods added to `AgentEventDelegate` in `bridge.rs`.
Here is the complete list of new methods needed across all phases:

```rust
#[uniffi::export(callback_interface)]
pub trait AgentEventDelegate: Send + Sync {
    // --- EXISTING methods (do not modify) ---
    fn on_thinking_delta(&self, thought: String);
    fn on_text_delta(&self, delta: String);
    fn on_tool_input_delta(&self, index: u32, partial_json: String);
    fn on_tool_started(&self, tool_use_id: String, name: String, input_json: String);
    fn on_tool_completed(&self, tool_use_id: String, result: String, is_error: bool);
    fn on_subagent_spawned(&self, agent_id: String, role: String);
    fn on_permission_required(&self, permission_id: String, tool_name: String, input_json: String, risk_level: String);
    fn on_context_compacting(&self, current_tokens: u32);
    fn on_context_compacted(&self, new_message_count: u32);
    fn on_turn_started(&self, turn_number: u32, message_count: u32);
    fn on_complete(&self, stop_reason: String, input_tokens: u32, output_tokens: u32);
    fn on_error(&self, message: String);
    fn execute_computer_action(&self, action_json: String) -> String;
    fn wait_for_permission(&self, permission_id: String) -> bool;

    // --- NEW methods for Specialties ---

    /// Phase 1: Ask user a clarifying question. Returns JSON { response, choice_index }.
    fn ask_user_question(&self, question_json: String) -> String;

    /// Phase 4: Perceive a macOS app's UI via AX+Vision fusion.
    /// Returns JSON array of UI elements with refs.
    fn perceive_app(&self, app_name: String, depth: String) -> String;

    /// Phase 4: Interact with a macOS app (click, type, scroll, etc).
    /// action_json: { app_name, action, target, value }
    fn interact_with_app(&self, action_json: String) -> String;

    /// Phase 4: Watch for changes on screen or filesystem.
    /// watch_json: { mode, target, condition, timeout_secs }
    fn start_screen_watch(&self, watch_json: String) -> String;

    /// Phase 5: Save/load/list Mamba SSM state snapshots.
    fn manage_ssm_state(&self, action_json: String) -> String;

    /// Phase 5: Generate constrained output from local model.
    fn generate_constrained(&self, prompt: String, grammar_json: String) -> String;

    /// Phase 7: Trigger a NightBrain background job.
    fn trigger_nightbrain_job(&self, job_type: String, priority: String) -> String;

    /// Phase 6: Get inline AI partner context at cursor position.
    fn get_partner_context(&self, note_id: String, cursor_offset: u32) -> String;
}
```

**IMPORTANT:** After adding new methods to this trait, you MUST also add corresponding
implementations in Swift's `StreamingDelegate.swift`. UniFFI will generate Swift protocol
requirements that must be satisfied.

---

## Part 10: File Structure After All Phases

```
agent_core/src/tools/
├── mod.rs               # pub mod declarations
├── registry.rs          # ToolRegistry, ToolHandler trait, RegisteredTool
├── think.rs             # ✅ exists
├── delegate_task.rs     # ✅ exists
├── chunk_reduce.rs      # ✅ exists
├── workspace_search.rs  # ✅ exists
├── computer_use.rs      # ✅ exists
├── file_ops.rs          # ✅ exists (check coverage)
├── web_fetch.rs         # ✅ exists (check coverage)
├── memory.rs            # ✅ exists (check coverage)
├── skills.rs            # ✅ exists (check coverage)
├── filesystem.rs        # NEW: read_file, write_file, patch, search_files
├── terminal.rs          # NEW: terminal, process
├── todo.rs              # NEW: session task list
├── clarify.rs           # NEW: ask user question (FFI callback)
├── scheduling.rs        # NEW: cronjob management
├── graph.rs             # NEW: graph_query, vault_navigate (Specialties B2, B4)
├── web.rs               # NEW: web_search, web_extract, web_crawl
├── macos.rs             # NEW: perceive, interact, screen_watch (Specialties A1-A3)
├── communication.rs     # NEW: send_message (multi-platform)
├── media.rs             # NEW: vision_analyze, image_generate, text_to_speech
├── reasoning.rs         # NEW: mixture_of_minds, route_private (Specialties C3, D4)
└── inference.rs         # NEW: ssm_resume, constrained_generate (Specialties C1, C2)
```

---

## Part 11: Verification Checklist

After each phase, verify:

1. `cargo test --manifest-path agent_core/Cargo.toml` — all pass
2. `cargo clippy --manifest-path agent_core/Cargo.toml` — no warnings
3. Build the full Xcode project: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify`
4. Run the tool schema export: verify each new tool appears in `get_definitions()`
5. For FFI changes: verify `StreamingDelegate.swift` compiles with new callback methods

---

## Part 12: What NOT To Do

- **Do NOT add tools that aren't registered in `register_default_tools()`** — they won't be sent to the LLM
- **Do NOT return plain text from tool handlers** — always return JSON strings
- **Do NOT use `println!` or `eprintln!`** — use `tracing::info!` / `tracing::error!`
- **Do NOT use `try!` or `.unwrap()` in tool handlers** — use `?` with `ToolError` conversions
- **Do NOT add blocking I/O in async handlers** — use `tokio::fs` not `std::fs` for file operations, or spawn_blocking
- **Do NOT modify the agent loop dispatch logic** — tools are automatically dispatched if registered
- **Do NOT change UniFFI callback method signatures after they're in use** — Swift will break. Only ADD new methods.
- **Do NOT buffer streaming responses** — see CLAUDE.md NON-NEGOTIABLE CONSTRAINTS
- **Do NOT use Debug format `{:?}` for JSON serialization** — use `serde_json`
