# LUMENLENS_SPINE — EPI-RP-02-LUMENLENS

ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS

This is a **code spine**, not a plan. It is a scaffold of real files carrying the
*binding contracts* from the LUMENLENS research so you can juxtapose it against
your live Epistemos repo and diff intent-vs-reality file by file.

Every file is a skeleton: real type signatures, real message schemas, real state
machines, real mark/serializer contracts — with `// TODO:` markers where an
implementation body goes. Nothing here fabricates an API. Where a fact was not
verifiable to a primary source it is flagged inline.

## What each file locks in (the four forks + gating + scale)
- `js-editor/src/bridge/document-load-state.ts` — Fork D: loadEpoch nonce +
  suppression window + `filterTransaction` guard. Never rely on `emitUpdate:false`
  (Tiptap #1715, #4828).
- `js-editor/src/bridge/inbound.ts` / `outbound.ts` — epoch-stamped bridge schemas.
- `js-editor/src/suggestions/SuggestionAdapter.ts` + `marks.ts` — Fork A: first-party
  suggestion engine behind a swappable adapter; hwc mark schema
  (`insertion`/`deletion`/`modification` + the doc-node block-mark trick).
- `js-editor/src/serializer/tiers.ts` + `minimal-diff-writeback.ts` — Fork B: tiered
  round-trip (A canonical-lossless / B custom-extension / C byte-preserving quarantine),
  changedRange minimal writeback, never reserialize the whole doc, frontmatter verbatim.
- `Epistemos/Engine/NoteSessionStateMachine.swift` — Fork C: one write-lease per note
  session, follower model, single source-tagged undo stack.
- `Epistemos/Engine/EpdocEditorBridge.swift` — epoch-stamped native bridge; UniFFI
  callbacks hop `DispatchQueue.main.async` (never `.sync`).
- `agent_core/src/provenance/suggestion_schema.rs` — attributed Suggestion schema.
- `Package.swift` — SwiftPM trait gating (KINDRED off on MAS).
- `.github/workflows/ci-matrix.yml` — 3-row leak-detector CI matrix.

## Build order (see PLAN doc)
L0 bridge spine → L1 suggestion seam → L2 serializer tiers → L3 minimal-diff
writeback → L4 session state machine → L5 provenance ledger.

## Hand-off seams to KINDRED (EPI-RP-05, external interface only)
- The `SuggestionAdapter` ingestion point is where KINDRED streams companion tokens.
- The provenance ledger is what "press mascot → see edits" reads.
- The epoch-stamped bridge carries KINDRED presence messages.
