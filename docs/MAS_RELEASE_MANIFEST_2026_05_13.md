# MAS Release Manifest — 2026-05-13

Authoritative inventory of what ships in the **`Epistemos-AppStore`**
scheme (Mac App Store build) at the
`checkpoint/theme-fonts-mas-ready-2026-05-13` tag and beyond.

This file is the single source of truth answer to "is feature X in
MAS?" during App Store Review prep and customer-support escalations.

## Build identity

| Field | MAS | Pro |
|---|---|---|
| Scheme name | `Epistemos-AppStore` | `Epistemos` |
| Bundle ID | `com.epistemos.appstore` | `com.epistemos.app` |
| Swift compile flag | `EPISTEMOS_APP_STORE` set | `EPISTEMOS_APP_STORE` unset |
| `agent_core` Cargo features | `mas-build,lsp-runtime` (no defaults) | `pro-build,lsp-runtime` (no defaults) |
| Sandbox | YES (`com.apple.security.app-sandbox = true` in Release) | NO |

## Features SHIPPING in MAS

### Agents + Models
- **Local agents** — MLX-based on-device inference (Qwen 3.5, etc.)
  via `MLXInferenceService`. Apple Intelligence via
  FoundationModels framework (macOS 26+).
- **Cloud agents** — direct URLSession to provider APIs (Anthropic
  Claude, OpenAI GPT, Google Gemini, Perplexity Sonar, OpenRouter,
  Z.AI, Kimi, DeepSeek, MiniMax, xAI, Mistral, Groq, HuggingFace).
  API keys stored in macOS Keychain (`SecItemAdd` / `SecItemCopyMatching`),
  never UserDefaults.
- **Operating modes** — Fast (1 turn / 0 tools), Thinking (1 turn /
  reasoning), Pro (3 turns / 8 tool calls), Agent (8 turns / 32 tool
  calls). Tool loops are bounded by `OverseerDepthBudget`.

### Tool surface (`ToolSurfacePolicy.coreAppStoreAllowedToolNames`)
32 canonical tool names exposed to MAS-visible tool surfaces:

**Vault + filesystem (scoped to vault root)**
- `vault.search`, `vault.read`, `vault.write`, `vault.list`
- `file.read`, `file.write`, `file.patch`, `file.search`

**System**
- `system.todo`

**Graph + memory**
- `graph.query`, `graph.neighbors`, `graph.vault_navigate`
- `memory.curated`

**Web (HTTPS via URLSession — no subprocess)**
- `web.search`, `web.extract`, `web.crawl`, `web.fetch`
- These read-only network tools route through the native approval gate.

**Vault knowledge**
- `knowledge.recall` (`vault_recall`)
- `knowledge.contradiction_check`
- `knowledge.evidence_score`
- `knowledge.session_search`
- `knowledge.neural_recall`

**Note authoring**
- `note.create`, `note.edit`, `note.research_digest`
- `note.template`, `note.linker`

**Composer helpers**
- `clarify.ask` — managed Rust agent sessions ask the user a follow-up question through the Swift delegate UI
- `research.search_papers` — read-only network tool, routed through native approval
- `research.collect_snippet`, `citation.save` — vault-scoped writes, routed through native approval plus the Rust R.5 resource grant gate
- `chunk.reduce`

**Pro-only tool surfaces hidden from MAS**
- `delegate_task`, `intelligence.mixture_of_minds`
- `skills.list`, `skills.view`, `skills.manage`

### Slash command CLI (`ACCSlashCommand`)
12+ in-app slash commands available in MAS:
- `/ask`, `/notes`, `/code`, `/debug`, `/plan`, `/research`,
  `/review`, `/security-review`, `/summarize`, `/read-branch`,
  `/explain`, `/todo`
- `/image` gated on whether `media.image_generate` tool surface
  resolves (currently MAS hides this).

### UI surfaces
- Landing greeting hero loop (Greetings/Researcher ↔ Click anywhere/to start a conversation)
- Chat with markdown rendering, code highlighting, AnswerPacket
  metadata chips, context-window indicator, AI disclaimer footer
- Notes editor (Tiptap WKWebView for .epdoc + TextKit 2 NSTextView
  for .md)
- Graph workspace (Metal SDF labels via `graph-engine` Rust crate)
- Halo / Shadow vault search (Tantivy lexical + usearch HNSW via
  `epistemos-shadow` Rust crate)
- Per-theme identity fonts (Classic = CoralPixels/RetroGaming,
  Platinum = MatrixTypeDisplay, Ember = ColorBasic-Regular with
  case-driven box glyphs + ChonkyPixels for H1-H3 + MatrixType for
  word count caption)
- Spotlight integration (CoreSpotlight indexing)
- Settings → Diagnostics rows (vault sync, search index, shadow
  search, editor bundle, background indexing, AnswerPacket, runtime
  truth, etc.)

## Features EXPLICITLY DENIED on MAS

These are NOT broken in MAS — they're denied by design with
explicit user-facing copy. Every entry point returns the
standardized denial string `"Native computer-use automation is
unavailable in the App Store build."` or the equivalent.

- **Subprocess execution** (`bash_execute`, `cli_passthrough`,
  `terminal`, `process`, `cronjob`) — Cargo `mas-build` feature
  `#[cfg]`-gates the entire `cli_passthrough.rs` + `terminal.rs`
  modules out of the Rust dylib. Symbol-leak audit (`nm -gU`)
  confirms ZERO matches for `osascript`, `bash_execute`,
  `cli_passthrough`, `stdio_mcp`, `browser_subprocess`,
  `imessage_send`, `cronjob`, `cli_{claude,codex,gemini,kimi}`,
  `computer_use` in the MAS dylib.
- **Computer use** (`computer`, `perceive`, `interact`,
  `screen_watch`) — Swift side gated via
  `AppStoreComputerUseStubs.swift` (`#if EPISTEMOS_APP_STORE`)
  returning the denial constant.
  `checkPermissions()` returns `.denied` for accessibility +
  automation, `.unknown` for screen recording.
- **Browser MCP** (`browser_navigate`, `browser_click`, etc.) — not
  in the MAS tool list; the chrome extension shim is Pro-only.
- **iMessage outbound** (`send_message`, `imessage`,
  `imessage_contacts`, `channel_contacts`) — subprocess-based
  AppleScript path, Pro-only.
- **Apple apps via osascript** (`apple_notes`, `apple_reminders`,
  `apple_calendar`, `apple_mail`) — subprocess-based, Pro-only.
- **Python / MoLoRA / KnowledgeFusion training** — `#if
  !EPISTEMOS_APP_STORE` gated at multiple sites. The QLoRA / KTO
  training paths require Python which is sandbox-forbidden.
- **CLI discovery health row** (`CLIDiscoveryHealthRow`) — entire
  file gated `#if !EPISTEMOS_APP_STORE` 2026-05-13. Previously the
  call site was gated but the file compiled in, leaking the literal
  paths `/usr/local/bin/{claude,codex,gemini,kimi}` into the MAS
  binary's `strings(1)` output. Now fully purged.
- **Embodied capture** (`EmbodiedCaptureService` — `screencapture`
  subprocess for synthetic-data training) — wholesale `#if
  !EPISTEMOS_APP_STORE` gated.

## Verification commands

Before every MAS App Store submission, re-run:

```bash
# 1. Build
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' \
  -configuration Release build

APP="path/to/Release/Epistemos.app"

# 2. Bundle ID + sandbox entitlement check
defaults read "$APP/Contents/Info.plist" CFBundleIdentifier
codesign -d --entitlements - "$APP" 2>&1 | grep app-sandbox

# 3. Subprocess path string scan (must return ZERO matches)
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'

# 4. Rust dylib symbol audit (must return ZERO matches)
nm -gU "$APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
```

Expected: 0 matches at steps 3 + 4. If anything appears, halt and
audit before submission.

## Cross-references

- `Epistemos/Bridge/ToolTierBridge.swift` —
  `ToolSurfacePolicy.coreAppStoreAllowedToolNames` (authoritative
  MAS tool list)
- `Epistemos/AppStore/AppStoreComputerUseStubs.swift` —
  denied-by-design computer-use stubs
- `Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift` — file-
  level gated `#if !EPISTEMOS_APP_STORE`
- `agent_core/Cargo.toml` — `mas-build` vs `pro-build` Cargo feature
  matrix
- `build-agent-core.sh` — prebuild script that picks the right
  Cargo feature based on `TARGET_NAME`
- Audit register RCA3-P0-001 / RCA4-P0-002 / RCA4-P2-002 — symbol-
  leak audits PATCHED 2026-05-13
