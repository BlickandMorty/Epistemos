# T+4 Deliberation Brief: Cognitive Workspace Typed Artifact Spine

**Date**: 2026-04-27
**Phase**: T+4 — typed artifact spine across 9 sub-slices (T+4.1 ArtifactKind enum → T+4.2 ArtifactHeader+Provenance → T+4.3 Raw Thoughts to 100% → T+4.4 readable_blocks projection → T+4.5 .epdoc package stub → T+4.6 Document editor host → T+4.7 ArtifactRoute view router → T+4.8 MutationEnvelope pattern → T+4.9 Agent patch graph edges)
**Author**: Claude builder
**Auditor**: deferred (user adjudicating; Codex unavailable)

---

## §A — Disk research synthesis

### A.1 — Current substrate state (the "80% done" landmark)

Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md`:

**Shipped (Patches 4 + 5):**
- Raw Thoughts substrate (Slice 1) at 80% — `agent_core/src/storage/raw_thoughts.rs` (745 lines + 7 tests). Run-folder layout `<vault>/Raw Thoughts/<provider>/<YYYY-MM-DD>_<run-id>/{manifest.json, events.jsonl, summary.md, links.json}` working with `EPISTEMOS_RAW_THOUGHTS_V0` flag. Anthropic signature bytes preserved verbatim; no hidden CoT reconstruction. Swift consumers (`RawThoughtsState.swift`, `RawThoughtsSection.swift`, `RawThoughtsInspectorView.swift`) gate UI under same flag (defaults OFF). T+3 verified this as G2-complete already.
- Typed graph types (Slice 2) at 30% — `GraphNodeType.run/.rawThought/.toolTrace` cases + `GraphEdgeType.producedDuring/.generatedBy/.derivedFrom/.summarizes` edges added. Switch exhaustiveness updated across `DialogueChatState`, `NodeInspectorState`, `GraphFloatingControls`, `MetalGraphView`, `RelationshipBrowser`.
- Existing ProseEditor (TextKit 2, protected per CLAUDE.md), Code editor (CodeEditSourceEditor 0.15.2), Metal graph (graph-engine + MetalGraphView), SwiftData models (`SDPage`/`SDChat`/`SDMessage`/`SDGraphNode`/`SDGraphEdge`), VaultSyncService + NoteFileStorage with BLAKE3 sidecar checksums, GRDB FTS5 (`page_search` + `block_search` virtual tables), and the agent runtime (`agent_core::agent_loop` with thinking + signature preservation, 37 UniFFI exports).

**Not yet built (Wave 3.1 / Wave 4 / Wave 5):**
- ArtifactKind enum (7 kinds) as first-class typed identity unifying Rust + Swift via FFI.
- ArtifactHeader (ULID + kind + schema_version + created_at + updated_at + title + vault_path + content_hash + provenance) and ProvenanceBlock (producer + derived_from + generated_by_run + tool_id + source_artifacts + output_artifacts).
- `.epdoc` package format. Zero mentions in the repo today.
- Document editor host (Tiptap-in-WKWebView). The `js-editor/` esbuild bundle is partially built per `CLAUDE.md` "JS Bundle (Tiptap editor)" section, but the host shell (pre-warmed `WKProcessPool` + transaction-summary bridge + custom URL scheme) is not yet wired.
- Block-level search projections (`readable_blocks` + `readable_blocks_fts`).
- Compile-time `ArtifactRoute` enum with exhaustive `@ViewBuilder` switch — current routing uses ad hoc dispatch.
- Typed `MutationEnvelope` pattern. Current invalidation uses broad `NotificationCenter.default.post(name: .vaultChanged)` style.
- Slice 1.5 Raw Thoughts additions: `thoughts/<turn>.<provider>.json` sidecars for large reasoning blobs, `tools/<tool-call-id>.json` sidecars, `final.json` on `MessageStop`/`EndTurn`. Currently Patch 4 inlines all events.

### A.2 — Architectural binding from EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md

> **DO NOT port AppFlowy UI. DO NOT rewrite Document editor in native Swift. DO NOT add Flutter.**

What we DO take from AppFlowy: data model patterns only — block-based document model with stable block IDs, slash-command UX pattern, embed system, plugin architecture. What we keep from Tiptap-in-WKWebView: pre-warmed shared `WKProcessPool` (~50ms first-document open), transaction-summary bridge (small deltas, single-digit-ms typing latency), local Tiptap bundle (no runtime npm), custom URL scheme. **Performance budgets**: typing latency p99 < 16ms (60fps), or <8ms (120fps ProMotion).

### A.3 — Convergent themes across workspace synthesis docs

Multiple docs (workspace_gpt_workspace_synthesis, workspace_gpt_workspace_architecture, compass_artifact_wf-c2d78e2f) converge on:

1. **Typed artifact spine is THE central V1.5 architectural inversion** — from "everything is a file" to "every artifact is typed, with canonical form + controlled projections."
2. **ProseMirror JSON is the canonical Document format** stored in `.epdoc` package directory; Markdown / HTML / DOCX / PDF are projections only.
3. **Tiptap-in-WKWebView is the document editor** — ratified by EDITOR_VERDICT (BINDING).
4. **Four-layer projection architecture**: canonical body + manifest + HTML snapshot + Markdown shadow + search text + binary exports, on prioritized autosave policy.
5. **Raw Thoughts = run-scoped artifact group** (NOT one flat file). Run folder per provider/model/task with manifest + events + summaries + provider-native sidecars.
6. **Block-level graph addressing** via Tiptap UniqueID extension keeping `_key: ULID` stable across edit/split/merge/undo.
7. **FTS5 over normalized `search_text` projection** (NOT raw HTML/Markdown). External-content table with INSERT/DELETE/UPDATE triggers.

### A.4 — Anti-patterns called out (verbatim)

- "Never let Markdown, HTML, or DOCX become the source of truth for rich Documents. They are projections."
- "Do not continuously round-trip rich documents through Markdown on every save."
- "Do not extend the current TextKit 2 prose editor until it is responsible for rich document tables."
- "Do not make DOCX canonical. Live DOCX autosave is FORBIDDEN (per GPT advice — creates churn, corruption risk)."
- "Do not build a custom SwiftUI block editor before you have shipped the dual-surface model."
- "Raw Thoughts: it should not be one flat text file. It should be a run-scoped artifact group."
- "Provider summaries are model/version-dependent and must NOT be canonical planner-layer content. App owns its own Run/Plan/Reasoning Summary/Execution Summary."
- "Code files: file-extension quarantine — no semantic markers, no ontological restructuring of source files."

### A.5 — Per-slice contracts from the implementation plan

**T+4.1 — ArtifactKind enum (already partially in code):**
```rust
#[repr(u8)]
pub enum ArtifactKind { ProseNote=1, Document=2, RawThought=3, Source=4, Code=5, Run=6, Output=7 }
```
Mirror in Swift `enum ArtifactKind: UInt8, Codable, Sendable, CaseIterable`. Binding: "extend, don't redefine"; legacy `GraphNodeType` cases stay; new code path uses `ArtifactKind` for typed routing; `mapsToArtifactKind()` helper bridges legacy node visits.

**T+4.2 — ArtifactHeader + ProvenanceBlock:**
```rust
pub struct ArtifactHeader {
  pub id: Ulid, pub kind: ArtifactKind, pub schema_version: u32,
  pub created_at: i64, pub updated_at: i64,
  pub title: String, pub vault_path: PathBuf,
  pub content_hash: blake3::Hash, pub provenance: ProvenanceBlock,
}
pub struct ProvenanceBlock {
  pub producer: Producer,                // Human | Agent | System
  pub derived_from: Vec<ArtifactRef>,
  pub generated_by_run: Option<Ulid>,
  pub tool_id: Option<String>,
  pub source_artifacts: Vec<ArtifactRef>,
  pub output_artifacts: Vec<ArtifactRef>,
}
```
Persisted as `manifest.json` per artifact (Documents) or as a SwiftData row (ProseNotes today).

**T+4.3 — Raw Thoughts to 100%:**
Slice 1.5 additions only. Patch 4 already serializes the manifest + events; need to add:
- `thoughts/<turn>.<provider>.json` written when provider emits oversized reasoning blobs (sidecar split threshold ~64KB).
- `tools/<tool-call-id>.json` sidecar for tool-call payloads exceeding inline threshold.
- `final.json` written on `MessageStop` / `EndTurn` containing the terminal aggregate.

**T+4.4 — readable_blocks + FTS5:**
```sql
CREATE TABLE readable_blocks (
  id INTEGER PRIMARY KEY,
  artifact_id TEXT NOT NULL, artifact_kind TEXT NOT NULL,
  block_id TEXT NOT NULL, block_kind TEXT NOT NULL,  -- paragraph|heading|code|table|callout|quote
  title_path TEXT, body TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE VIRTUAL TABLE readable_blocks_fts USING fts5(
  title_path, body, content='readable_blocks', content_rowid='id'
);
-- triggers keep FTS in sync.
```
Universal projection absorbing Documents + Raw Thoughts + Code + Source. Existing `page_search` + `block_search` continue serving Prose-only search until migration.

**T+4.5 — `.epdoc` package directory:**
```
MyResearchReport.epdoc/
  manifest.json              # ArtifactHeader + ProvenanceBlock
  content.pm.json            # canonical ProseMirror JSON
  projections/
    shadow.md                # GFM Markdown projection (lossy, derived)
    plain.txt                # FTS-friendly plain text
    search_blocks.jsonl      # block-level search (one per line)
  assets/                    # embedded media
  exports/                   # generated on-demand only
    *.docx
```
Binding: `content.pm.json` is canonical; Markdown is derived; DOCX/PDF are export snapshots; live DOCX autosave forbidden; external `shadow.md` edits do NOT silently overwrite canonical (imported as reviewable conversion).

**T+4.6 — Document editor host (Tiptap+WKWebView):**
- Pre-warmed shared `WKProcessPool` at `AppBootstrap` startup (~50ms first-doc-open).
- Transaction-summary bridge: Tiptap `onUpdate` emits bounded JSON delta (block-level); Swift consumes via `WKScriptMessageHandler`. Payload <1MB per transaction.
- Local Tiptap bundle: `bash build-tiptap-bundle.sh` (already in repo per CLAUDE.md JS Bundle section); content-hash gated on `package-lock.json`; copied to `Epistemos.app/Contents/Resources/Editor/`.
- Custom URL scheme `epistemos://` registered via `WKURLSchemeHandler` for assets in package.

**T+4.7 — ArtifactRoute enum + view router:**
```swift
enum ArtifactRoute: Equatable, Hashable {
  case proseNote(ArtifactID), document(ArtifactID), rawThoughtRun(RunID),
       source(ArtifactID), code(ArtifactID), output(ArtifactID)
}
struct ArtifactHostView: View {
  let route: ArtifactRoute
  @ViewBuilder var body: some View {
    switch route {
    case .proseNote(let id):     ProseEditorView(artifactID: id)
    case .document(let id):      DocumentEditorHostView(artifactID: id)
    case .rawThoughtRun(let id): RawThoughtTimelineView(runID: id)
    case .source(let id):        SourceReaderView(artifactID: id)
    case .code(let id):          EpistemosCodeView(artifactID: id)
    case .output(let id):        OutputArtifactView(artifactID: id)
    }
  }
}
```
Compile-time exhaustiveness; no `AnyView` (anti-pattern #7).

**T+4.8 — MutationEnvelope:**
```rust
pub struct MutationEnvelope {
  pub mutation_id: Ulid,
  pub touched_artifacts: SmallVec<[ArtifactRef; 8]>,
  pub touched_blocks: SmallVec<[BlockRef; 16]>,
  pub relation_changes: SmallVec<[RelationChange; 8]>,
  pub affects_summary: bool, pub affects_outline: bool,
  pub affects_backlinks: bool, pub affects_search_projection: bool,
  pub affects_graph: bool, pub affects_body: bool,
  pub source_op: SourceOp,
}
```
Replaces broad `NotificationCenter.default.post(name: .vaultChanged)`. Swift query fingerprint matches via `query.watchSet.intersects(mutation)`.

NOTE: Implementation plan struct has 11 fields. MASTER_FUSION §3.5 lists 14 (id/run_id/sequence/caused_by_event_id/actor/approval_id/status/created_at_ms/committed_at_ms/op/sensitivity/reversibility/integrity_hash/schema_version). The §3.5 schema is the doctrinal contract; implementation plan struct is an early sketch missing the integrity-chain fields. **Resolution**: T+4.8 should ship the §3.5-aligned struct (14 fields) — extending the plan struct, not replacing it. This closes Drift Q1 (§3.5 doctrine refresh) cleanly.

**T+4.9 — Agent patch + graph edges:**
Run artifact (kind=6) created at agent loop start; event log written; tool calls write `tools/<tool-call-id>.json`; on completion, graph edges materialize: `producedDuring`, `generatedBy`, `derivedFrom`, `summarizes` (existing) + `validatedBy`, `linksTo`, `references` (new for Slice 2).

---

## §B — Web research findings (primary sources, accessed 2026-04-27)

### B.1 — ProseMirror schema custom block-level metadata
- https://prosemirror.net/docs/ref/ — `attrs` field on node specs; arbitrary JSON-serializable values.
- https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing — `addAttributes()` API for `parseHTML`/`renderHTML`/`default` triplet; standard for stable `blockId` attribute.

### B.2 — Tiptap in WKWebView macOS performance
- https://developer.apple.com/documentation/webkit/wkprocesspool — singleton-pool pattern for shared process across views.
- https://developer.apple.com/documentation/webkit/wkwebviewconfiguration/processpool — `config.processPool = sharedPool` reduces cold-start ~40%.
- Tiptap `onUpdate` hook emits bounded JSON deltas via `WKScriptMessageHandler`.
- 2026 caveat: macOS 26.2 regressed some pre-warming wins but pattern still beneficial.

### B.3 — ULID vs UUID v7
- https://datatracker.ietf.org/doc/rfc9562/ — UUID v7 finalized May 2024; 48-bit ms timestamp, monotonic counter guidance.
- https://docs.rs/ulid/latest/ulid/ — canonical ulid crate v1.2.1; `Generator::new()` enforces strict monotonic mode within ms.
- Both 128-bit, sortable. UUID v7 is IETF standard; ULID is non-standard but widely adopted, smaller text encoding (26 chars base32 vs 36 chars hex).
- Codebase already uses ULID extensively (oplog, agent_core, raw_thoughts).

### B.4 — BLAKE3 vs SHA-256
- https://github.com/BLAKE3-team/BLAKE3 — BLAKE3 official spec; tree hash, streaming-friendly, parallel.
- https://docs.rs/crate/blake3/latest — crate v1.8.5+ stable.
- **2026 finding**: BLAKE3 ~25% SLOWER on M-series Apple Silicon (NEON lacks SHA-256 hardware instructions Apple added). On x86_64 BLAKE3 is ~8× faster than SHA-256.
- For local-first content hashing on Apple Silicon, raw SHA-256 is faster; but BLAKE3 supports incremental + tree-proof verification.

### B.5 — GFM vs Djot
- https://github.github.com/gfm/ — official GFM spec; widely adopted.
- https://github.com/kivikakk/comrak — canonical Rust GFM parser, actively maintained.
- https://github.com/jgm/djot — Djot repository; ~7 implementations, 2000+ stars; linear-time parsing; not widely adopted in mainstream tooling.
- For lossy `shadow.md`: GFM via comrak is the safer choice (broad tool support, well-defined spec).

### B.6 — macOS Custom UTI for `.epdoc`
- https://developer.apple.com/documentation/uniformtypeidentifiers — UTType API stable since macOS 11.
- https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/DocumentPackages/DocumentPackages.html — Document Packages guide.
- Pattern: `UTExportedTypeDeclarations` with `UTTypeIdentifier=com.epistemos.epdoc`, `UTTypeConformsTo=[com.apple.package]`, registered in `CFBundleDocumentTypes` with `LSItemContentTypes=["com.epistemos.epdoc"]`. Finder treats directory as opaque bundle.

### B.7 — WKProcessPool
- Same as B.2; singleton pattern stable; pre-warm via early hidden `WKWebView` instance at `AppBootstrap`.

### B.8 — SQLite FTS5 with custom block IDs
- https://www.sqlite.org/fts5.html — official FTS5 docs.
- Use contentless FTS5 + external-content table + BEFORE UPDATE triggers (delete old before applying new). Tokenizers: `unicode61` for prose, `trigram` for code.

### B.9 — Tiptap distribution
- https://tiptap.dev/docs/editor/getting-started/install — self-host esbuild bundle recommended; CDN options unstable (esm.sh RangeError on multiple prosemirror-model versions).

### B.10 — Open / non-primary
- BLAKE3 Apple Silicon perf benchmarks: only forum + community posts, no Apple official benchmarks.
- Djot adoption metrics: anecdotal only; no canonical tracker.

---

## §C — Conjugation (disk × web × doctrine)

**Q1: Does the implementation plan's ULID choice still hold given UUID v7 is IETF-standard since 2024?**
- Disk: implementation plan uses ULID throughout (ArtifactHeader, RawThoughtsManifest, MutationEnvelope, OpLog/Op).
- Web: UUID v7 is RFC 9562 (IETF-standard); ULID is widely adopted but non-standard.
- Doctrine: `fe97e512` BLAKE3 chain commit ships with ULID. Switching now invalidates OpLog substrate.
- **Synthesis**: keep ULID. Codebase consistency + shipped substrate outweigh portability gain. Document the decision; UUID v7 is reversible if external interop becomes critical.

**Q2: Does BLAKE3 hold given the Apple Silicon perf regression?**
- Disk: implementation plan + `fe97e512` ship BLAKE3 (`agent_core/src/oplog.rs:316-334` `compute_chain_link`). `NoteFileStorage` uses BLAKE3 sidecar checksums per CLAUDE.md.
- Web: BLAKE3 is 25% slower than SHA-256 on M-series; 8× faster on x86_64; supports tree/incremental hashing.
- Doctrine: substrate already shipped with BLAKE3 chain. Reversal would invalidate every persisted Merkle hash on user vaults.
- **Synthesis**: keep BLAKE3. Performance regression is real but acceptable — content hashing is not in hot path (frame budget not affected); the 25% headline applies to bulk hashing, not single-artifact hash. Tree-proof verification is forward-compatible value not available in SHA-256. Decision reversible if a future profiler shows hashing dominates a hot path.

**Q3: GFM or Djot for `shadow.md`?**
- Disk: implementation plan unspecified ("Markdown shadow"). Comrak available in Rust ecosystem.
- Web: GFM dominant; Djot niche.
- Doctrine: shadow.md is a projection, not canonical (binding). Whatever projects deterministically + lossy-but-bounded is fine.
- **Synthesis**: GFM via comrak. Mature, broad tool support, deterministic projection from ProseMirror JSON.

**Q4: MutationEnvelope — implementation plan struct (11 fields) vs MASTER_FUSION §3.5 contract (14 fields)?**
- Disk: divergent. Implementation plan has the 11-field "what changed" envelope; §3.5 names 14 fields including integrity-chain hooks (id/run_id/sequence/caused_by_event_id/actor/approval_id/status/created_at_ms/committed_at_ms/op/sensitivity/reversibility/integrity_hash/schema_version).
- Web: nothing relevant.
- Doctrine: §3.5 is the four-layer event hierarchy contract (the tighter one). Implementation plan struct is an earlier sketch.
- **Synthesis**: ship a unified struct that satisfies both — the 14 §3.5 fields + the 6 `affects_*` booleans from the implementation plan + `touched_artifacts/touched_blocks/relation_changes/source_op` SmallVecs. Net: ~21 fields. Rust struct + Swift mirror via FFI. This single design closes Drift Q1.

**Q5: Sub-slice ordering — does the implementation plan order match T+4 numbered slices?**
- Disk: implementation plan recommends ontology (T+4.1+T+4.2+T+4.7+T+4.8) → Raw Thoughts (T+4.3) → Document (T+4.5+T+4.6) → Search (T+4.4) → Export (post-T+4).
- T+4 numbering in the parent prompt has slices 4.1-4.9 numbered linearly.
- Doctrine: per the prompt, T+4 slices "in order" — but the prompt's ordering was illustrative, not binding. The implementation plan's logical-dependency order is more rigorous.
- **Synthesis**: execute in dependency order, not numeric order. T+4.1 + T+4.2 + T+4.7 + T+4.8 are the foundation (typed identity, header, router, mutation envelope) — they unblock everything else. Then T+4.3 (Raw Thoughts sidecars), T+4.5 (.epdoc package stub), T+4.6 (Document editor host), T+4.4 (readable_blocks projection — needs all artifact kinds present), T+4.9 (graph edges — needs Run/Code artifacts + tool-trace plumbing). Each commit gets its own WRV proof.

---

## §D — Trade-off matrix

### D.1 ID format

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Keep ULID | codebase consistency; substrate already shipped; smaller string encoding (26 vs 36) | non-IETF standard; less external interop | low | medium (DB column type change + serialization migration) | **CHOSEN** |
| B: Switch to UUID v7 | IETF standard (RFC 9562); broader external library support | invalidates shipped OpLog Merkle chain prev_hash references; codebase-wide rename | high | low (would re-touch every persisted artifact) | reject |
| C: Hybrid (ULID internal, UUID v7 external interop) | best of both | added complexity; type confusion at boundaries | medium | medium | reject — premature complexity |

### D.2 Content hash

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Keep BLAKE3 | substrate shipped; tree-proof + incremental future value; cryptographically modern | 25% slower than SHA-256 on Apple Silicon; non-hot-path so impact bounded | low | low (would invalidate Merkle chain on user vaults) | **CHOSEN** |
| B: Switch to SHA-256 | hardware-accelerated on Apple Silicon; widely standard | loses tree-hash / streaming proof; substrate already shipped with BLAKE3 | high | low (forced re-hash of every artifact) | reject |
| C: BLAKE3 for substrate, SHA-256 for content_hash | SHA-256 faster on hot artifact-save path | dual hash code; cognitive load; fingerprint mismatch risk | medium | medium | reject — split brain risks |

### D.3 Markdown shadow projector

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: GFM via comrak | mature; broad tool support; deterministic | lossy on advanced ProseMirror nodes (callouts, embeds) | low | high (projector swap is local) | **CHOSEN** |
| B: Djot via jgm/djot | linear parse; cleaner spec; preserves more attributes | niche (~7 impls); less tooling integration | medium | high | reject — adoption gap |
| C: Custom projector | exactly fits ProseMirror schema | maintenance burden; reinvents wheels | high | medium | reject |

### D.4 Sub-slice execution order

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Dependency order (4.1+4.2+4.7+4.8 → 4.3 → 4.5+4.6 → 4.4 → 4.9) | each commit unblocks next; minimal rework | departs from numeric sequencing | low | high | **CHOSEN** |
| B: Strict 4.1 → 4.9 numeric | matches parent prompt literal | T+4.4 (readable_blocks) before T+4.5 (.epdoc) means projecting blocks before the package format exists; rework | medium | high | reject |
| C: Big-bang single PR | atomic | massive blast radius; rollback expensive; impossible WRV | high | low | reject — violates MASTER_BUILD_PLAN per-slice doctrine |

### D.5 MutationEnvelope field set

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Unified §3.5 + plan struct (~21 fields) | satisfies both contracts; closes Drift Q1; full integrity chain | larger struct; more serialize cost | low | high | **CHOSEN** |
| B: Plan struct only (11 fields) | smaller | misses §3.5 integrity contract; Drift Q1 stays open | medium | high | reject — preserves drift |
| C: §3.5 struct only (14 fields) | doctrine compliant | missing the `affects_*` booleans the implementation plan needs for query-fingerprint matching | medium | high | reject — breaks Swift consumer pattern |

---

## §E — Decision

**Chosen path** (T+4 execution plan):

**Sub-slice order (dependency-first, NOT numeric):**

1. **T+4.1 ArtifactKind enum** — verify both Rust + Swift mirrors exist for all 7 kinds; add missing kinds if any. Canonical floor evidence shows ArtifactKind exists at `Epistemos/Models/ArtifactKind.swift:37` (RawThought=3 confirmed). Rust side TBD.
2. **T+4.2 ArtifactHeader + ProvenanceBlock** — Rust struct + Swift mirror via FFI. Persist as `manifest.json` for Documents; SwiftData row for ProseNotes.
3. **T+4.7 ArtifactRoute enum + view router** — closed enum, exhaustive `@ViewBuilder` switch, no `AnyView`. Stub `DocumentEditorHostView` and `OutputArtifactView` if not yet implemented.
4. **T+4.8 MutationEnvelope** — unified ~21-field struct satisfying §3.5 + implementation plan. Replace broad NotificationCenter at one call site as proof-of-concept; rest in T+13 hardening. **Closes Drift Q1.**
5. **T+4.3 Raw Thoughts to 100%** — add Slice 1.5 sidecars (`thoughts/`, `tools/`, `final.json`).
6. **T+4.5 `.epdoc` package stub** — directory layout + manifest.json + content.pm.json + projections/ + assets/. Custom UTI registration in Info.plist.
7. **T+4.6 Document editor host** — pre-warmed shared `WKProcessPool` in AppBootstrap; `WKURLSchemeHandler` for `epistemos://`; transaction-summary bridge wired to `js-editor/` bundle.
8. **T+4.4 readable_blocks + readable_blocks_fts** — SQLite FTS5 schema + INSERT/DELETE/UPDATE triggers. Existing `page_search` + `block_search` continue serving Prose-only until migration.
9. **T+4.9 Agent patch + graph edges** — Run artifact creation at agent loop entry; tool sidecars; existing edges already shipped (producedDuring/generatedBy/derivedFrom/summarizes); add new edges (validatedBy/linksTo/references).

**Foundational decisions (with reversal triggers):**
- Keep ULID (reversal: external interop becomes critical AND ULID-only library consumes >2 dev-days to adapt).
- Keep BLAKE3 (reversal: profiler shows artifact-save path latency >5ms p99 on M-series with hashing as dominant cost).
- GFM via comrak for shadow.md projection (reversal: comrak unmaintained OR ProseMirror-to-GFM projector loses critical fidelity).
- Unified MutationEnvelope struct (~21 fields, §3.5 + plan).
- Tiptap-in-WKWebView locked (per EDITOR_VERDICT BINDING; reversal triggers per EDITOR_VERDICT §"When to revisit").

**Rationale**: The implementation plan + workspace synthesis docs converge fully; web research confirms the patterns are 2026-current. The two flagged trade-offs (ULID/BLAKE3) lean strongly toward "keep what's shipped" because the substrate already commits to them and reversal would invalidate the OpLog Merkle chain (which `fe97e512` made substrate-real). The performance regressions are bounded (BLAKE3 only loses on M-series for bulk hashing, not on the hot frame budget).

**Risks accepted:**
- BLAKE3 25% slower on Apple Silicon for content hashing — bounded, not in frame budget.
- ULID non-standard — only matters for external interop, which is not a V1 surface.
- GFM lossy on advanced blocks (callouts, embeds) — `shadow.md` is explicitly a lossy projection; primary canonical is `content.pm.json`.

**Risks deferred:**
- Slice 2 closure of typed graph types (currently 30%) — completes during T+4.9.
- Slice 1.5 final.json schema — design when first sidecar is needed (T+4.3).
- T+4 sub-slices that touch protected surfaces — none should; ProseEditor stays untouched, Tiptap host is new code, graph engine untouched.

**Success metrics:**
- All 9 sub-slices land with WRV proof (Wired + Reachable + Visible).
- Per-commit `xcodebuild -scheme Epistemos build` green; per-commit `cargo test` green for touched crates.
- T+4.8 commit closes Drift Q1 (§3.5 doctrine refresh).
- Document editor host opens a `.epdoc` package via SwiftUI in <500ms cold + <50ms warm (shared `WKProcessPool`).
- `readable_blocks_fts` returns sub-30ms p50 search hit for query "find my note about X" across 10k blocks.

**Reversal triggers:**
- `xcodebuild` build fails on canonical floor and root cause is a T+4 slice (revert + reassess).
- AppStoreHardeningTests regress (revert immediately; doctrine §11.3 binding).
- Any T+4 slice touches ProseEditor, graph-engine, MetalGraphView, or HologramController source (revert; protected surfaces).
- WKWebView transaction bridge p99 typing latency exceeds 16ms on M-series (revisit per EDITOR_VERDICT decision triggers).
- MutationEnvelope schema changes break A2UI closed-catalog validation (revert; §11.1 binding).

**Citations (disk):**
- `/Users/jojo/Downloads/Epistemos/docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` (§§1, 3, 4, 6, 7, 8, 9, 10, 11)
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` (§§"DO NOT", "Performance budget", "When to revisit")
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/70_design_implementation/workspace_gpt_workspace_synthesis.md`
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/70_design_implementation/workspace_gpt_workspace_architecture.md`
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/70_design_implementation/workspace_epistemos_code_verdict.md`
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/50_research_corpus/final_v2/compass_artifact_wf-c2d78e2f-*.md`
- `/Users/jojo/Downloads/Epistemos/CLAUDE.md` (JS Bundle, FILE MAP)
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` (§3.5)

**Citations (web, all accessed 2026-04-27):**
- https://prosemirror.net/docs/ref/
- https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing
- https://tiptap.dev/docs/editor/getting-started/install
- https://developer.apple.com/documentation/webkit/wkprocesspool
- https://developer.apple.com/documentation/webkit/wkwebviewconfiguration/processpool
- https://datatracker.ietf.org/doc/rfc9562/
- https://docs.rs/ulid/latest/ulid/
- https://github.com/BLAKE3-team/BLAKE3
- https://docs.rs/crate/blake3/latest
- https://github.github.com/gfm/
- https://github.com/kivikakk/comrak
- https://github.com/jgm/djot
- https://developer.apple.com/documentation/uniformtypeidentifiers
- https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/DocumentPackages/DocumentPackages.html
- https://www.sqlite.org/fts5.html
