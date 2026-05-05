# Epistemos Pro — Master Doctrine & Implementation Cookbook

> **DISCLAIMER:** Every feature, config, schema, and design decision in this doctrine requires further deep research before implementation. This document is the starting trellis, not the final spec. Mark `UNVERIFIED` where flagged and probe before committing to wire.

---

## Executive verdict (3 sentences)

The public repo at `github.com/BlickandMorty/Epistemos` is unretrievable from a public web fetcher as of 27 Apr 2026, so on observable evidence **all twelve North Star moats score Missing** — not because the doctrine is wrong, but because no public code exists yet to earn Strong/Partial. The hardware reality is harsh and clarifying: M2 Pro 18 GB sustains exactly one credible faculty roster — **Hermes-3-Llama-3.1-8B-4bit (primary) + Llama-3.2-1B-4bit (drafter) + bge-small-en-v1.5 (embeddings) + Apple Foundation Models (zero-RAM utility)** — totalling ~5.6 GB resident with comfortable headroom; everything 30B+ and every hybrid-SSM that depends on `mamba-ssm` CUDA kernels is a meme on this device. The actually-defensible product is a **provenance-first append-only RunEventLog with BLAKE3 Merkle chaining, deterministic 10-stage SOAR replay, FSRS-6 epoch decay, AFM `@Generable` as the structurer, and a Swift macro-static A2UI v0.9 catalog** — i.e., the moats are won by ruthless determinism and Apple-native plumbing, not by chasing parameter counts.

---

# PART I — MASTER DOCTRINE

## §A. Moat audit (truthful baseline)

The repo URL `https://github.com/BlickandMorty/Epistemos` returned `PERMISSIONS_ERROR` on direct fetch and zero hits via Google `site:github.com`. It is private, mis-spelled, deleted, or unindexed. The audit therefore proceeds on doctrine intent only; **every moat below is Missing on observable code**, with the cheapest demoable proof per moat called out.

| # | Moat | Verdict | Cheapest proof to flip → Partial |
|---|---|---|---|
| 1 | Provenance-first 4-layer event model | **Missing** | `crates/provenance-core` with `RunEvent` enum + `replay` CLI + golden-file test |
| 2 | Native Apple Silicon supremacy | **Missing** | One Metal4 sample at 120fps + MLX `bytesNoCopy` demo |
| 3 | Hermes-as-bridge | **Missing** | `crates/epistemos-hermes-mcp` exposing 7 graph verbs over stdio |
| 4 | Verifiable cognition (10 properties) | **Missing** | A single chokepoint `dispatch_action(ActionEnvelope) -> Result` type |
| 5 | Schema-driven UI (closed A2UI catalog) | **Missing** | `Schemas/a2ui.json` + Swift enum with N cases + DEBUG quarantine |
| 6 | Provider sovereignty (8 providers) | **Missing** | `Provider` trait + 2 adapters (Hermes-MLX, Claude Code CLI) |
| 7 | Sandbox ladder | **Missing** | Wasmtime+Bollard PoC with `--network=none readonly_rootfs` |
| 8 | Vault as memory | **Missing** | `fsrs-rs` integration + `memory_state` GRDB table |
| 9 | Cognition layer (≤30ms Instant Recall) | **Missing** | `criterion` bench file with `usearch + FTS5 + RRF` over 100k vectors |
| 10 | Structured data first-class | **Missing** | `.epdoc` schema + `@Generable` extractor + audit walker binary |
| 11 | Manifest compiler | **Missing** | `examples/epistemos.yaml` + 7 golden output fixtures |
| 12 | Open-source disruption strategy | **Missing** | Sibling public repo `epistemos-provenance-standard` with schemas + trace-validator |

The honest bottom line: **this is a manifesto until the manifest compiler emits its first golden file**. Phase 0 must publish moats 11, 5, and 1 in that order — they convert doctrine to leverage with the fewest LOC.

## §B. Architecture spine

Five concentric rings, inside-out:

1. **Ring 0 — `RunEventLog` (Rust, durable):** the only source of truth. SQLite WAL, ULID keys, BLAKE3 Merkle chain, schema-versioned via `#[serde(tag="schema_version")]`. Append-only, redaction-gated, replay-deterministic.
2. **Ring 1 — `MutationEnvelope` (Rust):** typed graph mutations with `Reversibility`/`Sensitivity`/`status` fields, embedded as one variant of `RunEventKind::MutationCommitted`. Identity = ULID, integrity = BLAKE3.
3. **Ring 2 — Projections (Rust→Swift via UniFFI 0.29.5):** `AgentEvent` for transcript UI, `GraphEvent` for Metal renderer, both pure folds over Rings 0+1. Outbox pattern with `projection_outbox` table; relay marks rows `published`.
4. **Ring 3 — Faculty x Provider router (Rust):** Hermes-3 8B local MLX as primary, Llama-3.2-1B drafter, AFM via Swift bridge, four CLI subprocess providers, two HTTP providers — all behind one `Provider` trait, env-scrubbed, kill-on-drop, budget-gated.
5. **Ring 4 — UI (Swift 6.2, `@MainActor` default isolation):** A2UI v0.9 closed catalog of ~25 SwiftUI components, no runtime codegen, DEBUG quarantine renderer for unknown components, compile-time `@RoutableEnum` macro for view routing.

Around all five rings: the **Cognition Layer** sharing one `ClaimLedger`, one source-quality contract, one audit vocabulary — Instant Recall (≤30 ms p50), Research Kernel (10-stage SOAR), AutoResearch (nightly digest), Deep Deliberation (4-agent jury), Belief Drift (5 algorithms, append-only edges).

The **integration plane** sits underneath: `epistemos-hermes-mcp` Rust binary exposes seven graph verbs over MCP 2025-11-25 stdio; `manifest compiler` emits CLAUDE.md/.mcp.json/.codex/config.toml/SKILL.md/Gemini settings/Kimi env/Qwen tool manifest from one `epistemos.yaml`. The **provenance standard** (open) is bifurcated from the **app** (proprietary) with a sibling public repo.

## §C. Hardware-realistic faculty roster (locked)

M2 Pro 18 GB usable AI ceiling ≈ 10–11 GB. Tier A — always resident:

| Slot | Model | Repo | 4-bit footprint @8K | Role |
|---|---|---|---|---|
| Primary brain | **Hermes-3-Llama-3.1-8B-4bit** | `mlx-community/Hermes-3-Llama-3.1-8B-4bit` | ~4.85 GB (KV 4-bit) | Agent, ChatML+`<tool_call>`, JSON mode |
| Drafter | **Llama-3.2-1B-Instruct-4bit** | `mlx-community/Llama-3.2-1B-Instruct-4bit` | ~0.75 GB | Speculative decoding pair (same Llama-3 tokenizer — **mandatory architectural compatibility**) |
| Embedder | **bge-small-en-v1.5** | `BAAI/bge-small-en-v1.5` | ~30 MB | HNSW Instant Recall, 384-dim |
| Utility | **Apple Foundation Models 3B** | system framework | 0 GB to app | `@Generable` typed extraction, transcription post-process |
| **Subtotal** | | | **~5.65 GB** | leaves ~12 GB headroom |

Tier B — swap-in: Qwen3-4B-Instruct-2507-4bit (~2.6 GB) for low-latency tool routing; DeepSeek-R1-Distill-Qwen-7B-4bit (~4.5 GB) for math-heavy reasoning; FalconMamba-7B-Instruct-4bit (~4 GB flat) for very-long-context streaming.

**Hard rejects:** Qwen3-30B-A3B / Qwen3-Next-80B / FireFunction-V2 (won't fit); xLAM-7b (CC-BY-NC, commercial-blocked); Zamba2 / RecurrentGemma / Mamba-Codestral (no working MLX path — `mamba-ssm` CUDA kernels are a hard blocker on Apple Silicon as of April 2026).

**Critical correction to original brief:** the proposed Qwen3-0.6B drafter against Hermes-3 8B target is **vocabulary-mismatched** (Qwen tokenizer vs Llama-3 tokenizer). Cross-vocab speculative decoding (OmniDraft, arXiv 2507.02659) costs a re-encode per accept — defeats the purpose. Use Llama-3.2-1B-Instruct-4bit instead. This is non-negotiable.

## §D. The four-layer event model (canonical Rust types)

```rust
// Identity primitives
#[derive(Serialize, Deserialize, JsonSchema)]
#[serde(transparent)] pub struct EventId(pub Ulid);
#[serde(transparent)] pub struct RunId(pub Ulid);
#[serde(transparent)] pub struct MutationId(pub Ulid);
#[serde(transparent)] pub struct IntegrityHash(#[serde(with="hex::serde")] pub [u8; 32]);

#[derive(Serialize, Deserialize, JsonSchema)]
pub enum Sensitivity { PublicSafe, UserPrivate, CredentialSensitive, SecretForbidden }

#[derive(Serialize, Deserialize, JsonSchema)]
#[serde(tag="kind")]
pub enum Reversibility {
    Reversible { inverse: Box<MutationOp> },
    PartiallyReversible { inverse: Box<MutationOp>, lost_metadata: Vec<String> },
    Irreversible { reason: String },
}

#[derive(Serialize, Deserialize, JsonSchema)]
pub enum MutationStatus { Pending, Committed, Failed, Reverted }

#[derive(Serialize, Deserialize, JsonSchema)]
pub struct MutationEnvelope {
    pub id: MutationId, pub run_id: RunId, pub sequence: u64,
    pub caused_by_event_id: EventId, pub actor: Actor,
    pub approval_id: Option<ApprovalId>, pub status: MutationStatus,
    pub created_at: DateTime<Utc>, pub committed_at: Option<DateTime<Utc>>,
    pub op: MutationOp, pub integrity_hash: IntegrityHash,
    pub reversibility: Reversibility, pub sensitivity: Sensitivity,
    pub schema_version: u32,
}

// RunEventLog — durable
#[derive(Serialize, Deserialize, JsonSchema)]
#[serde(tag="type")]
pub enum RunEventKind {
    ProviderStarted(ProviderStartedPayload),
    ToolCallStarted(ToolCallStartedPayload),
    ToolCallFinished(ToolCallFinishedPayload),
    MutationCommitted(MutationEnvelope),
    PermissionRequested(PermissionRequestedPayload),
    Error(ErrorPayload),
    SessionCheckpoint(SessionCheckpointPayload),
    RedactionApplied(RedactionReport),
    RunStatusChanged { from: RunStatusEnum, to: RunStatusEnum, reason: Option<String> },
}

#[derive(Serialize, Deserialize, JsonSchema)]
pub struct RunEvent {
    pub id: EventId, pub run_id: RunId, pub sequence: u64,
    pub schema_version: u32, pub created_at: DateTime<Utc>,
    pub actor: Actor, pub sensitivity: Sensitivity,
    pub caused_by_event_id: Option<EventId>,
    pub kind: RunEventKind,
    pub prev_hash: IntegrityHash,         // Merkle link
    pub integrity_hash: IntegrityHash,    // BLAKE3(canonical(event_minus_hash) ‖ prev_hash)
}

// Ephemeral deltas — NEVER in durable log; rolled to transcript.jsonl.zst at flush boundaries
pub enum EphemeralEvent { TextDelta, ThinkingDelta, ToolCallDelta, BashOutput }

// Projections
#[derive(Serialize, Deserialize, JsonSchema, TS)]
#[serde(tag="type")]
pub enum AgentEvent { SpeakerTurn{...}, ToolInvoked{...}, AwaitingApproval{...},
                      StatusBadge{...}, ErrorBanner{...} }

#[derive(Serialize, Deserialize, JsonSchema, TS)]
#[serde(tag="type")]
pub enum GraphEvent { NodeAdded{...}, NodeRemoved{...}, NodeUpdated{...},
                      EdgeAdded{...}, EdgeRemoved{...}, Reset }
```

**Commit ordering (transactional outbox):**
```
BEGIN IMMEDIATE;
  INSERT INTO run_events (...) VALUES (...);
  -- if MutationCommitted variant:
  INSERT INTO mutations (...) VALUES (...);
  INSERT INTO projection_outbox (event_id, target, status='pending')
    VALUES (?, 'agent'), (?, 'graph');
  UPDATE projection_marker SET last_committed_seq = ? WHERE projection='run_event_log';
COMMIT;
-- relay task asynchronously derives AgentEvent/GraphEvent, marks 'published'
```

**Redaction pipeline (write-path interceptor):** `EventLog::append(evt)` calls `redactor.scan_and_transform(evt)` first; gitleaks-rule + entropy + Presidio-style NER classify into `Sensitivity`; `SecretForbidden` → reject + emit `Error{kind:SecretForbidden}` with hashed offending content; `CredentialSensitive` → redact with `<REDACTED:type:hash>` token + emit `RedactionApplied(RedactionReport)`. Hash is computed **after** redaction so the chain covers redacted content.

**RunStatus state machine:** `Created → Initializing → Running → AwaitingApproval → (Cancelling | Completed | Failed) → Committed`. Encode with **typestate at API surface** (`Run<Created>`, `Run<Running>`, etc., transitions consume `self`) AND emit runtime `RunStatusEnum` into events for serialisation. Bridge with `From<Run<S>> for RunStatusEnum`.

**Replay determinism rules:** no `SystemTime::now()` in projectors (capture in events at write); no `HashMap` iteration in `apply` (use `BTreeMap`); seed RNG from `H(event.id || stage)`; pin model weight hashes; sort directory listings; use Kahan summation or fixed-point for fp reductions; canonical CBOR for hashing (not JSON — JSON has multiple representations).

**Identity field requirements:** `event_id: Ulid` (ULID over UUIDv7 for spec-mandatory monotonic-within-ms + 26-char Crockford readability + 80 random bits), `run_id: Ulid`, `sequence: u64`, `timestamp_ms: i64`, `actor: ActorRef`, `schema_version: u32`.

## §E. Hermes-as-bridge architecture

**Roles.** Hermes-3 8B local (primary brain) → Hermes Nous Cloud API (escalation when local exceeds budget/complexity per per-session budget gate). Hermes Cloud is OpenAI-compatible at `https://portal.nousresearch.com`; Hermes-4-405B at $1/M in $3/M out, 131K context.

**The Rust binary `epistemos-hermes-mcp`** speaks MCP 2025-11-25 stdio JSON-RPC and exposes seven graph verbs:

```json
// tools/list response advertises:
{"name":"graph.search_semantic", "inputSchema":{...}}
{"name":"graph.search_fulltext", "inputSchema":{...}}
{"name":"graph.get_node", "inputSchema":{...}}
{"name":"graph.traverse", "inputSchema":{...}}
{"name":"graph.create_node", "inputSchema":{...}}
{"name":"graph.create_edge", "inputSchema":{...}}
{"name":"graph.commit_session", "inputSchema":{...}}
```

`graph.commit_session` is the linchpin: every Hermes session = subgraph; calling commit pins the subgraph as a `MutationEnvelope` with `caused_by_event_id` chained to the session's first `ProviderStarted` event.

**Skill-as-graph-node lifecycle.** Graph is canonical; SKILL.md is a projection for upstream-Hermes/Anthropic-skills compatibility (agentskills.io standard). Bidirectional mapping:
- node `id` ↔ directory name = frontmatter `name` (lowercase letters/numbers/hyphens, ≤64 chars)
- node `summary` ↔ frontmatter `description` (≤1024 chars, third-person imperative)
- node `body` (markdown) ↔ SKILL.md body (≤500 lines)
- node `permissions` ↔ frontmatter `allowed-tools` (space-separated)
- node `assets[]` ↔ `assets/`, `scripts/`, `references/` subdirs

Sync-back on session end: parse YAML frontmatter → diff against graph node → emit `MutationOp::UpdateField` operations; never mutate node in place.

**CLI subprocess providers** all flow through one `Provider` trait:
```bash
claude -p "..." --output-format stream-json --verbose --include-partial-messages --bare
codex exec "..." --json --sandbox read-only
gemini -p "..." --output-format stream-json
# Kimi has no first-party CLI — use OpenAI-compatible HTTP at api.moonshot.ai/v1
```

**Env scrubbing (mandatory, every spawn):** `Command::env_clear()` then allowlist `PATH HOME USER LANG TERM ANTHROPIC_API_KEY OPENAI_API_KEY MOONSHOT_API_KEY GOOGLE_API_KEY`. Never inherit `DEBUG NODE_OPTIONS LD_PRELOAD DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH MallocStackLogging PYTHONPATH RUBYOPT PERL5OPT`. `Command::kill_on_drop(true) + Command::process_group(0)`. **No PTY for non-interactive** (PTY corrupts JSONL framing via CR/LF translation); use plain pipes.

**What Hermes must never own:** graph state, run state, provider routing, permissions, schema validation, UI rendering. Hermes is invoked into the loop; the loop is not invoked by Hermes.

## §F. Cognition layer (one ClaimLedger, one source-quality contract)

**Instant Recall** — usearch 2.25.1 HNSW (`M=16, ef_construction=200, ef_search=64`, cosine, fp16 quantization on Apple NEON) + SQLite FTS5 with `bm25(notes_fts, 2.0, 1.0)` over porter-unicode61 tokenizer + RRF fusion `Σ 1/(60 + rank_i)`. Latency budget on M2 Pro at ≤1M chunks: query embed 3–6 ms, HNSW@50 0.5–2 ms, FTS5 BM25 3–10 ms, RRF merge <1 ms, snippet hydrate 5–10 ms = **p50 14–28 ms**, headroom 5 ms. FTS5 over Tantivy because of single-file vault UX and adequate quality at this scale.

**Research Kernel — deterministic 10-stage SOAR pipeline:** Question framing → Source enumeration → Evidence retrieval (RRF) → Extraction (claims + spans) → Cross-source corroboration → Contradiction surfacing → Analysis (argument graph) → Synthesis (candidate answer) → **Three-pass audit** (citation/consistency/counterfactual) → Emit. Determinism via seeded RNG `H(question || stage_id || run_id)`, `temperature=0`, `top_p=1.0`, ordered inputs, pinned model weight SHA-256 in every emit, tokenizer + prompt-template hashes logged. Inspired by Laird/Newell/Rosenbloom 1987 SOAR but flattened so audit and replay are bit-exact (UNVERIFIED: bit-exact reproduction across MLX builds is fragile due to Metal kernel reduction reordering).

**Cognitive AutoResearch — nightly digest, weekly consolidation, Karpathy metabolization.** Nightly: connected-components on note graph, stale-link detection (`1 - cos(end_a, end_b) < 0.4 AND last_traversed > 90d`), orphan re-surface scoring `0.4·(1−PPR_centrality) + 0.3·(1−E[θ]) + 0.3·days_since · exp(−R_FSRS) + 0.2·novelty_to_today`. LoRA micro-finetune via `mlx_lm.lora --iters 200 --batch-size 2 --learning-rate 1e-4`; 30–50% replay buffer of canonical notes mixed every batch to mitigate catastrophic forgetting; EWC penalty `λ/2 · Σ F_i (θ_i − θ*_i)²` (Kirkpatrick 2017, with Huszár 2017 single-Fisher correction for >2 tasks).

**Deep Deliberation jury — 4-agent stance × function-role taxonomy.** Default jury: `Proposer-Optimist + Critic-Skeptic + Synthesizer-Generalist + Adjudicator-Specialist`. Adjudicator MUST be a different model family than Proposer (mitigation for confidence-induced adversarial influence per Nature 2026 paper on multi-agent debate hijacking). Mandatory artifacts: transcript, per-claim provenance ledger, disagreement graph, final verdict, determinism manifest, cost stamp. Du et al. 2023 `arXiv:2305.14325` is the technical seed; Epistemos's contribution is requiring source-spans on every Critic-rejected claim.

**Belief Drift — five detection algorithms, append-only edges only:**
1. KL divergence on claim-class distributions over rolling windows (PSI > 0.2 = significant)
2. Embedding drift on tracked entities (centroid cosine > 0.15 → alert; report MMD too)
3. Contradiction-graph density (`edges_added / claims_added` per window)
4. Citation freshness decay `weight = 2^(−age/τ)`, τ per-domain (news 14d, science 730d, math ∞)
5. Statement reuse-rate collapse (formerly hot belief → zero reuse)

Status flips emit new edges (`supersedes`, `contradicts`, `decays`, `reaffirms`) into `claim_status_edges` table; **never mutate prior records**. The `claim_current` view derives status from latest edge.

## §G. Structured-data ontology pipeline (no-messy-data principle)

**`.epdoc` package format:** body = ProseMirror JSON canonical (`{type:"doc", content:[…]}`) in a sidecar `.epdoc.pm.json`; markdown view rendered by `prosemirror-markdown`; YAML front-matter holds typed metadata.

**Front-matter schema (required + optional):**
```yaml
---
id: 01HZK3...                          # required: ULID
type: Note|Concept|Skill|Anchor|Question|Plan|Reflection
schema: epdoc/v1
created_at: 2026-04-27T12:34:56Z
depth: { fkgl: 11.2, parse: 7, epistemic: 4, meta_order: 1 }   # see §depth
complexity: { tokens: 1240, sentences: 38 }
emotional_anchors:
  sentiment: 0.32                      # NLTagger NLSentimentScore [-1,+1]
  intensity: medium
  stance: hedged                        # certain|hedged|exploratory|doubtful
concept_refs: ["concept:phenomenology", "concept:basal_ganglia"]
provenance_run_id: 01HZK4...
# optional:
decay_state: { D: 5.6, S: 12.3, last_review: 1745... }   # FSRS-6
salience: 0.74
last_engaged_at: 2026-04-26T08:00:00Z
parent_concept: "concept:cognitive_neuroscience"
child_concepts: []
jsonld:
  "@context": https://schema.org
  "@type": CreativeWork
---
```

**Concept ontology graph.** Typed nodes (`Concept`), typed edges (`parent_of`, `related_to`, `instance_of`). Bootstrap: WordNet hypernym seed (~155k English lemmas) + ConceptNet relations for non-`IsA` edges + LLMs4OL benchmark workflow for term-typing/taxonomy-discovery (Babaei Giglou 2023, arXiv:2307.16648). Growth: at every note write, AFM `@Generable ConceptExtraction` extracts `[Concept{surface, parent, kind, confidence}]`; merge with TaxoGen-style adaptive split when a parent's child-set exceeds K=5 with low intra-cluster cosine (Zhang 2018, arXiv:1812.09551); NetTaxo-style joint text+network induction kicks in when notes have ≥30 backlinks (Shang 2020, doi:10.1145/3366423.3380259).

**Depth marker computation (write-time):**
- structural depth: Flesch-Kincaid `0.39·(w/s) + 11.8·(syll/w) − 15.59`
- syntactic depth: spaCy dependency-tree max depth from any token to ROOT
- epistemic depth: longest path in extracted claim→evidence→counter DAG
- dialectic score: `#counter / #claim`
- meta_order: regex screen (`I (notice|realize) that I`, `my own thinking`) + AFM `@Generable {is_meta: Bool, meta_order: Int}` confirm

```sql
CREATE TABLE note_depth (note_id TEXT PRIMARY KEY, fkgl REAL, parse_depth INT,
    epistemic_depth INT, dialectic_score REAL, meta_order INT DEFAULT 0);
CREATE INDEX idx_meta ON note_depth(meta_order, epistemic_depth DESC);
```

**Emotional anchor extraction:** Apple `NLTagger.tagSchemes=[.sentimentScore]` for cheap [-1,+1] paragraph scores; AFM `@Generable EmotionalAnchor {sentiment, intensity, stance}` for finer affect; never use cloud sentiment APIs for journal content.

**Conversation-as-structured-context.** Every chat session compiles to a JSON sidecar the model reads mid-conversation. Schema includes turn-by-turn `{role, content_redacted, sentiment, depth, concept_refs, anchor_refs, timestamp, latency_ms}`. Hybrid memory: A-MEM-style note evolution at write-time (Xu 2024, arXiv:2502.12110) + HippoRAG Personalized PageRank for ambient retrieval at session start (Gutiérrez 2024, arXiv:2405.14831) + MemGPT-style explicit `recall_*` tools for user-driven search (Packer 2023, arXiv:2310.08560). Anthropic prompt caching: place `cache_control:{type:"ephemeral", ttl:"1h"}` on the SESSION_SCHEMA_JSON system block (rarely changes), default 5-min ephemeral on USER_ONTOLOGY_YAML (refreshes per turn), 4 breakpoints max per request, stable JSON key order mandatory for cache hits.

**Brain-dump anchors.** Voice → whisper.cpp+Core ML (ANE-accelerated, base.en ~140 MB, RTF 7.9× on M-series) → AFM post-processing → `DataSit` object:
```rust
struct DataSit {
    id: Ulid, raw_text: String, captured_at: DateTime<Utc>,
    source: Source, audio_blob: Option<PathBuf>, transcript_conf: f32,
    sentiment: f32, concepts: Vec<ConceptRef>, anchors: Vec<AnchorRef>,
    embedding: Vec<f32>, fsrs: MemoryState,
    validation: Validation { schema: Ok, redaction: Ok, dup_check: Ok }
}
```
Anchors are stable identities (person, project, theme, question, goal); centroid embedding updated by EMA over linked notes; cosine match >0.82 to existing anchor → link, else propose new in nightly review.

**Audit pass.** `epistemos audit` walks the codebase via `ignore = "0.4"` (BurntSushi/ripgrep walker, gitignore-aware), classifies files by extension + libmagic MIME, converts plain-text/markdown/PDF candidates to `.epdoc` via local-model-as-structurer pipeline, **respects code-file exclusion** (see thirteen non-negotiables #12).

**No-messy-data principle.** Pipeline gates: every `DataSit` must pass `parse → schema_validate → redact → dedupe → anchor_resolve → embed → persist`. Each step pure & idempotent; failures route to quarantine table, never live store. Schema validation via `schemars 1.1` JSON Schema + `jsonschema = "0.18"` runtime validator; `garde` for value-level rules. Ambient retrieval has two thresholds: `τ_show = 0.6` (UI hint), `τ_inject = 0.78` (auto-add to context); never inject below `τ_inject` because hallucinated context is worse than no context.

## §H. Performance architecture

**Swift 6.2 strict concurrency:** Two SwiftPM targets — `EpistemosUI` with `swiftSettings: [.defaultIsolation(MainActor.self)]` (SE-0466), `EpistemosFFI` with `[.defaultIsolation(nil)]` (nonisolated default for raw-pointer plumbing). UniFFI #2818 workaround until fix lands: post-process generated `.swift` to prepend `nonisolated` to all file-level decls via sed; or wait for `[bindings.swift] default_isolation = "nonisolated"` toml knob.

**AsyncThrowingStream cancellation cascade** target <50 ms steady-state:
```
withTaskCancellationHandler 
  → continuation.onTermination = task.cancel() + runtime.cancel_all() 
  → UniFFI cancel_all  
  → tokio root CancellationToken.cancel() 
  → child token cascade
  → child.start_kill() (SIGKILL on Unix) + child.wait()
```
`Command::kill_on_drop(true)` is the safety net; `start_kill + wait` (not `kill().await`) for 5–15 ms reaping. AsyncThrowingStream silently finishes on cancellation (does NOT throw `CancellationError`; forums.swift.org/t/72777) — propagate via `onTermination`.

**MLX KV cache + DispatchSourceMemoryPressure:**
- `.warning`: drop oldest 50% of cached prefixes, shrink quantized KV FP16→4-bit, release attention scratch
- `.critical`: drop all non-active KV, force `MLX.GPU.clearCache()`, unload drafter (~700 MB freed)

**TurboQuant KV cache compression** (Zandieh 2025, arXiv:2504.19874): 3-bit keys + 4-bit values via random Hadamard rotation + Lloyd-Max scalar quant + 1-bit QJL residual, ~3.5 b/value with near-zero quality loss on RULER/LongBench. KIVI fallback (Liu 2024, arXiv:2402.02750) at 2-bit (per-channel keys, per-token values, 32-token FP16 residual) — 2.6× peak memory reduction, 2.35–3.47× throughput gain. **Apply only to full-attention layers**; SSM/linear-attention layers untouched.

**Speculative decoding** with K=5: `mlx-community/speculative-decoding` repo provides a Swift implementation; native DraftTargetPair on Llama-3.2-1B-4bit drafter + Hermes-3-8B-4bit target (vocabulary-matched, ~1.4–1.8× decode speedup expected on M2 Pro). Apple's ReDrafter (`apple/ml-recurrent-drafter`, arXiv:2403.09919) is the SOTA on Apple Silicon (2.3× on Vicuna M2 Ultra) but requires training — defer to v2.

**Metal 4 residency sets + ICB + MetalFX temporal scaler** (WWDC25 sessions 205, 254): `MTLResidencySet` replaces per-buffer `useResource:`; attach to **queue** if contents rarely change, **command buffer** if they change frequently. ICBs continue to work via `MTL4CommandAllocator` + `MTL4ArgumentTable`. MetalFX temporal scaler with `supportsMetal4FX:` capability check for 120 fps graph budget at 10K+ nodes.

**Metal zero-copy graph buffers** via `bytesNoCopy + IOSurface`: page-aligned (4 KiB on arm64 macOS) `posix_memalign` pointer wrapped via `device.makeBuffer(bytesNoCopy: pointer, length: bytes, options: .storageModeShared, deallocator: { free($0) })`. UMA means same physical page is shared CPU/GPU — zero copy across SoC. Verified: RSS delta 0.03 MB vs 16.78 MB for explicit copy on 16 MB buffer (abacusnoir 2026).

**Blelloch scan in Metal for Mamba-2 prefill:** Mamba-2 / SSD reformulates bulk work as matmul (chunk-intra) and uses an associative scan only for segment-sum between chunks. On M-series, **prefer `prefix_inclusive_sum()` SIMD-group intrinsics over textbook Blelloch** (Kieber-Emmons benchmark). Implementation: 1024-element chunks, threadgroup memory upsweep+downsweep, block sums recursively scanned, carry-back per chunk.

**Thermal-aware breaker throttling:** `ProcessInfo.processInfo.thermalState` + `thermalStateDidChangeNotification`. Critical caveat: on Apple Silicon, `ProcessInfo` collapses powermetrics' `moderate` and `heavy` into `.fair`, hiding throttling onset. For fidelity, parallel-read undocumented Darwin notification `com.apple.system.thermalpressurelevel` (5 levels: nominal/moderate/heavy/trapping/sleeping) via `notify_register_dispatch` (UNVERIFIED stability — private OSThermalNotification.h). Policy: `.nominal`→full+K=5; `.fair`→K=3, drop critic round; `.serious`→drafter-only, ef_search 64→32, pause drift passes; `.critical`→breaker open, drain only, modal "Mac is hot".

## §I. Notarization + entitlements (Pro-only Developer ID)

**Entitlements:**
```xml
<key>com.apple.security.cs.allow-jit</key><true/>          <!-- MLX runtime kernel compilation -->
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><false/>  <!-- DO NOT enable -->
<!-- sandbox: not present (non-sandboxed Pro build) -->
<!-- library-validation: leave at default (ON under Hardened Runtime) -->
```

**Info.plist TCC keys:** `NSAccessibilityUsageDescription`, `NSScreenCaptureUsageDescription`, `NSAppleEventsUsageDescription`, `NSMicrophoneUsageDescription` (voice dictation), `NSInputMonitoringUsageDescription` (global hotkey beyond Carbon).

**Inside-out codesign WITHOUT --deep:** depth-first signing (deepest dylibs first, then helpers, then frameworks, then main bundle last) preserves per-binary entitlements; `--deep` re-signs everything with same identity, corrupting nested helpers (Apple TN3161/TN3125).
```bash
find MyApp.app -type f \( -name "*.dylib" -o -perm +111 \) | awk '{print length,$0}' | sort -rn | cut -d" " -f2- \
  | while read f; do codesign --force --options runtime --timestamp --entitlements "$ENT" \
                              --sign "Developer ID Application: …" "$f"; done
codesign --force --options runtime --timestamp --entitlements MyApp.entitlements \
         --sign "Developer ID Application: …" MyApp.app
ditto -c -k --keepParent MyApp.app MyApp.zip
xcrun notarytool submit MyApp.zip --keychain-profile "AC_PROFILE" --wait
xcrun stapler staple MyApp.app
spctl -a -vvv -t install MyApp.app   # expect: source=Notarized Developer ID
```

**TCC prompt sequencing:** stagger first-launch requests behind feature use, never trigger an avalanche on first launch; cache permission state in user defaults to detect denials and surface re-request UI gracefully.

**EndpointSecurity infeasible for solo dev** (`com.apple.developer.endpoint-security.client` requires manual Apple approval, typically months for indie shops, denied unless EDR/security vendor + System Extension wrapper + root). Use **portable-pty middleman** (wezterm, v0.9.0): only sees processes user explicitly launches under Epistemos — exactly the right scope for a cognitive runtime.

## §J. Open-source disruption strategy (Epistemos Provenance Standard)

Bifurcated repo:
- **Public sibling repo `epistemos-provenance-standard`** (Apache 2.0): JSON Schemas (`run_event.v{N}.schema.json`, `mutation_envelope.v{N}.schema.json`, `agent_event.v{N}.schema.json`, `graph_event.v{N}.schema.json`), `epistemos-hermes-mcp` Rust binary source, `epistemos-trace verify` CLI source, golden-trace fixtures.
- **Proprietary monorepo `BlickandMorty/Epistemos`**: Swift app, Metal renderer, cognition layer (Research Kernel, AutoResearch, Deep Deliberation, Belief Drift), MLX integrations, manifest compiler.

The Standard is what other agent runtimes can adopt — making Epistemos's provenance format the lingua franca even when users don't run the Epistemos app. This is the moat that compounds.

---

# PART II — IMPLEMENTATION COOKBOOK

For every dossier item: state-of-the-art summary with citations, 2–4 implementation approaches, favored pick + defense, risks + mitigations, verification experiment.

## R14 — UniFFI 0.28 → 0.29.5 + Issue #2818

**SOTA.** UniFFI 0.29.5 (latest stable Apr 2026) removes `UniffiCustomTypeConverter` (now `custom_type!` macro), changes UDL external-type syntax, makes generated Swift protocols `Sendable` (#2450). Issue #2818 documents Xcode 26 / Swift 6.2 default `MainActor` isolation breaking generated bindings: generated code uses raw pointers, `deinit`, synchronous C interop that cannot be actor-isolated. ([github.com/mozilla/uniffi-rs/issues/2818](https://github.com/mozilla/uniffi-rs/issues/2818))

**Approaches:**
1. **Sed pipe in build script** — post-process generated Swift to prepend `nonisolated` to all file-level decls. Brittle, version-coupled.
2. **Two-target SwiftPM split** — `EpistemosFFI` with `.defaultIsolation(nil)`, `EpistemosKit` with `.defaultIsolation(MainActor.self)`. Clean separation; Sendable types bridge.
3. **Wait for upstream fix** — `[bindings.swift] default_isolation = "nonisolated"` toml knob (proposed in #2818).
4. **Hand-roll FFI without UniFFI** for hottest types — keep UniFFI for cold types only.

**Pick: #2 + #1 as bridge.** Two-target split is the right architecture regardless; sed pipe handles the residual until upstream lands the toml knob.

**Risks/mitigations:** UniFFI #2448 (async generated code not Sendable) — track and patch. UniFFI #2653/#2646 (`framework module` vs `module` modulemap) — switch to plain `module` for SPM consumability.

**Verify:** Build with `-warnings-as-errors`, run `cargo +stable test -p epistemos-ffi`, instantiate one Rust type from `EpistemosUI`, capture isolation-warning count = 0.

## R15 — Benchmark harness

**SOTA.** Rust `criterion` for Rust-side; XCTest performance + `XCTMeasureOptions` for Swift; instruments-cli for Metal.

**Approaches:**
1. **Single bench binary** with subcommand routing (`epistemos-bench afm | mlx | sqlite-vec | uniffi`).
2. **Per-bench-target** with shared fixtures crate.
3. **`hyperfine`-driven external timing** — easy but doesn't capture per-stage breakdown.

**Pick: #2.** Per-target gives crisp `cargo bench -p instant-recall` ergonomics; fixtures crate (`epistemos-bench-fixtures`) seeds 100k-vector corpus, 10k-doc FTS5 corpus, 1k AFM @Generable test cases.

**Targets:**
- AFM @Generable latency (p50/p95/p99 over 1k structured-extraction calls)
- MLX Qwen3-0.6B-4bit token rate under thermal pressure (.nominal vs .fair vs .serious)
- sqlite-vec KNN p50 at 100k vectors @1024-dim
- UniFFI callback throughput (calls/sec for `Vec<u8>` payloads at 1KB/64KB/1MB)

**Risks:** thermal state shifts mid-bench. Mitigation: run on AC, monitor `ProcessInfo.thermalState`, abort + re-run if state drifts; report `temp_state_at_start`/`_at_end`.

**Verify:** golden-file p50 numbers in `benches/golden/v1/` checked by CI; alert if drift > 10%.

## R16 — Phase 13 ETL Rust crawler

**SOTA.** `apalis-sqlite 1.0.0-rc.7` (SQLite-backed job queue, hook-based pickup), `ignore 0.4` (gitignore-aware walker), `xxhash-rust 0.8` (xxh3 fingerprinting ~40 GB/s on Apple NEON), AFM `@Generable` sidecar for structured extraction.

**Pipeline:**
```rust
WalkBuilder::new(root)
  .add_custom_ignore_filename(".epistemosignore")
  .threads(num_cpus::get_physical())
  .build_parallel()
  → fingerprint via xxh3_128 (skip if unchanged in `crawl_state` table)
  → MIME classify (libmagic) → code-file exclusion gate (§non-negotiable #12)
  → enqueue apalis job: { path, fingerprint, mime }
  → worker: parse → AFM @Generable extract front-matter → emit .epdoc sidecar
  → embed via bge-small-en-v1.5 → upsert HNSW + FTS5
```

**Pick:** `apalis-sqlite` `SqliteStorageWithHook` for sub-poll-interval pickup, `concurrency(4)` per worker on M2 Pro 10-core, `RetryPolicy::retries(5)` with exponential backoff.

**Risks:** runaway crawl on /. Mitigation: hard `--max-depth 16`, `--max-files 100k` per session, opt-in only.

**Verify:** crawl 10k-file repo twice; second run should re-process 0 files (xxh3 cache hit); golden assertion.

## W9.6 — Cost dashboard + per-session budget gate

**SOTA.** Cursor `/cost` slash command, Claude Code SDK `modelUsage` map per query, Aider `AIDER_MAX_CHAT_HISTORY_TOKENS`, Continue.dev proposal #10567.

**Schema:**
```sql
CREATE TABLE llm_calls (id TEXT PK, session_id TEXT, model TEXT, role TEXT,
  prompt_tok INT, completion_tok INT, cache_read INT, cache_create INT,
  cost_usd REAL, latency_ms INT, ts INTEGER);
CREATE INDEX llm_session_ix ON llm_calls(session_id, ts);
```

**Three thresholds:** Soft 80% (banner), Throttle 95% (downgrade non-critical roles to drafter), Hard 100% (refuse new calls except synthesizer-flush, emit `BudgetExceededEvent`).

**Pick:** transactional gate co-located with the `Provider::call` site so it cannot be bypassed; cache hits priced at 10% (Anthropic) or 25% (others) of fresh input rate.

**Risks:** model price changes mid-session. Mitigation: pin pricing version in `model_pricing` table updated daily from a trusted source (e.g., LiteLLM mirror).

**Verify:** simulate 100-call session, assert dashboard total within ±2% of provider invoice.

## W9.7 — Vault sidebar selector (per-model vaults)

**SOTA.** Synthesis of Obsidian vault model + Cursor per-workspace settings; no canonical reference (UNVERIFIED — Epistemos-specific).

**Pick:** sidebar lists vaults `(corpus_root, embedder_id, retrieval_index)`; one primary, optional secondaries (read-only context with vault-source badge); drag-attach to chat composer for one turn; model switch clears secondaries with incompatible embedder dims; per-vault drift dot.

**Risks:** embedder mismatch silently merges wrong vector spaces. Mitigation: compile-time `EmbedderProfile` tag on every vector index file; runtime mismatch → reject + re-embed prompt.

**Verify:** integration test attaches secondary vault with incompatible embedder, asserts merge refused.

## W9.8 — Approval modal (PausedForApproval surface)

**SOTA.** Cursor allowlist + `is_background` + diff preview; Cline Auto-approve toggle; LangFlow `require_approval` boolean.

**Pick:** typed `PendingAction` carrying `(toolName, description, sensitivity, blastRadius, revertibility, argsCanonicalJSON, modelHash, promptHash)`; UI shows description, blast targets, diff preview when applicable; "Allowlist this exact (tool, args-shape) for the session" — opt-in, never default-on for `.irreversible`. All approval events (`approvalRequested/Granted/Denied`) on the same RunEventLog stream so replay reproduces decisions.

**Risks:** approval fatigue → user click-throughs. Mitigation: progressive disclosure, sensitivity-color-coded, low-sensitivity allowlist sticks.

**Verify:** UI test simulates 10 approvals, replay log reproduces same final state byte-for-byte.

## W9.10 — TurboQuant KV cache compression (W9.30 KIVI alternative)

**SOTA.** TurboQuant (Zandieh 2025, arXiv:2504.19874): random Hadamard rotation + Lloyd-Max + 1-bit QJL residual; ~3.5 b/value with near-zero quality loss on RULER/LongBench/Gemma+Mistral. KIVI (Liu 2024, arXiv:2402.02750): per-channel keys + per-token values + 32-token FP16 residual, 2-bit, tuning-free, 2.6× peak memory reduction.

**Pick: TurboQuant TQ3-keys / TQ4-values primary, KIVI as fallback.** TurboQuant has better quality at 3.5 b; KIVI has wider deployment maturity (HF Transformers integration). Apply only to full-attention layers, never SSM.

**Risks:** Kitty paper (arXiv:2511.18643) shows KIVI-K2V2 collapses on Qwen3 reasoning. Per-model-family validation mandatory before shipping ≤2-bit.

**Verify:** Needle-in-a-Haystack at 64K context with TQ3/TQ4 vs FP16 baseline; assert recall delta <2%.

## W9.11 — Create ML personalized embeddings

**SOTA.** Apple's CreateML does not ship a first-party `MLEmbeddingTrainer` as of macOS 26 (UNVERIFIED — probe release notes). `NLEmbedding` is read-only.

**Pick: MLX-based on-device LoRA on bge-small-en-v1.5.** 33M-param encoder fine-tunes in <2 GB on M2 Pro. Pairs from user's notes: (note, tag), (snippet, AFM-summary). NT-Xent / InfoNCE τ=0.05, AdamW lr=1e-5, batch 32, 1–3 epochs, ~100k pairs nightly. Save LoRA adapter weights only (few MB) per user; merge for serving.

**Risks:** distribution shift early-life when user has <1k notes. Mitigation: defer fine-tune until ≥1k notes accumulated; until then, use frozen bge-small.

**Verify:** held-out retrieval recall@10 before/after; require ≥3 pp improvement to ship adapter.

## W9.12 — Orphan Knowledge Rediscovery (Night Brain digest)

**SOTA.** networkx `connected_components` + Personalized PageRank; HippoRAG (Gutiérrez 2024) PPR-with-node-specificity.

**Pick:** nightly job: build graph (notes/anchors as nodes, explicit + implicit cosine ≥ 0.78 edges); orphans = singletons or size-1–2 components untouched 30+ days; resurface score `0.4·(1−PPR) + 0.3·(1−E[θ]) + 0.3·days_since · exp(−R_FSRS) + 0.2·novelty_to_today`; emit 5–10 picks per morning with one-line "why now" rationale (LLM-generated, cached).

**Risks:** noise. Mitigation: user can mark "let it fade" → records FSRS Again rating, decays harder.

**Verify:** seed graph with 100 known orphans, assert ≥80 surface within 7 days.

## W9.13 — Daily Notes UI + FSRS-6 surfacing

**SOTA.** FSRS-6 21-parameter scheduler (Anki ≥25.07), Half-Life Regression as cold-start fallback (Settles & Meeder 2016), Bayesian Beta-Bernoulli for engagement probability.

**Pick:** Engagement signals → synthetic FSRS rating mapping (no explicit grading UI):
```rust
fn engagement_to_rating(open_ms: u32, scrolled_pct: f32, edited: bool, dismissed: bool) -> Rating {
    if dismissed && open_ms < 500 { Rating::Again }
    else if open_ms < 2_000 || (!edited && scrolled_pct < 0.5) { Rating::Hard }
    else if edited { Rating::Good }
    else if open_ms > 30_000 { Rating::Easy }
    else { Rating::Good }
}
```
Surfacing score: `0.45·ambient_sim + 0.20·(1−R_FSRS) + 0.15·anchor_overlap + 0.10·E[θ] + 0.05·meta_depth + 0.05·novelty`. MMR diversification λ=0.7. Sections: Carry-forward / Due to forget / Ambient mentions / Night Brain.

**Risks:** FSRS optimizer needs ≥1k revlogs for stability. Mitigation: use HLR (Settles formula `p̂ = 2^(−Δ/h)`, `MIN_HALF_LIFE=15min`, `MAX_HALF_LIFE=274d`) until threshold; auto-switch.

**Verify:** simulate 30-day usage on synthetic corpus; assert FSRS-derived schedule converges to optimal (RMSE vs offline-optimized <0.05).

## W9.14 — Block References + Transclusion (Tiptap/ProseMirror)

**SOTA.** `@tiptap/extension-unique-id 3.x` (Tiptap Pro) persists `data-id` per block. Critical collab rule: editor MUST mount only after collab provider syncs, else default empty paragraph gets ID, then synced state arrives, leaving ghost paragraphs.

**Pick:**
```ts
UniqueID.configure({
  types: ['paragraph','heading','blockquote','codeBlock'],
  attributeName: 'id',
  generateID: () => `block-${crypto.randomUUID()}`,
  filterTransaction: (tr) => !isChangeOrigin(tr),  // ignore remote
  enableInDoc: true,
})
```
Custom Transclusion node `<transclude target="noteId#blockId"/>`; render-time resolves to live snapshot via `editor.state.doc.descendants` walk; strip front-matter on transclusion (Obsidian forum convention).

**Risks:** Vitest multi-version `prosemirror-model` breaking unique-id (#6171). Mitigation: import via `@tiptap/pm/model` re-export only.

**Verify:** create 100 transclusions across 50 docs, mutate source blocks, assert all transclusions resolve correctly post-mutation.

## W9.15 — Static compile-time view routing macro

**SOTA.** Swift macros (SE-0382, Swift 5.9+); `ReerRouter` uses Mach-O `__DATA,__rerouter_vc` section pattern with `@_used @_section`; pure-SwiftUI compile-time enum approach is simpler.

**Pick:** `@RoutableEnum` attached member macro that synthesizes `static func destination(for: Self) -> some View` switch + missing-case → compile error. Pure Swift, zero runtime registration.

```swift
@RoutableEnum
enum AppRoute: Hashable {
    case home
    case note(id: UUID)
    case settings(tab: SettingsTab)
}
// expands to:
extension AppRoute {
    @ViewBuilder static func destination(for r: Self) -> some View {
        switch r {
        case .home: HomeView()
        case .note(let id): NoteView(id: id)
        case .settings(let tab): SettingsView(initialTab: tab)
        }
    }
}
```

**Risks:** non-exhaustive switch on case addition — actually a feature here.

**Verify:** add a case without view; assert build fails with explicit diagnostic.

## W9.21 — Honest FFI (Arc::into_raw + ~Copyable)

**SOTA.** `Arc::into_raw` + `Arc::from_raw` exactly-once contract; `Arc::increment_strong_count(ptr)` for borrow-without-take; Swift 5.9+ `~Copyable` for compile-time UAF prevention.

**Pick:**
```rust
#[derive(uniffi::Object)]
pub struct MlxRuntime { inner: Arc<MlxCore> }
```
```swift
public struct RustHandle: ~Copyable {
    private let ptr: OpaquePointer
    init(_ p: OpaquePointer) { self.ptr = p }
    deinit { uniffi_mlxruntime_free(ptr) }
    consuming func consume() -> OpaquePointer { let p = ptr; discard self; return p }
}
```
Apply `~Copyable` outer wrapper to: DB connection, MLX runtime context, subprocess controller. Hand-craft, since UniFFI doesn't yet emit them.

**Risks:** double-free if UniFFI auto-emits a non-`~Copyable` wrapper too. Mitigation: feature-gate UniFFI auto-wrapper for these specific types; ship `~Copyable` outer only.

**Verify:** ASAN run with intentional double-take attempt → compile error (not runtime crash).

## W9.22 — Typestate Islands for MLX/subprocess lifecycles

**SOTA.** `PhantomData<State>` + zero-sized state types; transitions consume `self`. UniFFI cannot directly export typestate; hide behind internal enum.

**Pick:**
```rust
pub struct Idle; pub struct Loaded; pub struct Generating; pub struct Drained;
pub struct MlxSession<S> { ctx: *mut mlx_ctx_t, _s: PhantomData<S> }
impl MlxSession<Idle> {
    pub fn load(self, w: &Path) -> Result<MlxSession<Loaded>, Err> { /* */ }
}
impl MlxSession<Loaded> {
    pub fn generate(self, p: &str) -> MlxSession<Generating> { /* */ }
}
// public API hides typestate behind enum + Result-returning methods
```

**Risks:** API verbosity. Mitigation: confined to `MlxRuntime`, `SubprocessController`, `RunSupervisor`.

**Verify:** add deliberately-invalid transition; assert compile error.

## W9.23 — Bit-packed circuit breaker (AtomicU64)

**SOTA.** `fetch_update` for lock-free CAS, AcqRel/Acquire ordering; `portable-atomic 1.x` for cross-arch AtomicU64/U128.

**Pick:** pack `state(2 bits) | failure_count(20) | success_count(20) | last_failure_ms(22)` into one `AtomicU64`. State Closed→Open→HalfOpen→Closed monotonically progresses + monotonic timestamps make ABA safe.

```rust
pub fn record_failure(&self, now_ms: u64) {
    let _ = self.word.fetch_update(AcqRel, Acquire, |w| {
        let fails = ((w >> FAIL_SHIFT) & FAIL_MASK) + 1;
        let mut new = w & !((FAIL_MASK << FAIL_SHIFT) | TS_MASK);
        new |= (fails & FAIL_MASK) << FAIL_SHIFT;
        new |= now_ms & TS_MASK;
        if fails >= self.fail_threshold {
            new = (new & !(0b11 << STATE_SHIFT)) | ((State::Open as u64) << STATE_SHIFT);
        }
        Some(new)
    });
}
```

**Risks:** 22-bit timestamp wraps every ~70 min. Mitigation: store relative-to-bootstrap-epoch.

**Verify:** loom test asserts no torn-read across 100k concurrent failures.

## W9.24 — Metal zero-copy graph buffers

**SOTA.** `bytesNoCopy` + IOSurface verified zero-RSS on UMA (abacusnoir 2026). Page alignment 4 KiB on arm64 macOS.

**Pick:**
```swift
var p: UnsafeMutableRawPointer? = nil
posix_memalign(&p, 4096, bytes)
let buf = device.makeBuffer(bytesNoCopy: p!, length: bytes,
    options: .storageModeShared, deallocator: { p, _ in free(p) })!
let mlxArray = MLXArray(buffer: buf, shape: [1024,1024], dtype: .float32)
```
For cross-API/cross-process, `IOSurface` + `device.makeTexture(descriptor:iosurface:plane:)`.

**Risks:** texture row alignment varies per pixel format. Mitigation: query `MTLDevice.minimumLinearTextureAlignment(for:)` at init.

**Verify:** Instruments allocations panel shows zero copy; RSS delta vs explicit-copy path < 100 KB on 16 MB buffer.

## W9.25 — Grammar-constrained logit masking (mlx-swift-structured)

**SOTA.** Outlines (DFA-based), llama.cpp GBNF, lm-format-enforcer (character-level + tokenizer prefix tree). Apple Foundation Models `@Generable` is built-in constrained decoding via OS-managed token masking.

**Pick: AFM `@Generable` for typed Swift outputs (free, type-safe); otriscon/llm-structured-output's `JSONSchemaAcceptor` for MLX paths.** No first-party `mlx-swift-structured` package as of late 2025 (UNVERIFIED — probe github.com/ml-explore/mlx-swift-examples/issues/221).

**Risks:** Outlines compilation slow on complex schemas. Mitigation: precompile schemas at app startup, cache DFAs.

**Verify:** generate 1000 tool calls under schema, assert 100% parse rate without retries.

## W9.26 — B-tree text rope (crop crate + UTF-16 metrics)

**SOTA.** `crop 0.4` (noib3) — UTF-8 byte-indexed B-tree rope with `Arc`-shared O(1) clones, `utf16-metric` cargo feature for SwiftUI bridging.

**Pick:**
```toml
crop = { version = "0.4", features = ["utf16-metric"] }
```
```rust
pub extern "C" fn rope_byte_at_utf16(rope: &Rope, utf16_idx: usize) -> usize {
    rope.byte_of_utf16_code_unit(utf16_idx)
}
```
SwiftUI `NSRange` (UTF-16) → byte offsets via FFI; AttributedString as render-side view, never source of truth.

**Risks:** Ropey/Jumprope alternatives — Ropey is char-indexed (mismatched), Jumprope lacks O(1) clone (no background snapshotting). Crop is unambiguous.

**Verify:** Quickcheck-style fuzz: 10k random insert/delete on rope, assert UTF-16 round-trip preserves all offsets.

## W9.27 — Append-only OpLog + replay (event-sourced graph)

**SOTA.** SQLite WAL for canonical OpLog (single-file vault UX); fjall 3.0 LSM for ultra-high-throughput logs (>100k events/sec sustained).

**Pick: SQLite WAL** for Epistemos. `journal_mode=WAL, synchronous=NORMAL, foreign_keys=ON, busy_timeout=5000, wal_autocheckpoint=1000`. ULID PK for monotonic time-sortable ID. Snapshot at every `SessionCheckpoint` event variant; on replay load latest snapshot ≤ target seq, replay tail.

**Risks:** WAL fails on NFS/CIFS. Mitigation: vault must be on local FS; refuse to open with diagnostic.

**Verify:** `epistemos-trace verify` rebuilds graph from log, asserts byte-identical to live state; run twice with shuffled directory listings, assert byte-identical.

## W9.28 — Blelloch scan in Metal for Mamba-2 prefill

**SOTA.** Blelloch 1990 work-efficient scan; SIMD-group `prefix_inclusive_sum()` intrinsics on Apple Silicon often beat textbook Blelloch (Kieber-Emmons). Mamba-2/SSD reformulates bulk as matmul; segment-sum is the only hand-tuned scan needed.

**Pick:** SIMD-group intrinsic for chunks ≤32; Blelloch for larger threadgroups (1024 elems with shared memory upsweep+downsweep, block-sums recursively scanned, carry-back per chunk).

**Risks:** Mamba-2 community models without working MLX path (Zamba2 etc) — defer SSM faculty until kernel landing.

**Verify:** unit test scan correctness on `[1,1,1,...]` length 8192 against `Vec::iter().scan()` baseline.

## W9.29 — Thermal-aware breaker throttling

**SOTA.** `ProcessInfo.processInfo.thermalState` + `thermalStateDidChangeNotification`; private Darwin `com.apple.system.thermalpressurelevel` for 5-level fidelity.

**Pick:** `ThermalBreaker` Swift class observes both; policy table (§H above). Probe undocumented notification via `notify_register_dispatch` (UNVERIFIED stability — flag as optional best-effort).

**Risks:** policy churn on thermal flap. Mitigation: 30-second hysteresis on transitions.

**Verify:** synthetic load drives `.serious`; assert generation degrades to drafter-only within 1 second.

## Brain-dump features as first-class (Phase 3)

These were covered in §F–G of the master doctrine. The cookbook entries:

**Epoch-decay raw thoughts:** FSRS-6 (`fsrs-rs` Rust core) primary; HLR cold-start fallback. Schema in §G. Synthetic engagement → rating mapping in W9.13.

**Hierarchical concept ontology:** WordNet/ConceptNet seed → AFM `@Generable ConceptExtraction` per write → TaxoGen adaptive split when parent>5 children with low cosine cohesion → NetTaxo joint induction at ≥30 backlinks.

**Depth markers + nested meta:** §G compute pipeline, queryable SQL index.

**Smart session summarization:** Anthropic prompt caching (`cache_control: ephemeral`, 1h TTL on schema, 5m on ontology, 4 breakpoints, stable JSON key order) + AFM streaming summarization with `T.PartiallyGenerated` snapshots. SSM summarization explicitly rejected (Jelassi 2024 associative-recall degradation).

**Model overnight metabolization:** `mlx_lm.lora` nightly with replay buffer 30–50% canonical notes, EWC penalty with single accumulated Fisher (Huszár 2017 correction), GRPO reward decomposition over verifiable structural correctness (schema-pass / keyword-recovery rewards).

**Brain-dump-anywhere button:** AVAudioEngine tap → 16kHz mono Float32 → whisper.cpp+Core ML (base.en, ANE-accelerated) → AFM `@Generable RawDump` post-process → `DataSit` object → pipeline gates → persist.

**Structured-file ontology:** `.epdoc` package (§G), ProseMirror JSON canonical body, YAML front-matter, jsonld escape hatch for schema.org interop.

**Structured-data audit pass:** `epistemos audit` walker (R16 pipeline reused), code-file exclusion gate (non-negotiable #12).

**Code-file embedding exclusion:** MIME + extension allowlist (`text/markdown`, `text/plain`, `text/x-org`); reject `text/x-*-source`, `application/json`, etc.; sidecar-only metadata (e.g., `foo.rs.epdoc` next to `foo.rs`).

**Local-model-as-structurer:** AFM `@Generable` primary (free, on-device, type-safe via constrained decoding); Qwen3-4B-Instruct-2507-4bit fallback when AFM 4K context exceeded; two-step extract-then-validate pattern with `jsonschema` retry on validation failure.

**No-messy-data principle:** §G pipeline gates + ambient retrieval thresholds.

**Conversation-as-structured-context:** A-MEM + HippoRAG + MemGPT hybrid; sidecar JSON read by model mid-conversation (cached aggressively).

**AFM + Qwen3 + SSM + Hermes bridging:** AFM utility, Qwen3-4B-Instruct-2507 fast tool-routing (Tier B swap), Llama-3.2-1B drafter (vocabulary-matched), Hermes-3 8B agent brain. SSM (FalconMamba-7B-Instruct-4bit) is rare long-context streamer only — defer until benchmark proves a real workload needs it.

---

## Critical proposals not in original brief

**Proposal 1 — Vocabulary-matched drafter (mandatory).** The brief specified Qwen3-0.6B drafter for Hermes-3 8B target. This is **architecturally broken**: Qwen tokenizer ≠ Llama-3 tokenizer. Use `Llama-3.2-1B-Instruct-4bit` instead. Non-negotiable.

**Proposal 2 — `epistemos-trace verify` as the public credibility lever.** Ship this CLI in the open Provenance Standard repo on day 1. It's the cheapest way to convert "manifesto" → "format other people can adopt." Validates schema, hash chain, sequence monotonicity, causality, status invariants, redaction completeness, state-machine validity, reversibility soundness. SARIF output for CI integration.

**Proposal 3 — CBOR-deterministic, not JSON, for hashing.** JSON has multiple representations of the same value (key order, whitespace, number formatting). Hash over **CBOR with deterministic encoding** (RFC 8949 §4.2); render JSON only at human/API boundaries.

**Proposal 4 — Ban TurboQuant ≤2.5b per-model-family without re-validation.** Kitty paper shows KIVI-K2V2 collapses on Qwen3 reasoning. Per-model NIAH validation gate before shipping any sub-3-bit KV configuration. Add to CI.

**Proposal 5 — Two thresholds on ambient retrieval (`τ_show=0.6, τ_inject=0.78`).** Hallucinated context is worse than no context. The single-threshold approach in most RAG systems silently injects garbage; explicit two-threshold is the small change with outsized correctness gain.

**Proposal 6 — Adjudicator must be different model family than Proposer.** Multi-agent debate is hijackable by confident wrong agents (Nature 2026). Cross-family mitigation is the cheap structural fix.

**Proposal 7 — Probe `com.apple.system.thermalpressurelevel` despite being private.** `ProcessInfo.thermalState` collapses moderate+heavy into `.fair`, so by the time you see `.serious` you've already been throttling for minutes. Best-effort probe of the private notification gives the breaker the granularity to react at actual onset. Flag as optional + UNVERIFIED stability.

---

## The thirteen non-negotiables

1. **No runtime SwiftUI codegen from LLM output.** Closed catalog only. LLMs generate JSON; the JSON drives compile-time-known components.
2. **No user-facing fallback inspector for unknown schemas.** DEBUG quarantine renderer only; in Release, unknown schema = explicit error event.
3. **No silent backend switching.** Provider switch is always a typed event, badge-visible per message.
4. **No silent cloud escalation.** Local→cloud transition requires explicit budget threshold or user opt-in; never automatic.
5. **No silent file mutation.** Every write is a `MutationEnvelope` with reversibility classification and approval-id (where applicable).
6. **No NotificationCenter for graph or render invalidation.** Typed `GraphEvent`/`AgentEvent` projections only; NotificationCenter is forbidden in render and graph paths.
7. **No `@unchecked Sendable` lies.** Where used, must wrap genuinely-synchronized state (e.g., `os_unfair_lock`); reviewer must sign off per usage.
8. **No string-keyed dispatch in render or token loops.** `repr(u8)` enums on the Rust side, exhaustive Swift `switch` on the UI side.
9. **No proxying of user OAuth tokens through Epistemos backend.** All provider auth lives in user keychain or local config; Epistemos servers (if any) never see them.
10. **No multi-agent worktree mutation.** One agent owns the tree at a time; concurrent agents work in disjoint sandboxes (Wasmtime/Bollard).
11. **No "we'll add provenance later."** Provenance is the spine, not the polish. Phase 0 ships the four-layer event model.
12. **No code-file embedding** (markdown/plain text only). Code files corrupt embedding spaces; sidecar-only metadata for them.
13. **No messy data fed to models without structuring pass first.** Local-model-as-structurer or AFM `@Generable` extraction is mandatory before any persistence; raw thoughts are the *only* unstructured channel and they're tagged accordingly.

---

## Raw-thoughts appendix (Jojo's brain dumps as canonical first-class concepts)

These eleven concepts are the design DNA; every architectural decision must serve them.

1. **Epoch-decay raw thoughts.** Notes degrade in *retrievability* over time without engagement, while preserved verbatim. FSRS-6 retrievability `R(t,S) = (1 + FACTOR·t/S)^DECAY` is the primary primitive; HLR is the cold-start fallback; Bayesian Beta-Bernoulli updates engagement probability with daily decay ρ=0.98; "ghost weight" multiplier `score = f·R_FSRS·E[θ]·(1−drift_penalty)` lowers retrieval probability without ever deleting. The note is sacred; the salience is mortal.

2. **Hierarchical concept ontology.** Real ontology, not flat tag clouds. Phenomenology → cognitive neuroscience → basal ganglia must nest properly. Bootstrap from WordNet/ConceptNet, grow via AFM `@Generable` extraction at write-time, restructure via TaxoGen-adaptive-split when child sets bloat with low cohesion, augment via NetTaxo joint text+network induction once backlinks accumulate. Concepts are typed graph nodes; parent-of/related-to/instance-of are typed edges; ontology evolves as the user's thinking evolves.

3. **Depth markers + nested meta-analysis markers.** Every note, raw thought, task, session, connection carries a depth/complexity vector — Flesch-Kincaid for readability, dependency-parse depth for syntactic density, epistemic-depth (claim→evidence→counter chain) for argumentative depth, meta_order (regex+AFM confirm) for thoughts-about-thoughts. Queryable: "show my deepest meta-thoughts of last week." Depth is information; sort and filter by it.

4. **Smart session summarization.** Hierarchical map-reduce (chunk→summary→super-summary) with citation traceback, Anthropic prompt caching (1h on rarely-changing schema, 5m on session ontology, 4 breakpoints, stable JSON key order), AFM streaming `PartiallyGenerated` snapshots for typed UI updates. SSM-based summarizers explicitly rejected — they degrade on associative recall (Jelassi 2024). System prompts as JSON contexts, deterministic key order, cached aggressively.

5. **Model overnight metabolization.** Karpathy framing — "never absorb information without predicting it first" — operationalized as nightly LoRA micro-finetune via `mlx_lm.lora`, with 30–50% replay buffer of canonical notes, EWC regularization (single accumulated Fisher per Huszár 2017), GRPO reward decomposition over verifiable structural targets (schema-pass, keyword-recovery). A "memory consolidation folder" stores re-understood prompts, weighted emotional depth, salience importance. Catastrophic forgetting is prevented by replay; harmful drift is prevented by GRPO's verifiable rewards.

6. **Brain-dump-anywhere button.** Voice or text from any chat surface, not just notes. Whisper.cpp+Core ML on Apple Silicon (RTF 7.9× on M-series); AFM transcription post-process via macOS 26 SpeechAnalyzer/SpeechTranscriber; emotional anchor extraction via NLTagger sentiment + AFM `@Generable` for finer affect; the result is a typed `DataSit` object passing through the pipeline gates before persistence. The button is a portal; the structure is the destination.

7. **Structured-file ontology for AI consumption.** Plain text/markdown/PDF are wrong substrates for AI consumption. The right substrate is `.epdoc`: ProseMirror JSON canonical body + YAML front-matter with emotional anchors + depth signals + concept refs + provenance refs + optional decay state and salience. Schema.org JSON-LD escape hatch for web interop. The model reads structured context, not prose; the prose is for humans.

8. **Structured-data audit pass.** Codebase-wide walker (`epistemos audit`) classifies every file, converts plain-text/markdown/PDF candidates to `.epdoc`, respects code-file exclusion, never overwrites without approval. The pass is idempotent and replayable — running it twice should produce the same conversions.

9. **Code-file embedding exclusion.** Code files corrupt embedding spaces because their token distributions are pathological. Markdown and plain text only get embedded; everything else gets sidecar-only metadata (`foo.rs.epdoc` next to `foo.rs`). MIME-type allowlist + extension fallback, never blocklist.

10. **Local-model-as-structurer.** Local model takes raw input, emits structured file. Raw goes to raw-thoughts pipeline (decay-tagged) or is discarded. AFM `@Generable` primary because constrained decoding guarantees schema validity; Qwen3-4B-Instruct-2507-4bit fallback when AFM's 4K context exceeded; two-step extract-then-validate with `jsonschema` retry on validation failure. The model converts; the deterministic pipeline persists.

11. **No-messy-data principle.** Everything structured deterministically. Models cannot deliberate on structure mid-process — structure decisions are made before generation, by deterministic gates. Raw thoughts are the *only* unstructured channel and are tagged as such (depth signals, decay state, no embedding); ambient retrieval has two thresholds (τ_show=0.6 for UI hint, τ_inject=0.78 for context injection); below τ_inject means do not pollute model input. Confidence and structure are co-required; one without the other is noise.

12. **Conversation-as-structured-context.** Conversation history auto-saves as JSON sidecar the model reads mid-conversation. Per-turn fields: role, content_redacted, sentiment, depth, concept_refs, anchor_refs, timestamp, latency_ms. Hybrid memory architecture: A-MEM-style note evolution at write-time, HippoRAG Personalized PageRank for ambient retrieval at session start, MemGPT-style explicit `recall_*` tools for user-driven search. More robust than regular history because it carries epistemic and emotional context, not just text.

---

This doctrine is the trellis. The next vine that grows on it is Phase 0: publish the moats that flip Missing → Partial in ascending difficulty — manifest compiler, A2UI catalog enum, provenance-core crate with replay CLI. Earn the first three; the next nine become tractable.