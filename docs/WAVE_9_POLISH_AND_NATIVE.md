# Wave 9 — Polish, Wire-up, Apple-Native

Synthesis of 5 parallel research streams (project plan audit + Downloads
corpus across optimization, UI wiring, Apple-native, PKM/memory).
Authored 2026-04-26 after W8.7 (Halo vault bootstrap) closure.

## Verdict

V1 is **shippable** conditional on three small ship-gates totaling ~7 hr:
mas-sandbox spot-check, reliability fresh baseline, TestFlight metadata.
The biggest remaining V1-feel gap is not architectural — it is **wiring
existing backend logic to user-facing surfaces** plus a small set of
Apple-native quick wins. Wave 9 closes those gaps without any
architectural rewrites.

## Tier 1 — XS, ship immediately (~6 hr cumulative)

| ID    | Item                                       | Source / status                       |
| ----- | ------------------------------------------ | ------------------------------------- |
| W9.1  | AVSpeechSynthesizer read-aloud             | Apple-native gap; 8 frameworks integrated, this one missing entirely |
| W9.2  | ~~GRDB pragmas + OSSignposter scaffold~~ ✅ already shipped | `Epistemos/Sync/SearchIndexService.swift:204` (canonical W2.3 pragma block) + `Epistemos/Telemetry/Sig.swift` (6-category OSSignposter facade) |
| W9.3  | Reasoning Trajectory Badge                 | `agent_core/src/reasoning_metrics.rs` already classifies Efficient/Hesitating/Stuck — no UI |
| W9.4  | Empty-state messaging                      | HomeView / ChatView / SessionListView blank on cold open |
| W9.5  | Streaming token-count badge                | `Views/Chat` already streams; cost transparency |

## Tier 2 — S, ship in the next 1–2 sessions

| ID    | Item                                       | Source / status                       |
| ----- | ------------------------------------------ | ------------------------------------- |
| W9.6  | Cost dashboard + per-session budget gate   | `agent_core/src/session_insights.rs` tracks `estimated_cost_usd`; never surfaced |
| W9.7  | Vault sidebar selector                     | LIVING_VAULT_ARCHITECTURE Vault-Per-Model registry — no switcher UI |
| W9.8  | Approval modal (PausedForApproval surface) | `SessionState::PausedForApproval { tool_name, args_json, deadline_secs }` exists; no view |
| W9.9  | Vision OCR clipboard pipeline              | `VNRecognizeTextRequest` integrated for screenshots; extend to clipboard |
| W9.10 | TurboQuant KV cache compression            | Google ICLR 2026; 6× memory, +25–32 % throughput, validated on M2 16 GB |

## Tier 3 — M, 2–3 weeks each (V1.5 candidates)

| ID    | Item                                       | Why                                   |
| ----- | ------------------------------------------ | ------------------------------------- |
| W9.11 | Create ML personalized embeddings          | 1 ms paragraph embeds vs 100 ms current; trains nightly via Night Brain |
| W9.12 | Orphan Knowledge Rediscovery               | Night Brain surfaces forgotten-but-relevant notes; uses existing HNSW + GRDB |
| W9.13 | Daily Notes + FSRS spaced repetition       | Logseq/Roam parity + modern FSRS (Ye SIGKDD 2022) replacing Leitner/SM-2 |
| W9.14 | Block References + Transclusion            | Logseq/Roam parity; copy-on-write embeds with edit propagation |
| W9.15 | Static compile-time view routing macro     | EPISTEMOS_DETERMINISTIC_PERF_PLAN Sprint 2 — eliminates AnyView/AttributeGraph diff cost |

## Tier 4 — V1.5+ (deferred)

| ID    | Item                                       |
| ----- | ------------------------------------------ |
| W9.16 | Graph drift / belief evolution timeline    |
| W9.17 | Working-memory window + activity context   |
| W9.18 | Dependency-aware query invalidation        |
| W9.19 | Slotmap + structure-of-arrays entity store |
| W9.20 | phf perfect-hash MCP / tool registries     |

## Tier 5 — Novel coding patterns (deep-research deep dive)

Surfaced by the deep-nest research pass on the Downloads corpus
(`arc8.txt`, `sw.txt`, `Metal Mamba 2 Research Prompt.txt`,
`MLX Constrained Decoding Research.md`, `EPISTEMOS_HERMES_MANIFESTO.md`,
`Epistemos Graph Engine Optimal Performance Roadmap.md`,
`vector quant.md`). These are 2026 production techniques distilled
from the user's own corpus, not generic best practices — each is a
genuinely rare pattern.

| ID    | Pattern                                                          | Source quote location                                                  | Effort | Wins                                                                    |
| ----- | ---------------------------------------------------------------- | ---------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------ |
| W9.21 | **Honest FFI** — `Arc::into_raw` + `~Copyable` wrappers          | `arc8.txt`                                                             | M      | Eliminates UniFFI HandleMap mutex; zero-cost identity mapping            |
| W9.22 | **Typestate Islands** — `~Copyable` for MLX/subprocess lifecycles | `arc8.txt`                                                             | M      | Compile-time prevention of use-after-free on MLX sessions + Hermes proc |
| W9.23 | **Bit-packed circuit breaker** — AtomicU64 + popcnt              | `arc8.txt`                                                             | S      | Lock-free, zero-alloc resilience; 8 bytes per breaker; cache-line padded |
| W9.24 | **Metal zero-copy graph buffers** — `makeBuffer(bytesNoCopy:)`   | `sw.txt`                                                               | M      | Page-aligned Rust alloc → Metal binding; 120 Hz on 10 K-node graph       |
| W9.25 | **Grammar-constrained logit masking** — MLXLMCommon LogitProcessor | `MLX Constrained Decoding Research.md`                                 | L      | 100 % JSON / tool-call validity from local Qwen 7-8 B; no retry loops    |
| W9.26 | **B-tree text rope** — `crop` crate + UTF-16 metrics             | `sw.txt`                                                               | L      | O(log n) edits in code editor; no lag at 100 KB+ files                   |
| W9.27 | **Append-only OpLog + replay** — event-sourced graph             | `Epistemos_ Audit, Research, Design.md`                                | M      | Time-machine debugging; perfect undo; multi-user audit trail             |
| W9.28 | **Blelloch scan in Metal** — Mamba-2 prefill parallelism         | `Metal Mamba 2 Research Prompt.txt`                                    | L      | 5 s prefill on 100 K tokens; unlocks "vault as memory" vision            |
| W9.29 | **Thermal-aware breaker throttling** — global supervisor         | `arc8.txt`                                                             | S      | Pre-empt thermal hardware throttle by tightening breaker thresholds     |
| W9.30 | **KIVI per-channel/per-token KV quantisation**                   | `vector quant.md`                                                      | M      | 60 % KV memory cut; 2-bit Key + per-token Value asymmetric quant         |

### Top 3 from Tier 5 to ship first
- **W9.21 Honest FFI** — biggest concurrency bottleneck removed; foundation for everything else
- **W9.25 Grammar-constrained logits** — makes local-model tool-calling reliable enough to ship
- **W9.28 Blelloch scan** — required to actually cash in the Mamba-2 vault vision

## Pre-TestFlight ship gates (orthogonal to Wave 9)

These three close out V1 release-readiness; track in `KNOWN_ISSUES_REGISTER.md`:

- **P0-2** Reliability fresh baseline (re-run 5-gate suite post-Phase-R closure) — ~2 hr
- **P0-4** mas-sandbox feature-gating spot-check (`agent_core/src/tools/registry.rs` + `omega-mcp/src/pty.rs`) — ~30 min
- **P0-3** TestFlight submission metadata (screenshots, App Review notes draft already in `MAS_APP_REVIEW_NOTES.md`) — ~4 hr

## Wave 10 + 11 — DRAFT, awaiting further research

> **STATUS — 2026-04-26:** Sections below are DRAFT. The user has more
> research arriving. Doc 1 (`Epistemos_ AI Cognitive Partner Analysis.txt`)
> and Doc 2 (`deep-research-report (2).md`) have been integrated as
> `[Doc1]` / `[Doc2]` annotations. Do NOT begin Wave 10/11 implementation
> beyond the wire-ups already shipped (W10.4) until the next research
> drop closes the open questions flagged below.

### Doc 2 plan-corrections (BRITTLE ITEMS — must redesign before code)

Four master-plan items are **technically brittle** per the deep-research
review and must be redesigned before any implementation:

| Master-plan item                          | Brittleness                                                    | Corrected pattern                                                                       |
| ----------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **W10.10 Model Metabolism / NightBrain** as adapter retraining | Apple Foundation Models adapters are version-locked to base model; "daily user-personalized retraining" is a brittle operational dependency, not a clean user feature | Metabolise into **structured state artifacts** — salience weights, prompt deltas, behavioral profiles, ontology corrections, retrieval priors. Keep adapter training rare, optional, and domain-specific. **"Belief drift as data, not weights."** |
| **W10.6 JIT Context Injection** mid-generation | Apple Foundation Models sessions are stateful, transcript-based, 4096-token context; mid-stream prompt surgery is the "movie version" of context engineering | **State compaction + tool-gated retrieval**. Carry forward essential instructions, preserve a few transcript entries, summarize the rest, ground the model in external sources of truth via tool-calling — NOT improvisational hot-swapping while a model is already generating. |
| **W10.2 Organic Decay** as vector quantisation | Lowering vector precision changes storage characteristics; it does **not** model cognition | Keep raw artifacts in **cold storage**, maintain compressed structured summaries, decay **retrieval priors** over time, rehydrate the full raw thought only when current task / concept / emotional trajectory makes it relevant. |
| **W10.12 `[Entity].epistemos.json`** as markdown replacement | "Abandon markdown entirely" is too extreme — Obsidian/Logseq users value portability, inspectability, longevity | **Dual representation**: human-readable Markdown source layer **PLUS** machine-readable sidecar layer. Notes stay legible/exportable; Epistemos *adds* sidecars (ontology, state files, salience maps, graph metadata). The moat is dual representation without user pain — NOT "no markdown." |

### Doc 1 implementation notes (Mirror-SD specifics for W10.5 Hybrid Brain)

The master-plan Phase 5 (Hybrid Brain ANE + GPU) needs concrete
implementation guardrails per Doc 1:

- **Draft model on ANE**: Qwen2.5-0.5B or Gemma 4 variants; ~2 W power
  vs ~20 W when routed through MLX/GPU path
- **Bypass CoreML's opaque scheduler** via Orion-style private API
  pattern (Objective-C runtime control over the neural accelerator)
- **17 undocumented ANE constraints** — concatenation causes silent
  compiler failure; BLOBFILE weights need 64-byte offset from chunk
  header or numerical corruption is silent
- **119-compilation hard cap per process** — use deferred compilation
  pipelines
- **fp16 overflow prevention**: rigid activation clamping required
- **Mirror-SD pipeline**: ANE speculates forward continuations across
  unified memory; MLX-backed 3B target on GPU validates tokens
  concurrently without inter-device contention

## Wave 11 — Missing moats (Doc 2 — net-new)

Three architectural moats the master plan barely touches but which
are explicitly aligned with current Apple platform direction. All
three need design before code.

| ID    | Item                                       | Effort | Why it matters                                      |
| ----- | ------------------------------------------ | ------ | --------------------------------------------------- |
| W11.1 | **App Intents + Spotlight first-class**    | M      | macOS 26 Spotlight surfaces App Intents directly. "Capture brain dump", "attach thought to current chat", "recall active thesis", "open raw-thought sandbox", "delegate to agent" — all should be Spotlight / Shortcuts / Siri reachable. "Stops being an app I open and starts being part of how the Mac thinks with me." Biggest unexplored Apple-native moat. |
| W11.2 | **Trust architecture** (permission UX)     | M      | Accessibility, Screen Recording, Microphone, Speech Recognition all carry user anxiety. Need: clear local-vs-cloud badges, explicit permission rationales, reversible toggles, visible audit history of "what acted and why", "manual mode" that explains intended actions before executing. **Permissions are product design, not plumbing.** |
| W11.3 | **Evaluation lab**                         | M      | Xcode Playgrounds + measurable tests for ontology extraction quality, note-to-concept nesting, session summary faithfulness, depth marker stability, memory retrieval relevance, permission UX success. **The moat is reliable intelligence under stress, not just clever architecture.** |
| W11.4 | **Auto / Manual Mode Machine + Rationale Layer** (user request 2026-04-26) | S | Every decision the app makes on the user's behalf — system-prompt engineering, model-vault routing, tool selection, voice persona, ontology classification, ambient-retrieval toggling — has BOTH an Auto mode (the app decides + acts) AND a Manual mode (the app proposes + waits for confirmation). **A rationale string is rendered in Settings AND inline wherever a decision is proposed**, explaining what was chosen, why, and what the alternatives were. Closes the Doc 2 trust gap from the *user's* angle: "make it feel magical rather than scary by making the reasoning visible." Plumbs through as a per-decision `DecisionMode = .auto / .manualWithRationale` enum so any new feature inherits the contract by default. |

### W11.4 design notes — Auto / Manual Mode Machine

The mode applies **at every decision boundary** the app exposes:

| Surface                     | Auto mode                                                | Manual mode (proposes with rationale)                     |
| --------------------------- | -------------------------------------------------------- | --------------------------------------------------------- |
| System-prompt engineering   | Auto-builds from harness + capability manifest + model profile | Shows assembled prompt + diff vs prior turn; user accepts |
| Model-vault routing         | Auto picks active vault per current model profile        | Shows ranked vault candidates + match score; user picks   |
| Tool selection per turn     | Auto-selects tools from tier + intent classification     | Shows allowlist + reasoning; user toggles                 |
| Voice persona (W9.1.b)      | Auto-picks Premium-quality voice per model               | Shows voice options grouped by quality; user assigns      |
| Ontology classification (W10.1) | Classifier writes `{parent_domain, child_concept}` directly | Shows top-3 classifications + confidence; user picks      |
| Ambient-retrieval toggle (W10.15) | Auto-enables on creative-task heuristic            | Always-explicit toggle in chat header                     |

**Rationale rendering contract**: every Settings row exposing a Mode
toggle shows a 1-line "Why?" link that expands to a 2-3 sentence
explanation of what Auto would do, what Manual adds, and which
default Apple recommends for similar capabilities. Inline rationales
(in chat, in note editor, in agent inspector) follow the same
template so the language stays consistent across surfaces.

**Persistence**: the Mode is per-decision (not a global flag) so the
user can accept Auto for low-stakes decisions (voice picking, vault
routing) and demand Manual for high-stakes ones (system-prompt
engineering, tool execution, ambient retrieval).

### Wave 11 — top 3 to ship first (per Doc 2 strategic frame)

1. **W11.1 App Intents catalogue** — start with 5 intents: `CaptureBrainDump`, `AttachThoughtToContext`, `RecallActiveThesis`, `OpenRawThoughtSandbox`, `DelegateToAgent`. Each registered with Shortcuts; each surfaceable from Spotlight on macOS 26. Lowest implementation friction, biggest Apple-platform alignment win.
2. **W11.2 Permission rationale + audit log** — every Accessibility / ScreenCaptureKit / Speech / Bash invocation writes a row to a user-readable audit log. Settings panel shows the log. "Manual mode" toggle gates destructive tool calls behind a confirmation that previews the intended action. Closes the master-plan Trust gap.
3. **W11.3 Foundation-Models eval harness** — Xcode Playground that exercises the W10.1 Ontological Classifier across a 50-note seed corpus and scores `{parent_domain, child_concept}` accuracy against a hand-labeled ground truth. Becomes the gate for advancing W10.1 from research → ship.

## Doc 2 architectural verdict — the four-layer bet

Per Doc 2, the canonical Epistemos architecture should land as four
asymmetric layers. **This frame supersedes any earlier "everything
flows through one model" architecture in the master plan**:

1. **On-device model layer** — Foundation Models for extraction,
   summarisation, tagging, structured generation. NOT a philosopher
   king. Use it where Apple says it is strong.
2. **Memory layer** — **dual format**. Human-readable notes +
   sidecar state (ontology, depth markers, emotional anchors,
   salience weights, session summaries, conversation-state files).
   Raw thoughts in **quarantined archive** by default; ambient
   retrieval is an **explicit toggleable mode**, not the default
   runtime.
3. **Agent layer** — **asymmetrical**. Hermes does reasoning + tool
   use + scheduling + skill use + multi-agent delegation. Epistemos
   owns **memory truth, schema truth, UI truth, OS truth**. Prevents
   Epistemos from becoming a thin Hermes skin.
4. **OS layer** — **radically native**. App Intents, Spotlight,
   Shortcuts, Accessibility, ScreenCaptureKit, Speech all as
   **product surfaces**, not hidden infrastructure.

**Replace "retrain the model every night" with "belief drift as
data, not weights"** — store thesis changes, persistent corrections,
preference priors, salience scores, rejected-agent patterns. If
adapters are ever used: narrow stable domains only, not as the daily
memory mechanism.

## Wave 10 — Cognitive Architecture (master-plan integration)

The user-authored master plan (`/Users/jojo/master_plan_doc.md`) defines
16 phases of architectural moats positioning Epistemos as a "biological
cognitive exoskeleton" rather than a flat PKM. Each row below shows the
phase concept, what already exists in the repo (verified by file grep),
what is net-new, and the recommended landing wave. **Every phase that
is "NEW" must enter the canonical Deep Research Protocol per the
master-plan epilogue before code generation** — exhaustive
potentiality coverage, structural verification against macOS / unified-
memory / FFI-latency thresholds, and deliberation on alternatives.

| Phase | Concept                                                    | Existing in repo                                              | Status | Recommended landing |
| ----- | ---------------------------------------------------------- | ------------------------------------------------------------- | ------ | ------------------- |
| 1     | Intelligent Semantic Ontology (parent_domain / child_concept JSON-schema-bounded extractor via Apple Foundation Model) | `Epistemos/Graph/EntityExtractor.swift` (naive string extractor) | Replace | **W10.1** — high-priority moat |
| 2     | Organic Decay Engine (Ebbinghaus pipeline; precision right-shift 16 → 8 → 2-bit) | `epistemos-core/src/storage/*` + Halo HNSW already quantises  | Extend **[Doc2-AMENDED]** | **W10.2** — fold into Night Brain. Corrected mechanism: cold-storage raw + structured summaries + decaying retrieval priors. Quantisation is storage, not cognition. |
| 3     | Omni-CLI Native Bridge (PTY daemon spawning claude-code / codex / hermes invisibly + typed CLIEvent across UniFFI) | `omega-mcp/src/pty.rs` exists; user-facing wrapper missing    | New    | **W10.3** — Pro-profile only |
| 4     | Full Harness Wiring (BootstrapPacketBuilder injects 800-token harness as first system msg) | `Epistemos/Harness/BootstrapPacketBuilder.swift` exists; not wired into AgentViewModel call site | Wire-up | **W10.4** — XS, immediate |
| 5     | Hybrid-Brain (AFM 3B subconscious + cloud Hermes executive sharing unified memory) | `AppleIntelligenceService.swift` + Rust agent_core both exist; routing logic absent | New    | **W10.5** — needs router design |
| 6     | JIT Context Injection (intercept `<thinking>`; AFM expands decayed memory mid-stream) | `agent_core/src/agent_loop.rs` has thinking preservation; mid-stream injection absent | New **[Doc2-AMENDED]** | **W10.6** — corrected: state compaction + tool-gated retrieval, NOT mid-stream prompt surgery. Foundation Models 4096-token transcript-based — robust pattern is grounding via tool-calling. |
| 7     | Hermes as Chief of Staff (registers claude-code / kimi as MCP tools; swarm coordination) | `omega-mcp/src/dispatcher.rs` + `Epistemos/Omega/MCPBridge.swift` exist | Extend | **W10.7** — Pro-profile only |
| 8     | Cognitive Depth Markers (L1 Surface / L2 Synthesized / L3 Core Belief enum on every note + meta-analysis edges) | Not implemented (grep returned 0 hits)                        | New    | **W10.8** — schema migration |
| 9     | High-Performance Session Distillation (AFM 3B with strict JSON schema for `decisions_made`, `unresolved_friction`, `active_themes`) | Naive text summariser exists; schema-bounded version missing  | Replace | **W10.9** — folds with W9.3 trajectory work |
| 10    | Model Metabolism / Overnight Consolidation (3 AM cron audits day's prompts; emits `salience_weights.json` per model vault) | `NightBrainService.swift` exists; metabolism logic absent     | Extend **[Doc2-AMENDED]** | **W10.10** — corrected: NOT adapter retraining (Apple FM adapters are version-locked to base model). Output **structured state artifacts**: salience weights, prompt deltas, behavioral profiles, ontology corrections, retrieval priors. Belief drift as data, not weights. |
| 11    | Omni-Contextual Brain Dumps (global voice anchor button bound to chat_id / note_id with Metal waveform overlay) | `AudioTranscriber.swift` + `SDPage.brainDump` page kind exist; global UI button absent | Wire-up | **W10.11** — XS UI gap |
| 12    | Cognitive Data Structures (`[Entity].epistemos.json` sidecar files with `interpretation_directive`) — **NEVER apply to code files** | Not implemented (grep returned 0 hits)                        | New **[Doc2-AMENDED]** | **W10.12** — corrected: dual representation. Keep human-readable Markdown source layer; sidecars are **additive** state, NOT a replacement. The moat is dual representation without user pain. |
| 13    | Unstructured Data Audit ETL (background Rust crawler converts loose `.md` / PDF → structured sidecar via AFM 3B; **hardcoded exclusion list for `.git`, `.build`, all programming languages**) | Vault crawl exists in `ShadowVaultBootstrapper`; structuring pass absent | New    | **W10.13** — extends W8.7 |
| 14    | Intake Valve (synchronous AFM 3B intercepts pasted / dictated text before save; emits clean sidecar) | `TextCapturePipeline.swift` exists; AFM intercept missing     | New    | **W10.14** — depends on W10.1 + W10.12 |
| 15    | Deterministic Core vs Ambient Retrieval (`/RawThoughtsArchive` quarantine; ambient-retrieval toggle for messy data) | RawThoughts V0 + Contextual Shadows V0 already shipped; quarantine + toggle missing | Extend | **W10.15** — folds with W9.12 (Orphan Knowledge) |
| 16    | Structured Conversation State (`conversation_state.epistemos.json` with `Active Thesis`, `Resolved Nodes`, `Emotional Trajectory`, semantic vector compaction) | Linear chat log; structured state absent                      | New    | **W10.16** — replaces compaction.rs naive truncation |

### Wave 10 — top 3 to ship first
- **W10.4 BootstrapPacket wire-up** (XS) — the harness packet already exists; just needs the AgentViewModel init call site. Free win.
- **W10.11 Global brain-dump button** (S) — `AudioTranscriber` + `SDPage.brainDump` already exist; needs the global voice-anchor UI bound to the active context (chat_id / note_id).
- **W10.1 Ontological Classifier** (M) — replaces the naive `EntityExtractor.swift` with an Apple-Foundation-Model-backed classifier emitting `{parent_domain, child_concept}` per the master plan. The single highest-leverage cognitive moat per the user's analysis ("phenomenology nests under neuroscience, not under good/free").

### Wave 10 — explicit safety constraints (from master plan)
- **Code-file exclusion rule**: `.epistemos.json` sidecar generation MUST never touch `.swift`, `.rs`, `.py`, `.json`, `.toml`, `.metal`, etc. Hardcode the exclusion list before shipping.
- **ETL exclusion list**: vault crawler must skip `.git`, `.build`, `target/`, `node_modules/`, `DerivedData/`, all programming languages.
- **Mamba history**: master plan explicitly notes prior Mamba/SSM attempts failed; Phase 2 stays on standard Transformers. Tier 5 W9.28 (Blelloch scan) remains a research item, NOT a hard plan dependency.
- **Hermes locality**: per master plan Prompt 6, the user's 16 GB Mac cannot run the largest Hermes locally; cloud Hermes is the executive in the Hybrid-Brain split (Phase 5).

## Sources

- `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `docs/AGENT_PROGRESS.md`, `docs/KNOWN_ISSUES_REGISTER.md`
- `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`, `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md`
- `~/Downloads/opt/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` + `Epistemos Performance Optimization Roadmap.txt`
- `~/Downloads/new features/Cognitive Computing Capabilities for a Native macOS Personal Knowledge System.md`
- `~/Downloads/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md`
- `~/Downloads/cap5_night_brain.md` (orphan + FSRS sources)
- Cross-corpus grep against `Epistemos/` source for "exists in code, no UI" gaps
