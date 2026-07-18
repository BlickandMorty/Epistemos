# 16 - Two-Lane Removal and Rebuild Directive - 2026-07-15

ID: `EPISTEMOS-MAS-TWO-LANE-REMOVAL-REBUILD-2026-07-15`
Parent: `EPISTEMOS-MAS-MASTER-CANON-2026-07-08`
Execution key: `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`
Status: authorizes two bounded implementation sessions in strict sequence;
Lane R removal is current and Lane B build is deferred; no new canonical
execution key

This directive supersedes canon 14/15's owner-review pause only for the two
scoped sessions below. Canon 14 still controls the product boundary and canon
15 still controls the complete add/remove/harden/test register.

## Owner intent checkpoint

### Verbatim owner excerpt

> “i want to continue in anotehrsession but i have a whole new directive i want
> to start the mass removal of things that need to be removed ... start a
> promot for thing that should be added.”

> “epdoc is now a bare new thing i want it to have all the rich stuff teh
> previoustiptap edpoc had and more.”

> “the multitask graphdoes not work it is blank.”

> “the header behavior everythign about it feels new and lacks teh robustness
> of what it use to be including the font palettes etc.”

### Interpreted intent

- Start two implementation sessions from the durable canon in sequence rather
  than another planning-only pass: finish Lane R's source checkpoint first;
  only then start Lane B.
- Lane R removes or fail-closes everything canon 15 classifies as canceled,
  parked, stale, or forbidden in Free V1 while preserving historical/user data
  and deterministic compatibility.
- Lane B builds and repairs everything canon 15 retains, starting with two
  current owner-observed P0 failures: Epdoc is visibly bare and has lost the
  previous rich-document robustness, and Multitask Graph opens blank.
- Native TextKit 2 plus canonical JSON `.epdoc` remains the selected Epdoc
  architecture. “Restore Tiptap richness” means recover and exceed the useful
  deterministic rich behaviors, styling, fonts, palettes, toolbar, blocks,
  save/undo/accessibility, and visual hierarchy. It does not mean restore the
  retired Tiptap/ProseMirror runtime, AI suggestions, or Markdown mirroring.
- Both sessions must read the complete owner history and current source before
  editing, write fail-first tests, implement their lane, and leave exact
  verification debt. They do not run concurrently, may not make overlapping
  edits, and may not run competing Xcode jobs.
- “Remove notebook” is limited to the legacy Chat/Sheet/Body-strip workspace,
  its stale tabs, launchers, restoration, and presentation. It does not cancel
  or delete the notebook concept. A later Epdoc-native notebook/structured
  document may be built on canonical JSON `.epdoc` blocks without Chat,
  Reckoner/Sheet, Tiptap, AI, or the retired workspace ontology.

## Shared authority and read order

Both lanes read in full before editing:

1. `AGENTS.md`
2. `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
3. external source-of-truth canon `00_READ_FIRST.md`
4. canon `14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md`
5. canon `15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md`
6. this canon `16_TWO_LANE_REMOVAL_AND_REBUILD_DIRECTIVE_2026_07_15.md`
7. `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
8. `docs/plans/keelstone/INTENT_LEDGER.md`
9. `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
10. `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md`
11. the lane-specific prompt and every source/test/call-site document it names

Local HEAD, fetched origin, and the handoff-publication SHA must match before
editing. Preserve the dirty worktree. Do not reset, overwrite, mass-format, or
stage unrelated changes.

## Non-overlap and sequential ownership

### Lane R - removal/fail-closed owner

Owns current Free product boundaries and canceled-source removal, including:

- product capability policy and Free-policy tests;
- Contextual Shadows state/panel and its mounting seam;
- query parser/compiler/runtime result sanitization;
- legacy Chat/Sheet notebook, TOC, disclosure, restoration, and recovery UI;
- Free editor JS entrypoint/dependency split and AI-only bridge/review removal;
- App bootstrap/environment/root approval sheets and canceled service startup;
- stale deterministic HTML/onboarding/Home copy outside Settings;
- Reckoner dataset hook and parked capability routes;
- `project.yml` target membership and KEELSTONE release-gate scanners.

Lane R may read but must not edit Lane B's Epdoc TextKit 2, rich-envelope,
toolbar/theme, or graph-host files.

The current authorized implementation session is Lane R. Lane B remains
deferred until Lane R records a stable source checkpoint and the coordinator
or owner explicitly starts the retained-build prompt.

### Lane B - retained construction and defect owner

Owns retained non-AI product construction, starting with:

- native Epdoc JSON/TextKit 2 session, view, document, chrome, toolbar, rich
  envelope/projection, theme/fonts, object rendering, save/undo/export seams,
  and dedicated tests;
- Multitask Graph route/host/container/physics/data-loading defect, Epdoc graph
  projection/opening, Home/Multitask graph destination behavior, and dedicated
  tests;
- retained editor identity/title/Name-Tags-Where, typography, palettes, width,
  large-document, accessibility, and performance behavior within those owned
  files.

Lane B may read but must not edit Lane R's policy, Contextual Shadows,
QueryRuntime, notebook-removal, bootstrap, JS AI-removal, `project.yml`, or
release-gate files.

### Externally owned and coordinator-only files

- Settings files are owned by the owner's separate Settings-cleanup session.
  Both lanes preserve them untouched unless the owner later transfers
  ownership explicitly.
- Canon 00-16, central `INTENT_LEDGER.md`, exact runtime evidence, current
  handoff, and manifest are coordinator-owned after this publication. Each lane
  writes a separate scoped intent/evidence ledger named in its prompt.
- `NoteDetailWorkspaceView.swift` belongs to Lane R for this batch because it
  contains the notebook/Contextual Shadows removal seams. Lane B must repair
  Multitask Graph without editing it; if that is impossible, record the exact
  requested seam and continue Epdoc rather than creating an overlapping edit.
- `project.yml` belongs to Lane R. Lane B may request membership changes in its
  ledger but may not edit the file concurrently.
- Neither lane edits the other's tests. Prefer new scoped test files over the
  shared giant App Store lane test file.

## Execution and verification serialization

- Lane R executes first. Lane B must not start while Lane R is implementing.
- After Lane R records a stable source checkpoint, Lane B may start as the next
  session under its own ownership map.
- Neither lane may run `xcodebuild`, launch Epistemos, delete/replace a current
  app/archive, or claim runtime behavior during its source implementation
  session.
- Each lane first reaches a source checkpoint: intent/evidence ledger updated,
  tests written, owned diff inspected, `git diff --check` clean for its paths,
  and verification debt recorded.
- After both source checkpoints are stable, one integration owner performs the
  mandatory resource preflight, retires stale products, and runs exactly one
  serial current App Store build/test product. No competing compiler or app.
- The integration owner then runs the finite removal/editor/graph manual matrix
  on that exact app. A later fresh Release archive remains part of the same
  KEELSTONE key, not either lane's independent completion claim.

## Lane R done bar

- Canon 15 P0-A, A2, A3, B, C, D, E, and F have fail-first tests and bounded
  implementation.
- Free V1 compile, launch, query, graph, notebook, restoration, Settings-copy
  boundary, accessibility, resources, and background work contain no canceled
  AI/June/LumenLens/chat/provider/model/Reckoner product path.
- Historical chat/sheet/agent records, migrations, and compatibility parsing
  remain non-destructive but cannot be queried or presented.
- Deterministic editing, note search/graph, Sync seams, native input, and Kokoro
  are not accidentally removed.
- No broad destructive deletion or false completion from hidden UI alone.
- The retired legacy workspace cannot expose Chat/Sheet/Body-strip behavior,
  but canonical JSON `.epdoc` remains free to gain a new deterministic
  Epdoc-native notebook/structured-document feature later.

## Lane B immediate done bar

### Epdoc richness recovery

- The live `.epdoc` route is unmistakably a rich document, not a bare plain-text
  or raw-Markdown surface.
- Inventory the last deterministic Tiptap Epdoc behavior and current native
  owner directives from Git/source/tests. Recover or improve: document
  hierarchy, headings, paragraphs, bold/italic/underline/strike/inline code,
  links, blockquotes, ordered/unordered lists, checklists, code blocks, tables,
  dividers, selection-scoped formatting, undo/redo, find/replace where admitted,
  image/attachment presentation, rich-node placeholders, and honest unsupported
  states.
- Restore Epistemos font and palette ownership: Matrix variants, Matrix Bold,
  Matrix Dots/type variants, Chonky, GNF/Greetings, theme pairs, selection,
  block accents, caret, placeholder, link, code, table/list/checklist, and
  light/dark behavior without late metric shifts.
- Restore robust header/title behavior: regular interactive title, recovered
  ASCII/blur reveal on identity changes, Name/Tags/Where popover, rename/move,
  no duplicate left title or glass bubble, stable traffic lights/drag regions,
  Reduce Motion, and VoiceOver.
- Keep the full Epdoc toolbar truthful and selection-scoped; no whole-document
  heading mutation, arbitrary right alignment, broken width slider, overflow,
  or command that is visible but unsupported.
- Preserve canonical JSON autosave, atomic recovery, stable block identities,
  legacy migration, independent Markdown publishing, PDF snapshot boundary,
  and the 67k-72k-word viewport/data-loss/performance bar.
- Add rich behaviors serially to native TextKit 2. Do not flip back to the old
  Tiptap runtime, CodeMirror-as-Epdoc, a synchronous Markdown mirror, or AI
  suggestion machinery.

### Blank Multitask Graph repair

- Reproduce the blank route through current source/tests before choosing a fix.
- Trace Landing/sidebar destination dispatch, workspace/tab hosting,
  `GraphWorkspaceRoute`, graph-state/data loading, product-policy sanitization,
  sizing/visibility, renderer lifecycle, vault changes, and Epdoc/Markdown node
  projections.
- A populated vault must render allowed graph nodes/edges in Multitask Graph;
  an honestly empty vault must show a deliberate empty state rather than a
  blank canvas.
- Repeated Home Graph/Multitask Graph switching must preserve route identity,
  load once as intended, avoid zero-size or occluded rendering, quiesce hidden
  physics/render loops, and open Markdown/Epdoc nodes through their canonical
  writable routes.
- The repair may not reintroduce hidden chat/agent/model/provider nodes or the
  removed faceless third graph mode.

## After the immediate Lane B defects

Only after the Epdoc and Multitask Graph defects are current-green may Lane B
continue canon 15's retained build queue: remaining rich objects and inspector,
PDF fifth surface, planner/calendar/EventKit, Quick Capture/Meeting integration,
Sync, native MAS integrations, Kokoro, and whole-app performance. Reckoner and
all canceled AI remain outside this queue.

## Prompt files

- Current prompt — Lane R:
  `docs/prompts/FREE_V1_REMOVAL_AND_FAIL_CLOSED_PROMPT_2026_07_15.md`
- Deferred until Lane R is stable — Lane B:
  `docs/prompts/RETAINED_BUILD_EPDOC_AND_MULTITASK_GRAPH_PROMPT_2026_07_15.md`

The prompts are executable authorities only within this ownership split and
the standing AGENTS/canon safety rules.
