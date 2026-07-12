# PLAN — LUMENLENS
ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS · Compiled 2026-07-06 (dual-wave V2)
Research base: `../kindred/RESEARCH_DUAL_KINDRED_LUMENLENS_2026_07_06.md` (read before building).
Amendments: §P-AMEND at the end (repo-audited 2026-07-06 — BINDING; overrides the body where they conflict).

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. LUMENLENS now
> targets MAS only. Keep the editor correctness, provenance, note-context,
> notebook, and suggestion seams; park Developer-ID/1Code/KINDRED runtime
> assumptions unless rebuilt through MAS/June.

## 0A. Owner-Intent And Verification Lock

Instruction lock ID: `OWNER-INTENT-HARDENING-LOCK-2026-07-07`.

Agents entering through this plan inherit the root read-first/research-first
discipline, the active build prompt, and the scoped `deep-hardening-loop`.
Before implementation or after any owner steer, write or update an intent
checkpoint in the active phase notes/evidence ledger: verbatim owner wording
or exact excerpt, interpreted intent, hard constraints, non-goals, acceptance
checks, contradictions/questions, and next action. If verification is
intentionally batched during a long coding pass, keep a verification-debt
ledger with deferred command, touched files, risk reason, expected proof, and
checkpoint trigger.

When this plan appears complete, do not stop at the last checked phase.
Continue auditing the implemented scope with `deep-hardening-loop` until the
owner explicitly stops, redirects, or a real blocker prevents useful progress;
include `thermo-nuclear-code-quality-review` for structural/refactor risk,
runtime/manual checks for UI or behavior claims, and release/security skills
when risk warrants them. This lock is a routing and verification directive
only; it does not expand LUMENLENS scope, overwrite the resolved verdicts, or
absorb another feature plan.

## Executive thesis
LUMENLENS is a four-lens, provenance-first markdown note editor for a 100k-note vault,
now active for the sandboxed MAS build only.
The wager: markdown-on-disk is the source of truth and the editor never silently rewrites
it (minimal-diff writeback + tiered round-trip proof); agent edits are tracked-change
suggestions with full provenance; the previous companion layer (KINDRED, EPI-RP-05) is parked
and must remain absent from MAS. Correctness is witnessable via done-bars,
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
- **Parked Kindred gating:** prior `KINDRED_ENABLED` compile-time gating remains provenance and
  leak-check context only while MAS-only is active; MAS must remain free of companion symbols.
- **Scale:** one SQLite DB per vault; GRDB DatabasePool WAL mode; FTS5 release-critical,
  embeddings deferred; diff3 merge engine v1 (not CRDT); security-scoped bookmarks with
  bookmarkDataIsStale re-resolve.

## Full scope preserved (harden, do not prune)
Four lenses (Prose native TextKit2, Epdoc/Tiptap-in-WKWebView as DEFAULT, Preview render,
Source CodeMirror6); the canonical markdown<->ProseMirror-JSON mapping for every block type
(headings, paragraphs, bold/italic, inline code, bullet/ordered/task lists, fenced code w/
lowlight, tables, blockquotes, images, inline+block math, callouts, wikilinks, highlights,
charts, HR, YAML frontmatter); load-vs-edit protocol; provenance ledger; MAS-June
context/provenance seam (parked KINDRED notes are provenance only); PDF viewing via PDFKit
(boundary with Plan 3 PDF->markdown);
performance budgets + failure recovery; WKWebView custom-scheme brotli asset pipeline;
competitive synthesis; Deep Fabric F1-F6 with per-seam ownership.

## Per-seam ownership (F1-F6)
- F1 Vault bus: native Swift (GRDB), file watch + security-scoped bookmarks + write-lease.
  *(→ P-AMEND 4: file-watch/bookmarks/atomic-write are KEELSTONE's — consume, don't rebuild.)*
- F2 Agent capability registry: agent_core (Rust); June is the active MAS driver.
- F3 Status/provenance: MAS-safe state display only; KINDRED companion presence is parked.
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

## Parked KINDRED Interface Notes (EPI-RP-05)
- L1 SuggestionAdapter remains the ingestion point for MAS-June streamed edit suggestions.
- L5 provenance ledger is what any future MAS-safe "see edits" affordance reads.
- The epoch-stamped Epdoc bridge can carry editor position/state, but KINDRED presence and
  embodied sprite work are parked while MAS-only is active.
Do not wait for KINDRED before shipping LUMENLENS; preserve these notes only as provenance seams.

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

1. **Gating verdict amended by MAS-only pivot.** SwiftPM traits are INAPPLICABLE (no root
   Package.swift). While MAS-only is active, do not add or rely on `KINDRED_ENABLED` /
   `EPISTEMOS_EXPERIMENTAL`; retain only the `Epistemos-AppStore` symbol/leak scan proving
   companion symbols are absent. OQ3 is parked.
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
8. **One active producer, one suggestion schema:** June = agent_core/UniFFI
   (copy `AgentEventDelegate`). 1Code/Node/Experimental bridges are parked
   provenance. LUMENLENS owns the schema.
9. **RECKONER seam (`EPI-RP-09-RECKONER`).** RECKONER is MAS data infrastructure, not a separate
   Data room. Datasets open as existing note-workspace/Epdoc-notebook tabs and embeds, with their
   own truth model (vault artifact + IronCalc calc authority; GRDB is derived cache per
   `docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`). Boundary: note TABLES (markdown, Tier B
   serializers) stay editor-side; dataset artifacts are RECKONER's; a note references a dataset via
   wikilink/embed (graph-linked, F4), never by duplicating rows into markdown. The
   suggestion/provenance schema (L1/L5) is designed to be reusable for RECKONER's
   agent table-restructuring (dry-run→confirm→undo) — keep span metadata payload-agnostic (ranges
   over an abstract doc, not markdown-specific offsets) so Data-cell edits can attribute through
   the same ledger later.
10. **LENS-FIDELITY DISCLOSURE — "nothing lost, NOTHING HIDDEN" (owner directive 2026-07-06).**
   Fork B guarantees no content is ever LOST across lenses (Tier B/C preservation); this adds the
   visibility half: no content is ever silently INVISIBLE. Epdoc is the richest lens; Prose and
   Source cannot render some content (charts, block math, callouts, image nodes, task states,
   Tier-C quarantine blocks, RECKONER dataset embeds). Mechanism:
   - The Tier classifier (`spine/tiers.ts` / `pickTier`) doubles as the **lens-fidelity
     registry**: every Tier B/C node type declares, per lens, one of three states —
     **rendered** / **degraded** (visible only as raw syntax, e.g. Source showing a chart's
     fenced block) / **invisible** — plus a preview provider (rendered snapshot).
   - On Prose/Source, a **disclosure toggle** (extend the EXISTING `showInfoPopover` affordance
     in `NoteDetailWorkspaceView`, or a sibling toggle in the lens switcher) lists every
     degraded/invisible item in the current doc: type, count, inline rendered preview,
     jump-to-in-Epdoc. Zero-item docs show nothing (quiet by default).
   - External content types register through the same seam — RECKONER embeds are the first
     (`EPI-RP-09` provides its preview provider; LUMENLENS owns the registry + UI).
   - **ROBUST popovers (owner upgrade 2026-07-06):** disclosure previews are HIGH-QUALITY rendered
     snapshots (not placeholders), and every item carries actions — **download / export** (dataset
     tab/embed → xlsx via IronCalc `save_to_xlsx` / CSV; chart → image; chat tab → markdown
     transcript; quarantined block → raw bytes) + jump-to-Epdoc. The popover is the universal
     escape hatch: complex content is fully USABLE from any lens, never just acknowledged.
   - **Done-bar (folds into L2, re-verified at L6):** at L2 — on a corpus doc containing every
     Tier B type + a quarantined block + a dataset embed, switching to Prose and to Source each
     shows an accurate disclosure list with working previews AND working exports; nothing
     renderable-in-Epdoc is silently invisible; bytes untouched (Fork B unaffected). At L6 —
     the same check re-runs with notebook tabs added to the corpus doc (tabs disclose + export
     like everything else). Native UI only — no js-editor bundle implications for MAS gating.
11. **THE EPDOC NOTEBOOK — embedded tabs in a single note (owner directive 2026-07-06).**
   A note opened in Epdoc can host TABS: the markdown body + sheet tabs (RECKONER datasets) +
   a "+ new tab" launcher pane (add a sheet, and later MAS-June assist references only if separately
   proven). LUMENLENS owns the CONTAINER:
   - **Truth rule (KEELSTONE Phase 4.5 unbroken):** the `.md` stays the sole note truth. Tabs
     persist as a Tier-B TAB MANIFEST of references (dataset ids, session ids, order, titles) —
     never embedded blobs. Dataset truth stays in RECKONER vault artifacts; GRDB is derived cache.
     Assist/chat truth
     must stay MAS-June/agent_core if added at all; Kindred/1Code session stores are parked. In vim/external editors the manifest reads as legible reference
     lines; Fork B round-trips it byte-stable; KEELSTONE reconcile/merge treats it as ordinary
     markdown.
   - **Seam ownership:** LUMENLENS = tab chrome, manifest syntax + round-trip, launcher pane,
     lens-fidelity integration (tabs disclose via the robust popovers on Prose/Source).
     RECKONER = sheet-tab content (its grid seam, second mount; `EPI-RP-09` D10 resolves the
     WebView economics + double-mount rules). MAS-June assist = any future chat-tab/assist content;
     Kindred K6 minichat is parked. Sheet tabs render fully on MAS.
   - **Guard rails:** no new chat system; the launcher is a pane inside the note, not a room;
     dangling references (deleted dataset/session) get a tombstone-tab UX, never silent loss;
     tab types beyond body/sheet/chat require the RECKONER D10 earn-a-tab survey's verdict.
   - **Done-bar (new phase L6 — after L2 and the RECKONER content seam exists):** a note
     with body + 2 sheet tabs and, only if proven MAS-safe, one June assist reference round-trips byte-stable through every lens; external
     edit of the manifest reconciles; deleting a referenced dataset shows the tombstone tab;
     the same note on MAS renders body + sheet tabs and discloses the chat tab with export.
12. **BLOCK-LEVEL EMBEDDED DATA + NAVIGATION, and the ENTERPRISE-MD housing rules (owner
   directive 2026-07-06).** The hierarchy is two levels: note-level TABS (P-AMEND 11) and
   BLOCK-level embeds inside the body (dataset embeds first; the same embed-node family carries
   any future rich type). Both must be first-class and easily navigable:
   - **Navigability:** embedded blocks join the note's outline/TOC (extend the EXISTING `TOCItem`
     infrastructure in `NoteDetailWorkspaceView`) — jump-between-embeds (next/prev + outline
     click), click-through to the source (dataset workspace tab / session), keyboard-reachable.
     Tabs and block-embeds share one navigator model so the notebook never needs a second nav UI.
   - **Enterprise-MD housing rules (how a plain `.md` robustly carries all of this):**
     (a) every tab/embed reference carries a STABLE ID (UUID) + type + version — renames never
     break references; (b) syntax is human-legible in raw markdown (vim shows meaningful lines);
     (c) FORWARD-COMPAT: an unknown/newer reference type or version degrades to Tier-C behavior —
     preserved byte-exact, shown as a tombstone with disclosure/export, NEVER dropped or
     "corrected"; (d) the **frontmatter nuance**: Fork B's "frontmatter verbatim passthrough"
     binds the MARKDOWN SERIALIZER — if the tab manifest lands in frontmatter (researcher fork,
     RECKONER D10), the app edits it ONLY through a dedicated YAML-safe structured-edit path,
     never by reserializing through the markdown engine; manifest edits are ordinary vault writes
     (AtomicVaultWriter) and reconcile as ordinary markdown under KEELSTONE; (e) manifest/embed
     changes are minimal-diff like everything else (a tab add = a few-line git diff); (f) the
     #440 corruption fixtures extend to cover manifests + embed references (external tools must
     never see them mangled).
   - **Done-bar (joins L6):** outline navigation reaches every tab + embed; an unknown-type
     reference survives a full edit/save/reload cycle byte-exact with a tombstone; a
     manifest-in-frontmatter edit (if that fork is chosen) leaves all other frontmatter keys
     byte-identical.
13. **TRUTH-FLIP CORRECTION (2026-07-06, RECKONER audit #4).** P-AMEND 9's "own truth model (GRDB
   tables…)" and P-AMEND 11's "Dataset truth stays GRDB" are SUPERSEDED: dataset truth = the VAULT
   ARTIFACT (CSV / XLSX-.icalc + .dataset.md companion); GRDB = derived cache. Nothing else in
   P-AMEND 9/11/12 changes — the boundary (note tables editor-side; datasets referenced never
   duplicated), the payload-agnostic span rule, the notebook manifest, and the disclosure/export
   contracts all stand; exports still ride IronCalc. "Data room" phrasing anywhere = the dataset
   tab surfaces (the room stays cut).
