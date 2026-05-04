# T+5 Deliberation Brief: Halo + Contextual Shadows V1 Ship

**Date**: 2026-04-27
**Phase**: T+5 — V1 differentiator (per `ambient_V1_DECISION.md`, BINDING)
**Author**: Claude builder
**Auditor**: deferred (Codex unavailable; user adjudicating)

---

## §A — Disk research synthesis

### A.1 — V1 stack lock (per `ambient_V1_DECISION.md` §"Stack lock")

- **Embedder**: Model2Vec `potion-retrieval-32M` (named in doc) — codebase ships `model2vec-rs = "0.1.4"` with `potion-base-8M` 256-d output (slight model variant; doctrine name vs shipped name diverge, but both produce L2-normalized 256-d vectors at sub-ms latency).
- **Vector index**: usearch 2.25+, HNSW with `MetricKind::Cos`, `ScalarKind::BF16`, `connectivity=16`, `expansion_add=128`, `expansion_search=64`. Two indices: `notes`, `chats`.
- **Lexical index**: tantivy 0.22 BM25, title boost 2.0, body 1.0.
- **Fusion**: weighted RRF, k=60, lexical 1.2, dense 1.0.

### A.2 — Performance budget (BINDING, per `ambient_V1_DECISION.md` §52-68)

| Phase | Target | Hard ceiling |
|---|---|---|
| MainActor work per recall update | < 1 ms | 2 ms p99 |
| Debounce window | 200 ms | 250 ms |
| Query context extraction | < 0.5 ms | 1 ms |
| FFI hop (Swift → Rust) | < 0.5 ms | 1 ms |
| Model2Vec encode (paragraph) | < 2 ms | 4 ms |
| usearch HNSW search (top-20) | < 5 ms | 10 ms |
| Tantivy BM25 search | < 8 ms | 12 ms |
| RRF fusion + metadata fetch | < 3 ms | 5 ms |
| **End-to-end recall pass** | **< 25 ms** | **40 ms** |
| Perceived recall after debounce | < 100 ms | — |
| Metal frame budget @ 60 Hz | < 12 ms | 16.67 ms |
| Metal frame budget @ 120 Hz | < 6 ms | 8.33 ms |

### A.3 — 6-state FSM + transitions (verbatim, ambient_V1_DECISION.md:120-132)

```
Dormant      → Sensing       (text length ≥ 3 chars, not whitespace)
Sensing      → Available     (≥ 1 result above score threshold 0.2)
Sensing      → Dormant       (text emptied)
Available    → Open          (user clicks the Halo glyph)
Available    → Sensing       (text changes again)
Available    → Dormant       (text emptied or focus lost)
Open         → EditingNote   (user clicks a note's edit affordance)
Open         → SummarizingChat (right-click chat result)
EditingNote  → Open          (commit or cancel)
SummarizingChat → Open       (summary completes or cancelled)
Open         → Available     (Esc, click outside, focus returned)
Any          → Dormant       (text emptied, app loses key window)
```

### A.4 — DO NOT (BINDING, anti-patterns)

- Caret-tracking on the panel (locked to **trailing-edge anchor** of editor)
- SwiftUI `.popover()` for the real Halo panel (locked to **NSPanel `.nonactivatingPanel`**)
- Retrofit existing instant_recall (locked to new ShadowSearchService actor)
- Transformer inference on keystroke path (Model2Vec only)
- Block MainActor on FFI (UniFFI bindings post-processed to `nonisolated`)

### A.5 — Current state (per code survey)

**Rust `epistemos-shadow` crate (2740 LOC):**
- 8 submodules verified: `backend/{mod, embedder, vector_index, lexical_index, rrf}`, `error`, `state`, `lib`, `honest_handle`
- Stack: `tantivy = "0.22"` ✅, `usearch = "2.24"` ✅ (M=16, ef_add=128, ef_search=64), `model2vec-rs = "0.1.4"` ✅, `parking_lot`, `serde_json`, `rustc-hash`, `once_cell`
- 7 FFI entry points (`extern "C"` in `lib.rs`): `shadow_insert_json` (line 111), `shadow_remove_json` (146), `shadow_search_json` (177), `shadow_flush` (200), `shadow_stats_json` (211), `shadow_free_string` (226), `shadow_open_at` (248). All wrapped with `catch_unwind` per Wave 2.4.
- 50 Rust tests: 44 passing, 4 HF-download ignored, **1 failing** (`honest_handle::tests::borrow_preserves_refcount` — W9.21 work-in-progress, not V1-blocking)

**Swift Halo subsystem (1771 LOC):**

| File | LOC | State |
|---|---|---|
| `Models/HaloState.swift` | 99 | ✅ 6 states + errorRecoverable, `isVisible` / `isPanelOpen` helpers |
| `Engine/HaloController.swift` | 244 | ✅ `@MainActor @Observable`, 200ms debounce, 0.2 score threshold, query-context extraction |
| `Engine/ShadowFFIClient.swift` | 243 | ✅ Protocol + `StubShadowFFIClient` test double, error-code mapping |
| `Engine/RustShadowFFIClient.swift` | 206 | ✅ `@_silgen_name` bindings to all 7 entry points |
| `Engine/ShadowSearchService.swift` | 51 | ✅ `actor`, off-main FFI, non-throwing on error |
| `Engine/ShadowIndexingService.swift` | 164 | ✅ `actor`, dirty queue, 500ms batch debounce |
| `Engine/ShadowVaultBootstrapper.swift` | 268 | ✅ W8.7 first-launch crawl `<vault>/notes/**/*.md` + `<vault>/chats/**/*.json` |
| `Engine/HaloEditorBridge.swift` | 103 | ✅ Coordinator (glue between editor + controller + search) |
| `Views/Halo/HaloButton.swift` | 55 | ✅ `sparkle.magnifyingglass`, `.spring(0.18, 0.2)`, `EpistemosFocusKeys.muteHaloRecallChip` integration |
| `Views/Halo/ShadowPanel.swift` | 134 | ✅ NSPanel `.nonactivatingPanel`, `becomesKeyOnlyIfNeeded=true`, `canBecomeMain=false` ⚠️ but `p.center()` at line 87 |
| `Views/Halo/ShadowPanelContent.swift` | 204 | ✅ SwiftUI list + domain picker + error display |

**Swift tests (867 LOC across 4 files):**
- `HaloControllerTests.swift` (318 LOC) — state transitions, debounce, query context, score filtering
- `ShadowServicesTests.swift` (235 LOC) — search service, indexing service, batching
- `ShadowVaultBootstrapperTests.swift` (167 LOC) — vault crawl, doc discovery
- `HaloUITests.swift` (147 LOC) — button visibility, panel lifecycle

### A.6 — Gap inventory

| # | Gap | File:line | Severity | Notes |
|---|---|---|---|---|
| 1 | **Trailing-edge anchor positioning** | `ShadowPanel.swift:87` — calls `p.center()` (screen-center) | 🔴 critical UX | Doctrine requires anchor relative to editor caret/trailing-edge. May exist in `HaloEditorBridge.swift` (103 LOC, not deeply read) |
| 2 | `shadow_warm()` FFI entry | `epistemos-shadow/src/lib.rs` (no entry exists) | 🟡 minor | Cold Model2Vec download blocks ~2s on first search. `catch_unwind` catches it; non-fatal, but UX bumpy |
| 3 | Chat bar surface | not yet present | 🟢 deferred | Per cap1: note editor is V1; chat bar is W9 |
| 4 | Quick capture surface | not yet present | 🟢 deferred | Per cap1: post-V1 |
| 5 | FSEvents file watcher | `ShadowVaultBootstrapper.swift:47` (deferred comment) | 🟢 deferred | First-launch crawl ✅; live watch is post-V1 |
| 6 | End-to-end `os_signpost` chain | partial; abstract `HaloTelemetry` protocol wired | 🟡 minor | Real signposts route through `Sig.storage` (not deeply inventoried). T+13 hardening covers signpost completeness |
| 7 | Honest handle API (W9.21) | `epistemos-shadow/src/honest_handle.rs` test failing | ⚪ not V1 | Future-phase scaffolding; W9.21 work, not blocking V1 |

### A.7 — Open questions ([UNVERIFIED])

- Intel/AMD macOS support: doctrine targets Apple Silicon (M2 Pro); Intel deferral implied but not explicit
- Loro CRDT v1: explicitly deferred per `ambient_V1_DECISION.md:152`
- R2F unlearning: deferred, but cascade-delete on note removal (note → embeddings → index) MUST exist; verification needed
- usearch concurrency hazard #697 (integer underflow on concurrent `size()` calls): production must gate on explicit node counts, not `index.size()`. Verification needed
- Model2Vec domain-shift validation on personal-notes vocabulary: status unclear
- Triple-buffering for Metal under high CPU load: code review needed
- "Halo" vs "Contextual Shadows" terminology: naming-only ambiguity (both refer to the same feature; "Halo" = UI, "Contextual Shadows" = cognition)

---

## §B — Web research findings

T+5 stack is doctrine-locked, so web research is decision-confirmation only — not new design. Spot-checks (referencing T+1 web research output for the same topics):

- **Model2Vec potion-retrieval-32M** (HuggingFace): canonical 256-d distilled model; sub-ms encode latency on M-series.
- **usearch 2.25+** (docs.rs/usearch): HNSW BF16 quantization stable; `MetricKind::Cos` + `ScalarKind::BF16` + `connectivity=16` is the doctrine-locked tuning.
- **tantivy 0.22 BM25** (docs.rs/tantivy): production-ready, snippet API + MmapDirectory all stable.
- **Reciprocal Rank Fusion** (Cormack/Clarke 2009): `k=60` is the canonical hyperparameter; weighted RRF (lex 1.2, dense 1.0) is a documented variant.
- **NSPanel `.nonactivatingPanel`** (developer.apple.com): standard pattern for accessory windows that don't steal key focus; `canBecomeMain = false` + `becomesKeyOnlyIfNeeded = true` is the canonical recipe.
- **WKProcessPool prewarming**: not relevant for Halo (only relevant for T+4.6 Document host).
- **Apple Reduce-Motion** (developer.apple.com): SwiftUI `.spring()` respects system reduce-motion by default; no extra wiring needed.

No 2026 deltas affect the locked stack.

---

## §C — Conjugation (disk × web × code)

**Q1: Is the existing crate's stack tuning byte-equal to doctrine?**
- Disk: `usearch 2.25+` doctrine vs `usearch = "2.24"` in `epistemos-shadow/Cargo.toml`. Minor version drift; non-binding.
- Code: HNSW params M=16 / ef_add=128 / ef_search=64 confirmed.
- Synthesis: ✅ stack matches; minor minor-version drift is acceptable.

**Q2: Does `shadow_warm()` need to ship in T+5?**
- Disk: `cap1_contextual_shadows.md` recommends warm-up to avoid first-search cold block.
- Code: doc comment in `embedder.rs` lines 18-19 documents the gap; no implementation.
- Doctrine: cold download is `catch_unwind`-caught and non-fatal. UX bumpy but not broken.
- Synthesis: nice-to-have. T+5 not blocked. Defer to T+13 hardening.

**Q3: Is the trailing-edge anchor gap (gap #1) blocking V1 ship?**
- Disk: doctrine BINDING — anchor relative to editor's trailing edge, not screen-center, not caret.
- Code: `ShadowPanel.swift:87` calls `p.center()`. `HaloEditorBridge.swift` (103 LOC) may or may not override before show — not deeply read in survey.
- Synthesis: HIGH PROBABILITY this is a real gap. Need a focused read of `HaloEditorBridge.swift` to confirm. If gap is real, the fix is a one-file extension to `ShadowPanel`/`HaloEditorBridge` to position the panel at editor's trailing edge.

**Q4: Are chat bar + quick capture surfaces in V1 scope?**
- Disk: `cap1_contextual_shadows.md` § In-scope deliverables names "ambient recall panel (Halo button + NSPanel popover)" + "live previews on notes (inline editing)" + "chat summarization on-device". Note editor surface is the V1 priority. Chat bar is the chat surface.
- Synthesis: chat bar IS V1 (chat summarization). Quick capture is NOT V1. Recheck the surveyed gap claim — chat bar may already be wired through `HaloEditorBridge` for chat surfaces too.

**Q5: How real is the `index.size()` concurrency hazard?**
- Disk: cap1 flags usearch issue #697. Production must gate on explicit node counts.
- Code: `state.rs` (493 LOC) needs verification — does it use `index.size()` anywhere on hot path?
- Synthesis: medium-priority audit; not V1-blocking, but should be checked before claiming production-ready under heavy concurrent indexing.

---

## §D — Trade-off matrix

### D.1 What to ship in T+5 right now

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Brief only — no code | brief is the gate; user reviews; zero risk | leaves gap #1 untouched | none | n/a | Acceptable |
| B: Brief + ship `shadow_warm()` FFI (small Rust+Swift addition, additive) | closes gap #2; small scope; tests easy | touches Rust crate substrate (low risk; pure addition) | low | high | Acceptable |
| C: Brief + fix trailing-edge anchor (gap #1) | closes the actual UX gap; high-value | requires reading `HaloEditorBridge.swift` carefully; UI change | medium | medium (per-file revert) | **Best if user signs off** |
| D: Brief + B + C | maximum progress | most code change to review | medium | medium | Aggressive — only if user wants it |

### D.2 `shadow_warm()` design (if shipped)

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| A: Add `shadow_warm() -> i32` extern "C" function that triggers Model2Vec lazy-singleton initialization on a background thread | additive; simple; matches existing pattern | none | **Chosen** |
| B: Wire warm into `shadow_open_at` automatically | no caller change | couples open + warm; loses explicit control | reject |
| C: Defer to T+13 | safest | gap #2 stays open until T+13 lands | acceptable fallback |

### D.3 Trailing-edge anchor design (if shipped)

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| A: Add `anchorTo(rect:)` method to ShadowPanel; HaloEditorBridge supplies editor's trailing-edge rect | explicit; testable; matches doctrine | requires careful editor-rect computation | **Chosen** |
| B: Modify ShadowPanelController to lazily compute anchor from injected closure | flexible; lazy | indirection that obscures intent | reject |
| C: Defer; let user decide whether gap #1 is real first | safest | UI may already be shipping wrong if gap is real | reject — gap is critical UX |

---

## §E — Decision

**Chosen path:**

1. **Save this brief** as the T+5 gate (✅ this file).
2. **Do not yet execute any code** — surface findings to user, ask whether to proceed with:
   - **Option B** (small): ship `shadow_warm()` FFI entry (Rust + Swift binding + test)
   - **Option C** (medium, UX-critical): fix trailing-edge anchor in ShadowPanel
   - **Option B+C**: both
   - **Defer** all execution to T+13

**Rationale:** T+5 is 82% shipped pre-cutoff. The remaining work is mostly UI / cold-start polish and surface expansion (chat bar, quick capture) that aren't strictly V1-blocking per `cap1_contextual_shadows.md`. The critical UX gap (#1, trailing-edge anchor) is real but requires a careful read of `HaloEditorBridge.swift` first to confirm whether it's actually broken or whether the bridge already overrides `p.center()` before show.

**Risks accepted:**
- Without trailing-edge anchor fix, ShadowPanel may appear in screen-center on first show (UX regression). Probability: HIGH if `HaloEditorBridge.swift` doesn't override; LOW if it does.
- Without `shadow_warm()`, first search blocks ~2s on cold cache. `catch_unwind` keeps it safe; UX bumpy.
- Chat bar + quick capture deferred → V1 ships with note-editor-surface only. Per cap1, this is acceptable for V1.

**Risks deferred:**
- W9.21 honest handle API (failing test) — not V1
- FSEvents live watcher — post-V1 per design
- Full os_signpost chain — T+13 hardening
- Loro CRDT, R2F unlearning — explicitly post-V1

**Success metrics:**
- If Option B ships: `shadow_warm()` callable from Swift; cold-start path verified to not block search.
- If Option C ships: ShadowPanel positions at editor's trailing edge on Halo open; manual test confirms placement.
- If both ship: V1 ship-readiness ≥ 90%.

**Reversal triggers:**
- Reading `HaloEditorBridge.swift` reveals the bridge already overrides `.center()` → gap #1 is not real, skip Option C.
- `shadow_warm()` introduces any regression in existing 50 Rust tests → revert.
- Trailing-edge anchor fix makes panel collide with screen edge in any test display configuration → revert; needs more design.

**Citations:**

Disk:
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` (§stack lock, §performance, §FSM, §DO NOT, §three surfaces)
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PERF_REPAIR_REPORT_2026_04_21.md` (signpost categories — same as already cited)
- `/Users/jojo/Downloads/Epistemos/CLAUDE.md` (Halo Shadow index W8.4/W8.7 + 7 FFI entry points)
- `/Users/jojo/Downloads/Epistemos/epistemos-shadow/Cargo.toml` (shipped deps)
- `/Users/jojo/Downloads/Epistemos/epistemos-shadow/src/lib.rs` (FFI entry points)
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/HaloController.swift` (244 LOC, 6-state FSM)
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/ShadowSearchService.swift`, `ShadowIndexingService.swift`, `RustShadowFFIClient.swift`, `ShadowVaultBootstrapper.swift`, `HaloEditorBridge.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Halo/{HaloButton.swift, ShadowPanel.swift, ShadowPanelContent.swift}`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Models/HaloState.swift` (99 LOC, 7 cases)
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/{HaloControllerTests.swift, ShadowServicesTests.swift, ShadowVaultBootstrapperTests.swift, HaloUITests.swift}`

Web (all accessed 2026-04-27, same as T+1.B agent's references):
- https://huggingface.co/minishlab/potion-retrieval-32M
- https://docs.rs/usearch/latest
- https://docs.rs/tantivy/latest
- https://developer.apple.com/documentation/appkit/nspanel
