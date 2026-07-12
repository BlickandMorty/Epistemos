# DEEP-RESEARCH PROMPT — PLAN 9 (RECKONER): AGENT-NATIVE DATA, RESHAPED (the triad's third piece)

**ID:** `EPI-RP-09-RECKONER` · **Codename:** RECKONER · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: if reused,
> research RECKONER for MAS/June only. Treat KINDRED/1Code as parked provenance;
> the active agent caller is June through in-process `agent_core`.

> **How to use this file.** Give the research model four inputs, in this order:
> 1. `INTEGRATION_FABRIC.md` (whole file).
> 2. `RESEARCH_PROMPT_STANDARD.md` (whole file).
> 3. `PROMPT_PLAN_9_DATA_TABLES.md` §0, §1-§11, Cross-plan note, and especially the BINDING
>    `RESHAPE`, `Exact §0 supersession map`, and `TRUTH-FLIP SUPERSESSION`.
> 4. Everything below `─── BEGIN ───` in this file.
>
> Output = a **build-ready dossier + implementation spine** hardening the RESHAPED MAS direction
> (2026-07-06 plus 2026-07-07 MAS pivot) against LUMENLENS `EPI-RP-02`; KINDRED `EPI-RP-05` is parked. Owner authored
> 2026-07-06. This is a research brief, not a build brief: the researcher returns the dossier,
> schemas, seams, file-tree/skeleton proposals, contradiction sweep, self-score, and self-critique.
>
> **Build target: MAS only.** The data core, tools, tabs, and embeds ship on MAS. The older
> companion/minichat presence chrome is parked; June answers the active tools on MAS.
>
> **This is a RE-RESEARCH of direction, not of engine keystones.** The 2026-07-03 canon
> (`PROMPT_PLAN_9_DATA_TABLES.md` + `PLAN9_ADJUDICATION_WORKING_2026_07_03.md`) clone-verified the
> engine architecture — silent-Univer renderer × IronCalc sole calc authority × vault-artifact
> truth with GRDB as derived cache × dual-zone/defined-names deferred post-v1 — against fresh
> clones (ironcalc/univer/teable/baserow) and the 2026-07-06 audit. DO NOT re-litigate those
> keystones. What changed is the PRODUCT SHAPE (the canon's RESHAPE + §0 supersession map +
> truth-flip): the standalone Data room is CUT; the docked chat panel is CUT; five-views-v1 is
> deferred to grid-first; the vault artifact outranks GRDB. Your job: make the new shape as hard
> as the old engine without resurrecting stale pre-wave wording.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal product-architecture researcher for an agent-native data layer inside a macOS PKM.
Produce a build-ready dossier AND a compact implementation spine: chosen mechanisms with rejected
alternatives named, schemas, seams (who owns what), UX flows, failure modes, perf budgets, phased
build order with witnessable done-bars, and concrete build contracts (DDL, Swift/Rust/TypeScript
interfaces, bridge payloads, markdown/reference syntax, preview/export provider protocols, and a
proposed file tree). External claims cited to primary sources; engine facts may cite the existing
adjudication instead of re-deriving. No invented APIs; unknowns flagged with fallbacks.

**Run three internal cycles before finalizing, and print the cycle outcomes:**
1. **C1 — Engine inheritance audit:** verify every claimed engine fact is inherited from the
   2026-07-03 canon/adjudication or newly cited with file:line/source; do not re-open locked
   keystones without new evidence.
2. **C2 — Triad integration audit:** prove the RECKONER shape plugs into KEELSTONE, LUMENLENS, and
   KINDRED through named seams rather than absorbing their scope.
3. **C3 — Contradiction/buildability audit:** sweep for resurrected Data-room, docked-chat,
   five-views-v1, duplicate-truth, hidden-content, MAS-subprocess, and new-chat contradictions; then
   rewrite any section that fails the rubric before returning.

## 1. Product context (ground truth — design against this)
Epistemos = macOS-native PKM (Swift 6 + Rust agent_core/UniFFI + GRDB + WKWebView). Active build:
MAS (sandboxed, June agent, in-process agent_core, no subprocess). 1Code/Experimental/Kindred are
parked. Notes = markdown files in a
vault (file-truth, KEELSTONE `EPI-RP-07`); the editor = four synced lenses with Epdoc
(Tiptap-in-WKWebView) as default (LUMENLENS `EPI-RP-02`); ONE companion identity works across
surfaces through MAS-June context/provenance, not through Kindred runtime.

**RECKONER after the reshape — the triad's third piece, not a fourth room:**
1. **Primary door = the agents.** Datasets are created/restructured/queried through an F2
   capability ("track my reading list," "make this note's table real," "chart this") with
   dry-run → schema-diff preview → confirm → apply → undo, ledger-attributed. June drives the
   active MAS tools. **No new chat
   anywhere. No docked chat panel.**
2. **Datasets open as TABS in the existing note workspace tab group** (direct precedent:
   `.epdoc` documents already join `NoteWindowManager.noteTabbingIdentifier`). Native chrome
   ceiling: toolbar/table-switcher/schema-inspector + Swift Charts. WKWebView ONLY for the grid.
3. **Inline note embeds** (the vault-integration moat): notes reference datasets via
   wikilink/embed — records are first-class vault objects (wikilinks, graph nodes).
4. **CUT/deferred:** the dedicated room + chrome; kanban/gallery/calendar/form + record-detail
   views (deferred phases — grid first).

**Locked engine keystones (cite the adjudication + 2026-07-06 audit; do not re-derive):** Univer
OSS = silent grid renderer (`notExecuteFormula: true`); IronCalc = the ONLY calc authority (WASM
co-resident in the WebView for the hot loop; native via UniFFI `epistemos_calc` for headless/agent
calc for MAS/June); dataset truth = the vault artifact (CSV for flat datasets, XLSX/`.icalc`
for workbooks, plus `.dataset.md` metadata); GRDB = derived working cache/index, rebuilt from the
vault and synchronously written back on commits; dual-zone/defined-names is deferred post-v1, not
killed; xlsx via IronCalc; never Univer Pro; Teable = AGPL behavior-reference only; IronCalc has
NO dirty-cells accessor after evaluate() (snapshot-diff dependents) and NO merge-cells API;
`CellValue = {None, String, Number, Boolean}`.

## 2. Thesis
**Data is something the agent does FOR you, that you can then open like a document and embed like
a link.** The measure of success is not "a powerful data room" — it is: a user asks the companion
to track something, watches a schema-diff preview, confirms, and from then on a live dataset
exists as a tab beside their notes and as embeds inside them, maintained conversationally, every
structural change attributed and revertible. Harden that loop until it is boringly reliable.

## 3. Hard constraints (a design violating these is wrong)
1. Engine keystones above are LOCKED (new evidence required to touch them).
2. **No new chat; no room.** Agent access = June (MAS) through ONE F2 tool
   surface backed by in-process `agent_core`. KINDRED minichat/main-agent and
   presence chrome are parked provenance.
3. **One truth per domain:** notes = vault files; datasets = vault artifacts
   (CSV/XLSX-`.icalc` + `.dataset.md`); GRDB is a derived cache/working store. Cross-domain =
   references (wikilink/embed/graph), NEVER row duplication into markdown.
3b. **Nothing lost, nothing hidden (owner directive 2026-07-06):** Epdoc is the richest lens; when
   the user switches to Prose or Source, any content those lenses cannot render — INCLUDING
   dataset embeds and notebook tabs (3c) — must surface through LUMENLENS's **Lens-Fidelity
   Disclosure** affordance (`docs/plans/lumenlens/` §P-AMEND 10): an info toggle listing every
   not-renderable-here item with a rendered preview + jump-to-Epdoc. The popovers are ROBUST:
   high-quality previews (real rendered snapshots, not placeholders) plus per-item actions —
   **download / export** (dataset → xlsx via IronCalc's verified `save_to_xlsx` / CSV; chart →
   image; chat tab → markdown transcript) — so complex content is fully usable from ANY lens.
   RECKONER embeds/tabs REGISTER preview+export providers; RECKONER does not build its own
   disclosure UI.
3c. **The Epdoc Notebook (owner directive 2026-07-06):** a single note file, opened in Epdoc, can
   host EMBEDDED TABS — the markdown body plus sheet tabs (RECKONER datasets)
   and, only if separately proven MAS-safe, June assist references. The `.md`
   file stays the SOLE note truth
   (KEELSTONE Phase 4.5): tabs are persisted as REFERENCES in the markdown (a Tier-B tab
   manifest), never embedded blobs — dataset truth stays the RECKONER vault artifact. Seam ownership: LUMENLENS owns the tab container + manifest +
   round-trip;
   RECKONER owns the sheet-tab content (same grid seam as D2/D3, second mount point).
   KINDRED/1Code chat tabs are parked; MAS renders sheet tabs fully and may
   later add June assist references only after a separate MAS-safe proof.
4. Every structural/bulk agent op: dry_run → schema-diff preview → confirm → apply → undo, with
   attribution through the LUMENLENS provenance schema (its span metadata is payload-agnostic BY
   DESIGN for this reason — `docs/plans/lumenlens/` §P-AMEND 9).
5. MAS: no subprocess; sandbox-legal; keys in Keychain. Never block @MainActor; UniFFI callbacks
   hop main.async. Graph via public API only.
6. Licensing discipline unchanged (Apache-2.0 Univer OSS, MIT/Apache IronCalc, Baserow MIT
   donor-only, Teable clean-room only).
7. Do not absorb LUMENLENS/KINDRED scope — their seams are external interfaces named by ID.

## 4. What exists (design to extend)
- The canon + adjudication (engine verification, DDL drafts, donor map, §8 perf guardrails,
  §11 hardening) — your inheritance, minus the superseded shape items.
- The plan packages: `docs/plans/lumenlens/` (SuggestionAdapter, provenance schema, epoch
  bridge, tiered serializer) + `docs/plans/keelstone/` (AtomicVaultWriter, reconciler, MAS
  leak-proof schema). `docs/plans/kindred/` remains parked provenance only.
- Repo precedents: the note/doc tab group (EpdocDocument tabbing, guard-tested); the Epdoc
  WKWebView patterns (custom scheme `epistemos-doc://` + brotli, script-message bridge, process
  pooling, teardown discipline); the existing per-vault GRDB (SearchIndexService etc.); the F2
  capability registry concept (`INTEGRATION_FABRIC.md`). 1Code `sub_chats.sessionId`/`stream_id`
  are historical references only.

**Researcher reality check:** You may not have repo access. Treat these file paths as design targets
and mark each claim as **observed from provided canon**, **inferred from provided canon**, or
**requires repo verification**. If a mechanism depends on exact live code (for example tabbing
identifier, bridge handler names, or 1Code store columns), give the verification query/file to run.

## 5. Research dimensions

### D1 — The agent-first data lifecycle ★ (the new primary door — go deepest)
- The full conversational loop: natural-language intent → typed schema inference (columns/types/
  defined names) → dry-run diff preview (what does a SCHEMA DIFF look like in chat/minichat UX?) →
  confirm → apply → undo. What does the agent do on AMBIGUOUS intent (ask vs assume)?
- **Ongoing maintenance:** the companion as data steward — appending rows from conversation
  ("log today's run"), recurring updates, dedupe, schema evolution over time (add column, retype,
  split), each attributed. How is per-ROW/CELL provenance stored without bloating the op-log?
- The F2 tool schema itself: enumerate the tools (create_dataset, alter_schema, upsert_rows,
  query, chart, import) with typed params, honest gating (which are per-turn approved), and
  IDENTICAL semantics driven by June (`agent_core`). One tool surface, one
  active MAS driver — specify the seam.
- Return a **tool-contract spine**: JSON schemas for each dry-run/apply/undo command, the preview
  hash/inverse-op requirement, per-turn approval classification, redaction rules for row/cell
  context sent to agents, and the exact failure envelope (ambiguous intent, coercion warning,
  partial import, too-large selection, timeout).
- Prior art, cited: Notion AI databases, Airtable AI/Omni, agentic-spreadsheet products (e.g.
  Shortcut/Paradigm-class), Tana supertags+AI, LLM text-to-schema literature. What they get wrong
  (silent restructuring, no undo, hallucinated schemas) → your guardrails.

### D2 — Datasets as workspace-tab documents
- The document model: a dataset "opens" as a tab in the note/doc tab group. The vault artifact is
  truth and GRDB is the live derived working copy — there is no manual dirty/save cycle like
  notes. Define tab semantics: commits produce a GRDB transaction plus synchronous vault writeback,
  native undo/redo mapping, close = just close.
- Multiple tabs/windows on ONE dataset: reuse LUMENLENS Fork C's write-lease/follower model, or
  is cache-serialized writing plus artifact-level conflict routing enough? Verdict with rationale.
- Chrome: the native toolbar/table-switcher/schema-inspector ceiling (kept from §0.7) around the
  grid WebView; Swift Charts placement; how a dataset tab title/icon lives in the tab group.
- WebView economics: one WKWebView per dataset tab vs a pooled/single grid view re-pointed —
  measure against the repo's Epdoc pooling + teardown discipline (40-60MB per editor reclaimed).
- Return a **dataset-document spine**: tab identity fields, lifecycle events, undo/redo ownership,
  close/reopen behavior, multi-window conflict policy, and bridge messages between native tab
  chrome and the grid WebView.

### D3 — The grid seam, hardened at scale
- Carry the canon's §3 seam (silent-Univer + IronCalc-WASM co-resident; edit → setUserInput +
  evaluate → snapshot-diff dependents → push `v` values into Univer; commit → bitcode diff over
  the script-message bridge). Pressure-test: 100k rows × 30 columns — virtualized rendering
  limits in Univer OSS, WASM memory envelope, evaluate() latency, diff-queue size. Cite Univer/
  IronCalc sources or flag as measure-first.
- Return an **engine-bridge spine**: Swift, Rust/UniFFI, and TypeScript interface sketches for
  workbook load, edit/evaluate, diff flush, snapshot save, undo/redo, reload after WebView crash,
  and headless agent dry-run. Keep Univer as renderer and IronCalc as sole calc authority in every
  sketch.
- Failure modes: crash mid-commit (op-log replay + vault writeback reconciliation), WebView reload
  (re-hydrate from the vault artifact through GRDB cache + to_bytes snapshot), WASM OOM, formula
  cycles, the free-zone/record-zone conflict cases.

### D4 — Embeds in notes (the moat, now sharper)
- The embed node: a LUMENLENS Tier-B markdown construct (wikilink-style reference + optional view
  params). Define the markdown syntax, round-trip rules, and render modes: LIVE values in Epdoc
  vs snapshot-with-refresh — pick one for v1 with evidence (perf, offline, sync implications).
- Embed interactions: click-through to the dataset tab; selection→cite; can an embed be edited
  in-place or read-only v1? Records as graph nodes (F4) — what links auto-materialize?
- **Cross-lens visibility (constraint 3b):** specify the embed's per-lens fidelity states —
  rendered (Epdoc) / degraded (Source shows raw reference syntax) / invisible (Prose?) — and the
  preview provider the embed registers with LUMENLENS's Lens-Fidelity Disclosure (what a
  disclosure preview shows: dataset name, dims, a value snapshot; how staleness is marked; reuse
  whatever liveness verdict D4 picks — one render path, two consumers).
- Return an **embed/reference spine**: markdown grammar, stable IDs, versioning, unknown-type
  tombstone behavior, minimal-diff edit rules, graph edge emission, preview/export provider shape,
  and examples of the raw markdown an external editor would see.

### D5 — Dataset-aware MAS-June context (no new chat)
- What June needs to serve a dataset tab: focused-dataset context injection
  (schema + selection + view state into the session) with MAS-safe status/provenance.
  Specify the context payload + size bounds.
- Parked provenance: older KINDRED minichat/session-continuity ideas may inform
  the context shape, but do not require `sub_chats.sessionId`, presence, or a
  second chat runtime.
- Return a **dataset-context packet** for MAS/June: bounded schema summary,
  selected rows/cells digest, visible view state, provenance handles, privacy/redaction policy, and
  escalation behavior when the context is too large.

### D6 — Storage placement + KEELSTONE alignment ★ (accepted truth-flip — harden the cache path)
- Dataset artifacts live in the vault as the portable truth: CSV for flat datasets,
  XLSX/`.icalc` for promoted workbooks, plus `.dataset.md` metadata. Research the exact artifact
  layout, writeback envelope, and external-editor/sync behavior; do not move truth back to
  SQLite/GRDB.
- GRDB is derived cache/working store. Fold into the existing per-vault GRDB family where possible;
  if a separate cache is proposed, it must satisfy KEELSTONE B4 as a derived index, not claim a
  truth exemption. Verdict + migration/teardown implications.
- Datasets in the release gate: what KEELSTONE §9 soak cases must extend to cover artifact
  writeback and cache rebuild (kill -9 mid-commit, sync-storm around the artifact + metadata,
  op-log replay equivalence, stale-cache invalidation).
- Return an explicit **KEELSTONE handoff card**: what, if anything, the sync/release agent must be
  reprompted with; if no reprompt is needed, say so and justify by seam ownership.

### D7 — Ingest, agent-scoped
- v1 ingest through the agent door: CSV/xlsx (IronCalc load verified) + paste-a-table; Vision/PDF
  table extraction (canon §5, MAS-legal on-device) as a phase-2 capability. Each ingest =
  dry-run schema preview first. Define size limits + failure UX.

### D8 — Performance budgets + failure table
- Budgets (merge into `docs/perf-budgets.toml` as `[reckoner.*]`): tab-open-to-interactive,
  keystroke→repaint in-grid, evaluate() p95 at 10k/100k rows, commit latency, embed render cost
  in Epdoc, WASM resident memory. Failure table in the KEELSTONE style (detect → contain →
  recover → witness) for every D3/D6 failure mode.
- Include a **measurement plan** for each budget: fixture size, hardware assumption, warm/cold
  distinction, instrumentation point, pass/fail threshold, and fallback trigger (for example
  pooled WebView, lazy mount, or renderer fallback).

### D9 — Competitive synthesis
- Cited table: Notion databases, Airtable (+AI), Obsidian Dataview/Bases, Tana, Capacities,
  AnyType, Grist — columns: truth model, agent capability, embeds, portability, offline, undo/
  provenance. End with the 3-5 moves that make RECKONER genuinely novel (leading candidate: the
  attributed, revertible, conversation-driven schema lifecycle — validate or beat it).

### D10 — The Epdoc Notebook junction ★ (new owner directive — research it hard)
A note becomes a NOTEBOOK: the markdown body + in-note tabs holding sheets and chats, navigable
inside Epdoc, with a "+ new tab" launcher page (add a sheet · start a chat · what else earns a
place?). This is the triad physically converging inside one document — design it so it stays
honest:
- **The tab manifest in markdown:** how tabs persist inside the `.md` (frontmatter manifest vs a
  fenced Tier-B block vs per-tab reference syntax) — pick with evidence on round-trip stability,
  external-editor readability (vim shows legible reference lines), merge/conflict behavior under
  KEELSTONE reconcile, and Fork-B byte preservation. The note remains a valid, readable markdown
  file everywhere. **Enterprise-MD housing rules bind whichever fork wins** (LUMENLENS §P-AMEND
  12): stable UUID + type + version per reference; unknown/newer types degrade to byte-preserved
  tombstones (never dropped); if frontmatter wins, app edits go through a YAML-safe structured
  path (Fork B's verbatim rule binds the markdown SERIALIZER, not deliberate app edits); manifest
  edits are minimal-diff; the #440 corruption fixtures extend to manifests + references.
- **Block-level embedded data is the same family, navigable:** dataset embeds (D4) and any future
  rich block share ONE embed-node family and ONE navigator — embeds + tabs join the note
  outline/TOC (LUMENLENS extends its existing `TOCItem` infra) with jump-between and
  click-through. Specify what the navigator shows for a sheet (title, dims, staleness) and how
  in-body embeds relate to tabs (an embed can be "promoted" to a tab? research the UX, don't
  assume).
- **Sheet tabs = the second mount of the same grid seam:** one dataset can be open as a workspace
  tab (D2) AND as an in-note tab — same vault artifact truth, same GRDB derived cache, same
  IronCalc/Univer instance rules. Resolve: WebView economics for N in-note tabs (lazy-mount only
  the active tab?), what happens when the same dataset is mounted twice, and how in-note sheet
  state (active view, scroll) is or isn't persisted in the manifest.
- **Chat tabs (parked):** KINDRED/1Code minichat tabs are not active MAS scope.
  If a future assist tab is needed, research a MAS-June reference that preserves
  context through `agent_core` without a new chat system, hidden session store,
  or companion runtime.
- **The "+ new tab" launcher:** an in-note landing pane (add sheet — new or existing dataset;
  start a chat; candidates from research below). Scope guard: it is a launcher INSIDE the note,
  not a room; quiet, native-feeling, no navigation weight.
- **What else earns a tab? (research, don't assume):** survey the best container-doc systems —
  Quip (docs + embedded spreadsheets + per-doc chat — the closest ancestor), Coda (docs as apps),
  Notion inline databases, Jupyter notebooks, Craft, OneNote sections, Airtable interfaces —
  and recommend at most 1–2 additional v1-worthy tab types (chart tab? PDF tab? none?) with
  rejection rationale for the rest. Bloat is the enemy; every tab type must round-trip.
- **Failure modes:** dangling references (dataset/session deleted → tombstone tab UX), manifest
  merge conflicts, tab-order preservation, a note shared to a machine without the dataset,
  export-from-disclosure as the universal escape hatch.
- **Cross-lens:** the whole notebook obeys 3b — Prose/Source show the body normally and the tabs
  through the ROBUST disclosure popovers (preview + download/export per tab).
- Return a **notebook spine**: manifest schema, sample markdown before/after adding a sheet tab and
  a chat tab, tab-order conflict policy, in-note navigator entries, lazy-mount rules, promotion
  flow from embed→tab if accepted, and MAS degradation/export behavior for chat tabs.

### D★ — Deep Fabric Integration (F1–F6) — MANDATORY (`INTEGRATION_FABRIC.md`)
- **F1 vault:** records are first-class vault objects via references; embeds live in notes;
  datasets never duplicate into markdown. **F2 capability:** RECKONER is the exemplar F2 citizen —
  one tool surface, one active MAS driver (June/agent_core), honest per-turn gating.
  **F3 status:** MAS-safe state/provenance shows dataset work without Kindred presence.
  **F4 graph:** records/datasets as nodes; embed links auto-edge. **F5 provenance:**
  every structural op attributed through the shared ledger (payload-agnostic spans); "what did
  the companion change in my data this week" is answerable. **F6 state bus:** calc/refresh/commit
  states stream to all surfaces; embeds show staleness honestly.
These six briefs + this one form a **single integrated product built one plan at a time**.

## 6. Primary-source discipline
Engine facts: cite `PLAN9_ADJUDICATION_WORKING_2026_07_03.md` + the clone paths rather than
re-deriving; NEW claims about Univer/IronCalc internals need file:line from the clones or upstream
sources. External products: official docs/changelogs over blogs. SQLite-under-sync and sandbox
claims require primary/official sources first (sqlite.org, Apple docs, vendor docs for iCloud/
Dropbox behavior where available), with incident write-ups only as corroboration. Observed vs
inferred flagged; version-gated capabilities carry fallbacks. If a needed current source cannot be
verified, mark it `OPEN` and design a fail-closed fallback instead of guessing.

## 7. Deliverable
1. Executive thesis (the loop, boringly reliable). 2. **Agent-first lifecycle + F2 tool schema**
(D1 — longest). 3. Tab-document model + lease verdict (D2). 4. Grid seam at scale + failure
modes (D3). 5. Embed spec + liveness verdict (D4). 6. Dataset-aware chat parameterization (D5).
7. **Storage-placement verdict** (D6 — the hard call, with the KEELSTONE gate extensions).
8. Ingest (D7). 9. Budgets + failure table (D8). 10. Competitive + novel moves (D9).
11. **The Epdoc Notebook** (D10 — headline: manifest verdict, second-mount rules, chat-tab seam,
launcher scope, the earn-a-tab survey, failure modes). 12. Deep Fabric section (D★).
13. **Implementation Spine Appendix** with proposed file tree plus the contracts requested in D1-D6,
D8, and D10: tool JSON schemas, DDL, UniFFI/Swift/TS interfaces, bridge payloads, markdown
reference grammar, preview/export provider protocols, notebook manifest examples, failure table,
and perf-budget TOML snippet. 14. **Phased build order** (data core → native IronCalc/UniFFI → grid
seam → tab documents → F2 tools + dry-run loop → embeds → notebook tabs + launcher →
dataset-aware MAS-June context → ingest), each phase with a WITNESSABLE done-bar; flag dependencies (KEELSTONE
0-4; LUMENLENS L1/L5 + the tab container). 15. **Contradiction sweep** against the old
Plan 9 room/chat/five-view wording and against LUMENLENS/parked-KINDRED ownership; include verdicts.
16. Open questions preserved (not silently resolved). 17. Self-critique + rubric scores (§3 of the
standard; iterate any axis <4). If any axis remains below 4, the dossier is not done.

## 8. Anti-patterns (do NOT do)
Do not resurrect the room, the docked chat panel, or five-views-v1. Do not re-litigate the
clone-verified engine keystones without new file:line evidence. No dual-compute (Univer formula
engine stays OFF). No Univer Pro, no Teable code, no server, no subprocess on MAS. No second chat
system on any build. No silent agent restructuring — every structural op previews and is
revertible. Do not absorb LUMENLENS/KINDRED scope; name their seams by ID. Do not leave the
storage-placement fork unresolved — it gets a verdict with evidence. Notebook tabs are REFERENCES
in the markdown, never embedded blobs (the `.md` stays sole note truth and stays readable
everywhere); chat/assist tabs are parked unless rebuilt as MAS-June references, never a new chat runtime; the "+ new tab"
launcher stays inside the note — it is not a room; do not add tab types the earn-a-tab survey
can't defend. Do not return a dossier without an implementation spine, contradiction sweep,
phase-by-phase done-bars, and explicit handoff cards for KEELSTONE, LUMENLENS, and parked-KINDRED seams.

─── END RESEARCH BRIEF ───

---

## POST-WAVE ANNOTATION (2026-07-06 — the wave returned; audit #4 accepted with amendments)
The accepted truth-flip is now merged into this brief: vault artifact = truth, GRDB = derived
cache (see the canon's TRUTH-FLIP SUPERSESSION + `docs/plans/reckoner/`). The old "data core is
TRUTH so B4's exemption holds" argument is invalid — the reckoner GRDB is DERIVED, B4 binds, and
the pool joins SearchIndexService's existing DB unless a measured derived-cache exception is
documented. OQ-1/OQ-2 (IronCalc wasm surface) were settled empirically during the audit (=0.7.0,
4-arg ctor, no UserModel in wasm). The build-ready package + full amendment set:
`docs/plans/reckoner/`.
