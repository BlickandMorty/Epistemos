# Cognitive Artifact Implementation Plan — 2026-04-25

**Authority cascade** (highest → lowest):
1. PLAN_V2.md §22 (BoltFFI carve-out, no mass-migration)
2. CLAUDE.md non-negotiables (preserve thinking blocks; stream everything; no silent backend rerouting)
3. AGENTS.md golden rules
4. This plan
5. EXTENDED_PROGRAM_PLAN_2026_04_25.md (wave sequencing)
6. Per-slice patch queue entries

**Core thesis** (locked, do not drift):
> Humans and agents think in **Prose** and **Raw Thoughts**.
> They produce in **Documents** and **Code**.
> Everything is linked through typed graph relationships inside one vault.
> Editors are surfaces. File/artifact type drives the surface.
> The graph/search/agent runtime operates on **stable artifact identity**, not random file paths.

**Single-line invariant**:
> **Filesystem is durable. Graph is rebuildable. Artifact identity is stable.**

---

## 1. Repo inventory (current state, 2026-04-25)

### Already built
- **Prose editor** — TextKit 2 native (`Epistemos/Views/Notes/ProseEditorView.swift`, `ProseTextView2.swift`, `ProseEditorRepresentable2.swift`, `MarkdownContentStorage.swift`). Protected.
- **Code editor** — `Epistemos/Views/Notes/CodeEditorView.swift` using CodeEditSourceEditor 0.15.2 with `Binding<String>` O(n) path; outline replaces minimap; right-side line gutter (Patch 11) added.
- **Graph** — Metal renderer (`MetalGraphView.swift`), Rust `graph-engine` crate (~127 C-FFI functions), `HologramOverlay.swift`. Protected.
- **SwiftData models** — `SDPage`, `SDChat`, `SDMessage`, `SDGraphNode`, `SDGraphEdge`, `GraphTypes` (17 node types, 16 edge types after Patch 5). `SDMessage.thinkingTrace` + `thinkingDurationSeconds` persisted.
- **Vault sync** — `VaultSyncService.swift` (SwiftData-authoritative + vault `.md` export-only); `NoteFileStorage.swift` atomic writes + Blake3 sidecar checksums.
- **Search** — GRDB FTS5 in `SearchIndexService.swift` (`page_search` + `block_search` virtual tables with INSERT/DELETE/UPDATE triggers).
- **Instant Recall** — HNSW substrate via `graph-engine/src/retrieval_index.rs` + Swift `InstantRecallService` (Patch 2 migrated startup hydration off MainActor).
- **Agent runtime** — `agent_core/src/agent_loop.rs` real multi-turn loop with thinking + signature preservation; `bridge.rs` 37 UniFFI exports + `runAgentSession` callback delegate; providers Claude/OpenAI/Perplexity/Gemini.
- **MCP bridge** — `omega-mcp` (16 UniFFI exports); `omega-mcp/src/pty.rs` PTY+orphan cleanup; **Patch 17** stripped PTY/osascript symbols from MAS dylib.
- **Raw Thoughts substrate (Slice 1 — 80% DONE)**:
  - **Rust emitter** (Patch 4): `agent_core/src/storage/raw_thoughts.rs` (745 lines + 7 tests) writes per-run folder under flag `EPISTEMOS_RAW_THOUGHTS_V0`. Folder layout: `<vault_root>/Raw Thoughts/<provider>/<YYYY-MM-DD>_<run-id>/{manifest.json, events.jsonl, summary.md, links.json}`. Anthropic signature bytes preserved verbatim.
  - **Swift consumer** (Patch 5): `Epistemos/State/RawThoughtsState.swift` + `RawThoughtsSection.swift` + `RawThoughtsInspectorView.swift` (file-type-driven sidebar entry, NOT new silo).
- **Typed graph types (Slice 2 — 30% DONE)**: Patch 5 added `GraphNodeType.run`/`.rawThought`/`.toolTrace` + `GraphEdgeType.producedDuring`/`.generatedBy`/`.derivedFrom`/`.summarizes`. Switch exhaustiveness updated in DialogueChatState, NodeInspectorState, GraphFloatingControls, MetalGraphView, RelationshipBrowser.
- **Contextual Shadows V0** (Patch 7): subtle composer button + slide-in panel with Notes/Chats tabs; off-MainActor recall via `Task.detached(.utility)`; 200ms debounce.
- **Pro+Cloud routing fix** (Patch 1, BLOCKER): cloud models in Pro mode now route through Rust agent loop with `chat_pro` tier.
- **MAS hardening**: omega-mcp PTY/osascript stripped from MAS dylib (Patch 17); JIT App Review notes (Patch 16); bundle-size CI gate (Patch 9); App Store hardening tests; PrivacyInfo.xcprivacy.

### NOT yet built
- **`ArtifactKind` taxonomy as first-class typed identity** across Rust + Swift. Today there's no unified `ArtifactKind` enum that spans all artifacts.
- **`ArtifactHeader` + `ProvenanceBlock`** with ULID + content_hash + producer + derived_from + generated_by_run + tool_id.
- **`.epdoc` package format** — completely absent (zero matches for `.epdoc`/`Tiptap`/`ProseMirror`/`WKWebView` in repo).
- **Document editor host** (Tiptap inside WKWebView).
- **Block-level search projections** — `readable_blocks` table + `readable_blocks_fts` virtual table.
- **Epistemos Code surface** (Patch 6a from earlier session — BLOCKED): main editor uses CodeEditSourceEditor's internal MultiStorageDelegate, NOT `SyntaxCoreService`. Wiring requires either custom `HighlightProviding` adapter or replacing SourceEditor binding.
- **Agent patch/provenance workflow** — code patches are not currently linked to Run artifacts via graph edges.
- **Mutation envelope pattern** — current invalidation is `NotificationCenter.default.post(name: .vaultChanged, ...)` style (broad). No typed `MutationEnvelope` with per-artifact / per-block / per-relation flags.
- **Compile-time `ArtifactRoute` enum + `@ViewBuilder` switch** — current routing in some places still uses string-keyed dispatch.

---

## 2. ArtifactKind taxonomy (proposed)

Unified Rust + Swift enum, mirrored across the FFI boundary.

```rust
// agent_core/src/artifacts/kind.rs (NEW)
#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ArtifactKind {
    ProseNote = 1,
    Document = 2,
    RawThought = 3,
    Source = 4,
    Code = 5,
    Run = 6,
    Output = 7,
}
```

```swift
// Epistemos/Models/ArtifactKind.swift (NEW)
enum ArtifactKind: UInt8, Codable, Sendable, CaseIterable {
    case proseNote = 1
    case document = 2
    case rawThought = 3
    case source = 4
    case code = 5
    case run = 6
    case output = 7
}
```

`SwiftData GraphNodeType` cases stay (legacy compatibility), but the new code path uses `ArtifactKind` for typed routing. Migration: add a `mapsToArtifactKind()` helper on `GraphNodeType` for legacy node visits.

---

## 3. ArtifactHeader + ProvenanceBlock

Every artifact carries a stable identity + provenance:

```rust
// agent_core/src/artifacts/header.rs (NEW)
pub struct ArtifactHeader {
    pub id: Ulid,
    pub kind: ArtifactKind,
    pub schema_version: u32,
    pub created_at: i64,        // unix ms
    pub updated_at: i64,
    pub title: String,
    pub vault_path: PathBuf,
    pub content_hash: blake3::Hash,
    pub provenance: ProvenanceBlock,
}

pub struct ProvenanceBlock {
    pub producer: Producer,           // Human | Agent | System
    pub derived_from: Vec<ArtifactRef>,
    pub generated_by_run: Option<Ulid>,
    pub tool_id: Option<String>,
    pub source_artifacts: Vec<ArtifactRef>,
    pub output_artifacts: Vec<ArtifactRef>,
}
```

Persisted as `manifest.json` per artifact (Documents) or as a row in SwiftData (ProseNotes, today).

---

## 4. Package layouts

### ProseNote
Today: SwiftData `SDPage` + vault `.md` file (managed by `NoteFileStorage`). Keep as-is. Add `ArtifactHeader` migration path that derives header from existing `SDPage` fields without breaking the on-disk format.

### Document `.epdoc`
```
MyResearchReport.epdoc/
  manifest.json              # ArtifactHeader + ProvenanceBlock
  content.pm.json            # canonical ProseMirror JSON
  projections/
    shadow.md                # GFM Markdown projection (lossy, derived)
    plain.txt                # FTS-friendly plain text
    search_blocks.jsonl      # block-level search projection (one per line)
  assets/
    image-01.png             # embedded media
  exports/                   # generated on-demand only
    *.docx                   # Pandoc + reference.docx
    *.pdf                    # later
```

**Rules**:
- `content.pm.json` is canonical. Markdown is derived. DOCX/PDF are export snapshots.
- Markdown shadow regenerates from canonical on every save.
- External `shadow.md` edits do NOT silently overwrite canonical — they're imported as a reviewable conversion / new version.
- Live DOCX autosave is FORBIDDEN (per GPT advice — creates churn, corruption risk).

### Raw Thought run (already mostly built)
```
Vault/Raw Thoughts/<provider>/<YYYY-MM-DD>_<run-id>/
  manifest.json              # RawThoughtsManifest (run_id, prompt_id, provider, model, started_at, ended_at, status)
  events.jsonl               # append-only typed event stream
  summary.md                 # planner + execution summary (app-owned)
  links.json                 # { artifact_refs, source_refs, chat_refs }
  thoughts/                  # provider-exposed reasoning surfaces (NEW for Slice 1.5)
    turn-0001.anthropic-thinking.json
    turn-0002.openai-reasoning.json
    turn-0003.local-think-spans.json
  tools/                     # per-tool-call payloads (NEW for Slice 1.5)
    <tool-call-id>.json
  final.json                 # final agent output (NEW for Slice 1.5)
```

Patch 4 already wrote: `manifest.json`, `events.jsonl`, `summary.md`, `links.json` (via `write_links()`). Slice 1.5 adds: `thoughts/<turn>.<provider>.json` (sidecar files for large reasoning blobs), `tools/<tool-call-id>.json`, `final.json`.

### Source
Webpage extracts, PDF imports, citation snapshots. Header points to original URL/file. Body = extracted plain text + structured metadata.

### Code
Code file in vault. Header carries language, last-build status, last-test status, agent-patch refs.

### Output
A produced artifact (deliverable). Header has `generated_by_run` + `derived_from` (the prompts/sources/prose that fed the run).

---

## 5. Graph edge model (typed)

Existing edges (16): `reference`, `contains`, `tagged`, `mentions`, `cites`, `authored`, `related`, `quotes`, `supports`, `contradicts`, `expands`, `questions`, `producedDuring`, `generatedBy`, `derivedFrom`, `summarizes`.

New edges to add for Slice 2:
- `references` — explicit document → source citation (alias of `cites`?)
- `validatedBy` — Output → Test/CI run
- `linksTo` — generic typed link (alias of `reference`?)

Layered semantics:
- **Layer 1 (explicit)**: user typed wikilinks, manual references, structured citations.
- **Layer 2 (structural)**: produced_by_run, derived_from, generated_by — emitted by agent runtime when artifacts are created.
- **Layer 3 (semantic)**: similarity-based suggested links (deferred to V1.5+).

---

## 6. Search projection model

```sql
CREATE TABLE readable_blocks (
  id INTEGER PRIMARY KEY,
  artifact_id TEXT NOT NULL,
  artifact_kind TEXT NOT NULL,
  block_id TEXT NOT NULL,
  block_kind TEXT NOT NULL,         -- paragraph | heading | code | table | callout | quote
  title_path TEXT,                  -- "Doc Title > Section A > Subsection 2"
  body TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE readable_blocks_fts USING fts5(
  title_path,
  body,
  content='readable_blocks',
  content_rowid='id'
);

-- Triggers keep the FTS index in sync.
```

Search opens the **exact block**, not just the artifact. Click → editor jumps to `block_id` within the artifact. Existing `page_search` + `block_search` tables continue to serve current Prose-only search; `readable_blocks` is the new universal projection that absorbs Documents + Raw Thoughts + Code + Source.

---

## 7. Editor routing model (compile-time, no AnyView in hot paths)

```swift
// Epistemos/State/ArtifactRoute.swift (NEW)
enum ArtifactRoute: Equatable, Hashable {
    case proseNote(ArtifactID)
    case document(ArtifactID)
    case rawThoughtRun(RunID)
    case source(ArtifactID)
    case code(ArtifactID)
    case output(ArtifactID)
}

struct ArtifactHostView: View {
    let route: ArtifactRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .proseNote(let id):       ProseEditorView(artifactID: id)
        case .document(let id):        DocumentEditorHostView(artifactID: id)
        case .rawThoughtRun(let id):   RawThoughtTimelineView(runID: id)
        case .source(let id):          SourceReaderView(artifactID: id)
        case .code(let id):            EpistemosCodeView(artifactID: id)
        case .output(let id):          OutputArtifactView(artifactID: id)
        }
    }
}
```

`some View` opaque return is critical — preserves SwiftUI structural identity. **No `AnyView` in artifact routing hot paths.** Per `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` constraint #3.

---

## 8. Mutation envelope pattern (Slice 8 — deferred until after Slice 6)

```rust
// agent_core/src/artifacts/mutation.rs (NEW)
pub struct MutationEnvelope {
    pub mutation_id: Ulid,
    pub touched_artifacts: SmallVec<[ArtifactRef; 8]>,
    pub touched_blocks: SmallVec<[BlockRef; 16]>,
    pub relation_changes: SmallVec<[RelationChange; 8]>,
    pub affects_summary: bool,
    pub affects_outline: bool,
    pub affects_backlinks: bool,
    pub affects_search_projection: bool,
    pub affects_graph: bool,
    pub affects_body: bool,
    pub source_op: SourceOp,
}
```

Swift consumer:
```swift
func shouldRefresh(_ query: QueryFingerprint, for mutation: MutationEnvelope) -> Bool {
    query.watchSet.intersects(mutation)
}
```

This replaces broad `NotificationCenter.default.post(name: .vaultChanged, ...)` style invalidation.

---

## 9. Implementation slices (reconciled with EXTENDED_PROGRAM_PLAN waves)

| Slice | Purpose | Wave | Status |
|---|---|---|---|
| **Slice 0** | Planning + perf gates (this doc + Sprint 0 instrumentation) | Wave 1+2 | THIS DOC + DEFERRED to next |
| **Slice 1** | Raw Thoughts persistence (Rust emitter + Swift consumer) | Wave 3 | **80% DONE** (Patches 4+5) — needs `thoughts/`, `tools/`, `final.json` sidecar files |
| **Slice 2** | Typed Artifact Graph extensions (ProseNote/Document/Source/Code/Output as full first-class types) | Wave 3 | **30% DONE** (Run/RawThought/ToolTrace types added in Patch 5) |
| **Slice 3** | `.epdoc` package + ArtifactHeader + ProvenanceBlock | Wave 4 | NOT STARTED |
| **Slice 4** | Document editor host (Tiptap + WKWebView + bridge) | Wave 5 | NOT STARTED |
| **Slice 5** | Block-level search projections (`readable_blocks` + FTS) | Wave 6 | NOT STARTED |
| **Slice 6** | Epistemos Code surface (Swift+SwiftTreeSitter+Rust background+LSP) | Wave 7 | BLOCKED (Patch 6a — main editor uses CodeEditSourceEditor's MultiStorageDelegate, not SyntaxCoreService) |
| **Slice 7** | Agent patch/provenance workflow (code patches link to Run artifacts via graph) | Wave 8 | NOT STARTED |
| **Slice 8** | Mutation envelope pattern (typed dependency tracking; replaces broad NotificationCenter) | Wave 9 | NOT STARTED |
| **Slice 9** | Deep deterministic perf (Sprints 3-6 from `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` — Metal binary archive, substrate-rt zero-copy ring, PGO, bumpalo) | Waves 10-12 | NOT STARTED |

---

## 10. Acceptance criteria per slice

### Slice 1 closure (Raw Thoughts persistence)
- ✅ `runs/<run-id>/manifest.json` validates against `RawThoughtsManifest` schema.
- ✅ `events.jsonl` is append-only (master auditor verified Patch 4 byte-equality test).
- ✅ Anthropic signature bytes preserved verbatim.
- ⏳ `thoughts/turn-NNNN.<provider>.json` sidecar files written for large reasoning blobs (NOT YET — Patch 4 inlines all events).
- ⏳ `tools/<tool-call-id>.json` sidecar files written for large tool payloads (NOT YET — inlined).
- ⏳ `final.json` written on `MessageStop`/`EndTurn` (NOT YET — only `summary.md` written).
- ✅ `links.json` connects run → produced artifacts (Patch 4 has `write_links()`).
- ✅ Sidebar timeline can browse runs (Patch 5 `RawThoughtsSection`).
- ✅ NO hidden CoT reconstruction — only observable provider surfaces.

### Slice 2 closure (Typed Artifact Graph)
- ⏳ `ArtifactKind` enum exists in both Rust + Swift with byte-equal raw values.
- ⏳ `GraphNodeType.proseNote` / `.document` / `.source` / `.code` / `.output` cases added (currently only Run/RawThought/ToolTrace).
- ⏳ `GraphEdgeType.linksTo` / `.validatedBy` cases added.
- ⏳ Graph rebuild from filesystem state works for new types.
- ⏳ Graph filter UI can toggle Raw Thoughts on/off.

### Slice 3-9: see acceptance criteria per slice in `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` §1-6 + GPT advice in this session.

---

## 11. Non-goals (locked)

- ❌ NOT replacing the Prose editor (canon).
- ❌ NOT building a custom SwiftUI block editor for Documents (use Tiptap WKWebView).
- ❌ NOT live-autosaving DOCX or PDF (export-only).
- ❌ NOT making Markdown shadow an equal source of truth.
- ❌ NOT reconstructing hidden chain-of-thought (capture observable surfaces only).
- ❌ NOT cloning Xcode (Code is a cognitive execution surface, not a full IDE).
- ❌ NOT putting per-keystroke syntax range mapping through Rust FFI for the live editor (UTF-8/UTF-16 trap; SwiftTreeSitter handles live highlighting Swift-side).
- ❌ NOT mass-migrating to BoltFFI (per PLAN_V2 §22 — only benchmark-proven hot paths).
- ❌ NOT touching `crates/agent_core/` from the Deterministic Perf Plan sprints (Phase I has its own migration).

---

## 12. Drift prevention (Codex-style strict audit, every wave)

For every dispatched patch:
1. Master auditor reads source-of-truth docs (this doc + PLAN_V2 + EXTENDED_PROGRAM_PLAN + the relevant slice's research file under `/Users/jojo/Downloads/{workspace,opt}/`).
2. Subagent dispatched with strict scope guards (file allowlist + non-negotiables).
3. Subagent returns diff + tests + build evidence.
4. Master auditor INDEPENDENTLY verifies (`xcodebuild build`, `cargo test`, `nm` for symbol stripping, manual diff review for canon adherence).
5. Out-of-scope drift (xcodeproj edits, protected file changes, anti-pattern violations) is reverted via `git restore` BEFORE commit.
6. Audit trail recorded in commit message with citations to source-of-truth doc lines.
7. Stabilization tag dropped at every wave boundary (`v-perf-0`, `v-cognitive-1`, etc.).

**Source-of-truth files for every dispatch**:
- `/Users/jojo/Downloads/Epistemos/AGENTS.md`
- `/Users/jojo/Downloads/Epistemos/CLAUDE.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
- `/Users/jojo/Downloads/Epistemos/docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` (this doc)
- `/Users/jojo/Downloads/Epistemos/docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` (when implementing Slice 9 / Waves 10-12)
- The relevant `/Users/jojo/Downloads/workspace/*` or `/Users/jojo/Downloads/opt/*` research file for the slice.

---

## 13. Reconciled wave order (canonical, supersedes EXTENDED_PROGRAM_PLAN's earlier ordering)

Per GPT's spine-first advice + user's "finish hardening before features":

| Wave | What | Time | Slice mapping |
|---|---|---|---|
| 1 | Finish V1 ship hardening (reliability 5-gate, TestFlight prep, smoke tests) | 1 wk | — |
| 2 | Sprint 0 instrumentation (signposts + GRDB pragmas + LTO + perf-budgets + bench/morning-session) | 1 wk | Slice 0 |
| 3 | Cognitive substrate (Raw Thoughts close-out + ArtifactKind + typed graph extensions) | 2 wk | Slices 1 + 2 |
| 4 | `.epdoc` package + ArtifactHeader + ProvenanceBlock | 2 wk | Slice 3 |
| 5 | Document editor host (Tiptap + WKWebView) | 2 wk | Slice 4 |
| 6 | Block-level search projections | 1 wk | Slice 5 |
| 7 | Epistemos Code surface (Patch 6a + LSP integration) | 3 wk | Slice 6 |
| 8 | Agent patch/provenance workflow | 1 wk | Slice 7 |
| 9 | Mutation envelope pattern + ACC full surface | 2 wk | Slice 8 + Program B remainder |
| 10-12 | Deep deterministic perf (Sprints 3-6 from dpp — Metal binary archive, substrate-rt zero-copy ring, PGO, bumpalo) | 7 wk | Slice 9 |

**Total horizon**: ~22 weeks for the full multi-program plan, sequenced spine-first.

**Stabilization checkpoints** every wave boundary. Skip-eligible per dpp §7 (Path A: cheap wins only / Path B: skip Sprint 4 substrate-rt / Path C: defer Swift macros).

---

## 14. What changes from the prior EXTENDED_PROGRAM_PLAN

The earlier plan put **deep deterministic perf (substrate-rt, slotmap, phf, Metal archive)** in Waves 3-6, BEFORE features. GPT's advice says the spine-first order is:

> Provenance is the foundation, not the editor.
> Raw Thoughts first. Typed artifacts second. .epdoc third. Editor fourth. Performance gates always.

So this reconciled plan moves **Sprints 1-6 of dpp (slotmap, phf, Metal archive, substrate-rt, PGO, bumpalo) to Waves 10-12 (after editor surfaces are stable enough to measure)**. Sprint 0 (signposts + GRDB pragmas + LTO) stays in Wave 2 because it's INSTRUMENTATION, not architecture rework — it's the measurement foundation that makes every subsequent perf claim provable.

This satisfies:
- User's "finish hardening before features": Wave 1 (V1 ship) + Wave 2 (Sprint 0 perf instrumentation) come first.
- GPT's "spine before cathedral": Provenance substrate (Waves 3-4) before editor surfaces (Waves 5-7).
- dpp §0.6 "every sprint produces a shippable improvement": each wave is independently tag-able.
- AGENTS.md "minimal fixes": no wave forces unrelated rewrites.
