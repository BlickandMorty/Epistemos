# Epistemos Retained Build: Rich Epdoc and Multitask Graph Execution Prompt

Task ID: `EPISTEMOS-RETAINED-BUILD-LANE-B-2026-07-15`
Canonical execution key: `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`
Role: Lane B, sole retained-construction/Epdoc/graph edit owner
Execution order: deferred until Lane R records its stable source checkpoint

Do not execute this prompt while Lane R removal is active. When the owner or
coordinator starts it after Lane R's stable source checkpoint, execute it and
do not stop after producing another plan.

## Grounding before any edit

Repository: `/Users/jojo/Downloads/Epistemos`
Branch: `feat/goose-surface`

1. Fetch origin. Verify the current branch, local HEAD,
   `origin/feat/goose-surface`, and
   `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
   match. If they do not, stop without resetting or overwriting anything and
   explain the mismatch.
2. Read in full, in this order:
   - `AGENTS.md`
   - `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
   - `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`
   - canon `14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md`
   - canon `15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md`
   - canon `16_TWO_LANE_REMOVAL_AND_REBUILD_DIRECTIVE_2026_07_15.md`
   - `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
   - `docs/plans/keelstone/INTENT_LEDGER.md`, especially the native TextKit 2,
     Epdoc richness, toolbar, title, 67k-72k, Home/Multitask, and graph checkpoints
   - `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
   - `docs/prompts/PROMPT_PLAN_2_EDITOR.md` as historical behavior/test inventory,
     not as authority to restore AI or the retired runtime
   - `docs/canon/epistemos_mas_master_canon_2026_07_08/12_LIVE_REFERENCE_AND_FREE_V1_SURFACE_REGISTRY_2026_07_13.md`
   - `docs/canon/epistemos_mas_master_canon_2026_07_08/13_EXECUTIVE_CONTINUITY_AND_FREE_V1_REMEDIATION_2026_07_13.md`
   - `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md`
   - current Epdoc/graph source, prior Tiptap/ProseMirror source and Git history,
     call sites, tests, fixtures, logs, artifacts, and diff.
3. Load and follow `agentic-engineering-protocol`. When the bounded source
   implementation appears complete, use `deep-hardening-loop`; do not claim
   product/release completion without the integration evidence below.
4. Inspect `git status --porcelain=v1 -uall`. Preserve all dirty work.
   Settings files belong to another owner session: do not edit, revert,
   format, stage, or absorb them.
5. Create and maintain your scoped ledger only at:
   `docs/plans/two_lane_2026_07_15/BUILD_INTENT_AND_EVIDENCE.md`.
   Record this owner directive verbatim, interpretation, constraints,
   non-goals, tests, files, proof, verification debt, and every later steer.
   Do not edit the central canon, handoff, central intent ledger, exact runtime
   evidence, or manifest; those are coordinator-owned.

## Exact owner intent

The current native Epdoc is visibly bare and has lost the robust rich-document
behavior, header/title treatment, typography, fonts, palettes, blocks, toolbar,
and polish the earlier Tiptap Epdoc had. Restore all useful deterministic rich
behavior and exceed it on the selected native TextKit 2 + JSON architecture.
Do not restore Tiptap itself, AI suggestions, a raw-Markdown Epdoc, or a
synchronous Markdown mirror.

The current Multitask Graph opens blank. Diagnose and repair it as a real
runtime/data/host defect. A blank canvas is not an acceptable empty state.

## Immediate P0-A - Make Epdoc unmistakably rich again

Start from current canonical `.epdoc` JSON, `EpdocContentEnvelope`, package,
TextKit 2 session/view, document, chrome, toolbar, graph projection, tests, and
legacy migration. Inventory the last deterministic Tiptap Epdoc and all owner
steers before changing source. Map each behavior to `present`, `partial`,
`missing`, `intentionally retired`, or `canceled AI` in your ledger.

Implement a real native rich-document vertical slice, not CSS/token polish:

1. Rich block presentation and editing:
   - paragraphs and H1-H6 hierarchy;
   - bold, italic, underline, strike, inline code, links;
   - blockquotes, code blocks, dividers;
   - ordered/unordered lists, nested lists, native-quality checklists;
   - tables with stable selection/editing behavior;
   - selection-scoped commands, split/merge, stable block IDs, Unicode/IME,
     undo/redo, copy/paste, find and truthful replace support;
   - images/attachments rendered as useful native objects where current schema
     supports them, plus accessible honest placeholders for not-yet-admitted
     audio/drawing/PDF/calendar/task/Meeting/rich node families.
2. Typography and visual system:
   - restore the Epistemos palette across canvas, selection, caret, headings,
     links, code, quotes, dividers, tables, lists/checklists, placeholders, and
     object accents in light/dark mode;
   - preserve and expose Matrix regular, Matrix Bold, Matrix Dots/type variants,
     Chonky, and GNF/Greetings fonts without late metric shifts;
   - keep body/header spacing, readable measure, line height, insets, alignment,
     and viewport behavior stable while editing and resizing;
   - do not make Epdoc look like Source/raw Markdown.
3. Header/title and chrome:
   - use the recovered regular interactive `MotionTitle` ASCII/blur reveal on
     document identity/navigation changes;
   - preserve Name/Tags/Where, rename/move, keyboard/VoiceOver, traffic lights,
     drag regions, restoration, and Reduce Motion;
   - remove the glass title bubble and duplicate deprecated left title;
   - ensure standalone Epdoc has actual popover parity rather than a label.
4. Toolbar and geometry:
   - full rich Epdoc toolbar, with every visible command backed by a native
     operation and fail-first test;
   - headings/marks act on the selection or intended caret block, never the
     whole document;
   - lists/checklists/tables/nested structures/link/image/find/replace are not
     silently hidden to call the toolbar complete;
   - width/margin control works, uses a normal centered default, does not snap,
     overflow, move Epdoc to the right, steal selection, or mutate document JSON.
5. Document truth and performance:
   - JSON-only autosave, atomic save/recovery, stable IDs, migrations, external
     change/conflict, close/reopen, versioning, and crash behavior;
   - explicit collision-safe independent Markdown publishing and explicit PDF
     snapshot boundaries; no reverse sync or silent Markdown overwrite;
   - viewport/chunked rich rendering that never hides/restores stale text;
   - 4k, 20k, 67k-72k-word, 72k-character, and 2x rich-JSON fixtures for
     typing, rapid backspace/delete, selection, scroll while editing, undo,
     toolbar commands, save/reopen, resize, graph navigation, and memory.

Do not merely re-enable all schema nodes at once. Add each native operation with
tests and an honest unsupported state; preserve unknown/legacy bytes.

## Immediate P0-B - Repair blank Multitask Graph

Treat the owner's observation as current runtime evidence requiring diagnosis.

1. Trace current destination dispatch from Landing and Notes sidebar through
   Home Graph versus Multitask Graph, workspace/tab construction,
   `GraphWorkspaceRoute`, `GraphWorkspaceContainer`, graph state/data loading,
   vault lifecycle, renderer size/visibility, physics lifecycle, and node open.
2. Write a failing host/route test that proves Multitask Graph receives a
   non-empty allowed graph fixture and produces a visible renderable scene.
   Cover an honestly empty vault with a deliberate labeled empty state.
3. Check common blank-canvas causes with evidence: unsupported/stale persisted
   graph mode, wrong route, zero-size host, occlusion, missing environment,
   graph load never triggered, load canceled on tab attach, all nodes filtered,
   stale vault identity, renderer/physics paused forever, or an overlay hiding
   the scene. Do not guess.
4. Repair the smallest proven cause while preserving:
   - exactly Home Graph and Multitask Graph; no faceless third mode;
   - Free policy exclusion of chat/agent/model/provider nodes;
   - allowed Markdown and Epdoc nodes/edges;
   - canonical writable Markdown/Epdoc open routes;
   - stable repeated destination switching, resize, tab restore, vault switch,
     empty/populated state, accessibility, and hidden-loop quiescence.

## File ownership and forbidden overlap

You own the native Epdoc JSON/TextKit 2, rich-envelope/projection, chrome,
toolbar, theme/font, object rendering, Epdoc graph projection, and Multitask/
Home graph route/host/container/renderer files required above.

Do not edit:

- `Epistemos/App/ProductCapabilityPolicy.swift`
- Contextual Shadows files
- QueryParser/StructuredQueryParser/QueryCompiler/QueryRuntime
- notebook Chat/Sheet removal, TOC, disclosure, or restoration files
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- Free JS editor AI-removal/HandleWithCare files or AI-only bridge/review files
- AppBootstrap/AppEnvironment/EpistemosApp removal seams
- `project.yml`
- `scripts/keelstone-release-gate.sh`
- any Settings file
- canon 00-16, central handoff/ledgers/evidence, or manifest

If your change genuinely requires one of those files, record the exact file,
caller, minimal requested seam, and test in your scoped ledger; do not make the
overlapping edit. Continue the other P0 work.

Prefer Lane-B-specific tests such as the existing
`EpdocCanonicalContentTests.swift`, `EpdocNativeToolbarTests.swift`, and new
dedicated Multitask Graph tests. Do not edit Lane R's removal tests or the shared
giant App Store lane test file.

## Verification protocol

Implement and inspect the complete owned diff. Run source-only guards that do
not launch Xcode or Epistemos, and record everything deferred.

Do not run `xcodebuild`, launch Epistemos, delete/replace an app or archive, or
claim runtime behavior while Lane R may still be editing. Finish with a source
checkpoint in your scoped ledger containing:

- behavior inventory from the previous rich Tiptap Epdoc;
- every owned file changed;
- fail-first tests and their intended proof;
- source/static commands actually run;
- exact remaining Xcode, visual, large-document, graph, memory, accessibility,
  save/recovery, and manual/runtime debt;
- any requested cross-lane seam;
- `READY_FOR_SERIAL_INTEGRATION_VERIFICATION` only if your owned diff is stable.

After both lanes are stable, one integration owner must run the mandatory
below-16-GiB preflight, remove stale products, produce exactly one current App
Store build/test product, and execute the owner-visible Epdoc plus both-graph
matrix. The rich Epdoc done bar requires screenshots and manual editing on that
exact app; the graph done bar requires visible populated and explicit-empty
states. Only after those immediate P0 defects are current-green may this lane
continue the retained capability order in canon 15. Do not start a new execution
key or claim KEELSTONE/release completion.
