# Epistemos Vision Backlog — Comprehensive Future Work

**Last Updated:** 2026-04-01
**Source:** Brain dump + all research docs + codebase audit

This is the COMPLETE list of remaining work. Items are organized by theme and priority tier.

---

## TIER 0: SHIP-BLOCKING (Cannot release without these)

### 0A. Notarization + Sparkle Auto-Update
- DMG packaging exists (GitHub Actions) but NO xcrun notarytool step
- No Sparkle SUFeedURL or SUPublicEDSAKey configured
- Cannot distribute without notarization on macOS
- **Action:** Add notarize step to release.yml, configure Sparkle 2, add SUFeedURL to Info.plist

### 0B. ResearchPause Continuation Fix
- Has timeout (120s) but potential double-resume crash
- Needs atomic completion guard (same pattern as ConfirmationGate fix)
- **File:** `Epistemos/Omega/Orchestrator/ResearchPause.swift`

### 0C. EmbeddingService Main Thread Hang
- 3738ms hang during "pushed 1017 embeddings" — MainActor.run block after FFI call
- Profile with Instruments, move remaining MainActor work to background
- **File:** `Epistemos/Graph/EmbeddingService.swift`

---

## TIER 1: HERMES AGENT PARITY (Close the gap with upstream v0.6.0)

### 1A. Merge Hermes v0.6.0 Updates
Hermes shipped 95 PRs. Key features missing from Epistemos:
- **Profiles:** Multiple isolated Hermes instances (separate config, memory, sessions, skills)
- **MCP Server Mode:** Hermes exposes conversations to MCP clients
- **Fallback Provider Chains:** Automatic failover between inference providers
- **Docker Container:** Containerized Hermes for isolated execution
- **Telegram/Slack/WeCom Adapters:** Communication channel integrations
- **Exa Search Backend:** Alternative to Tavily
- **Action:** `git submodule update` hermes-agent, audit new features, wire into Swift bridge

### 1B. Multi-Instance Agent Profiles
- Spawn N isolated Hermes instances (research, content, BD, coding)
- Each has own config, memory, sessions, skills, rate limits
- UI: Agent tabs in sidebar (like Notes window tabs), start/stop per profile
- Wire to `HermesSubprocessManager` — needs multi-process support
- **Profile JSON schema:** name, model, skills, tools, memory_dir, personality

### 1C. Fallback Provider Chains
- Configure primary → secondary → tertiary inference providers
- Auto-failover with cooldown (e.g., Anthropic → OpenRouter → OpenAI)
- Wire into `HermesRuntimeRoute` resolution
- **File:** `Epistemos/Agent/HermesSubprocessManager.swift`

### 1D. Fix "Dumb Chatbot" UX Gap
The app doesn't FEEL like Hermes Agent or OpenClaw because:
- Tool results don't stream visually (user sees "thinking..." not the tool executing)
- No live agent panel showing tool calls, results, thinking in real-time
- No sub-agent delegation visible in UI
- Agent window should look like Xcode's debug console — live, informative, scrolling
- **Action:** Restyle AgentSessionPanel to show: tool call → result → thinking → next action in real-time

### 1E. Skills System Swift Integration
- Hermes has skills but Swift has no scanner for `~/.epistemos/skills/`
- Need: hot-reload watcher, skill discovery UI in sidebar, skill trigger matching
- Bundle default skills (summarize-paper, daily-review, code-review, web-research)
- **Per IMPLEMENTATION_PROMPTS §4**

### 1F. iMessage Integration
- Read: ~/Library/Messages/chat.db (SQLite, requires Full Disk Access)
- Send: AppleScript → Messages.app
- Alt: BlueBubbles REST API (localhost)
- Agent tools: imessage_read, imessage_send
- **Per IMPLEMENTATION_PROMPTS §5**

---

## TIER 2: CODING FEATURES (Xcode-inspired)

### 2A. Code Streaming to Notes
- When user chats or agent generates code, stream it to a note in real-time
- Toggle per chat/agent: "Stream responses to notes"
- Can target: new note, existing note, agent vault, code section
- Code section in notes sidebar with syntax highlighting

### 2B. Code Section in Notes Sidebar
- Notes sidebar becomes a "Knowledge Hub" with sections:
  - My Notes
  - Recent Chats
  - Agent Vaults (per-model knowledge profiles)
  - Code (syntax-highlighted, searchable, auto-organized by language)
- Code auto-extracted from chat/agent responses
- Tap code section → transforms current window to code view

### 2C. Ask Bar in Code Section
- Same capabilities as main chat Ask Bar
- Recent chats, context from code files, Xcode-style command palette
- Can ask questions about code, get inline explanations
- **Inspiration:** Xcode's Quick Help + Copilot Chat

### 2D. Study OpenClaw's Coding Patterns
- OpenClaw uses a VLM-driven coding loop with screen awareness
- Port patterns: file tree navigation, diff generation, test execution
- Adapt for local files, not just web-based repos

---

## TIER 3: GRAPH ENHANCEMENTS

### 3A. Black & White Graph Theme
- Folders: black (dark mode: white), shade lightens with nesting depth
- Notes: keep current color scheme
- Chats: yellow (or configurable)
- Nodes still glow — white/black glow effect

### 3B. Living Graph Animation
- Nodes drift slowly when idle — makes graph feel alive
- Subtle, continuous, non-distracting movement
- Configurable: Settings toggle for "Living Graph"

### 3C. Nested Perspective Layers
- Select a folder → zooms into that folder's subgraph
- Nested folders appear as layered depth planes (perspective)
- Moving "into" nested layers feels cinematic — real depth, not parallax
- Each depth level is a visual layer in the hologram overlay
- Setting: "Immersive Graph" toggle for enhanced depth effect

### 3D. Dead Code Cleanup in Graph
- Remove unused graph code from the "living system" era
- Audit graph-engine for dead code paths
- Focus Metal rendering on production quality

---

## TIER 4: SIDEBAR OVERHAUL

### 4A. Unified Notes Sidebar + Mini Chat
- Notes sidebar becomes the primary knowledge surface
- Contains: Notes, Recent Chats, Agent Vaults, Code, Coworker Agent
- Toggle between sidebar and mini chat (or show both)
- Mini chat appears as a section/tab within sidebar

### 4B. Coworker Agent (Sidebar Intern)
- Sidebar turns into an agent that works on local files
- Routes through agent runtime OR operates independently
- Can: organize notes, suggest edits, find related content, draft responses
- Background mode: works while you do other things

### 4C. Agent Vault Directories
- Per-model knowledge profiles visible in sidebar
- User can browse, edit, rebuild (per CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md)
- Shows: concept index, active context, instructions, knowledge profile

---

## TIER 5: MULTI-AGENT SYSTEM (OpenClaw-level)

### 5A. Sub-Agent Architecture
- Main agent spawns sub-agents for parallel tasks
- Sub-agents communicate with each other
- Concurrent process execution (not sequential)
- Context scoping: each sub-agent sees only relevant context
- **Pattern:** OpenClaw's agent delegation + NemoClaw's parallel execution

### 5B. Agent Personas
- Each agent has a personality JSON + system prompt + limits
- Can have email, social media accounts (for automation)
- Profile: name, model, tools, personality, communication style, boundaries
- Max 4 agent profiles active + 1 user profile

### 5C. Agent Self-Development
- An agent can be given an entire vault + app instance
- It asks AI questions, takes notes, does auto-research
- Creates its own models, agents, trains them
- Separate instance of the app that self-develops based on profile
- **This is the autonomous research pipeline vision**

### 5D. Wake-Up Summary
- Agent works overnight (NightBrain + background tasks)
- On wake: desktop shows summary of completed work
- "While you slept, I researched X, organized Y, drafted Z"
- OpenClaw-level: continuous operation across sleep/wake cycles

---

## TIER 6: COMMUNICATION CHANNELS

### 6A. iMessage Agent (Tier 1F)
- Text Epistemos to do work, fetch stuff, get summaries
- Bidirectional: read messages + send responses

### 6B. Telegram Webhook (from Hermes v0.6.0)
- Wire Hermes's new Telegram adapter
- Agent responds to Telegram messages

### 6C. Agent Email
- Give agent its own email account
- Auto-responds, fetches info, files emails as notes

---

## TIER 7: OPTIMIZATION & HARDENING

### 7A. Stream Composition Pipeline
- Compose existing safety components into a clean chain:
  - Raw SSE → Thinking Extraction → Cost Accumulation → Credential Redaction → UI Rendering
- Currently called separately at ad-hoc points

### 7B. Auth Profile Rotation
- Multi-key failover with cooldown
- Primary → secondary → tertiary API keys
- Automatic rotation on rate limit or error

### 7C. ContextBudgetManager in Omega
- Wired in Hermes flow but NOT in Omega orchestrator
- Add budget tracking to OrchestratorState

### 7D. Phase 8: macOS Isolation
- Sandbox-exec profiles for candidate evaluation
- Volatile project roots, env scrubbing, network restriction

### 7E. Zero-Copy & Performance
- Audit all FFI boundaries for unnecessary copies
- Metal StorageModeShared everywhere possible
- Profile with Instruments before optimizing
- Crossbeam-epoch for lock-free reads on hot paths

---

## TIER 8: BUSINESS FEATURES

### 8A. Company Training Pipeline
- Fine-tune local 3-tier models for companies
- Specific purposes: customer support, internal tools, domain expertise
- Niche: training local models on-device for enterprise clients

### 8B. Tyler/Local Business Outreach
- Research companies in Tyler area
- Pitch AI automation, app development, model training
- Create portfolio from Epistemos capabilities

---

## TIER 8B: LIVING VAULT (from LIVING_VAULT_ARCHITECTURE.md — Sprint Omega-5)

The vault becomes a living cognitive substrate. Every memory change is a diff, not an overwrite.

### 8B-1. Diff Engine (Rust)
- `agent_core/src/storage/diff_engine.rs` — unified diff via `similar` crate
- Text diff + JSON tree diff + fuzzy patch application
- **Sprint task:** Omega-5 Task 1

### 8B-2. Memory Classifier (Rust)
- `agent_core/src/storage/memory_classifier.rs` — ADD/UPDATE/DELETE/NOOP
- Embedding similarity (cosine > 0.85) + lightweight LLM classification
- **Sprint task:** Omega-5 Task 2

### 8B-3. Ebbinghaus Decay (Rust)
- `agent_core/src/storage/memory_decay.rs` — strength decay + GC sweep
- `strength(t) = strength(t₀) × e^(-λ × (t - t₀))`
- Pin/boost/manual delete. Graph shows strength as node opacity.

### 8B-4. Cross-File Propagation
- When one vault file is patched, scanner checks all references
- All patches land as one atomic git commit — no belief drift between files
- Uses tantivy full-text search to find references

### 8B-5. Git as Cognitive Journal
- Every vault mutation is a git commit with structured message
- `git log` IS the agent's intellectual history
- `git revert` undoes a bad memory

### 8B-6. Context Compiler (Rust)
- `agent_core/src/context_compiler.rs` — prompt DAG assembly
- Cache-optimal ordering (U-curve aware): tools → system → skills → memory → few-shot → RAG → history → user message
- Multi-level compression (lossless → near-lossless → LLMLingua → aggressive)
- Self-improving optimization loop (DSPy/OPRO/EvoPrompt style)

### 8B-7. Multi-Vault Registry
- Per-model vaults, per-agent vaults, per-user vault
- Vault switching in UI changes what context compiler draws from
- Merges with priority: agent > model > personal

### 8B-8. Agent Graph Visualizer
- 5 zoom levels (cosmic → constellation → solar system → planet → surface)
- Live state: pulsing active agents, flashing tool edges, token flow particles
- Phase 1: Grape, Phase 2: Metal instanced, Phase 3: full Metal compute

---

## TIER 9: CODE EDITOR & IDE FEATURES (from Architecture Discovery Report)

### 9A. Custom CoreText Code Editor Surface
- Reject TextKit 2 for code — viewport estimation breaks scroll positioning
- Custom NSView + CTTypesetter + CTFrame for code rendering
- Hardware-accelerated glyph rendering, sub-16ms typing latency
- Line numbers, gutters, minimap in same draw pass
- **Reference:** Nova, CodeEdit both abandoned NSTextView for this approach

### 9B. Rust Rope Text Storage
- Replace String-based text storage with Sum-Tree/Rope in Rust
- O(log N) for all operations (insert, delete, search)
- Immutable snapshots for concurrent background parsing
- Zero-copy cursor for Tree-sitter integration
- **Reference:** Zed, Helix use this pattern

### 9C. Tree-sitter Incremental Parsing
- Embed Tree-sitter in Rust core for Swift, Rust, Python, Markdown, Web
- Incremental AST updates in <2ms per keystroke
- Syntax tokens returned as flat C-array via FFI: `[start_byte, end_byte, token_id]`
- **Already partially exists** in epistemos-core — needs wiring to code editor surface

### 9D. LSP Supervisor in Rust
- sourcekit-lsp (Swift), rust-analyzer (Rust), pyright (Python), typescript-language-server (Web)
- Rust tokio::process supervision — crash detection, auto-restart, graceful degradation
- Features: diagnostics, hover, go-to-definition, find references, formatting
- Merge LSP semantic tokens with Tree-sitter syntax tokens (semantic takes priority)

### 9E. BoltFFI for Hot Paths
- UniFFI for coarse-grained events (file open, config change)
- BoltFFI or manual C FFI for 120fps hot paths (keystrokes, cursor, syntax tokens)
- Zero-copy via Apple Silicon UMA — Swift reads Rust memory addresses directly
- **Benchmark target:** <16ms keystroke-to-frame, <2ms AST update

### 9F. AI-Native Code Context
- Tree-sitter semantic excerpt generation — don't send entire files to LLM
- Ascend syntax tree to extract function + enclosing class + dependencies
- Workspace-aware RAG: sqlite-vec retrieves code chunks + notes, cross-referenced with LSP symbols
- Merkle-tree hashing for incremental re-indexing (only embed diffs)

---

## TIER 10: CONTROL PLANE ARCHITECTURE (from Deep Research Report)

### 10A. Harness as GUI Control Plane
The app must become the **GUI control plane** for the agent runtime, not "another chat client."
- Expose all Hermes/OpenClaw primitives as first-class UI objects:
  - Profiles/Agents: picker, creation, import/export, isolated workspaces
  - Sessions: list, search, compaction status, new/reset
  - Skills: install/manage, "skill used" traces, availability per session
  - Tools & Approvals: execution stream, approval UI, hardening signals
  - Schedulers: cron timeline, next-run times, run logs, outputs
  - Provider Routing: active provider, fallback chain, failover events
  - Gateways/Channels: connect/disconnect, pairing, webhook toggles

### 10B. MCP as the Spine
- Hermes (server) ⇄ Harness (client) via MCP
- Harness runs its own MCP servers: vault filesystem, graph, notes, code artifacts
- Agent runtime accesses UI-managed resources through MCP protocol
- Avoids bespoke API that duplicates ecosystem convergence

### 10C. Automated Install + Doctor + Update
- First-run bootstrap: embedded runtime + dependency install
- "Doctor" command: runtime health, dependency presence, credential sanity, tool-sandbox check
- "Update" flow: pull latest + reinstall (like Hermes's `hermes update`)
- Sandbox choices (local vs Docker) visible and selectable in UI

### 10D. Paperclip "Company OS" Mode
- Optional mode inside Harness for managing:
  - Org charts, budgets, governance, heartbeats, role/persona configs, audit logs
- "If OpenClaw is an employee, Paperclip is the company"
- Treat as a plugin/mode, not core — MIT licensed, attribution required

---

## TIER 11: ZERO-COPY & PERFORMANCE ENGINEERING (from Typestate Report)

### 11A. Noncopyable FFI Handles
- Wrap all UniFFI handles in Swift 6 `~Copyable` structs
- `deinit` calls Rust release function — RAII pattern, zero leaks
- `consuming func` for state transitions — compile-time enforcement
- **Already deferred to Phase 13** — but should be reconsidered for critical paths

### 11B. Typestate for Critical Protocols
- MLX pipeline: `Uninitialized` → `Ready` → `InferenceInProgress` (noncopyable)
- PTY handle: `Opened` → `Closed` (Rust PhantomData)
- FoundationModels session: `Active` → `Recycling` → `Closed`
- **Already deferred to Phase 11** — assess after Phases 1-9 stable

### 11C. Capability-State Tokens
- `ComputeCapability` token required for inference
- Low-power state → only issues `QuantizedInferenceCapability`
- Prevents operations that would fail or drain battery
- Wire into PowerGuard mode transitions

### 11D. Zero-Copy IPC Patterns
- Apache Arrow for shared-memory interchange (columnar, relocatable)
- FlatBuffers for zero-parse structured messages
- Append-only mmap logs for transcripts, tool traces, graph events
- UI reads via offsets/slices — only materialize for display

### 11E. Lock-Free Circuit Breaker on Apple Silicon
- AtomicU64 bit-packed ring with popcount health check
- `#[repr(align(128))]` for 128-byte L1 cache lines
- ManagedBuffer for co-located header + element storage
- **Already deferred to Phase 12** — implement when profiling justifies

### 11F. Performance Benchmark Targets
| Metric | Target |
|--------|--------|
| Typing latency (keyDown → frame swap) | <16ms |
| File open (100K lines) | <150ms |
| Idle memory (workspace open) | <150MB |
| AST update (single char) | <2ms |
| Tantivy search (10K files) | <10ms |
| LSP crash recovery | <3s |

---

## RESEARCH ITEMS (Need Investigation Before Building)

| ID | Topic | Blocker For |
|----|-------|-------------|
| R2 | CoreML ANE dual-brain path | Tier 5 sub-agents |
| R3 | Dual-model memory budget | Tier 5 concurrent agents |
| R10 | Cartesia Metal kernels for Mamba-2 | Custom model training |
| R14 | LoRA on Mamba-2 via MLX | Knowledge Fusion |
| R17 | SMAppService App Store distribution | Mac App Store version |
| NEW | OpenClaw VLM agent loop analysis | Tier 2 coding, Tier 5 sub-agents |
| NEW | Hermes v0.6.0 profiles architecture | Tier 1 multi-instance |
| NEW | Docker-in-app feasibility | Tier 5 isolation |
| NEW | BoltFFI vs UniFFI hot-path benchmarks | Tier 9 code editor |
| NEW | CoreText custom NSView patterns (Nova, CodeEdit) | Tier 9 code editor |
| NEW | Rope data structure evaluation (ropey vs custom) | Tier 9 text storage |
| NEW | Apache Arrow / FlatBuffers for zero-copy IPC | Tier 11 performance |
| NEW | Paperclip integration architecture | Tier 10 company OS mode |
| NEW | OpenCode coding patterns analysis | Tier 2 coding features |

---

## EXECUTION ORDER (Recommended)

```
PHASE A — STABILITY FIXES (This week):
  0B ResearchPause fix
  0C EmbeddingService hang
  (0A Notarization + Sparkle DEFERRED — do after app is feature-complete)

PHASE B — AGENT PARITY (Make it feel like Hermes/OpenClaw):
  1A Merge Hermes v0.6.0
  10A Build control plane UI (profiles, sessions, tools, cron, providers)
  1D Restyle agent window (Xcode-inspired live execution view)
  10C Automated install + doctor + update flow
  1B Multi-instance agent profiles
  1C Fallback provider chains
  1E Skills system Swift integration

PHASE C — KNOWLEDGE HUB (Sidebar overhaul + code):
  4A Unified notes sidebar (notes + chats + vaults + code + coworker)
  2A Code streaming to notes
  2B Code section in sidebar
  2C Ask bar in code section
  4B Coworker agent in sidebar

PHASE D — GRAPH CINEMA:
  3A Black & white theme with glow
  3B Living graph animation (slow drift)
  3C Nested perspective layers (cinematic depth)

PHASE E — CODE EDITOR (V2 — after core is stable):
  9A Custom CoreText code surface
  9B Rust Rope text storage
  9C Tree-sitter incremental parsing
  9D LSP supervisor in Rust
  9E BoltFFI for hot paths
  9F AI-native code context

PHASE F — MULTI-AGENT & COMMUNICATION:
  5A Sub-agent architecture
  5B Agent personas (JSON profiles)
  5C Agent self-development (autonomous research pipeline)
  5D Wake-up summary
  6A iMessage integration
  6B Telegram webhook
  6C Agent email
  10D Paperclip "company OS" mode

PHASE G — PERFORMANCE HARDENING:
  7A Stream composition pipeline
  7B Auth profile rotation
  10B MCP as spine (standardize on MCP for all IPC)
  11A-F Zero-copy, typestate, capability tokens
  Phases 10-13 from MASTER_HARDENING_AND_HARNESS_PLAN

PHASE H — RELEASE PREP (After features are complete):
  0A Notarization + Sparkle auto-update
  Release preflight, DMG packaging, legal docs
  Fresh-machine verification

DEFERRED (Research-blocked):
  8A-8B Business features
  MOHAWK custom model training (RunPod funding + R10/R14 research)
  Mamba Metal kernels (Cartesia Edge or MLX Mamba support)
  CoreML ANE dual-brain (R2/R3 research)
```
