# Audit: V2.2 Halo V1 ship-status verification — 2026-05-05

> Loop iteration audit (slice d). Closes the open question from the
> previous turn ("V2.2 doctrine merged + Shadow backend wired, but
> need to confirm 6-state FSM + Model2Vec + 25ms latency budget
> actually shipped, not just scaffolded"). Read against
> `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` (the canonical doctrine).

## Summary

| Doctrine criterion | Ship status | Evidence |
|---|---|---|
| 6-state FSM (+ errorRecoverable) | ✅ shipped | `Epistemos/Models/HaloState.swift:60` enum has all 7 cases (6 baseline + errorRecoverable) |
| Model2Vec (real, not trigram placeholder) | ✅ shipped | `model2vec-rs = "0.1.4"` in `epistemos-shadow/Cargo.toml`; live wrapper at `epistemos-shadow/src/backend/embedder.rs` loads `StaticModel::from_pretrained` |
| usearch HNSW + Tantivy BM25 + RRF (k=60) | ✅ shipped | Three modules under `epistemos-shadow/src/backend/`: `vector_index.rs`, `lexical_index.rs`, `rrf.rs` |
| Non-activating NSPanel (`canBecomeKey=true, canBecomeMain=false`) | ✅ shipped | `Epistemos/Views/Halo/ShadowPanel.swift:31` style mask + lines 50-51 |
| Honest Handle FFI (vs legacy global) | ✅ shipped | `Epistemos/Engine/RustShadowFFIClient.swift` 7 entry points named `shadow_handle_*` |
| Vault crawl on first launch | ✅ shipped | `Epistemos/Engine/ShadowVaultBootstrapper.swift` (per W8.7) |
| Build pipeline | ✅ shipped | `build-epistemos-shadow.sh` produces dylib, integrated in Xcode build |
| 25ms p99 end-to-end latency budget | ⚠️ **partial — not enforced via signposts** | One controller-level `halo.search` interval emitted via `Sig.storage`. The doctrine names 14 specific signposts (`shadow.search.total.ms`, `shadow.embed.ms`, `shadow.ann.ms`, `shadow.bm25.ms`, `shadow.fusion.ms`, `halo.mainactor.ms`, `halo.uiApply.ms`, `panel.openLatency.ms`, etc.) — none of those exact names appear in the codebase. Doctrine §4: "every cell in this table is enforceable via os_signpost events" + "the CI artifact tracks p50/p95/p99; regressions in p99 block release" |
| Score threshold 0.2 + debounce 200ms | ✅ shipped | `HaloController.swift` `scoreThreshold` + `debounceWindowMs` parameters |
| State transitions + cancellation | ✅ shipped | `HaloController.swift:177` cooperative `pendingSearch?.cancel()` + per-state guards |

## Verdict

**Halo V1 functional surface = SHIPPED.** All four doctrine pillars
(state machine, retrieval stack, panel, FFI) are landed in production
code, integrated in the build, and reachable from the app.

**Halo V1 latency-budget enforcement = PARTIAL.** The doctrine §4
performance budget is the gate that blocks release on p99 regression,
and the doctrine spells out specific signpost names that should emit
from each pipeline stage. The current code emits one umbrella
`halo.search` interval; it does not break out per-stage timings the
way the doctrine requires for the CI p99 regression gate.

## Per-doctrine-pillar deep dive

### Pillar 1 — State machine (§5)

**Doctrine:** 6 states + errorRecoverable. Deterministic transitions.
The starter implements 5 of the 6 correctly; the missing piece is
errorRecoverable + explicit editingNote→open / summarizingChat→open.

**Code today** (`Epistemos/Models/HaloState.swift:60`):
- `dormant`, `sensing`, `available(count)`, `open(domain)`,
  `editingNote(id)`, `summarizingChat(id)`, `errorRecoverable(message)`
  — all 7 present.
- `isVisible` + `isPanelOpen` derived properties match doctrine §3.7.
- Cooperative cancellation via `pendingSearch?.cancel()`
  (`HaloController.swift:177`).

**Status: ✅ shipped to spec.**

### Pillar 2 — Retrieval stack (§3.2)

**Doctrine:** Two-lane fused (Model2Vec semantic + Tantivy BM25), RRF
fused (k=60). Model2Vec via `model2vec-rs` crate, fallback to manual
50-line port if aarch64 issues. usearch HNSW for ANN.

**Code today:**
- `epistemos-shadow/Cargo.toml:31` → `model2vec-rs = "0.1.4"` (real
  crate, no trigram fallback in production path)
- `epistemos-shadow/src/backend/embedder.rs:73` →
  `model2vec_rs::model::StaticModel::from_pretrained`
- `epistemos-shadow/src/backend/vector_index.rs` → usearch
- `epistemos-shadow/src/backend/lexical_index.rs` → tantivy
- `epistemos-shadow/src/backend/rrf.rs` → RRF (k=60 verified at
  `RRF_K_DEFAULT`)
- TrigramEmbedder still exists per doctrine §2.5 audit ("Keep as
  fallback only") — not in the live retrieval path.

**Status: ✅ shipped to spec.**

### Pillar 3 — Floating panel (§3.1)

**Doctrine:** Custom `NSPanel(.nonactivatingPanel)` hosting
`NSHostingView<SwiftUI>`. `canBecomeKey = true, canBecomeMain = false`
so the panel takes keyboard input without stealing editor focus.

**Code today** (`Epistemos/Views/Halo/ShadowPanel.swift`):
- Line 31: `styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView]`
- Line 50: `canBecomeKey: Bool { true }`
- Line 51: `canBecomeMain: Bool { false }`
- `ShadowPanelContent.swift` carries SwiftUI content + the recently-
  shifted Cognitive DAG provenance ribbon (commit 21e29ca9).

**Status: ✅ shipped to spec.**

### Pillar 4 — FFI bridge (§3.4 + Honest Handle doctrine)

**Doctrine:** Sub-1ms FFI hop. The Honest Handle FFI doctrine
(`project_honest_handle_ffi_doctrine.md`, 2026-05-04) says: opaque
handles + versioned envelopes + cross-runtime parity tests; never
expose Rust internals across the boundary.

**Code today** (`Epistemos/Engine/RustShadowFFIClient.swift`):
- 7 `@_silgen_name("shadow_handle_*")` entry points
  (open_at, retain, release, search, insert, remove, flush, stats)
- Header doc explicitly notes the legacy global-state surface
  (`shadow_open_at`/`shadow_search_json`/etc.) was REPLACED by the
  handle-based surface
- `build-epistemos-shadow.sh` produces dylib, integrated in Xcode
  build

**Status: ✅ shipped to spec.**

### Pillar 5 — Performance budget enforcement (§4)

**Doctrine:** 14 named signposts, each with target/ceiling/p99 budget,
exported as JSON regression artifact, "regressions in p99 block
release."

**Code today:**
- `HaloController.swift:188-189` emits one umbrella interval named
  `halo.search` via the test telemetry sink + `Sig.storage` for
  production
- A `grep -rn` for any of the 14 doctrine signpost names
  (`shadow.search.total.ms`, `shadow.embed.ms`, `shadow.ann.ms`,
  `shadow.bm25.ms`, `shadow.fusion.ms`, `halo.mainactor.ms`,
  `halo.uiApply.ms`, `panel.openLatency.ms`, `shadow.extract.ms`,
  `shadow.ffi.ms`, `graph.frame.ms`, `stream.flush.ms`, `db.write.ms`,
  `app.coldStart.ms`, `app.warmStart.ms`) returns ZERO matches
- No CI artifact JSON generation visible in the build pipeline for
  these signposts
- The `SearchFusionMetrics` ring buffer (per existing CLAUDE.md file
  map) records `fused_search` latency per query, but that's the RRF
  cross-index path (different from Halo retrieval) and it's a
  one-line aggregate, not the per-stage breakdown the doctrine wants

**Status: ⚠️ PARTIAL.** The retrieval pipeline works; the
**release-gating CI signpost surface does not exist yet**.

## Recommendation

V2.2 functional ship: COMPLETE. Halo V1 is reachable, demoable,
indexes the vault, runs Model2Vec semantic search + Tantivy BM25 +
RRF fusion, and surfaces results in a non-activating panel.

V2.2 doctrinal close-out: needs one focused slice to land the §4
signpost surface. Concrete shape:

1. Add 8 named signposts to the Rust hot path (in `epistemos-shadow`):
   `shadow.embed.ms`, `shadow.ann.ms`, `shadow.bm25.ms`,
   `shadow.fusion.ms`, plus `shadow.search.total.ms` as the
   end-to-end. Emit via the existing FFI seam back to Swift's
   `os_signpost`.
2. Add 4 named signposts to the Swift hot path (in
   `HaloController.swift` + `ShadowPanel.swift`):
   `halo.mainactor.ms`, `halo.uiApply.ms`, `panel.openLatency.ms`,
   `shadow.extract.ms`.
3. Wire a `bench/halo-budget` CI gate that loads the JSON regression
   artifact and fails on p99 regression vs baseline (similar shape to
   the `verify-replay` CI gate at `412f9e77`).

That slice is a discrete unit (~1-2 days) and unblocks the doctrine
phrase "regressions in p99 block release" — without it, Halo V1
ships but cannot be CI-defended against future regression.

**No code change applied this iteration** — surfacing for sign-off.

## Provenance

Audit run during the audit-with-preservation loop, slice (d). Build
verified clean before audit (`cargo test --all-targets`: 26 binaries,
1046 tests, 0 failures; `xcodebuild`: BUILD SUCCEEDED). Cross-checked
against `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` §3, §4, §5.
