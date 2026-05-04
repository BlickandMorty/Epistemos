# Epistemos V1 — The Architectural Verdict

**Date:** April 24, 2026
**Author:** Architect-engineer synthesis for Jojo
**Status:** Decision document, ready for execution

---

## The one-sentence stand

Ship a sandboxed App Store V1 whose only differentiator is **Contextual Shadows surfaced through a Halo** — instant, local, private, impossibly smooth — then ship a notarized direct/Pro build for computer use, agents, and the rest of the future.

If Epistemos does this one thing flawlessly, it wins. If it does fifteen things adequately, it doesn't.

---

## What Epistemos V1 *is*

A native macOS cognitive workspace. Notes, knowledge graph, chat with local + cloud models, ambient recall. The app feels like an extension of the user's own memory: type a sentence, and the half-shadow of every related thought you've had in the past appears beside the cursor — but only when you reach for it.

## What Epistemos V1 is *not*

Not an agent platform. Not a computer-use tool. Not a research playground. Not a CRDT collab editor. Not a model-editing harness. Those ship later, in their proper season, in a separate SKU when needed.

---

## Three commitments that override everything else

### 1. Privacy as ground state

- All embeddings computed locally. No telemetry by default.
- Vault access via security-scoped bookmarks chosen by the user.
- Cloud model calls require per-provider opt-in with plain-language explanation.
- Complete `PrivacyInfo.xcprivacy` with required-reason API justifications.
- App sandbox enabled. Hardened runtime. No JIT, no library-validation exceptions, no unsigned helpers.

### 2. Stability as architecture

- Every subsystem has a graceful-degradation path: if recall index is rebuilding, the editor still works; if the local model fails to load, chat falls back to cloud (with consent) or shows a clear error; if Metal is unavailable, the graph view is replaced with a list view, not a crash.
- All persistence uses GRDB with WAL, `synchronous=NORMAL`, and `F_BARRIERFSYNC` (not `F_FULLFSYNC` — APFS already provides barrier semantics).
- Crash-only design: state on disk is always the truth; in-memory state is rebuildable.

### 3. Performance as feel

- Typing is never blocked. Period.
- Graph stays at 60 fps under all conditions.
- Recall feels instant — sub-300ms from keystroke to panel update.
- AI streaming does not interfere with anything.

---

## The performance budget — non-negotiable

| Phase | Target | Hard ceiling |
|---|---|---|
| MainActor work per recall update | < 1 ms | 2 ms |
| Debounce window | 200 ms | 250 ms |
| Query context extraction | < 0.5 ms | 1 ms |
| FFI hop (Swift → Rust) | < 0.5 ms | 1 ms |
| Model2Vec encode (paragraph) | < 2 ms | 4 ms |
| usearch HNSW search (top-20) | < 5 ms | 10 ms |
| Tantivy BM25 search | < 8 ms | 12 ms |
| RRF fusion + metadata fetch | < 3 ms | 5 ms |
| **End-to-end recall pass** | **< 25 ms** | **40 ms** |
| Metal frame budget @ 60 Hz | < 12 ms | 16.67 ms |
| Metal frame budget @ 120 Hz | < 6 ms | 8.33 ms |
| AI streaming token batch save | every 250 ms | every 500 ms |

These get measured with `os_signpost`. No vibes. No "feels fine." Numbers.

---

## The technical stack — locked

### Retrieval

- **Embedder:** Model2Vec `potion-retrieval-32M`, distilled once in Python, exported as a flat binary (token vocabulary + embedding matrix + L2-normalized 256-dim output). Re-implemented in Rust using the `tokenizers` crate. Sub-millisecond per paragraph on M2 Pro.
- **Vector index:** `usearch` 2.25+, HNSW with `MetricKind::Cos`, `ScalarKind::BF16`, `connectivity=16`, `expansion_add=128`, `expansion_search=64`. Two indices: `notes` and `chats`. Persisted to `.usearch` files, mmap-loaded on startup.
- **Lexical index:** `tantivy` over titles, bodies, chunks, chat snippets. Title boost 2.0, body 1.0, exact-token boost for code/IDs/filenames.
- **Fusion:** Weighted Reciprocal Rank Fusion. `k=60`. Lexical weight 1.2, dense weight 1.0. Lexical favored because exact recall ("Gemma 4", "PLAN_V2", "AL") matters more than fuzzy semantic recall during typing.

### UI

- **Editor core:** `NSTextView` with TextKit 2 (already migrated). Caret geometry, glyph rects, and mutation events drive the Halo trigger.
- **Floating panel:** Custom `NSPanel` subclass with `.nonactivatingPanel` style mask, `becomesKeyOnlyIfNeeded = true`, `canBecomeMain = false`. Hosts SwiftUI content via `NSHostingView`. The panel can become key for inline editing without yanking main-window status from the editor.
- **Halo button:** SwiftUI overlay anchored to the editor's trailing edge, hidden until results above threshold are available. Spring animation `.spring(duration: 0.18)` for show/hide. No emoji, no icon clutter — a single `sparkle.magnifyingglass` SF Symbol.
- **Animation:** All animations use `.spring()` with `duration ≤ 0.25s`. Reduced-motion respected.
- **Materials:** Panel uses `.ultraThinMaterial` background; capped at 480px wide to keep blur cost ≤ 2ms/frame.

### Concurrency

- **Halo controller:** `@MainActor @Observable`. Owns nothing heavy. Holds `matches`, `state`, `pendingTask`. All it does is debounce and reflect.
- **Search service:** `actor ShadowSearchService` with default cooperative executor. Calls `nonisolated` UniFFI bindings. Returns plain `[ShadowHit]`.
- **Indexing service:** `actor ShadowIndexingService`. Owns the dirty queue. Batches saves. Persists to `.usearch` and Tantivy on idle.
- **Streaming committer:** Separate `actor` for AI streaming. Tokens display in `@Observable var liveText` (not persisted). Commits to GRDB every 250ms or on sentence boundary.
- **No FFI on MainActor. Ever.** UniFFI generated bindings get the `nonisolated` post-processing hack until upstream `default_isolation = "nonisolated"` lands.

### Rendering

- **Metal renderer:** Driven by `CADisplayLink` (macOS 14+) on a dedicated `DispatchQueue(label: "epistemos.metal.render", qos: .userInteractive)`.
- **Pixel format:** `BGRA8Unorm` not `BGRA8Unorm_sRGB`. Avoids the dark-halo issue around glyphs.
- **Triple buffering:** `DispatchSemaphore(value: 3)` gating dynamic buffer writes.
- **Precompiled .metallib:** Build phase compiles all shaders to a metallib shipped in the bundle. Saves 30–100ms startup.
- **MTSDF text labels:** SF Pro Text, 512×512 atlas, `-size 64`, `-pxrange 6`, `-type mtsdf`. Asset Catalog interpretation = Data, NOT sRGB.
- **Force-directed graph:** Barnes-Hut quadtree in a Metal compute shader. Targets 120fps with 10K nodes on M2 Pro.

### Persistence

- **GRDB** with WAL, `synchronous=NORMAL`, `F_BARRIERFSYNC` for syncs.
- PRAGMAs: `temp_store=memory`, `mmap_size=30000000000`, `cache_size=-65536`, `optimize` on close.
- `TransactionObserver` drives the Shadows dirty queue with 500ms debounce.

---

## The state machine

The Halo lives in one of six states. Transitions are deterministic.

```
Dormant      → Sensing       (text length ≥ 3 chars, not whitespace)
Sensing      → Available     (≥ 1 result above score threshold 0.2)
Sensing      → Dormant       (text emptied)
Available    → Open          (user clicks the Halo glyph)
Available    → Sensing       (text changes again)
Available    → Dormant       (text emptied or focus lost from editor)
Open         → EditingNote   (user clicks a note's edit affordance)
Open         → SummarizingChat (user right-clicks a chat result)
EditingNote  → Open          (commit or cancel)
SummarizingChat → Open       (summary completes or cancelled)
Open         → Available     (Esc, click outside, or focus returned to editor)
Any          → Dormant       (text emptied, app loses key window)
```

---

## What ships in V1 (Mac App Store)

- Notes / prose editor (TextKit 2, Markdown source of truth, Rust-backed Ropey for >1MB documents).
- Knowledge graph view (Metal, force-directed, Barnes-Hut, MTSDF labels, 120fps).
- Chat with local models (MLX-Swift) and cloud models (opt-in, Anthropic + OpenAI).
- **Contextual Shadows + Halo** — the signature feature.
- Quick capture (global hotkey via `KeyboardShortcuts` package, floating non-activating NSPanel).
- Voice capture via WhisperKit (CoreML, on-device).
- Privacy manifest, security-scoped vault access, sandbox on, hardened runtime on.

## What does *not* ship in V1

- Computer use / AX automation / CGEvent simulation
- ScreenCaptureKit-driven workflows
- GEPA self-evolution loop
- Cozo promotion as authoritative store
- Loro CRDT live editor
- R2F selective unlearning
- EMMET batched fact editing
- Mirror Speculative Decoding
- Plugin system / external extensions
- Managed Agents API integration

These are deferred to V1.x or to the Pro/direct build, per user demand and feasibility.

---

## The 6-week ship roadmap

### Week 1 — Phase 0: stop the bleeding

- Move `EmbeddingService` FFI off MainActor onto a dedicated serial queue or actor with cooperative executor.
- Move Metal graph rendering off the main thread to a dedicated render queue with triple-buffered command buffers.
- Debounce AI streaming persistence to sentence-boundary or 250ms intervals.
- Measure with `os_signpost`. Acceptance: no MainActor work > 2ms during typing or streaming. Graph pans smoothly with 500+ nodes.

### Week 2 — Phase 1: Shadow Engine in Rust

- New crate: `epistemos-shadow` with submodules `embed`, `ann`, `lexical`, `fusion`, `store`, `ffi`.
- Distill Model2Vec `potion-retrieval-32M` to flat binary; implement Rust encoder.
- Integrate `usearch` for HNSW; build save/load/insert/remove/search.
- Integrate `tantivy` for BM25.
- Implement weighted RRF fusion.
- Expose narrow UniFFI surface: `shadow_insert`, `shadow_remove`, `shadow_search`, `shadow_flush`, `shadow_stats`.
- Test harness verifying < 25ms end-to-end search latency on 10k documents.

### Week 3 — Phase 2: Swift controller + panel

- `HaloController` (`@MainActor @Observable`) — owns state machine, debounce, panel toggle.
- `ShadowSearchService` (`actor`) — runs FFI off main.
- `ShadowIndexingService` (`actor`) — dirty queue, batched persistence.
- `ShadowPanel` (NSPanel non-activating) hosting `ShadowPanelContent` (SwiftUI).
- Editor wiring: NSTextView delegate → controller `textDidChange`.
- Vault indexing on startup with progress UI.

### Week 4 — Phase 3: panel UX polish

- Notes tab: hover preview, inline edit, save-back to GRDB.
- Chats tab: hover preview, click-to-navigate, right-click summarize.
- Halo glyph spring animations, dormant-state hide.
- Keyboard navigation (Esc closes, Cmd+Up/Down through results).
- Reduced-motion compliance.

### Week 5 — Phase 4: hardening

- App Store entitlements audit. Strip computer-use surfaces.
- `PrivacyInfo.xcprivacy` complete with all required-reason APIs documented.
- Security-scoped bookmark flow for vault access.
- Local model catalog: corrected context windows + temperatures (per deep-research findings).
- Notarization build pipeline.
- Crash-recovery test matrix.

### Week 6 — Phase 5: ship

- Beta cohort (TestFlight).
- Performance regression test suite.
- App Store submission with featured-app pitch deck.
- Privacy manifest review.
- Marketing site emphasizing privacy-first, native, fast.

---

## The Apple Design Award angle

The criteria the editorial team weighs:

1. **Inclusion.** Voice capture (WhisperKit), full keyboard navigation, reduced-motion support, dynamic type, VoiceOver labels on every Halo state.
2. **Delight and surprise.** The Halo's dormant→available transition. Hover preview's material chrome. The way the panel doesn't steal focus.
3. **Innovation.** Contextual Shadows as a first-class UI primitive — nobody else has this.
4. **Visual + graphic design.** SF Pro for everything. Three colors max (text-primary, text-secondary, accent). No drop shadows, no gradients, no skeumorphism. System materials for surfaces.
5. **Interaction design.** Every action has < 100ms perceived latency. Every animation has a purpose. No modals where a panel works. No buttons where a gesture works.
6. **Social impact.** Privacy-first. Local-first. Veteran-built, solo-built, indie. The story matters as much as the product.

You're not chasing the award. You're building the app the award is for.

---

## What gets measured

Every release runs a benchmark suite that emits `os_signpost` events for:

- `shadow.extract.ms`
- `shadow.embed.ms`
- `shadow.ann.ms`
- `shadow.bm25.ms`
- `shadow.fusion.ms`
- `shadow.uiApply.ms`
- `graph.frame.ms`
- `stream.flush.ms`
- `db.write.ms`
- `panel.openLatency.ms`
- `editor.keystrokeToFrame.ms`

Regressions block release. CI fails on p99 over budget.

---

## The closing thought

The best version of Epistemos isn't the one with the most features — it's the one where every feature feels inevitable. Where the user types a sentence, sees a related thought appear, and can't remember a time before it worked that way.

That's what V1 ships.

Everything else is V2.
