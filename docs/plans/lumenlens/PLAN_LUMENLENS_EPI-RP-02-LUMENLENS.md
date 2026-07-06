# PLAN — LUMENLENS
ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS · Compiled 2026-07-06 (dual-wave V2)
Research base: `../kindred/RESEARCH_DUAL_KINDRED_LUMENLENS_2026_07_06.md` (read before building).
Amendments: §P-AMEND at the end (repo-audited 2026-07-06 — BINDING; overrides the body where they conflict).

## Executive thesis
LUMENLENS is a four-lens, provenance-first markdown note editor for a 100k-note vault,
sharing one correctness core across a sandboxed MAS build and a Developer-ID 1Code build.
The wager: markdown-on-disk is the source of truth and the editor never silently rewrites
it (minimal-diff writeback + tiered round-trip proof); agent edits are tracked-change
suggestions with full provenance; the companion layer (KINDRED, EPI-RP-05) is compiled out
of MAS via SwiftPM traits with a CI leak-detector. Correctness is witnessable via done-bars,
not vibes.

## Locked verdicts carried forward (binding — do not re-litigate)
- **Fork A (suggestions):** first-party engine on raw ProseMirror transactions +
  prosemirror-changeset + provenance IDs behind a swappable `SuggestionAdapter`; default
  references @handlewithcare/prosemirror-suggest-changes (insertion/deletion/modification
  marks + the doc-node block-mark trick `marks: "insertion modification deletion"`). Never
  a shadow editor, never blind setContent.
- **Fork B (round-trip):** canonical-normalized round-trip with a tiered harness (A
  canonical-lossless / B custom-extension serializers with tests / C byte-preserving opaque
  quarantine). Minimal-diff writeback via changeset changedRange — reserialize only touched
  blocks, never the whole doc. YAML frontmatter verbatim passthrough.
- **Fork C (sync):** one write-lease per note session; second windows are followers; states
  Idle -> Loading -> Clean -> Dirty -> Autosaving -> Clean with ExternalChange + Conflict
  side-states; single undo stack in the lease-owner's PM history plugin, source-tagged
  (agent | user).
- **Fork D (load-vs-edit):** loadEpoch nonce + suppression window + filterTransaction guard;
  never rely on emitUpdate:false (Tiptap #1715, #4828).
- **Gating:** compile-time KINDRED_ENABLED via SWIFT_ACTIVE_COMPILATION_CONDITIONS + SwiftPM
  package traits gating dependency targets + 3-row CI matrix + #error guard; runtime
  Capabilities struct for UI only. *(→ P-AMEND 1: traits struck; flags already landed.)*
- **Scale:** one SQLite DB per vault; GRDB DatabasePool WAL mode; FTS5 release-critical,
  embeddings deferred; diff3 merge engine v1 (not CRDT); security-scoped bookmarks with
  bookmarkDataIsStale re-resolve.

## Full scope preserved (harden, do not prune)
Four lenses (Prose native TextKit2, Epdoc/Tiptap-in-WKWebView as DEFAULT, Preview render,
Source CodeMirror6); the canonical markdown<->ProseMirror-JSON mapping for every block type
(headings, paragraphs, bold/italic, inline code, bullet/ordered/task lists, fenced code w/
lowlight, tables, blockquotes, images, inline+block math, callouts, wikilinks, highlights,
charts, HR, YAML frontmatter); load-vs-edit protocol; provenance ledger; embodied-edit
coordinate seam (feeds KINDRED); PDF viewing via PDFKit (boundary with Plan 3 PDF->markdown);
performance budgets + failure recovery; WKWebView custom-scheme brotli asset pipeline;
competitive synthesis; Deep Fabric F1-F6 with per-seam ownership.

## Per-seam ownership (F1-F6)
- F1 Vault bus: native Swift (GRDB), file watch + security-scoped bookmarks + write-lease.
  *(→ P-AMEND 4: file-watch/bookmarks/atomic-write are KEELSTONE's — consume, don't rebuild.)*
- F2 Agent capability registry: agent_core (Rust); June always, KINDRED capability gated.
- F3 Companion presence: 1Code (gated, compiled out on MAS) — external seam to KINDRED.
- F4 Knowledge graph: public API only; the editor is a client, never touches internals.
- F5 Provenance/citation: agent_core provenance/ledger.rs + replay.rs.
- F6 State/event bus: native Swift; debounced, backpressure-aware.

## Phased build order (witnessable proven-done bars)
- **L0 Bridge spine.** DONE: loadEpoch bumps on load; a stale-epoch transaction is provably
  rejected by filterTransaction (unit test); no reliance on emitUpdate:false anywhere.
- **L1 Suggestion seam.** DONE: an agent transaction enters as insertion marks via
  HwcSuggestionAdapter; accept/reject round-trips; swapping to NoopSuggestionAdapter compiles.
- **L2 Serializer tiers.** DONE: Tier A canonical round-trips lossless on a 100+ file corpus;
  Tier C preserves bytes on an opaque block; frontmatter byte-identical after an edit; the
  four DesktopCommander #440 corruption cases (frontmatter, GFM tables, wikilinks, spurious
  escapes) do NOT reproduce.
- **L3 Minimal-diff writeback.** DONE: editing one block reserializes ONLY that block's byte
  range (assert the whole doc is not rewritten) via changedRange; a one-paragraph edit on a
  multi-MB doc yields a one-region git diff.
- **L4 Session state machine.** DONE: two windows, one lease-owner; the follower cannot write;
  ExternalChange reloads when clean, enters diff3 conflict when dirty (never silent clobber).
- **L5 Provenance ledger.** DONE: Suggestion rows append; replay() reconstructs accept-state
  history; revert-turn removes exactly a turn's ranges.

## Dependency flags on KINDRED (EPI-RP-05) — external interface
- L1 SuggestionAdapter is the ingestion point for KINDRED streamed companion tokens (D2).
- L5 provenance ledger is what KINDRED's "press mascot -> see edits" reads (D7).
- The epoch-stamped Epdoc bridge carries KINDRED presence + the embodied sprite's position.
All three must ship in LUMENLENS before KINDRED can light up.

## Preserved open questions
1. Exact hwc mark attrs/toDOM — read the installed dist/schema.js before L1 to lock the
   SuggestionAdapter default; decide hwc-wrapped-by-ledger vs davefowler's username+data model.
2. Minimal-diff writeback granularity — region-level vs whole-file-byte-identical-when-unchanged;
   needs a spike measuring diff size on a 5-20 MB doc.
3. SwiftPM trait-condition API — confirm the exact `.when(traits:)` target-condition syntax.
   *(→ CLOSED as moot: no root Package.swift; xcodegen flags landed — P-AMEND 1.)*
4. Autosave/serializer budget (<16 ms touched-block reserialize) is a target, not yet measured.

## Self-critique + rubric
Weakest points: hwc schema literal un-read this session (inferred); Milkdown byte-for-byte
claim corroborated only indirectly; serializer budgets unmeasured. Rubric (1-5): Grounded 5 ·
Alternatives 5 · Build-actionable 5 · No fabrication 5 · Constraint-fidelity 5 · Integration
depth 4 · Depth/novelty 4. No axis < 4.

---

## §P-AMEND — Repo-audited binding amendments (2026-07-06; full evidence in `LUMENLENS_REVIEW_V2_2026_07_06.md`)

1. **Gating verdict corrected.** SwiftPM traits are INAPPLICABLE (no root Package.swift; two
   xcodegen targets). The mechanism ALREADY LANDED (KEELSTONE `8a1ca87d1`): `KINDRED_ENABLED` +
   `EPISTEMOS_EXPERIMENTAL` on all Epistemos-target configs, absent from AppStore;
   `AppSurface.swift` `#error` guards live. CI leak-detector = a job in the EXISTING
   `.github/workflows/ci.yml` (build `Epistemos-AppStore` + symbol scan). OQ3 closed.
2. **emitUpdate:false nuance.** The live loader legitimately passes `emitUpdate: false` and the
   guard test PINS that exact block (EpdocVisibilitySourceGuardTests:270). The ban means: never
   RELY on the flag — the epoch/filterTransaction layer is the correctness mechanism. Loader
   reflows update the pinned test in the same commit.
3. **Extend, never replace, the live modules:** `document-load-state.ts` (14-line boolean gate —
   layer the epoch plugin onto it; its exports are guard-pinned); the serializer = `@tiptap/
   markdown` + `epdoc-markdown-nodes.ts` renderMarkdown hooks (+ existing `check:markdown-roundtrip`
   script); the three `*.DELTA.swift` spine files are delta contracts over big live files (the
   live scheme is **`epistemos-doc://`** — never create `epdoc://`); autosave configures the
   existing `EpdocEditorSavePipeline`. js-editor toolchain = webpack 5 (CLAUDE.md's esbuild is stale).
4. **KEELSTONE seams bind:** writeback splices in memory and writes the WHOLE buffer through
   `AtomicVaultWriter`; `NoteSessionStateMachine` implements KEELSTONE's `ActiveEditorBridge`;
   `note_session` joins the EXISTING per-vault GRDB; KEELSTONE Phases 0-4 precede L3/L4. Fork C's
   follower model is real (graph-embed + window can both mount one note).
5. **Deps:** `prosemirror-changeset` 2.4.1 already installed; hwc NOT installed (L1 begins with
   npm add or first-party marks). Tiptap all 3.24.0.
6. **Ledger:** copy the EXISTING in-memory idiom (`events` Vec + `events_since` + snapshot→
   ReplayBundle w/ BLAKE3 + FFI export) for the Rust event stream; DURABLE persistence = GRDB
   editor-domain table (`spine/EditorProvenanceStore.swift`) with `claim_id` linkage.
7. **L4 opens with the undo decision:** the live code tears down the WKWebView on lens switch —
   choose retain-per-session (memory-budgeted) vs documented v1 undo-loss; amend the bar to match.
8. **Two producers, one suggestion schema:** June = agent_core/UniFFI (copy `AgentEventDelegate`);
   1Code = Node backend via the Experimental bridges. LUMENLENS owns the schema.
9. **RECKONER seam (Plan 9 Data tab, `EPI-RP-09-RECKONER`).** The Data room is a SEPARATE surface
   with its own truth model (GRDB tables + IronCalc calc authority per
   `docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`) — the editor does NOT absorb it. Boundary: note
   TABLES (markdown, Tier B serializers) stay editor-side; Data-room DATASETS are RECKONER's; a
   note references a dataset via wikilink/embed (graph-linked, F4), never by duplicating rows into
   markdown. The suggestion/provenance schema (L1/L5) is designed to be reusable for RECKONER's
   agent table-restructuring (dry-run→confirm→undo) — keep span metadata payload-agnostic (ranges
   over an abstract doc, not markdown-specific offsets) so Data-cell edits can attribute through
   the same ledger later.
