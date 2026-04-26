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

## Wave 12 — Implementation Contract (compass artifact integration, DRAFT)

The compass artifact (`/Users/jojo/Downloads/compass_artifact_wf-0d84391a-...md`,
946 lines) is the most technically grounded research yet — version-pinned
crates, verified APIs, concrete reality-checks against shipping releases as of
**2026-04-26** (Apple Foundation Models, MLX-Swift 0.31.x, mlx-swift-lm 3.31.x,
UniFFI 0.29.5, Swift 6.2 / Xcode 26, macOS 26.4 "Tahoe" RC). It supersedes
ambiguity in earlier docs.

### Compass strategic verdict — ship-first set

> "Ship phases **1, 2, 8, 12, and one of {3 or 5}** first. They produce
> the highest demo-to-effort ratio, feed every other phase's data
> substrate, and align directly with Apple Design Award judging
> patterns (native API depth, distinctive viewpoint, on-device privacy)."

| Priority | Phase | Type | ADA category fit |
| -------- | ----- | ---- | ---------------- |
| 1 | **Phase 8** — live dynamic Metal graph (sqlite-vec + petgraph) | Demo + Infra | **Innovation / Visuals & Graphics** |
| 2 | **Phase 2** — organic decay (FSRS-6 + tiered quantisation cascade) | Demo + Infra | Innovation |
| 3 | **Phase 1** — `@Generable` ontology classifier | Infra (powers everything) | Innovation |
| 4 | **Phase 12** — JSON sidecar files (`vim`-able, dual representation) | Infra (trust moat) | Inclusivity / Innovation |
| 5 | **Phase 5** — hybrid brain (AFM 3B + MLX Qwen3 0.6B subconscious) | Infra | Innovation |

**Defer to v1.5**: Phase 10 NightBrain LoRA (highest infra moat,
nearly impossible to demo live), Phase 11 voice (commodity), Phase 16
stenographer (overlaps with Granola).
**Treat Phase 6 as a feasibility fence**: pause-mid-stream-and-inject
does not exist on any cloud API and **must** be replaced with
tool-use retrieval.

### Compass reality-checks — CRITICAL FIXES TO EXISTING WAVES

These are platform truths that contradict assumptions earlier in the
plan. The fixes are not yet shipped (per the user's "don't finalize"
instruction) but are tagged `[Compass-FIX-NEEDED]` so the next session
can land them as code.

| ID | Existing item | Compass reality | Action |
| -- | ------------- | --------------- | ------ |
| W10.4-FIX | BootstrapPacket wire-up (committed 87c5b9bc) | "Your 800-token bootstrap is BELOW the cache minimum on every major provider. Anthropic minimums: Sonnet 4.5/3.7 = **1,024**, Sonnet 4.6 = **2,048**, Opus 4.5/4.6/4.7 + Haiku 4.5 = **4,096**." | **Pad packet to ≥1,100 tokens of stable content**; verify cache hits via `cache_creation_input_tokens` / `cache_read_input_tokens` telemetry. **Without padding the W10.4 wire-up provides ZERO caching benefit.** |
| W10.4-FIX-b | TTL on `cache_control` markers | "Anthropic silently changed default ephemeral TTL from 1 h to 5 min in March 2026 — always pass `ttl` explicitly." | Pass `ttl: "1h"` explicitly on cache markers. |
| W10.4-FIX-c | Assistant prefilling for JSON shaping | "Assistant prefilling is REMOVED on Claude Opus 4.6/4.7, Sonnet 4.6, Mythos Preview — returns 400." | Switch to `output_config.format` for JSON shaping. |
| W10.10-FIX | Night Brain 3 AM cron via `BGTaskScheduler` | "**`BGTaskScheduler` does NOT exist on macOS** (`API_UNAVAILABLE(macos)` in SDK headers). `NSBackgroundActivityScheduler` only runs while app is alive — useless for 3 AM wake if user quits the app." | Use `SMAppService.agent(plistName:)` + launchd `StartCalendarInterval`. **Only mechanism that wakes from sleep + coalesces missed runs.** Plist must be Team-ID-signed or `SMAppService.register()` fails silently. |
| W10.10-FIX-b | M-series battery deferral | "M-series laptop on battery + lid closed may defer 3 AM jobs by hours" | Fallback fire on next launch if `last_consolidation > 36 h`. |
| W10.5-FIX | "Hybrid Brain" ANE + MLX speculation | "**MLX does NOT use ANE** (MLX is GPU-only on M2). AFM's daemon does." Doc 1's Mirror-SD is technically correct but MLX itself runs on GPU; ANE-based draft model needs Core ML, not MLX. | Update W10.5 to reflect MLX = GPU-only. For ANE-based draft model: Core ML routes (ANEMLL, john-rocky/CoreML-LLM achieve 47–62 tok/s for 1B at ~2 W vs ~20 W GPU). |
| W10.5-FIX-b | Local subconscious model choice | "Recommendation: **Qwen3 0.6B 4-bit, NOT SmolLM2 1.7B**. RAM @ 4k ctx = ~600 MB vs ~1.4 GB. Top pick for subconscious on M2 Pro 18 GB." | Pin `mlx-community/Qwen3-0.6B-4bit` as the canonical local subconscious. |
| W10.6-FIX | Mid-generation prompt surgery | (Already amended by Doc 2.) Compass adds: "Read Claude's `thinking_delta` events YES (summarized; **observe only, cannot steer**); raw thinking trace requires Anthropic sales contact. **Inject context mid-thought via tool use** is the only real mechanism. Cancel + re-call breaks thinking-block signatures (Claude rejects)." | Update W10.6 to be tool-use-only, with `epistemos_retrieve` as cached part of system+tools prefix; interleaved thinking auto-on for Sonnet/Opus 4.6+. |
| W11.x-FIX | UniFFI + Swift 6.2 / Xcode 26 | "**Issue #2818 open since Feb 11, 2026, no fix shipped.** With `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` (Xcode 26 default), uniffi-bindgen generated Swift fails to compile because `deinit` cannot be MainActor-isolated." | Pin `uniffi = "0.29.5"` (NOT 0.30 / 0.31 — method-checksum changes). Place generated bindings in **separate SwiftPM target with `defaultIsolation(nil)`** (nonisolated). |
| W11.x-FIX-b | Swift `Task.cancel()` cancelling Rust futures | "Does not — UniFFI issue #2771, open. Without explicit handling, Rust's tokio runtime keeps running AFM to completion, wasting CPU/battery." | Ship explicit `CancellationToken` handle objects; Swift must call `handle.cancel()` in `continuation.onTermination`. |

### Compass-verified concrete tech stack (to pin in Cargo.toml + Package.swift)

| Crate / Framework | Version | Purpose | Source |
| ----------------- | ------- | ------- | ------ |
| `FoundationModels` | macOS 26+ | `@Generable` + `@Guide` ontology / structured outputs | Apple, OS daemon (zero RAM cost to app) |
| `mlx-swift` | `0.31.3` | Local subconscious | Apple, ~23 Mar 2026 |
| `mlx-swift-lm` | `3.31.3` | LLM/VLM/Embedder runtime | Apple, 15 Apr 2026 |
| `uniffi` | `0.29.5` (PINNED) | Rust↔Swift FFI | Mozilla — DO NOT bump to 0.30/0.31 |
| `sqlite-vec` | `0.1.9` | Vector KNN inside GRDB SQLite (sub-50 ms @ 100k) | Alex Garcia, 165 KB extension |
| `petgraph` | `0.8.2` | StableDiGraph for in-memory property graph projection | bluss/petgraph |
| `fsrs` | `5.2.0` | FSRS-6 spaced repetition (BSD-3, Anki's lead dev + Jarrett Ye, Burn-based, no libtorch) | open-spaced-repetition |
| `tokio-cron-scheduler` | `0.15.1` | In-process cron | mvniekerk |
| `apalis` | `1.0.0-rc.7` | Production job queue with SQLite backend (no Redis) | geofmureithi |
| `notify` | `8.2.0` | FSEvents file watching | notify-rs |
| `notify-debouncer-full` | `0.7.0` | Coalesces rename pairs + tracks inode IDs across renames | notify-rs |
| `ignore` | `0.4.25` | Codebase exclusion (BurntSushi/ripgrep) for ETL | BurntSushi |
| `twox-hash` | `2.x` (xxh3-128) | Change detection (31 GB/s, 128-bit space) | shepmaster |
| `BLAKE3` | latest | Cryptographic integrity (signed exports, 8.4 GB/s multi-threaded) | BLAKE3-team |
| `pty-process` | `0.5.3` | PTY spawning (Tokio-native AsyncRead/Write) for CLI bridge | doy |
| `anstream` | `0.6` | ANSI stripping for CLI output | rust-cli |
| `hdbscan` | `0.12` | Unsupervised cluster discovery for ontology | mhrjedi |
| `schemars` | `0.8` | JSON Schema export from Rust structs | GREsau |
| `rmcp` | `0.16` | MCP server (target spec **`2025-06-18`** — broadest client support) | model context protocol |
| `candle-core` | latest | GGUF Q-types (Q8_0, Q4_K, Q2_K) for tier-cascade quantisation | huggingface |
| `LLMLingua-2` | latest | 2-20× compression via BERT-class encoder; sidecar Python or Core ML port | microsoft |

### Compass-verified concrete schemas

**Phase 1 — `@Generable OntologyNode`** (recursive nesting works; **property declaration order is semantically significant** — model fills fields sequentially, dependents must follow referents):

```swift
@Generable struct OntologyNode {
    @Guide(description: "Canonical concept, lowercase kebab-case") let concept: String
    @Guide(description: "Knowledge depth marker") let depth: DepthMarker
    @Guide(.count(0...8)) let children: [OntologyNode]   // recursive
}
@Generable enum DepthMarker { case surface, synthesized, coreBelief }
```

**Phase 8 — graph schema (sqlite-vec + petgraph)**:

```sql
CREATE TABLE node (
  id TEXT PRIMARY KEY, kind TEXT NOT NULL,
  depth INTEGER NOT NULL,                   -- 1=surface, 2=synthesized, 3=core-belief
  title TEXT NOT NULL, body TEXT,
  created_at INTEGER, updated_at INTEGER, sidecar_path TEXT
);
CREATE TABLE edge (
  src TEXT, dst TEXT, rel TEXT,             -- parent_of, derived_from, contradicts, supports, session_of
  weight REAL DEFAULT 1.0, meta JSON,
  PRIMARY KEY (src, dst, rel)
);
CREATE VIRTUAL TABLE vec_node USING vec0(
  node_id TEXT PRIMARY KEY, embedding float[384]
);
```

Hysteresis on dynamic edge inference: `τ_add = 0.80`, `τ_remove = 0.65` (prevents oscillation as user iterates). Existing edges decay `weight *= 0.97^days` via Phase 2 cron.

**Phase 12 — sidecar struct**:

```rust
#[derive(Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
struct EpistemosSidecar {
    schema_version: u16,
    entity_id: Ulid,
    depth: DepthMarker,
    parent_domain: Option<String>,
    derived_from: Vec<Ulid>,
    embeddings: Option<EmbeddingRef>,
    cognitive_meta: CognitiveMeta,
    annotations: Vec<Annotation>,
}
```

### Compass-verified Apple Foundation Models hard limits

- **4,096 tokens combined input + output.** `LanguageModelGenerationError.exceededContextWindowSize`. Use `model.tokenCount(for:)` (macOS 26.4+) to budget.
- **No multimodal input** as of 26.4 (text-only).
- **Guardrails are mandatory and cannot be disabled.**
- Streaming is via `T.PartiallyGenerated` snapshots — **no token-level callbacks exposed.**
- **PCC is never used.** Apple DTS engineer confirmed: "Currently the Foundation Models framework only has access to the on-device model. PCC is never used. Ever." Zero cloud egress; no fallback if on-device too small.
- **Cold start: 1–3 seconds.** Use `session.prewarm(promptPrefix:)` on app launch.
- **Adapters**: `.fmadapter` packages ~160 MB, LoRA rank 32. **Production deployment requires Foundation Models Framework Adapter Entitlement** (request via Apple Developer Account Holder). Adapter ID regex `/fmadapter-\w+-\w+/` — undocumented; **hyphens in adapter names break loading**.
- **macOS 15 Sequoia ships NO model assets.** Require macOS 26 Tahoe minimum; gate via `SystemLanguageModel.default.availability`.

### Compass-verified hybrid-brain memory budget (M2 Pro 18 GB)

| Component | Owner | Resident |
| --------- | ----- | -------- |
| macOS + WindowServer + daemons | OS | ~3.5–4 GB |
| **AFM 3B (`generativeexperiences`d)** | OS daemon | **~2 GB, OS process — does NOT count against app** |
| Swift heap + UI + SQLite + sqlite-vec hot pages | App | ~1.5–2 GB |
| Rust core (UniFFI) + tokenizers | App | ~300–500 MB |
| **MLX subconscious (Qwen3 0.6B 4-bit)** | App | **~600–800 MB** |
| MLX KV cache headroom (8K ctx) | App | ~300 MB |
| GPU/Metal heaps | App | ~200–400 MB |
| **App total** | | **~3.5–5 GB** |

### Compass concurrency policy (heart of Phase 5)

```swift
private func canRunMLX() -> Bool {
    let pi = ProcessInfo.processInfo
    if pi.isLowPowerModeEnabled { return false }
    if pi.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue { return false }
    if PowerSource.isOnBattery && PowerSource.currentCharge < 0.50 { return false }
    if Date.now.timeIntervalSince(idleSince) < 2.0 { return false }
    if afmSession.isResponding { return false }   // yield GPU to AFM
    return true
}
```

Cap MLX RSS via `MLX.GPU.set(memoryLimit: 6 * 1024 * 1024 * 1024)`. Monitor `ProcessInfo.thermalStateDidChangeNotification` and `.NSProcessInfoPowerStateDidChange`.

### Compass per-CLI verified flag matrix (Phase 3)

| CLI | Headless | JSON stream | Auth | MCP support | Reality |
| --- | -------- | ----------- | ---- | ----------- | ------- |
| **Claude Code** | `claude -p "..." --output-format stream-json --verbose --include-partial-messages [--bare]` | NDJSON: `system`, `stream_event`, `result`. `--json-schema` for constrained output. `--continue` / `--resume <session_id>` | `ANTHROPIC_API_KEY` | `claude mcp add`; can act as MCP server via `claude mcp serve` | Best supported |
| **OpenAI Codex** | `codex exec --json "..."` (Rust binary, **source-available** `openai/codex`) | JSONL: `thread.started`, `turn.{started,completed,failed}`, `item.{started,updated,completed}`. `--output-schema` for constrained output. | ChatGPT OAuth or `OPENAI_API_KEY` | `codex mcp add`, `codex mcp serve` | **Stable; can vendor `codex-rs` directly as Cargo dep** |
| **Kimi CLI** (`MoonshotAI/kimi-cli` v1.39) | `kimi --print -p "..."` | `--output-format=stream-json` (OpenAI Message format) | OAuth or API key | `kimi mcp add` | macOS+Linux only |
| **Hermes Agent** (Nous Research) | `hermes chat -q "..."` | **No first-class JSONL flag**. Spawn `hermes api-server` once and stream via SSE on `/v1/chat/completions`. Or `hermes acp` (Agent Client Protocol) over stdio | OAuth via `hermes auth` | `hermes mcp serve` | **Treat as a service, not a one-shot CLI** |

### Compass Hermes pricing (April 2026)

| Model | Provider | Input / 1M | Output / 1M |
| ----- | -------- | ---------- | ----------- |
| **Hermes 4 70B** | Nous Portal / OpenRouter | **$0.13** | **$0.40** |
| Hermes 4 405B | Nous Portal | $1.00 | $3.00 |
| Hermes 4 405B | Nebius FP8 (via OpenRouter) | $0.60 | $1.90 |
| Hermes 3 405B | OpenRouter free tier | $0 | $0 |
| Claude Sonnet 4.6 | Anthropic | $3.00 | $15.00 |
| Kimi K2 | Moonshot | $0.15 | ~$2.50 |

**Hermes 70B as orchestrator vs Claude Sonnet 4.6 ≈ 3.2× cheaper end-to-end** ($0.038 vs $0.12 per 5-step session).

### Compass token-usage decision tree

| Pattern | When to use | Savings |
| ------- | ----------- | ------- |
| Anthropic 5-min cache | Static across requests | **~90 %** on cached tokens (1.25× write cost) |
| Anthropic 1-h cache | Stable system+tools | ~90 % on cached tokens (2× write; break-even ≈ 2 hits) |
| OpenAI cache | Newest models | **50 %** baseline (up to 90 %) |
| Kimi cache | Moonshot models | **75–83 %** input cost |
| LLMLingua-2 compression | Long bloated text | 2–20× token reduction; ~50–80 % input cost |
| Tool-use retrieval vs full-context | Large but only sometimes needed | **~99 % input reduction on retrieved part** |
| LoRA persona vs system prompt | Stable persona/style + self-host | Eliminates 500–2,000 tokens *every* call |

**What does NOT work**: raw embeddings as conversational input (no commercial provider supports), hot-swap system prompts (single-character drift = full miss), pause-and-inject mid-stream (no provider exposes the primitive).

### Compass build order — 12-month plan

> Optimised for **ADA submission March 2026 → June 2026 reveal**.
> Featuring nominations open ~3 months before WWDC; June 8–12 is WWDC
> 2026; ADA reveal expected late May / first week June 2026.

**Months 1–3 (foundation)**: Phase 1 (AFM `@Generable` ontology) → Phase 8 (sqlite-vec + petgraph + Metal graph) → Phase 12 (sidecars + notify + ignore) → Phase 4 (bootstrap with **cache padding to 1100+ tokens**) → Phase 5 (hybrid brain orchestrator with thermal/battery/GPU-contention policy).

**Months 4–6 (sensory + structure)**: Phase 14 (intake valve with <500 ms target, explicit cancellation token) → Phase 15 (two-DB quarantine) → Phase 11 (SpeechAnalyzer + Metal waveform) → Phase 2 (FSRS-6 + candle Q-types tier cascade + launchd LaunchAgent).

**Months 7–9 (orchestration + intelligence)**: Phase 3 (CLI bridge with pty-process) → Phase 6 (**tool-use retrieval, NOT pause-and-inject**) → Phase 9 (`@Generable SessionTelemetry`) → Phase 16 (real-time stenographer).

**Months 10–12 (defensibility + polish)**: Phase 7 (Hermes Chief of Staff via rmcp 0.16) → Phase 13 (apalis-sqlite ETL with xxh3) → Phase 10 (NightBrain LoRA — quietly, with in-context fallback always engaged) → ADA polish (Liquid Glass, App Intents, Quick Look, accessibility audit).

### Compass — three things to do first this week

1. **Pin `uniffi = "0.29.5"`** + stand up Issue #2818 mitigation (separate SwiftPM target with `nonisolated` defaults). Without this, every other Swift 6 build is broken on Xcode 26.
2. **Build benchmark harness** measuring (a) AFM `@Generable` round-trip latency, (b) MLX Qwen3 0.6B 4-bit tok/s under thermal pressure, (c) sqlite-vec KNN at 100 k vectors, (d) UniFFI callback throughput. **Numbers in this report are estimates; measure the actual stack.**
3. **Pad the W10.4 BootstrapPacket to ≥1,100 tokens** of stable content; verify cache hits via `cache_creation_input_tokens` / `cache_read_input_tokens` telemetry. **Without padding, W10.4 has zero caching benefit.**

### Compass ADA strategic frame

- **2026 ADA winners not yet announced** (WWDC June 8–12, ADA reveal late May / first week June 2026). Any "2026 ADA winner" claim is fabricated.
- **Apple has skipped pure-genAI apps two years running** — they prefer apps that *use* AFM to enhance a non-AI core experience.
- **Apple PR'd 7 AFM-using apps in Sept 2025** (SmartGym, Stoic, VLLO, Grammo, Stuff, CellWalk, Lil Artist) — going hard on AFM is aligned with Apple's 2026 marketing priorities.
- **Recommended ADA category for Epistemos: Innovation (primary), Visuals & Graphics (backup)**.
- **No public ADA submission form**; apps must be on App Store; selection by Apple's editorial team. Visibility levers: App Store Connect Featuring Nominations ~3 months before WWDC, Today/Discover, dev relations.
- **Required engineering polish for editor's eye**: Liquid Glass adoption, App Intents, Spotlight integration, Quick Look for sidecar files, Shortcuts actions, VoiceOver + Dynamic Type + Reduce Motion *actually working*.

### Compass demo video structure (60–90 sec)

1. 0:00–0:05 Cold open: live Metal graph animation, ~1000 nodes pulsing
2. 0:05–0:35 Native moment: type a thought → AFM streams → graph node materialises → connects. 60 fps.
3. 0:35–0:55 Decay moment: time-lapse of unused notes physically dimming and shrinking.
4. 0:55–1:15 Privacy moment: airplane mode ON, everything still works. Activity Monitor shows AFM on Neural Engine.
5. 1:15–1:25 Open `.epistemos.json` in TextEdit. *"Your data, your files. Forever."*
6. 1:25–1:30 Logo.

**Hide**: Rust ("performance core"), cloud LLMs (de-emphasise, lead on-device), multi-agent CLI orchestration (powerful but reads as chaotic — save for hackathons).

## Sources

- `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `docs/AGENT_PROGRESS.md`, `docs/KNOWN_ISSUES_REGISTER.md`
- `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`, `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md`
- `~/Downloads/opt/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` + `Epistemos Performance Optimization Roadmap.txt`
- `~/Downloads/new features/Cognitive Computing Capabilities for a Native macOS Personal Knowledge System.md`
- `~/Downloads/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md`
- `~/Downloads/cap5_night_brain.md` (orphan + FSRS sources)
- Cross-corpus grep against `Epistemos/` source for "exists in code, no UI" gaps
