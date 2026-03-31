# Agent Integration: Remaining Work Plan

**Created:** 2026-03-30
**Last Updated:** 2026-03-30 (late session — Items 1-15 completed, Gemini analysis integrated)
**Context:** Items 1-15 are now COMPLETE and building clean. Remaining work is release hardening (Items 16-19), deferred architecture (Items 10-11), and two new items from Gemini deep analysis (Items 20-21).

---

## How to Reload Context

Start a new session with:

```
Read these files in order to understand the current state:
1. CLAUDE.md (project rules)
2. docs/AGENT_INTEGRATION_SESSION_PLAN.md (this file — the work plan)
3. Epistemos/ViewModels/AgentViewModel.swift (main agent orchestration — all MCP, budget, repair, skill discovery, loop/depth/cost/credential/threat scanning)
4. Epistemos/Omega/Orchestrator/OrchestratorState.swift (Omega execution loop — loop detector, checkpoint manager, depth limiter)
5. Epistemos/Omega/Safety/ (10 safety files — ToolLoopDetector, ContextBudgetManager, TranscriptRepair, ExecutionCheckpointManager, AgentDepthLimiter, MMRReranker, CredentialRedactor, CostTracker, ContextCompiler, MemoryThreatScanner, ShadowGitCheckpoint)
```

---

## What Was Completed (March 30 — Early Session)

### MCP Bridge Wiring
- [x] `EpistemosMCPServer` instantiated with vault_search, vault_read, vault_list tools
- [x] `HermesMCPClient` instantiated for Swift→Hermes bidirectional calls
- [x] `routeBridgeLine()` dispatcher — routes JSON-RPC requests/responses vs bridge events
- [x] Auto-refresh admin state (MCP servers, cron, skills, config) on bridge `"ready"`
- [x] Cron keepalive (60s tick via admin command)
- [x] TranscriptRepair wired into `parseSessionHistory()` — fixes orphaned tool_use/result pairs
- [x] ContextBudgetManager tracking tokens on "complete" events, auto-compact at 70%

### OpenClaw Safety Ports (6 files in Omega/Safety/)
- [x] ToolLoopDetector — SHA-256 hashing, 4 loop types, wired into OrchestratorState.executePlan()
- [x] ContextBudgetManager — token tracking, adaptive thinking budgets
- [x] TranscriptRepair — orphan cleanup, dedup, same-role merging
- [x] ExecutionCheckpointManager — atomic JSON persistence, wired into OrchestratorState
- [x] AgentDepthLimiter — subagent recursion cap at depth 3
- [x] MMRReranker — Jaccard similarity + MMR (lambda=0.7), wired into AgentGraphMemory.recall()

### Fusion Analysis Items
- [x] NaN/Inf sanitization at FFI boundary (graph-engine/src/lib.rs: add_node, add_nodes_batch, add_edge)
- [x] Native Skill Store — `skill_discover` + `skill_schema` MCP tools with MMR retrieval
- [x] Paste sanitization + IME guard (already production-grade in ProseTextView2)
- [x] Undo grouping for AI streaming (already production-grade in ProseEditorRepresentable2)
- [x] Security-scoped bookmark timeout (already production-grade — resolveVaultBookmarkWithTimeout)
- [x] NoteFileStorage atomic writes (already production-grade — temp→F_FULLFSYNC→rename)
- [x] FFI catch_unwind (already complete — 60+ call sites)

## What Was Completed (March 30 — Late Session: Items 1-15)

### Do First Tier (Safety + Cost) ✅
- [x] **Item 6:** ToolLoopDetector wired into Hermes bridge `tool_completed` events — interrupts agent on loop detection
- [x] **Item 5:** AgentDepthLimiter wired into Hermes bridge `tool_started`/`tool_completed` for delegate/subagent tools
- [x] **Item 15:** CredentialRedactor — 9 regex patterns (sk-, ghp_, AKIA, PEM, Bearer, token=, slack, hex secrets), wired into vault_search + vault_read
- [x] **Item 14:** CostTracker — micro-dollar precision, March 2026 pricing table (Sonnet/Opus/Haiku/Perplexity), cache discount, wired into `complete` events
- [x] **Item 8:** ContextCompiler — U-curve reordering applied to vault_search results

### Do Second Tier (Safety + Infrastructure) ✅
- [x] **Item 13:** MemoryThreatScanner — role hijack (9 patterns), exfiltration (5 patterns), invisible unicode (14 scalars), wired into vault_search + vault_read (blocks/sanitizes/flags)
- [x] **Item 12:** ShadowGitCheckpoint — actor with GIT_DIR/GIT_WORK_TREE separation, 10s timeout, auto-checkpoint on file-mutating tool_started events
- [x] **Item 3:** NightBrain menu bar agent mode — `nightbrain.menuBarAgent` config, `applicationShouldTerminateAfterLastWindowClosed`, Settings toggle
- [x] **Item 7:** Living Vault Rust modules verified (70/70 tests pass), UniFFI exports added: `classify_vault_memory`, `decay_memory_nodes`, `gc_memory_nodes`

### Do Third Tier (Features + Hardening) ✅
- [x] **Item 4:** SkillStoreView — category picker (7 categories), search, detail sheet, native + Hermes skill display
- [x] **Item 9:** QLoRATrainer now prefers composed `train_final.jsonl` (IFD-filtered, CAMPUS-sorted) over raw synthesis shards
- [x] **Item 1:** HTTP/SSE transport via NWListener for MCP payloads >50KB (deadlock prevention), MCPHttpListener with payload store
- [x] **Item 2:** recovery.rs (detect + repair: Latin-1, BOM, null bytes, truncated multibyte, 7 tests) + HexViewerView (dual-pane hex dump / repaired text, Rust FFI)

### Post-Implementation Audit ✅
- [x] Swift build: zero errors after xcodegen + xcodebuild
- [x] agent_core: 70/70 Rust tests pass
- [x] graph-engine: 2448/2448 Rust tests pass (+ 7 new recovery tests)
- [x] Architecture integrity: 3 force-unwrap violations found and fixed
- [x] No DispatchQueue.main.sync in new code, no try!, no print() in production paths

---

## Remaining Work Items

### Item 1: HTTP/SSE Transport for Heavy MCP Payloads

**Problem:** macOS has a hardcoded 64KB pipe buffer. If an MCP tool returns >64KB (e.g., a large file read, a deep AX tree dump, or a screenshot), the stdio pipe can deadlock.

**Current state:** All MCP communication uses stdio pipes. Typical payloads are well under 64KB, but screenshots (base64 PNG) and large AX trees could exceed it.

**What to build:**
- Add an HTTP/SSE transport option to `EpistemosMCPServer` alongside stdio
- When the bridge launches, start a localhost HTTP server on a dynamic port
- Pass the port to Hermes via the `"ready"` event
- For payloads >50KB, route through HTTP instead of stdio
- Use `NWListener` (Network.framework) for the HTTP server — zero external dependencies

**Files to touch:**
- `Epistemos/Agent/EpistemosMCPServer.swift` — add HTTP transport mode
- `Epistemos/ViewModels/AgentViewModel.swift` — start HTTP server in `connectIfNeeded()`, pass port in ready handler
- `hermes-agent/epistemos_bridge.py` — accept HTTP endpoint for large tool results

**Verification:**
- Send a 100KB tool result through the MCP server
- Confirm no deadlock on stdio
- Confirm HTTP fallback activates automatically

**Estimated complexity:** Medium-High. ~200 lines Swift, ~50 lines Python.

---

### Item 2: graph-engine/src/recovery.rs + HexViewerView

**Problem:** Notes corrupted by encoding errors (Mojibake, null-padded, multibyte truncation) have no recovery path. Users lose data.

**What to build:**
- `graph-engine/src/recovery.rs` — Rust module with:
  - Corruption detection heuristics (check for invalid UTF-8 sequences, null bytes in text, BOM markers)
  - Transcode chains: try Latin-1→UTF-8, Windows-1252→UTF-8, Shift-JIS→UTF-8
  - Return both the raw bytes and the best-effort repaired text
  - Export via FFI: `recovery_detect(bytes) -> CorruptionType` and `recovery_repair(bytes) -> String`
- `Epistemos/Views/Notes/HexViewerView.swift` — SwiftUI dual-pane view:
  - Left pane: hex dump of raw bytes (16 bytes per row, ASCII sidebar)
  - Right pane: heuristically repaired text
  - "Accept Repair" button that overwrites the note with the repaired text
  - Accessible from note context menu when corruption is detected

**Files to touch:**
- NEW: `graph-engine/src/recovery.rs`
- MODIFY: `graph-engine/src/lib.rs` — add FFI exports for recovery functions
- NEW: `Epistemos/Views/Notes/HexViewerView.swift`
- MODIFY: Note context menu (wherever the "..." menu is) — add "Repair Note" option

**Verification:**
- Create a test note with deliberately corrupted bytes (Latin-1 encoded text saved as UTF-8)
- Open HexViewerView, confirm hex dump is accurate
- Click "Accept Repair", confirm note is now valid UTF-8
- `cargo test` for the recovery module

**Estimated complexity:** Medium. ~150 lines Rust, ~200 lines Swift.

---

### Item 3: launchd Plist for NightBrain Cron Persistence

**Problem:** Hermes cron jobs only run while the app is open. If the user wants "every morning at 9am, summarize my inbox," the app must be running at 9am.

**Current state:** Cron ticks every 60s via `sendHermesCommand` while the subprocess is alive. No background execution.

**What to build:**
- A `launchd` plist that keeps the Hermes subprocess alive as a LaunchAgent
- OR: Use macOS `NSBackgroundActivityScheduler` (simpler, no root needed):
  - Register a background activity with `shouldDefer = false`
  - On trigger: launch the Hermes subprocess, run due cron jobs, terminate
  - Tolerance: 10 minutes (macOS batches background activities)
- A "Background Agent" toggle in Settings that enables/disables the LaunchAgent

**Approach decision needed from user:**
- **Option A: NSBackgroundActivityScheduler** — simpler, works in App Sandbox, but macOS may defer execution by hours. Best for "roughly daily" tasks.
- **Option B: LaunchAgent plist** — precise timing, but requires user to approve installing a LaunchAgent. Not App Sandbox compatible. Direct distribution only.
- **Option C: Keep app running as menu bar agent** — set `LSUIElement = true` when NightBrain is enabled, hide dock icon, show menu bar item. App stays alive and cron ticks normally. Simplest implementation.

**Files to touch (Option C — recommended):**
- `Epistemos/App/AppBootstrap.swift` — add menu bar agent mode toggle
- `Epistemos/Views/Settings/` — add NightBrain toggle in preferences
- `Info.plist` — conditionally set `LSUIElement`

**Verification:**
- Enable NightBrain mode
- Close all windows (app should stay alive in menu bar)
- Wait for a cron job to fire
- Confirm it executes and results appear in session history

**Estimated complexity:** Low-Medium. ~100 lines Swift.

---

### Item 4: Skill Store SwiftUI Storefront

**Problem:** The backend for skill discovery is done (MMR-scored `skill_discover` + `skill_schema` MCP tools), but there's no user-facing UI to browse, install, or manage skills.

**What to build:**
- `Epistemos/Views/Omega/SkillStoreView.swift` — SwiftUI view with:
  - Search bar with live filtering (uses MMR internally)
  - Grid/list of skill cards: icon, name, description, agent, install status
  - Detail sheet: full description, input schema, example arguments, safety info
  - 1-click "Enable" toggle per skill
  - Categories: Safari, File, Notes, Terminal, Automation, Custom
  - "Installed Skills" section showing user-created skills from SkillManifest
  - Token cost estimate per skill (how many tokens its schema adds to context)
- Wire into the Omega panel sidebar or a dedicated "Skills" tab

**Dependencies:**
- `OmegaToolRegistry.all` — existing tool catalog from Rust
- `SkillManifest` — existing user skill persistence
- `MMRReranker` — existing reranker for search
- `HermesAdminViewModel.installedSkills` — existing Hermes skill list

**Files to touch:**
- NEW: `Epistemos/Views/Omega/SkillStoreView.swift`
- MODIFY: Omega panel navigation (wherever tabs/sidebar is defined) — add Skills tab

**Verification:**
- Open Skill Store, see all native tools organized by agent
- Search "search web" — verify MMR returns diverse results (not 5 search variants)
- Toggle a skill on/off, confirm it persists across app restart
- Check that enabled skill count matches what Hermes receives in its tool list

**Estimated complexity:** Medium. ~300 lines SwiftUI.

---

### Item 5: Wire DepthLimiter into Hermes Delegate Tool

**Problem:** The `AgentDepthLimiter` is wired into `OrchestratorState` (the Omega path) but NOT into the Hermes agent path. If Hermes spawns sub-agents via `delegate_tool.py`, there's no Swift-side depth enforcement.

**What to build:**
- When Hermes sends a `"tool_started"` event with name containing "delegate" or "subagent", increment the depth limiter
- When that tool completes, decrement it
- If depth limit exceeded, send an interrupt command to Hermes with an error message

**Files to touch:**
- `Epistemos/ViewModels/AgentViewModel.swift` — in `handleHermesBridgeLine`, check depth on tool_started/tool_completed events

**Verification:**
- Configure a task that would cause Hermes to delegate recursively
- Confirm it's blocked at depth 3
- Confirm the error message reaches the UI

**Estimated complexity:** Low. ~20 lines.

---

### Item 6: Wire LoopDetector into Hermes Agent Path

**Problem:** Same as depth limiter — the `ToolLoopDetector` is wired into `OrchestratorState` (Omega) but NOT into the Hermes bridge event stream. If Hermes enters an infinite tool-calling loop, the Swift side doesn't detect it.

**What to build:**
- On each `"tool_completed"` event from Hermes, call `loopDetector.record()`
- If a loop is detected, send an interrupt command to Hermes
- Show the loop detection message in the UI

**Files to touch:**
- `Epistemos/ViewModels/AgentViewModel.swift` — add a `ToolLoopDetector` property, record on tool_completed, check and interrupt

**Verification:**
- Simulate a loop (agent calling the same tool with same args 4+ times)
- Confirm the loop detector fires and interrupts the agent
- Confirm UI shows the loop detection message

**Estimated complexity:** Low. ~30 lines.

---

## Priority Order

1. **Item 6: Wire LoopDetector into Hermes path** (Low effort, high safety value)
2. **Item 5: Wire DepthLimiter into Hermes path** (Low effort, high safety value)
3. **Item 3: NightBrain cron persistence** (Low-Medium effort, enables key feature)
4. **Item 4: Skill Store SwiftUI** (Medium effort, polishes UX)
5. **Item 1: HTTP/SSE transport** (Medium-High effort, prevents edge-case deadlocks)
6. **Item 2: Recovery + HexViewer** (Medium effort, edge-case data recovery)

---

## Architecture Reference

```
Epistemos.app (Swift 6 + Rust/UniFFI)
├── AgentViewModel.swift ← MCP server/client, bridge routing, budget, repair
│   ├── EpistemosMCPServer ← vault_search, vault_read, vault_list, skill_discover, skill_schema
│   ├── HermesMCPClient ← Swift→Hermes tool calls
│   ├── ContextBudgetManager ← token tracking, auto-compact
│   └── routeBridgeLine() ← JSON-RPC dispatch (server/client/events)
│
├── OrchestratorState.swift ← Omega DAG execution loop
│   ├── ToolLoopDetector ← 4 loop types, SHA-256 hashing
│   ├── ExecutionCheckpointManager ← atomic crash recovery
│   └── AgentDepthLimiter ← recursion cap
│
├── AgentGraphMemory.swift ← recall() with MMR reranking
├── MMRReranker.swift ← Jaccard + diversity scoring
├── TranscriptRepair.swift ← orphan/dedup/merge repair
│
├── graph-engine/src/lib.rs ← NaN sanitization, catch_unwind
│
└── hermes-agent/ (Python subprocess, managed via HermesSubprocessManager)
    ├── epistemos_bridge.py ← stdio JSON bridge
    ├── run_agent.py ← AIAgent core loop
    └── cron/scheduler.py ← background job scheduler
```

---

## Phase 3: Living Vault Memory Engine

**Source:** `docs/sprint-sessions/sprint-omega-5-living-vault.md`, Gemini Antigravity `agent_fusion_analysis.md` §2

**Current state:** The Rust storage modules exist (`agent_core/src/storage/`) but need verification and Swift-side wiring.

### Item 7: Verify + Wire Rust Living Vault Modules

**Existing Rust files (need audit):**
- `agent_core/src/storage/diff_engine.rs` — atomic Unix patch generation via `similar` crate
- `agent_core/src/storage/vault_git.rs` — `libgit2` integration for atomic cognitive commits
- `agent_core/src/storage/memory_classifier.rs` — 4-way ADD/UPDATE/DELETE/NOOP classifier
- `agent_core/src/storage/memory_decay.rs` — Ebbinghaus decay with lambda=0.01/day

**What to do:**
1. Read each file and verify it compiles (`cargo test --manifest-path agent_core/Cargo.toml`)
2. Check if these modules are exported via UniFFI to Swift
3. Wire into the agent's vault_write path: when the agent writes a note, run the classifier first
4. Wire memory_decay into the NightBrain cron tick (Item 3)
5. Wire vault_git so agent edits produce semantic git commits

**Files to touch:**
- `agent_core/src/storage/` (4 files — audit and fix)
- `agent_core/src/lib.rs` or `agent_core/src/bridge.rs` — UniFFI exports for vault operations
- `Epistemos/ViewModels/AgentViewModel.swift` — route vault_write through classifier before disk write

**Verification:**
- Agent writes a note → classifier determines ADD/UPDATE/DELETE/NOOP
- Git log shows semantic commit messages like `[MEMORY:UPDATE] Updated transformer notes`
- Run decay with fast-forwarded time → weakly accessed nodes pruned

**Estimated complexity:** Medium-High. Mostly wiring + testing existing code.

---

### Item 8: Context Compiler with "Lost in the Middle" Awareness

**Problem:** LLMs attend most to the beginning and end of context, with a valley in the middle (the "Lost in the Middle" problem). The context compiler should place high-relevance items at head and tail, with lower-relevance items in the middle.

**What to build:**
- A `ContextCompiler` that takes ranked search results and arranges them in U-curve order
- Place the top result first, second result last, third result second, fourth result second-to-last, etc.
- Apply `cache_control` breakpoints on the stable system prefix for Anthropic prompt caching

**Files to touch:**
- NEW: `Epistemos/Omega/Safety/ContextCompiler.swift` or add to existing ContextBudgetManager
- MODIFY: AgentViewModel.swift — use compiler when building context for vault_search results

**Estimated complexity:** Low. ~50 lines.

---

## Phase 4: Pipeline Hardening (Master Gap Closure)

**Source:** Gemini Antigravity `implementation_plan.md` Phase 1, `2026-03-27-master-gap-closure-plan.md`

**Current state (verified 2026-03-30):**
- Deploy gate in `TrainingScheduler.swift` is REAL (not a stub) — runs `eval_bfcl.py` and checks regression
- `resolveTargetPID` in `OrchestratorState.swift` correctly resolves target app PIDs via NSWorkspace
- QLoRATrainer exists but doesn't reference `train_final.jsonl` or `compose_training_mix.py`

### Item 9: Wire QLoRATrainer to Composed Training Data

**Problem:** The QLoRATrainer may be reading raw data shards instead of the IFD-filtered, CAMPUS-sorted `train_final.jsonl` from `compose_training_mix.py`.

**What to do:**
1. Read `QLoRATrainer.swift` to understand its current data loading path
2. Read `compose_training_mix.py` (if it exists) to understand the output format
3. Ensure QLoRATrainer exclusively reads from the composed output
4. Verify IFD filtering and CAMPUS curriculum sorting aren't bypassed

**Files to touch:**
- `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`
- Related training data composition scripts

**Verification:**
- Training run uses `train_final.jsonl` as the sole data source
- Data is IFD-filtered (low-quality samples removed) and CAMPUS-sorted (curriculum order)

**Estimated complexity:** Medium. Requires understanding the training pipeline.

---

## Phase 5: OpenClaw Network Layer (Deferred — Design Pass Needed)

**Source:** Gemini Antigravity `agent_fusion_analysis.md` §1, OpenClaw `docs.acp.md`

**These do NOT exist yet and are the most architecturally complex items:**

### Item 10: Tokio WebSocket Gateway (agent_core)

**What:** A local WebSocket gateway (`ws://127.0.0.1:18789`) that routes ACP messages between the Swift host, IDE extensions, and remote execution nodes.

**Why deferred:** This is a significant architectural addition. The current MCP bridge handles local communication fine. The gateway becomes important when:
- Multiple clients need to connect (IDE + app + CLI simultaneously)
- Remote execution nodes are added (iOS companion app)
- Docker-isolated sessions are needed

**Files to create:**
- `agent_core/src/networking/gateway_node.rs`
- `agent_core/src/networking/acp_router.rs`

**Decision needed:** Is multi-client support needed for the initial release, or can this wait for v2?

### Item 11: Docker Sandbox Executor

**What:** Run untrusted or experimental agent sessions in Docker containers for isolation.

**Why deferred:** Requires Docker Desktop to be installed. Not suitable for MAS distribution. Only relevant for power users running self-hosted agents.

**Files to create:**
- `agent_core/src/sandbox/docker_executor.rs`

**Decision needed:** Is Docker isolation a release requirement or a post-launch feature?

---

---

## Phase 6: OpenClaw Patterns Not Yet Ported

**Source:** Deep dive into OpenClaw/Hermes codebase (March 30 analysis)

These are genuinely novel patterns from OpenClaw that Epistemos doesn't have yet. Verified as NOT implemented.

### Item 12: Shadow Git Checkpoints (Transparent File Snapshots)

**What OpenClaw does:** Before any file-mutating tool (write_file, patch), it creates a git snapshot in a shadow repo at `~/.hermes/checkpoints/{sha256(dir)[:16]}/`. Uses `GIT_DIR` + `GIT_WORK_TREE` separation so the `.git` folder doesn't leak into the user's project. Configurable excludes (node_modules, .env, etc.) and 30s timeout on git operations.

**Why we need it:** The ExecutionCheckpointManager saves step STATUS (pending/running/completed) but NOT the file contents. If the agent corrupts a file, there's no rollback to the pre-edit version.

**What to build:**
- `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` — creates shadow git repos per vault directory
- Before any vault_write MCP tool call, snapshot the current file state
- Provide a `vault_rollback` MCP tool that Hermes or the user can invoke
- Exclude patterns: `.git/`, `node_modules/`, `.env`, `__pycache__/`, `.DS_Store`
- Timeout: 10s on git operations (use `Process` with timeout)

**Files to touch:**
- NEW: `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift`
- MODIFY: `AgentViewModel.swift` — call checkpoint before vault_write, register vault_rollback tool

**Estimated complexity:** Medium. ~150 lines.

### Item 13: Memory Threat Scanning on Vault Writes

**What OpenClaw does:** Before injecting MEMORY.md or USER.md into the system prompt, it scans for prompt injection patterns, role hijack attempts, exfiltration URLs, invisible unicode, and SSH backdoor insertions.

**Why we need it:** If an attacker-controlled document is in the vault, the agent could inject it into context and follow malicious instructions.

**What to build:**
- `Epistemos/Omega/Safety/MemoryThreatScanner.swift` — scan text for:
  - Role hijack: `"you are now"`, `"ignore previous"`, `"system:"`, `"<|im_start|>"`
  - Exfiltration: URLs with API keys, `curl | sh`, `wget | bash`
  - Invisible unicode: zero-width joiners, RTL overrides, homograph characters
  - SSH/credential patterns: `-----BEGIN`, `AKIA`, `ghp_`, `sk-`
- Return a `ThreatLevel` (safe/suspicious/blocked) and list of detected threats
- Wire into vault_search results before they enter the agent's context

**Files to touch:**
- NEW: `Epistemos/Omega/Safety/MemoryThreatScanner.swift`
- MODIFY: `AgentViewModel.swift` — scan vault_search results before returning to Hermes

**Estimated complexity:** Medium. ~120 lines.

### Item 14: Cost Tracking with Micro-Dollar Precision

**What OpenClaw does:** Tracks all API costs in integer micro-dollars (1 micro-dollar = $0.000001) to avoid float precision loss. Per-model, per-provider, per-session breakdown with March 2026 pricing tables including cache read cost differentiation.

**Why we need it:** The ContextBudgetManager tracks tokens but not dollars. Users need to see "this session cost $0.47" in the UI.

**What to build:**
- `Epistemos/Omega/Safety/CostTracker.swift`:
  - Pricing table: claude-sonnet-4-6 ($3/$15 per M), claude-opus-4-6 ($15/$75), claude-haiku-4-5 ($0.80/$4), perplexity ($1/$5)
  - Cache read discount: 90% off input tokens for cached prefix
  - Store cumulative cost per session in micro-dollars (Int64)
  - Wire into AgentViewModel "complete" event (already has input/output token counts)
- Add a cost display to the agent panel footer

**Files to touch:**
- NEW: `Epistemos/Omega/Safety/CostTracker.swift`
- MODIFY: `AgentViewModel.swift` — compute cost on "complete" event, expose as observable property

**Estimated complexity:** Low-Medium. ~100 lines.

### Item 15: Credential Redaction Before Context Injection

**What OpenClaw does:** Before any text enters conversation history, it's scanned for credentials (API keys, tokens, private keys, database passwords). Detected credentials are partially masked (first 4 + last 4 chars visible, middle replaced with `***`).

**Why we need it:** If a vault note contains an API key and gets pulled into context via vault_search, that key could be leaked to the cloud API provider.

**What to build:**
- Add to `MemoryThreatScanner.swift` (or separate `CredentialRedactor`):
  - Detect: `sk-...`, `ghp_...`, `AKIA...`, `-----BEGIN...KEY-----`, `Bearer ...`, `token=...`
  - Redact: show first 4 + last 4 chars, mask middle
  - Apply to vault_search results and vault_read output before sending to Hermes

**Files to touch:**
- MODIFY: `Epistemos/Omega/Safety/MemoryThreatScanner.swift` (add redaction methods)
- MODIFY: vault_read and vault_search tool handlers in `AgentViewModel.swift`

**Estimated complexity:** Low. ~60 lines.

---

## Phase 6.5: Gemini Deep Analysis Upgrades (2026-03-30)

**Source:** `~/.gemini/antigravity/brain/0d3792b7-.../artifacts/epistemos_architecture_upgrade.md.resolved`

A deep comparative analysis of OpenClaw (TypeScript, gateway-centric) and Hermes Agent (Python, SQLite-backed) was conducted by Gemini. Six proposals were evaluated against Epistemos's actual Swift+Rust+Metal architecture. Two were accepted as high-leverage. Four were rejected as inapplicable.

### Item 20: NightBrain Heartbeat Memory Distillation

**Source:** OpenClaw's `HEARTBEAT.md` paradigm — periodic idle-time memory consolidation.

**Problem:** NightBrain runs maintenance jobs (WAL checkpoint, dedup, compaction) but does NOT process memory. The `ContextBudgetManager` "80% rule" triggers compaction reactively during active sessions, causing latency spikes. Memory consolidation should happen in the background during idle time.

**What to build:**
- Add a new `NightBrainService.Job.memoryDistillation` case
- During idle NightBrain execution, call the Rust Living Vault FFI exports we added in Item 7:
  - `decay_memory_nodes()` — apply Ebbinghaus decay to all AgentGraphMemory nodes
  - `gc_memory_nodes()` — garbage-collect nodes below strength 0.15
  - `classify_vault_memory()` — classify recent session content against existing vault facts, auto-consolidate
- Write consolidated results back to vault via AgentGraphMemory

**Files to touch:**
- MODIFY: `Epistemos/State/NightBrainService.swift` — add `memoryDistillation` job case
- MODIFY: `Epistemos/Omega/Knowledge/AgentGraphMemory.swift` — add `distillFromRecentSessions()` method

**Verification:**
- Enable NightBrain, wait for idle trigger
- Check that memory node strengths have been updated (decayed)
- Check that weak nodes were garbage-collected
- Check that new session content was classified and consolidated

**Estimated complexity:** Low-Medium. ~80 lines Swift.

### Item 21: Sub-Agent Hierarchical Context Scoping

**Source:** OpenClaw's `AGENTS.md` paradigm — narrow, role-specific context for sub-agents.

**Problem:** When Hermes delegates to sub-agents via `delegate_tool.py`, the sub-agent inherits the full master prompt, wasting tokens and risking behavioral drift. A terminal sub-agent doesn't need the global user identity or research context.

**What to build:**
- Modify `hermes-agent/tools/delegate_tool.py` to accept a `context_scope` parameter
- Define role-specific context files in `hermes-agent/contexts/` (e.g., `terminal_agent.md`, `research_agent.md`, `file_agent.md`)
- Sub-agents load only their scoped context file instead of the full system prompt
- Falls back to full context if no scope file matches

**Files to touch:**
- MODIFY: `hermes-agent/tools/delegate_tool.py` — add context_scope parameter
- NEW: `hermes-agent/contexts/terminal_agent.md`
- NEW: `hermes-agent/contexts/research_agent.md`
- NEW: `hermes-agent/contexts/file_agent.md`

**Verification:**
- Delegate a terminal task — confirm sub-agent prompt is <2K tokens (not 8K+)
- Delegate a research task — confirm it uses research-specific context
- Confirm depth limiter still fires at depth 3

**Estimated complexity:** Low. ~40 lines Python + 3 small markdown files.

### Gemini Proposals — Evaluated and Rejected

These four proposals from the Gemini analysis were evaluated and rejected because they don't match Epistemos's architecture:

| Proposal | Rejection Reason |
|---|---|
| **A2UI Protocol for SwiftUI** | Epistemos already renders natively in SwiftUI via `AgentViewModel` → `ContentBlocks` → SwiftUI views. No browser/web client exists. Defining a JSON schema language for structured rendering is a valid post-launch design project, but not an integration task. |
| **PyO3 FFI Bridge (Python→Rust)** | The essay assumes a Python-first architecture. Epistemos is Swift→Rust via UniFFI. We already have the compiled FFI path the essay recommends — it just recommends it in the wrong direction. Hermes subprocess is for orchestration, not heavy compute. |
| **Zero-Trust WebSocket Handshakes** | Epistemos is a local macOS app. MCP bridge uses stdio pipes within the same process. Cryptographic nonce signing on localhost is overengineering. Noted for future use IF Item 10 (WebSocket Gateway) is ever built. |
| **Credential-Injecting Network Proxy for Docker** | Item 11 (Docker Sandbox) is deferred. Building a proxy for an executor that doesn't exist is premature. Noted for future use IF Item 11 is ever built. |

---

## Phase 7: Release Hardening (Before Shipping)

**Source:** `docs/handoffs/2026-03-28-final-claude-release-master-handoff.md`, `docs/handoffs/2026-03-28-jojo-manual-release-checklist.md`, `docs/handoffs/2026-03-28-codex-claude-release-preservation-prompt.md`

### Item 16: Release Preflight + Bundle Verification

**What exists:** `scripts/audit/release_preflight.sh` — runs Rust tests, fresh build, codesign verify, asset checks.

**What to do:**
1. Run `./scripts/audit/release_preflight.sh` and fix any failures
2. Verify the app bundle contains:
   - `Contents/Frameworks/libepistemos_core.dylib`
   - `Contents/Frameworks/libomega_mcp.dylib`
   - `Contents/Frameworks/libomega_ax.dylib`
   - `Contents/Resources/model_manifest.json`
   - `Contents/Resources/PrivacyInfo.xcprivacy`
   - `Contents/Resources/RetroGaming.ttf`
   - `Contents/Resources/KnowledgeFusion/` runtime files
3. Verify NO `Contents/PlugIns` directory exists
4. Run `codesign --verify --deep --strict --verbose=4 <app>`

**Estimated complexity:** Low. Mostly verification.

### Item 17: DMG Packaging + Notarization Script

**What to build:**
- `scripts/release/package_dmg.sh`:
  1. Clean build with `xcodebuild -configuration Release`
  2. Sign with `Developer ID Application: <identity>`
  3. Create DMG with `create-dmg` or `hdiutil`
  4. Submit for notarization: `xcrun notarytool submit --wait`
  5. Staple: `xcrun stapler staple`
  6. Verify: `spctl --assess --type execute -vvv`
  7. Generate SHA-256 checksum

**Prerequisites (user must do manually):**
- Active Apple Developer Program enrollment
- `Developer ID Application` certificate installed in Keychain
- App-specific password for notarization stored in Keychain

**Files to create:**
- `scripts/release/package_dmg.sh`
- `scripts/release/notarize.sh`

**Estimated complexity:** Medium. ~150 lines bash.

### Item 18: Privacy Policy + ToS + License Attribution

**What to create:**
- `docs/legal/privacy-policy.md` — what data is collected, where it goes, how to delete
- `docs/legal/terms-of-service.md` — standard software ToS
- `docs/legal/licenses.md` — open-source attribution:
  - GRDB (MIT)
  - MLX / mlx-swift (MIT)
  - HuggingFace Transformers (Apache 2.0)
  - AXorcist (MIT)
  - tantivy (MIT)
  - sqlite-vec (MIT)
  - Hermes-Agent (MIT)
  - Any other bundled dependencies
- Host at a URL (GitHub Pages or similar)
- Reference URL in app's Settings and Info.plist

**Estimated complexity:** Low-Medium. Mostly writing, not code.

### Item 19: Fresh-Machine Verification Protocol

**Cannot be automated — must be done manually by user:**

1. Create a clean macOS user account (or use a fresh Mac)
2. Copy the notarized DMG
3. Install to `/Applications`
4. Launch WITHOUT Xcode or dev tools present
5. Verify:
   - [ ] App launches without crash
   - [ ] No missing-dylib errors
   - [ ] No missing-asset errors
   - [ ] App does not depend on repo-relative paths
   - [ ] First-launch permission flow works (Accessibility, Screen Recording)
   - [ ] Vault creation via NSOpenPanel works
   - [ ] Note creation and editing works
   - [ ] AI agent responds (cloud model with API key)
   - [ ] Local model downloads and runs
   - [ ] Omega panel opens and shows agent phases
   - [ ] Graph visualization renders
   - [ ] Search returns results

**Estimated complexity:** N/A — manual testing only.

---

## MAS Compliance Checklist (If Mac App Store Is Attempted)

This is a comprehensive checklist extracted from the 2026 Mac App Store compliance research. Only relevant if distributing via MAS (currently blocked — see Distribution Decision in MASTER_SESSION_PROMPT.md).

### Consent Architecture (Guideline 5.1.2(i))
- [ ] First-Use Consent Dialog per agentic action (NOT blanket consent)
- [ ] Explicit provider name + API endpoint in consent dialog
- [ ] AI-generated content visually distinguished (watermarks/indicators)
- [ ] Privacy Dashboard for reviewing + revoking AI integrations
- [ ] Consent revocation without app deletion

### PII Scrubbing Engine
- [ ] ANE-powered NER scan before cloud API calls
- [ ] Token substitution for detected PII (names, finances, addresses)
- [ ] Rehydration on response return (within sandbox)
- [ ] Zero raw PII transmitted to cloud providers

### Sandbox + XPC Architecture
- [ ] Heavy agent logic in XPC Service (crash-isolated from UI)
- [ ] DAS-CTS scheduling for background tasks (not continuous loops)
- [ ] XPC_ACTIVITY_PRIORITY_UTILITY for compute-heavy work
- [ ] Lifecycle Persistence — save state on expiration signal
- [ ] Balance security-scoped bookmark access/release calls

### AppIntents Integration
- [ ] Map agent actions to AppIntents where possible
- [ ] AppEntity + NSUserActivity for on-screen context
- [ ] Semantic control (intent handler) over pixel automation

### Required Entitlements
- [ ] `com.apple.security.cs.allow-jit` with Review Notes justification
- [ ] `com.apple.security.files.user-selected.read-write` for vault
- [ ] `com.apple.developer.accessibility` with graceful AXIsProcessTrusted flow
- [ ] `com.apple.security.cs.allow-unsigned-executable-memory` (MLX weights)
- [ ] `com.apple.security.cs.disable-library-validation` (Rust FFI dylibs)

### Texas Regulatory (TDPSA/TASAA/TRAIGA)
- [ ] TDPSA: Zero-retention for non-essential PII
- [ ] TASAA: Volatile memory-only age verification
- [ ] TRAIGA: Immutable system guardrails + post-generation output filter

### Glass Box UI
- [ ] Real-time Activity Stream (visible agent reasoning)
- [ ] Traceability Matrix (sources linked to conclusions)
- [ ] Pre-Action Validation Gates for destructive actions
- [ ] Progressive "Always Allow" for low-risk domains

### Energy + Performance (Guideline 2.4.2)
- [ ] No continuous background loops
- [ ] BGContinuedProcessingTask with expiration handler
- [ ] Stateless task design (serialize/resume across interruptions)
- [ ] Energy impact monitoring via MetricKit

---

## Updated Priority Order (All Phases)

### ~~Do First~~ ✅ COMPLETE
1. ~~Item 6: Wire LoopDetector into Hermes path~~
2. ~~Item 5: Wire DepthLimiter into Hermes path~~
3. ~~Item 15: Credential Redaction~~
4. ~~Item 14: Cost Tracking~~
5. ~~Item 8: Context Compiler with U-curve ordering~~

### ~~Do Second~~ ✅ COMPLETE
6. ~~Item 13: Memory Threat Scanning~~
7. ~~Item 12: Shadow Git Checkpoints~~
8. ~~Item 3: NightBrain cron persistence~~
9. ~~Item 7: Verify + Wire Living Vault Rust modules~~

### ~~Do Third~~ ✅ COMPLETE
10. ~~Item 4: Skill Store SwiftUI~~
11. ~~Item 9: Wire QLoRATrainer to composed data~~
12. ~~Item 1: HTTP/SSE transport for heavy MCP~~
13. ~~Item 2: Recovery + HexViewer~~

### ~~Do Next~~ ✅ COMPLETE
14. ~~Item 20: NightBrain Heartbeat Memory Distillation~~ (~80 lines, uses existing Rust FFI)
15. ~~Item 21: Sub-Agent Hierarchical Context Scoping~~ (~40 lines Python, narrow sub-agent prompts)

### Do Fourth (Release hardening — before shipping)
16. **Item 16: Release preflight + bundle verification** (~30 min)
17. **Item 17: DMG packaging + notarization script** (~100 lines bash)
18. **Item 18: Privacy policy + ToS + license attribution** (legal docs)
19. **Item 19: Fresh-machine verification protocol** (manual test)

### Do Later (Architectural — needs design pass)
20. **Item 10: Tokio WebSocket Gateway** (multi-client support) — if added, include Zero-Trust nonce signing per Gemini analysis
21. **Item 11: Docker Sandbox Executor** (isolation) — if added, include credential-injecting network proxy per Gemini analysis

---

## Key Files to Read When Starting

| File | Why |
|---|---|
| `Epistemos/ViewModels/AgentViewModel.swift` | Central orchestration — all MCP, budget, repair, skill discovery |
| `Epistemos/Omega/Orchestrator/OrchestratorState.swift` | Omega execution — loop detection, checkpoints, depth limiting |
| `Epistemos/Omega/Safety/*.swift` | 11 safety files: ToolLoopDetector, ContextBudgetManager, TranscriptRepair, ExecutionCheckpointManager, AgentDepthLimiter, MMRReranker, CredentialRedactor, CostTracker, ContextCompiler, MemoryThreatScanner, ShadowGitCheckpoint |
| `Epistemos/Agent/HermesSubprocessManager.swift` | Subprocess lifecycle, crash recovery, pre-warm |
| `Epistemos/Agent/EpistemosMCPServer.swift` | MCP server (tools/list, tools/call routing) |
| `Epistemos/Agent/HermesMCPClient.swift` | MCP client (JSON-RPC with timeout) |
| `Epistemos/Omega/MCPBridge.swift` | OmegaToolRegistry — Rust-driven tool catalog |
| `hermes-agent/epistemos_bridge.py` | Python bridge — stdio protocol, admin commands |
| `agent_core/src/storage/` | Living Vault Rust modules (diff, git, classifier, decay) |
| `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift` | Training pipeline |
| `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift` | Deploy gate + eval |
| `docs/sprint-sessions/sprint-omega-5-living-vault.md` | Living Vault architecture spec |

## Source Documents (for deep context)

| Document | Location | What It Contains |
|---|---|---|
| Gemini Antigravity Fusion Analysis | `~/.gemini/antigravity/brain/c766d684.../agent_fusion_analysis.md` | OpenClaw gateway, Living Vault, context compaction, gap closure |
| Gemini Antigravity Implementation Plan | `~/.gemini/antigravity/brain/c766d684.../implementation_plan.md` | 3-phase execution plan with verification |
| OpenClaw ACP Protocol | `jojo/openclaw-main/docs.acp.md` | Agent Client Protocol spec, session mapping |
| Living Vault Architecture | `docs/sprint-sessions/sprint-omega-5-living-vault.md` | 4-op classifier, Git persistence, Ebbinghaus decay |
| Hermes Integration Research | `docs/HERMES_INTEGRATION_RESEARCH.md` | 40-file study, feature roadmap, verification checklist |
| Agent Deep Verification Manual | `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` | 3-pass audit protocol, evidence standards |
| Gemini Architecture Upgrade Analysis | `~/.gemini/antigravity/brain/0d3792b7-.../epistemos_architecture_upgrade.md.resolved` | OpenClaw/Hermes deep comparison, 6 proposals (2 accepted, 4 rejected) |

## OpenClaw Patterns Reference (from March 30 deep dive)

These are the specific files in the Hermes/OpenClaw codebase where the novel patterns live. Read these when implementing Items 12-15:

| Pattern | Source File | Key Lines |
|---|---|---|
| Shadow git checkpoints | `hermes-agent/tools/checkpoint_manager.py` | Shadow repo creation, GIT_DIR/GIT_WORK_TREE separation, exclude patterns |
| Memory threat scanning | `hermes-agent/tools/memory_tool.py` | Injection detection before MEMORY.md/USER.md injection |
| Credential redaction | `hermes-agent/agent/redact.py` | Partial masking (first 4 + last 4 chars), pattern detection |
| Dangerous command approval | `hermes-agent/tools/approval.py` | 75+ regex patterns, 4-scope model |
| Tirith pre-exec scanning | `hermes-agent/tools/tirith_security.py` | Homograph URLs, pipe-to-interpreter, terminal injection |
| Granular read loop tracking | `hermes-agent/tools/file_tools.py:56-163` | `(path, offset, limit)` tuple tracking per task |
| Session search + summarization | `hermes-agent/tools/session_search_tool.py` | FTS5 + cheap LLM summary pipeline |
| Context compressor (5-phase) | `hermes-agent/agent/context_compressor.py` | Prune → protect head → protect tail → summarize → fold |
| Cost tracking (micro-dollars) | `reference-code/` patterns | Integer micro-dollars, per-model pricing tables |
| ACP session persistence | `hermes-agent/acp_adapter/session.py` | SQLite SessionDB, recovery on reconnect |

## Post-Implementation Audit Checklist

After completing all items, run this verification pass:

### Automated
```bash
# Rust tests
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path graph-engine/Cargo.toml

# Swift build
xcodegen generate
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep "error:"

# Focused Swift tests (if test targets exist)
xcodebuild -scheme Epistemos -destination 'platform=macOS' test-without-building \
  -only-testing:EpistemosTests 2>&1 | tail -20
```

### Manual Runtime Verification
1. **MCP Bridge**: Launch app → agent panel → type a prompt → verify thinking/text/tools stream correctly
2. **Vault Tools**: Ask agent "search my notes for X" → verify vault_search returns results
3. **Skill Discovery**: Ask agent "what tools can you use?" → verify skill_discover returns MMR-ranked list
4. **Loop Detection**: Make agent repeat same tool call 4x → verify it gets interrupted
5. **Cron**: Create a cron job via admin panel → wait 60s → verify it ticks
6. **Transcript Repair**: Inspect session history → verify no orphaned tool_use/result blocks
7. **Cost Tracking** (when built): Complete a multi-turn session → verify cost in micro-dollars is shown
8. **Credential Redaction** (when built): Put an API key in a vault note → vault_search it → verify key is masked
9. **Shadow Git** (when built): Agent writes a note → check `~/Library/Application Support/Epistemos/checkpoints/` for git snapshot
10. **Context Budget**: Run a long session (10+ turns) → verify auto-compact fires at 70%

### Architecture Integrity Check
- [ ] No `DispatchQueue.main.sync` in UniFFI callbacks (deadlock)
- [ ] No `try!` or force-unwraps in production paths
- [ ] No `print()` in production paths (use `os.Logger`)
- [ ] All `@Sendable` closures capture value types or use `[weak self]`
- [ ] All file writes use atomic temp→rename (not direct write)
- [ ] Thinking blocks preserved in message history (not stripped)
- [ ] Tool results clamped to ≤16K chars before context injection
