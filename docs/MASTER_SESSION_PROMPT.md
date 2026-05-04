# Epistemos Master Session Prompt

> **Index status**: SUPERSEDED-HISTORICAL — older 2026-03-30 session-bootstrap prompt. Current canonical session bootstrap is [`docs/MASTER_BUILD_PLAN.md §9`](MASTER_BUILD_PLAN.md) (operational pre-flight reads) plus [`docs/plan/prompts/full_session_orchestrator.md`](plan/prompts/full_session_orchestrator.md) (single-session orchestrator). User auto-memory at `project_master_session` may still reference this file; the user is consolidating and will update memory. Classified in [`docs/_INDEX.md §9`](_INDEX.md).

**Last Updated:** 2026-03-30 (late session — 15 items completed, Gemini analysis integrated)
**Use this prompt to start EVERY new Claude Code session on Epistemos.**

---

## The Prompt

Copy this exactly into a new session:

```
Read these files in this exact order. They are your complete context for Epistemos development.

1. CLAUDE.md — project rules, non-negotiable constraints, file map
2. docs/MASTER_SESSION_PROMPT.md — full state summary, distribution decision, MAS compliance, research insights, architecture map
3. docs/AGENT_INTEGRATION_SESSION_PLAN.md — work plan with 19 items across 7 phases, priority tiers, verification checklists

Then execute remaining items from the "Do First" tier downward. After each tier:
- Run: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep "error:"
- Run: cargo test --manifest-path agent_core/Cargo.toml (if Rust files changed)

After ALL items are done, run the full post-implementation audit checklist at the bottom of AGENT_INTEGRATION_SESSION_PLAN.md.

For release preparation specifically, also read:
- docs/handoffs/2026-03-28-final-claude-release-master-handoff.md
- docs/handoffs/2026-03-28-jojo-manual-release-checklist.md
- docs/handoffs/2026-03-28-codex-claude-release-preservation-prompt.md
```

---

## Current State Summary (2026-03-30)

### What's Built and Working (DO NOT REBUILD)

**MCP Bridge (fully wired):**
- `EpistemosMCPServer` with vault_search, vault_read, vault_list, skill_discover, skill_schema
- `HermesMCPClient` for Swift→Hermes bidirectional calls
- `routeBridgeLine()` dispatcher (JSON-RPC → MCP server/client, events → handler)
- Auto-refresh admin state on bridge `"ready"` event
- Cron keepalive (60s tick)
- TranscriptRepair wired into `parseSessionHistory()`
- ContextBudgetManager tracking tokens on "complete", auto-compact at 70%

**OpenClaw Safety (6 files in `Epistemos/Omega/Safety/`):**
- ToolLoopDetector — 4 loop types, SHA-256 hashing, wired into OrchestratorState
- ContextBudgetManager — token tracking, adaptive thinking budgets
- TranscriptRepair — orphan/dedup/merge repair
- ExecutionCheckpointManager — atomic JSON persistence, wired into OrchestratorState
- AgentDepthLimiter — subagent recursion cap at depth 3
- MMRReranker — Jaccard + MMR (lambda=0.7), wired into AgentGraphMemory.recall()

**FFI Hardening:**
- NaN/Inf sanitization in graph-engine add_node/add_nodes_batch/add_edge
- catch_unwind complete (60+ call sites)

**Already Production-Grade (verified, no work needed):**
- Paste sanitization + IME guard (ProseTextView2.swift)
- Undo grouping for AI streaming chunks (ProseEditorRepresentable2.swift)
- Divider stripping on note load (ProseEditorRepresentable2.swift)
- Security-scoped bookmark timeout (VaultSyncService.swift — resolveVaultBookmarkWithTimeout)
- NoteFileStorage atomic writes (temp → F_FULLFSYNC → POSIX rename → F_FULLFSYNC parent)
- Deploy gate runs real eval_bfcl.py (TrainingScheduler.swift)
- Target PID resolution via NSWorkspace (OrchestratorState.swift)

### What Was Built (March 30 Late Session — Items 1-15 COMPLETE)

All 15 items from the Do First through Do Third tiers are now implemented and building clean.

**New files created (11 total):**
- `Epistemos/Omega/Safety/CredentialRedactor.swift` — 9-pattern API key/token redaction
- `Epistemos/Omega/Safety/CostTracker.swift` — micro-dollar cost tracking, March 2026 pricing
- `Epistemos/Omega/Safety/ContextCompiler.swift` — U-curve "Lost in the Middle" reordering
- `Epistemos/Omega/Safety/MemoryThreatScanner.swift` — prompt injection + exfiltration + invisible unicode detection
- `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` — file-level git snapshots before agent mutations
- `Epistemos/Views/Omega/SkillStoreView.swift` — category-filtered skill browsing UI
- `Epistemos/Views/Notes/HexViewerView.swift` — corruption recovery with Rust FFI hex dump
- `graph-engine/src/recovery.rs` — encoding detection/repair (Latin-1, BOM, null bytes)
- UniFFI exports in `agent_core/src/bridge.rs` — `classify_vault_memory`, `decay_memory_nodes`, `gc_memory_nodes`
- HTTP transport in `Epistemos/Agent/EpistemosMCPServer.swift` — NWListener for >50KB payloads
- Recovery C header declarations in `graph-engine-bridge/graph_engine.h`

**Key wiring changes:**
- AgentViewModel: LoopDetector, DepthLimiter, CostTracker, ShadowCheckpoint properties + vault tool threat scanning + credential redaction + U-curve ordering
- EpistemosApp: `applicationShouldTerminateAfterLastWindowClosed` for NightBrain menu bar mode
- EpistemosConfig: `nightBrainMenuBarAgent` setting
- QLoRATrainer: prefers composed `train_final.jsonl` over raw shards

**Test results:** Swift zero errors, agent_core 70/70, graph-engine 2448/2448 (+7 new)

### What's NOT Built (remaining work)

See `docs/AGENT_INTEGRATION_SESSION_PLAN.md` for details.

**Priority tiers:**
1. **Do Next** (Items 20,21): NightBrain Heartbeat Memory Distillation, Sub-Agent Context Scoping (from Gemini analysis)
2. **Do Fourth** (Items 16-19): Release preflight, DMG packaging, legal docs, fresh-machine test
3. **Do Later** (Items 10,11): Tokio WebSocket Gateway, Docker Sandbox

### Gemini Deep Analysis (evaluated 2026-03-30)

A comparative analysis of OpenClaw and Hermes Agent architectures produced 6 proposals. **2 accepted**, 4 rejected:

| Accepted | Why |
|---|---|
| **Heartbeat Memory Distillation** (Item 20) | NightBrain should use idle time to run Rust Living Vault FFI (decay, GC, classify) on memory nodes — prevents latency spikes from reactive compaction |
| **Sub-Agent Context Scoping** (Item 21) | Delegate tools should pass narrow, role-specific context files to sub-agents instead of full master prompt — saves tokens, prevents drift |

| Rejected | Why |
|---|---|
| A2UI Protocol | Epistemos already renders natively in SwiftUI — no browser client exists |
| PyO3 FFI Bridge | Architecture is Swift→Rust via UniFFI, not Python→Rust — essay written for wrong direction |
| Zero-Trust WebSocket | Local macOS app — stdio pipes, not exposed network ports |
| Docker Network Proxy | Docker Sandbox (Item 11) is deferred — building proxy for nonexistent executor is premature |

---

## Distribution Decision

**Method:** Direct distribution via Developer ID-signed DMG (NOT Mac App Store).

**Why MAS is blocked:** 6 hardened runtime exceptions required:
1. `com.apple.security.cs.allow-jit` — MLX/Metal shader compilation
2. `com.apple.security.cs.allow-unsigned-executable-memory` — MLX weight loading
3. `com.apple.security.cs.disable-library-validation` — Rust FFI dylibs
4. `com.apple.developer.accessibility` — AX tree access for computer use
5. Apple Events automation — cross-app orchestration
6. Terminal command execution — agent bash tool

**Entitlements file:** Already populated. Ready for codesign + notarization.

**What's release-ready:**
- Entitlements file populated and correct
- Privacy manifest (PrivacyInfo.xcprivacy) complete
- Rust dylibs embed as universal binaries (arm64 + x86_64)
- NoteFileStorage uses hardened atomic writes + integrity sidecars
- Release preflight script exists (`scripts/audit/release_preflight.sh`)
- Codesign verification passes on fresh Debug builds
- All required runtime assets bundled

**Release blockers (legal/infra — Items 16-19 in session plan):**
- Privacy policy (needs hosting URL)
- Terms of service document
- Open-source license attribution page (GRDB MIT, MLX MIT, HuggingFace Apache 2.0, AXorcist MIT, tantivy MIT, sqlite-vec MIT, Hermes-Agent MIT)
- DMG packaging + notarization script
- Developer ID Application certificate setup
- Fresh-machine verification (manual)
- Sparkle update feed URL (optional for v1)

---

## Mac App Store Compliance (If MAS is Attempted Later)

If MAS distribution is ever revisited, these architectural changes are required:

### Mandatory Consent Architecture (Guideline 5.1.2(i))
- **First-Use Consent Dialogs** per agentic action (NOT blanket "I Agree")
- Explicit disclosure of API endpoint + provider name (e.g., "Anthropic API - US-East")
- AI-generated content must be visually distinct from user content (watermarks/indicators)
- Persistent **Privacy Dashboard** for reviewing and revoking AI integrations
- Consent revocation must not require deleting the app

### Local-First PII Scrubbing Engine
- ANE-powered NER pass before any cloud API call
- Token substitution for detected PII (names, financial data, internal terms)
- Rehydration on response return (all within local sandbox)
- Satisfies both Apple 5.1.2(i) and Texas TDPSA data minimization

### Sandbox Architecture
- **XPC Service** for heavy agent logic (crash-isolated from UI process)
- **DAS-CTS scheduling** for background tasks (not continuous loops)
- **Lifecycle Persistence** — save state on expiration signal, resume on next window
- All file I/O through Security-Scoped Bookmarks (already implemented)
- Balance `startAccessingSecurityScopedResource()`/`stop` calls (already implemented)

### AppIntents Integration
- Map agent actions to native AppIntents instead of raw AX/CGEvent where possible
- Implement AppEntity + NSUserActivity for on-screen context awareness
- Prefer semantic control (XPC to intent handler) over pixel-level automation

### Texas Regulatory Compliance (TDPSA/TASAA/TRAIGA)
- **TDPSA:** Zero-retention for non-essential PII (scrubbing engine handles this)
- **TASAA:** Volatile memory-only age verification via App Store API signals
- **TRAIGA:** Immutable system guardrails in agent prompt + post-generation output filter

### Required Entitlements for MAS
| Entitlement | Purpose | Review Notes Required |
|---|---|---|
| `com.apple.security.cs.allow-jit` | Local MLX inference | "JIT isolated to ML engine, shielded from network input" |
| `com.apple.security.files.user-selected.read-write` | Vault access | "User selects vault via NSOpenPanel, Security-Scoped Bookmarks" |
| `com.apple.developer.accessibility` | AX tree for computer use | "AXIsProcessTrustedWithOptions with graceful fallback" |

---

## Key Research Insights (from 150+ docs scan)

### Training Pipeline Status
- **3,772 SFT examples** exist but data mix is catastrophically imbalanced (68% symbol_qa)
- **Zero successful adapter training runs** — 6 adapter dirs have config but no weights
- **Missing:** AST code graph, live AX capture pipeline, evaluation holdouts, IFD filtering, CAMPUS sorting
- **Timeline to first real training run:** ~3-4 weeks
- **Decision:** Ship v1 with chat-only adapters. Training pipeline is post-launch.

### Hermes Parity Status
- **90%+ parity achieved** — agent loop, streaming, sessions, memory, approvals, cron, MCP, tools
- **Missing:** Local HTTP endpoint for agent-capable local models, smart model routing, trajectory export, `hermes doctor`
- **Hermes has built-in API server** at `gateway/platforms/api_server.py` (localhost:8642)

### Instant Recall Architecture
- Binary-quantized HNSW: 1M notes in 128MB, <3ms retrieval
- Two-phase: binary HNSW → top-100 (0.5ms) → float32 rescore → top-5 (2ms)
- Phase 2: Mamba-2 state injection (~50ms prefill for context-aware writing)
- Phase 4: TurboQuant (3.5 bits/channel, 4.5x compression)

### Research SOAR Migration
- 7 new tools needed (readpagecontent, searchpapers, collectsnippet, savecitation, createresearchnote, analyzecontradiction, scoreevidence)
- Enters exclusively through Omega panel, NOT standard chat
- Evidence scoring is deterministic (URL→tier, no LLM needed)
- 3 stateless structs: ResearchComplexityGate, ResearchEvidenceScorer, ResearchConfidenceState

### Living Vault
- 4-op classifier (ADD/UPDATE/DELETE/NOOP) in Rust
- Ebbinghaus decay: `strength(t) = strength(t₀) × e^(-λ × (t - t₀))`, GC at strength < 0.15
- Git-as-journal: every mutation is a structured commit
- Rust modules exist in `agent_core/src/storage/` — need audit + Swift wiring

---

## Architecture Map

```
Epistemos.app (Swift 6 + Rust/UniFFI + Metal)
│
├── AgentViewModel.swift           ← Central orchestration
│   ├── EpistemosMCPServer         ← vault tools + skill discovery (MMR) + HTTP transport
│   ├── HermesMCPClient            ← Swift→Hermes calls
│   ├── ContextBudgetManager       ← token tracking, auto-compact
│   ├── CostTracker                ← micro-dollar API cost tracking
│   ├── ToolLoopDetector           ← Hermes bridge loop detection
│   ├── AgentDepthLimiter          ← Hermes bridge depth limiting
│   ├── ShadowGitCheckpoint        ← file snapshots before mutations
│   ├── TranscriptRepair           ← orphan/dedup/merge
│   └── routeBridgeLine()          ← JSON-RPC dispatch + threat scan + credential redact + U-curve
│
├── OrchestratorState.swift        ← Omega DAG execution
│   ├── ToolLoopDetector           ← SHA-256, 4 loop types
│   ├── ExecutionCheckpointManager ← atomic crash recovery
│   └── AgentDepthLimiter          ← recursion cap
│
├── Omega/Safety/                  ← 11 safety components
│   ├── CredentialRedactor         ← 9-pattern API key masking
│   ├── MemoryThreatScanner        ← prompt injection + exfiltration detection
│   ├── ContextCompiler            ← U-curve "Lost in the Middle" reordering
│   ├── CostTracker                ← micro-dollar precision, per-model pricing
│   └── ShadowGitCheckpoint        ← GIT_DIR/GIT_WORK_TREE shadow repos
├── AgentGraphMemory.swift         ← recall() with MMR reranking
│
├── graph-engine/src/lib.rs        ← NaN sanitization, catch_unwind
├── agent_core/src/storage/        ← Living Vault (diff, git, classifier, decay)
│
├── hermes-agent/                  ← Python subprocess (managed)
│   ├── epistemos_bridge.py        ← stdio JSON bridge
│   ├── run_agent.py               ← AIAgent core loop
│   └── cron/scheduler.py          ← background scheduler
│
└── KnowledgeFusion/               ← Training pipeline
    ├── Training/QLoRATrainer.swift
    └── Alignment/TrainingScheduler.swift (deploy gate)
```

## Source Documents Index

| Document | Path | Topic |
|---|---|---|
| Project Rules | `CLAUDE.md` | Non-negotiable constraints |
| Work Plan (15 items) | `docs/AGENT_INTEGRATION_SESSION_PLAN.md` | Remaining work with priority order |
| Gemini Fusion Analysis | `~/.gemini/antigravity/brain/c766d684.../agent_fusion_analysis.md` | OpenClaw gateway, Living Vault, compaction |
| Gemini Implementation Plan | `~/.gemini/antigravity/brain/c766d684.../implementation_plan.md` | 3-phase execution |
| OpenClaw ACP Protocol | `jojo/openclaw-main/docs.acp.md` | Agent Client Protocol spec |
| Living Vault Architecture | `jojo/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md` | 4-op classifier, decay, git |
| Living Vault Sprint | `docs/sprint-sessions/sprint-omega-5-living-vault.md` | Sprint spec |
| Hermes Integration Research | `docs/HERMES_INTEGRATION_RESEARCH.md` | 40-file study, feature roadmap |
| Hermes Parity Report | `docs/HERMES_PARITY_REPORT.md` | What's done vs missing |
| Instant Recall | `docs/INSTANT_RECALL_ARCHITECTURE.md` | Binary HNSW, Mamba-2 |
| Research SOAR Migration | `docs/plans/2026-03-27-omega-research-soar-migration-plan.md` | 7 tools, 3 structs |
| Pretraining Gap Report | `docs/plans/2026-03-27-pretraining-readiness-gap-report.md` | Training pipeline gaps |
| Distribution Decision | `docs/plans/2026-03-28-distribution-decision-and-compliance-report.md` | DMG, entitlements, legal |
| Deep Verification Manual | `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` | 3-pass audit protocol |
| OpenClaw Feature Spec | `docs/OPENCLAW_FEATURE_SPEC.md` | Safety ports spec |
| Agent Architecture | `docs/agent-system/AGENT_ARCHITECTURE.md` | Background reference |
| Knowledge Fusion | `docs/knowledge-fusion/README.md` | QLoRA, KTO, adapters |
| Release Master Handoff | `docs/handoffs/2026-03-28-final-claude-release-master-handoff.md` | What landed, bundle verification, release verdict |
| Manual Release Checklist | `docs/handoffs/2026-03-28-jojo-manual-release-checklist.md` | Fresh-machine test, DMG packaging, signing |
| Release Preservation Prompt | `docs/handoffs/2026-03-28-codex-claude-release-preservation-prompt.md` | Repeatable release-preservation workflow |
| Distribution Decision | `docs/plans/2026-03-28-distribution-decision-and-compliance-report.md` | DMG vs MAS, entitlements, legal requirements |
| Gemini Architecture Upgrade | `~/.gemini/antigravity/brain/0d3792b7-.../epistemos_architecture_upgrade.md.resolved` | OpenClaw/Hermes deep comparison — 2 accepted, 4 rejected |
| Master Build Spec | Referenced in attachments | Complete 8-phase build specification |
| Agent Architecture v1 + v1.1 | Referenced in attachments | Provider matrix, tool arsenal, computer use pipeline |
