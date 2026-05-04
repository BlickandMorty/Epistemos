# Ambient Recall Halo — Master Plan

> **Index status**: DEFERRED-RESEARCH — design spec for Phase H (Ambient Recall), downstream of Phase R, upstream of Phase S. **Not canonical doctrine** — read when implementing Phase H, not before. Linked from [`docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`](IMPLEMENTATION_PLAN_FROM_ADVICE.md). Classified in [`docs/_INDEX.md §8`](_INDEX.md).

**Status:** Design-locked. Execution-blocked on Phase R closure.
**Date:** 2026-04-24
**Owner:** Jordan
**Synthesis of:** four independent research passes — Claude (`claude ambient.md`), GPT (`gpt advice` + `deep-research-report (2).md`), Gemini (`gemini ambient.txt`), the Epistemos V1 verdict (`EPISTEMOS_V1_DECISION.md`), plus Jordan's own implementation brainstorm with codebase audit (2026-04-24). Reference starters: `epistemos_shadow.rs`, `HaloController.swift`.
**Slots into:** [docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md](IMPLEMENTATION_PLAN_FROM_ADVICE.md) as **Phase H**, downstream of Phase R Resource Runtime Hardening, upstream of Phase S App Store hardening.

---

## 0. The one-line stand

**Ship one feature so well it feels inevitable: an Ambient Recall Halo that surfaces the half-shadow of every relevant thought beside the cursor — instant, local, private, impossibly smooth.**

Everything else V1 ships is in support of that. Computer use, GEPA, CRDT, EMMET, R2F, Mirror-SD, plugins — all deferred to V1.x or the Pro build. The MAS launch is hardened around this one promise; the Pro build adds the autonomy surfaces afterward.

This is the Apple Design Award angle. Not because we chase the award — because the app the award is for is the app this plan describes.

---

## 1. Why this, why now

The convergent answer from four independent research sources: the V1 differentiator is not breadth, it is **the absence of friction during recall**. Every feature compounds; every feature you defer reduces the surface area an MAS reviewer can reject and the surface area users can stutter on.

The Halo is also the natural sibling to your in-flight [Landing Wave search bar](Epistemos/Views/Notes/) on `feature/landing-liquid-wave`:

- **Wave bar** = explicit search ("I want to look something up now")
- **Halo** = ambient recall ("I'm thinking right now, watch quietly")

They share the same Rust Shadow Engine. One index, two surfaces. Build the engine once.

---

## 2. Prerequisites — what must close before Phase H starts

This phase is **gated**. Do not begin Halo work until all four prerequisites are satisfied, in this order:

### 2.1 Phase R Resource Runtime — zero PARTIAL items

Status today: see [docs/KNOWN_ISSUES_REGISTER.md](KNOWN_ISSUES_REGISTER.md). Issues I-001 through I-019 must show **🟢 FIXED** or **explicitly closed**. The Halo reads/writes notes and chats through the same resource layer; it cannot be built on top of:

- a split-brain model ID layer (I-001, partial)
- duplicate read/edit/find codepaths (I-002, I-003, partial)
- unverified attachment write paths (I-004 through I-006, partial)
- snapshot-vs-live attachment ambiguity (I-007, I-008)
- permission text-vs-store divergence (I-009, fixed; verify regression suite remains green)

**Acceptance:** all 19 register entries closed; the headline regression `gpt_5_4_sidebar_shows_full_history` and the 46 Phase R suite tests stay green; cargo + xcodebuild clean.

### 2.2 Phase 0 — Stop the bleeding

Before any Halo code, three fixes that are independent of the Halo but necessary for it to feel magical:

| Fix | File | Acceptance |
|---|---|---|
| `EmbeddingService` FFI off MainActor | [Epistemos/Bridge/](Epistemos/Bridge/) | Instruments shows zero MainActor-isolated FFI calls during typing |
| Metal graph rendering off main thread | [Epistemos/Views/Graph/MetalGraphView.swift](Epistemos/Views/Graph/MetalGraphView.swift) | 500-node graph maintains 60 fps under typing + streaming load |
| AI streaming write debounce (250 ms / sentence boundary) | [agent_core/src/](agent_core/src/) + Swift commit path | No `@Query` cascade; `db.write.ms` p99 < 5 ms during streaming |

These are already partially in flight on `feature/landing-liquid-wave` (graph control + force settings touched). Land them as their own commits before opening Halo PRs.

### 2.3 Resource ID canonical layer is stable

The Halo's `ShadowDocument.doc_id` field uses the same `ResourceId::Note { ... }` / `ResourceId::Chat { ... }` enum that crosses FFI for I-001. If that enum is still being expanded mid-Halo work, both phases destabilize each other. Lock the schema first.

### 2.4 GRDB write path is verified-before-claim

Phase R.6 (verified write) must land before the Halo's "edit-in-panel-and-save" affordance ships. Without it, a user editing a note inside the panel and then seeing it not appear in the sidebar is exactly the split-brain bug Phase R was built to kill.

---

## 2.5 Codebase audit — what exists, what's missing

Jordan's audit (2026-04-24) of the existing repo identifies two retrieval paths, neither of which is the right V1 engine:

| Component | Location | Lines | Status | V1 disposition |
|---|---|---|---|---|
| `TrigramEmbedder` | [epistemos-core/src/instant_recall/embedder.rs](epistemos-core/src/instant_recall/embedder.rs) | 185 | Works but is placeholder (trigram hash, not Model2Vec) | Keep as fallback only |
| `InstantRecallIndex` | [epistemos-core/src/instant_recall/index.rs](epistemos-core/src/instant_recall/index.rs) | 270 | Flat binary scan with Hamming + rescore | Research-grade; do not retrofit |
| `HybridSearchPipeline` | [epistemos-core/src/instant_recall/fusion.rs](epistemos-core/src/instant_recall/fusion.rs) | 469 | Compiles | Research-grade; do not retrofit |
| `TurboQuantVector` | [epistemos-core/src/instant_recall/turbo_quant.rs](epistemos-core/src/instant_recall/turbo_quant.rs) | 523 | Research-grade quantization | Keep for V1.x when vault crosses 100K |
| `PreparedRetrievalStore` | [graph-engine/src/retrieval_index.rs](graph-engine/src/retrieval_index.rs) | 892 | HNSW via usearch, batch-oriented | Wrong shape; not designed for live insert/remove cycles |
| `InstantRecallService` | [Epistemos/KnowledgeFusion/InstantRecallService.swift](Epistemos/KnowledgeFusion/InstantRecallService.swift) | 293 | Exists but not wired to editor | Replace with `ShadowSearchService` |
| Editor (NSTextView, TextKit 2) | [Epistemos/Views/Notes/](Epistemos/Views/Notes/) | — | Migration done, ready for delegate hooks | Use as-is |
| **Debounce → encode → search → UI** | Nowhere | 0 | Does not exist | **Build in `Epistemos/Shadow/`** |
| **Halo button / floating panel** | Nowhere | 0 | Does not exist | **Build in `Epistemos/Shadow/`** |
| **Tantivy BM25** | Not in Cargo.toml | 0 | Not added | **Add in `crates/epistemos-shadow/`** |
| **Model2Vec (real)** | Not in Cargo.toml | 0 | Not added (trigram placeholder exists) | **Add in `crates/epistemos-shadow/`** |

**Decision: build a new `epistemos-shadow` crate; do not retrofit either existing module.**

Reasoning:
- `epistemos-core/instant_recall/` is research code (TurboQuant, ButterflyRotation, KittyVector, ProgressiveKVCache) — over-engineered for V1's ≤100K-note scale.
- `graph-engine/retrieval_index.rs` is batch-oriented (loads from manifest files) — wrong shape for live insert/remove cycles driven by typing.
- The research's `epistemos_shadow.rs` starter is the right shape: narrow UniFFI surface, clean separation (embed / ann / lexical / fusion / store).

The existing instant_recall code stays in tree as research scaffolding for V1.x quantization work. It is not the V1 critical path.

---

## 3. Architecture — locked

Where four research sources converge, take it as decided. Where they diverge, explicit calls below with rationale.

### 3.1 Layer separation

| Layer | Owner | Responsibility |
|---|---|---|
| Editor core | AppKit | `NSTextView` + TextKit 2 for caret geometry, glyph rects, mutation events |
| Shell / chrome | SwiftUI | Layout, theming, panel content rendering |
| Floating panel | AppKit | Custom `NSPanel(.nonactivatingPanel)` hosting `NSHostingView<SwiftUI>` |
| Halo glyph | SwiftUI | Anchored overlay; springs in/out; reflects controller state |
| State machine | Swift `@MainActor @Observable` | Owns nothing heavy; debounce + reflect |
| Search | Swift `actor` → Rust UniFFI | Off-main FFI ingress; serial executor |
| Indexing | Swift `actor` → Rust UniFFI | Dirty queue + batched writes |
| Retrieval engine | Rust crate `epistemos-shadow` | Embedder + ANN + lexical + fusion + store |
| Persistence | GRDB (notes, chats, embeddings sidecars) + `.usearch` files + Tantivy mmap dirs | Crash-only design |

**Decision (against Gemini, with everyone else): use a non-activating `NSPanel`, not SwiftUI `.popover()`.** Gemini suggests popovers; Claude, GPT, deep-research correctly identify that popovers cannot support inline editing + hover previews + focus retention without yanking main-window status. The HaloController.swift starter encodes this correctly.

### 3.2 Retrieval — two-lane fused

| Lane | Tech | Why |
|---|---|---|
| **Static semantic** | Model2Vec `potion-retrieval-32M`. Try the `model2vec-rs` crate first; fall back to a 50-line manual port (tokenize → lookup → mean-pool → L2-normalize) if the crate has aarch64 issues. 256-dim. | Sub-millisecond per paragraph on M2 Pro. No transformer self-attention in the live loop. |
| **Lexical** | `tantivy` BM25 over titles (boost 2.0), bodies, snippets | Exact-token recall ("AL", "PLAN_V2", "MCP") matters more than fuzzy semantic recall during typing |
| **Fusion** | Weighted Reciprocal Rank Fusion. `k = 60`. `lex_weight = 1.2`, `dense_weight = 1.0` | Cormack 2009; lexical favored because typing context is keyword-rich |

**Decision: do not ship binary 1-bit Hamming quantization in V1.** Claude's research correctly notes BF16 HNSW at 10K–100K notes is sub-millisecond; binary quant is justified only past ~1M notes and meaningfully degrades recall. Ship BF16; defer binary to V1.x if and only if a single user vault crosses 100K.

### 3.3 ANN index parameters — locked

```
metric:           Cos
quantization:     BF16
connectivity:     16
expansion_add:    128
expansion_search: 64
multi:            false
```

Two indices: `notes.usearch` and `chats.usearch`. Both mmap-loaded on startup. Persist raw float32 vectors in GRDB so a model upgrade can rebuild without re-encoding from text.

### 3.4 Concurrency — the line in the sand

**No Rust FFI on MainActor. Ever.** This is non-negotiable.

```
@MainActor only does:                    Off-main does:
  - view state assignment                  - all FFI
  - tiny animation state                   - embedding generation
  - focus updates                          - HNSW search
  - panel placement                        - BM25 search
                                           - GRDB writes
                                           - graph recompute
                                           - file crawling
                                           - model loading
```

**The actor map:**

| Actor | Isolation | Job |
|---|---|---|
| `HaloController` | `@MainActor @Observable` | Owns `state`, `matches`, `domain`. Debounces. Reflects. Nothing else. |
| `ShadowSearchService` | default cooperative executor (`actor`) | All `shadowSearch` FFI ingress. Serializes concurrent typing-driven searches. |
| `ShadowIndexingService` | default cooperative executor (`actor`) | Dirty queue, 500 ms batch debounce, batched `shadowInsert` + `shadowFlush`. |
| `StreamCommitter` | default cooperative executor (`actor`) | AI streaming token batching. Commits to GRDB every 250 ms or on sentence boundary. |
| Rust internal | `parking_lot::RwLock` per index, `Mutex` per Tantivy writer | Serializes inserts/searches against the same HNSW. |

**UniFFI binding gotcha (handle in build script):** Swift 6.2 / Xcode 26 default `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` causes UniFFI-generated bindings to inherit MainActor. Until `default_isolation = "nonisolated"` lands upstream, the build script post-processes the generated `.swift` file to prepend `nonisolated` to file-level declarations. Reference: [uniffi-rs#2818](https://github.com/mozilla/uniffi-rs/issues/2818).

### 3.5 Data plane vs control plane

This is the rigor the deep-research report adds that the others don't surface clearly:

**UniFFI = control plane only.** Configuration objects, lightweight requests, result records, typed errors, async lifecycle. No bulk data.

**C-shim = data plane.** For any future transport that exceeds modest record sizes (Mamba-2 cache transfer, Metal buffer interop, dense candidate batches), use a small hand-written `extern "C"` shim with explicit slab ownership.

For the **Halo specifically**, payload sizes are small enough that UniFFI is fine for everything. But the rule prevents UniFFI from becoming a bottleneck as the architecture grows. Document the rule now; enforce it in code review.

### 3.6 Editor integration

```
NSTextView delegate
  → textDidChange (cheap, MainActor)
  → extractQueryContext(text)
       1. Last paragraph (since last "\n\n")
       2. If < 40 tokens: fall back to last 128 tokens
       3. Add document title at low weight
  → HaloController.editorTextDidChange(context, domain)
       cancel pendingTask
       if state == .dormant: transition(.sensing)
       schedule new Task:
         sleep 200ms
         if cancelled: return
         hits = await ShadowSearchService.search(...)
         apply on MainActor
```

Reference: HaloController.swift starter has this pattern correct. Use it as the skeleton.

### 3.6.1 Halo button anchor — locked

**Anchor the Halo glyph to the editor's trailing edge. Do not track the caret.**

Gemini's research recommends caret-tracking via `NSLayoutManager.boundingRect(forGlyphRange:in:)` with NSScrollView → SwiftUI coordinate-space translation. **Reject this.** Reasons:

- Caret-tracking buttons jitter during fast typing
- Coordinate transforms are a maintenance liability across text-layout permutations
- Fights with autocomplete popups and IME composition windows
- Trailing-edge anchor is always reachable, never interferes with typing, and never moves unpredictably

The HaloController.swift starter does NOT make this anchor decision; it must be enforced at the SwiftUI overlay layer in [ProseEditorRepresentable2.swift](Epistemos/Views/Notes/ProseEditorRepresentable2.swift).

### 3.6.2 Multi-surface Halo

The Halo lives on **three editor surfaces**, all driven by the same `HaloController` and `ShadowSearchService` (injected via SwiftUI environment, not duplicated):

| Surface | Anchor | Domain default | Trigger |
|---|---|---|---|
| Note editor | Trailing edge of `ProseTextView2` | `notes` | `NSTextView.textDidChange` |
| Chat message bar | Right side of input field | `chats` mixed with `notes` | Input text-change observer |
| Quick capture panel | Trailing edge of capture input | `notes` | Input text-change observer |

A user clicking the chat-bar Halo gets recall over their entire vault context, not just chats — because the user's intent there is "what have I thought about this before?"

### 3.7 Panel UX

| State | What renders |
|---|---|
| Dormant | Nothing visible |
| Sensing | Glyph fades in (spring 0.18s, 0.85→1.0 scale) at trailing edge of editor |
| Available(count) | Glyph stays; no panel yet |
| Open | NSPanel slides in. Segmented Notes/Chats picker. Lazy `LazyVStack` of `ShadowRow`. Hover → 180px preview pane appears below results |
| EditingNote | Selected note's snippet replaces with mini `NSTextView`. Save commits via `actor VaultStore` to GRDB |
| SummarizingChat | Right-click → contextMenu → local model summarizes. Result rendered in panel only. **Persisted only on user confirm**, never automatically |
| ErrorRecoverable | Banner inside panel, dismiss-only |

**Materials:** `.ultraThinMaterial` background. Panel capped at 480 px wide to keep blur cost ≤ 2 ms/frame on M2 Pro.

**Animations:** all `.spring(duration: 0.18)`. Reduced-motion respects `accessibilityReduceMotion`.

### 3.7.1 Chat indexing strategy

Chats are not notes. Index them differently:

- **Chunk by conversation turn**, not by full transcript. A 200-message chat is too large for a single embedding; embed each user message and each assistant reply separately, with a `parent_chat_id` field to group results.
- **Index both user messages and assistant responses.** When typing "AL", a user wants to find chats where they themselves talked about AL topics — not just chats where the assistant mentioned AL.
- **Tantivy fields:** `parent_chat_id`, `turn_index`, `model_name`, `created_at`, `body`. Filter queries by date range when the user's text contains temporal cues ("last Tuesday", "yesterday").
- **Temporal decay on chat scores:** `score *= exp(-days_ago / 30.0)`. Recent chats rank higher. This is applied post-fusion, before the panel sees results.
- **Snippet construction:** include the speaker prefix ("You:" / "Claude:") so the panel row makes the conversational context obvious.

### 3.7.2 Inline edit save path

When a user edits a note inline in the panel:

1. On edit-affordance click: load **full** note body from GRDB (not just the snippet) into a mini `NSTextView` inside the panel row.
2. On save: write back through the Phase R.6 verified-write path (single transaction, fsync barrier, file-system + GRDB consistency check).
3. Trigger `ShadowIndexingService.markDirty(docId)` to re-embed and re-index.
4. The main editor's `@Observable` model picks up the change via GRDB observation pipeline; the user sees the change in the main editor within < 100 ms.
5. The panel becomes **key** (for keyboard input) without becoming **main** (which would steal editor focus). This is exactly what `canBecomeKey = true, canBecomeMain = false` on `NSPanel` does.

### 3.7.3 Summarize-from-panel flow

When a user right-clicks a chat row → Summarize:

1. Fetch full chat transcript from GRDB (all turns, ordered).
2. Construct a prompt: "Summarize the key points from this conversation in bullet points."
3. Route through the existing [ChatCoordinator](Epistemos/) inference path; respects the active local-model preference.
4. Stream the summary into a new row inside the panel, below the selected chat. The user sees tokens arrive live.
5. **Do not persist by default.** The summary lives in memory only.
6. If the user clicks "Save as note" on the summary row: create a new note with `source: chat-summary`, link back to the parent chat, then mark dirty for re-indexing.

This is the only Halo flow that requires LLM inference. Everything else is pure retrieval. Keep them architecturally separate.

### 3.8 Index lifecycle

```
Startup:
  ├── load .usearch indices (mmap; no rebuild on launch)
  ├── load Tantivy mmap dirs
  ├── verify schema_version + embedder_id headers
  ├── if mismatch: schedule background rebuild, but launch immediately
  └── show "rebuilding recall index" subtle indicator

Incremental:
  ├── GRDB TransactionObserver fires on note/chat commit
  ├── ShadowIndexingService.markDirty(docId)
  ├── 500 ms debounce
  ├── batch upsert through shadow_insert
  └── shadow_flush every 30s of idle, or on app quit

Recovery:
  ├── if .usearch corrupt: rebuild from GRDB embeddings table
  ├── if embeddings table empty: rebuild from raw text
  ├── never block editor launch
  └── show progress; allow normal use during rebuild
```

### 3.9 Persistence settings — locked (per V1 DECISION)

GRDB with WAL, `synchronous = NORMAL`, `F_BARRIERFSYNC` (not `F_FULLFSYNC` — APFS already provides barrier semantics; FULL is dramatically slower).

PRAGMAs:
```
journal_mode  = WAL
synchronous   = NORMAL
temp_store    = memory
mmap_size     = 30000000000
cache_size    = -65536       (64 MB)
optimize      (on close)
```

---

## 4. Performance budget — measurable, CI-gated

Every cell in this table is enforceable via `os_signpost` events emitted from the codepaths that should produce them, captured by Instruments and exported as a JSON regression artifact in CI.

| Phase | Target | Hard ceiling | Signpost name |
|---|---|---|---|
| MainActor work per recall update | < 1 ms | 2 ms | `halo.mainactor.ms` |
| Debounce window | 200 ms | 250 ms | (config, not measured) |
| Query context extraction | < 0.5 ms | 1 ms | `shadow.extract.ms` |
| FFI hop (Swift → Rust) | < 0.5 ms | 1 ms | `shadow.ffi.ms` |
| Model2Vec encode (paragraph) | < 2 ms | 4 ms | `shadow.embed.ms` |
| usearch HNSW search top-20 | < 5 ms | 10 ms | `shadow.ann.ms` |
| Tantivy BM25 search | < 8 ms | 12 ms | `shadow.bm25.ms` |
| RRF + metadata fetch | < 3 ms | 5 ms | `shadow.fusion.ms` |
| **End-to-end recall pass** | **< 25 ms** | **40 ms** | `shadow.search.total.ms` |
| UI apply (set matches, transition state) | < 1 ms | 2 ms | `halo.uiApply.ms` |
| Metal frame @ 60 Hz | < 12 ms | 16.67 ms | `graph.frame.ms` |
| Metal frame @ 120 Hz | < 6 ms | 8.33 ms | `graph.frame.ms` |
| AI streaming token batch save | every 250 ms | every 500 ms | `stream.flush.ms` |
| GRDB single write | < 3 ms | 5 ms | `db.write.ms` |
| Panel open latency | < 30 ms | 50 ms | `panel.openLatency.ms` |
| Cold app start to useful UI | < 800 ms | 1200 ms | `app.coldStart.ms` |
| Warm start to editor ready | < 250 ms | 400 ms | `app.warmStart.ms` |

**Engineer for p99, not p50.** Users feel hitches, not averages. The CI artifact tracks p50/p95/p99; regressions in p99 block release.

---

## 5. State machine

Six states. Transitions deterministic. Logged via `os_log` so any flake is reconstructable.

```
Dormant         → Sensing            (text length ≥ 3 chars, has non-stopword token)
Sensing         → Available(count)   (≥ 1 result above score threshold 0.2)
Sensing         → Dormant            (text emptied or no results)
Available       → Open(domain)       (Halo glyph clicked)
Available       → Sensing            (text changes)
Available       → Dormant            (text emptied or focus left editor)
Open            → EditingNote(id)    (inline edit affordance)
Open            → SummarizingChat(id) (right-click → Summarize)
EditingNote     → Open(domain)       (commit or cancel)
SummarizingChat → Open(domain)       (summary completes or cancelled)
Open            → Available(count)   (Esc, click outside, or focus returned to editor)
Any             → Dormant            (text emptied; app loses key window)
Any             → ErrorRecoverable   (FFI failure, log, banner inside panel)
```

The HaloController.swift starter implements 5 of these correctly. Add `errorRecoverable` and the explicit `editingNote → open` / `summarizingChat → open` transitions when the inline action completes.

---

## 6. File map

### 6.1 New Rust crate: `crates/epistemos-shadow/`

```
crates/epistemos-shadow/
├── Cargo.toml             // staticlib + cdylib + rlib; tokenizers, usearch, tantivy, parking_lot, rayon
├── build.rs               // uniffi build scaffolding
├── src/
│   ├── lib.rs             // UniFFI exports + module wiring
│   ├── embed.rs           // StaticEmbedder (Model2Vec)
│   ├── ann.rs             // AnnIndex (usearch wrapper, RwLock-protected)
│   ├── lexical.rs         // LexicalIndex (Tantivy BM25, Mutex<IndexWriter>)
│   ├── fusion.rs          // weighted_rrf
│   ├── store.rs           // DocStore — backed by GRDB schema, NOT in-memory (replace starter)
│   ├── error.rs           // ShadowError enum (uniffi::Error)
│   └── state.rs           // ShadowEngine + global OnceLock
└── shadow.udl             // optional, if proc-macros + UDL hybrid
```

The `epistemos_shadow.rs` starter file in `~/Downloads/ambient/` is the skeleton. **Three deltas from the starter before shipping:**

1. Replace the in-memory `DocStore` with a real GRDB-backed store that shares the same SQLite file as the rest of the app.
2. Add schema versioning headers to `.usearch` and Tantivy index dirs so model upgrades trigger rebuilds.
3. Add a `ShadowError::SchemaMismatch` variant + recovery path.

### 6.2 New Swift module: `Epistemos/Shadow/`

```
Epistemos/Shadow/
├── HaloState.swift                 // ShadowDomain, ShadowHit, HaloState enums
├── HaloController.swift            // @MainActor @Observable state machine
├── ShadowSearchService.swift       // actor, FFI ingress
├── ShadowIndexingService.swift     // actor, dirty queue + batch flush
├── ShadowPanel.swift               // NSPanel subclass + ShadowPanelController
├── ShadowPanelContent.swift        // SwiftUI view hosted in NSPanel
├── ShadowRow.swift                 // single result row with hover + edit affordance
├── ScoreBar.swift                  // small visual score indicator
├── HoverPreview.swift              // 180px preview pane
└── HaloButton.swift                // anchored SF Symbol glyph
```

The `HaloController.swift` starter in `~/Downloads/ambient/` is the skeleton. **Three deltas before shipping:**

1. Wire the `ShadowSearchService` to the real UniFFI-generated `shadowSearch` (the starter has placeholder stubs).
2. Replace `VaultStore.shared` and `SummarizationService.shared` placeholders with the real services from [Epistemos/Bridge/](Epistemos/Bridge/) and [Epistemos/Omega/Inference/](Epistemos/Omega/Inference/).
3. Add VoiceOver labels to every state transition; respect `accessibilityReduceMotion` for all spring animations.

### 6.3 Editor integration touches

| File | Change |
|---|---|
| [Epistemos/Views/Notes/ProseTextView2.swift](Epistemos/Views/Notes/ProseTextView2.swift) | Forward `textDidChange` to the injected `HaloController` |
| [Epistemos/Views/Notes/ProseEditorRepresentable2.swift](Epistemos/Views/Notes/ProseEditorRepresentable2.swift) | Anchor the `HaloButton` overlay at trailing edge |
| [Epistemos/App/AppBootstrap.swift](Epistemos/App/AppBootstrap.swift) | Initialize `ShadowEngine` after Phase R `resourceServiceInit` runs |

### 6.4 Tests

| Suite | Coverage |
|---|---|
| `EpistemosTests/ShadowEngineTests.swift` | UniFFI roundtrip, search-after-insert, persistence reload |
| `EpistemosTests/HaloControllerTests.swift` | State machine transitions, debounce, cancellation |
| `EpistemosTests/ShadowPerformanceTests.swift` | End-to-end < 25 ms on 10K-doc fixture |
| `crates/epistemos-shadow/tests/integration.rs` | Insert/remove/search/flush over a tempdir vault |
| `EpistemosTests/HaloAccessibilityTests.swift` | VoiceOver labels, reduced-motion compliance |

---

## 7. UniFFI surface — narrow, locked

Six functions. Two records. One stats. One error enum. **Resist scope creep.** Anything more than this should land in a separate crate or behind a deferred-feature flag.

```
shadow_init(vault_dir: String, embedder_path: String) -> Result<bool, ShadowError>
shadow_insert(doc: ShadowDocument) -> Result<bool, ShadowError>
shadow_remove(doc_id: String) -> Result<bool, ShadowError>
shadow_search(query: String, domain: String, limit: u32) -> Result<Vec<ShadowHit>, ShadowError>
shadow_flush() -> Result<bool, ShadowError>
shadow_stats() -> Result<ShadowStats, ShadowError>
```

```
ShadowDocument:  doc_id, title, body, domain ("note" | "chat")
ShadowHit:       doc_id, title, snippet, score, source ("note" | "chat")
ShadowStats:     note_count, chat_count, index_size_bytes, last_flush_ms_ago
ShadowError:     NotInitialized, Embed, Ann, Lexical, Io, InvalidDomain, SchemaMismatch, Internal
```

The `domain` field is a string at the FFI boundary (not an enum) deliberately, to allow forward-extension to `("note" | "chat" | "code" | "task" | ...)` without breaking the contract. Swift maps it to the `ShadowDomain` enum at the actor boundary.

---

## 8. Roadmap — 6 weeks, gated by acceptance

### Week 0 — Phase R closure + Phase 0 perf

Not part of Halo work. Listed for completeness because Halo cannot start until this is green.

**Acceptance gate:**
- [ ] All 19 [KNOWN_ISSUES_REGISTER.md](KNOWN_ISSUES_REGISTER.md) entries closed
- [ ] `EmbeddingService` Instruments trace shows zero MainActor FFI
- [ ] Graph maintains 60 fps under typing + streaming load
- [ ] AI streaming `db.write.ms` p99 < 5 ms

### Week 1 — Shadow Engine, Rust side

- Cargo workspace addition: `crates/epistemos-shadow/`
- Distill Model2Vec `potion-retrieval-32M` once in Python; export `tokenizer.json` + `matrix.bin`
- Implement `StaticEmbedder` in Rust
- Integrate `usearch` HNSW with `RwLock` protection
- Integrate `tantivy` with `Mutex<IndexWriter>` and `OnCommitWithDelay` reader
- Implement `weighted_rrf`
- Implement GRDB-backed `DocStore` (replacing the starter's in-memory map)
- UniFFI surface: 6 functions, 3 records, 1 error enum

**Acceptance gate:**
- [ ] `cargo test --manifest-path crates/epistemos-shadow/Cargo.toml` green
- [ ] Test harness: 10K-doc fixture, < 25 ms p99 end-to-end search latency
- [ ] Schema versioning: corrupt-index test triggers rebuild; clean-index test loads in < 50 ms

### Week 2 — Swift services + actor map

- `ShadowSearchService` actor wired to UniFFI bindings
- `ShadowIndexingService` actor with 500 ms debounce
- `HaloController` `@MainActor @Observable` with the 6-state machine
- UniFFI binding post-processing in build script
- Bootstrap wiring in [AppBootstrap.swift](Epistemos/App/AppBootstrap.swift) — after Phase R resource init
- Vault indexing with progress UI, batched 64 paragraphs at a time

**Acceptance gate:**
- [ ] `swift test` covers all state machine transitions
- [ ] No `@MainActor` annotation appears anywhere in `ShadowSearchService` or `ShadowIndexingService`
- [ ] Instruments trace confirms zero MainActor FFI hops during simulated typing

### Week 3 — Panel + editor wiring

- `ShadowPanel` non-activating NSPanel with `NSHostingView`
- `ShadowPanelContent` SwiftUI view: segmented Notes/Chats picker, `LazyVStack` of rows
- `HaloButton` SwiftUI overlay anchored to editor trailing edge; spring animation
- `ProseTextView2` forwards `textDidChange` to controller
- Outside-click monitor via `NSEvent.addGlobalMonitorForEvents`

**Acceptance gate:**
- [ ] Halo glyph appears within debounce window after typing 3 meaningful characters
- [ ] Clicking glyph opens panel without yanking main-window status from editor
- [ ] Esc, outside-click, and focus-return-to-editor all dismiss correctly
- [ ] Reduced-motion preference disables all spring animations

### Week 4 — Hover preview, inline edit, summarize

- `HoverPreview` pane, 180 px tall, lazy-loaded by `doc_id`
- Inline edit: replace snippet with mini `NSTextView`; commit through `VaultStore` actor; verified write through Phase R.6 path
- Right-click context menu on chat rows: Summarize action dispatches local model, renders result in panel, persists only on confirm
- Keyboard navigation: `Cmd+Up/Down` through results, `Esc` closes, `Cmd+Return` opens

**Acceptance gate:**
- [ ] Edit-in-panel save shows up in main editor's view of the same note within 100 ms
- [ ] Summarize completes in < 3 s for a 50-message chat (local Qwen 8B Q4_K_M, M2 Pro)
- [ ] Cancel mid-summarize never persists partial output
- [ ] Full keyboard navigation works without mouse

### Week 5 — Phase S hardening (App Store gate)

- Strip computer-use / AX automation surfaces from MAS build (deployment profile = Bounded Intelligence OS)
- `PrivacyInfo.xcprivacy` audit: every required-reason API justified
- Security-scoped bookmark flow for vault access
- Sandbox entitlements minimized
- Hardened runtime; no JIT, no library-validation exceptions
- Local model catalog correctness pass (per Claude ambient §4B)
- Notarization build pipeline rehearsal
- Crash-recovery test matrix: corrupt index, missing index, partial flush, half-encoded vault
- Privacy delete: deleting a note purges raw text + embeddings + Tantivy entries + hover-preview cache + `.usearch` entry **transactionally**

**Acceptance gate:**
- [ ] MAS build has zero `CGEvent`, `AXUIElement.perform`, or `ScreenCaptureKit` symbols (verified by `nm` grep)
- [ ] PrivacyInfo.xcprivacy passes Apple's static checker
- [ ] Sandbox audit: every entitlement traceable to a user-facing feature
- [ ] Crash-recovery matrix: every scenario produces a usable app within 5 seconds
- [ ] Privacy delete test: zero residual bytes on disk for purged docs (signpost-verified)

### Note on timing

Jordan's brainstorm proposes a tighter 4-week core build (perf+engine, controller+panel, polish+integration, hardening). That is correct **for the Halo build itself** — it omits the Phase R closure (Week 0) and Phase S MAS audit (Weeks 5–6) bookends because those are not Halo work, they're prerequisites and ship-readiness.

**Reconciliation:** the master plan keeps the 6-week framing because Phase R and Phase S are non-negotiable; the inner 4 weeks (Weeks 1–4 here) are the Halo-build core. If Phase R closes faster than Week 0 budget, slide everything earlier; if it takes longer, slide later. The Halo timing is determined by Phase R closure, not by calendar.

### Week 6 — Beta + ship

- TestFlight beta cohort
- Performance regression test suite running nightly
- Marketing site copy emphasizing privacy-first, native, fast
- App Store submission with featured-app pitch deck
- Privacy manifest reviewer-friendly version

**Acceptance gate:**
- [ ] No p99 regression vs Week 4 baseline across all signposts
- [ ] Beta cohort reports zero "stutter" or "freeze" issues
- [ ] App Store review: privacy manifest uploads without warnings

---

## 9. Operating doctrine — project law

These rules apply to every PR touching the Halo, Shadow Engine, or any code that interacts with them. Code review enforces them.

1. **MainActor is for pixels, not thinking.** No FFI, embeddings, search, recompute, model loading, or DB writes ever cross to MainActor. View state assignment and panel placement are the only allowed MainActor work in the recall hot path.

2. **Every feature has a signpost-measured budget.** No vibes. Numbers in CI. Regression in p99 blocks release.

3. **Graceful degradation is mandatory.** Index rebuilding? Editor still works. Local model failing? Cloud falls back with consent. Metal unavailable? List view, not crash. App must launch even with corrupt/missing/stale index.

4. **No FFI function transfers ownership AND exposes a borrowed alias to the same memory.** This single rule prevents most cross-language memory bugs.

5. **Persistence batches.** Never save per token. Never reindex per keystroke. Token streams accumulate in `actor StreamCommitter`; reindex respects 500 ms debounce.

6. **UniFFI = control plane only. C-shim = data plane.** For the Halo, UniFFI is enough. The rule prevents UniFFI from becoming a bottleneck as adjacent features grow.

7. **Privacy defaults are boring and strong.** Local by default. Cloud opt-in per provider. No telemetry. Delete-note purges raw text + embedding + snippet + index entry transactionally. Logs redact content unless a developer-only debug flag is set.

8. **MAS build has zero computer-use surfaces.** No `CGEvent`, no `AXUIElement.perform`, no `ScreenCaptureKit` workflows. Those are Pro-build only. CI verifies via symbol-grep on every MAS build.

9. **Triple-buffer mutable GPU resources.** `DispatchSemaphore(value: 3)` on dynamic Metal buffers. Never write into a buffer that may still be in flight on the GPU.

10. **Crash-only design.** Disk is truth. In-memory state is rebuildable. Every actor must be safe to drop and recreate from disk state.

11. **Commit after every cohesive change.** Per `feedback_commit_after_change.md` memory. Never batch features into one commit.

12. **Read every associated research/prompt/backlog doc before touching a feature.** Per `feedback_doc_verbosity.md` memory. Token cost irrelevant. Disconnects come from reading one doc, not N.

13. **Best-version audit on every feature entry.** Per `feedback_best_version_audit.md` memory. Multiple versions of every concept exist; rank by rigor + philosophy + recency + specificity; ship the best one.

---

## 10. Privacy & MAS compliance — the lock-down

### 10.1 Default behavior

| Capability | Default | User opt-in flow |
|---|---|---|
| Local embedding generation | Always on | N/A |
| Local model summarization | Always on | N/A |
| Cloud summarization | Off | Per-provider toggle in Settings; explanation copy mandatory |
| Cloud chat | Off | Per-provider toggle; API key in Keychain only |
| Telemetry | Off | No "anonymous usage stats" prompt; no analytics SDK |
| Crash reports | Off | Apple's native crash-report system only; no third-party |

### 10.2 Vault access

- Security-scoped bookmarks via `NSOpenPanel` user-selected folder
- Persisted to Keychain-encrypted defaults
- Resolution: `URL.startAccessingSecurityScopedResource()` on first read each launch
- No filesystem crawling beyond user-selected scope

### 10.3 Data deletion contract

When a user deletes a note or chat, in a single atomic transaction:

1. Remove from GRDB `notes` / `chats` table
2. Remove from GRDB `embeddings` sidecar table
3. Call `shadow_remove(doc_id)` to purge `.usearch` + Tantivy entries
4. Clear hover-preview cache for this `doc_id`
5. Clear any local model cache that retained snippets

Test: `EpistemosTests/PrivacyDeleteContractTests.swift` verifies zero residual bytes on disk for the purged doc, signpost-confirmed.

### 10.4 Privacy manifest (PrivacyInfo.xcprivacy)

Required-reason APIs to document:
- `NSPrivacyAccessedAPICategoryFileTimestamp` — vault scanning (reason: 0A2A.1)
- `NSPrivacyAccessedAPICategoryDiskSpace` — index size telemetry (reason: 7D9E.1)
- `NSPrivacyAccessedAPICategorySystemBootTime` — `os_signpost` startup measurement (reason: 35F9.1)
- `NSPrivacyAccessedAPICategoryUserDefaults` — KeyboardShortcuts persistence (reason: CA92.1)

Collected data types: **none.** All processing on-device by default.

### 10.5 Hardened runtime entitlements (MAS)

```
com.apple.security.app-sandbox             = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.network.client          = true   # cloud model opt-in
com.apple.security.cs.allow-jit            = false
com.apple.security.cs.disable-library-validation = false
com.apple.security.cs.allow-unsigned-executable-memory = false
```

Anything more requires a documented user-facing capability and a separate Pro-build entitlement.

---

## 11. What's deferred — and why

| Capability | Deferred to | Reason |
|---|---|---|
| Computer use / `CGEvent` automation | Pro build | Sandbox-incompatible; MAS rejection risk |
| AX automation via AXorcist | Pro build | Same |
| ScreenCaptureKit workflows | Pro build | Same |
| GEPA self-evolution | V1.x or research SKU | Not user-visible value in V1; needs trajectory infrastructure |
| Loro CRDT live editor | V1.x | GRDB + single-user is enough; CRDT adds complexity without V1 user value |
| EMMET batched fact editing | Research SKU | Premature; no user-facing surface that needs it |
| R2F unlearning | V1.x | Privacy in V1 is delete-purge, not parametric unlearning |
| Mirror Speculative Decoding | V1.x | Local Qwen 8B Q4_K_M already produces summaries in < 3s on M2 Pro |
| Plugin system | Pro build | Hardened Runtime + library validation conflict |
| Cozo as authoritative store | Maybe never | GRDB recursive CTEs handle 95% of graph traversals at user scale |
| Mamba-2 cache injection | V1.x | Phase 1A landed; injection UX is V2 work |
| Hyperbolic topology / Markov-blanket TriageService | Research SKU | Genuinely interesting; not a launch differentiator |
| Binary 1-bit Hamming quantization | When a vault crosses 100K notes | BF16 is sub-millisecond at V1 scale |
| Speculative decoding (classical) | V1.x | Halo summarization is fast enough without it |

**Defer doesn't mean "abandon."** Each entry has a clear V1.x or Pro-build slot. The Pro build is where computer use, plugins, and the more autonomous capabilities live; V1.x is where retrieval scaling, CRDT, and Mamba-2 injection slot in once the Halo proves the foundation.

---

## 11.5 Risk register

Per Jordan's brainstorm audit:

| Risk | Severity | Mitigation |
|---|---|---|
| `model2vec-rs` doesn't compile cleanly for aarch64 | Medium | Manual 50-line port (math is trivial: tokenize → lookup → mean-pool → L2-normalize). Test both options on Day 1 of Week 1. |
| Tantivy binary size bloat | Low | Already ~2 MB. Feature-flag if needed; binary impact acceptable for the search quality it adds. |
| usearch concurrent insert+search deadlock | Medium | Serialize mutations through `parking_lot::RwLock` per index. The starter code already does this correctly. |
| UniFFI Swift 6.2 `@MainActor` inheritance | High | `sed` post-processing workaround in build script (well-documented, [mozilla/uniffi-rs#2818](https://github.com/mozilla/uniffi-rs/issues/2818)). |
| Panel focus stealing from editor | Medium | NSPanel with `canBecomeMain = false` — battle-tested pattern (Raycast, Alfred, every macOS utility). |
| First-launch indexing blocks app | Low | Background `Task.detached`, batched 64–128 paragraphs, progress UI in main window. App fully usable during. |
| Chat summarize latency (LLM inference) | Low | Async, spinner, streaming — user expectation is already "AI takes a moment." |
| Phase R partial close blocks Halo work | High | Halo work cannot start until [KNOWN_ISSUES_REGISTER.md](KNOWN_ISSUES_REGISTER.md) closes. Track weekly; flag blockers. |
| `epistemos-core/instant_recall/` confusion (two retrieval paths) | Medium | Document `epistemos-core/instant_recall/` as research-grade in its README; route all V1 retrieval through `epistemos-shadow`. |

---

## 12. Apple Design Award angle

The editorial criteria, mapped:

| Criterion | How the Halo serves it |
|---|---|
| **Inclusion** | Voice capture (WhisperKit), full keyboard navigation, reduced-motion compliance, dynamic type, VoiceOver labels on every Halo state |
| **Delight + surprise** | The dormant→sensing→available→open transition. Hover preview chrome. The way the panel doesn't steal focus |
| **Innovation** | Contextual Shadows as a first-class UI primitive — nobody else has this |
| **Visual + graphic design** | SF Pro for everything. Three colors max. No drop shadows, no gradients, no skeumorphism. System materials only |
| **Interaction design** | Every action < 100 ms perceived latency. Every animation has a purpose. No modals where a panel works |
| **Social impact** | Privacy-first. Local-first. Veteran-built, solo-built, indie. The story matters as much as the product |

Don't chase the award. Build the app the award is for.

### 12.1 The killer demo moment

The single 3-second sequence that justifies the whole project:

> User types "AL" in a note. The Halo glyph fades in beside the editor on a gentle spring. User clicks. Panel slides in. List shows: "All grocery list", "All features to add", "All things go." User hovers over one — full preview slides up below. User clicks edit, adds an item right there, dismisses. Keeps typing.
>
> All in under 3 seconds. All on-device. Zero cloud calls. Zero context switches.

That's the Apple Design Award demo. That's the V1 promise.

---

## 13. Acceptance gates — summary

A single checklist that gates the V1 release. Every box must be green.

### Foundation
- [ ] Phase R 19/19 issues closed
- [ ] Phase 0 perf: zero MainActor FFI, 60 fps graph under load, debounced streaming
- [ ] Resource ID schema locked

### Shadow Engine
- [ ] `crates/epistemos-shadow` builds clean; cargo tests green
- [ ] 10K-doc fixture: < 25 ms p99 end-to-end search
- [ ] Schema versioning + corrupt-index recovery

### Swift integration
- [ ] All state machine transitions covered
- [ ] Zero `@MainActor` in `ShadowSearchService` / `ShadowIndexingService`
- [ ] Editor wiring; non-activating panel; outside-click dismiss

### UX
- [ ] Hover preview, inline edit, summarize all functional
- [ ] Edit-in-panel save reflects in main editor in < 100 ms
- [ ] Full keyboard navigation
- [ ] Reduced-motion compliance

### Hardening
- [ ] MAS build: zero computer-use symbols
- [ ] PrivacyInfo.xcprivacy passes Apple's checker
- [ ] Sandbox audit complete
- [ ] Crash-recovery matrix: every scenario produces usable app in < 5 s
- [ ] Privacy delete contract: zero residual bytes

### Performance
- [ ] All signposts within budget at p99
- [ ] CI artifact tracking p50/p95/p99 across releases
- [ ] No regression vs Week 4 baseline

### Ship
- [ ] TestFlight beta cohort: zero stutter/freeze reports
- [ ] App Store submission: clean upload
- [ ] Marketing site live
- [ ] Featured-app pitch deck delivered

---

## 14. Open questions — resolve before Week 1

These need a decision from Jordan before Phase H opens. None block Week 0 (Phase R closure + Phase 0 perf).

1. **Embedder packaging.** Bundle ~30 MB Model2Vec matrix in app bundle (cleaner UX, larger download), or first-launch download (smaller MAS bundle, slight first-run hiccup)? **Recommend bundle.**

2. **Tantivy index location.** Inside the user's vault dir, or in `Application Support/com.epistemos`? **Recommend Application Support** — vault should stay user-portable; index is rebuildable from the vault.

3. **Halo glyph icon.** SF Symbol `sparkle.magnifyingglass` is the V1 DECISION default. Confirm or pick alternate (`brain.head.profile`, `eye.circle`, `circle.dotted`).

4. **Domain expansion timing.** V1 ships `note` and `chat` domains. When does `code` (for code files attached to chats) and `task` come online? **Recommend V1.x** — keep V1 surface narrow.

5. **Cloud summarization opt-in granularity.** Per-provider, or per-task? **Recommend per-provider in V1, per-task in V1.x.**

6. **Pro build sequencing.** After MAS V1 ships, what's the first Pro-only capability? Computer use, plugin system, or both in tandem? **Recommend computer use first** — single concentrated work stream, well-researched in `claude ambient.md` §6.

---

## 15. Provenance — where each decision came from

| Decision | Source consensus | Dissents |
|---|---|---|
| Halo as V1 differentiator | Claude, GPT, Gemini, deep-research, V1 DECISION | None |
| AppKit `NSTextView` (not SwiftUI `TextEditor`) | Claude, Gemini, deep-research | None |
| Non-activating `NSPanel` (not SwiftUI `.popover()`) | Claude, GPT, deep-research | Gemini suggested popover; outvoted on inline-edit + focus-retention grounds |
| Model2Vec `potion-retrieval-32M` | Claude, Gemini | GPT/deep-research agreed on static embedding family |
| usearch HNSW BF16 | Claude, Gemini, deep-research | None |
| Tantivy BM25 | Claude, GPT | None |
| Weighted RRF (lex 1.2, dense 1.0) | Claude, GPT | None |
| 200 ms debounce | Claude, Gemini, GPT | None |
| Zero MainActor FFI | All four | None |
| Triple-buffered Metal | Claude, deep-research, V1 DECISION | None |
| `BGRA8Unorm` (not sRGB) | Claude, V1 DECISION | None |
| `F_BARRIERFSYNC` (not FULL) | Claude, V1 DECISION | None |
| GRDB + WAL + 500 ms batch | Claude, Gemini (ModelActor pattern), V1 DECISION | None |
| Defer computer use to Pro | Claude, GPT, V1 DECISION | None |
| Defer Loro / EMMET / R2F / Mirror-SD | All four | None (Gemini documents them but doesn't recommend V1) |
| Halo button anchored to editor trailing edge (NOT caret-tracking) | Jordan's brainstorm + Claude | Gemini recommended caret-tracking; rejected on jitter/maintenance grounds |
| Multi-surface Halo (note editor + chat bar + quick capture) | Jordan's brainstorm | Original V1 DECISION focused on note editor; broader surface preserves UX consistency |
| Try `model2vec-rs` crate first, fall back to manual port | Jordan's brainstorm + Gemini reference | Claude recommended only manual port; pragmatic to test the maintained crate first |
| Build new `epistemos-shadow` crate; do not retrofit `epistemos-core/instant_recall/` | Jordan's brainstorm (codebase audit) | Existing module is research-grade quantization, wrong shape for V1 live recall |
| Chat indexing chunked per turn with temporal decay | Jordan's brainstorm | Research focused on notes; chats need per-turn embedding + recency weighting |
| Control/data plane split | deep-research only | Adopted as architectural rigor; doesn't affect Halo specifically |
| Engineer for p99 | deep-research, V1 DECISION | Adopted |

---

## 16. Cross-references

- [docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md](IMPLEMENTATION_PLAN_FROM_ADVICE.md) — root plan; Halo is Phase H
- [docs/KNOWN_ISSUES_REGISTER.md](KNOWN_ISSUES_REGISTER.md) — Phase R prerequisite
- [docs/EPISTEMOS_FUSED_v3.md](EPISTEMOS_FUSED_v3.md) — full system spec
- [docs/AGENT_PROGRESS.md](AGENT_PROGRESS.md) — sprint state
- [docs/INSTANT_RECALL_ARCHITECTURE.md](INSTANT_RECALL_ARCHITECTURE.md) — superseded by this doc; keep for historical context
- [docs/LANDING_WAVE_SEARCH_PLAN.md](LANDING_WAVE_SEARCH_PLAN.md) — sibling feature, shares Shadow Engine
- `~/Downloads/ambient/EPISTEMOS_V1_DECISION.md` — the Architectural Verdict (preserve verbatim)
- `~/Downloads/ambient/claude ambient.md` — Claude's deep implementation guide (preserve verbatim)
- `~/Downloads/ambient/deep-research-report (2).md` — GPT-5-pro deep research (preserve verbatim)
- `~/Downloads/ambient/gemini ambient.txt` — Gemini's architectural blueprint (preserve verbatim)
- `~/Downloads/ambient/epistemos_shadow.rs` — Rust starter, skeleton for `crates/epistemos-shadow/`
- `~/Downloads/ambient/HaloController.swift` — Swift starter, skeleton for `Epistemos/Shadow/`

---

## 17. The closing thought

The best version of Epistemos isn't the one with the most features — it's the one where every feature feels inevitable. Where the user types a sentence, sees a related thought appear, and can't remember a time before it worked that way.

That's what V1 ships.

Everything else is V2.

---

*End of master plan. Hand to Codex / Claude Code as input once Phase R closes.*
