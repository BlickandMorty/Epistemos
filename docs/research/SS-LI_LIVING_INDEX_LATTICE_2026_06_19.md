# SS-LI — Living-Index + Lattice Explorer (the "absolutely last, indefinite" item) (2026-06-19)

Read-only research (subagent), code-grounded. The owner's explicitly-LAST, indefinite item — researched only
after the finite backlog (A–Z + AA/AB) completed. Cross-refs the shadow index + Cognitive DAG. **Honest framing:
this is a large open frontier, NOT a quick win.**

## Headline
The SUBSTRATE for a living index already exists + is real (a continuously-updating shadow search index
BM25+HNSW+RRF, a content-addressed Cognitive DAG with resonance propagation, a vault file-watcher, rich Metal/
Hologram graph views). What does NOT exist is the *unified surface* the owner means: **no `LivingIndex` type, no
concept-lattice/FCA engine, no in-app lattice-explorer UI.** The two named "Living Index"/"lattice" artifacts are
(a) a Markdown doc (`EPISTEMOS_LIVING_INDEX_2026_05_24.md`) and (b) a standalone 707KB HTML explainer
(`artifacts/lattice-coordinate-explainer/index.html`) **NOT wired into the app** (zero Swift refs). The ledger
correctly flags this as INDEFINITE/open-ended, to do absolutely last (`OWNER_REQUESTS_LEDGER_2026_06_18.md
:1480-1493`).

## Living index — substrate today
- **Halo Shadow index** = the real index substrate (tantivy BM25 + usearch HNSW + RRF): `Engine/Shadow
  SearchService.swift`, `ShadowIndexingService.swift`, `ShadowVaultBootstrapper.swift`; Rust `epistemos-shadow/
  src/{lib.rs,state.rs,backend/}`.
- **It IS incrementally "living," not static-rebuild:** `ShadowIndexingService` (actor `:57`) coalesces inserts/
  removes on a **500ms debounce** (`:15,36,84,143`), driven by `ShadowVaultBootstrapper.swift:144` + a vault
  **file-watcher** (`Sync/VaultSyncService.swift:3573 startFileWatcher`, DispatchSource vnode + debounce). Edits
  to `<vault>/notes/**` flow into the index live — the closest existing thing to a "living index."
- **RRF cross-index fusion** (self-organizing across indices): `Sync/RRFFusionQuery.swift` +
  `SearchIndexService.fusedSearch`; k=60 SOT `epistemos-shadow/src/backend/rrf.rs`.
- **Cognitive DAG** = the provenance/knowledge-graph substrate: `agent_core/src/cognitive_dag/` — 10 NodeKind +
  10 EdgeKind (`node.rs`/`edge.rs`), BLAKE3 content-addressed, Merkle root (`merkle.rs`), **resonance
  propagation** (Kleene-K3 truth, cascading invalidation along reverse DerivesFrom/Contradicts, `resonance.rs`).
  **Caveat: resonance is library-complete but NOT yet live-driven** — only callers outside the module are tests +
  `provenance/replay.rs:699`; it's a Phase-8.B scaffold mirroring writes, not yet authority (`cognitive_dag/mod
  .rs:27-29`). The DAG is "alive" in capability but not continuously self-propagating in production.

## Lattice — what exists / what's meant (false friends)
1. **`LatticeWBO`** (`Epistemos/LatticeWBO/LatticeWBOWiring.swift`, `agent_core/src/oplog.rs:522-532
   oplog_lattice_wbo`) = an oplog **write-budget/observability accountant** (a health row), UNRELATED to a UI
   lattice. Misleading name.
2. **`lattice-coordinate-explainer/index.html`** = a standalone HTML visualization of the system's own
   coordinate/ambition map; **doc artifact only, NOT in-app** (verified no Swift refs).
3. The genuine "navigable concept lattice" intent lives **only as aspirational doctrine** (`docs/_consolidated/
   00_canonical_authority/EXPLORATION_SPECTRUM_N3.md` — N3 "infinite concept doors"/`ConceptNode` tree, no
   shipped engine). **No FCA/formal-concept-analysis code exists** (verified).
- Disambiguation: "EML / episodic-memory-lattice" is NOT a memory lattice — EML = the math primitive
  `eml(x,y)=exp(x)−ln(y)` (`docs/UNFINISHED_RESEARCH_SWEEP_2026_06_18.md:49-56`). Don't conflate.

## Graph / knowledge-viz substrate (reusable today, shippable)
- `Epistemos/Graph/`: `GraphState.swift` (live model), `GraphBuilder/GraphEngine/GraphStore.swift`,
  `SemanticClusterService.swift` (embedding clustering), `EmbeddingService.swift`, `OntologyClassifier.swift`,
  `EntityExtractor.swift`.
- `Epistemos/Views/Graph/`: `MetalGraphView.swift` (GPU force-graph), `HologramOverlay.swift`, `HologramNode
  Inspector.swift`, `HologramSearchSidebar.swift`, `GraphWorkspaceContainer.swift`, and a read-only
  **`CognitiveDagVisualizerPanel.swift`** that already polls DAG node/edge/merkle counts at 1Hz
  (`SubstrateHealthUnifiedClient.snapshot()`) — the **embryonic "living index status" surface.**

## The gap (reusable vs net-new)
- **Reusable:** shadow index + file-watcher + RRF (the "living" feed); DAG schema + resonance + Merkle (the
  knowledge graph); MetalGraphView/Hologram (rendering); EmbeddingService/SemanticClusterService (clustering);
  the DAG visualizer panel (status mirror).
- **Net-new (the open frontier):** (1) a **`LivingIndex` orchestrator** unifying shadow-index + DAG + provenance
  into one continuously-updating, resonance-propagating, provenance-aware index with a *live driver* wiring
  `propagate_truth_change` into the write path (today scaffold/replay-only); (2) a **concept-lattice/FCA engine**
  (objects×attributes → concept lattice) — NO impl exists, only N3 doctrine; (3) a **lattice explorer UI**
  (navigable concept/knowledge-lattice surface — the Hologram view is force-directed clustering, NOT a
  partial-order lattice); (4) **T4 promotion** (reachable/visible/verified/logged/rollback) per the Architecture
  Promotion Canon — DAG/resonance are blue scaffold, not green.

## Honest scoping + a bounded first step
Correctly sequenced LAST: most architecturally open (a real concept-lattice/FCA layer is net-new research);
depends on the rest being solid (search/model/skills, the DAG flipped to authority at Phase 8.H); owner scoped
it as a NON-terminating loop that recursively mines its own research corpus (`OWNER_REQUESTS_LEDGER_2026_06_18
.md:1487-1493`) — start only after all finite work. **Bounded first step (read-only, no new engine):** extend
`CognitiveDagVisualizerPanel.swift` into a read-only **"Living Index status"** surface showing (a) shadow-index
liveness (last flush, pending queue, file-watcher active — data already in `ShadowIndexingService` +
`VaultSyncService.swift:3515-3520`) alongside (b) DAG node/edge/merkle/resonance counts already mirrored — i.e.
**surface what's already living as one panel BEFORE attempting any lattice engine.** Finite, T4-promotable, proves
the concept without opening the indefinite loop.

## Unverified
Did not render the 707KB `lattice-coordinate-explainer/index.html` (verified only that it's not Swift-referenced).
"Resonance not live-driven" is from caller-grep (tests + replay.rs:699 only) — if a live driver exists under an
unenumerated feature flag, treat as unverified.

Key files: `Engine/{ShadowIndexingService,ShadowSearchService,ShadowVaultBootstrapper}.swift`; `epistemos-shadow/
src/{lib.rs,state.rs,backend/rrf.rs}`; `Sync/{RRFFusionQuery.swift,VaultSyncService.swift:3573}`; `agent_core/src/
cognitive_dag/{mod,node,edge,resonance,merkle,storage}.rs`; `Epistemos/LatticeWBO/LatticeWBOWiring.swift` +
`oplog.rs:522` (false friend); `artifacts/lattice-coordinate-explainer/index.html` (doc only);
`docs/_consolidated/00_canonical_authority/EXPLORATION_SPECTRUM_N3.md` (aspirational); `Views/Graph/{MetalGraph
View,HologramOverlay,CognitiveDagVisualizerPanel}.swift`; `Graph/{GraphState,SemanticClusterService,Embedding
Service}.swift`; ledger `:1480-1493`; `EPISTEMOS_LIVING_INDEX_2026_05_24.md`.
