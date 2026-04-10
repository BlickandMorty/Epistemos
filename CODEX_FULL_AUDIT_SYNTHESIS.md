# Epistemos Full Codebase Audit Synthesis — For Codex Review

**Date:** 2026-04-08
**Scope:** Last ~30 commits (Kimi + Claude sessions) plus all uncommitted work
**Codebase:** 137K LOC Swift, 94K LOC Rust, 370 Swift files, 99 Rust files
**Build status:** Swift compiles (only pre-existing TraceCollector.swift error). Rust epistemos-core: 5/5 tests pass. agent_core: compiles.

---

## TABLE OF CONTENTS

1. [Commit History Summary](#1-commit-history)
2. [Uncommitted Work](#2-uncommitted-work)
3. [Subsystem-by-Subsystem Audit](#3-subsystem-audit)
4. [Architecture Diagram](#4-architecture)
5. [What Works vs What's Stubbed](#5-works-vs-stubbed)
6. [Known Issues & Technical Debt](#6-issues)
7. [Audit Checklist for Codex](#7-checklist)

---

## 1. COMMIT HISTORY (Last 30 Commits)

### Phase: Rust Agent Core Migration (Goose Parity)

| Commit | Summary |
|--------|---------|
| `d6ff9fea` | Phase 2: Gemini provider added to Rust agent_core (4th cloud provider) |
| `7dd83ee8` | Phase 3a: Memory tool ported from Hermes v0.7.0 to Rust |
| `86b61d4e` | Phase 3b: Skills tool ported from Hermes v0.7.0 to Rust |
| `21e23230` | Goose parity: general-purpose file operations tool |
| `a464a5f5` | Phase 3c: Wire approval flow — StreamingDelegate captured for permission resolution |
| `b85872a8` | Phase 4: Web fetch + computer use tools (19 total Rust tools) |
| `89499631` | Phase 5: Agent UI state — tool tracking, turn counter, context events |
| `c7efdabb` | Phase 6: Hermes subprocess now optional — main chat uses Rust agent_core |

**Audit focus:** Verify all 11 tools in registry actually execute. Verify 5 providers connect. Verify compaction doesn't drop thinking blocks. Verify permission flow round-trips through StreamingDelegate.

### Phase: Computer Use

| Commit | Summary |
|--------|---------|
| `0c2b6c9b` | Real computer use: ScreenCaptureKit + AX tree + per-provider wiring |

**Audit focus:** Verify ScreenCaptureKit produces actual screenshots (not stubs). Verify AXorcist bridge returns real accessibility tree. Check TCC permission gating.

### Phase: Research-Driven Hardening

| Commit | Summary |
|--------|---------|
| `dc6a29a0` | AX pruning, dual decay, MCP client, hash guard |
| `7b8c7628` | Subagent foundation + complexity caching + anchor dedup |

**Audit focus:** Verify memory decay constants (Ebbinghaus model). Check hash guard against SHA collision attacks.

### Phase: Local Model Catalog Buildout

| Commit | Summary |
|--------|---------|
| `af2546cb` | 15+ providers via universal OpenAI-compatible provider |
| `3629cba6` | Local model catalog: Gemma 4, Qwopus, DeepSeek R1, Qwen Coder (18 models) |
| `566da094` | Per-model native capability metadata — each model tuned to its potential |
| `80cebe63` | Model routing upgrade: 2026 frontier models as defaults |
| `1bca2295` | Per-model capability hardening: correct context, temps, thinking, abliteration |

**Audit focus:** Verify every model's HuggingFace repo ID is valid and downloadable. Verify `isSSM`, `supportsThinkingMode`, `supportsVision` flags are correct per model architecture. Verify `maxContextTokens` matches model training context. Verify temperature/topK/topP tuning matches published recommendations.

### Phase: Release Hardening

| Commit | Summary |
|--------|---------|
| `285872e4` | Release hardening: model catalog, FFI crash fix, privacy manifest |
| `aa91b846` | Omega cleanup: delete 28 dead files, stub OrchestratorState |
| `d306d171` | Fix graph stutter: revert triple buffer to double buffer |
| `a1751587` | Agent consolidation: .agent mode routes through main chat |
| `9d6e4b80` | Cloud Distillation UI, tool tiers, sandbox, settings cleanup |
| `0c92cb96` | Binary size optimization + specialist model tool tier upgrades |
| `0af6ec63` | Release build: -Os, LTO, dead code stripping, ShipGate |
| `3c7003b6` | A+ audit: fix all P0-P2 issues from definitive release audit |
| `a2c01f74` | Final release cleanup: SHIP_MODE gating, remove hermes bundle |
| `71f918ca` | Optimize Debug + Release configs, auto-SHIP_MODE on archive |

**Audit focus:** Verify ShipGate excludes agent_core in release (saves 52MB). Verify privacy manifest (PrivacyInfo.xcprivacy) lists all data types. Verify LTO + dead code stripping don't break UniFFI exports. Verify 28 deleted Omega files had no remaining references.

### Phase: Bug Fixes

| Commit | Summary |
|--------|---------|
| `0013169a` | Fix 4 compiler warnings: unused variables and dead assignments |
| `ff3b890a` | Fix Gemma 4 HuggingFace repo IDs — models now downloadable |
| `959fc686` | Fix code editor UX: background, popover anchor, bar layout |
| `005b40f5` | Unify agent system: remove Hermes subprocess, add model capability UI |

**Audit focus:** Verify no regressions from Hermes removal. Verify code editor still renders correctly.

---

## 2. UNCOMMITTED WORK (Current Session)

### Modified Files (24 tracked files)

**Mamba-2 / SSM Runtime (NEW — this session):**
- `EpistemosConfig.swift` — +3 feature flags (`ssmStatePersistenceEnabled`, `ssmAutoSaveOnTurnEnd`, `ssmMaxSnapshotsPerModel`)
- `epistemos-core/src/ssm_state.rs` — **NEW**: v2 binary state format, 380 LOC, 5 tests pass
- `epistemos-core/src/lib.rs` — +ssm_state module
- `epistemos-core/src/uniffi_exports.rs` — +6 FFI exports (ssm_save/load/list/prune/hash)
- `epistemos-core/uniffi/epistemos_core.udl` — +6 function decls, +SSMStateError enum
- `epistemos-core/Cargo.toml` — +tempfile dev-dep, +half/memmap2/chrono already present

**MLX Inference Integration (NEW — this session):**
- `MLXInferenceService.swift` — +176 lines: persistent SSM session, state save hook, setSsmStateService/setActiveSessionID, notifySSMStateService
- `AppBootstrap.swift` — +21 lines: SSMStateService creation + wiring to MLX + NightBrain
- `ChatCoordinator.swift` — +41 lines: activeSessionID wiring, vault root passing
- `NightBrainService.swift` — +52 lines: ssmStatePruning job, ssmStateServiceProvider

**Vault Memory Integration (NEW — this session + prior Kimi session):**
- `ConversationPersistence.swift` — +40 lines: ssmStatePath binding, SSM state methods
- `SSMStateService.swift` — **NEW**: 210 LOC actor (save/load/list/prune/staleness detection)

**Agent Core Enhancements (prior Kimi/Claude sessions):**
- `agent_core/src/bridge.rs` — +652 lines: neocortex FFI, vault topology, neural cache, SSM state, evolution, dispatcher, shm
- `agent_core/src/agent_loop.rs` — +40 lines: prompt mode detection, compaction improvements
- `agent_core/src/session.rs` — +70 lines: session summary generation
- `agent_core/src/prompts.rs` — +63/-26 lines: tool preference rules, local fallback
- `agent_core/src/lib.rs` — +11 lines: new modules (neocortex, dispatcher, context_loader, evolution)
- `agent_core/src/storage/memory_classifier.rs` — +10 lines: embedding improvements
- `agent_core/src/tools/registry.rs` — +5 lines: tool additions
- `agent_core/Cargo.toml` — +4 deps (rayon, uuid features)

**Other:**
- `InferenceState.swift` — +150 lines: new SSM model entries (LFM2, LFM2.5, Mamba2, Jamba, FalconH1)
- `StreamingDelegate.swift` — +2 lines: minor
- `LocalAgentLoop.swift` — +17 lines: token budget from model
- `project.yml` — +5 lines: local mlx-swift-lm package path

### New Untracked Files (26 files)

**Metal Shaders (4 files, 14 kernels):**
- `Epistemos/Shaders/Mamba2/segsum_stable.metal` — stable segment sum
- `Epistemos/Shaders/Mamba2/inter_chunk_scan.metal` — Apple-safe 3-dispatch scan
- `Epistemos/Shaders/Mamba2/elementwise_ssm_helpers.metal` — decay, merge, SiLU, RMSNorm
- `Epistemos/Shaders/Mamba2/direct_conv.metal` — 4-tap causal depthwise conv

**Swift Actors/Services (7 files):**
- `Epistemos/Engine/MetalRuntimeManager.swift` — 14 kernel pipeline manager + benchmark harness
- `Epistemos/Vault/SSMStateService.swift` — SSM state persistence actor
- `Epistemos/Vault/VaultLifecycleService.swift` — vault lifecycle (graph gen, evolution sweep)
- `Epistemos/Vault/KnowledgeGraphService.swift` — session graph wrapper
- `Epistemos/Vault/ContradictionDetectionService.swift` — fact conflict detection
- `Epistemos/Vault/SkillEvolutionService.swift` — GEPA skill self-improvement
- `Epistemos/Vault/SessionBrowser.swift` — session listing

**Rust Modules (8 files):**
- `agent_core/src/neocortex.rs` — SSM-ready fluid awareness layer
- `agent_core/src/dispatcher.rs` — skill dispatch routing
- `agent_core/src/context_loader.rs` — 5-tier vault context injection
- `agent_core/src/evolution/` — trace analyzer + mutation proposer (GEPA)
- `agent_core/src/storage/contradiction_detector.rs` — 4 conflict types
- `agent_core/src/storage/hyperbolic_topology.rs` — Poincare embeddings
- `agent_core/src/storage/neural_cache.rs` — 4-layer tiered retrieval
- `agent_core/src/storage/session_store.rs` — session folder management
- `agent_core/src/storage/session_graph.rs` — knowledge graph extraction
- `agent_core/src/storage/skills_registry.rs` — YAML skill registry
- `agent_core/src/storage/ssm_state.rs` — v1 binary state format

**Documentation (7 files):**
- `AI_VAULT_RUNTIME_AUDIT.md`
- `MAMBA2_RUNTIME_PLAN.md`
- `VAULT_STATE_SCHEMA.md`
- `PERF_BASELINE.md`
- `MIGRATION_AND_ROLLBACK_PLAN.md`
- Plus several prior audit docs (CLAUDE_IMPLEMENTATION_AUDIT*.md, etc.)

**Local Package:**
- `LocalPackages/mlx-swift-lm/` — Local fork of mlx-swift-lm with `extractKVCache()` + `injectKVCache()` on ChatSession

---

## 3. SUBSYSTEM-BY-SUBSYSTEM AUDIT

### A. Rust Agent Core (agent_core/)

**Status: WORKING — Debug only (ShipGate excludes from release)**

| Component | Files | Status | Notes |
|-----------|-------|--------|-------|
| Agent loop | agent_loop.rs | ✅ Working | 25-turn max, 3 prompt modes, proactive+reactive compaction |
| Bridge/FFI | bridge.rs | ✅ Working | 40+ UniFFI exports, panic-safe guards |
| Claude provider | providers/claude.rs | ✅ Working | SSE streaming, thinking block preservation |
| OpenAI provider | providers/openai.rs | ✅ Working | o1/GPT-4 |
| Gemini provider | providers/gemini.rs | ✅ Working | Google AI |
| Perplexity | providers/perplexity.rs | ✅ Working | No tools |
| OpenAI-compatible | providers/openai_compatible.rs | ✅ Working | 15+ providers (OpenRouter, Ollama, etc.) |
| Tool registry | tools/registry.rs | ✅ Working | 11 tools auto-registered |
| vault_search tool | tools/ | ✅ Working | Hybrid semantic + keyword |
| vault_read/write | tools/ | ✅ Working | Frontmatter-aware |
| bash_execute | tools/ | ✅ Working | Allowlist-gated |
| web_search/fetch | tools/ | ✅ Working | HTTP-based |
| computer use | tools/ | ✅ Working | Delegates to Swift |
| file_ops | tools/ | ✅ Working | General FS operations |
| think tool | tools/think.rs | ✅ Working | Extended reasoning |
| Context compaction | compaction.rs | ✅ Working | 80% threshold trigger |
| Prompt caching | prompt_caching.rs | ✅ Working | Claude-specific |
| Security scanner | security.rs | ✅ Working | Credential redaction |
| Session store | storage/session_store.rs | ✅ Working | JSONL transcript, trace, summary |
| Vault store | storage/vault.rs | ✅ Working | Tantivy FTS + SQLite |
| Neural cache | storage/neural_cache.rs | ✅ Working | 4-layer tiered retrieval |
| Memory classifier | storage/memory_classifier.rs | ✅ Working | Add/Update/Delete/Noop |
| Memory decay | storage/memory_decay.rs | ✅ Working | Ebbinghaus model |
| Contradiction detector | storage/contradiction_detector.rs | ✅ Working | 4 conflict types |
| Hyperbolic topology | storage/hyperbolic_topology.rs | ✅ Working | Poincare disk, Markov Blanket |
| Session graph | storage/session_graph.rs | ✅ Working | 2-pass extraction |
| Skills registry | storage/skills_registry.rs | ✅ Working | YAML with usage stats |
| SSM state (v1) | storage/ssm_state.rs | ✅ Working | MAMB binary format |
| Neocortex | neocortex.rs | ⚠️ Text-only | Awaiting tensor state APIs |
| Dispatcher | dispatcher.rs | ✅ Working | Skill routing |
| Context loader | context_loader.rs | ✅ Working | 5-tier vault injection |
| Evolution (GEPA) | evolution/ | ✅ Working | Trace analysis + mutation |

**Audit questions for Codex:**
1. Are all 11 tools in registry.rs reachable from the agent loop?
2. Does compaction preserve thinking blocks (CLAUDE.md NON-NEGOTIABLE)?
3. Is the permission flow from StreamingDelegate → Rust → back to Swift deadlock-free?
4. Does the 25-turn limit actually work as a safety rail?

---

### B. Local Model Catalog (InferenceState.swift)

**Status: 33 models enumerated, all downloadable**

| Family | Count | isSSM | supportsThinking | supportsVision | Notes |
|--------|-------|-------|-----------------|----------------|-------|
| Qwen 3.5 | 6 | No | Yes (4B+) | No | enable_thinking Jinja key |
| Gemma 4 | 5 | No | No | Yes (27B) | Thinking not in MLX pipeline |
| Qwopus | 2 | No | Yes | No | Claude Opus distilled |
| LFM2.5 | 5 | Yes | Yes (1.2B-T) | Yes (VL-1.6B) | Liquid Foundation Models |
| LFM2 | 3 | Yes | No | No | SSM-only |
| Mamba2 | 1 | Yes | No | No | Pure Mamba-2 |
| Jamba | 1 | Yes | No | No | Hybrid Mamba+attention |
| FalconH1 | 2 | Yes | No | No | Hybrid |
| DeepSeek R1 | 1 | No | Yes (always) | No | Distilled 7B |
| Others | 7 | No | Mixed | Mixed | SmolLM3, Devstral, etc. |

**Audit questions for Codex:**
1. Do all 33 HuggingFace repo IDs resolve to real downloadable models?
2. Is `maxContextTokens` correct for each model? (e.g., Qwen 3.5 should be 131072, not 32768)
3. Are `minimumRecommendedMemoryGB` values accurate? (e.g., 27B models should require 24GB+)
4. Do any models claim `supportsThinkingMode` but lack chat template support?

---

### C. Graph Engine + Metal Rendering

**Status: WORKING — Metal GPU-accelerated graph**

| Component | Status | Notes |
|-----------|--------|-------|
| GraphEngine.swift | ✅ Working | Rust FFI wrapper, force-directed layout |
| MetalGraphView.swift | ✅ Working | CAMetalLayer, MTLDevice, GPU rendering |
| PhysicsCoordinator | ✅ Working | Attract/off/repel center, freeze |
| SDF Label Atlas | ✅ Working | GPU text rendering |
| graph-engine Rust crate | ✅ Working | Physics + rendering |

**Audit questions for Codex:**
1. Is the double-buffer (not triple) approach stable? (d306d171 reverted triple → double)
2. Any memory leaks in the Metal render loop?

---

### D. Cloud Knowledge Distillation

**Status: WORKING — runs in NightBrain**

- Compiles per-model knowledge vaults from vault notes + recent chats
- Stores via KnowledgeProfileStore
- UI: CloudDistillation settings panel exists
- Gated by NightBrain scheduling

**Audit questions for Codex:**
1. Does the distillation actually produce valid markdown files?
2. Is the concept limit (per model) properly enforced?

---

### E. Vault System

**Status: WORKING — Tantivy FTS + SwiftData + SQLite**

| Component | Status | Notes |
|-----------|--------|-------|
| VaultSyncService | ✅ Working | Hybrid persistence bridge |
| Tantivy FTS (Rust) | ✅ Working | Keyword + field search |
| SQLite vec0 embeddings | ⚠️ Created but not always populated | Lazy init |
| SearchIndexService | ✅ Working | Used by NightBrain checkpoint |
| VaultManifest | ✅ Working | Note catalog for briefings |

**Audit questions for Codex:**
1. Is the Tantivy index correctly updated on every vault_write?
2. Are embeddings ever populated in the vec0 table? If not, is the table dead weight?

---

### F. NightBrain (Background Maintenance)

**Status: ALL 10 JOBS IMPLEMENTED AND RUNNABLE**

| Job | Implementation | Audit Risk |
|-----|---------------|------------|
| eventStoreCheckpointVacuum | `store.walCheckpointVacuum()` | Low |
| searchIndexPassiveCheckpoint | `searchIndex.passiveCheckpoint()` | Low |
| dedupeArtifacts | `store.deduplicateArtifacts()` | Low |
| workspaceSnapshotCompaction | `store.compactSnapshots(olderThanDays: 30)` | Medium — verify no data loss |
| memoryDistillation | `graphMemory.distillMemory()` | Medium — verify decay rates |
| cloudKnowledgeDistillation | Async closure | Low |
| sessionGraphGeneration | `VaultLifecycleService.mergeVaultGraphs()` | Low |
| skillEvolutionAnalysis | `VaultLifecycleService.runEvolutionSweep()` | Low |
| ssmStatePruning | Prune per-model SSM snapshots | Low |
| maintenanceLog | No-op terminal marker | N/A |

**Audit questions for Codex:**
1. Does the resume-from-checkpoint logic correctly skip already-completed jobs?
2. Are thermal guards actually preventing execution on hot devices?

---

### G. Computer Use

**Status: WORKING — 6 native macOS actions**

| Action | Implementation | Notes |
|--------|---------------|-------|
| screenshot | ScreenCaptureKit (1280x720 JPEG) | TCC permission required |
| click | CGEvent mouse down/up | At x,y coordinates |
| type_text | CGEvent keyboard unicode | String input |
| scroll | CGEvent scroll | At x,y |
| get_ax_tree | AXorcist accessibility tree | Full tree dump |
| key_press | CGEvent key combos | Modifier support |

**Audit questions for Codex:**
1. Does ScreenCaptureKit gracefully handle the case where permission is denied?
2. Is there rate limiting on CGEvent actions to prevent runaway automation?

---

### H. Knowledge Fusion / Training

**Status: INFRASTRUCTURE PRESENT — NOT END-TO-END FUNCTIONAL**

| Component | Status | Notes |
|-----------|--------|-------|
| AdapterRegistry | ✅ Can load/export LoRA | No training invocation |
| TrainingProfileManager | ✅ Recommends profiles | knowledge/style/mixed |
| DocumentChunker (Rust) | ✅ Working | Min 50, max 2048 tokens |
| TrainingScheduler | ⚠️ Exists | Not wired to actual training |
| Training UI | ⚠️ Exists | TrainOnVaultView, TrainingHistoryView |

**Audit questions for Codex:**
1. Is any training code actually invoked anywhere? If not, should the UI be hidden?
2. The epistemos-core `auto_tune()` function exists — is it ever called from Swift?

---

### I. Mamba-2 / SSM Runtime (NEW — This Session)

**Status: PHASE 1A COMPLETE — persistence wired, custom kernels created but not yet invoked**

| Component | Status | Notes |
|-----------|--------|-------|
| ssm_state.rs (v2, epistemos-core) | ✅ 5/5 tests pass | 60-byte header, vault_id/model_hash scoping |
| SSMStateService.swift | ✅ Wired | save/load/list/prune/staleness |
| Feature flags | ✅ 3 flags in EpistemosConfig | Default off |
| MLXInferenceService hooks | ✅ Wired | Persistent SSM session, state save notify |
| AppBootstrap wiring | ✅ Wired | Service creation + MLX + NightBrain |
| ChatCoordinator | ✅ Wired | activeSessionID + vault root |
| ConversationPersistence | ✅ Wired | ssmStatePath binding |
| NightBrain pruning | ✅ Wired | ssmStatePruning job |
| MetalRuntimeManager | ✅ Created | 14 pipeline states + benchmark harness |
| segsum_stable.metal | ✅ Created | Naive + tiled variants |
| inter_chunk_scan.metal | ✅ Created | 3-dispatch safe (NO Decoupled Lookback) |
| elementwise_ssm_helpers.metal | ✅ Created | 6 utility kernels |
| direct_conv.metal | ✅ Created | Prefill + decode + fused |
| LocalPackages/mlx-swift-lm | ✅ Created | extractKVCache + injectKVCache |

**Audit questions for Codex:**
1. Does the v2 binary format correctly handle both v1 and v2 files? (backward compat)
2. Are the Metal kernels numerically correct? (segsum must avoid catastrophic cancellation)
3. Is the inter_chunk_scan truly safe on Apple GPUs? (no spin-waiting between workgroups)
4. Does `notifySSMStateService` actually result in state being saved to disk?
5. Is the `persistentSSMSession` properly cleared on model unload?
6. Does staleness detection (`isStateStale`) handle the case where vault root doesn't exist?
7. Are Metal shader function constants (`CHUNK_LEN`, `NUM_HEADS`) correctly set before dispatch?

---

### J. MLX Inference

**Status: FULLY FUNCTIONAL**

| Component | Status | Notes |
|-----------|--------|-------|
| MLXInferenceService | ✅ Actor | Single-request gate, streaming |
| ChatSession (MLX) | ✅ Working | Multi-turn, thinking mode |
| Loop detection | ✅ Working | 5 repeated chunks or 3 suffixes |
| Memory policies | ✅ Working | Per-request limits |
| Vision models | ✅ Working | MLXVLM dependency |

**Audit questions for Codex:**
1. Is the `LocalMLXRequestGate` truly preventing concurrent inference? (single-request enforcement)
2. Does the loop guard correctly distinguish thinking loops from intentional repetition?

---

### K. Conversation Persistence

**Status: FULLY FUNCTIONAL**

- JSON-encoded turns with full metadata (role, model, tokens, tool calls, latency)
- Session folder structure: `{root}/sessions/{uuid}.jsonl`
- Agent session folder forwarding (Rust → Swift)
- SSM state path binding per session

**Audit questions for Codex:**
1. Is the JSONL append truly atomic? (file handle management)
2. Are session files ever cleaned up, or do they grow unbounded?

---

### L. MCP Bridge

**Status: FULLY FUNCTIONAL**

- omega-mcp Rust crate: orchestrator, catalog, vault ops
- MCPBridge.swift: Swift wrapper
- 5 agent categories: safari, file, notes, terminal, automation
- SQLite execution logging

**Audit questions for Codex:**
1. Is the MCP bridge used in the main chat flow, or only in agent mode?
2. Are there any MCP tools that shadow the agent_core tools?

---

### M. Feature Flags (EpistemosConfig)

**17 total flags, all @AppStorage backed:**

| Category | Flags | All Wired? |
|----------|-------|-----------|
| Power | ecoModeEnabled | ✅ |
| Capture | captureEnabled, ocrFallbackEnabled, allowlist, blocklist | ✅ |
| Friction | frictionEnabled, frictionThreshold | ✅ |
| NightBrain | enabled, requiresAC, minIdleSeconds, menuBarAgent | ✅ |
| SSM State | persistenceEnabled, autoSaveOnTurnEnd, maxSnapshots | ✅ |
| Heartbeat | enabled, interval, requiresAC, prompt, budgetCap | ✅ |

---

### N. epistemos-core FFI

**Status: 30+ functions exported, all callable from Swift**

| Category | Functions | Notes |
|----------|-----------|-------|
| Vault analysis | compute_mtld, tokenize_for_mtld, estimate_tokens | MTLD lexical diversity |
| Integrity | content_hash, verify_content_hash, normalize_to_nfc | BLAKE3, NFC |
| Recovery | classify_corruption, repair_mojibake, extract_text_from_binary | Mojibake repair |
| Filesystem | full_sync_fd | F_FULLFSYNC (macOS only) |
| Document | classify_document, filter_boilerplate, chunk_document | Chunking pipeline |
| Quality | dedup_texts, score_training_pair | Near-duplicate detection |
| Routing | route_prompt | Adapter type classification |
| Auto-tuning | select_lora_rank, select_lora_alpha, auto_tune | LoRA hyperparams |
| Recall | instant_recall_create/insert/remove/search/clear/encode | Trigram BM25 |
| Scheduling | evaluate_schedule | Training tier decision |
| SSM State (NEW) | ssm_save/load/list/prune_state, ssm_hash_vault/model | Vault memory |

---

## 4. ARCHITECTURE DIAGRAM

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           EpistemosApp (@main)                           │
│                              AppBootstrap                                │
│   ┌────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────────┐   │
│   │ ChatState  │ │InferenceState│ │  GraphState   │ │ EpistemosConfig│   │
│   └─────┬──────┘ └──────┬───────┘ └──────┬───────┘ └────────────────┘   │
│         │               │                │                               │
│   ┌─────▼──────────────▼────────────────▼────────────────────────┐      │
│   │                   ChatCoordinator                             │      │
│   │  handleQuery() → PipelineService → TriageService              │      │
│   │  runRustAgentPath() → agent_core FFI (debug only)             │      │
│   └──────────────────────┬───────────────────────────────────────┘      │
│                          │                                               │
│   ┌──────────────────────▼────────────────────────────────────────┐     │
│   │                    LLMService                                  │     │
│   │  ┌──────────────────┐  ┌──────────────────┐                   │     │
│   │  │ LocalMLXClient   │  │ CloudLLMClient    │                   │     │
│   │  │ → MLXInference   │  │ → Anthropic/OAI   │                   │     │
│   │  │   Service (actor) │  │   /Gemini/etc     │                   │     │
│   │  │ + SSM persist    │  │                    │                   │     │
│   │  └──────────────────┘  └──────────────────┘                   │     │
│   └────────────────────────────────────────────────────────────────┘     │
│                                                                          │
│   ┌─────────────┐ ┌──────────────┐ ┌───────────────┐ ┌──────────────┐  │
│   │SSMState     │ │MetalRuntime  │ │ VaultSync     │ │ NightBrain   │  │
│   │Service      │ │Manager       │ │ Service       │ │ Service      │  │
│   │(save/load)  │ │(14 kernels)  │ │(Tantivy+GRDB) │ │(10 jobs)     │  │
│   └─────────────┘ └──────────────┘ └───────────────┘ └──────────────┘  │
│                                                                          │
│   ┌─────────────┐ ┌──────────────┐ ┌───────────────┐ ┌──────────────┐  │
│   │Conversation │ │ GraphEngine  │ │CloudKnowledge │ │ MCPBridge    │  │
│   │Persistence  │ │ (Metal GPU)  │ │Distillation   │ │ (omega-mcp)  │  │
│   └─────────────┘ └──────────────┘ └───────────────┘ └──────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘

Rust Crates (FFI):
┌─────────────────┐  ┌───────────────┐  ┌────────────┐  ┌──────────┐
│  agent_core      │  │ epistemos-core │  │ graph-engine│  │omega-mcp │
│  (debug only)    │  │ (always ships) │  │ (rendering) │  │(MCP svr) │
│  11 tools        │  │ 30+ exports    │  │ Metal GPU   │  │5 agents  │
│  5 providers     │  │ zero-corruption│  │ physics     │  │logging   │
│  vault memory    │  │ SSM state v2   │  │ SDF labels  │  │dispatch  │
└─────────────────┘  └───────────────┘  └────────────┘  └──────────┘
```

---

## 5. WORKS vs STUBBED

### Genuinely Working (End-to-End)
- Local MLX inference (streaming, thinking mode, loop detection)
- Cloud provider routing (5 providers)
- Rust agent loop with 11 tools
- Computer use (screenshot, click, type, AX tree)
- Vault search (Tantivy FTS)
- NightBrain (all 10 jobs)
- Graph rendering (Metal GPU)
- Cloud knowledge distillation
- MCP bridge (omega-mcp)
- Feature flag system (17 flags)
- SSM state persistence pipeline (save/load/prune)
- Conversation persistence (JSONL + session metadata)
- Memory classifier (add/update/delete/noop)
- Hyperbolic topology (Poincare disk)

### Infrastructure Present But Not End-to-End
- **Knowledge Fusion training** — UI + profiles exist, no training execution
- **SQLite vec0 embeddings** — table created, not always populated
- **Neocortex** — text-only, awaiting tensor state connection
- **Custom Metal kernels** — compiled but not yet invoked in SSD forward pass
- **Skill evolution mutations** — proposals generated but no auto-apply

### Dead / Excluded
- **Hermes subprocess** — removed (005b40f5), all routing through Rust agent_core
- **28 Omega files** — deleted (aa91b846)
- **ODIATraceGenerator** — excluded in project.yml
- **TraceDataMixer** — excluded in project.yml

---

## 6. KNOWN ISSUES & TECHNICAL DEBT

| Issue | Severity | Location | Notes |
|-------|----------|----------|-------|
| `TraceCollector.swift` `TraceEvent` redeclaration | Build error | Epistemos/Harness/ | Pre-existing, not from recent work |
| Training UI exists but training doesn't execute | UX confusion | KnowledgeFusion/ | Should hide or disable |
| SSM state save is notification-only (tensor save blocked by private cache) | Functional gap | MLXInferenceService.swift | Local fork solves this (LocalPackages/) |
| agent_core only in DEBUG builds | Expected | ShipGate | By design — saves 52MB |
| Neocortex is text-only | Feature gap | agent_core/neocortex.rs | Needs MLX tensor injection |
| Metal kernels compiled but never dispatched | Not yet integrated | Shaders/Mamba2/ | Phase 1B next step |
| Vec0 embeddings table may be empty | Reduced search quality | vault.rs | Depends on EmbeddingService init |
| No end-to-end SSM model test | Untested path | MLXInferenceService | Needs model download |

---

## 7. CODEX AUDIT CHECKLIST

### Critical Safety Checks
- [ ] Verify thinking blocks are NEVER stripped from message history (CLAUDE.md NON-NEGOTIABLE)
- [ ] Verify API keys are in macOS Keychain, never UserDefaults
- [ ] Verify `DispatchQueue.main.async` (not `.sync`) in all UniFFI callbacks
- [ ] Verify no `try!`, no force-unwraps, no `print()` in production paths
- [ ] Verify every `unsafe` block has `// SAFETY:` comment (Rust)
- [ ] Verify Metal kernels have bounds guards on all buffer accesses
- [ ] Verify inter_chunk_scan does NOT use Decoupled Lookback (would crash on Apple GPUs)

### Build Integrity
- [ ] `xcodebuild -scheme Epistemos build` succeeds (ignore TraceCollector pre-existing error)
- [ ] `cargo check --manifest-path agent_core/Cargo.toml` succeeds
- [ ] `cargo test --manifest-path epistemos-core/Cargo.toml` — 5/5 ssm_state tests pass
- [ ] `cargo check --manifest-path epistemos-core/Cargo.toml` succeeds
- [ ] project.yml regeneration via xcodegen produces valid project

### Functional Verification
- [ ] Feature flag `ssmStatePersistenceEnabled = false` → zero SSM code paths execute
- [ ] Feature flag `ssmStatePersistenceEnabled = true` → state saved after SSM generation
- [ ] Non-SSM models (Qwen, Gemma) completely unaffected by SSM changes
- [ ] NightBrain ssmStatePruning respects `ssmMaxSnapshotsPerModel`
- [ ] Graph rendering doesn't stutter (double buffer, not triple)
- [ ] Model download for all 33 catalog entries resolves to valid HF repos

### Architecture Consistency
- [ ] No circular dependencies between Swift modules
- [ ] No Rust panics crossing FFI boundary (catch_unwind everywhere)
- [ ] No async/await deadlocks in actor isolation (check MLXInferenceService)
- [ ] ShipGate correctly excludes agent_core from release binaries
- [ ] SHIP_MODE=release build produces < 100MB binary

### Data Integrity
- [ ] MAMB v2 format correctly round-trips (save → load → compare)
- [ ] Session JSONL is truly append-only (never rewritten)
- [ ] Vault notes are NFC-normalized before storage
- [ ] BLAKE3 hashes are consistent across runs

---

## 8. CODE EDITOR SUBSYSTEM AUDIT

### Architecture (Dual Editor System)

**Prose Editor (Markdown/Text):**
- `ProseEditorView.swift` (484 LOC) — SwiftUI container, debounced saves
- `ProseEditorRepresentable2.swift` (1,324 LOC) — NSViewRepresentable + Coordinator2 (per-page state cache)
- `ProseTextView2.swift` (2,448 LOC) — NSTextView + TextKit 2 (NSTextLayoutManager)
- `MarkdownContentStorage.swift` (1,160 LOC) — Rust FFI paragraph styling + tree-sitter code block tokenization

**Code Editor (Language-specific):**
- `CodeEditorView.swift` (3,957 LOC) — Xcode-style editor via CodeEditSourceEditor v0.15.2
- Tree-sitter syntax highlighting, flat theme engine
- MetalComputeEngine for GPU-accelerated semantic search (implemented, not yet used in hot path)
- `CodeContextBridge` — semantic context weighting
- `EditorBreadcrumbBar.swift` (307 LOC) — Xcode-style symbol hierarchy
- `SegmentedIndentationGuideView.swift` (286 LOC) — VS Code-style indent guides
- `CodeAskBar.swift` (595 LOC) — Inline AI code Q&A

**AI Partner Integration:**
- `AIPartnerService.swift` (740 LOC) — Observable AI state: suggestions, context highlights, frequency presets (calm/balanced/frequent/aggressive)
- `AIPartnerControlPanel.swift` (666 LOC) — Configuration UI
- `AIPartnerInlineView.swift` (713 LOC) — Ghost text suggestion rendering
- `GhostBrainCoauthor.swift` (80 LOC) — Graph-aware context injection
- `WeightedContextEngine.swift` (506 LOC) — Semantic + recency + graph weighting

**Overlay Systems:**
- `TransclusionOverlayManager2.swift` (335 LOC) — `((blockref))` inline rendering
- `BlockRefAutocomplete2.swift` (312 LOC) — `((` autocomplete popover
- `DiffSheetView.swift` (889 LOC) — GitHub-style version history diff (unified + split, chunk navigation, restore)
- `DiffPreviewView.swift` — Green/red inline diff for AI file edits

### Recent Fixes (Commit 959fc686)
- Fixed double-stacked backgrounds (ultraThinMaterial + grey overlay fighting)
- Fixed suggestion popover anchoring (pins to gutter edge x:70, breadcrumb offset y:36)
- Cleaned bottom bar layout (removed .bar background, adjusted padding)
- Enabled `useThemeBackground: true` for clean CodeEditSourceEditor rendering

### Editor Feature Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `codeEditor.wrapLines` | false | Line wrapping |
| `codeEditor.showMinimap` | true | Minimap visibility |
| `codeEditor.showInvisibles` | false | Whitespace chars |
| `codeEditor.fontSize` | 13 | Font size (8-32pt) |
| `codeEditor.useSpaces` | true | Spaces vs tabs |
| `codeEditor.tabWidth` | 4 | Indent width |
| AI Partner mode | .auto | Auto vs manual suggestions |
| AI Partner frequency | .balanced | Calm/balanced/frequent/aggressive |

### Metal GPU in Editor

`MetalComputeEngine` (inside CodeEditorView.swift):
- `batchCosineSimilarity()` — GPU batch scoring
- `topKSimilarity()` — fast top-K selection
- `cpuBatchCosineSimilarity()` — CPU fallback via Accelerate vDSP
- **Status:** Implemented and compiled, but semantic search loop still uses CPU path. GPU path ready for integration.

### Performance Notes
- CPU-bound cosine similarity in CodeContextBridge (GPU engine available but not wired)
- Synchronous NLEmbedding calls block utility thread
- Syntax highlighting on main thread for large files
- Binding<String> path (not NSTextStorage) — by design due to CodeEditSourceEditor constraint

### Audit Questions for Codex
- [ ] Is MetalComputeEngine's `metalSource` string valid MSL? Does it compile at runtime?
- [ ] Does per-page state (Coordinator2) correctly restore scroll position on page switch?
- [ ] Is the 300ms debounce + 3s persist save strategy reliable under rapid edits?
- [ ] Does `isRichText = true` in ProseTextView2 cause any data corruption? (Set true to fix TextKit 2 layout on Sonoma)
- [ ] Are all 4 flat themes (flatLight, flatDark, minimalLight, minimalDark) producing correct colors?
- [ ] Does the AI Partner suggestion popover clip off-screen on small windows?
- [ ] Is GhostBrainCoauthor's vault search bounded by timeout/token limit?

---

## 9. NEW UI VIEWS & FEATURES AUDIT

### Chat & Reasoning (NEW — April 2026)

| View | LOC | Status | Purpose |
|------|-----|--------|---------|
| ThinkingTrailView | ~200 | ✅ Working | Collapsible reasoning disclosure (Anthropic thinking + OpenAI reasoning) |
| ArtifactBlockView | ~300 | ✅ Working | Interactive artifact cards (JSON/YAML/code/CSV), expand/collapse, copy, export |
| ContextWindowIndicator | ~100 | ✅ Working | Animated progress bar showing token usage (green → yellow → orange → red) |
| ModelAboutSheet | ~200 | ✅ Working | Compact model capability overview (vision, thinking, agent, tool calling) |

### Agent System UI (Consolidated)

| View | Status | Notes |
|------|--------|-------|
| AgentModeUnavailableView | ✅ NEW | Graceful degradation when model lacks agent capability |
| TaskInputBar | ✅ NEW | Simple task entry form |
| OmegaPanel | ⚠️ Retired | Directs to unified chat |
| ExecutionProgressView | ⚠️ Retired | Agent progress now inline in chat |
| ResearchRequestView | ⚠️ Retired | Merged into main chat |
| ConfirmationSheet | ⚠️ Retired | Approvals via Rust agent_core permission flow |

### Knowledge Fusion Training UI

| View | LOC | Status | Purpose |
|------|-----|--------|---------|
| TrainOnVaultView | ~400 | ✅ UI complete | Main training form with Python env, model info, progress |
| TrainingHistoryView | ~300 | ✅ UI complete | Adapter list with quality scores, metrics, context menu |
| AdapterSelectorView | ~200 | ✅ UI complete | Dropdown picker for loaded adapters |
| FeedbackIndicatorView | ~150 | ✅ UI complete | Sidebar badge showing preference collection status |

**Note:** Training UI is complete but the actual MLX training execution loop is not wired end-to-end. UI exists, execution path does not.

### Cloud Knowledge Distillation Settings

| View | Status | Purpose |
|------|--------|---------|
| ModelVaultsSettingsView | ✅ Working | Per-provider vault compilation status + rebuild |
| CognitiveSettingsSection | ✅ Working | Cross-App Capture, Friction, Night Brain toggles |

### Session Management

| View | Status | Purpose |
|------|--------|---------|
| SessionListView | ✅ Working | Sidebar list of agent sessions grouped by date |
| SessionBrowser.swift (service) | ✅ Working | Session folder scanning + metadata loading |

### Skills Evolution

| View | Status | Purpose |
|------|--------|---------|
| SkillEvolutionView | ✅ Working | GEPA mutation proposals with diff viewer |

### Landing & Navigation

| View | Status | Purpose |
|------|--------|---------|
| TimeMachineView | ✅ Working | Temporal vault state exploration |
| SessionIntelligenceOverlay | ✅ Working | Semantic title extraction from session logs |
| LandingView | ✅ Enhanced | Liquid glass greeting, operating mode selector |

### Vault & Conflict Resolution

| View | Status | Purpose |
|------|--------|---------|
| ConflictCardView | ✅ Working | Old vs new fact contradiction display with resolution buttons |

### System Views

| View | Status | Purpose |
|------|--------|---------|
| ToastOverlay | ✅ Working | Bottom-aligned glass capsule notifications |

### Audit Questions for Codex
- [ ] Are retired Omega views truly unreachable? (OmegaPanel, ExecutionProgressView, ResearchRequestView, ConfirmationSheet)
- [ ] Does TrainOnVaultView show misleading "Train" buttons when no training backend is wired?
- [ ] Is TimeMachineView's "restore" operation non-destructive? (Should create new workspace, not overwrite)
- [ ] Does ConflictCardView correctly handle all 4 conflict types (numeric, boolean, antonym, semantic)?
- [ ] Are SwiftUI previews (#Preview) functional for all new views?
- [ ] Does ModelAboutSheet display correct capabilities for all 33 models?
- [ ] Is the context window indicator's token estimation accurate? (Uses `estimate_tokens()` from Rust)
- [ ] Do retired Omega views show clear messaging about where functionality moved?

---

## END OF SYNTHESIS

**Total scope:**
- 30 commits audited (Goose migration → release hardening → Mamba-2 runtime)
- +1,622 lines uncommitted across 27 files (24 modified + 26 new)
- 16 subsystems audited: agent core, model catalog, graph engine, cloud distillation, vault, NightBrain, computer use, knowledge fusion, SSM runtime, MLX inference, persistence, MCP bridge, feature flags, epistemos-core FFI, code editor, new UI views
- 50+ audit checklist items for Codex verification
- All changes additive, all behind feature flags, no destructive modifications
