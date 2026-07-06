# DEEP-RESEARCH PROMPT — PLAN 9 (RECKONER): AGENT-NATIVE DATA, RESHAPED (the triad's third piece)

**ID:** `EPI-RP-09-RECKONER` · **Codename:** RECKONER · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> Paste everything below `─── BEGIN ───` into a top-tier deep-research model. Output = a
> **build-ready dossier** hardening the RESHAPED direction (2026-07-06) against the dual plan
> (LUMENLENS `EPI-RP-02` + KINDRED `EPI-RP-05`). Owner authored 2026-07-06.
>
> **Build split: both builds.** The data core, tools, tabs, and embeds ship on MAS + Experimental;
> only the companion/minichat *presence chrome* is 1Code-only (June answers the same tools on MAS).
>
> **This is a RE-RESEARCH of direction, not of engine keystones.** The 2026-07-03 canon
> (`PROMPT_PLAN_9_DATA_TABLES.md` + `PLAN9_ADJUDICATION_WORKING_2026_07_03.md`) clone-verified the
> engine architecture — silent-Univer renderer × IronCalc sole calc authority × GRDB single truth ×
> dual-zone/defined-names — against fresh clones (ironcalc/univer/teable/baserow). DO NOT
> re-litigate those keystones. What changed is the PRODUCT SHAPE (the canon's RESHAPE + §0
> supersession map): the standalone Data room is CUT; the docked chat panel is CUT; five-views-v1
> is deferred to grid-first. Your job: make the new shape as hard as the old engine.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal product-architecture researcher for an agent-native data layer inside a macOS PKM.
Produce a build-ready dossier: chosen mechanisms with rejected alternatives named, schemas, seams
(who owns what), UX flows, failure modes, perf budgets, phased build order with witnessable
done-bars. External claims cited to primary sources; engine facts may cite the existing
adjudication instead of re-deriving. No invented APIs; unknowns flagged with fallbacks.

## 1. Product context (ground truth — design against this)
Epistemos = macOS-native PKM (Swift 6 + Rust agent_core/UniFFI + GRDB + WKWebView). Two builds:
MAS (sandboxed, June agent, in-process agent_core, no subprocess) and 1Code/Experimental
(Developer ID, embedded 1Code Node backend, the KINDRED companion). Notes = markdown files in a
vault (file-truth, KEELSTONE `EPI-RP-07`); the editor = four synced lenses with Epdoc
(Tiptap-in-WKWebView) as default (LUMENLENS `EPI-RP-02`); ONE companion identity works across
surfaces with an Epdoc sidebar minichat (KINDRED `EPI-RP-05`, 1Code-only).

**RECKONER after the reshape — the triad's third piece, not a fourth room:**
1. **Primary door = the agents.** Datasets are created/restructured/queried through an F2
   capability ("track my reading list," "make this note's table real," "chart this") with
   dry-run → schema-diff preview → confirm → apply → undo, ledger-attributed. The KINDRED
   companion/minichat drives it on Experimental; June drives the SAME tools on MAS. **No new chat
   anywhere. No docked chat panel.**
2. **Datasets open as TABS in the existing note workspace tab group** (direct precedent:
   `.epdoc` documents already join `NoteWindowManager.noteTabbingIdentifier`). Native chrome
   ceiling: toolbar/table-switcher/schema-inspector + Swift Charts. WKWebView ONLY for the grid.
3. **Inline note embeds** (the vault-integration moat): notes reference datasets via
   wikilink/embed — records are first-class vault objects (wikilinks, graph nodes).
4. **CUT/deferred:** the dedicated room + chrome; kanban/gallery/calendar/form + record-detail
   views (deferred phases — grid first).

**Locked engine keystones (cite the adjudication; do not re-derive):** Univer OSS = silent grid
renderer (`notExecuteFormula: true`); IronCalc = the ONLY calc authority (WASM co-resident in the
WebView for the hot loop; native via UniFFI `epistemos_calc` for headless/agent calc on both
builds); SQLite/GRDB = the single durable truth, synced at transaction boundaries via IronCalc
`UserModel` (`flush_send_queue()` bitcode diffs / `apply_external_diffs()` / `to_bytes()` /
`undo()/redo()`); dual-zone model (typed record zone + free formula zone) with per-column IronCalc
defined names; xlsx via IronCalc; never Univer Pro; Teable = AGPL behavior-reference only;
IronCalc has NO dirty-cells accessor after evaluate() (snapshot-diff dependents) and NO
merge-cells API; `CellValue = {None, String, Number, Boolean}`.

## 2. Thesis
**Data is something the agent does FOR you, that you can then open like a document and embed like
a link.** The measure of success is not "a powerful data room" — it is: a user asks the companion
to track something, watches a schema-diff preview, confirms, and from then on a live dataset
exists as a tab beside their notes and as embeds inside them, maintained conversationally, every
structural change attributed and revertible. Harden that loop until it is boringly reliable.

## 3. Hard constraints (a design violating these is wrong)
1. Engine keystones above are LOCKED (new evidence required to touch them).
2. **No new chat; no room.** Agent access = KINDRED minichat/main agent (Experimental) + June
   (MAS) through ONE F2 tool surface. Presence chrome 1Code-only.
3. **One truth per domain:** notes = vault files; datasets = GRDB. Cross-domain = references
   (wikilink/embed/graph), NEVER row duplication into markdown.
3b. **Nothing lost, nothing hidden (owner directive 2026-07-06):** Epdoc is the richest lens; when
   the user switches to Prose or Source, any content those lenses cannot render — INCLUDING
   dataset embeds — must surface through LUMENLENS's **Lens-Fidelity Disclosure** affordance
   (`docs/plans/lumenlens/` §P-AMEND 10): an info toggle listing every not-renderable-here item
   with a rendered preview + jump-to-Epdoc. RECKONER embeds REGISTER into that mechanism (a
   preview provider per embed); RECKONER does not build its own disclosure UI.
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
- The dual-plan packages: `docs/plans/lumenlens/` (SuggestionAdapter, provenance schema, epoch
  bridge, tiered serializer) + `docs/plans/kindred/` (presence bus via /host ws, K6 minichat
  extraction, gating) + `docs/plans/keelstone/` (AtomicVaultWriter, reconciler, two-config schema).
- Repo precedents: the note/doc tab group (EpdocDocument tabbing, guard-tested); the Epdoc
  WKWebView patterns (custom scheme `epistemos-doc://` + brotli, script-message bridge, process
  pooling, teardown discipline); the existing per-vault GRDB (SearchIndexService etc.); the F2
  capability registry concept (`INTEGRATION_FABRIC.md`); 1Code `sub_chats.sessionId`/`stream_id`.

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
  IDENTICAL semantics driven by June (agent_core) and the 1Code backend. One tool surface, two
  drivers — specify the seam.
- Prior art, cited: Notion AI databases, Airtable AI/Omni, agentic-spreadsheet products (e.g.
  Shortcut/Paradigm-class), Tana supertags+AI, LLM text-to-schema literature. What they get wrong
  (silent restructuring, no undo, hallucinated schemas) → your guardrails.

### D2 — Datasets as workspace-tab documents
- The document model: a dataset "opens" as a tab in the note/doc tab group. But GRDB truth is
  LIVE — there is no dirty/save cycle like notes. Define tab semantics: commits at IronCalc
  transaction boundaries (UserModel flush), native undo/redo mapping, close = just close.
- Multiple tabs/windows on ONE dataset: reuse LUMENLENS Fork C's write-lease/follower model, or
  is GRDB-serialized writing enough (last-write at row level)? Verdict with rationale.
- Chrome: the native toolbar/table-switcher/schema-inspector ceiling (kept from §0.7) around the
  grid WebView; Swift Charts placement; how a dataset tab title/icon lives in the tab group.
- WebView economics: one WKWebView per dataset tab vs a pooled/single grid view re-pointed —
  measure against the repo's Epdoc pooling + teardown discipline (40-60MB per editor reclaimed).

### D3 — The grid seam, hardened at scale
- Carry the canon's §3 seam (silent-Univer + IronCalc-WASM co-resident; edit → setUserInput +
  evaluate → snapshot-diff dependents → push `v` values into Univer; commit → bitcode diff over
  the script-message bridge). Pressure-test: 100k rows × 30 columns — virtualized rendering
  limits in Univer OSS, WASM memory envelope, evaluate() latency, diff-queue size. Cite Univer/
  IronCalc sources or flag as measure-first.
- Failure modes: crash mid-commit (op-log replay), WebView reload (re-hydrate from GRDB +
  to_bytes snapshot), WASM OOM, formula cycles, the free-zone/record-zone conflict cases.

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

### D5 — Dataset-aware chat (no new chat — the parameterization ask on K6)
- What the KINDRED minichat needs to serve a dataset tab: focused-dataset context injection
  (schema + selection + view state into the session), `Location.surface = dataTab` presence, and
  the SAME session continuity (`sub_chats.sessionId`). Specify the context payload + size bounds.
- MAS parity: June receives the same context through agent_core — specify where that context is
  assembled natively so both drivers see one shape.

### D6 — Storage placement + KEELSTONE alignment ★ (open fork — resolve with evidence)
- WHERE does the data-core SQLite live? Options: (a) inside the vault directory (portable,
  user-visible, but exposed to third-party sync writing SQLite mid-transaction — KEELSTONE's
  nightmare); (b) app container keyed to the vault (safe, NOT portable — breaks "my vault is my
  data"); (c) vault-adjacent with explicit export/import (.reckoner package? xlsx via IronCalc?).
  Resolve with cited evidence on SQLite-under-file-sync corruption (WAL + Dropbox/iCloud), and
  define the backup/portability story either way. This is the dossier's hardest call.
- One DB per vault (datasets + op-log + views in the data core) vs folding into the EXISTING
  per-vault GRDB (KEELSTONE B4 forbids a second DERIVED db — but the data core is TRUTH, not
  derived; does the exemption hold?). Verdict + migration/teardown implications.
- Datasets in the release gate: what KEELSTONE §9 soak cases must extend to cover the data core
  (kill -9 mid-commit, sync-storm around the DB file, op-log replay equivalence).

### D7 — Ingest, agent-scoped
- v1 ingest through the agent door: CSV/xlsx (IronCalc load verified) + paste-a-table; Vision/PDF
  table extraction (canon §5, MAS-legal on-device) as a phase-2 capability. Each ingest =
  dry-run schema preview first. Define size limits + failure UX.

### D8 — Performance budgets + failure table
- Budgets (merge into `docs/perf-budgets.toml` as `[reckoner.*]`): tab-open-to-interactive,
  keystroke→repaint in-grid, evaluate() p95 at 10k/100k rows, commit latency, embed render cost
  in Epdoc, WASM resident memory. Failure table in the KEELSTONE style (detect → contain →
  recover → witness) for every D3/D6 failure mode.

### D9 — Competitive synthesis
- Cited table: Notion databases, Airtable (+AI), Obsidian Dataview/Bases, Tana, Capacities,
  AnyType, Grist — columns: truth model, agent capability, embeds, portability, offline, undo/
  provenance. End with the 3-5 moves that make RECKONER genuinely novel (leading candidate: the
  attributed, revertible, conversation-driven schema lifecycle — validate or beat it).

### D★ — Deep Fabric Integration (F1–F6) — MANDATORY (`INTEGRATION_FABRIC.md`)
- **F1 vault:** records are first-class vault objects via references; embeds live in notes;
  datasets never duplicate into markdown. **F2 capability:** RECKONER is the exemplar F2 citizen —
  one tool surface, two drivers (June/agent_core + 1Code backend), honest per-turn gating.
  **F3 presence:** `dataTab` surface; the mascot pins on the dataset it restructures
  (1Code-only). **F4 graph:** records/datasets as nodes; embed links auto-edge. **F5 provenance:**
  every structural op attributed through the shared ledger (payload-agnostic spans); "what did
  the companion change in my data this week" is answerable. **F6 state bus:** calc/refresh/commit
  states stream to all surfaces; embeds show staleness honestly.
These six briefs + this one form a **single integrated product built one plan at a time**.

## 6. Primary-source discipline
Engine facts: cite `PLAN9_ADJUDICATION_WORKING_2026_07_03.md` + the clone paths rather than
re-deriving; NEW claims about Univer/IronCalc internals need file:line from the clones or upstream
sources. External products: official docs/changelogs over blogs. SQLite-under-sync: primary
sources (sqlite.org, hictor/hazard write-ups with provenance). Observed vs inferred flagged;
version-gated capabilities carry fallbacks.

## 7. Deliverable
1. Executive thesis (the loop, boringly reliable). 2. **Agent-first lifecycle + F2 tool schema**
(D1 — longest). 3. Tab-document model + lease verdict (D2). 4. Grid seam at scale + failure
modes (D3). 5. Embed spec + liveness verdict (D4). 6. Dataset-aware chat parameterization (D5).
7. **Storage-placement verdict** (D6 — the hard call, with the KEELSTONE gate extensions).
8. Ingest (D7). 9. Budgets + failure table (D8). 10. Competitive + novel moves (D9). 11. Deep
Fabric section (D★). 12. **Phased build order** (data core → native IronCalc/UniFFI → grid seam →
tab documents → F2 tools + dry-run loop → embeds → dataset-aware chat → ingest), each phase with
a WITNESSABLE done-bar; flag dependencies (KEELSTONE 0-4; LUMENLENS L1/L5; KINDRED K6).
13. Open questions preserved (not silently resolved). 14. Self-critique + rubric scores (§3 of
the standard; iterate any axis <4).

## 8. Anti-patterns (do NOT do)
Do not resurrect the room, the docked chat panel, or five-views-v1. Do not re-litigate the
clone-verified engine keystones without new file:line evidence. No dual-compute (Univer formula
engine stays OFF). No Univer Pro, no Teable code, no server, no subprocess on MAS. No second chat
system on any build. No silent agent restructuring — every structural op previews and is
revertible. Do not absorb LUMENLENS/KINDRED scope; name their seams by ID. Do not leave the
storage-placement fork unresolved — it gets a verdict with evidence.

─── END RESEARCH BRIEF ───
