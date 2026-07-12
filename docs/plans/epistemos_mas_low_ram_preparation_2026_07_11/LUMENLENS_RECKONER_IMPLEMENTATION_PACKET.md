# LUMENLENS + RECKONER Implementation Packet

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

Execution ID prepared for: `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`
Canon sources: 06_LUMENLENS_RECKONER_WORKSPACE_PLAN.md, 03 Prompt 4, 02 Phases
3–4, 04 (KEELSTONE writeback dependency), 05 (June approval dependency).
Gate: requires KEELSTONE complete AND
`EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08` complete.

## 0. Headline asymmetry

**LUMENLENS is a verify-and-harden phase** — every canon obligation has
current source. **RECKONER is a build phase** — no grid, no calc engine, no
charts, no dataset artifact writer exist; only seam hooks (Rust tabular
suggestion schema, disclosure dataset references, index awareness) are in
place. Plan capacity accordingly.

## 1. LUMENLENS requirements → source map + classification

| Canon obligation (06) | Current source | Classification |
|---|---|---|
| Epdoc/Tiptap bundled WKWebView richest lens; native chrome native | `js-editor/` bundle (`build-tiptap-bundle.sh`), `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `Epistemos/Engine/EpdocEditorBridge.swift` | EXISTING AND REUSABLE |
| Load-vs-edit guard: loadEpoch + suppression window + transaction filtering | `js-editor/src/bridge/document-load-state.ts`, `js-editor/src/bridge/inbound.ts` | EXISTING; acceptance test "stale epoch rejected" not yet found — propose T-LL-1 |
| Serializer tiers A/B/C | `js-editor/src/markdown/tiers.ts` (`SerializerTier`, tierB catalog: table/taskList/inlineMath/blockMath/callout/wikilink/highlight with prose/source degradation labels); Tier-C byte-preserving quarantine: `Epistemos/Engine/QuarantineArchive.swift` (`QuarantineEntry`, `QuarantineAnchor`, `capture()`); `Epistemos/Engine/StructureRegistry.swift`, `IntakeValve.swift`, paste classifier bridge | EXISTING AND REUSABLE |
| Minimal-diff writeback: splice in memory, full-buffer write via KEELSTONE | `Epistemos/Engine/EpdocMarkdownWriteThrough.swift` (frontmatter-aware; an `AtomicVaultWriter` caller); tested: `EditorProvenanceStoreTests` :177 "applies minimal writeback regions before saving", :222 full-markdown fallback, :329 teardown flush, :390 direct JS snapshot before host save, :435 clean switches don't save normalized snapshots | EXISTING AND REUSABLE (source+test level) + REQUIRES RUNTIME EVIDENCE (lens-switch fidelity is a KEELSTONE runtime item) |
| Suggestion seam (SuggestionAdapter) | `js-editor/src/suggestions/SuggestionAdapter.ts`, `Epistemos/Engine/EpdocAIDiffReview.swift` (`EpdocAIDiffStageRequest`, `EpdocAIDiffReviewDraft`, `EpdocSuggestionReviewDraft`), `EditorProvenanceStore.swift` bridge sink | EXISTING AND REUSABLE |
| Provenance store for editor suggestions | `Epistemos/Views/Notes/EditorProvenanceStore.swift` + 12 tests (spans persist/decide/query-by-turn, compaction, duplicate-ID refusal, missing-span decide fails loudly) | EXISTING — but see contradiction C-LL-1 below |
| Lens-fidelity disclosure | `Epistemos/Views/Notes/LensFidelityDisclosure.swift` (states, items, fenced/inline scans, `scanNotebookReferences`, `LensFidelityDatasetReference` + `exports(for:)`, `LensFidelityChartPreview`) | EXISTING AND REUSABLE — already RECKONER-aware by design |
| Epdoc Notebook manifests = references, not blobs | `Epistemos/Views/Notes/EpdocNotebookManifest.swift` (frontmatter + fenced manifest parse/render/upsert; `EpdocNotebookTab`, `EpdocNotebookTabKind`) | EXISTING; "no row blobs in embeds" enforcement test missing — propose T-LL-4 |
| Session state / conflict handoff | `NoteSessionStateMachine.swift` (lenses, `leaseHandoff`), conflict owners: `VaultSyncService.swift`, `NoteDetailWorkspaceView.swift`, `ProseEditorView.swift` | PARTIALLY IMPLEMENTED + REQUIRES KEELSTONE (dirty-open-note conflict path is a KEELSTONE done-bar; two-window clobber test missing — T-LL-5) |

### C-LL-1 (top LUMENLENS contradiction to resolve)

Two suggestion/provenance representations exist: Swift
`EditorProvenanceStore` (editor spans) and Rust
`agent_core/src/provenance/suggestion_schema.rs` (canonical prose+tabular
`Suggestion`). Canon 06 F5 forbids parallel provenance schemas. Resolution to
implement (not now): declare the Rust schema canonical; document + test the
Swift store as its projection (field-mapping table, no divergent semantics),
or route the Swift store's rows through the Rust ledger via FFI. This MUST
land before RECKONER stages tabular suggestions, or the two grammars fork.

## 2. RECKONER requirements → source map + classification

| Canon obligation (06) | Current source | Classification |
|---|---|---|
| Dataset truth = vault artifacts (CSV / XLSX / `.icalc` / `.dataset.md`) | none writes datasets; `.dataset.md` string recognized by `Epistemos/Sync/VaultIndexActor.swift`, `LensFidelityDisclosure.swift`, `JuneEpdocAssist.extractDatasetRefs` | MISSING (hooks only) |
| GRDB = derived working cache for datasets | GRDB present app-wide; no dataset cache tables | MISSING |
| IronCalc sole calc authority | not vendored (no hits in `project.yml`, `LocalPackages/`, `Epistemos/Vendor/` — Vendor is empty) | MISSING + REQUIRES OFFICIAL-SOURCE VALIDATION (see §6) |
| Univer silent renderer (bundled WKWebView asset) | not vendored | MISSING + REQUIRES OFFICIAL-SOURCE VALIDATION |
| Swift Charts primary charting | zero `import Charts` in Epistemos/ | MISSING (disclosure preview types `LensFidelityChartPoint/ChartPreview` exist as consumers) |
| Dataset tabs inside existing note/workspace tab system | `EpdocNotebookTab`/`EpdocNotebookTabKind` exist; dataset kind unverified | PARTIALLY IMPLEMENTED (manifest machinery reusable) |
| Dataset embeds carry references only | manifest design is reference-based | PARTIALLY IMPLEMENTED; enforcement test missing (T-RK-4) |
| Agent changes stage as TabularSuggestions + approval | Rust: `suggestion_schema.rs` `TabularRange`, `RangePayload::is_tabular`, `requires_approval()` — EXISTS; Swift staging UI + June dataset tools | PARTIALLY IMPLEMENTED (schema yes, everything else missing) + REQUIRES PRIOR CANONICAL ID (June approval seam) |
| No Data room, no data chat | n/a | guard test to add (T-RK-7); note older Plan 9 doc SAYS "in-tab agent chat" — REJECTED by canon 06 (see contradiction map) |

## 3. Shared contracts touched

Vault truth (dataset artifacts through `AtomicVaultWriter` +
`CoordinatedVaultFileMutation`); stable IDs (dataset ID in `.dataset.md` is
DEFINED IN THIS PHASE — owner correction 2026-07-11: the ID system is
PARTIALLY IMPLEMENTED, with existing carriers `SDPage.id` / frontmatter `id` /
`_epdoc_id` / manifest IDs; no new global ID framework unless survival tests
prove them insufficient);
editor writeback (notebook manifest upsert path); provenance
(`suggestion_schema.rs` as the ONE grammar per C-LL-1); June tools (dataset
query/clean/chart/transform register in the one registry + allowlist);
target membership (new bundled grid assets join the MAS resources build like
JuneWeb/Tiptap: build script + `bundle-app-runtime-assets.sh` pattern).

## 4. Duplicate-authority traps specific to this ID

1. Grid working store becoming truth → GRDB dataset cache must be
   delete-and-rebuild safe from artifacts (canon 04 falsifier).
2. Univer persisting computed values → IronCalc owns calc; acceptance "Univer
   never persists a computed value; IronCalc does".
3. Second suggestion grammar for tabular changes → C-LL-1 resolution first.
4. Dataset tab chat → forbidden; June surface is the only chat.
5. A second markdown serializer for dataset embeds → notebook manifest
   renderer is the one place embeds are serialized.
6. A dataset-specific FSEvents watcher → subscribe to `VaultSyncService`.

## 5. Smallest implementation batches (dependency order)

LUMENLENS first (cheap, mostly tests), then RECKONER:

- **LL-1 — acceptance-test backfill (no product code expected):** stale-epoch
  rejection, frontmatter byte-identity, Tier-C preserve+disclose,
  one-paragraph-edit → one-region diff. May expose small guard fixes.
- **LL-2 — suggestion-schema unification (C-LL-1):** mapping table + projection
  tests between `EditorProvenanceStore` and `suggestion_schema.rs`; extend FFI
  in `agent_core/src/bridge.rs` only if projection routes through Rust.
- **LL-3 — conflict/two-window handoff:** dirty-open-note conflict UX + test;
  depends on KEELSTONE conflict done-bar.
- **RK-1 — dataset artifact truth:** `.dataset.md` schema + CSV artifact
  read/write via `AtomicVaultWriter`; stable dataset ID defined here,
  consistent with the existing note-ID carriers (owner correction: no global
  ID framework unless survival tests fail); GRDB derived cache +
  rebuild-equivalence test.
- **RK-2 — silent grid spike:** vendor Univer bundled asset (license + size
  validation first, §6); renderer-only proof: loading a dataset emits zero
  autosave/change events.
- **RK-3 — calc authority:** IronCalc integration (Rust crate in agent_core or
  separate crate + FFI); Univer formula engine silenced; recalc event flow.
- **RK-4 — dataset tabs + embeds:** `EpdocNotebookTabKind` dataset case; embeds
  reference-only enforcement; LensFidelity registration (types already exist).
- **RK-5 — TabularSuggestions + June tools:** dataset query/clean/transform
  tools registered in `agent_core/src/tools/` + admitted in
  `JuneMASToolPolicy`; staging → approval → ledger via the unified schema.
- **RK-6 — Swift Charts + provenance-before-render.**
- **RK-7 — status/leak/scale hardening:** no-data-room guard, parked-presence
  leak check, large-CSV soak (ties into canon 08 storage soak suite).

## 6. External facts requiring later official-source validation

- IronCalc: current crate/license/maturity, `.icalc` format spec, WASM vs
  native-Rust embedding path (official IronCalc docs/repo). Older Plan 9
  clone-verification is provenance, not current proof.
- Univer: license terms for bundled offline use, bundle size, formula-engine
  disable switch (official Univer docs/repo). MAS rule: bundled assets only,
  no CDN.
- XLSX read/write path (e.g. CoreXLSX or IronCalc's own XLSX IO) — pick with
  license + maintenance evidence.
- Swift Charts API availability on the shipping macOS target (Apple docs).
- App Review posture for bundled WASM execution in WKWebView (canon 08 marks
  RECKONER "SAFE WITH CONDITIONS — bundled grid/WASM").

## 7. Older research: salvage vs reject

- SALVAGE as spec appendix: `PROMPT_PLAN_9_DATA_TABLES.md` (silent-Univer ×
  IronCalc keystones, dual-zone formulas, defined-name refs), editor lens
  canon (`EDITOR_CANONICAL_PLAN`), June ontology tokens.
- REJECT: Plan 9's "GRDB truth" (canon: artifacts truth, GRDB derived),
  Plan 9's "in-tab agent chat" (canon 06: no data chat), any Data-room shape,
  pre-pivot execution order.

## 8. Proposed regression tests

Exact names/fixtures/assertions in `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md`
(T-LL-1…5, T-RK-1…7 series).

## 9. Manual/runtime evidence required after implementation

Stale-epoch rejection demo; rich-fixture lens round-trip (already a KEELSTONE
matrix item — re-run on this phase's build); dataset open emits zero autosave
events (log); Univer-persists-nothing proof (artifact byte diff after
open/recalc); one staged TabularSuggestion approved and applied with ledger
row + artifact hash; chart renders with provenance row present; embed
markdown contains no cell data (fixture diff).
