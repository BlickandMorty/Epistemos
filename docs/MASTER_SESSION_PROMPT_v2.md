# Epistemos — Master Session Prompt v2

**Last Updated:** 2026-03-31
**Paste this at the start of EVERY new Claude Code session.**

---

## CONTEXT RESTORATION

You are continuing work on **Epistemos** — a macOS-native cognitive exoskeleton PKM. The architecture:

- **Swift 6 UI** + **Rust core** (UniFFI FFI) + **Metal compute shaders**
- **hermes-agent** Python subprocess = the REAL agent backend (orchestration, tools, cloud API)
- **MLX-Swift** for local inference (Qwen 3 4B router, nomic-embed-text, DeepSeek-R1-8B reasoner)
- **GRDB** persistence, **tantivy** FTS, **sqlite-vec** vectors
- 137K lines Swift, 94K lines Rust, 370 Swift files, 99 Rust files

**Read these files first (in order):**
1. `CLAUDE.md` — Non-negotiable constraints, file map, provider matrix
2. `docs/AGENT_PROGRESS.md` — What's done, what's next
3. `docs/BEST_OF_CLAW_AND_OPENCLAW.md` — 15 engineering patterns to implement
4. `docs/FUSED_AGENT_ENGINEERING_REPORT.md` — Root cause analysis + upgrade path

---

## CRITICAL: WHY THE AGENT FEELS DUMB (FIX THIS FIRST)

The hermes-agent loop works correctly. **Tools don't load.** Every tool has a `check_fn` gate in `hermes-agent/tools/registry.py:123-131`. When `check_fn()` returns False, the tool is **silently dropped**. The model receives zero tools → produces plain text → loop exits after 1 turn.

**Fix priority:**
1. Add debug logging to `tools/registry.py` (see BEST_OF_CLAW_AND_OPENCLAW.md §1)
2. Set `HERMES_ENV_TYPE=local` in subprocess environment
3. Pass `TAVILY_API_KEY` or `EXA_API_KEY` from Keychain
4. Ensure `~/.hermes/` directory exists
5. Verify: print tool list to stderr after agent creation

---

## HERMES-AGENT IS THE BACKEND (NOT agent_core)

- `hermes-agent/` submodule = Python subprocess for orchestration, cloud API, tools, skills
- `agent_core/` Rust crate = Living Vault, storage, security, compaction (NOT the agent loop)
- Communication: Swift ↔ hermes-agent via stdio JSON-RPC (Content-Length framing + SHM for large payloads)
- `HermesSubprocessManager.swift` manages the subprocess lifecycle
- `AgentViewModel.swift` routes user input → hermes → streams responses to UI
- `epistemos_bridge.py` = the bridge on the Python side, max_turns=30

**hermes-acp toolset** (27 tools): file ops, terminal, web search, browser, vision, skills, memory, session, code execution, delegation. ALL gated by check_fn.

---

## ANTI-DRIFT RULES

Before writing ANY code, verify:
- [ ] Am I editing hermes-agent (Python) for agent behavior, NOT agent_core (Rust)?
- [ ] Am I using `objc2-metal`, NOT `metal-rs` (deprecated)?
- [ ] Am I using UniFFI proc-macros for non-perf FFI, C FFI for Metal buffers?
- [ ] Does search pipeline have ALL FIVE stages? (tantivy + vectors + graph + RRF + reranking)
- [ ] Am I implementing real code, not stubs/TODOs?
- [ ] API keys go in macOS Keychain, NEVER UserDefaults?
- [ ] Am I streaming every token immediately, never buffering?
- [ ] Am I preserving thinking blocks + signatures in tool_use responses?
- [ ] Did I READ the file before editing it?
- [ ] Did I research/search online for relevant patterns before starting this phase?

---

## FIVE ENGINES (Research Foundation)

### Engine 1: ECS Graph (Rust + Metal)
- SVG collapses at ~400 nodes. Metal: 400,000 at 50 FPS.
- SoA layout: 5.7-10x speedup. ECS: 262K entities, 7 systems = 3ms.
- Pipeline: SoA arrays → MTLBuffer storageModeShared → zero-copy GPU physics → Metal rendering.

### Engine 2: Zero-Copy IPC (POSIX SHM)
- Shared memory: ~5M msg/sec vs ~130K UDS = 36x throughput, 1.4us latency.
- Apple Silicon: 128-byte cache lines. Pad metadata to 128B.
- Protocol: Write to shm → pass SHM_REF JSON pointer → mmap on receiver.

### Engine 3: TurboQuant+ K8V4
- Walsh-Hadamard → Asymmetric K8V4 (8-bit Keys, 4-bit Values).
- half4 vectorized butterfly on Metal. 4.6x compression, 99.1% perplexity retention.

### Engine 4: NightBrain (Temporal Memory Distillation)
- CLS theory replay. Ebbinghaus R = e^(-t/S). FSRS scheduling.
- Distillation: 371→38 tokens (11x), 96% retrieval quality.
- NSBackgroundActivityScheduler for idle/AC/thermal checks.

### Engine 5: Token Savior (AST Intelligence)
- tree-sitter + PageRank → 1,024 tokens for entire repo (~97% reduction).
- MCP tools: find_symbol, get_function_source, get_change_impact.

---

## AGENT SYSTEM ENGINEERING (from claw-code + OpenClaw)

### Patterns to Implement (Priority Order)

1. **Tool Check Fix** — Make check_fn failures visible, ensure env vars set
2. **Auto-Discovery** — Cascading config: env → keychain → config file → defaults
3. **Agent Loop Hardening** — Exponential backoff, overload/rate-limit detection, overflow recovery
4. **Skills System** — Markdown files with YAML frontmatter, hot-reloaded from `~/.epistemos/skills/`
5. **Cost Tracking** — Per-token micro-dollar tracking, invisible to user, budget alerts
6. **Error Recovery** — Retryable error classification, context overflow recovery with summary continuation
7. **Tool Loop Detection** — Sliding window hash comparison, 4 loop types (exact/semantic/output/oscillation)
8. **Context Compaction** — 4-phase: summarize old turns, keep system+recent, continuation message
9. **iMessage Integration** — Hybrid: SQLite read (chat.db) + AppleScript send, or BlueBubbles REST
10. **Cron & Heartbeat** — Background scheduler for NightBrain, memory distillation, keepalive
11. **Stream Composition** — Wrapper chains: thinking extraction → cost tracking → credential redaction → UI
12. **Session Auto-Management** — Auto-save, auto-resume, conversation branching

### iMessage Architecture
```
Read path:  ~/Library/Messages/chat.db (SQLite, read-only)
            → message + chat_message_join + chat + handle tables
            → Full Disk Access required (TCC prompt)

Send path:  AppleScript → Messages.app → send(message, to: handle)
            → com.apple.security.automation.apple-events entitlement

Alt path:   BlueBubbles REST API (localhost:1234)
            → No TCC needed, but requires BlueBubbles server running
```

---

## SEARCH ARCHITECTURE (Four Signals + RRF)

1. **tantivy FTS** — ~2x Lucene, sub-ms, NEON-accelerated
2. **Vector search** — <4ms at 100K/384d quantized (nomic-embed-text v1.5, Matryoshka 768→384)
3. **Knowledge graph** — NER → SQLite → recursive CTE. GraphRAG: 72-83% comprehensiveness
4. **Cross-encoder reranking** — ms-marco-MiniLM-L-6-v2 (22MB), top-50 → top-10
5. **RRF fusion** — `score(d) = Σ 1/(60 + rank_r(d))`. **<50ms total pipeline.**

---

## LOCAL INFERENCE ARCHITECTURE

- **MLX > llama.cpp by 20-30%.** M2 Pro: Qwen 8B Q4 = 45-58 tok/s.
- **Router:** Qwen 3 4B (3GB, pinned). Outputs intent+reasoning_depth. mlx-swift-structured for JSON.
- **Embedding:** nomic-embed-text v1.5 (0.3GB, 768→384 Matryoshka).
- **Reasoner:** DeepSeek-R1-8B (5-6GB, cold-loaded, TTL).
- **RAG > long context.** Top-12 chunks, 2-4K context.

---

## MIXED-PRECISION SOLUTIONS (Known Engineering Paths)

The naive 1.2-1.5x SIMD penalty is the **starting point**, not the ceiling:
- **Kitty**: Two-tensor decomposition → uniform 2-bit tensors, no divergence
- **T-MAC**: Lookup tables bypass dequantization entirely (6.6x over llama.cpp on M2-Ultra)
- **BitDecoding**: Software pipeline hides dequant behind matrix execution (3-9x over FP16)
- **RotorQuant**: Fused Metal kernel, 9-31x on M4 (Clifford rotors, 160x arithmetic reduction)
- **mlx-optiq**: 47% slower → 2% penalty after incremental optimization
- **OpenEvolve**: Already optimized Metal attention kernels (12.5% decode improvement)

---

## COGNITIVE COMPUTING CAPABILITIES

1. **Contextual Shadows** — Cross-app capture via ScreenCaptureKit + Vision OCR
2. **Edit Telemetry** — Track user editing patterns for predictive assistance
3. **Temporal Knowledge Graph** — Time-weighted edges, Ebbinghaus decay
4. **Night Brain** — Idle-time memory consolidation, distillation, FSRS scheduling
5. **Spatial Graph Canvas** — Metal-rendered force-directed graph, semantic zoom
6. **Living Vault** — 4-op classifier (ADD/UPDATE/DELETE/NOOP), git-as-journal

---

## WHAT'S BUILT (DO NOT REBUILD)

**MCP Bridge:** EpistemosMCPServer (vault tools + skill discovery), HermesMCPClient, routeBridgeLine(), cron keepalive, TranscriptRepair, ContextBudgetManager.

**Safety (11 components):** ToolLoopDetector, ContextBudgetManager, TranscriptRepair, ExecutionCheckpointManager, AgentDepthLimiter, MMRReranker, CredentialRedactor, CostTracker, ContextCompiler, MemoryThreatScanner, ShadowGitCheckpoint.

**FFI Hardening:** NaN/Inf sanitization, catch_unwind (60+ sites).

**Agent System:** 4 sprints complete (Agent-1 through Agent-4), 5 Omega sprints complete, 449 Rust tests passing, Swift building clean.

---

## WHAT'S NOT BUILT (Remaining Work)

### Tier 1: Ship-Blocking (Do First)
- [ ] Fix tool check_fn gates (the "dumb chatbot" root cause)
- [ ] Auto-discovery for API keys and tool dependencies
- [ ] Agent loop hardening (backoff, overflow recovery)
- [ ] Skills system (markdown-based, hot-reload)

### Tier 2: Core Agent Features
- [ ] iMessage channel integration
- [ ] Cron & heartbeat (NightBrain background tasks)
- [ ] Cost tracking (invisible micro-dollar)
- [ ] Stream composition chains
- [ ] Tool loop detection wiring to hermes bridge
- [ ] MCP tool bundling (auto-discover MCP servers, merge tools into agent)
- [ ] Auth profile rotation (multi-key failover with cooldown)
- [ ] Tool result truncation (prevent context overflow from large tool outputs)

### Tier 3: Polish & Release
- [ ] NightBrain Heartbeat Memory Distillation (Item 20)
- [ ] Sub-Agent Context Scoping (Item 21)
- [ ] Release preflight, DMG packaging, legal docs
- [ ] Fresh-machine verification

---

## DISTRIBUTION

**Method:** Developer ID-signed DMG (NOT Mac App Store).
**Why:** 6 hardened runtime exceptions required (JIT, unsigned memory, dylib loading, AX access, Apple Events, terminal execution).
**Stack:** Lemon Squeezy + Sparkle 2 + DMG. Direct download.

---

## PERFORMANCE TARGETS

| Operation | Target |
|-----------|--------|
| Vector search (1M) | <5ms |
| Ingest | <1ms |
| Full hybrid pipeline | <50ms |
| Rotation swap | <1us |
| MLX inference | 45-58 tok/s |
| IPC latency | <1.4us (SHM) |

---

## KEY MATH

- ButterflyQuant: O(d log d) rotation, (d log d)/2 params
- PM-KVQ Right Shift: `floor((2^{2b} - 2^b + 1)(X_{2b} + 2^{b-1})) >> 3b`
- RRF: `score(d) = Σ 1/(60 + rank_r(d))`
- Ebbinghaus: `R = e^(-t/S)`, S increments on recall
- MMR Estimator: `<y, x̃> = <y, Q⁻¹(Q(x))> + ||r||₂ · <y, QJL(r)>`

---

## BEHAVIORAL RULES FOR EVERY SESSION

1. **Always read files before editing.** No blind edits.
2. **Always research/search online between phases.** Gain insight about what you're implementing.
3. **Run verification after each task.** Don't batch.
4. **Update AGENT_PROGRESS.md** after completing each sprint item.
5. **Test:** `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify`
6. **Rust test:** `cargo test --manifest-path agent_core/Cargo.toml`

---

## ARCHITECTURE MAP

```
Epistemos.app (Swift 6 + Rust/UniFFI + Metal)
│
├── AgentViewModel.swift           ← Central orchestration
│   ├── HermesSubprocessManager    ← Manages hermes-agent Python subprocess
│   ├── EpistemosMCPServer         ← Vault tools + skill discovery + HTTP transport
│   ├── HermesMCPClient            ← Swift→Hermes bidirectional MCP
│   ├── Safety/                    ← 11 safety components
│   └── routeBridgeLine()          ← JSON-RPC dispatch + threat scan + redact + U-curve
│
├── hermes-agent/ (Python subprocess — THE REAL BACKEND)
│   ├── run_agent.py               ← AIAgent core loop (while < max_iterations)
│   ├── epistemos_bridge.py        ← stdio JSON-RPC bridge (max_turns=30)
│   ├── tools/registry.py          ← Tool registration + check_fn gates (THE BUG)
│   ├── toolsets.py                ← hermes-acp: 27 tools
│   └── cron/scheduler.py          ← Background scheduler
│
├── agent_core/ (Rust — storage, security, compaction)
│   ├── src/storage/vault.rs       ← Living Vault (diff, git, classifier, decay)
│   ├── src/security.rs            ← Credential scanning, threat detection
│   ├── src/compaction.rs          ← 4-phase context compaction
│   └── src/prompt_caching.rs      ← Cache control breakpoints
│
├── epistemos-core/ (Rust — Instant Recall engine)
│   └── src/instant_recall/        ← Binary HNSW, quantization, segment MVCC
│
├── Engine/ (Swift — MLX inference)
│   └── MLXInferenceService.swift  ← Qwen router, embedding, reasoning
│
├── Graph/ (Swift + Metal)
│   ├── MetalGraphView.swift       ← Force-directed GPU rendering
│   └── FilterEngine.swift         ← Graph query DSL
│
└── Views/ (SwiftUI)
    ├── Notes/ProseEditorView.swift ← Note editor
    ├── AgentSessionPanel.swift     ← Agent chat UI
    └── Graph/HologramSearchSidebar.swift
```

---

## SOURCE DOCUMENTS INDEX

| Document | Path | Topic |
|---|---|---|
| Project Rules | `CLAUDE.md` | Non-negotiable constraints, file map |
| Agent Progress | `docs/AGENT_PROGRESS.md` | Sprint status, verification |
| Best of Claw+OpenClaw | `docs/BEST_OF_CLAW_AND_OPENCLAW.md` | 15 engineering patterns |
| Fused Report | `docs/FUSED_AGENT_ENGINEERING_REPORT.md` | Root cause + upgrade path |
| Master Build Spec | `docs/EPISTEMOS_FUSED_v3.md` | Complete 8-phase spec |
| Hermes Integration | `docs/HERMES_INTEGRATION_RESEARCH.md` | 40-file study |
| Agent Architecture | `docs/agent-system/AGENT_ARCHITECTURE.md` | Provider matrix, tools |
| Operator Manual | `docs/agent-system/OPERATOR_MANUAL.md` | 3-prompt workflow |
| Distribution | `docs/plans/2026-03-28-distribution-decision-and-compliance-report.md` | DMG, entitlements |
| Release Handoff | `docs/handoffs/2026-03-28-final-claude-release-master-handoff.md` | What landed |

---

## NOW

1. Read `CLAUDE.md` and `docs/AGENT_PROGRESS.md`
2. Read `docs/BEST_OF_CLAW_AND_OPENCLAW.md`
3. Fix the tool check_fn issue (Tier 1, Item 1)
4. Then work down the tier list
