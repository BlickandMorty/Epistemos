# Skill Port Master Reference: OpenClaw + Hermes Agent -> Epistemos Rust

> Every skill from both platforms, categorized by priority, with Rust porting instructions.
> Generated 2026-04-09. Source: OpenClaw GitHub + Hermes Agent GitHub + docs.

---

## Table of Contents

1. [Porting Architecture](#porting-architecture)
2. [Priority Tiers](#priority-tiers)
3. [Tier 1: Core Agent Tools](#tier-1-core-agent-tools) (ship first)
4. [Tier 2: Knowledge & Memory](#tier-2-knowledge--memory)
5. [Tier 3: Browser & Web](#tier-3-browser--web)
6. [Tier 4: macOS Native](#tier-4-macos-native)
7. [Tier 5: Communication & Messaging](#tier-5-communication--messaging)
8. [Tier 6: Media & Creative](#tier-6-media--creative)
9. [Tier 7: Smart Home & IoT](#tier-7-smart-home--iot)
10. [Tier 8: Development & DevOps](#tier-8-development--devops)
11. [Tier 9: Advanced AI](#tier-9-advanced-ai)
12. [Tier 10: Niche & Platform-Specific](#tier-10-niche--platform-specific)
13. [Skill File Format (agentskills.io)](#skill-file-format)
14. [Rust Crate Dependency Map](#rust-crate-dependency-map)
15. [What Epistemos Already Has](#what-epistemos-already-has)

---

## Porting Architecture

### How Both Platforms Work

**Hermes Agent** has 47 built-in Python tools + 71 bundled/optional skills + MCP. Tools are registered via `registry.register()` with OpenAI function-format schemas. Skills are SKILL.md files (agentskills.io standard) that inject prompt instructions.

**OpenClaw** has ~30 native Gateway tools (Node.js) + 53 bundled skills + 5,700+ community skills. Skills are SKILL.md directories. Skills are NOT code -- they're prompt content that teaches the agent to use existing tools (exec, browser, curl, etc.).

### Epistemos Porting Strategy

```
agent_core/src/tools/
  registry.rs          -- Tool registry (you have this)
  filesystem.rs        -- read_file, write_file, patch, search_files
  terminal.rs          -- exec, process management
  browser.rs           -- CDP browser automation
  web.rs               -- search, extract, crawl
  memory.rs            -- persistent memory, session search
  vision.rs            -- image analysis, screenshot analysis
  media.rs             -- TTS, image gen, audio analysis
  communication.rs     -- messaging platform adapters
  macos.rs             -- AX automation, Apple apps, system
  smart_home.rs        -- Home Assistant, Hue, Sonos
  scheduling.rs        -- cron jobs, reminders
  delegation.rs        -- subagent spawning
  skills.rs            -- skill CRUD, discovery, evolution
  dev_tools.rs         -- GitHub, git, coding agents
```

Each tool registers as an OpenAI function-format schema (you already do this in `registry.rs`).

---

## Priority Tiers

| Tier | Category | Why | Count |
|------|----------|-----|-------|
| 1 | Core Agent Tools | Can't function without these | 12 |
| 2 | Knowledge & Memory | Your differentiator | 8 |
| 3 | Browser & Web | Agent needs eyes on the web | 14 |
| 4 | macOS Native | Your platform advantage | 10 |
| 5 | Communication | Users expect messaging | 8 |
| 6 | Media & Creative | Rich output | 9 |
| 7 | Smart Home & IoT | Popular category | 6 |
| 8 | Development & DevOps | Power users want this | 8 |
| 9 | Advanced AI | Differentiator features | 6 |
| 10 | Niche & Platform | Nice-to-haves | 15+ |

---

## Tier 1: Core Agent Tools

These are the foundation. Both Hermes and OpenClaw have them. Your agent can't do real work without them.

### 1.1 `terminal` (exec/bash)
- **Source:** Hermes `terminal` + OpenClaw `exec`
- **What:** Execute shell commands with timeout, background mode, environment sanitization
- **Params:** `command: String`, `background: bool`, `timeout_secs: u32`, `workdir: Option<String>`
- **Output:** `{ stdout: String, stderr: String, exit_code: i32 }` or `{ session_id: String }` for background
- **Rust impl:** `tokio::process::Command` with `timeout()`. Sanitize env vars (strip API keys from child env). Background via `tokio::spawn` with output buffering.
- **Crates:** `tokio` (process), `nix` (signals)
- **You have:** Partially in `agent_core/src/tools/` -- verify it handles background processes

### 1.2 `process` (background process manager)
- **Source:** Hermes `process` + OpenClaw `process`
- **What:** List/poll/log/kill/write-stdin for background processes. 200KB rolling output buffer per process. Max 64 concurrent. 30-min TTL for finished.
- **Params:** `action: enum(list|poll|log|wait|kill|write|submit)`, `session_id: String`, `data: Option<String>`, `timeout: Option<u32>`
- **Output:** Process status, buffered output, PID, uptime
- **Rust impl:** `HashMap<String, ProcessHandle>` with `tokio::sync::RwLock`. Rolling buffer via `VecDeque<u8>`. JSON checkpoint for crash recovery.
- **Crates:** `tokio`, `nix` (SIGTERM/SIGKILL), `serde_json`

### 1.3 `read_file`
- **Source:** Hermes `read_file` + OpenClaw `read`
- **What:** Read text file with line numbers and pagination. Reject binary files. 100K char safety limit.
- **Params:** `path: String`, `offset: u32` (1-indexed), `limit: u32` (default 500, max 2000)
- **Output:** `{ content: String, total_lines: u32 }`
- **Rust impl:** `BufRead` line-by-line. Binary detection via first 8KB scan for null bytes.
- **Crates:** `std::fs`, `content_inspector` (binary detection)
- **You have:** Yes, in tool registry -- verify pagination

### 1.4 `write_file`
- **Source:** Hermes `write_file` + OpenClaw `write`
- **What:** Write/overwrite file. Auto-create parent dirs. Block writes to system paths. Produce diff preview.
- **Params:** `path: String`, `content: String`
- **Output:** `{ success: bool, bytes_written: u64 }`
- **Rust impl:** `tokio::fs::write` with `create_dir_all`. Path validation blocklist: `/etc`, `/usr`, `/System`, `~/.ssh`, etc.
- **Crates:** `tokio::fs`

### 1.5 `patch` (edit/find-replace)
- **Source:** Hermes `patch` (9-strategy fuzzy match) + OpenClaw `edit` + `apply_patch`
- **What:** Targeted find-and-replace with fuzzy matching (whitespace normalization, indent-insensitive). Also supports unified diff format. Stale file detection.
- **Params:** `path: String`, `old_string: String`, `new_string: String`, `replace_all: bool` OR `patch: String` (unified diff)
- **Output:** `{ success: bool, replacements: u32 }`
- **Rust impl:** Fuzzy match strategies: (1) exact, (2) whitespace-normalized, (3) indent-stripped, (4) leading/trailing trimmed, (5) collapsed whitespace, (6) line-by-line fuzzy, (7) token-based, (8) regex-escaped, (9) best-effort substring. Apply in order, first match wins.
- **Crates:** `similar` (diff), `regex`
- **You have:** Basic version -- add fuzzy matching

### 1.6 `search_files`
- **Source:** Hermes `search_files` + OpenClaw (via exec + rg)
- **What:** Ripgrep-backed content/filename search. Regex, glob filter, pagination.
- **Params:** `pattern: String`, `target: enum(content|files)`, `path: String`, `file_glob: Option<String>`, `limit: u32`, `context_lines: u32`
- **Output:** `{ matches: Vec<SearchMatch> }` with file, line, content
- **Rust impl:** Use ripgrep libraries directly for zero-overhead search.
- **Crates:** `grep-regex`, `grep-searcher`, `grep-matcher` (ripgrep internals), `globset`

### 1.7 `todo` (task list)
- **Source:** Hermes `todo` + OpenClaw community `todo`
- **What:** Session-scoped task list. CRUD with merge semantics. Status: pending/in_progress/completed/cancelled.
- **Params:** `todos: Option<Vec<TodoItem>>` (write), `merge: bool`
- **Output:** `{ todos: Vec<TodoItem>, summary: { pending, in_progress, completed } }`
- **Rust impl:** `Vec<TodoItem>` with serde. Trivial.
- **Crates:** `serde`

### 1.8 `clarify` (ask user)
- **Source:** Hermes `clarify` + OpenClaw (via message tool)
- **What:** Ask user a question. Multiple-choice (max 4 + "Other") or open-ended. Blocks until response.
- **Params:** `question: String`, `choices: Option<Vec<String>>`
- **Output:** `{ question: String, response: String, choice_index: Option<u32> }`
- **Rust impl:** Send question to Swift UI via FFI callback. Block on `tokio::sync::oneshot` channel until user responds.
- **Bridge:** Swift `StreamingDelegate` needs a "question" event type

### 1.9 `delegate_task` (subagent)
- **Source:** Hermes `delegate_task` + OpenClaw `sessions_spawn`
- **What:** Spawn 1-3 isolated child agents with their own tool sets. Only summaries return to parent. Parallel batch mode.
- **Params:** `goal: String`, `context: String`, `toolsets: Vec<String>`, `max_iterations: u32`
- **Output:** `{ results: Vec<{ status, summary, api_calls, duration, tool_trace }> }`
- **Rust impl:** Spawn isolated `AgentLoop` instances via `tokio::task`. Filtered tool registry clone. Message passing via channels.
- **Crates:** `tokio` (spawn, channels)
- **You have:** `agent_core/src/tools/delegate_task.rs` -- verify it works

### 1.10 `cronjob` (scheduling)
- **Source:** Hermes `cronjob` + OpenClaw `cron`
- **What:** Create/list/update/pause/resume/remove/run scheduled jobs. Natural language schedules ("every 2h"). Jobs run in fresh sessions.
- **Params:** `action: enum(create|list|update|pause|resume|remove|run)`, `job_id: Option<String>`, `prompt: String`, `schedule: String`, `name: Option<String>`
- **Output:** Job details, list of jobs, execution result
- **Rust impl:** `cron` crate for expression parsing. SQLite persistence. Timer loop checks every minute.
- **Crates:** `cron`, `rusqlite`, `tokio` (interval)

### 1.11 `think` (scratchpad)
- **Source:** Hermes (implicit in agent loop) + Claude Code `think` tool
- **What:** Internal reasoning scratchpad. Agent writes thoughts that don't become tool calls. Helps with complex multi-step planning.
- **Params:** `thought: String`
- **Output:** `{ acknowledged: true }`
- **Rust impl:** No-op tool that just returns. Its value is in the LLM's chain-of-thought.
- **You have:** `agent_core/src/tools/think.rs` -- done

### 1.12 `skills_list` / `skill_view` / `skill_manage`
- **Source:** Hermes skills toolset (3 tools) + OpenClaw `clawhub` + `skill-creator`
- **What:** List available skills (tier 0 metadata), view full skill content (tier 1), create/edit/delete skills. Progressive disclosure to minimize tokens.
- **Params:** Various per action (see Hermes section above)
- **Output:** Skill metadata, full content, CRUD confirmation
- **Rust impl:** Scan `~/.epistemos/skills/` directory. Parse YAML frontmatter with `serde_yaml`. Size limit 15KB. Security scan on writes.
- **Crates:** `walkdir`, `serde_yaml`, `std::fs`
- **You have:** `SkillEvolutionService.swift` (Swift side) -- need Rust tooling

---

## Tier 2: Knowledge & Memory

Your vault system gives you an advantage here. These tools make the agent remember and learn.

### 2.1 `memory` (persistent cross-session)
- **Source:** Hermes `memory` (MEMORY.md + USER.md, 2200/1375 char limits)
- **What:** Add/replace/remove entries in persistent memory files. Atomic writes with file locking. Injection/exfiltration scanning. Frozen at session start for cache efficiency.
- **Params:** `action: enum(add|replace|remove)`, `target: enum(memory|user)`, `content: String`, `old_text: Option<String>`
- **Output:** `{ success: bool, usage: { chars_used, chars_limit } }`
- **Rust impl:** File-backed with `fs2` locking. Regex-based injection scanner (detects "ignore previous", base64 payloads, URL exfiltration attempts).
- **Crates:** `fs2` (file locking), `regex`
- **You have:** `agent_core/src/storage/vault.rs` + `memory_classifier.rs` -- extend with Hermes-style bounded stores

### 2.2 `session_search` (recall past conversations)
- **Source:** Hermes `session_search` (FTS5 + LLM summarization)
- **What:** Browse recent sessions or keyword-search past conversations. AI-generated summaries via cheap model. Groups by session, resolves delegation chains.
- **Params:** `query: Option<String>`, `role_filter: Option<String>`, `limit: u32`
- **Output:** Session metadata or summarized conversation snippets
- **Rust impl:** Already have Tantivy. Query session transcripts, return top-k matches. Optional LLM summarization pass.
- **Crates:** `tantivy`, `rusqlite`
- **You have:** `agent_core/src/storage/session_store.rs` -- wire to tool registry

### 2.3 `vault_search` (Epistemos-specific)
- **Source:** Neither has this -- YOUR differentiator
- **What:** Hybrid full-text + vector search across vault notes. Returns ranked results with context snippets.
- **Params:** `query: String`, `limit: u32`, `note_filter: Option<Vec<String>>`
- **Output:** `{ results: Vec<{ note_id, title, snippet, score }> }`
- **Rust impl:** Tantivy FTS + sqlite-vec embedding search. MMR reranking.
- **You have:** `agent_core/src/storage/vault.rs` -- expose as tool

### 2.4 `vault_write` (note mutation)
- **Source:** Neither -- YOUR differentiator
- **What:** Create/update vault notes. Respects wikilinks, backlinks, metadata.
- **Params:** `action: enum(create|append|replace_section)`, `note_id: Option<String>`, `title: Option<String>`, `content: String`
- **Output:** `{ note_id: String, success: bool }`
- **Rust impl:** Write through vault sync layer. Trigger graph reindex.

### 2.5 `graph_query` (knowledge graph)
- **Source:** Neither -- YOUR differentiator
- **What:** Query the knowledge graph. Find related concepts, paths between nodes, top entities.
- **Params:** `query: String`, `mode: enum(related|path|top_nodes)`, `limit: u32`
- **Output:** `{ nodes: Vec<GraphNode>, edges: Vec<GraphEdge> }`
- **Rust impl:** graph-engine crate query API.
- **You have:** `graph-engine/src/engine.rs`

### 2.6 `contradiction_check`
- **Source:** Neither -- YOUR differentiator
- **What:** Check if new information contradicts existing vault knowledge.
- **Params:** `claim: String`, `context: Option<String>`
- **Output:** `{ contradictions: Vec<{ existing_fact, conflict_type, confidence }> }`
- **You have:** `agent_core/src/storage/contradiction_detector.rs`

### 2.7 `knowledge_distill`
- **Source:** Hermes self-evolution (adjacent concept)
- **What:** Extract key concepts from a conversation and add to vault knowledge profile.
- **Params:** `session_id: String`, `auto: bool`
- **Output:** `{ concepts_added: u32, concepts: Vec<String> }`
- **You have:** `CloudKnowledgeDistillationService.swift` -- need Rust tool wrapper

### 2.8 `instant_recall`
- **Source:** Neither -- YOUR differentiator
- **What:** Fast semantic recall from vault. Returns most relevant notes for a query with zero LLM cost.
- **Params:** `query: String`, `limit: u32`
- **Output:** Ranked note snippets
- **You have:** `InstantRecallService.swift` -- expose via tool

---

## Tier 3: Browser & Web

### 3.1 `web_search`
- **Source:** Hermes (Tavily/Exa/Parallel) + OpenClaw (Brave Search)
- **What:** Web search with structured results. SSRF protection. Configurable backend.
- **Params:** `query: String`, `limit: u32`
- **Output:** `{ results: Vec<{ url, title, description, position }> }`
- **Rust impl:** `reqwest` to search API. Support multiple backends: Tavily (`api.tavily.com/search`), Brave (`api.search.brave.com/res/v1/web/search`), Perplexity.
- **Crates:** `reqwest`, `serde`

### 3.2 `web_extract`
- **Source:** Hermes `web_extract`
- **What:** Extract full content from URLs. HTML to markdown. Chunk large content and LLM-summarize in parallel. SSRF protection.
- **Params:** `urls: Vec<String>`, `use_llm_processing: bool`
- **Output:** `{ results: Vec<{ url, title, content }> }`
- **Rust impl:** `reqwest` + `scraper` for HTML parsing. `html2md` for conversion. Parallel summarization via `tokio::join!`.
- **Crates:** `reqwest`, `scraper`, `html2md`

### 3.3 `web_crawl`
- **Source:** Hermes `web_crawl`
- **What:** Multi-page crawl from a base URL with LLM-guided extraction. Respects robots.txt.
- **Params:** `url: String`, `instructions: String`, `depth: enum(basic|advanced)`
- **Output:** Structured page summaries
- **Rust impl:** `spider` crate or custom BFS crawler with `reqwest`.
- **Crates:** `spider`, `reqwest`, `url`

### 3.4-3.14 `browser_*` (11 tools)
- **Source:** Hermes browser toolset + OpenClaw `browser`
- **Tools:** `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type`, `browser_scroll`, `browser_back`, `browser_press`, `browser_close`, `browser_get_images`, `browser_vision`, `browser_console`
- **What:** Full CDP-based browser automation. Navigate, get accessibility tree snapshot, click/type/scroll by element ref, screenshot + vision analysis, JS console access.
- **Rust impl:** All through Chrome DevTools Protocol (CDP).
- **Crates:** `chromiumoxide` (async CDP client) or `headless_chrome`
- **Note:** You already have AXorcist + ScreenCaptureKit for native app automation. Browser automation is a different concern -- it controls a web browser specifically.

| Browser Tool | Params | CDP Method |
|---|---|---|
| `navigate` | `url: String` | `Page.navigate` |
| `snapshot` | `full: bool` | `Accessibility.getFullAXTree` |
| `click` | `ref: String` | Resolve ref -> `DOM.getBoxModel` -> `Input.dispatchMouseEvent` |
| `type` | `ref: String, text: String` | `DOM.focus` -> `Input.dispatchKeyEvent` per char |
| `scroll` | `direction: enum(up\|down)` | `Runtime.evaluate("window.scrollBy(0, ±500)")` x5 |
| `back` | -- | `Page.navigateToHistoryEntry` |
| `press` | `key: String` | `Input.dispatchKeyEvent` |
| `close` | -- | Close CDP session |
| `get_images` | -- | `Runtime.evaluate` DOM query |
| `vision` | `question: String` | `Page.captureScreenshot` + vision LLM |
| `console` | `expression: Option<String>` | `Runtime.evaluate` / `Runtime.consoleAPICalled` |

---

## Tier 4: macOS Native

This is your platform advantage. OpenClaw has many of these via CLI tools; you can do them natively.

### 4.1 `screenshot` / `screen_capture`
- **Source:** OpenClaw `peekaboo` + Hermes `browser_vision`
- **What:** Capture screen/window/region. Annotate with element labels.
- **Rust impl:** Already have this via Swift ScreenCaptureKit bridge.
- **You have:** `Epistemos/Omega/Vision/ScreenCaptureService.swift`

### 4.2 `ax_click` / `ax_type` / `ax_inspect`
- **Source:** OpenClaw `peekaboo` (clicks, types, element maps)
- **What:** Click UI elements, type text, inspect element trees via Accessibility API.
- **Rust impl:** Already have via AXorcist bridge.
- **You have:** `Epistemos/Omega/Vision/AXorcistBridge.swift`

### 4.3 `apple_notes`
- **Source:** OpenClaw `apple-notes`
- **What:** CRUD Apple Notes via AppleScript or direct SQLite.
- **Params:** `action: enum(list|read|create|search|delete)`, `title: Option<String>`, `folder: Option<String>`, `content: Option<String>`
- **Rust impl:** `std::process::Command` calling `osascript` with JXA/AppleScript. Or `rusqlite` reading `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`.
- **Crates:** `rusqlite` (for read), `std::process` (for write via osascript)

### 4.4 `apple_reminders`
- **Source:** OpenClaw `apple-reminders`
- **What:** List/add/edit/complete/delete reminders.
- **Params:** `action: enum(list|add|complete|delete)`, `title: String`, `due_date: Option<String>`, `list: Option<String>`
- **Rust impl:** AppleScript subprocess. Or Swift EventKit bridge via FFI.
- **Better:** Implement in Swift via EventKit, expose via UniFFI

### 4.5 `apple_calendar`
- **Source:** OpenClaw `gog` (calendar portion)
- **What:** List/create/modify calendar events.
- **Params:** `action: enum(list|create|modify|delete)`, `title: String`, `start: String`, `end: String`, `calendar: Option<String>`
- **Rust impl:** Swift EventKit bridge via UniFFI. Or AppleScript.

### 4.6 `apple_mail`
- **Source:** OpenClaw `himalaya` + `gog` (Gmail)
- **What:** Search/read/send/reply emails.
- **Params:** `action: enum(search|read|send|reply)`, `query: Option<String>`, `to: Option<String>`, `subject: Option<String>`, `body: Option<String>`
- **Rust impl:** For Apple Mail: AppleScript. For Gmail/IMAP: `lettre` (SMTP) + `imap` crate.
- **Crates:** `lettre`, `imap`, `mailparse`

### 4.7 `finder_operations`
- **Source:** OpenClaw `peekaboo` (drag-and-drop, file management)
- **What:** Open files, reveal in Finder, move to trash, get file info.
- **Params:** `action: enum(open|reveal|trash|info)`, `path: String`
- **Rust impl:** `std::process::Command::new("open")` for open/reveal. `objc2` for NSFileManager trash.
- **Crates:** `objc2`

### 4.8 `clipboard`
- **Source:** OpenClaw `peekaboo` (clipboard ops)
- **What:** Read/write system clipboard.
- **Params:** `action: enum(read|write)`, `content: Option<String>`
- **Output:** Clipboard text content
- **Rust impl:** `arboard` crate (cross-platform clipboard).
- **Crates:** `arboard`

### 4.9 `system_info`
- **Source:** OpenClaw `healthcheck` (system context)
- **What:** Get system info: CPU, memory, disk, battery, thermal state, running apps.
- **Params:** `detail: enum(summary|full)`
- **Output:** System metrics JSON
- **Rust impl:** `sysinfo` crate for CPU/memory/disk. `battery` crate. IOKit for thermal via `core-foundation`.
- **Crates:** `sysinfo`, `battery`

### 4.10 `imessage`
- **Source:** OpenClaw `imsg` + `bluebubbles`
- **What:** Send/read iMessages. List chats, search history.
- **Params:** `action: enum(send|read|list_chats|search)`, `to: Option<String>`, `text: Option<String>`, `query: Option<String>`
- **Rust impl:** Read: `rusqlite` on `~/Library/Messages/chat.db`. Send: AppleScript `tell application "Messages"`. Requires Full Disk Access.
- **Crates:** `rusqlite`, `std::process`

---

## Tier 5: Communication & Messaging

### 5.1 `send_message` (multi-platform)
- **Source:** Hermes `send_message` (14+ platforms) + OpenClaw shared `message` tool
- **What:** Send messages to Telegram, Discord, Slack, WhatsApp, Signal, Email, Matrix. Platform-aware formatting. Media attachments. Intelligent chunking.
- **Params:** `platform: String`, `target: String`, `message: String`, `media: Option<String>`
- **Output:** Send confirmation
- **Rust impl:** Platform adapter trait with implementations per platform.
- **Crates per platform:**

| Platform | Crate | Auth |
|---|---|---|
| Telegram | `teloxide` or `reqwest` to Bot API | Bot token |
| Discord | `serenity` or `twilight` | Bot token |
| Slack | `slack-morphism` or `reqwest` | Bot token |
| Email | `lettre` (SMTP) + `imap` | SMTP/IMAP creds |
| Matrix | `matrix-sdk` | Access token |
| WhatsApp | `reqwest` to Business API | Business API key |
| Signal | `reqwest` to signal-cli REST API | Signal account |
| Webhooks | `reqwest` POST | URL + optional secret |

### 5.2-5.8 Platform-specific messaging
Each platform from the table above is its own tool registration but shares the adapter trait. The agent picks the right platform based on context.

---

## Tier 6: Media & Creative

### 6.1 `vision_analyze`
- **Source:** Hermes `vision_analyze`
- **What:** Analyze images via vision LLM. Accepts URLs or local files. Base64 encoding.
- **Params:** `image_url: String`, `question: String`
- **Output:** `{ analysis: String }`
- **Rust impl:** `reqwest` to vision API (Claude, Gemini, GPT-4V). `image` crate for format handling. `base64` for encoding.
- **Crates:** `image`, `base64`, `reqwest`

### 6.2 `image_generate`
- **Source:** Hermes `image_generate` (FLUX 2 Pro via FAL.ai) + OpenClaw `image_generate`
- **What:** Text-to-image generation. Auto-upscale 2x.
- **Params:** `prompt: String`, `aspect_ratio: enum(landscape|portrait|square)`
- **Output:** `{ image_url: String }`
- **Rust impl:** `reqwest` to FAL.ai, Replicate, or DALL-E API.
- **Crates:** `reqwest`

### 6.3 `text_to_speech`
- **Source:** Hermes `text_to_speech` (Edge TTS/ElevenLabs/OpenAI) + OpenClaw `sag` + `sherpa-onnx-tts`
- **What:** Convert text to audio. Multiple providers. Platform-aware format selection.
- **Params:** `text: String`, `provider: Option<String>`, `voice: Option<String>`
- **Output:** `{ audio_path: String }`
- **Rust impl:** Edge TTS (free, no API key -- HTTP to Microsoft edge voices). ElevenLabs/OpenAI via `reqwest`. Local: `sherpa-onnx` Rust bindings or `whisper-rs`.
- **Crates:** `reqwest`, optionally `sherpa-onnx` or `ort` (ONNX Runtime)

### 6.4 `speech_to_text`
- **Source:** Hermes `transcribe_audio` + OpenClaw `openai-whisper` + `openai-whisper-api`
- **What:** Transcribe audio to text. Local (whisper.cpp) or cloud (OpenAI/Groq).
- **Params:** `audio_path: String`, `provider: enum(local|openai|groq)`, `language: Option<String>`
- **Output:** `{ transcript: String }`
- **Rust impl:** Local: `whisper-rs` (whisper.cpp bindings). Cloud: `reqwest` multipart upload.
- **Crates:** `whisper-rs`, `reqwest`

### 6.5 `audio_analyze` (spectrogram)
- **Source:** OpenClaw `songsee`
- **What:** Generate spectrograms, mel, chroma, MFCC visualizations from audio.
- **Params:** `audio_path: String`, `viz_type: String`, `output_path: String`
- **Rust impl:** `rustfft` for FFT, `hound` for WAV, `image` for rendering.
- **Crates:** `rustfft`, `hound`, `image`, `mel-spec`

### 6.6 `gif_search`
- **Source:** OpenClaw `gifgrep`
- **What:** Search GIF providers (Tenor/Giphy), download results.
- **Params:** `query: String`, `source: enum(tenor|giphy)`, `limit: u32`
- **Output:** `{ gifs: Vec<{ url, preview_url, title }> }`
- **Rust impl:** `reqwest` to Tenor/Giphy API.
- **Crates:** `reqwest`

### 6.7 `video_frames`
- **Source:** OpenClaw `video-frames`
- **What:** Extract frames from videos at timestamps.
- **Params:** `video_path: String`, `timestamp: String`, `output_path: String`
- **Rust impl:** `ffmpeg-next` crate or subprocess to `ffmpeg`.
- **Crates:** `ffmpeg-next` or `std::process`

### 6.8 `summarize_content`
- **Source:** OpenClaw `summarize` + Hermes `web_extract` (with LLM)
- **What:** Summarize URLs, PDFs, YouTube videos, podcasts. Multiple length options.
- **Params:** `source: String`, `length: enum(short|medium|long)`, `extract_only: bool`
- **Output:** `{ summary: String }`
- **Rust impl:** `reqwest` for fetching, `lopdf` for PDF, LLM for summarization. YouTube: subprocess to `yt-dlp`.
- **Crates:** `reqwest`, `lopdf`, `scraper`

### 6.9 `music_generate` / `video_generate`
- **Source:** OpenClaw native tools
- **What:** Generate music/video via AI APIs (Suno, Runway, etc.)
- **Params:** `prompt: String`, `duration: Option<u32>`
- **Rust impl:** `reqwest` to provider APIs. Low priority -- APIs change frequently.

---

## Tier 7: Smart Home & IoT

### 7.1-7.4 Home Assistant (4 tools)
- **Source:** Hermes `ha_list_entities`, `ha_get_state`, `ha_list_services`, `ha_call_service`
- **What:** Control any Home Assistant device. List entities, get state, call services.
- **Rust impl:** All simple REST calls to HA API (`/api/states`, `/api/services`).
- **Crates:** `reqwest`
- **Auth:** Long-lived access token in header

### 7.5 `hue_control`
- **Source:** OpenClaw `openhue`
- **What:** Control Philips Hue lights. On/off, brightness, color, scenes.
- **Rust impl:** Hue Bridge local REST API. mDNS for discovery.
- **Crates:** `reqwest`, `mdns` (discovery)

### 7.6 `sonos_control`
- **Source:** OpenClaw `sonoscli`
- **What:** Control Sonos speakers. Play/pause, volume, grouping, queue.
- **Rust impl:** `sonor` crate for Sonos UPnP/SOAP.
- **Crates:** `sonor`, `ssdp-client`

---

## Tier 8: Development & DevOps

### 8.1 `github` (full GitHub integration)
- **Source:** Hermes GitHub skills + OpenClaw `github` + `gh-issues`
- **What:** Issues, PRs, CI runs, code review, API queries. Parallel issue-fixing with worktrees.
- **Params:** `action: enum(issue_list|issue_create|pr_list|pr_create|pr_review|run_status|api)`, plus action-specific params
- **Rust impl:** `octocrab` for typed GitHub API. Or `reqwest` to `api.github.com`.
- **Crates:** `octocrab`, `git2`

### 8.2 `git_operations`
- **Source:** Both (implicit in terminal use)
- **What:** Git status, diff, commit, branch, merge, log. Safer than raw terminal for common ops.
- **Params:** `action: enum(status|diff|commit|branch|log|stash)`, plus action-specific params
- **Rust impl:** `git2` crate for libgit2 bindings.
- **Crates:** `git2`

### 8.3 `execute_code` (sandboxed scripting)
- **Source:** Hermes `execute_code` (Python sandbox with RPC tool access)
- **What:** Run Python/JS in sandbox with access to whitelisted tools via RPC. Only stdout returns.
- **Params:** `code: String`, `language: enum(python|javascript)`
- **Rust impl:** For Python: `pyo3` embedded interpreter. For JS: `boa_engine` or `deno_core`. UDS-based tool RPC.
- **Crates:** `pyo3`, `tokio::net::UnixStream`
- **Alternative:** Lua via `mlua` or Rhai via `rhai` for lightweight scripting

### 8.4 `linear_integration`
- **Source:** OpenClaw community `linear`
- **What:** Linear issue and project management.
- **Params:** `action: enum(list|create|update|search)`, plus fields
- **Rust impl:** `reqwest` to Linear GraphQL API.
- **Crates:** `reqwest`, `graphql_client`

### 8.5 `notion_integration`
- **Source:** OpenClaw `notion`
- **What:** Notion pages, databases, blocks CRUD.
- **Rust impl:** `reqwest` to `api.notion.com/v1/`.
- **Crates:** `reqwest`

### 8.6 `trello_integration`
- **Source:** OpenClaw `trello`
- **What:** Trello boards, lists, cards management.
- **Rust impl:** `reqwest` to `api.trello.com/1/`.

### 8.7 `dataview_query` (Obsidian-compatible)
- **Source:** OpenClaw `obsidian` + Epistemos `DataviewService.swift`
- **What:** DQL queries against vault notes (TABLE, LIST, TASK with FROM/WHERE/SORT/LIMIT).
- **You have:** `DataviewService.swift` -- port to Rust for agent access

### 8.8 `coding_agent` (delegate to external)
- **Source:** OpenClaw `coding-agent`
- **What:** Delegate coding tasks to Claude Code, Codex, etc. via subprocess.
- **Params:** `agent: enum(claude|codex|opencode)`, `task: String`, `workdir: String`
- **Rust impl:** `tokio::process::Command` to spawn CLI tools.

---

## Tier 9: Advanced AI

### 9.1 `mixture_of_agents`
- **Source:** Hermes `mixture_of_agents`
- **What:** Route hard problems through 4 frontier LLMs in parallel, aggregate via best model. 5 API calls total.
- **Params:** `prompt: String`
- **Output:** `{ response: String, models_used: Vec<String>, processing_time_ms: u64 }`
- **Rust impl:** `tokio::join!` for parallel `reqwest` calls to Claude, GPT, Gemini, DeepSeek. Aggregation prompt to Claude.
- **Crates:** `reqwest`, `tokio`
- **You have:** The routing infrastructure in `agent_core/src/routing.rs`

### 9.2 `self_improve` (GEPA evolution)
- **Source:** Hermes `hermes-agent-self-evolution`
- **What:** Read execution traces -> detect failure patterns -> propose skill mutations -> constraint-gate -> apply. Genetic-Pareto optimization.
- **Params:** `action: enum(analyze|propose|validate|apply)`, `skill_name: Option<String>`
- **Output:** Mutation proposals with constraint check results
- **Rust impl:** Trace analysis in Rust, mutation proposal via LLM, constraint gates (size <=15KB, semantic preservation, test pass).
- **You have:** `SkillEvolutionService.swift` -- port core logic to Rust

### 9.3 `reasoning_chain`
- **Source:** Hermes (implicit in agent loop with thinking)
- **What:** Explicit multi-step reasoning. Break complex problems into steps, evaluate each, synthesize.
- **Params:** `problem: String`, `max_steps: u32`
- **Output:** `{ steps: Vec<{ thought, evaluation, result }>, final_answer: String }`
- **Rust impl:** Iterative LLM calls with structured output parsing.

### 9.4 `research_deep`
- **Source:** OpenClaw community `deep-research-agent`
- **What:** Multi-source research with confidence ratings, citations, methodology transparency.
- **Params:** `question: String`, `depth: enum(quick|standard|deep)`, `sources: u32`
- **Output:** `{ answer: String, confidence: f64, citations: Vec<Citation>, methodology: String }`
- **You have:** `ResearchOrchestrator.swift` -- expose as tool

### 9.5 `proactive_suggestions`
- **Source:** OpenClaw community `proactive-agent`
- **What:** Transform agent from reactive to proactive. Suggest next actions based on context.
- **Rust impl:** Context analysis + pattern matching on recent actions.

### 9.6 `rl_training` (10 tools)
- **Source:** Hermes RL toolset (tinker-atropos)
- **What:** Full RL training pipeline: environment selection, config, training, status, results.
- **Rust impl:** Heavy Python dependency (atropos). Best ported as subprocess orchestration, not pure Rust.
- **Priority:** Low -- research feature, not shipping requirement

---

## Tier 10: Niche & Platform-Specific

Lower priority. Implement based on user demand.

| Tool | Source | What | Rust Approach |
|---|---|---|---|
| `rss_monitor` | OC `blogwatcher` | Monitor RSS feeds | `feed-rs` + `reqwest` |
| `pdf_edit` | OC `nano-pdf` | AI-powered PDF editing | `lopdf` + LLM |
| `weather` | OC `weather` | Weather via wttr.in | `reqwest` to wttr.in |
| `spotify` | OC `spotify-player` | Spotify control | `rspotify` crate |
| `things3` | OC `things-mac` | Things 3 tasks | `rusqlite` + URL scheme |
| `bear_notes` | OC `bear-notes` | Bear note CRUD | SQLite + x-callback-url |
| `food_delivery` | OC `ordercli` | Foodora orders | `reqwest` (reverse API) |
| `1password` | OC `1password` | Secret management | `op` subprocess |
| `todoist` | OC community | Todoist tasks | `reqwest` to REST API |
| `excel` | OC community | Spreadsheet ops | `calamine` + `xlsxwriter` |
| `voice_call` | OC `voice-call` | Phone calls via Twilio | `reqwest` to Twilio API |
| `x_twitter` | OC `xurl` | Twitter/X posting | `reqwest` + OAuth 1.0a |
| `bluesound` | OC `blucli` | Bluesound speakers | `reqwest` to local API |
| `eight_sleep` | OC `eightctl` | Smart bed control | `reqwest` (reverse API) |
| `camera_snap` | OC `camsnap` | RTSP camera capture | `retina` + `ffmpeg-next` |
| `google_workspace` | OC `gog` | Gmail/Cal/Drive/Sheets | `google-apis-rs` |

---

## Skill File Format

Both Hermes and OpenClaw use the **agentskills.io** standard. Adopt this for Epistemos.

### Directory Structure
```
skill-name/
  SKILL.md          # Required: YAML frontmatter + instructions
  scripts/          # Optional: executable code
  references/       # Optional: documentation
  assets/           # Optional: templates, resources
```

### SKILL.md Format
```yaml
---
name: skill-name
description: What it does (1-1024 chars, include keywords for matching)
version: 1.0.0
metadata:
  epistemos:
    requires_tools: [terminal, web_search]    # Tools this skill needs
    requires_env: [API_KEY]                    # Env vars needed
    platforms: [macos]                         # OS restrictions
    category: development                      # For UI grouping
    tags: [git, automation]                    # For search
---

## When to Use
Describe when the agent should activate this skill.

## Procedure
Step-by-step instructions the agent follows.

## Pitfalls
Common mistakes to avoid.

## Verification
How to verify the skill worked correctly.
```

### Progressive Disclosure (critical for token efficiency)
- **Tier 0 (~100 tokens):** Name + description. Loaded at startup for ALL skills.
- **Tier 1 (<5000 tokens):** Full SKILL.md body. Loaded on activation.
- **Tier 2 (as needed):** Referenced files. Loaded individually on demand.

### Rust Implementation
```
agent_core/src/skills/
  registry.rs    -- Scan directories, build tier-0 index
  loader.rs      -- Parse SKILL.md frontmatter + body
  matcher.rs     -- Match user intent to skill descriptions
  manager.rs     -- Create/edit/delete skills
  evolution.rs   -- GEPA mutation pipeline
```

---

## Rust Crate Dependency Map

### Already in Cargo.toml (verify)
- `tokio` -- async runtime
- `reqwest` -- HTTP client
- `serde` / `serde_json` -- serialization
- `tantivy` -- full-text search
- `rusqlite` -- SQLite

### Need to Add

| Crate | Used For | Tools |
|---|---|---|
| `chromiumoxide` | CDP browser automation | browser_* |
| `scraper` | HTML parsing | web_extract |
| `html2md` | HTML to markdown | web_extract |
| `grep-regex` + `grep-searcher` | ripgrep internals | search_files |
| `globset` | Glob pattern matching | search_files |
| `similar` | Diff/patch | patch |
| `content_inspector` | Binary file detection | read_file |
| `fs2` | File locking | memory |
| `walkdir` | Directory traversal | skills |
| `serde_yaml` | YAML frontmatter | skills |
| `cron` | Cron expression parsing | cronjob |
| `arboard` | Clipboard | clipboard |
| `sysinfo` | System info | system_info |
| `image` | Image processing | vision, media |
| `base64` | Base64 encoding | vision |
| `whisper-rs` | Local STT | speech_to_text |
| `git2` | Git operations | git, github |
| `octocrab` | GitHub API | github |
| `lettre` | SMTP email | email |
| `imap` | IMAP email | email |
| `feed-rs` | RSS parsing | rss_monitor |
| `lopdf` | PDF manipulation | pdf_edit |
| `sonor` | Sonos control | sonos |
| `nix` | Unix signals | process |
| `pyo3` | Python embedding | execute_code |

---

## What Epistemos Already Has

Cross-reference with your existing `agent_core/src/tools/`:

| Tool | Status | File |
|---|---|---|
| `think` | Done | `tools/think.rs` |
| `delegate_task` | Done | `tools/delegate_task.rs` |
| `vault_search` | Partial | `storage/vault.rs` |
| `memory` | Partial | `storage/memory_classifier.rs` + `memory_decay.rs` |
| `session_search` | Partial | `storage/session_store.rs` |
| `contradiction_check` | Done | `storage/contradiction_detector.rs` |
| `terminal` | Check | `tools/registry.rs` |
| `read_file` | Check | `tools/registry.rs` |
| `write_file` | Check | `tools/registry.rs` |
| `patch` | Check | `tools/registry.rs` |
| `search_files` | Check | `tools/registry.rs` |
| `web_search` | Via Perplexity | `providers/perplexity.rs` |
| `screenshot` | Via Swift | `Omega/Vision/ScreenCaptureService.swift` |
| `ax_automation` | Via Swift | `Omega/Vision/AXorcistBridge.swift` |
| `graph_query` | Via Rust | `graph-engine/src/engine.rs` |

### Gap Count
- **You have (done/partial):** ~15 tools
- **Hermes has:** 47 built-in + 71 skills = 118
- **OpenClaw has:** ~30 native + 53 bundled = 83
- **Combined unique (deduplicated):** ~95 distinct capabilities
- **You need to build:** ~80 tools/skills

### Realistic Shipping Order
1. **v1.0:** Tier 1 (12 core tools) + Tier 2 (8 knowledge tools) = 20 tools
2. **v1.1:** Tier 3 (browser + web, 14 tools) = 34 tools
3. **v1.2:** Tier 4 (macOS native, 10 tools) = 44 tools
4. **v1.3:** Tier 5-6 (communication + media, 17 tools) = 61 tools
5. **v2.0:** Tier 7-9 (smart home + dev + AI, 20 tools) = 81 tools
6. **v2.x:** Tier 10 (niche, 15+ tools) = 95+ tools
