# Plan 9 — Agent-Native Data Tables: deep-research prompt (2026-07-03)

> ✅ **RESEARCH COMPLETE — this prompt has been fulfilled.** 4 dossiers returned
> (3 GPT singletons + the owner's Claude synthesis, weighted spine), adjudicated and
> clone-verified in `docs/research/PLAN9_ADJUDICATION_WORKING_2026_07_03.md`. **The
> canonical, buildable plan is [`PROMPT_PLAN_9_DATA_TABLES.md`](PROMPT_PLAN_9_DATA_TABLES.md)
> — build from THAT.** This file remains as the owner-intent frame (§0 locked decisions)
> the plan inherits.

Paste-to-external-deep-research-agent prompt. The canonical Plan 9 gets written FROM the
dossier this produces (same pattern as the OpenChamber/MAS research). Owner decisions are
locked in §0; the research validates the architecture and returns a buildable dossier with
code.

---

Research task: produce an execution dossier for **Plan 9 of Epistemos** — an
**agent-native "Data" tab**: a unified spreadsheet+database surface (Excel-grade grid +
Airtable-style views) where the user's companion agent can restructure the database by
natural-language prompt, chat about the data, and ingest structured OR unstructured input
(a photo of a receipt, a PDF, pasted messy text, a CSV) into typed records — all living in
the app's local vault, with no server and no heavy backend.

## The app / fixed environment (do not question these)
- Epistemos = a native **macOS** research/PKM app. Swift (SwiftUI + AppKit) + **Rust**
  (crate `agent_core`, exposed to Swift via **UniFFI**) + **GRDB/SQLite** for the local
  vault + a knowledge graph. Ships WKWebViews already (a Tiptap editor, KaTeX).
- **Two builds:** MAS (Mac App Store — App Sandbox + hardened runtime, **no subprocess, no
  local server binary**) and Pro (Developer ID — subprocess OK).
- **Two agent surfaces** the Data tab must work with: **MAS = "June" + `agent_core`
  in-process** (sandbox-legal, no subprocess); **Pro = OpenChamber + goose/OpenCode**.
  Both consume agent tools via an app-hosted MCP / `agent_core` tool seam.
- Keys in Keychain. On-device Apple frameworks available (Vision, PDFKit, Swift Charts,
  Foundation Models on macOS 26).

## §0 LOCKED OWNER DECISIONS (design around these; do not relitigate)
1. **Dedicated tab / room** — like the app's other tabbed features (arXiv, Browser,
   Notes). Integrated the same way. NOT buried inside the editor.
2. **Unified hybrid data model** — ONE data core; any table is viewable as an **Excel-like
   grid** OR as **Airtable views**. All of grid + **kanban + gallery + calendar + form**
   ship in v1.
3. **Core, real formula engine** — must feel like a genuine spreadsheet (hundreds of
   functions, cross-cell math like `=SUM(A1:A10)`, live recalculation). This is the main
   reason to base on IronCalc/Univer.
4. **"As native as I can get without sacrificing any functionality"** is the north star.
   The owner got burned once *forcing* nativeness on a foreign streaming web UI (the goose
   reskin). A spreadsheet is different (interactive CRUD, not streaming), but the owner is
   rightly wary. So: **native frame always; push content native as far as it goes at FULL
   functionality; fall back to a themed WKWebView surface (the app's proven editor pattern)
   only where native provably sacrifices functionality.** Map the exact native ceiling.
5. **Agent-native** (the differentiator): the companion agent can **restructure the entire
   database via prompt** (create/alter tables, fields, types, links, views; bulk
   transforms; populate); there is a **chat surface in the Data tab**; and it **ingests
   structured + unstructured data** (receipts/PDFs/pasted text/CSV) into typed records.
   This must work on **BOTH** agent builds (MAS in-process `agent_core` + Pro goose/OpenCode).
6. **No heavy server, no Postgres, no subprocess on MAS.** The "heaviness" of Teable/
   Baserow (Postgres + Django/Node servers) is replaced by the app's **embedded SQLite/
   GRDB**. That's how we supersede them without their weight.
7. **Licensing (verified):** IronCalc (MIT/Apache) and Univer (Apache-2.0 core) →
   embeddable/vendorable. Baserow **MIT core** → studyable + borrowable. **Teable is
   AGPL-3.0 → CLEAN-ROOM ONLY** (study its UX/behavior, reimplement; never port its code
   into this proprietary app). Airtable/Notion/Coda = UX reference only.

## Research questions (answer each with rigor + code)

**Q1 — IronCalc vs Univer: which is the base?** Deeply characterize BOTH (the owner has
seen IronCalc, likes its Excel look, loves that it's Rust; has NEVER seen Univer — describe
it concretely). For each: exact license; architecture (engine vs full app; what it renders
vs what's headless); formula/function coverage; grid rendering (canvas? virtualization?
100k-row perf?); views/charts; embeddability; maturity/activity. Critically for IronCalc:
**can its Rust core be compiled as a native staticlib and driven from Swift over UniFFI
(like `agent_core`) to power a NATIVE (AppKit) grid — and what is that FFI surface** (cell
model, set/get, formula eval, recalc/dirty events)? Recommend which to base the Excel-look
unified-hybrid on, with rationale. **Code:** a Swift↔IronCalc UniFFI sketch (load workbook,
set cell, read computed value, subscribe to recalc).

**Q2 — The native ceiling (the owner's #1 concern).** For EACH surface — window/tab/
toolbar chrome; the **dense editable grid**; kanban; gallery; calendar; form; the **chat**
— give a verdict: native (AppKit/SwiftUI) at full functionality, web (WKWebView + engine),
or hybrid; with functionality-parity, effort, and risk. **Stress-test the native grid
specifically:** can NSTableView / NSCollectionView / a custom Core-Animation-or-Metal grid
match Excel-grade functionality (virtualized 100k rows, frozen panes, range selection,
inline edit, copy/paste of ranges, live formula recalc)? Where exactly does native stop
matching, if it does? Produce a **per-surface native-vs-web table + a recommended
composition** honoring "native as far as full functionality allows." (First-impression
hypothesis to validate or beat: native frame + native for the simple views
kanban/gallery/calendar/form, web-engine for the dense formula grid — but prove it.)

**Q3 — Unified-hybrid data model on embedded SQLite/GRDB.** Design the schema for: typed
**tables**, **fields** with Airtable-style types (text, number, date, single/multi-select,
**link-to-another-table**, **formula**, attachment, checkbox, rating, user…), **records**,
**links** (relations), and **multiple views** (grid/kanban/gallery/calendar/form) over the
SAME records with per-view filters/sorts/grouping/field-visibility. Resolve the hard
tension of the *hybrid*: reconcile the **spreadsheet cell model** (A1 refs, ranges,
formulas) with the **typed-record model** (rows=records, typed columns) — how does a
"formula field" or a grid cell bind to IronCalc's engine? Study how Teable (Postgres) and
Baserow (Django registry pattern) model fields/views/links and reimplement on SQLite.
**Code:** the SQLite/GRDB schema (tables/fields/records/links/views) + how a formula field
routes through the engine.

**Q4 — The agent layer: natural-language DB restructuring + chat, on BOTH builds.** Define
the **agent tool/function schema** for structural ops (`create_table`, `add_field`,
`change_field_type`, `add_link`, `create_view`, `bulk_transform`, `populate_records`,
`rename`, `delete`…) that the companion calls. Because NL structural ops are **destructive**,
specify a **safety pattern: preview/dry-run → confirm → apply → undo** (schema migrations
with rollback). Show how the SAME tool surface is driven **in-process on MAS via
`agent_core` (sandbox-legal, no subprocess)** and on **Pro via goose/OpenCode** (the
app-hosted MCP). Define the **chat surface** in the Data tab (talk to/about the data;
results render as tables/edits). **Code:** the tool/function schema (JSON), the Swift/Rust
execution path, and the dry-run+undo pattern.

**Q5 — Ingest: structured + unstructured → typed records (MAS-legal).** Design the pipeline
from arbitrary input to typed records: a **receipt photo** or image → **Apple Vision
`VNRecognizeText`** on-device OCR (native, sandbox-legal) → agent structures the text into
fields; a **PDF** → PDFKit / the app's existing EdgeParse/liteparse; **CSV/JSON** → native
parse; **pasted messy text** → agent field-inference. The agent **proposes a table schema**
from unstructured input and maps values in. Preserve **provenance** (the source image/file
linked to the records it produced). Cloud OCR/parse = optional **Pro** enhancement only.
**Code:** Vision OCR → agent-structuring → record-insert (Swift), incl. field inference.

**Q6 — Deep integration (the moat).** Records as **first-class vault objects**:
agent-readable, `[[wikilink]]`-able from notes, **graph nodes/edges**. **Inline-embed** a
table/view as a block inside a note (Notion-style — the secondary surface over the same
data core). One data core, four ways in: the **tab**, the **inline block**, the **chat**,
the **agent**. Charts (Swift Charts native vs ECharts/Univer web). **Code:** the
inline-note-embed block + the vault/graph binding for a record.

**Q7 — Study donors, license-aware.** From Teable (AGPL, **clean-room**) and Baserow (MIT
core, **borrowable**): their view renderers (grid/kanban/gallery/calendar/form), field-type
systems, linked-records, filter/sort/group engines, and registry/plugin patterns — what
specifically to emulate to *supersede them without the server heaviness*. Airtable/Notion/
Coda as UX reference for the hybrid + agent + inline-DB feel.

**Q8 — MAS/Pro + verification.** Confirm the ALL-embedded stack (SQLite/GRDB + IronCalc/
Univer + native/web views + agent via `agent_core`/MCP + Vision OCR) is fully
**MAS-sandbox-legal** (no server, no subprocess, no forbidden entitlements). Confirm every
license. Flag anything that needs a server or is Pro-only. Confirm the agent DB-ops + chat
+ ingest all run in-process on the MAS June build.

## Deliverable format (be rigorous)
- Per-question **verdict tables** with a **confidence column** (verified-in-source /
  inferred / uncertain) and **citations** (official docs, GitHub repos, file-level where
  possible). Prefer primary sources; flag anything that changed 2024–2026.
- **CODE SNIPPETS at every integration seam** (the owner explicitly wants these):
  Swift↔Rust IronCalc UniFFI; the SQLite/GRDB hybrid schema; the agent tool/function schema
  + dry-run/undo execution; the Vision-OCR→structuring→insert ingest; the WKWebView grid
  host (if web); the inline-note-embed block; the vault/graph binding. Real, buildable
  sketches — not pseudocode.
- Two headline recommendations: **(a) IronCalc vs Univer — which base**, and **(b) the
  per-surface native-vs-web composition** (the native ceiling map).
- A **phased build plan** + a tight **v1 scope** (which views/fields/agent-ops ship first).
- **Open questions for the owner.**

## Critical constraints (repeat for the researcher)
- Native macOS, Swift + Rust(UniFFI) + GRDB/SQLite; two builds (MAS sandboxed / Pro
  Developer-ID); two agent surfaces (MAS June+agent_core in-process / Pro goose+OpenCode).
- **No server, no Postgres, no subprocess on MAS. Embed everything.**
- "As native as possible **without sacrificing functionality**" — map the native ceiling;
  native frame always; web only where native provably loses functionality.
- Reuse what exists: the GRDB vault, `agent_core` FFI, the proven WKWebView editor pattern,
  Apple Vision OCR, PDFKit/EdgeParse, the knowledge graph, the app-hosted-MCP/agent-tool seam.
- Licensing: IronCalc/Univer/Baserow-MIT embeddable; **Teable AGPL = clean-room only**.

## Special attention
- The **unified-hybrid modeling tension** (spreadsheet cells vs typed records) is the
  hardest design problem — want a concrete, defensible recommendation, not hand-waving.
- The **native grid ceiling** is the owner's top worry — be honest and specific about where
  native can and cannot match Excel-grade functionality.
- **Destructive NL DB ops** need a real preview/undo/rollback story.
- The agent (restructure + chat + ingest) must run **in-process on the MAS build** — verify
  each piece is sandbox-legal (esp. OCR via Apple Vision, not a cloud/subprocess dependency).
- Note anything that is genuinely Pro-only vs MAS-safe.
