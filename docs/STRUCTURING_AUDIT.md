# Input → Structure Pipeline Audit

> **Index status**: CANONICAL-RESEARCH — S1-S16 surfaces + G1-G9 gap-fixes; already in _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



Authored 2026-04-27 per user directive: "every single thing that gets
into my app, I want it to be structured… infrastructure JSON,
structure files and file trees so that the models used in the app
itself can understand itself better."

This is the canonical "what becomes structured data, what doesn't"
inventory. Every input surface in the codebase has a row. Phase 7+
work raises the percent-structured number until every Raw row is
either Partial or Fully structured.

---

## Summary (snapshot 2026-04-27)

| Bucket | Count | % |
| ------ | ----- | - |
| **Fully structured** (AFM @Generable + persisted to typed store) | 4 | 25% |
| **Partially structured** (typed store but no AFM extraction) | 8 | 50% |
| **Raw / unstructured** (free text or in-memory only) | 4 | 25% |

**Goal:** every input is at least Partial by V1 ship; Fully structured
for any input the cognitive layer needs to reason over.

---

## Per-surface inventory

| ID | Surface | File | Status | Lands in | @Generable? | Gap |
| -- | ------- | ---- | ------ | -------- | ----------- | --- |
| **S1** | Quick Capture (text) | `Epistemos/Views/Capture/QuickCaptureView.swift` | Partial | SDPage + JSON sidecars + TraceEvent | No | Wire AFM `@Generable` for title/summary/entity extraction on submit. The new structured-preview chip strip already hints at the schema client-side. |
| **S2** | TextCapturePipeline | `Epistemos/Engine/TextCapturePipeline.swift` | **Full** | CaptureResult (Codable) + SDPage + TraceEvent | Partial | Codable result with SourceSpan provenance per entity/task. Bridge to AFM for richer summaries. |
| **S3** | Chat input bar | `Epistemos/Views/Chat/ChatInputBar.swift` | Partial | SDMessage (SwiftData) | No | Free text → SDMessage; needs `IntentClassification` @Generable wrap before SDMessage creation. |
| **S4** | ChatCoordinator routing | `Epistemos/App/ChatCoordinator.swift` | Partial | SDMessage + SDChat | No | Reference resolution via ChatState; needs structured `RoutingDecision` schema. |
| **S5** | Note editor (Prose / TextKit2) | `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` | Partial | SDPage.body (string) + on-disk file | No | Raw markdown stored. On save (debounced 300ms), feed through OntologyClassifier + emit ontology nodes. |
| **S6** | Epdoc editor (Tiptap / WKWebView) | `Epistemos/Engine/EpdocEditorBridge.swift` | Raw | In-memory WKWebView + future `.epdoc` packages | No | Bridge layer only. Need `TiptapContentExtractor` → `EpdocBlock[]` @Generable. |
| **S7** | Voice dictation | `Epistemos/Engine/ComposerVoiceInputService.swift` | Partial | Transcribed string → composer | No | Audio→text via Apple Speech; route the text through TextCapturePipeline so structuring matches QuickCapture. |
| **S8** | Settings free-text (paths, model names, keys) | `Epistemos/Views/Settings/SettingsView.swift` | Raw | AgentAuthorityStore (file-backed) | No | API keys + paths stored as plain strings. Add `VaultPathValidator` @Generable for path inputs. |
| **S9** | Search queries (Halo + landing) | `Epistemos/Views/Graph/HologramSearchSidebar.swift` + `Epistemos/Engine/ShadowSearchService.swift` | Partial | SearchResult structs + LexicalIndex | No | Strings ranked. Need `SearchIntent` @Generable so router knows intent before BM25/HNSW dispatch. |
| **S10** | Vault crawler / file import | `Epistemos/Engine/ShadowVaultBootstrapper.swift` + `Epistemos/Sync/NoteFileStorage.swift` | Partial | SDPage / SDChat + ShadowIndexingService | No | Files discovered + parsed. Needs OntologyClassifier on title + first 200 chars per discovered file. R16 ETL crawler will extend this. |
| **S11** | Paste classifier | `Epistemos/Engine/EpdocPasteClassifier.swift` (W10.14 IntakeValve) | **Full** | IntakeDecision routed to matchExisting / newConcept / ambient / noise | **Yes** | Reference implementation for the @Generable + AFM tier-C pattern. |
| **S12** | Screen capture (Pro) | `Epistemos/Omega/Vision/ScreenCaptureService.swift` | Raw | In-memory ScreenCapture objects | No | AX tree → vision data. Need `ScreenElement[]` @Generable with roles + labels + inferred semantics. |
| **S13** | Spotlight / App Intents | `Epistemos/Intents/Entities/NoteEntity.swift` | Partial | SearchResult → SDPage fetch | No | Intent search via rankedPages. Each intent input field that takes free text needs an explicit @Generable. |
| **S14** | iMessage inbound (Pro) | `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift` | Partial | DriverChannelMessage structs | No | Plain text routed through agent_core. Add `MessageIntent` classification before dispatch. |
| **S15** | OntologyClassifier | `Epistemos/Graph/OntologyClassifier.swift` (W10.1) | **Full** | OntologyNode (@Generable, recursive) + graph nodes | **Yes** | Reference implementation. Stores parentDomain / childConcept / depth. |
| **S16** | Session telemetry | `Epistemos/Engine/SessionTelemetryClassifier.swift` (W10.9) | **Full** | Codable telemetry structs (@Generable) | **Yes** | AFM-backed; Phase 9 marks + persists structured session events. |

---

## Gap-fix queue (ROI-ordered — every item has a WRV plan)

### Tier 1 — ship before V1 (highest ROI, all touch user-visible flows)

#### G1. Chat message intent classification (S3 + S4)
- **Why now**: chat is 40%+ of user time; free-form messages are the primary LLM-input surface; structured intent unlocks ranking, autocomplete, retraction propagation.
- **Approach**: add `IntentClassification` @Generable schema (intent: enum, confidence: Double, entities: [SourceRef], context_flags: [ContextFlag]). Run on submit with 300ms AFM budget; persist alongside SDMessage in a new `intent_json` column. Mirrors the IntakeValve tier-C pattern (S11).
- **WRV plan**: visible — intent tag chip on each user message bubble; reachable — every chat send; wired — ChatCoordinator pre-flight call → IntentClassifier.shared.

#### G2. Search query intent (S9)
- **Why now**: landing search + Halo are discovery surfaces; structured intent unlocks tier routing (BM25 vs HNSW vs graph traversal).
- **Approach**: pre-classify queries via IntakeValve tier B (Levenshtein FTS5) + tier C (AFM for ambiguous). Emit `SearchIntent` @Generable (queryText, inferredDomain, filterPreferences) alongside the raw string.
- **WRV plan**: visible — small inline pill above results showing detected intent; reachable — every search; wired — ShadowSearchService.search() pre-call.

#### G3. Voice → structured pipeline (S7)
- **Why now**: dictation is zero-friction capture but currently lands as raw text; same surface deserves same structuring as typed capture.
- **Approach**: after AudioTranscriber emits text, route through TextCapturePipeline (already wired in QuickCaptureView). Inherit title / entity / task extraction.
- **WRV plan**: visible — same chip strip + confirmation card; reachable — Dictate button in QuickCapture (already there); wired — single line in ComposerVoiceInputService.

#### G4. Note save → ontology emit (S5)
- **Why now**: markdown notes are the vault's core asset; full-text indexing alone leaves the cognitive layer blind to concept relationships.
- **Approach**: on debounced save (300ms exists), pass body through OntologyClassifier + emit OntologyNode[] + block-level entity refs into SDPage's existing JSON sidecar field. Behind the existing `OntologyClassifier.shared.readiness() == .available` gate.
- **WRV plan**: visible — sidecar inspector row count or a "concepts: N" badge on the note header; reachable — every save; wired — Coordinator2 didEdit hook in ProseEditorRepresentable2.

### Tier 2 — Phase 7 / Phase 8 (medium ROI, narrower surface)

#### G5. Settings vault path validator (S8)
- Validate path on input — exists / readable / indexable. Persist with audit trail in AgentAuthorityStore.

#### G6. Epdoc content extractor (S6)
- WKWebView.evaluateJavaScript to query ProseMirror DOM → emit `EpdocBlock[]` @Generable into the .epdoc package manifest.

#### G7. Vault crawler entity linking (S10)
- Re-run OntologyClassifier on each discovered file's title + first 200 chars; link OntologyNodes to SDGraphNodes via the shadow index. R16 ETL crawler is the natural home.

### Tier 3 — Phase 10+ (lower ROI, narrow Pro features)

#### G8. Screen-capture AX semantics (S12)
- Screen2AXFusion → `ScreenElement[]` @Generable with role + label + bounding box + inferred semantic.

#### G9. iMessage message intent (S14)
- Light classification via DriverChannelToolExecutor: command / question / confirmation. Reuse IntakeValve tier B + simple keyword pre-filter.

---

## Architecture invariants (must hold for every fix)

1. **AFM @Generable is the canonical structuring primitive.** Every new structuring step uses an `@Generable` Swift type. No ad-hoc JSON parsing.
2. **Source-span provenance is mandatory.** Every extracted entity carries a `SourceSpan` (file path / byte range / chat-message id) so retraction and audit trails work end-to-end.
3. **Persist structured, query eagerly.** The pattern that breaks today (S5 raw-markdown body + lazy structuring) creates a fast-path / slow-path divergence. Flip it: structure on input, store structured, query the structured form first.
4. **Latency budget is 300ms per AFM call.** Beyond that, the structuring step belongs in NightBrain (background pass), not the synchronous input flow.
5. **Every structured store is queryable by the local LLM.** SwiftData rows + JSON sidecars + GRDB rows are all visible to the on-device LLM via the appropriate MCP/agent_core resource. If a structured store isn't reachable from a tool call, it's invisible to the cognitive layer.

---

## Self-introspection — how the app knows its own structure

A new module `Epistemos/Engine/StructureRegistry.swift` ships alongside this audit. It catalogs every @Generable schema + which surface produces it + where the result lands. The local LLM reads this registry to answer "what kinds of structured data does my host know about?"

Concretely the registry exposes:

```swift
StructureRegistry.shared.allSchemas
// → [
//   .init(id: "intake_decision", surface: "paste",
//         storage: "QuarantineArchive", swiftType: "IntakeDecision"),
//   .init(id: "ontology_node", surface: "note_save",
//         storage: "SDGraphNode + sidecar", swiftType: "OntologyNode"),
//   …
// ]
```

The agent can then call `getStructureCatalog()` as an MCP resource +
ask "do I have a tool that produces X?" instead of guessing.

---

## How to use this doc

1. Each entry in the per-surface table has a stable ID (`S1`–`S16`).
2. Each gap-fix has a stable ID (`G1`–`G9`).
3. PRs that close a gap update the affected row's status (Raw →
   Partial → Full) and add a changelog line at the bottom.
4. When all rows are Partial or Full + the registry catalogs every
   schema, the V1 structuring posture is achieved.

## Changelog

- 2026-04-27 — Initial audit (16 surfaces inventoried).
