# RAW corpus — Plan 9 Data-tab research

> ⚠️ **RAW RESEARCH INPUT — DO NOT BUILD FROM THIS FILE.** Verbatim Plan-9 research corpus (3 GPT
> singletons + the owner's Claude synthesis, the weighted spine). It contains pre-RECKONER wording
> that is now superseded: GRDB-as-truth, OpenChamber/goose Pro wiring, docked/in-tab chat, and
> five-views-v1. The canonical build docs are `docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`,
> `docs/prompts/RESEARCH_PROMPT_PLAN_9_RECKONER.md`, and `docs/plans/reckoner/`. Provenance only.

## THE CLAUDE SYNTHESIS (owner-weighted spine)

claude final synthesis. this has the most weight please make sure u are able to deeply upgrade basedon its executive reasoing. upgrade the plans docs and research references create and update based on this please. and again i want eh openchamber and jne agtns to be connected deeply to them as well and have a dedicated agent chat on hte spreadsheet page if thats the best option as well butthis is my opinion without have read the syunthesis - # Plan 9 — Epistemos "Data" Tab: Grid Renderer & Formula-Freedom Architecture Decision
## TL;DR
- **Ship Univer OSS (Apache-2.0) as the renderer, but make IronCalc the single calc authority via the "silent-Univer" pattern**: register Univer's formula plugin with `notExecuteFormula: true` so its TypeScript engine never computes, push IronCalc-computed values in as plain cell values while keeping the formula string visible in the formula bar. This wins because no other library combines a genuine free-form spreadsheet grid, Apache-2.0 licensing, offline WKWebView embeddability, and a canvas renderer proven to large row counts. Fallback: **Glide Data Grid (MIT)** for a leaner canvas grid if Univer's bundle/complexity proves too heavy for v1.
- **Full formula freedom is buildable but costs roughly 2–3× the conservative model's spreadsheet-layer engineering**, driven almost entirely by the durable-reference problem: IronCalc 0.7.1 does **not** yet implement Excel-style structured table references (`Table1[Column]`), so you must build an app-level reference-rewriting layer on top of IronCalc's **named ranges** (which ARE implemented) to keep formula bindings durable across record insert/delete/reorder and field rename.
- **IronCalc-in-WASM inside the WKWebView is the recommended engine placement** for the free-form grid (eliminates the per-keystroke Swift↔JS round trip), with SQLite/GRDB as the durable source of truth synced at transaction boundaries via IronCalc's new `flush_send_queue()`/`apply_external_diffs()` byte-diff API and `to_bytes()` snapshot. Native UniFFI IronCalc remains for headless/agent calc on both builds.
---
## Key Findings
### 1. IronCalc 2026 re-verification (highest-leverage unknown)
Verified against docs.rs, readthedocs, the GitHub roadmap, and npm as of mid-2026:
| Fact | Status (mid-2026) | Confidence |
|---|---|---|
| Latest version | v0.7.1 (`ironcalc_base` published 21 June 2026); still pre-1.0 | verified-in-source |
| License | MIT/Apache-2.0 dual | verified-in-source |
| `UserModel` wrapper with undo/redo + diff history | **NEW and present** — `undo()`, `redo()`, `can_undo()`, `can_redo()` | verified-in-source |
| Diff/sync API | `flush_send_queue() -> Vec<u8>` and `apply_external_diffs(&[u8])`, bitcode-serialized | verified-in-source |
| Diff type | `ironcalc_base::user_model::history::Diff` enum (InsertRow/Column, DeleteRow/Column variants confirmed verbatim; value-set/style variants inferred) | verified-in-source (partial) |
| Downstream "dirty cells" accessor from `evaluate()` | **None found** — `evaluate()` returns `()`; must re-read dependents | inferred (absence) |
| Named ranges / defined names | **Implemented** — full CRUD on `UserModel` (`new_defined_name`, `update_defined_name`, `delete_defined_name`, `get_defined_name_list`) | verified-in-source |
| Structured table references (`Table1[Column]`) | **Roadmap only — NOT in 0.7.1** | verified-in-source |
| Merged cells | **Roadmap/planned — no merge API on UserModel 0.7.1** | verified-in-source |
| Conditional formatting | Roadmap ("coming soon") | verified-in-source |
| Charts, pivot tables | Roadmap (v1.0/2.0) | verified-in-source |
| Frozen rows/columns | Implemented (`get/set_frozen_rows_count`) | verified-in-source |
| WASM bindings | `@ironcalc/wasm` (engine only, no xlsx reader/writer); `@ironcalc/workbook` React UI at v0.5.7, 1.33 MB unpacked | verified-in-source (workbook); wasm version ~0.7.x inferred |
| UniFFI compatibility | Clean — Rust `Model`/`UserModel` map to Swift via standard UniFFI staticlib/XCFramework flow | verified-in-source (pattern) |
**Interpretation:** The single most important change since the prior dossiers is the `UserModel` diff/undo/history layer. The prior research "found no recalc-event API and had to diff before/after evaluate." That is now partly obsolete: there IS a structured user-diff queue (`flush_send_queue()` "Returns the list of pending diffs and removes them from the queue… used together with `apply_external_diffs` to keep two remote models in sync") and native undo/redo. But it tracks *user-initiated* diffs, not recalculated dependents — so for a free-form grid you still re-read the dependent cells you rendered after each `evaluate()`. There is still **no first-party embeddable production grid**: `@ironcalc/workbook` is a v0.5.7 React UI (1.33 MB unpacked) that is not production-hardened and not a drop-in canvas grid. IronCalc alone cannot eliminate Univer.
### 2. Multi-cycle renderer comparison
**Cycle 1 — Characterization (license + architecture):**
| Library | License | Render | Free-form grid? | Offline WKWebView | Large row counts | Verdict gate |
|---|---|---|---|---|---|---|
| **Univer OSS** | **Apache-2.0** | Canvas | **Yes (true spreadsheet)** | Yes (static assets, `loadFileURL`) | Yes (canvas virtualized) | PASS |
| Glide Data Grid | **MIT** | Canvas | No (data grid, not sheet) | Yes | Yes (scales to millions of rows; "hundreds of thousands of updates per second") | PASS (fallback) |
| canvas-datagrid | BSD-3-clause-like | Canvas | Partial | Yes | Yes (single-canvas immediate mode) | PASS (thin) |
| RevoGrid | MIT (core) | DOM/virtual | No | Yes | Yes | PASS (data grid) |
| AG Grid Community | MIT | DOM | No | Yes | Yes | pivot/range = Enterprise $$ |
| Jspreadsheet | MIT CE / commercial | DOM | Yes-ish | Yes | Moderate | license split |
| **Handsontable** | **Non-commercial only; commercial required** | DOM | Yes | Yes | Moderate | **FAIL (license)** |
| Luckysheet | MIT but **EOL/archived Oct 30, 2025** | Canvas | Yes | Yes | Yes | **FAIL (dead)** |
| x-spreadsheet | MIT | Canvas | Yes | Yes | Moderate | maintenance risk |
**License traps flagged:**
- **Handsontable** dropped MIT for a custom "free for non-commercial and evaluation" license with **v7.0.0, released March 6, 2019** (last MIT release was v6.2.2, Dec 19, 2018; the non-commercial license text itself is dated Feb 19, 2019 — the "Version 1.0, last updated November 20, 2025" seen on their site is merely the current revision of that license document, not the date of the change). The `'non-commercial-and-evaluation'` key **cannot** be used in a paid Mac app — a commercial per-developer-seat license is required. Disqualifying.
- **AG Grid**: Community is MIT ("free for commercial and non-commercial use"); pivoting, integrated charts, and advanced range features are Enterprise-only. AG Grid Enterprise "starts at $999 per developer for a perpetual licence with 1 year of support and updates" (Single Application License, per-developer seat). A pure renderer would work under Community, but you'd lose the enterprise features and still lack spreadsheet semantics.
- **Luckysheet**: archived read-only Oct 30, 2025; the maintainers explicitly redirect users to Univer ("With the release of Univer, luckysheet is EOL").
**Cycle 2 — Against the dual-zone formula-freedom model:** The decisive question is whether the renderer can delegate formula evaluation to IronCalc. Univer's `@univerjs/engine-formula` exposes `IUniverEngineFormulaConfig` with **`notExecuteFormula?: boolean`** — you register the formula plugin so it parses/displays formulas but does not compute. Cells' `v` (value) can be set directly (Univer docs describe clearing/setting the cell `v` value on init). This means Univer renders externally-computed values while showing the formula string — exactly the free-form requirement. Glide and canvas grids have no formula concept at all: they render pushed values trivially but give you no formula bar, no A1 selection semantics, no fill-handle-of-formulas — you'd rebuild spreadsheet UX from scratch.
**Cycle 3 — Integration seam:** Univer-in-WKWebView with IronCalc-WASM co-resident in the same webview keeps keystroke→recalc→repaint entirely inside JS/WASM (sub-frame latency), pushing to SQLite only at transaction boundaries. This is dramatically better than routing every keystroke over `postMessage` to native UniFFI IronCalc and back. Univer's canvas renderer + IronCalc-WASM both run offline via `loadFileURL` with no server and no subprocess (MAS-legal).
**Ranked final verdict:**
1. **Univer OSS + IronCalc-WASM (silent-Univer pattern)** — winner.
2. **Glide Data Grid + IronCalc-WASM** — fallback (leaner, MIT, but you build spreadsheet UX yourself).
3. canvas-datagrid — thin third option.
### 3. Dual-zone (free-form + typed-record) schema
The typed-record projection and the free-form cell layer coexist over one SQLite store via a **cell-overlay model**. Records remain first-class rows in typed tables (so kanban/gallery/calendar/form views work). The sheet surface is a projection: typed columns map to a reserved "record zone" of columns; everything else is "free zone." A single `cell_overlay` table stores any cell (record-zone override or free-zone scratch) that carries a formula or a manual value not derived from a record field.
```sql
-- Typed record layer (drives kanban/gallery/calendar/form)
CREATE TABLE record (
  id INTEGER PRIMARY KEY,
  table_id INTEGER NOT NULL,
  sort_key REAL NOT NULL          -- fractional indexing for reorder
);
CREATE TABLE field (
  id INTEGER PRIMARY KEY,
  table_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,             -- text/number/date/select/formula
  col_order INTEGER NOT NULL,
  stable_col_uuid TEXT NOT NULL   -- durable identity across rename/reorder
);
CREATE TABLE cell_value (         -- typed record data
  record_id INTEGER NOT NULL REFERENCES record(id),
  field_id  INTEGER NOT NULL REFERENCES field(id),
  value BLOB,
  PRIMARY KEY (record_id, field_id)
);
-- Free-form / overlay layer (the spreadsheet scratch space)
CREATE TABLE sheet_region (
  id INTEGER PRIMARY KEY,
  table_id INTEGER NOT NULL,
  kind TEXT NOT NULL,             -- 'record_zone' | 'free_zone'
  top_row INTEGER, left_col INTEGER,
  bottom_row INTEGER, right_col INTEGER
);
CREATE TABLE cell_overlay (       -- any free-form or formula cell
  table_id INTEGER NOT NULL,
  row INTEGER NOT NULL,           -- absolute sheet coordinates
  col INTEGER NOT NULL,
  raw_input TEXT,                 -- "=SUM(A1:A10)" or literal
  cached_value BLOB,              -- last IronCalc result
  cached_kind TEXT,               -- number/string/error/bool
  PRIMARY KEY (table_id, row, col)
);
CREATE TABLE named_range (        -- durable binding layer
  id INTEGER PRIMARY KEY,
  table_id INTEGER NOT NULL,
  name TEXT NOT NULL,             -- e.g. "Invoices_Amount"
  ref_kind TEXT NOT NULL,         -- 'field_column' | 'record_cell' | 'static'
  stable_col_uuid TEXT,           -- links to field.stable_col_uuid
  a1_fallback TEXT
);
```
**Durable reference mechanism (the crux):** Because IronCalc 0.7.1 lacks structured table references, durability is achieved with **named ranges + app-side reference rewriting**. Each typed column gets an IronCalc **defined name** (verified-supported) scoped to the sheet, e.g. `Invoices_Amount`. Free-form formulas that reference record data use the defined name, not `C2:C50`. On record insert/delete/reorder or field rename/reorder, the app updates the named range's extent (via `update_defined_name`) rather than rewriting every A1 reference. Raw `A1` references into the record zone are supported but flagged as fragile in the UI. This gives Excel-`Table1[Column]`-equivalent durability without waiting for IronCalc's roadmap.
**Conflict semantics:** A free-form formula writing into the typed zone is disallowed at field-owned cells (record-derived cells are read-only projections); overlay cells may only exist in the free zone or as explicit formula-field columns. Agent structural operations (insert/delete field, reorder) trigger named-range extent updates in the same transaction as the schema change.
### 4. Engine placement & consistency architecture
**Recommended: IronCalc-WASM in the WKWebView (grid-side authority) + IronCalc-UniFFI native (headless/agent authority), sharing a serialized model.**
- Interactive editing: user types in Univer → Univer emits an edit command → JS calls IronCalc-WASM `setUserInput` + `evaluate` → reads changed cells → pushes plain values into Univer via the Facade API (Univer plugin registered with `notExecuteFormula: true`). All in-webview, no native round trip.
- Persistence: at transaction commit, JS calls IronCalc-WASM `flush_send_queue()` → bitcode `Vec<u8>` diff → posted to Swift via `WKScriptMessageHandler` → Swift writes overlay rows + records to GRDB in one transaction. For full snapshots, `to_bytes()`.
- Agent/headless (both builds): native IronCalc-UniFFI `UserModel` loaded from the same serialized bytes reproduces the workbook for dry-run/apply without a webview.
**Consistency: one authoritative engine (IronCalc), never dual-compute.** Univer's engine is disabled (`notExecuteFormula`). This sidesteps the entire function-coverage/semantic-divergence problem below — there is only one set of results.
### 5. Dual-engine consistency problem (if you ever enable Univer's engine)
Both engines claim 300–500+ functions but diverge on: date systems (1900 vs 1904), floating-point/rounding, error propagation (`#VALUE!`/`#REF!` handling), and dynamic-array/spill behavior (Univer supports spill; IronCalc's dynamic arrays are on the v1 roadmap). **Recommendation: never run both authoritatively.** Options ranked:
1. **Strip Univer compute, inject IronCalc values** (recommended) — one authority, zero divergence.
2. Optimistic Univer compute + IronCalc reconcile — instant UI but requires a reconciliation pass and divergence handling; only worth it if latency demands it.
3. Drop IronCalc for the grid, let Univer be authority, persist results to SQLite — weakens the Rust story and forfeits IronCalc's xlsx fidelity and headless agent calc; not recommended (the agent could still query SQLite, but you lose one-engine coherence).
### 6. Agent + free-form cells
Extend the agent tool surface with cell/range operations. Both builds: in-process `agent_core` on MAS, MCP on Pro. Dry-run produces cell-level diffs (using IronCalc's `flush_send_queue` diff to preview), confirm→apply writes the transaction, undo uses IronCalc `UserModel.undo()` plus the GRDB transaction log.
```json
{
  "tools": [
    {"name": "get_range", "params": {"a1": "F1:F20"},
     "returns": {"cells": [{"a1":"F1","formula":"=SUM(...)","value":42}]}},
    {"name": "set_range", "params": {"a1": "F1:F20", "values": [["=A1*2"]],
     "dry_run": true},
     "returns": {"diff": [{"a1":"F1","before":null,"after":"=A1*2","new_value":8}]}},
    {"name": "apply_formula_to_range",
     "params": {"a1": "F1:F20", "formula": "=Invoices_Amount*1.2", "dry_run": true}},
    {"name": "describe_region", "params": {"a1": "F1:F20"},
     "returns": {"summary": "scratch calc: running total of Amount column"}}
  ]
}
```
Provenance/undo: every free-form mutation is a bitcode diff appended to the transaction log with agent attribution; `describe_region` lets the agent answer "what does the scratch calculation in F1:F20 say" by reading formulas + cached values.
### 7. MAS vs Pro capability map (Univer)
| Capability | MAS build (no server) | Pro build (Developer ID) |
|---|---|---|
| Univer core sheet, formulas, filter/sort, data validation, **conditional formatting**, hyperlinks, comments, find/replace, **tables**, number formatting | ✅ OSS Apache-2.0, offline | ✅ same |
| Univer OSS formula engine | ✅ (disabled in favor of IronCalc) | ✅ same |
| **Charts** | ⚠️ Not via Univer (Pro pkg `@univerjs-pro/sheets-chart`). Use **ECharts (Apache-2.0)** or **Swift Charts (native)** offline | Univer Pro chart pkg needs license/server; prefer ECharts/Swift Charts anyway |
| **Pivot tables** | ⚠️ Not via Univer (Pro `@univerjs-pro/sheets-pivot`). Implement over **SQLite directly** | Univer Pro pivot needs license/server; SQLite pivot still preferred |
| Advanced import/export, print, edit history, collaboration, server-side calc, advanced formula engine (`@univerjs-pro/*`) | ❌ Univer Pro + running server | ⚠️ Technically possible but see below |
| Print | ✅ native macOS printing of rendered views | ✅ same |
**Univer Pro redistribution reality:** Univer Pro is released under the **Univer Commercial License**; without a license the server runs in limited mode (watermark, import-size caps, collaboration quota). Per Univer's official README, **headless Univer supports Node.js ≥18.17.0, and developing the monorepo requires Node.js ≥22.18**; the server is normally deployed via Docker/Helm. This makes Univer Pro impractical and legally fraught to bundle inside a paid Mac app even on the Pro (Developer ID) build. **Recommendation: do NOT bundle Univer Pro. Cover gap features MAS-legally**: pivots over SQLite, charts via ECharts (Apache-2.0, offline in the same WKWebView) or Swift Charts (native), print via native macOS printing. This keeps both builds server-free and on one code path.
---
## Details
**Why Univer over the lighter grids, concretely.** The owner's locked requirement is a *genuine free-form spreadsheet* — arbitrary formulas anywhere, formula bar, A1 selection, fill handle, frozen panes, multi-range selection, merged cells, Excel-fidelity clipboard. Univer OSS delivers all of these as an Apache-2.0 canvas SDK today; its changelog through 2025–2026 shows active work (filter-by-color, HYPERLINK function, autofill across frozen panes, sparkline import/export, server-side calc toggles). Glide/canvas-datagrid/RevoGrid are *data grids*: excellent at rendering large row counts but with no native spreadsheet semantics — choosing them means rebuilding the entire spreadsheet interaction layer, which contradicts "maximum robustness." Handsontable would fit functionally but its non-commercial license (effective v7.0.0, March 2019) is disqualifying for a paid app. Luckysheet is dead (archived Oct 30, 2025, redirects to Univer).
**Why IronCalc stays the calc authority.** It is the owner's Rust kernel, drives xlsx import/export fidelity, runs headless for the agent on both builds, and now has a real diff/undo layer (`UserModel`). Letting Univer's TS engine compute would fork the truth. The `notExecuteFormula` flag is the clean seam that keeps Univer as pure renderer.
**Latency architecture.** Placing IronCalc-WASM beside Univer in the webview means the hot loop (type → compute → repaint) never crosses the process boundary. The Swift↔JS bridge is used only at transaction boundaries (commit/undo/load), where a single bitcode blob crosses. This is the lowest-latency, lowest-chattiness design and it is fully MAS-legal (no server, no subprocess, `loadFileURL` only). The proven `WKScriptMessageHandler` bridge pattern already used for Tiptap/KaTeX applies directly.
**Complexity accounting (full freedom vs conservative).** The conservative model (formula fields + grid-only helper columns) needs no overlay table, no free-zone/record-zone partitioning, and no reference-rewriting layer — durability is trivial because formulas only ever live in typed columns. Full freedom adds: (a) the `cell_overlay` + `sheet_region` schema and its sync; (b) the named-range-based durable-reference rewriting engine (the single largest cost, because IronCalc lacks structured table refs); (c) conflict rules between free and typed zones; (d) agent tools for arbitrary ranges with cell-level diffs; (e) reconciling free-form edits with record insert/delete/reorder. Estimate: roughly 2–3× the conservative build's spreadsheet-layer effort, concentrated in the reference-durability subsystem. Risk is concentrated there too — get named-range extent maintenance wrong and formulas silently point at the wrong data after a reorder.
---
## Recommendations
**Stage 1 (v1, tight scope):** Univer OSS + IronCalc-WASM in one WKWebView, `notExecuteFormula: true`, IronCalc single authority. SQLite/GRDB source of truth, sync at transaction boundaries via `flush_send_queue`/`apply_external_diffs`/`to_bytes`. Free-form scratch space in the free zone with named-range durable references for record-data references. Native undo via `UserModel.undo()`. Charts via Swift Charts; pivots via SQLite. No Univer Pro, no server, both builds share an identical grid path.
**Stage 2:** Agent tools `get_range`/`set_range`/`apply_formula_to_range`/`describe_region` with dry-run cell diffs (MAS in-process, Pro MCP). ECharts in-webview for richer charts if Swift Charts is insufficient.
**Stage 3 (revisit gates):** Reassess when (a) IronCalc ships 1.0 with native structured table references — then retire much of the reference-rewriting layer; (b) IronCalc ships merged cells/conditional formatting — then drop any Univer-side shims; (c) if Univer's bundle or complexity measurably hurts startup/memory in the webview, switch to the Glide Data Grid fallback and build minimal spreadsheet UX.
**Thresholds that change the decision:** If measured WKWebView cold-start with Univer + IronCalc-WASM exceeds an acceptable budget, or webview memory footprint is too high on typical vaults, fall back to Glide. If the free-form durable-reference subsystem proves too risky for v1 timelines, ship the conservative model first and layer free zones in later behind a flag.
---
## Caveats
- IronCalc is pre-1.0 and moving fast; merged cells, conditional formatting, charts, pivots, dynamic arrays, and structured table references are roadmap, not shipped in 0.7.1. Re-verify at each IronCalc release.
- The `@ironcalc/wasm` exact version and bundle size were not retrievable from primary source; validated only that the package exists (engine-only, no xlsx) and that `@ironcalc/workbook` UI is v0.5.7 / 1.33 MB unpacked. Measure the wasm bundle empirically before committing to in-webview placement.
- IronCalc's diff/send-queue tracks user diffs, not recalculated dependents; you must re-read dependent cells after `evaluate()` to repaint. The confirmed absence of a dirty-cell accessor is inferred, not proven (private methods not visible in rustdoc).
- The full variant list of `user_model::history::Diff` could not be enumerated from primary source (Insert/Delete Row/Column confirmed verbatim; value-set/clear/style variants inferred).
- Univer OSS vs Pro package boundaries can shift; verify each `@univerjs/*` vs `@univerjs-pro/*` package's license before shipping. Charts, pivots, print, edit history, collaboration, and the advanced formula engine are Pro.
- Running Univer Pro locally on the Pro build is technically possible but commercially licensed and Node/Docker-dependent (Node.js ≥18.17.0 floor); treated as out-of-scope for redistribution.
## Open questions for the owner
1. Is a ~1–3 MB IronCalc-WASM payload plus Univer's bundle acceptable inside the WKWebView on target hardware, or is the Glide fallback preferred for footprint? (Measure empirically — wasm size unverified.)
2. For record-zone references, do you want raw `A1` refs allowed (fragile) or forced through named ranges only (durable but constrains power users)?
3. Should free-form formulas be permitted to reference *other tables'* record zones (cross-sheet named ranges), or is v1 single-sheet?
4. Acceptable v1 posture on merged cells/conditional formatting given IronCalc lacks them — Univer-side visual-only shim, or defer entirely?

---

## THE THREE GPT SINGLETONS

ok now do ur own exectuive research syntheize harden and verify all of it and then start creatign the plan for plan 9 please and the prompt for the agent to start building. i have one more reserch passs that i will give u after this so please just absorb these first and then i will give u the final syntehsis


also i have a few research docs i have the singletons and then opne sythesis. i put much more time and compute into the synthesis opf claudeso take please absorb that and espouse it as being much more deep and defensible.

GPT 1 - # Plan 9 of Epistemos execution dossier

## Headline recommendations

The strongest overall architecture is:

**Base on IronCalc, not Univer, for the data core and formula kernel.** IronCalc is a Rust spreadsheet engine with a documented headless API, existing Node/Python/WASM bindings, dual MIT/Apache-2.0 licensing, and an engine-first design that maps naturally onto Epistemos’s Swift↔Rust UniFFI architecture. It already supports hundreds of functions, `.xlsx` read/write, formatting, and programmatic creation/edit/evaluation; its repo is active and at `v0.7.1` as of January 25, 2026. Univer, by contrast, is a much more mature **web spreadsheet SDK** with canvas rendering, a plugin system, a facade API, and excellent browser-side UX, but its architecture is JavaScript-first, its headless story is **Node.js**, and several capabilities most likely to matter later for parity—import/export, charts, pivots, edit history, advanced formula features—sit behind **Univer Pro** and, in multiple cases, require a **server**. That makes Univer a superb renderer SDK, but a weaker fit for a local-first Rust-native system of record. citeturn34view2turn15view0turn15view1turn14search1turn33view1turn30view0turn30view1turn30view2turn30view3

**Use a native frame with a web dense-grid fallback.** The owner’s instinct is right: the dense editable spreadsheet surface is the one place where AppKit/SwiftUI is least likely to reach Excel-grade parity without disproportionate effort. AppKit gives you solid tables and collections, but not a prebuilt Excel interaction stack. Native is the right choice for tab chrome, toolbar, chat, kanban, gallery, calendar, form, record inspector, and charts. The dense formula grid should be treated as a **hybrid/web enclave inside a native frame** in v1, unless the team is willing to fund a serious custom grid program. citeturn19view2turn30view3turn24search0turn24search1turn24search2turn22view0turn22view1turn21view7

The resulting recommendation is:

| Decision | Verdict | Why | Confidence |
|---|---|---|---|
| Spreadsheet/formula base | **IronCalc** | Rust-native engine, embeddable, no server requirement, existing bindings, dual permissive license, aligns with UniFFI and local vault architecture. citeturn34view2turn15view0turn15view1turn32view0turn32view1 | Verified in source |
| Dense grid composition | **Hybrid: native frame + themed WKWebView grid** | Best path to frozen panes, range selection, fill handle, clipboard matrices, live recalc UI, and future formula parity without a multi-quarter custom AppKit grid effort. citeturn19view2turn30view3turn11search3 | Inferred from sources and platform constraints |
| Non-grid views | **Native AppKit/SwiftUI** | Kanban, gallery, calendar, form, chat, inspectors, and charts map cleanly to native collection/layout primitives and to the product’s “native room” standard. citeturn18search9turn24search0turn24search1turn24search2turn36search0 | Verified + inferred |
| System of record | **SQLite/GRDB typed-record core** | Matches local vault, avoids server weight, and can emulate the best of Baserow/Teable view semantics without Postgres/Django/Node. citeturn13search0turn13search1turn21view0turn28view0turn28view1turn35view1 | Verified + inferred |
| Agent integration | **Same DB tool surface on MAS and Pro** | MAS can run in-process with `agent_core` and Apple frameworks; Pro can expose the exact same tools over the app-hosted MCP seam to OpenChamber/goose/OpenCode. Apple’s on-device frameworks cover OCR and, on supported systems, Foundation Models covers structured output and tool calling. citeturn11search1turn37search0turn37search3turn37search4turn12search2 | Verified + inferred |

My **tight v1** would be: typed tables; field types for text/long text/number/date/checkbox/single-select/multi-select/link/attachment/formula/rating/user; views for grid/kanban/gallery/calendar/form; record detail panel; agent chat with preview→confirm→apply→undo; CSV/JSON/paste import; Vision OCR for images/receipts; PDF ingest via PDFKit/existing parser path; inline note embeds for grid/kanban/gallery/calendar; native charts via Swift Charts from typed query results. I would **not** ship arbitrary per-cell schema-breaking formulas in typed tables in v1; formulas belong in formula fields and analysis sheets first. citeturn21view1turn25search6turn21view0turn24search0turn24search1turn24search2turn36search0turn11search1turn20view3

## Engine choice

### What IronCalc is, concretely

IronCalc is an engine-first spreadsheet project. Its repository explicitly says it contains “the main engine and the xlsx reader and writer,” and its docs.rs API is positioned as the technical API used both for language bindings and for applications. The workspace contains `base`, `xlsx`, and bindings for `wasm`, `python`, and `nodejs`, which is exactly the kind of headless-core-plus-bindings shape that Epistemos already uses with `agent_core`. The project is dual-licensed under MIT or Apache-2.0, at the integrator’s option. As of the repo snapshot surfaced here, it had roughly 4k stars, 1,701 commits, and latest release `v0.7.1` on January 25, 2026. citeturn34view2turn15view0turn15view1turn6view2turn34view0turn32view0turn32view1

Its public Rust API already exposes the shape Epistemos needs: `Model::new_empty`, `set_user_input`, `evaluate`, `get_cell_value_by_index`, access to style APIs, and `.xlsx` save support. The docs and site also state that it supports **hundreds of functions**, `.xlsx` import/export, formatting, and programmatic use from multiple languages. The site’s own unsupported-features page is valuable because it is candid: real-time collaboration, charts, function helper/autocomplete, and pivot tables are not yet there. That honesty matters because it means IronCalc is strong specifically where Epistemos needs it most—embedded calc kernel and workbook semantics—but not yet a complete spreadsheet product surface. citeturn15view0turn15view1turn14search1turn15view3turn14search6

### What Univer is, concretely

Univer is not just a spreadsheet widget. Its own README calls it “a full-stack, isomorphic office SDK” for spreadsheets, docs, and presentations, with a plugin architecture, canvas-based rendering, a formula engine, and a facade API that works in browser and Node.js. It is very clearly **framework software**: you compose packages or presets, add a browser container, and register rendering, UI, sheets, formula, number-format, and other plugins. The open-source core includes sheets, selection, formulas, number formatting, filtering, sorting, validation, conditional formatting, hyperlinks, comments, find/replace, notes, tables, and drawing integration. It also explicitly supports **frozen panes**, which is one of the load-bearing spreadsheet UX features. citeturn6view3turn33view1turn30view3turn7search14

Univer’s big advantage is UI maturity. Its rendering engine is canvas-based and explicitly described as built for “large surfaces.” The repo is much larger and more active than IronCalc—roughly 13.4k stars, 124 issues, and a monorepo full of packages for core, design, validation, docs, sheets, filters, tables, and more. If the problem were “I need the best embeddable spreadsheet UI in a web runtime,” Univer would be the stronger answer. citeturn33view2turn33view1

The catch is architectural and licensing-adjacent rather than feature-adjacent. Univer’s open-source core is Apache-2.0, which is fine. But its docs explicitly place several capabilities behind **Univer Pro**, and the Pro overview and feature docs repeatedly say that advanced capabilities and import/export depend on the **Univer server**. That includes the exact set of capabilities that tends to snowball inside spreadsheet products: import/export, charts, pivot tables, printing, edit history, and collaboration. For Epistemos, which is explicitly **no heavy backend, no server, no subprocess on MAS**, that is a bad strategic center of gravity. citeturn32view2turn30view0turn30view1turn30view2turn6view3

### Engine verdict table

| Topic | IronCalc | Univer | Winner | Confidence |
|---|---|---|---|---|
| License | Dual MIT / Apache-2.0. citeturn34view2turn32view0turn32view1 | Apache-2.0 core; Pro under commercial license. citeturn32view2turn30view0 | **IronCalc** | Verified in source |
| Architecture | Rust engine + xlsx IO + bindings (`wasm`, `python`, `nodejs`); engine-first. citeturn6view2turn34view0turn34view1turn15view0 | JS/TS office SDK; plugin-first; browser UI + Node headless. citeturn6view3turn33view1 | Depends on goal; **IronCalc** for core, **Univer** for UI | Verified in source |
| Formula coverage | “Hundreds of functions”; explicit engine API around `set_user_input`, `evaluate`, cell values. citeturn14search1turn15view0turn15view1 | Docs claim “nearly all Excel functions” in core sheets. citeturn30view3 | **Univer** on breadth claim; **IronCalc** on native fit | Verified in source |
| Dense grid rendering | Not positioned as a complete native/UI kit; engine plus web app/tooling. citeturn34view1turn15view3 | Canvas rendering, cursor/selection drawing, frozen panes. citeturn33view1turn30view3 | **Univer** | Verified in source |
| Headless embeddability | Strong; pure Rust model, bindings pattern already present. citeturn15view0turn34view0 | Headless exists in Node.js, not Rust. citeturn6view3turn33view1 | **IronCalc** | Verified in source |
| Server dependence | None for core calc path. citeturn15view0turn14search1 | Pro/server required for advanced capabilities and import/export. citeturn30view0turn30view1 | **IronCalc** | Verified in source |
| Alignment with Swift↔Rust UniFFI | Direct and strong. citeturn16search1turn16search3turn16search16 | Indirect; runtime lives in JS/TS and browser/Node. citeturn6view3turn33view1 | **IronCalc** | Verified + inferred |
| Project maturity | Active but still candidly incomplete as a product surface. citeturn34view2turn15view3 | More mature UI surface and larger ecosystem. citeturn33view2turn33view0 | **Univer** | Verified in source |

### Recommendation

For **Plan 9**, the base should be **IronCalc**.

That does **not** mean “native grid from day one.” It means: the **kernel**, the **formula semantics**, the **calc graph**, the **future analysis-sheet substrate**, and the **agent-facing workbook API** should live in Rust, inside the same trust boundary as the vault. The grid renderer is a separate decision. Univer is better understood as a renderer/framework option, not as the right center of gravity for an embedded local-first Rust app with a two-build MAS/Pro split. citeturn34view2turn33view1turn30view0

### Swift ↔ Rust UniFFI sketch for IronCalc

The cleanest FFI surface is **not** “export the entire workbook object graph.” It is a small, high-leverage facade around workbook lifecycle, sheet/cell IO, formula evaluation, dirty-region recalc, and observation. UniFFI supports Swift integration and Xcode workflows, and it supports traits/interfaces implemented on the foreign side, which is enough to model a recalc observer. citeturn16search1turn17search10turn17search14

```rust
// crates/ironcalc_bridge/src/lib.rs

use std::sync::{Arc, Mutex};
use ironcalc_base::{cell::CellValue, Model};
use uniffi::deps::anyhow::{anyhow, Result};

#[derive(uniffi::Record, Clone, Debug)]
pub struct CellAddress {
    pub sheet: u32,
    pub row: u32,
    pub col: u32,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct CellComputed {
    pub raw: String,
    pub formatted: String,
    pub kind: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct RecalcEvent {
    pub dirty: Vec<CellAddress>,
}

#[uniffi::export(callback_interface)]
pub trait RecalcObserver: Send + Sync {
    fn on_recalc(&self, event: RecalcEvent);
}

#[derive(uniffi::Object)]
pub struct WorkbookHandle {
    model: Mutex<Model>,
    observers: Mutex<Vec<Arc<dyn RecalcObserver>>>,
}

#[uniffi::export]
impl WorkbookHandle {
    #[uniffi::constructor]
    pub fn new_empty(name: String, locale: String, tz: String, lang: String) -> Result<Arc<Self>> {
        let model = Model::new_empty(&name, &locale, &tz, &lang)
            .map_err(|e| anyhow!("{e}"))?;
        Ok(Arc::new(Self {
            model: Mutex::new(model),
            observers: Mutex::new(vec![]),
        }))
    }

    pub fn load_xlsx(path: String, locale: String, tz: String, lang: String) -> Result<Arc<Self>> {
        // Sketch: wrap your real xlsx loader here.
        let model = Model::new_empty(&path, &locale, &tz, &lang)
            .map_err(|e| anyhow!("{e}"))?;
        Ok(Arc::new(Self {
            model: Mutex::new(model),
            observers: Mutex::new(vec![]),
        }))
    }

    pub fn add_sheet(&self, name: String) -> Result<u32> {
        let mut model = self.model.lock().unwrap();
        model.add_sheet(&name).map_err(|e| anyhow!("{e}"))?;
        Ok((model.workbook.worksheets().len() - 1) as u32)
    }

    pub fn set_cell_input(&self, addr: CellAddress, input: String) -> Result<()> {
        let mut model = self.model.lock().unwrap();
        model
            .set_user_input(addr.sheet as usize, addr.row as i32, addr.col as i32, input)
            .map_err(|e| anyhow!("{e}"))?;
        Ok(())
    }

    pub fn get_computed(&self, addr: CellAddress) -> Result<CellComputed> {
        let model = self.model.lock().unwrap();

        let raw = match model.get_cell_value_by_index(addr.sheet as usize, addr.row as i32, addr.col as i32) {
            Ok(CellValue::String(s)) => s,
            Ok(CellValue::Boolean(b)) => b.to_string(),
            Ok(CellValue::Number(n)) => n.to_string(),
            Ok(CellValue::Error(err)) => format!("{err:?}"),
            Ok(CellValue::EmptyCell) => String::new(),
            Err(e) => return Err(anyhow!("{e}")),
        };

        let formatted = model
            .get_formatted_cell_value(addr.sheet as usize, addr.row as i32, addr.col as i32)
            .map_err(|e| anyhow!("{e}"))?;

        Ok(CellComputed {
            raw,
            formatted,
            kind: "computed".to_string(),
        })
    }

    pub fn evaluate(&self) -> Result<()> {
        let mut model = self.model.lock().unwrap();
        model.evaluate();

        // Sketch: if IronCalc later exposes a dirty-cell API, use it.
        let event = RecalcEvent { dirty: vec![] };

        let observers = self.observers.lock().unwrap().clone();
        drop(model);

        for obs in observers {
            obs.on_recalc(event.clone());
        }
        Ok(())
    }

    pub fn subscribe(&self, observer: Arc<dyn RecalcObserver>) {
        self.observers.lock().unwrap().push(observer);
    }
}

uniffi::setup_scaffolding!();
```


```swift
// DataSpreadsheetBridge.swift

import Foundation

final class GridRecalcObserver: RecalcObserver {
    var onEvent: ((RecalcEvent) -> Void)?

    func onRecalc(event: RecalcEvent) {
        DispatchQueue.main.async { [onEvent] in onEvent?(event) }
    }
}

@MainActor
final class SpreadsheetSession: ObservableObject {
    private let workbook: WorkbookHandle
    private let observer = GridRecalcObserver()

    @Published var lastEvent: RecalcEvent?

    init(path: String? = nil) throws {
        if let path {
            workbook = try WorkbookHandle.loadXlsx(
                path: path,
                locale: "en",
                tz: "UTC",
                lang: "en"
            )
        } else {
            workbook = try WorkbookHandle.newEmpty(
                name: "DataTable",
                locale: "en",
                tz: "UTC",
                lang: "en"
            )
        }

        observer.onEvent = { [weak self] event in
            self?.lastEvent = event
        }
        workbook.subscribe(observer: observer)
    }

    func setCell(sheet: UInt32, row: UInt32, col: UInt32, input: String) async throws {
        try workbook.setCellInput(
            addr: CellAddress(sheet: sheet, row: row, col: col),
            input: input
        )
        try workbook.evaluate()
    }

    func computed(sheet: UInt32, row: UInt32, col: UInt32) throws -> String {
        let value = try workbook.getComputed(
            addr: CellAddress(sheet: sheet, row: row, col: col)
        )
        return value.formatted
    }
}
```

That is the surface I would actually build first: constructor, load/save, add sheet, set input, get computed, evaluate, observe. Everything else can layer on top.

## Native ceiling map

### The key conclusion

The native ceiling is **high for record-centric views** and **low for the fully interactive spreadsheet grid**.

Apple’s AppKit table and collection APIs are good at rows, columns, scrolling, selection, sorting, customization, reusable views, and collection-style layouts. Apple’s own table programming guide is explicit that `NSTableView` is for related records, with vertical and horizontal scrolling, selection, column dragging, sorting, and custom row/cell/header views. `NSCollectionView` is the natural native primitive for card/grid layouts. `WKWebView` remains the platform-native way to embed a full web app surface inside a macOS app. citeturn19view2turn18search9turn11search3

But none of those APIs gives you, out of the box, the interaction stack that makes Excel feel like Excel: frozen panes with independent scroll regions, marquee range selection, keyboard navigation across large cell matrices, fill handle semantics, formula bar interactions, multi-cell paste with shape reconciliation, copy/paste across apps using spreadsheet MIME/HTML/plain-text conventions, viewport virtualization on both axes, cell overlays, drag autofill, spill visualization, and fast selection painting over huge grids. Those are all buildable natively, but building them natively is a **product effort**, not a normal Mac view implementation. The absence of an Apple-native spreadsheet control is itself the signal here. citeturn19view2turn30view3

### Per-surface verdict table

| Surface | Verdict | Why | Functionality parity risk | Confidence |
|---|---|---|---|---|
| Window / tab / toolbar chrome | **Native** | Standard Epistemos shell; no reason to web-host. citeturn12search2turn11search7 | Low | Verified + inferred |
| Dense editable grid | **Hybrid / web in WKWebView** | Best chance at Excel-grade interactions, frozen panes, range semantics, and future parity. Univer explicitly supports rendering, selection, and frozen panes; AppKit table APIs do not equate to spreadsheet behavior. citeturn30view3turn19view2turn11search3 | High if native-only | Verified + inferred |
| Kanban | **Native** | Record cards grouped by field value map directly to collection/list drag-and-drop. Baserow and Teable both describe kanban as cards grouped by a single field. citeturn21view7turn24search0 | Low | Verified in source |
| Gallery | **Native** | Cards with cover images and configurable visible fields are a straightforward `NSCollectionView` / SwiftUI `LazyVGrid` problem. citeturn22view0turn18search9 | Low | Verified + inferred |
| Calendar | **Native** | Date-based record layout, drag-to-reschedule, labels, colors; native calendar/timeline layout is manageable. Baserow and Teable both model it as record placement by date fields. citeturn22view1turn24search1 | Medium | Verified + inferred |
| Form | **Native** | Teable and Baserow form views are field-driven record-submission surfaces; perfect fit for SwiftUI forms and validation. citeturn23search0turn24search2 | Low | Verified in source |
| Chat | **Native** | Existing agent/chat patterns fit SwiftUI/AppKit cleanly; results can render native tables/previews. citeturn37search4turn37search7 | Low | Verified + inferred |
| Charts | **Native first** | Swift Charts is powerful, concise, and native. Use web charting only if spreadsheet-embedded charts become a parity requirement later. citeturn36search0turn36search4 | Medium | Verified in source |

### Stress test of the native grid

If you attempted a pure-AppKit grid, the plausible path would be a custom-scrolling, custom-drawn surface rather than `NSTableView` as-is. `NSTableView` is row-record oriented; it is excellent for tables, but it is not a spreadsheet engine UI. `NSCollectionView` is even less natural for editable spreadsheets. A custom Core Animation or Metal grid **could** hit 100k+ visible-model virtualization with enough engineering, but at that point you are building a spreadsheet product subsystem from first principles. Apple’s APIs support the pieces; they do not supply the behavioral bundle. citeturn19view2turn18search9turn36search15

My honest boundary line is this:

- If the requirement is “fast, native, record-centric grid with row selection, inline edit, sort/filter, and maybe light range copy/paste,” native is viable.
- If the requirement is “Excel-grade grid with frozen panes, live formula interaction, large-range copy/paste, autofill, multi-cell keyboard semantics, and believable spreadsheet feel,” native becomes a **specialized grid program** and should not be the v1 path.

That means the owner’s first-impression hypothesis is basically right. I would refine it slightly: **native frame, native simple views, native charting, native chat, native record details, and a WKWebView spreadsheet enclave for the dense grid.** citeturn30view3turn19view2turn36search0

### Recommended composition

Use one native room with this layout:

- SwiftUI/AppKit chrome: tab, search, table switcher, view switcher, toolbar, schema inspector, chat panel, import controls.
- Native content surfaces for kanban/gallery/calendar/form/chart/record details.
- A dedicated `SpreadsheetCanvasHostView` backed by `WKWebView` only when the active view is **grid**.
- One bridge layer that translates grid actions into local vault transactions and IronCalc calls.

```swift
import SwiftUI
import WebKit

struct GridWebContainer: NSViewRepresentable {
    let htmlURL: URL
    let bridge: GridJSBridge

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "epistemosGrid")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        context.coordinator.webView = webView
        bridge.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let bridge: GridJSBridge
        weak var webView: WKWebView?

        init(bridge: GridJSBridge) {
            self.bridge = bridge
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "epistemosGrid",
                  let body = message.body as? [String: Any],
                  let kind = body["kind"] as? String
            else { return }

            Task { @MainActor in
                try await bridge.handleMessage(kind: kind, payload: body)
            }
        }
    }
}

@MainActor
final class GridJSBridge: ObservableObject {
    weak var webView: WKWebView?
    let controller: DataTabController

    init(controller: DataTabController) {
        self.controller = controller
    }

    func handleMessage(kind: String, payload: [String: Any]) async throws {
        switch kind {
        case "editCell":
            try await controller.applyGridEdit(payload)
        case "requestViewport":
            let snapshot = try await controller.currentGridViewport(payload)
            try push(event: "viewportData", json: snapshot)
        case "selectRange":
            controller.updateSelection(payload)
        default:
            break
        }
    }

    func push(event: String, json: String) throws {
        let js = "window.EpistemosGrid.receive(\(json));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}
```

That composition is faithful to the owner’s “native as far as I can get without sacrificing functionality.”

## Unified data core and agent layer

### The core modeling decision

The hardest design tension is real: spreadsheets are a **cell matrix**, while Airtable-style bases are **typed records with per-column semantics**. Trying to pretend they are the same thing all the way down is how products get weird.

The defensible solution is to make the **typed table/record core** the system of record, and treat the spreadsheet grid as a **projection** over that core.

That is exactly how Baserow and Teable think about their product surfaces: one underlying table, many views, each with filters/sorts/grouping/field visibility/card config/date config/form config, but the same records underneath. Baserow’s docs are explicit that different views display the same underlying data without duplication, and both Baserow and Teable center fields as typed columns and records as rows. citeturn21view0turn21view1turn25search6turn24search3

### The concrete recommendation

Use this contract:

- **Vault truth** = SQLite tables/fields/records/links/views.
- **Grid truth** for typed tables = a materialized view of those records into a sheet-like coordinate space.
- **Columns remain typed.** A column is a field, not an arbitrary bag of mixed cell types.
- **Formula fields** are first-class field definitions stored canonically as row-scoped expressions over field IDs.
- The IronCalc engine is used to evaluate:
  - formula fields,
  - selection summaries,
  - derived view expressions,
  - later, optional analysis sheets.

This avoids the worst trap: letting arbitrary cell formulas mutate typed schemas in uncontrolled ways.

For v1, I recommend **two formula modes**, not one:

| Formula mode | Stored as | UI affordance | Semantics | Confidence |
|---|---|---|---|---|
| Field formula | Canonical field-expression AST referencing field IDs | Airtable-style formula field, visible in grid as a formula column | Row-scoped, typed, durable, schema-safe | Inferred, backed by Baserow/Teable field semantics. citeturn21view5turn25search2 |
| Analysis sheet formula | Workbook formula in IronCalc sheet | Separate “analysis” or “scratch” sheet later | Free-form A1/range formulas; not the canonical table schema | Inferred; recommended future extension |

That gives you a true spreadsheet engine **without** collapsing the database into a floppy workbook.

### SQLite / GRDB schema sketch

The schema below is deliberately shaped by Baserow/Teable concepts: typed fields, a view model with per-view options, linked records, view-column metadata, and computed fields. Baserow’s plugin docs are especially useful here because they make the abstractions explicit: a field type defines how a column is stored, and a view type defines how table data is displayed. Teable’s API docs further show view options like row height, hidden columns, width, grouping, and frozen columns. citeturn28view0turn28view1turn27view0turn27view1turn27view2

```swift
import GRDB

struct DataMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("plan9_initial") { db in
            try db.create(table: "db_table") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("primary_field_id", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            try db.create(table: "db_field") { t in
                t.column("id", .text).primaryKey()
                t.column("table_id", .text).notNull()
                    .references("db_table", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull() // text, number, date, single_select, ...
                t.column("is_primary", .boolean).notNull().defaults(to: false)
                t.column("is_nullable", .boolean).notNull().defaults(to: true)
                t.column("position", .integer).notNull()
                t.column("config_json", .text).notNull().defaults(to: "{}")
                t.column("formula_expr", .text)   // canonical row-scoped expression
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "db_record") { t in
                t.column("id", .text).primaryKey()
                t.column("table_id", .text).notNull()
                    .references("db_table", onDelete: .cascade)
                t.column("display_order", .double).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("created_by", .text)
                t.column("updated_by", .text)
                t.column("deleted_at", .datetime)
            }

            try db.create(table: "db_cell") { t in
                t.column("record_id", .text).notNull()
                    .references("db_record", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                    .references("db_field", onDelete: .cascade)
                t.column("value_json", .text)              // canonical typed payload
                t.column("display_text", .text)            // cached render
                t.column("computed_json", .text)           // formula / lookup / rollup cache
                t.column("source_hash", .text)
                t.column("updated_at", .datetime).notNull()
                t.primaryKey(["record_id", "field_id"])
            }

            try db.create(table: "db_link_edge") { t in
                t.column("id", .text).primaryKey()
                t.column("field_id", .text).notNull()
                    .references("db_field", onDelete: .cascade)
                t.column("from_record_id", .text).notNull()
                    .references("db_record", onDelete: .cascade)
                t.column("to_record_id", .text).notNull()
                    .references("db_record", onDelete: .cascade)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.uniqueKey(["field_id", "from_record_id", "to_record_id"])
            }

            try db.create(table: "db_view") { t in
                t.column("id", .text).primaryKey()
                t.column("table_id", .text).notNull()
                    .references("db_table", onDelete: .cascade)
                t.column("kind", .text).notNull() // grid, kanban, gallery, calendar, form
                t.column("name", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("options_json", .text).notNull().defaults(to: "{}")
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "db_view_field") { t in
                t.column("view_id", .text).notNull()
                    .references("db_view", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                    .references("db_field", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("width", .integer)
                t.column("hidden", .boolean).notNull().defaults(to: false)
                t.column("meta_json", .text).notNull().defaults(to: "{}")
                t.primaryKey(["view_id", "field_id"])
            }

            try db.create(table: "db_view_filter") { t in
                t.column("id", .text).primaryKey()
                t.column("view_id", .text).notNull()
                    .references("db_view", onDelete: .cascade)
                t.column("field_id", .text)
                t.column("operator", .text).notNull()
                t.column("value_json", .text)
                t.column("group_id", .text)
                t.column("position", .integer).notNull()
            }

            try db.create(table: "db_view_sort") { t in
                t.column("id", .text).primaryKey()
                t.column("view_id", .text).notNull()
                    .references("db_view", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                t.column("direction", .text).notNull() // asc, desc
                t.column("position", .integer).notNull()
            }

            try db.create(table: "db_view_group") { t in
                t.column("id", .text).primaryKey()
                t.column("view_id", .text).notNull()
                    .references("db_view", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                t.column("direction", .text).notNull()
                t.column("position", .integer).notNull()
            }

            try db.create(table: "db_attachment") { t in
                t.column("id", .text).primaryKey()
                t.column("blob_path", .text).notNull()
                t.column("mime_type", .text)
                t.column("filename", .text)
                t.column("byte_count", .integer)
                t.column("sha256", .text)
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "db_record_attachment") { t in
                t.column("record_id", .text).notNull()
                    .references("db_record", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                    .references("db_field", onDelete: .cascade)
                t.column("attachment_id", .text).notNull()
                    .references("db_attachment", onDelete: .cascade)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.primaryKey(["record_id", "field_id", "attachment_id"])
            }

            try db.create(table: "db_import_source") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull() // image, pdf, csv, json, pasted_text
                t.column("attachment_id", .text).references("db_attachment", onDelete: .setNull)
                t.column("raw_text", .text)
                t.column("metadata_json", .text).notNull().defaults(to: "{}")
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "db_record_provenance") { t in
                t.column("record_id", .text).notNull()
                    .references("db_record", onDelete: .cascade)
                t.column("source_id", .text).notNull()
                    .references("db_import_source", onDelete: .cascade)
                t.primaryKey(["record_id", "source_id"])
            }

            try db.create(table: "db_op_log") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull() // schema_change, data_change, import, view_change
                t.column("forward_json", .text).notNull()
                t.column("inverse_json", .text).notNull()
                t.column("preview_hash", .text)
                t.column("created_at", .datetime).notNull()
                t.column("applied_at", .datetime)
            }
        }
    }
}
```

### How formula fields route through IronCalc

The practical routing pattern is:

1. Build a **sheet projection** for a table/view: row `n` corresponds to record `recordIDs[n]`; column `m` corresponds to field `fieldIDs[m]`.
2. For non-formula fields, write their current typed values into the appropriate sheet cells as literal user input.
3. For formula fields, compile the canonical field expression into a per-row A1 formula. Example: canonical `mul(field("qty"), field("unit_price"))` for row 12 becomes `=C12*D12`.
4. Evaluate the workbook.
5. Read computed results back into `db_cell.computed_json` / `display_text`.
6. Use those cached computed values everywhere outside the grid.

That gives you spreadsheet-grade recalc while keeping formulas durable against column reorder/rename, because the durable representation is field-ID based, not A1 based.

```swift
struct FormulaCompiler {
    static func compileRowFormula(
        canonical: FormulaExpr,
        row: Int,
        columnByFieldID: [String: Int]
    ) throws -> String {
        switch canonical {
        case .field(let fieldID):
            guard let col = columnByFieldID[fieldID] else { throw CompileError.unknownField(fieldID) }
            return "\(columnLetter(col))\(row)"
        case .number(let n):
            return "\(n)"
        case .string(let s):
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .call(let fn, let args):
            let rendered = try args.map { try compileRowFormula(canonical: $0, row: row, columnByFieldID: columnByFieldID) }
            return "\(fn.uppercased())(\(rendered.joined(separator: ",")))"
        case .binary(let lhs, let op, let rhs):
            let l = try compileRowFormula(canonical: lhs, row: row, columnByFieldID: columnByFieldID)
            let r = try compileRowFormula(canonical: rhs, row: row, columnByFieldID: columnByFieldID)
            return "(\(l)\(op.rawValue)\(r))"
        }
    }
}
```

### Agent tools and safety pattern

The tool surface should be the same on MAS and Pro. The tool contract is the moat.

Baserow and Teable both expose structural concepts that are broadly similar—fields, views, filters, sorts, grouping, column meta, link fields, rollups—which is a good signal that these operations are stable enough to put behind app-level tools. Teable’s API surfaces view options, grouping, and column meta as explicit operations; Baserow makes field/view types first-class abstractions. citeturn27view0turn27view1turn27view2turn28view0turn28view1

I would define the agent layer around **intents that produce transaction previews**.

```json
{
  "namespace": "epistemos.data",
  "tools": [
    {
      "name": "plan_changes",
      "description": "Analyze a natural-language request and return a dry-run plan of schema/view/data operations without applying them.",
      "input_schema": {
        "type": "object",
        "properties": {
          "request": { "type": "string" },
          "table_id": { "type": "string" },
          "view_id": { "type": "string" },
          "selection": { "type": "object" }
        },
        "required": ["request"]
      }
    },
    {
      "name": "apply_transaction",
      "description": "Apply a previously previewed transaction hash.",
      "input_schema": {
        "type": "object",
        "properties": {
          "preview_hash": { "type": "string" },
          "user_confirmed": { "type": "boolean" }
        },
        "required": ["preview_hash", "user_confirmed"]
      }
    },
    {
      "name": "undo_transaction",
      "description": "Undo a previously applied transaction using its inverse log.",
      "input_schema": {
        "type": "object",
        "properties": {
          "op_id": { "type": "string" }
        },
        "required": ["op_id"]
      }
    },
    {
      "name": "query_data",
      "description": "Run a local query over a table/view and return rows, summaries, and chart-ready series.",
      "input_schema": {
        "type": "object",
        "properties": {
          "table_id": { "type": "string" },
          "view_id": { "type": "string" },
          "filter": { "type": "object" },
          "sort": { "type": "array" },
          "group": { "type": "array" },
          "limit": { "type": "integer" }
        }
      }
    }
  ]
}
```

The **preview → confirm → apply → undo** pattern should work like this:

- `plan_changes` returns a structured transaction: proposed ops, impact summary, rows affected, schema changes, reverse ops, and a `preview_hash`.
- The Data tab renders a review sheet: “rename field X to Y,” “convert N records,” “create two linked fields,” “drop one field,” and a compact diff.
- Only after explicit user confirmation does the app call `apply_transaction`.
- Every applied transaction writes both forward and inverse ops into `db_op_log`.
- `undo_transaction` simply replays the inverse ops inside one SQLite transaction.

```rust
#[derive(serde::Serialize, serde::Deserialize, Clone)]
#[serde(tag = "op")]
pub enum DataOp {
    CreateTable { table_id: String, name: String },
    AddField { table_id: String, field_id: String, name: String, kind: String, config_json: String },
    ChangeFieldType { field_id: String, old_kind: String, new_kind: String, migration_json: String },
    RenameField { field_id: String, from: String, to: String },
    CreateView { table_id: String, view_id: String, kind: String, name: String, options_json: String },
    PutViewColumnMeta { view_id: String, field_id: String, width: Option<i64>, hidden: Option<bool> },
    PutViewGroup { view_id: String, field_id: String, direction: String },
    UpsertCell { record_id: String, field_id: String, value_json: String },
    DeleteField { field_id: String },
}

#[derive(serde::Serialize, serde::Deserialize, Clone)]
pub struct PlannedTransaction {
    pub preview_hash: String,
    pub summary: String,
    pub forward: Vec<DataOp>,
    pub inverse: Vec<DataOp>,
    pub warnings: Vec<String>,
}
```


```swift
@MainActor
final class DataToolExecutor {
    let dbWriter: DatabaseWriter
    let planner: AgentPlanner

    func plan(request: String, context: DataContext) async throws -> PlannedTransaction {
        try await planner.plan(request: request, context: context)
    }

    func apply(_ tx: PlannedTransaction, confirmed: Bool) throws {
        guard confirmed else { return }

        try dbWriter.write { db in
            for op in tx.forward {
                try applyOp(op, db: db)
            }

            try OpLog(
                id: UUID().uuidString,
                kind: "schema_change",
                forwardJSON: try JSONEncoder().encode(tx.forward).utf8String,
                inverseJSON: try JSONEncoder().encode(tx.inverse).utf8String,
                previewHash: tx.preview_hash,
                createdAt: Date(),
                appliedAt: Date()
            ).insert(db)
        }
    }

    func undo(opLogID: String) throws {
        try dbWriter.write { db in
            let opLog = try OpLog.fetchOne(db, key: opLogID)!
            let inverse = try JSONDecoder().decode([DataOp].self, from: Data(opLog.inverseJSON.utf8))
            for op in inverse {
                try applyOp(op, db: db)
            }
        }
    }
}
```

### MAS and Pro execution path

The key thing to preserve is **one semantic tool layer**.

- On **MAS**, the request enters the native chat surface, is routed to the in-process `agent_core` seam, which can call `plan_changes`, `query_data`, and ingest tools directly in-process. This stays inside sandbox-friendly app memory and local file access patterns. Vision and PDFKit are in-process Apple frameworks. citeturn12search2turn11search1turn20view3
- On **Pro**, the exact same tool contracts are registered on the app-hosted MCP boundary for OpenChamber/goose/OpenCode. The implementation still executes inside the app against SQLite and Rust; the external agent is just a client. That keeps product behavior aligned across builds. This is an inference from the owner’s fixed environment, but it is the right architectural move because it reduces split-brain semantics. | Confidence: inferred. |

## Ingest and deep integration

### MAS-safe ingest pipeline

The MAS-safe ingest path is stronger than it first appears because the required primitives already exist on-device.

- **Images / receipts:** Vision’s `VNRecognizeTextRequest` / text-recognition docs explicitly expose text recognition in images. citeturn11search1turn11search5
- **PDFs:** PDFKit is a full PDF framework for viewing, editing, writing, searching, and selecting PDF content. Apple’s WWDC22 PDFKit session also notes Live Text support for scanned PDFs, with OCR done on demand. citeturn11search10turn20view3
- **Structured output / tool calling for local agents:** Foundation Models documentation and WWDC material explicitly describe structured output, guided generation, and tool calling; on supported systems this is a clean MAS-legal way to turn OCR’d or parsed text into typed records. citeturn37search0turn37search3turn37search4turn37search8

That means the ingest story can be:

1. Acquire raw bytes into the local vault.
2. Extract raw text locally.
3. Ask the agent to propose a table schema and row mapping.
4. Show preview.
5. Insert records and record provenance.

### Ingest verdicts

| Input | MAS-safe path | Notes | Confidence |
|---|---|---|---|
| Receipt photo / image | Vision OCR → agent structuring → preview → insert | Fully in-process and on-device. citeturn11search1turn11search5 | Verified in source |
| PDF | PDFKit text/search/selection or existing parser path; use Live Text for scanned PDFs where needed | Good local path; still some parser-quality variance across documents. citeturn11search10turn20view3 | Verified in source |
| CSV / JSON | Native parse in Swift | No special policy risk; easiest lane | Inferred |
| Pasted messy text | Agent schema inference + structured output | Strong fit for Foundation Models or existing local agent pipeline. citeturn37search0turn37search8 | Verified + inferred |
| Cloud OCR / cloud parsing | **Pro-only optional enhancement** | Keep off by default for MAS privacy/local-first story | Inferred |

### Vision OCR → structuring → insert sketch

```swift
import Vision
import AppKit
import GRDB

struct OCRLine: Codable {
    let text: String
    let confidence: Float
}

struct ProposedField: Codable {
    let name: String
    let kind: String
}

struct ProposedRow: Codable {
    let values: [String: String]
}

struct ProposedImport: Codable {
    let tableName: String
    let fields: [ProposedField]
    let rows: [ProposedRow]
}

final class ReceiptImporter {
    let dbWriter: DatabaseWriter
    let agent: DataStructuringAgent

    init(dbWriter: DatabaseWriter, agent: DataStructuringAgent) {
        self.dbWriter = dbWriter
        self.agent = agent
    }

    func importImage(_ imageURL: URL) async throws -> ProposedImport {
        let attachmentID = try storeAttachment(imageURL)

        let cgImage = try loadCGImage(url: imageURL)
        let request = RecognizeTextRequest()
        let observations = try await request.perform(on: cgImage)

        let rawLines: [OCRLine] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return OCRLine(text: candidate.string, confidence: candidate.confidence)
        }

        let rawText = rawLines.map(\.text).joined(separator: "\n")

        let proposal = try await agent.proposeSchemaAndRows(
            sourceKind: "receipt_image",
            rawText: rawText,
            preferredTableName: "Receipts"
        )

        try dbWriter.write { db in
            let sourceID = UUID().uuidString
            try db.execute(
                sql: """
                INSERT INTO db_import_source (id, kind, attachment_id, raw_text, metadata_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    sourceID, "image", attachmentID, rawText,
                    #"{"ocr":"vision","lineCount":\#(rawLines.count)}"#,
                    Date()
                ]
            )
        }

        return proposal
    }

    func apply(import proposal: ProposedImport, sourceID: String) throws {
        try dbWriter.write { db in
            let tableID = UUID().uuidString
            try db.execute(
                sql: "INSERT INTO db_table (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)",
                arguments: [tableID, proposal.tableName, Date(), Date()]
            )

            var fieldIDs: [String: String] = [:]
            for (idx, field) in proposal.fields.enumerated() {
                let fieldID = UUID().uuidString
                fieldIDs[field.name] = fieldID
                try db.execute(
                    sql: """
                    INSERT INTO db_field (id, table_id, name, kind, position, config_json, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, '{}', ?, ?)
                    """,
                    arguments: [fieldID, tableID, field.name, field.kind, idx, Date(), Date()]
                )
            }

            for (rowIndex, row) in proposal.rows.enumerated() {
                let recordID = UUID().uuidString
                try db.execute(
                    sql: """
                    INSERT INTO db_record (id, table_id, display_order, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [recordID, tableID, Double(rowIndex), Date(), Date()]
                )

                for (fieldName, value) in row.values {
                    guard let fieldID = fieldIDs[fieldName] else { continue }
                    try db.execute(
                        sql: """
                        INSERT INTO db_cell (record_id, field_id, value_json, display_text, updated_at)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        arguments: [recordID, fieldID, #"{"text":"\#(value)"}"#, value, Date()]
                    )
                }

                try db.execute(
                    sql: "INSERT INTO db_record_provenance (record_id, source_id) VALUES (?, ?)",
                    arguments: [recordID, sourceID]
                )
            }
        }
    }
}
```

### Deep integration with the vault and graph

The moat is not “spreadsheet features.” The moat is that a record is a **vault object**.

That means every record should have:

- a stable vault object ID,
- a canonical URL / internal link target,
- graph-node materialization,
- backlink participation from notes,
- inline embed support in notes.

This is exactly where Epistemos can surpass Baserow/Teable: not by recreating server-y app builders, but by making records addressable in the same substrate as notes and research artifacts. Baserow and Teable are database-first; Epistemos can be **vault-first**. Baserow and Teable both expose the record/table/view model cleanly enough to borrow the behavioral ideas, but they do not own the local PKM graph in the same way. citeturn21view0turn25search6turn35view1

```swift
struct VaultObjectRef: Codable, Hashable {
    let kind: String   // "record"
    let tableID: String
    let recordID: String
}

struct RecordGraphNode: Codable {
    let id: String              // "record:<tableID>:<recordID>"
    let title: String
    let vaultRef: VaultObjectRef
    let searchableText: String
}

final class RecordBinder {
    let dbReader: DatabaseReader
    let graphStore: GraphStore

    func bindRecord(tableID: String, recordID: String) throws {
        let display = try fetchPrimaryDisplay(tableID: tableID, recordID: recordID)
        let text = try fetchRecordSearchText(tableID: tableID, recordID: recordID)

        let node = RecordGraphNode(
            id: "record:\(tableID):\(recordID)",
            title: display,
            vaultRef: .init(kind: "record", tableID: tableID, recordID: recordID),
            searchableText: text
        )

        try graphStore.upsert(node: node)
    }

    func wikilink(for tableID: String, recordID: String) -> String {
        "[[record:\(tableID):\(recordID)]]"
    }
}
```

### Inline note embed block

```swift
struct DataEmbedBlock: Codable, Hashable {
    let tableID: String
    let viewID: String
    let style: String   // grid, kanban, gallery, calendar
    let titleOverride: String?
    let height: Double?
}

extension DataEmbedBlock {
    var markdownToken: String {
        let json = try! String(data: JSONEncoder().encode(self), encoding: .utf8)!
        return #"{{epistemos-data:\#(json)}}"#
    }
}

struct NoteDataEmbedView: View {
    let block: DataEmbedBlock
    @ObservedObject var controller: DataTabController

    var body: some View {
        Group {
            switch block.style {
            case "kanban":
                NativeKanbanView(tableID: block.tableID, viewID: block.viewID)
            case "gallery":
                NativeGalleryView(tableID: block.tableID, viewID: block.viewID)
            case "calendar":
                NativeCalendarView(tableID: block.tableID, viewID: block.viewID)
            default:
                EmbeddedGridPreview(tableID: block.tableID, viewID: block.viewID)
            }
        }
        .frame(minHeight: block.height ?? 320)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

For charts, I would use **Swift Charts** for record-derived visualizations in v1. It is native, expressive, accessible, and a better fit for “data derived from local typed records” than trying to drag spreadsheet-embedded charting parity into v1. If later you decide that spreadsheet-inline chart objects matter, that can become a web-grid concern. citeturn36search0turn36search4

## Donors, licensing, and MAS/Pro verification

### What to borrow from Teable and Baserow

The clean-room donor lessons are very specific.

From **Baserow**, borrow the product abstractions and plugin mentality:

- field types are explicit abstractions over per-column storage,
- view types are explicit abstractions over table presentation,
- view configuration is independent per view,
- lookup/rollup/count build on link fields,
- the same data can be visualized in grid/kanban/gallery/calendar/form without duplication. citeturn28view0turn28view1turn21view0turn21view2turn21view4turn23search0

From **Teable**, borrow the modern view polish and operational metadata ideas:

- grid options for row height and frozen columns,
- view-column metadata with width/hidden/statistics,
- grouping as an explicit view operation,
- one-way vs two-way link modeling,
- practical view docs for bulk edit, fill handle, selection statistics, and card configuration. citeturn24search3turn27view0turn27view1turn27view2turn25search1turn24search0

Do **not** borrow Teable server architecture. Teable’s own deployment docs require PostgreSQL, Redis, and S3-compatible object storage for production deployments, and its repo structure is explicitly `nextjs-app` + `nestjs-backend` + Postgres-oriented packages. That is precisely the weight the owner wants to avoid. citeturn29search0turn29search2turn35view1

### Licensing and redistribution table

| Component | License | Practical takeaway | Confidence |
|---|---|---|---|
| IronCalc | MIT or Apache-2.0, at your option. citeturn34view2turn32view0turn32view1 | Safe to embed/vendor with notice obligations. | Verified in source |
| Univer core | Apache-2.0. citeturn32view2 | Safe to embed, but watch Pro/server boundary. | Verified in source |
| Univer Pro | Commercial; advanced features/server required. citeturn30view0turn30view1 | Not a fit for MAS/no-server center of gravity. | Verified in source |
| Baserow OSE | MIT Expat for open-source edition outside premium/enterprise/docs carve-outs. citeturn6view1turn35view0 | Safe to study and selectively borrow ideas/code with care for premium boundaries. | Verified in source |
| Teable CE repo | Mixed; core apps AGPL-3.0, packages MIT, plugins AGPL-3.0. citeturn6view0turn35view1 | Clean-room only for app behavior/UX; do not port AGPL app code into proprietary product. | Verified in source |
| Apple Vision / PDFKit / WKWebView / Swift Charts / Foundation Models | Apple platform frameworks. citeturn11search1turn11search10turn11search3turn36search0turn37search0 | Fine for shipped native app usage under Apple platform terms. | Verified in source |

### MAS / Pro verification

The all-embedded stack the owner wants is realistic on MAS **if you keep everything in-process**.

App Sandbox restricts resource access by entitlements, and Apple documents that incoming server connections are an explicit entitlement (`com.apple.security.network.server`). That means a design that avoids any local web server or helper service is cleaner and more review-stable. Apple’s own guidance around sandbox inheritance also makes child-process architectures awkward inside sandboxed apps; the owner’s decision to avoid subprocesses on MAS is the right one. citeturn12search2turn12search1turn12search7turn12search9

That yields this build split:

| Capability | MAS June build | Pro build | Confidence |
|---|---|---|---|
| SQLite / GRDB local vault | Yes | Yes | Verified + inferred. citeturn13search0turn13search20 |
| IronCalc Rust engine in-process | Yes | Yes | Verified + inferred. citeturn15view0turn16search1turn16search3 |
| Dense grid in WKWebView | Yes | Yes | Verified in source. citeturn11search3 |
| Native kanban/gallery/calendar/form/chat | Yes | Yes | Verified + inferred. citeturn24search0turn24search1turn24search2 |
| Vision OCR | Yes | Yes | Verified in source. citeturn11search1turn11search5 |
| PDFKit PDF ingest | Yes | Yes | Verified in source. citeturn11search10turn20view3 |
| Agent DB ops in-process | Yes | Yes | Inferred from fixed environment; MAS path is sandbox-legal because it is in-process and local-only. |
| OpenChamber / goose / OpenCode subprocess path | No | Yes | Fixed environment + sandbox/process constraints. citeturn12search7turn12search9 |
| Local server binary / server-backed spreadsheet feature dependency | No | Optional but not recommended for core | Verified + inferred. citeturn12search1turn30view0turn30view1 |
| Cloud OCR / cloud parse | Optional enhancement, not core | Optional enhancement | Inferred |

The main caveat is hardware/OS availability for Apple Foundation Models. Apple’s docs describe Foundation Models as a native framework for language understanding, structured output, and tool calling, but practical availability depends on supported Apple Intelligence hardware/OS. That is not a blocker here because the MAS build already has June + `agent_core`; Foundation Models can be treated as an optional on-device structured-output accelerator where available, not as the only structuring path. citeturn37search0turn37search4turn11search0

## Phased build plan and open questions

### Suggested build plan

**Phase one** should establish the durable substrate: the SQLite/GRDB hybrid schema; IronCalc bridge; field definitions; records/cells/links/views tables; native table picker and schema inspector; native chat panel; CSV/JSON import; OCR/PDF extraction preview; and a first grid view running inside WKWebView with local bridge calls only. This is the point where Plan 9 becomes real. citeturn13search0turn15view0turn11search1turn20view3turn11search3

**Phase two** should add the native secondary views and make the database feel like a database rather than a sheet: kanban, gallery, calendar, form, view filters/sorts/grouping/field visibility, linked-record UX, lookup/rollup display, record detail drawer, provenance UI, and note embeds. That gets you to a credible Airtable-like local base product. citeturn21view0turn21view2turn21view4turn22view0turn22view1turn24search0turn24search1turn24search2

**Phase three** should turn the agent into the differentiator: structural editing tools, transaction preview/diff rendering, undo history, NL bulk transform, schema inference from messy text, chart generation from local data, and note/graph-native workflows like “link all records referenced in this note,” “turn this paragraph into a table,” or “embed a calendar view of all sources due this month.” Apple’s structured-output and tool-calling primitives, plus the existing `agent_core` seam, are especially relevant here. citeturn37search0turn37search3turn37search4turn37search7

### Tight v1 scope

The best v1 is **not** “all spreadsheet features.”

The best v1 is:

- one local typed data core,
- grid/kanban/gallery/calendar/form,
- formula fields using IronCalc,
- linked records + lookup/rollup,
- CSV/JSON/image/PDF/paste ingest,
- chat over data,
- NL schema changes with safe preview/undo,
- note embeds + graph binding.

That is already differentiated.

### Open questions and limitations

A few things remain genuinely open.

The first is **renderer choice for the grid enclave**. I am confident that the grid should be web-hosted in v1 inside a native frame; I am less confident, from the sources gathered here, which exact grid renderer should sit on top of the local model on day one. IronCalc is the right kernel, but its current public artifacts speak more strongly to engine APIs than to a turnkey embedded grid SDK. Univer is a stronger renderer, but centering it would distort the architecture. So the practical question is whether the team wants a temporary renderer compromise for speed or a single-engine purity play that may take longer. citeturn15view0turn15view3turn33view1turn30view3

The second is **how much spreadsheet freedom to allow inside typed tables**. My recommendation is intentionally conservative: formula columns yes, arbitrary per-cell schema-breaking formulas no, at least in v1. If the owner wants “literally any cell can become a formula anywhere,” then the product begins crossing from hybrid data surface into full workbook land, and the design should explicitly introduce analysis sheets rather than smuggling workbook behavior into typed table columns.

The third is **Foundation Models availability strategy**. The framework is promising and local, but the product should not gate MAS ingest or data chat on it. Keep `agent_core` as the portability baseline, and layer FM where supported. citeturn37search0turn37search4

The fourth is **chart scope**. Native Swift Charts is the right v1 answer for record-derived analytics, but if the owner specifically wants spreadsheet-embedded object charts in the grid itself, that should be treated as post-v1 work, because Univer’s chart story is Pro-branded in docs and IronCalc charts are explicitly not there yet. citeturn36search0turn30view2turn15view3

If you want the shortest version of the dossier’s conclusion, it is this: **build the database as a native local-first typed system, run IronCalc as the Rust calc kernel, make the agent operate on explicit previewable transactions, keep all ingest in-process on MAS, and accept that the dense spreadsheet grid is the one surface where a WKWebView fallback is the honest way to preserve functionality.** citeturn34view2turn13search0turn11search1turn12search2turn30view3turn11search3

GPT 2 - # Plan 9 of Epistemos Execution Dossier

Research snapshot: July 3, 2026 in America/Chicago. citeturn24time0

## Executive verdicts

The strongest recommendation is to make **SQLite/GRDB the single source of truth**, layer a **Rust IronCalc wrapper** beside it for spreadsheet computation, and ship a **hybrid UI composition**: native macOS chrome and native database views everywhere they can hit parity, with a **bundled WKWebView only for the dense spreadsheet grid**. That gets you the stack fit of Rust + UniFFI, keeps the MAS build fully embedded and sandbox-friendly, preserves the app’s native feel, and avoids building an Excel-class grid from scratch in AppKit before v1. IronCalc is a Rust spreadsheet engine expressly positioned as embeddable, already used through Rust/JavaScript/Python bindings, and supports `.xlsx` import/export plus hundreds of spreadsheet functions, while its public docs still describe the project as young and missing some major spreadsheet features such as charts and collaboration. citeturn9search2turn10view2turn10view3turn10view4turn10view5turn34search5turn40search0turn41search1turn25search0

The strongest opposite-case recommendation is this: if the owner values **fastest possible Excel-grade interaction parity inside the grid** over Rust alignment, then **Univer is the better grid shell**. Univer is a full-stack spreadsheet framework with plugin architecture, a canvas rendering engine, 500+ functions, published rendering numbers at million-cell scales, and mature command/event APIs. But the red-team problem is that Univer’s center of gravity is **TypeScript + canvas + plugin ecosystem**, not Swift/Rust, and many of the exact “office-grade” features that make it attractive on paper—collaboration, charting, pivoting, some import/export paths—either live behind **Pro plugins**, expect a **server**, or are documented as backend-powered. For a MAS-first, all-local, no-server product, that is strategic friction, not just implementation detail. citeturn15view1turn15view2turn15view3turn16view0turn16view1turn16view3turn28search7turn15view6turn15view0turn38view0turn38view1turn37search8

The owner’s first-impression hypothesis holds up under scrutiny: **native frame + native simple views + web dense grid** is the most defensible v1 ceiling map. AppKit gives you excellent native windows, toolbars, forms, boards, card layouts, charts, and inspectors. It does not give you Excel-grade spreadsheet behavior for free. `NSTableView` is record-oriented, `NSCollectionView` is reusable-item oriented, and `CATiledLayer` helps with large surfaces, but none of those components comes close to an end-to-end spreadsheet interaction model with range semantics, formula editing, fill-handle behavior, frozen panes, multi-cell clipboard compatibility, merged cells, IME-safe editing, and million-cell scroll feel. WKWebView is explicitly the platform’s supported in-app web-content container, and Epistemos already ships that pattern successfully. citeturn27search4turn27search0turn27search12turn27search13turn27search5turn27search3turn27search2turn27search10turn27search14turn15view0

The hardest design tension—**spreadsheet cells versus typed database records**—should not be “solved” by making one side fake the other. The better answer is a **projected hybrid**. Keep a typed relational core for records, links, views, and vault/graph identity. Mirror that core into an IronCalc sheet for formulas, recalculation, and spreadsheet affordances. Then allow **grid-only helper columns** and hidden helper ranges for real spreadsheet work, while only **projected typed fields** participate in kanban, gallery, calendar, form, graph, and note embeds. Airtable-style relational semantics such as lookup and rollup should remain native field kinds, not be forced through A1 formulas. That is also the pattern donor products teach: Baserow and Teable both treat multiple views as alternate projections of the same underlying rows, and both differentiate link/lookup/rollup behavior from raw spreadsheet formulas. citeturn29search8turn29search19turn29search7turn29search4turn29search1turn29search13turn29search17turn18search6turn18search1turn18search5turn18search8turn18search0turn18search10

### Headline recommendations

| Decision | Recommendation | Why | Confidence |
|---|---|---|---|
| Base engine | **IronCalc** | Best fit with Swift + Rust + UniFFI stack, embeddable engine posture, `.xlsx` support, no intrinsic server dependency, and easier MAS-safe story than a TS-first framework. citeturn9search2turn10view2turn10view3turn34search5turn40search0turn25search0 | Verified / inferred |
| UI composition | **Native frame and non-grid views; bundled web grid in WKWebView** | Native parity is realistic for kanban/gallery/calendar/form/chat/charts, but not for an Excel-grade dense formula grid under v1 constraints. citeturn27search4turn27search12turn27search13turn27search3turn27search2turn15view0 | Inferred, strongly supported |
| Opposite approach | **Univer-first inside WKWebView** | Best speed-to-parity if the goal is a spreadsheet UI shell first, but strategically worse for MAS-first local architecture because of JS centrality and server/Pro gravity. citeturn15view1turn15view2turn16view0turn16view1turn38view0turn38view1turn28search7 | Verified / inferred |

## Base engine choice

### IronCalc versus Univer

| Axis | IronCalc | Univer | Recommendation | Confidence |
|---|---|---|---|---|
| License | Dual MIT / Apache-2.0. citeturn9search2turn34search9turn40search1 | Apache-2.0 for OSS packages; Pro plugins and licenses exist separately. citeturn28search7turn28search5turn28search6turn13search15 | Both are license-compatible for embedding, but Univer requires stricter feature-boundary discipline. | Verified |
| Architectural center | Rust spreadsheet engine plus xlsx reader/writer; docs describe it as the engine used for bindings and apps. citeturn10view2turn10view3turn33search7 | Full-stack framework with microkernel/plugin architecture, separate render engine, formula engine, UI, and headless Node mode. citeturn15view1turn15view3turn16view0turn16view1 | IronCalc fits Epistemos’s existing Rust center of gravity better. | Verified |
| Formula surface | “Hundreds of functions,” Excel-compatibility goal, many categories present; some docs still call sections incomplete. citeturn10view4turn11search6turn11search3turn34search5 | 500+ functions, custom formula registration, cross-sheet formulas. citeturn12search2turn14search1turn14search3 | Univer is broader today; IronCalc is sufficient if v1 keeps relational fields native and spreadsheet features focused. | Verified / inferred |
| Rendering | No public native macOS renderer; repo ships web app/widget/wasm and docs emphasize the engine more than the renderer. citeturn7search0turn9search8turn33search7 | Canvas render engine, browser UI, event system, selection/clipboard APIs, and published scrolling benchmarks. citeturn13search0turn13search1turn16view2turn16view3turn15view0 | Univer has the stronger shipped UI shell. | Verified |
| Published large-grid performance | I did not find equivalent public scrolling benchmarks in the inspected sources. | 50–60 FPS published at 100k, 200k, 1m, and 6m rendered cells in the Pro performance page. citeturn15view0 | Univer wins on verifiable grid-shell performance evidence. | IronCalc uncertain / Univer verified |
| Charts and advanced office features | Charts explicitly not planned for v1.0; merged cells were still on the issue roadmap; public signals on conditional formatting are mixed. citeturn10view5turn5search2turn9search6turn34search5 | Charts, pivots, shapes, collaboration, server integration, and related advanced features are documented in Pro/server-facing areas. citeturn15view6turn37search8turn38view1turn38view2turn28search2 | For Plan 9 v1, neither engine should be allowed to define the chart/view architecture. | Verified |
| Embeddability | Explicitly marketed as embeddable and suitable for bindings; Rust/JS/Python usage documented. citeturn9search2turn10view2turn34search5 | Embeddable in browser or Node via plugins/presets. citeturn16view0turn16view1turn28search7 | Both embed; IronCalc embeds more naturally into this app’s Rust seam. | Verified |
| Maturity and activity | Young, still “in its infancy,” but active, ~4k GitHub stars, crate 0.7.1 in Jan 2026. citeturn10view4turn6search6turn9search2 | Much larger project, ~13.3k stars, latest release June 27, 2026, 109 releases. citeturn28search7 | Univer is the more mature UI framework; IronCalc is the better fit engine. | Verified |

The practical call is this: **base the computation layer on IronCalc, not the interface layer on IronCalc**. Treat IronCalc as a workbook/runtime library and not as the entity that owns Data tab persistence, views, or agent semantics. The app should own those in SQLite/GRDB, then project into the engine. That preserves your local-vault architecture, avoids two sources of truth, and keeps the Rust seam coherent. citeturn10view2turn10view3turn33search7turn23search5

The red-team objection to IronCalc is real: its public sources make it clear that it is still early, and some spreadsheet features are clearly incomplete or ambiguous. If the owner secretly wants the grid itself to carry most of the product in v1, IronCalc is the riskier UI starting point. But the owner’s actual locked decisions put the differentiator in the **agent-native typed database**, not in beating Excel on every spreadsheet edge case on day one. Under those terms, IronCalc is the better base. citeturn10view4turn10view5turn34search5

### Swift and UniFFI seam

Compiling a Rust library into a static library and generating Swift bindings with UniFFI is a supported Xcode integration path. UniFFI’s own docs describe compiling the Rust crate into a static lib, generating Swift bindings, and linking them into Xcode. IronCalc does not appear to ship a UniFFI crate today in the inspected sources, but its Rust API is already used to power language bindings and applications, which makes a thin wrapper around `Model` or `UserModel` a straightforward move. That wrapper should expose only the stable operations Epistemos needs: load workbook, read/write input, recalc, enumerate changed cells, and save/export. Dirty-cell notifications should be implemented in your wrapper by diffing before/after evaluate, because I did not find a first-party push-event API for that in the inspected IronCalc docs. citeturn25search0turn25search15turn25search16turn10view2turn10view3turn34search0turn40search0

```rust
// Crate: crates/plan9_calc/src/lib.rs
// Cargo.toml:
// [lib]
// crate-type = ["staticlib", "cdylib"]

use std::sync::{Arc, Mutex};
use ironcalc::{
    base::{cell::CellValue, Model},
    import::load_from_xlsx,
    export::save_to_xlsx,
};

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum CalcError {
    #[error("{0}")]
    Message(String),
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct CellCoord {
    pub sheet: u32,
    pub row: u32,
    pub col: u32,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct RecalcBatch {
    pub revision: u64,
    pub changed: Vec<CellCoord>,
}

#[derive(uniffi::Object)]
pub struct WorkbookHandle {
    inner: Mutex<Model<'static>>,
    revision: Mutex<u64>,
}

#[uniffi::export]
impl WorkbookHandle {
    #[uniffi::constructor]
    pub fn new_empty(name: String) -> Result<Arc<Self>, CalcError> {
        let model = Model::new_empty(Box::leak(name.into_boxed_str()), "en", "UTC", "en")
            .map_err(|e| CalcError::Message(e.to_string()))?;
        Ok(Arc::new(Self {
            inner: Mutex::new(model),
            revision: Mutex::new(0),
        }))
    }

    #[uniffi::constructor]
    pub fn load_xlsx(path: String) -> Result<Arc<Self>, CalcError> {
        let model = load_from_xlsx(&path, "en", "UTC", "en")
            .map_err(|e| CalcError::Message(e.to_string()))?;
        Ok(Arc::new(Self {
            inner: Mutex::new(model),
            revision: Mutex::new(0),
        }))
    }

    pub fn set_input(
        &self,
        sheet: u32,
        row: u32,
        col: u32,
        input: String,
    ) -> Result<RecalcBatch, CalcError> {
        let mut model = self.inner.lock().unwrap();

        // Snapshot populated cells before recalc.
        let before = model.get_all_cells()
            .into_iter()
            .map(|c| (c.sheet as u32, c.row as u32, c.column as u32,
                      model.get_formatted_cell_value(c.sheet, c.row, c.column).unwrap_or_default()))
            .collect::<std::collections::HashMap<_, _>>();

        model.set_user_input(sheet as i32, row as i32, col as i32, input)
            .map_err(|e| CalcError::Message(e.to_string()))?;
        model.evaluate();

        let after_cells = model.get_all_cells();
        let mut changed = Vec::new();

        for c in after_cells {
            let key = (c.sheet as u32, c.row as u32, c.column as u32);
            let val = model.get_formatted_cell_value(c.sheet, c.row, c.column).unwrap_or_default();
            if before.get(&key).map(|s| s.as_str()) != Some(val.as_str()) {
                changed.push(CellCoord { sheet: key.0, row: key.1, col: key.2 });
            }
        }

        let mut revision = self.revision.lock().unwrap();
        *revision += 1;

        Ok(RecalcBatch {
            revision: *revision,
            changed,
        })
    }

    pub fn display_value(&self, sheet: u32, row: u32, col: u32) -> Result<String, CalcError> {
        let model = self.inner.lock().unwrap();
        model.get_formatted_cell_value(sheet as i32, row as i32, col as i32)
            .map_err(|e| CalcError::Message(e.to_string()))
    }

    pub fn raw_formula(&self, sheet: u32, row: u32, col: u32) -> Result<Option<String>, CalcError> {
        let model = self.inner.lock().unwrap();
        model.get_cell_formula(sheet as i32, row as i32, col as i32)
            .map_err(|e| CalcError::Message(e.to_string()))
    }

    pub fn typed_value(&self, sheet: u32, row: u32, col: u32) -> Result<String, CalcError> {
        let model = self.inner.lock().unwrap();
        let v = model.get_cell_value_by_index(sheet as i32, row as i32, col as i32)
            .map_err(|e| CalcError::Message(e.to_string()))?;
        Ok(match v {
            CellValue::Number(n) => n.to_string(),
            CellValue::String(s) => s,
            CellValue::Boolean(b) => b.to_string(),
            CellValue::Empty => String::new(),
            other => format!("{other:?}"),
        })
    }

    pub fn save_xlsx(&self, path: String) -> Result<(), CalcError> {
        let model = self.inner.lock().unwrap();
        save_to_xlsx(&model, &path).map_err(|e| CalcError::Message(e.to_string()))
    }
}

uniffi::setup_scaffolding!();
```


```swift
import Foundation
import Combine

@MainActor
final class Plan9CalcBridge: ObservableObject {
    @Published private(set) var revision: UInt64 = 0
    @Published private(set) var changedCells: [CellCoord] = []

    private let workbook: WorkbookHandle

    init(xlsxPath: String? = nil) throws {
        if let xlsxPath {
            self.workbook = try WorkbookHandle.loadXlsx(path: xlsxPath)
        } else {
            self.workbook = try WorkbookHandle.newEmpty(name: "Plan9")
        }
    }

    func setCell(sheet: UInt32 = 0, row: UInt32, col: UInt32, input: String) throws {
        let batch = try workbook.setInput(sheet: sheet, row: row, col: col, input: input)
        revision = batch.revision
        changedCells = batch.changed
        NotificationCenter.default.post(
            name: .plan9CalcDidRecalc,
            object: self,
            userInfo: ["revision": batch.revision, "changed": batch.changed]
        )
    }

    func displayValue(sheet: UInt32 = 0, row: UInt32, col: UInt32) throws -> String {
        try workbook.displayValue(sheet: sheet, row: row, col: col)
    }
}

extension Notification.Name {
    static let plan9CalcDidRecalc = Notification.Name("plan9CalcDidRecalc")
}
```

## Native ceiling map

### Surface-by-surface verdict

| Surface | Recommended implementation | Why | Confidence |
|---|---|---|---|
| Window, tab, toolbar chrome | **Native** | SwiftUI/AppKit is the correct home for tab chrome, inspectors, segmented view switchers, import buttons, selection summaries, and status indicators. | Verified / trivial |
| Dense editable grid | **Hybrid with web grid inside WKWebView** | This is the one surface where full spreadsheet parity is already solved better in web/canvas engines than in AppKit. citeturn27search4turn27search12turn27search13turn27search3turn27search2turn15view0 | Inferred, strongly supported |
| Kanban | **Native** | Card lists, drag/drop between groups, chips, avatars, and inline inspectors are straightforward in SwiftUI/AppKit. Donor products show these as record projections, not spreadsheet-native concepts. citeturn29search8turn29search3turn18search1 | Verified / inferred |
| Gallery | **Native** | Cards, thumbnails, metadata stacks, and field visibility toggles are much closer to native collection/grid UI than to spreadsheet UI. citeturn29search8turn29search0 | Verified / inferred |
| Calendar | **Native** | Month/week layouts, drag to move date ranges, and native event affordances map cleanly to AppKit/SwiftUI. citeturn29search8turn29search18turn18search5 | Verified / inferred |
| Form | **Native** | Typed input forms are a native strength and should share validators with database field definitions. citeturn29search16turn18search8 | Verified / inferred |
| Chat | **Native** | Chat, plan preview, diff previews, result tables, and undo banners fit SwiftUI natively and are central to the “companion agent” feel. citeturn18search7 | Verified / inferred |
| Charts | **Native first** | Swift Charts is capable for the likely v1 analytics set; avoid server-leaning spreadsheet chart stacks. Fall back to web only for exotic chart types later. citeturn36search0turn36search1turn36search2turn36search3turn15view6 | Verified / inferred |

The native-grid question is where the dossier should be blunt. Yes, you can render *data* natively at large scale. `NSTableView` is explicitly for records in rows and columns and supports scrolling and column interactions. `NSCollectionView` gives reuse. `CATiledLayer` supports asynchronous tiling for very large surfaces. But “Excel-grade functionality” is not merely a list view with many cells. It is a single tightly integrated interaction model: range semantics, active cell, formula bar, editing mode, keyboard navigation, frozen panes, clipboard import/export behavior, fill-handle, merged cells, selection painting, row/column headers, structural edits, sheet tabs, drag-reorder, and live recalc feedback together. Apple’s primitives help with pieces of that, not the whole. By contrast, Univer publishes scrolling FPS for million-cell surfaces because spreadsheet interaction itself is core product functionality there. citeturn27search4turn27search12turn27search13turn27search5turn27search3turn15view0

So the honest native ceiling is this: **native can match record views and secondary analytics surfaces at full functionality, but not the spreadsheet grid itself without turning Plan 9 into a spreadsheet-product project.** That would be the wrong rabbit hole for v1. The right compromise is to keep the **frame, side panels, chat, selection summaries, field editor, and view switcher native**, and confine the web surface to the single pane where it buys real parity. citeturn27search2turn27search10turn27search14turn15view0

### WKWebView host sketch

A bundled WKWebView host is MAS-safe as long as it loads local assets instead of booting a localhost server. Apple’s docs position WKWebView as the supported in-app renderer for rich web content, and the app already has this pattern. The same bridge should be used for grid edits, selection events, clipboard events, and themed appearance. citeturn27search2turn27search10turn27search14

```swift
import WebKit
import SwiftUI

final class DataGridMessageHandler: NSObject, WKScriptMessageHandler {
    var onMessage: (String, Any) -> Void = { _, _ in }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        onMessage(message.name, message.body)
    }
}

struct DataGridWebView: NSViewRepresentable {
    let assetFolderURL: URL
    let bootstrapJSON: String
    let messageHandler: DataGridMessageHandler

    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(messageHandler, name: "plan9")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // blend with native frame
        let html = assetFolderURL.appendingPathComponent("index.html")
        webView.loadFileURL(html, allowingReadAccessTo: assetFolderURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let js = "window.Plan9?.bootstrap(\(bootstrapJSON));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
```

## Unified local data core

The cleanest implementation is to make **SQLite/GRDB the canonical data model** and treat the spreadsheet engine as a **materialized computational projection**. Donor products validate the underlying premise: one table, many views, same records, with per-view filters, sorts, field visibility, and display rules. Baserow documents views as alternate displays of the same table data, with field, view, and filter types implemented via registries. Teable documents grid, kanban, calendar, and form as alternate projections over table records, and its field model clearly separates link, formula, lookup, and rollup semantics. SQLite gives you foreign keys, JSON functions, generated columns, and strong local embeddability, while GRDB gives migrations, associations, observation, and raw-SQL freedom. citeturn29search8turn29search19turn17search0turn17search1turn17search6turn18search6turn18search1turn18search5turn18search8turn18search0turn18search10turn23search3turn23search12turn23search2turn23search5

### The model tension resolved

| Problem | Recommendation | Why | Confidence |
|---|---|---|---|
| Typed records need stable field semantics in kanban/gallery/calendar/form | Keep a typed relational core in SQLite/GRDB | These views care about field meaning, not arbitrary cell heterogeneity. citeturn29search8turn18search6turn18search1turn18search5turn18search8 | Verified / inferred |
| Spreadsheet needs real A1/range formulas and recalculation | Mirror each table into a hidden IronCalc sheet | That gives real spreadsheet semantics without making the engine the source of truth. citeturn10view2turn10view3turn34search5 | Inferred |
| Airtable-style formulas and relational fields are different from Excel formulas | Keep **formula**, **lookup**, and **rollup** as distinct field kinds | Baserow and Teable both separate these concepts. citeturn29search13turn29search17turn29search4turn29search1turn18search10 | Verified |
| Owner wants real spreadsheet feel in the grid | Support **grid-only helper columns** and helper ranges | They satisfy sheet-style scratch work while keeping non-grid views coherent. | Inferred |
| Need one data core, not divergent sheet files | Persist only metadata and typed record values; regenerate engine projection on demand or incrementally sync it | Prevents two-truth drift. | Inferred |

The key design move is this: **projected typed fields** are what non-grid views understand. **Grid-only helper columns** are allowed for scratch formulas, imported temporary math, and Excel-like workflows, but they remain `visibility_scope = grid_only` until the user or agent explicitly promotes them into schema fields. That gives the owner the spreadsheet feeling without poisoning every table with arbitrary cell-level heterogeneity. It also gives the companion agent a natural power move: “promote helper column H to field `Margin %` as Number and show it in Gallery.” That is much more coherent than trying to make every per-cell formula a first-class database attribute. 

### GRDB and SQLite schema sketch

```swift
import GRDB

enum Plan9Migrations {
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("plan9_v1") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON;")

            try db.create(table: "data_tables") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("slug", .text).notNull().unique()
                t.column("icon", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "data_fields") { t in
                t.column("id", .text).primaryKey()
                t.column("table_id", .text).notNull()
                    .references("data_tables", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("slug", .text).notNull()
                t.column("kind", .text).notNull() // input|formula|lookup|rollup|helper
                t.column("semantic_type", .text).notNull() // text|number|date|single_select|...
                t.column("visibility_scope", .text).notNull()
                    .defaults(to: "all_views") // all_views|grid_only
                t.column("is_primary", .boolean).notNull().defaults(to: false)
                t.column("calc_col", .integer).notNull()   // stable column index in IronCalc sheet
                t.column("config_json", .text).notNull().defaults(to: "{}")
                t.column("formula_source", .text)          // user-facing formula template
                t.column("formula_a1_template", .text)     // compiled relative template
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.uniqueKey(["table_id", "slug"])
                t.uniqueKey(["table_id", "calc_col"])
            }

            try db.create(table: "field_options") { t in
                t.column("id", .text).primaryKey()
                t.column("field_id", .text).notNull()
                    .references("data_fields", onDelete: .cascade)
                t.column("value", .text).notNull()
                t.column("label", .text).notNull()
                t.column("sort_order", .integer).notNull()
                t.column("color_token", .text)
            }

            try db.create(table: "table_records") { t in
                t.column("id", .text).primaryKey()
                t.column("table_id", .text).notNull()
                    .references("data_tables", onDelete: .cascade)
                t.column("calc_row", .integer).notNull()   // stable row index in IronCalc sheet
                t.column("row_order", .double).notNull()
                t.column("archived", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.uniqueKey(["table_id", "calc_row"])
            }

            try db.create(table: "record_values") { t in
                t.column("record_id", .text).notNull()
                    .references("table_records", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                    .references("data_fields", onDelete: .cascade)
                t.column("value_text", .text)
                t.column("value_real", .double)
                t.column("value_int", .integer)
                t.column("value_json", .text)              // arrays, attachments, selects, users
                t.column("display_text", .text)            // cached for UI and search
                t.column("sort_text", .text)
                t.column("sort_real", .double)
                t.column("is_null", .boolean).notNull().defaults(to: false)
                t.primaryKey(["record_id", "field_id"])
            }

            try db.create(table: "record_links") { t in
                t.column("id", .text).primaryKey()
                t.column("source_record_id", .text).notNull()
                    .references("table_records", onDelete: .cascade)
                t.column("source_field_id", .text).notNull()
                    .references("data_fields", onDelete: .cascade)
                t.column("target_record_id", .text).notNull()
                    .references("table_records", onDelete: .cascade)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.uniqueKey(["source_record_id", "source_field_id", "target_record_id"])
            }

            try db.create(table: "data_views") { t in
                t.column("id", .text).primaryKey()
                t.column("table_id", .text).notNull()
                    .references("data_tables", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("view_type", .text).notNull()     // grid|kanban|gallery|calendar|form
                t.column("config_json", .text).notNull().defaults(to: "{}")
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "view_fields") { t in
                t.column("view_id", .text).notNull()
                    .references("data_views", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                    .references("data_fields", onDelete: .cascade)
                t.column("visible", .boolean).notNull().defaults(to: true)
                t.column("width", .integer)
                t.column("position", .integer).notNull()
                t.primaryKey(["view_id", "field_id"])
            }

            try db.create(table: "view_filters") { t in
                t.column("id", .text).primaryKey()
                t.column("view_id", .text).notNull()
                    .references("data_views", onDelete: .cascade)
                t.column("field_id", .text)
                    .references("data_fields", onDelete: .cascade)
                t.column("op", .text).notNull()
                t.column("value_json", .text).notNull().defaults(to: "null")
                t.column("position", .integer).notNull()
            }

            try db.create(table: "view_sorts") { t in
                t.column("id", .text).primaryKey()
                t.column("view_id", .text).notNull()
                    .references("data_views", onDelete: .cascade)
                t.column("field_id", .text).notNull()
                    .references("data_fields", onDelete: .cascade)
                t.column("direction", .text).notNull() // asc|desc
                t.column("position", .integer).notNull()
            }

            try db.create(table: "ingest_sources") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull() // image|pdf|csv|json|paste
                t.column("vault_path", .text)
                t.column("sha256", .text)
                t.column("raw_text", .text)
                t.column("metadata_json", .text).notNull().defaults(to: "{}")
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "record_provenance") { t in
                t.column("record_id", .text).notNull()
                    .references("table_records", onDelete: .cascade)
                t.column("source_id", .text).notNull()
                    .references("ingest_sources", onDelete: .cascade)
                t.column("confidence", .double)
                t.column("mapping_json", .text).notNull().defaults(to: "{}")
                t.primaryKey(["record_id", "source_id"])
            }

            try db.create(table: "operation_log") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull()          // schema|data|ingest
                t.column("summary", .text).notNull()
                t.column("request_json", .text).notNull()
                t.column("inverse_json", .text).notNull()
                t.column("db_before_json", .text)
                t.column("db_after_json", .text)
                t.column("created_at", .datetime).notNull()
            }
        }

        return migrator
    }
}
```

### Formula routing through the engine

The rule should be simple. **Relational fields first, spreadsheet formulas second.** Link, lookup, and rollup fields are computed in the relational layer and materialized as scalar values into the calc sheet. Formula fields then compile against those scalar cells. Grid-only helper columns may contain arbitrary A1 formulas. Projected formula fields should prefer a stable field-template syntax such as `{Revenue} - {Cost}` that is compiled to row-relative A1 references at sync time. That keeps schema changes manageable and lets the agent rewrite formulas safely during field renames. citeturn29search7turn29search4turn29search1turn29search13turn29search17turn18search10

```swift
struct FormulaCompiler {
    let fieldBySlug: [String: DataField]

    func compileFieldTemplate(_ source: String, row: Int) throws -> String {
        // User-facing formula: {revenue} - {cost}
        // Compiled formula: =B12-C12
        let regex = try NSRegularExpression(pattern: #"\{([a-zA-Z0-9_\-]+)\}"#)
        let ns = source as NSString
        var result = source

        for match in regex.matches(in: source, range: NSRange(location: 0, length: ns.length)).reversed() {
            let slug = ns.substring(with: match.range(at: 1))
            guard let field = fieldBySlug[slug] else {
                throw NSError(domain: "FormulaCompiler", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown field \(slug)"])
            }
            let a1 = "\(columnLetters(field.calcCol))\(row)"
            let whole = match.range(at: 0)
            result = (result as NSString).replacingCharacters(in: whole, with: a1)
        }

        return result.hasPrefix("=") ? result : "=\(result)"
    }

    private func columnLetters(_ oneBased: Int) -> String {
        var n = oneBased
        var s = ""
        while n > 0 {
            let rem = (n - 1) % 26
            s = String(UnicodeScalar(65 + rem)!) + s
            n = (n - 1) / 26
        }
        return s
    }
}
```

## Agent operations and ingest

The right agent surface is a **single operation schema** with three execution modes: `dry_run`, `apply`, and `undo`. MAS and Pro should not have different semantics; they should only have different transports. Baserow’s action system is a strong donor here because it treats actions as first-class objects with do/undo/redo, retrieved via registries. Univer’s command model exists for similar reasons: change tracking, undo/redo, and associated logic. Teable’s AI Chat docs make the product-safety point explicit: if a task will modify data or create nodes, ask the AI to list the plan first, then confirm before execution. That is exactly the behavioral contract Plan 9 should adopt. citeturn17search13turn29search2turn16view1turn16view3turn18search7

### Structural operations contract

| Requirement | Recommendation | Why | Confidence |
|---|---|---|---|
| Natural-language restructuring is destructive | Always run **preview/dry-run** first | Gives the user a schema diff, record impact counts, and coercion warnings before commit. citeturn18search7turn17search13 | Verified / inferred |
| MAS and Pro need the same tool surface | One JSON tool schema, one Swift executor, transport-swapped | Keeps behavior identical and simplifies testing. | Inferred |
| Undo must be real, not “best effort” | Store inverse operations and snapshots in `operation_log` | Baserow treats undo/redo as first-class actions for a reason. citeturn17search13 | Verified / inferred |
| Spreadsheet projection must stay coherent | Commit DB transaction and calc sync together | Prevents vault/engine divergence. | Inferred |
| Agent changes need trust | Render plan, diff, and post-apply summary in chat pane and data pane | Teable’s current AI UX leans in this same direction. citeturn18search7 | Verified / inferred |

### Tool schema sketch

```json
{
  "name": "plan9_execute",
  "description": "Preview, apply, or undo structural and data operations against the local Plan 9 vault.",
  "input_schema": {
    "type": "object",
    "required": ["mode"],
    "properties": {
      "mode": {
        "type": "string",
        "enum": ["dry_run", "apply", "undo"]
      },
      "expected_revision": {
        "type": "integer"
      },
      "undo_operation_id": {
        "type": "string"
      },
      "operations": {
        "type": "array",
        "items": {
          "oneOf": [
            {
              "type": "object",
              "required": ["op", "name"],
              "properties": {
                "op": { "const": "create_table" },
                "name": { "type": "string" }
              }
            },
            {
              "type": "object",
              "required": ["op", "table_id", "name", "semantic_type"],
              "properties": {
                "op": { "const": "add_field" },
                "table_id": { "type": "string" },
                "name": { "type": "string" },
                "semantic_type": { "type": "string" },
                "kind": { "type": "string", "default": "input" },
                "visibility_scope": { "type": "string", "default": "all_views" },
                "config": { "type": "object" }
              }
            },
            {
              "type": "object",
              "required": ["op", "field_id", "new_semantic_type"],
              "properties": {
                "op": { "const": "change_field_type" },
                "field_id": { "type": "string" },
                "new_semantic_type": { "type": "string" },
                "coercion_policy": {
                  "type": "string",
                  "enum": ["strict", "best_effort", "null_on_failure"]
                }
              }
            },
            {
              "type": "object",
              "required": ["op", "source_table_id", "source_field_id", "target_table_id"],
              "properties": {
                "op": { "const": "add_link" },
                "source_table_id": { "type": "string" },
                "source_field_id": { "type": "string" },
                "target_table_id": { "type": "string" },
                "multi": { "type": "boolean", "default": true }
              }
            },
            {
              "type": "object",
              "required": ["op", "table_id", "view_type", "name"],
              "properties": {
                "op": { "const": "create_view" },
                "table_id": { "type": "string" },
                "view_type": { "type": "string", "enum": ["grid", "kanban", "gallery", "calendar", "form"] },
                "name": { "type": "string" },
                "config": { "type": "object" }
              }
            },
            {
              "type": "object",
              "required": ["op", "table_id", "records"],
              "properties": {
                "op": { "const": "populate_records" },
                "table_id": { "type": "string" },
                "records": {
                  "type": "array",
                  "items": { "type": "object" }
                }
              }
            },
            {
              "type": "object",
              "required": ["op", "table_id", "script"],
              "properties": {
                "op": { "const": "bulk_transform" },
                "table_id": { "type": "string" },
                "script": { "type": "string" }
              }
            }
          ]
        }
      }
    }
  }
}
```

### Shared MAS and Pro execution path

On **MAS**, the June/`agent_core` path should call the tool **in-process**, not through a localhost MCP server. On **Pro**, OpenChamber/goose/OpenCode can talk to the same executor through your app-hosted MCP adapter. The executor itself should live in Swift alongside GRDB and the vault, with narrow Rust calls out to the calc wrapper when formulas or projections need recompute. This avoids MAS trouble around subprocesses and avoids network/server entitlements for loopback transport. Apple’s docs make App Sandbox required for App Store distribution, note that child-process/helper patterns should prefer XPC over `Process`/`NSTask`-style helpers in sandboxed worlds, and document explicit client/server network entitlements and local-network privacy behavior. If you can keep MAS fully in-process, you should. citeturn20search17turn20search0turn20search18turn20search2turn21search1turn21search4turn21search0turn21search7

```swift
@MainActor
final class Plan9ToolHost {
    private let dbQueue: DatabaseQueue
    private let calcBridge: Plan9CalcBridge
    private let planner: Plan9Planner
    private let executor: Plan9Executor
    private let undoStore: UndoStore

    init(dbQueue: DatabaseQueue, calcBridge: Plan9CalcBridge) {
        self.dbQueue = dbQueue
        self.calcBridge = calcBridge
        self.planner = Plan9Planner()
        self.executor = Plan9Executor(calcBridge: calcBridge)
        self.undoStore = UndoStore()
    }

    func invoke(_ request: DataOpsRequest) throws -> DataOpsResult {
        switch request.mode {
        case .dryRun:
            return try dbQueue.read { db in
                try planner.preview(db: db, request: request)
            }

        case .apply:
            return try dbQueue.write { db in
                let opId = UUID().uuidString
                let preview = try planner.preview(db: db, request: request)

                try db.inTransaction {
                    let inverse = try executor.apply(db: db, request: request, preview: preview)
                    try undoStore.persist(db: db, operationID: opId, inverse: inverse, request: request)
                    return .commit
                }

                return DataOpsResult(
                    operationID: opId,
                    summary: preview.summary,
                    warnings: preview.warnings,
                    applied: true
                )
            }

        case .undo:
            return try dbQueue.write { db in
                let inverse = try undoStore.load(db: db, operationID: request.undoOperationID!)
                try db.inTransaction {
                    _ = try executor.apply(db: db, request: inverse, preview: nil)
                    return .commit
                }
                return DataOpsResult(
                    operationID: request.undoOperationID!,
                    summary: "Undo completed",
                    warnings: [],
                    applied: true
                )
            }
        }
    }
}
```

### Structured and unstructured ingest

The MAS-safe ingest path is straightforward. **Receipt image or photo** goes through Vision text recognition on-device. **PDF** goes through PDFKit text extraction, plus your existing parser stack for higher fidelity. **CSV/JSON** stay native. **Messy pasted text** goes to the existing agent seam for schema proposal and row extraction. Apple documents Vision text recognition through `VNRecognizeTextRequest`, PDFKit’s `PDFDocument`/`PDFPage` APIs for writing/searching/selecting text, and the Foundation Models framework for guided generation and tool calling on-device. That means the entire “OCR → structuring → typed insert” flow can stay local on MAS. citeturn19search5turn19search7turn19search24turn19search1turn19search4turn19search16turn26search0turn26search1turn26search2turn26search8

```swift
import Vision
import PDFKit
import GRDB

struct ImportProposal: Codable {
    struct Field: Codable {
        var name: String
        var semanticType: String
    }
    struct Row: Codable {
        var values: [String: String]
    }

    var tableName: String
    var fields: [Field]
    var rows: [Row]
}

@MainActor
final class ReceiptImporter {
    let toolHost: Plan9ToolHost
    let dbQueue: DatabaseQueue
    let agent: AgentClient // Existing June/agent_core or Pro client seam

    init(toolHost: Plan9ToolHost, dbQueue: DatabaseQueue, agent: AgentClient) {
        self.toolHost = toolHost
        self.dbQueue = dbQueue
        self.agent = agent
    }

    func importReceiptImage(at url: URL) async throws -> DataOpsResult {
        let rawText = try await ocrImage(at: url)

        let proposal: ImportProposal = try await agent.generateStructured(
            system: """
            You convert OCR text into a typed local database proposal.
            Prefer fields like merchant, date, total, tax, subtotal, currency, payment_method, line_items.
            """,
            user: rawText
        )

        let sourceID = UUID().uuidString
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO ingest_sources (id, kind, vault_path, raw_text, metadata_json, created_at)
                VALUES (?, 'image', ?, ?, '{}', CURRENT_TIMESTAMP)
                """,
                arguments: [sourceID, url.path, rawText]
            )
        }

        let dryRun = try toolHost.invoke(
            DataOpsRequest.previewImport(proposal: proposal)
        )

        // The UI should show dryRun first, then the user confirms.
        let result = try toolHost.invoke(
            DataOpsRequest.applyImport(proposal: proposal, sourceID: sourceID)
        )
        return result
    }

    func importPDF(at url: URL) async throws -> DataOpsResult {
        guard let pdf = PDFDocument(url: url) else {
            throw NSError(domain: "ReceiptImporter", code: 1)
        }
        let rawText = pdf.string ?? ""
        // then same agent proposal path as image OCR
        return try await importStructuredText(rawText, sourceKind: "pdf", sourcePath: url.path)
    }

    func importStructuredText(_ rawText: String, sourceKind: String, sourcePath: String?) async throws -> DataOpsResult {
        let proposal: ImportProposal = try await agent.generateStructured(
            system: "Infer a table schema and row data from the provided text.",
            user: rawText
        )
        let dryRun = try toolHost.invoke(.previewImport(proposal: proposal))
        _ = dryRun
        return try toolHost.invoke(.applyImport(proposal: proposal, sourcePath: sourcePath, sourceKind: sourceKind))
    }

    private func ocrImage(at url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                let handler = try VNImageRequestHandler(url: url)
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

## Deep integration, donor patterns, and compliance

The moat is not “a spreadsheet.” The moat is **records as first-class vault objects**. Each record should have a stable vault identity and graph identity even when viewed as a grid row, a kanban card, a calendar event, a form submission, a chat entity, or an inline note embed. Baserow and Teable both reinforce the same lesson: views are alternate surfaces over shared data, not independent apps. Teable’s AI chat also shows the right UX pattern for context-sensitive operations on the current table/view. citeturn29search8turn29search19turn18search7

### What to emulate from donors and what to reject

| Donor | Emulate | Reject | Confidence |
|---|---|---|---|
| Baserow | Registry pattern for field types, view types, filter types, and action types; “same data, many views”; real undo/redo action objects. citeturn17search0turn17search1turn17search6turn17search13turn17search11 | Its Django/PostgreSQL server weight and API-shaped architecture. citeturn17search11turn17search12 | Verified |
| Teable | Clean UI behaviors for grid/kanban/calendar/form, import preview with field type guessing, linked-record UX, AI chat in the current context. citeturn18search6turn18search1turn18search5turn18search8turn18search14turn18search7turn18search0turn18search10 | Any code, because CE is AGPL-3.0 and the product architecture is Postgres/server-oriented. citeturn28search1turn28search3turn30search1turn30search2 | Verified |
| Univer | Grid interaction ideas, command/event model, selection/clipboard behavior, and performance expectations. citeturn16view2turn16view3turn15view0 | The temptation to pull in Pro/server features to paper over local product gaps. citeturn38view0turn38view1turn38view2turn28search2 | Verified |
| Airtable / Notion / Coda | UX references only: inline DB feel, embeds, records-as-objects, companion-copy ergonomics. | Any code or proprietary implementation details. | Inferred / accepted constraint |

### Vault and graph binding sketch

```swift
struct VaultRecordRef: Codable, Hashable {
    let tableID: String
    let recordID: String

    var wikilink: String {
        "[[\(tableID)/\(recordID)]]"
    }

    var uri: String {
        "epistemos://record/\(tableID)/\(recordID)"
    }
}

extension Database {
    func upsertGraphNode(for ref: VaultRecordRef, title: String) throws {
        try execute(
            sql: """
            INSERT INTO graph_nodes (id, kind, title, target_uri)
            VALUES (?, 'record', ?, ?)
            ON CONFLICT(id) DO UPDATE SET title = excluded.title, target_uri = excluded.target_uri
            """,
            arguments: ["record:\(ref.tableID):\(ref.recordID)", title, ref.uri]
        )
    }

    func syncLinkEdges(from source: VaultRecordRef, targets: [VaultRecordRef]) throws {
        try execute(
            sql: "DELETE FROM graph_edges WHERE source_id = ? AND kind = 'record_link'",
            arguments: ["record:\(source.tableID):\(source.recordID)"]
        )
        for target in targets {
            try execute(
                sql: """
                INSERT INTO graph_edges (source_id, target_id, kind)
                VALUES (?, ?, 'record_link')
                """,
                arguments: [
                    "record:\(source.tableID):\(source.recordID)",
                    "record:\(target.tableID):\(target.recordID)"
                ]
            )
        }
    }
}
```

### Inline note embed sketch

Epistemos already has a WKWebView editor surface. The inline embed should therefore be a **note block type** that resolves to the same Plan 9 data core instead of storing copied table HTML. The block only stores `tableId`, `viewId`, and a small rendering config. That keeps the note, tab, chat, and agent all pointed at the same object. 

```swift
struct DataEmbedBlock: Codable, Hashable {
    let tableID: String
    let viewID: String
    let title: String?
    let preferredHeight: Double?
}

struct DataEmbedBlockView: View {
    let block: DataEmbedBlock
    @EnvironmentObject var dataStore: Plan9Store

    var body: some View {
        Group {
            if let snapshot = dataStore.inlineSnapshot(tableID: block.tableID, viewID: block.viewID) {
                InlineDataView(snapshot: snapshot)
                    .frame(minHeight: block.preferredHeight ?? 260)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ProgressView()
                    .frame(minHeight: block.preferredHeight ?? 260)
            }
        }
        .task {
            await dataStore.loadInlineSnapshot(tableID: block.tableID, viewID: block.viewID)
        }
    }
}
```

For charts, start with **Swift Charts** for the analytics set most local PKM/research apps actually need: time series, bars, stacked bars, scatter, pie/donut, and simple dashboards. Apple positions Swift Charts as a native SwiftUI data visualization framework, and recent releases expanded it with more interactivity and larger-data APIs. Do not make Univer charts or ECharts a v1 dependency; Univer charts are in a Pro plugin lane, which is precisely the server/license creep Plan 9 should avoid early. citeturn36search0turn36search1turn36search2turn36search4turn36search5turn15view6

### MAS and Pro verification

| Component | MAS-safe | Pro-safe | Notes | Confidence |
|---|---|---|---|---|
| GRDB + SQLite local vault | Yes | Yes | Embedded local DB, ideal for all-local vault. citeturn23search5turn23search21 | Verified |
| IronCalc wrapper in-process | Yes | Yes | Pure library embedding; no server required. citeturn9search2turn10view2turn10view3turn34search5turn25search0 | Verified / inferred |
| WKWebView with bundled assets | Yes | Yes | Supported in-app web-content wrapper; no local server required. citeturn27search2turn27search10turn27search14 | Verified |
| Vision OCR | Yes | Yes | On-device text recognition. citeturn19search5turn19search7turn19search24 | Verified |
| PDFKit extraction | Yes | Yes | Native PDF access and text/search/select APIs. citeturn19search1turn19search4turn19search16 | Verified |
| Agent DB ops in-process via `agent_core` | Yes | Yes | MAS should use in-memory/in-process tool seam, not localhost or subprocess. citeturn20search17turn20search18turn21search1turn21search4 | Inferred, strongly supported |
| Localhost server for MAS MCP/tooling | **No recommendation** | Yes, if desired | MAS would drag in network server entitlements and possibly local-network/privacy complexity for no product benefit. citeturn21search1turn21search0turn21search7 | Verified / inferred |
| Univer OSS core in WKWebView | Technically yes | Yes | But strategic fit is poor as the main base. | Inferred |
| Univer Pro collaboration/charts/pivots/import-export server path | No | Pro-only | Docs explicitly describe server dependence and Pro plugins. citeturn38view0turn38view1turn38view2turn37search8turn28search2 | Verified |

The MAS conclusion is therefore clean: **agent DB ops, chat, OCR ingest, and PDF ingest can all run in-process with embedded frameworks and libraries**. App Sandbox is required for App Store distribution, and avoiding subprocesses plus localhost services is the right way to stay inside the intended model. citeturn20search17turn20search1turn20search0turn20search18

### Phased build plan and tight v1 scope

The right v1 is not “everything a spreadsheet can ever do.” It is “everything the locked owner decisions require, with one honest sacrifice: the dense grid lives in a WKWebView.”

**Foundation phase.** Ship the GRDB schema, field registry, view registry, operation log, and IronCalc wrapper. Build the native Data tab frame, schema editor, table sidebar, and chat pane. Get CSV/JSON import working. Ship grid view first, but hosted in WKWebView with a native inspector and native field panel.

**View phase.** Add native kanban, gallery, calendar, and form over the same SQLite records and view definitions. Add native Swift Charts dashboards for selected views. Add inline note embeds and graph bindings so records become first-class vault objects.

**Agent phase.** Ship the single tool schema, dry-run preview, confirm/apply, undo, and result rendering. Start with `create_table`, `add_field`, `rename`, `change_field_type`, `create_view`, `populate_records`, and a constrained `bulk_transform`. Delay highly destructive table deletes and relational rewrites until the undo path is battle-tested.

**Ingest phase.** Add Vision OCR for images/receipts, PDFKit extraction for PDFs, messy-text structuring, provenance linking, and table-schema proposals in chat. Make cloud OCR or cloud document parsing a Pro enhancement only.

The tightest defensible v1 field set is: text, long text, number, date, single select, multi select, checkbox, attachment, rating, link-to-record, lookup, rollup, formula, and helper formula columns. The “user” field should exist only if the owner wants local-person references in single-user mode; if “user” is intended to mean multi-user identity, that should be treated as a later sync/collaboration concern rather than faked in v1. Baserow and Teable both show how much value you can get from links, lookups, rollups, and multiple views before you need collaborative account systems. citeturn18search0turn29search7turn29search4turn29search1turn29search17

### Open questions and real limitations

The biggest unresolved product question is not technical. It is semantic: **how much arbitrary per-cell formula freedom should a “typed table” really allow?** My recommendation is explicit: allow full arbitrary formulas only in **grid-only helper columns/ranges**, and keep promoted typed fields schema-stable. If the owner instead wants every field cell to support unique formulas while still behaving like Airtable in non-grid views, the complexity rises substantially.

The biggest implementation risk is also clear: **building or heavily modifying a native spreadsheet grid is the wrong v1 investment.** If the owner later wants to push more of the grid native, that should happen after the data core, agent contract, and multi-view model are already stable.

The main source uncertainty in upstream research is IronCalc UI maturity. The engine posture, Rust API, and embeddability are clear, but public signals around some end-user spreadsheet features remain mixed, especially around advanced display features. That uncertainty is one more reason to use IronCalc as the **engine layer** and keep Plan 9’s persistence, schemas, views, and agent semantics under Epistemos control. citeturn10view4turn10view5turn5search2turn9search6turn34search5

GPT 3- # Plan 9 of Epistemos Execution Dossier

This dossier assumes the fixed Epistemos environment exactly as specified in your uploaded brief: native macOS app, SwiftUI/AppKit front end, Rust `agent_core` via UniFFI, GRDB/SQLite local vault, knowledge graph, two builds, two agent surfaces, no heavy server, and a strict “native as far as full functionality allows” rule. The recommendations below are intentionally designed around those locked constraints rather than relitigating them. fileciteturn1file0L1-L46 fileciteturn1file1L1-L55

The two headline recommendations are straightforward. First, **base the unified-hybrid Data tab on IronCalc, not Univer**. IronCalc is the better fit for Epistemos because it is already Rust, explicitly intended to power bindings and host applications, dual-licensed MIT/Apache-2.0, and its core API is small enough to wrap cleanly behind a UniFFI façade. Univer is impressive and more expansive, but it is fundamentally a TypeScript/browser-plus-Node framework with a canvas renderer and optional commercial “Pro” layer for several spreadsheet features you would want in a serious grid product. That makes it excellent as a web surface and poor as the local-native core of a Swift+Rust app. citeturn48view0turn48view3turn50view0turn47view0turn36view1turn47view3

Second, the **native ceiling map** is real: ship a **native frame**, **native simple views** and **chat**, but use a **themed WKWebView for the dense spreadsheet grid**. AppKit can absolutely host a performant CRUD-heavy tab and can power great kanban, gallery, calendar, form, toolbars, and inspector panels. What it does not give you out of the box is an Excel-grade grid with mature formula editing, range semantics, frozen panes, autofill, and clipboard parity without building a very large control from scratch. Apple’s own `NSTableView` guidance is row/data-source oriented and cell-reuse based; it is not a spreadsheet engine UI. So the honest answer is: native does not “fail” in theory, but it loses on cost, fidelity, and time-to-parity for the one surface where parity matters most. citeturn12view4turn36view1turn48view3turn6view0

## Executive verdicts

| Decision area | Recommendation | Why | Confidence | Sources |
|---|---|---|---|---|
| Spreadsheet engine base | **IronCalc** | Rust-native, intended for bindings and host apps, dual MIT/Apache-2.0, smaller and easier to wrap into UniFFI than a TS/Node/browser framework | Verified-in-source + integration inference | citeturn48view0turn48view3turn50view0turn38view0turn38view1 |
| Dense formula grid | **WKWebView-hosted surface** | Highest functionality parity with lower product risk; native AppKit grid would require a major custom control effort | Inferred from sources + platform experience | citeturn12view4turn36view1turn6view0 |
| Kanban / gallery / calendar / form | **Native AppKit/SwiftUI** | These are record/view presentations, not spreadsheet engines; native parity is achievable without sacrificing core behavior | Inferred, high confidence | citeturn32view0turn31view0turn32view3 |
| Data core | **SQLite/GRDB typed-record core + hidden spreadsheet projection per table** | Keeps one source of truth while giving real cell formulas and Airtable-style typed views | Architectural recommendation | citeturn27view0turn41view0turn41view3turn45view2 |
| Agent ops | **Single app-hosted tool surface shared by MAS and Pro** | Same tools, different orchestrators; MAS runs in-process, Pro can reach same tools over app-hosted MCP | Inferred from locked environment | fileciteturn1file0L11-L23 fileciteturn1file1L1-L28 |
| Ingest | **On-device first** | Vision/PDFKit/native parsers/agent structuring satisfy local-first and MAS constraints | Verified-in-source + environment constraints | citeturn20view3turn21view0turn21view4 fileciteturn1file1L29-L40 |

## Engine choice

### IronCalc and Univer side by side

| Criterion | IronCalc | Univer | Confidence | Sources |
|---|---|---|---|---|
| License | Dual MIT / Apache-2.0 | Apache-2.0 OSS core; Pro commercial layer separate | Verified | citeturn48view0turn50view0turn47view0turn47view1 |
| Architecture | Rust spreadsheet engine + XLSX reader/writer; multiple host “skins” planned | Full-stack isomorphic office SDK for browser and Node; plugin-first, canvas renderer, formula engine, Facade API | Verified | citeturn48view3turn48view1turn50view0turn36view1turn47view2 |
| Headless story | Strong fit: engine-first | Strong in Node/browser, not native Swift/Rust | Verified + inferred | citeturn50view0turn47view2 |
| Grid rendering | IronCalc core does not render a native grid; current public surfaces are terminal/web app style hosts | Canvas-based rendering engine for large editable surfaces | Verified | citeturn48view3turn36view1 |
| Formula/function coverage | Broad Excel-style catalog across lookup/reference, financial, engineering, database, date/time, etc.; still has public “unsupported features” page | Mature sheets surface with formulas, filtering, sorting, data validation, conditional formatting, notes, tables; advanced features such as charts/pivots/edit history/import-export live in Pro | Verified | citeturn48view4turn48view5turn6view0turn36view4turn47view3 |
| Charts / pivots / collaboration | Not yet in 1.0 path | Pro/commercial territory | Verified | citeturn6view0turn47view3 |
| Maturity and activity | Public repo ~3.9k stars; latest v0.7.1 published January 25, 2026 | Public repo ~13.4k stars; latest v0.25.x published June 27, 2026; 1.0 coming soon | Verified | citeturn49view0turn49view1turn8view1turn8view0turn47view0 |
| Fit for Epistemos | Excellent core engine fit | Better as web surface than as native core | Recommendation | citeturn50view0turn38view0turn36view1 |

The most important thing to say concretely about **Univer**, since you had not seen it: it is not “just another spreadsheet widget.” It is an office SDK with sheets/docs/slides, a canvas renderer, plugin architecture, and a facade API that runs in browser and Node. It also has a “Bases” direction for custom structured-data products, which is why it feels so relevant to Plan 9. But its open-source/core boundary is explicit: several features people associate with a serious office/spreadsheet suite, including import/export, charts, pivot tables, collaboration, and certain performance-enhanced formula features, sit in the Pro/commercial layer. That is exactly the wrong boundary to introduce into a local-first proprietary macOS app whose north star is “embed everything and avoid backend heaviness.” citeturn36view1turn47view2turn47view3

IronCalc is much narrower, but that narrowness is an advantage here. Its public docs describe it as core API documentation used to build language bindings and full applications; the basic API already exposes a `Model`, `set_user_input`, `add_sheet`, `evaluate`, workbook styling hooks, and XLSX save. That is exactly the shape you want to put behind a stable local `epistemos_calc` wrapper crate. citeturn50view0turn48view3

The biggest caution on IronCalc is equally clear in its own docs: charts, pivot tables, real-time collaboration, and formula helper UI are still explicitly listed as unsupported/planned. So the right way to use it is **not** to promise “Excel clone parity everywhere”; it is to use it as a **calculation substrate** for a records-first product, and to own the surrounding view system yourself. citeturn6view0turn6view1

### Recommendation

Use **IronCalc as the calculation engine and workbook projection layer**, and build a very thin Epistemos-owned wrapper crate around it. Do **not** bind Swift directly to raw IronCalc internals; export a smaller, stable interface that matches your product semantics: workbook open/save, cell raw input set/get, evaluated display lookup, dirty-range recalc, and sheet projection sync. That gives you Rust/Rust reuse on MAS and Pro, keeps logic inside your app, and avoids anchoring the whole product on a browser-native office runtime. citeturn50view0turn38view0turn39view0

### Swift and Rust integration sketch

```rust
// Cargo.toml for epistemos_calc
[package]
name = "epistemos_calc"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib", "cdylib"]

[dependencies]
ironcalc = "0.7.1"
uniffi = { version = "0.29", features = ["cli"] }
thiserror = "1"
serde = { version = "1", features = ["derive"] }
```


```rust
// src/lib.rs
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use ironcalc::{base::Model, export::save_to_xlsx};
use thiserror::Error;
use uniffi::Object;

#[derive(Debug, Error, uniffi::Error)]
pub enum CalcError {
    #[error("{message}")]
    Generic { message: String },
}

#[derive(uniffi::Record, Clone)]
pub struct CellAddress {
    pub sheet: u32,
    pub row: u32,
    pub col: u32,
}

#[derive(uniffi::Record, Clone)]
pub struct CellValue {
    pub raw_input: Option<String>,
    pub display: String,
}

#[derive(uniffi::Record, Clone)]
pub struct RecalcEvent {
    pub dirty: Vec<CellAddress>,
}

#[uniffi::export(callback_interface)]
pub trait RecalcSink: Send + Sync {
    fn on_recalc(&self, event: RecalcEvent);
}

#[derive(Object)]
pub struct WorkbookHandle {
    model: Mutex<Model>,
    sink: Mutex<Option<Box<dyn RecalcSink>>>,
}

#[uniffi::export]
impl WorkbookHandle {
    #[uniffi::constructor]
    pub fn new_empty(name: String) -> Result<Arc<Self>, CalcError> {
        let model = Model::new_empty(&name, "en", "UTC", "en")
            .map_err(|e| CalcError::Generic { message: e.to_string() })?;
        Ok(Arc::new(Self {
            model: Mutex::new(model),
            sink: Mutex::new(None),
        }))
    }

    pub fn set_recalc_sink(&self, sink: Box<dyn RecalcSink>) {
        *self.sink.lock().unwrap() = Some(sink);
    }

    pub fn add_sheet(&self, name: String) -> Result<(), CalcError> {
        self.model.lock().unwrap()
            .add_sheet(&name)
            .map_err(|e| CalcError::Generic { message: e.to_string() })
    }

    pub fn set_user_input(&self, addr: CellAddress, input: String) -> Result<(), CalcError> {
        let mut model = self.model.lock().unwrap();
        model.set_user_input(addr.sheet, addr.row, addr.col, input)
            .map_err(|e| CalcError::Generic { message: e.to_string() })
    }

    pub fn evaluate(&self) -> Result<(), CalcError> {
        let mut model = self.model.lock().unwrap();
        model.evaluate();
        // In production, diff cached evaluated cells and emit actual dirty set.
        if let Some(sink) = self.sink.lock().unwrap().as_ref() {
            sink.on_recalc(RecalcEvent { dirty: vec![] });
        }
        Ok(())
    }

    pub fn save_to_xlsx(&self, path: String) -> Result<(), CalcError> {
        let model = self.model.lock().unwrap();
        save_to_xlsx(&model, PathBuf::from(path))
            .map_err(|e| CalcError::Generic { message: e.to_string() })
    }
}

uniffi::setup_scaffolding!();
```


```swift
// Swift host usage
import Foundation

final class GridCalcBridge: RecalcSink {
    var onRecalc: (([CellAddress]) -> Void)?

    func onRecalc(event: RecalcEvent) {
        onRecalc?(event.dirty)
    }
}

let wb = try WorkbookHandle(name: "plan9.xlsx")
let sink = GridCalcBridge()
sink.onRecalc = { dirty in
    // invalidate visible ranges in native/web grid host
}
wb.setRecalcSink(sink: sink)

try wb.setUserInput(
    addr: CellAddress(sheet: 0, row: 2, col: 1),
    input: "=SUM(A1:A10)"
)
try wb.evaluate()
```

This is the right architectural shape even though the exact getter surface you will wrap around IronCalc should be finalized against the current crate API during implementation. UniFFI’s Xcode guidance explicitly supports compiling a Rust crate into a static library, generating Swift bindings, and including the generated bridging header in Xcode. citeturn50view0turn38view0turn38view1turn39view0turn40view0

## Native ceiling map

### Per-surface verdict

| Surface | Best choice | Functionality parity | Effort | Risk | Confidence | Sources |
|---|---|---|---|---|---|---|
| Window/tab/toolbar chrome | Native | Full | Low | Low | High | fileciteturn1file0L1-L23 |
| Dense editable formula grid | Hybrid with **web grid** inside native shell | Highest with web; native achievable only through major custom control | Very high if native-first | High | Medium-high | citeturn12view4turn36view1turn6view0 |
| Kanban | Native | Full enough for v1 | Moderate | Low | Medium-high | citeturn32view0turn31view0 |
| Gallery | Native | Full enough for v1 | Moderate | Low | Medium-high | citeturn32view0 |
| Calendar | Native | Full enough for v1 | Moderate | Low | Medium-high | citeturn32view0turn32view5 |
| Form | Native | Full enough for v1 | Moderate | Low | High | citeturn31view0 |
| Chat | Native | Full | Low | Low | High | fileciteturn1file1L1-L28 |

The key engineering judgment is the grid. `NSTableView` is built around `numberOfRowsInTableView:` and `tableView:viewForTableColumn:row:`. It reuses views and is good at dense tabular presentation, but Apple’s programming guide is still describing a table/list control, not a spreadsheet interaction model. There is nothing in that surface that gives you formula bar semantics, region fill, multi-range clipboard fidelity, frozen panes, cell references during edit, or workbook-style recalc invalidation. You can absolutely build all of that on AppKit, but at that point you are no longer “using `NSTableView`”; you are writing a spreadsheet application control. citeturn12view4

So the honest native ceiling is this: **native AppKit can match an excellent record grid; it does not economically match an Excel-grade sheet surface in v1 without becoming a separate product effort.** That does not mean “web everything.” It means preserve the owner’s rule precisely: use native shell, native simple views, native inspectors, native command routing, native selection state and chat, but put the one surface that has a true functionality cliff behind a well-themed local WKWebView. citeturn36view1turn12view3turn6view0

### Recommended composition

Use a split architecture:

- **Native frame**: toolbar, sidebar, view switcher, inspectors, breadcrumbs, record detail sheets, command menus, drag/drop entry points, chat dock.
- **Native views**: kanban, gallery, calendar, form, chart panel, record detail.
- **Web view only where needed**: the dense formula grid, backed by local packaged assets and local app-to-web bridges.
- **Shared data model beneath both**: one SQLite/GRDB store and one IronCalc-backed sheet projection.

That composition beats the “all-native grid” hypothesis on risk, and beats the “all-web database tab” hypothesis on app feel. citeturn12view3turn36view1turn47view3

### WKWebView grid host sketch

```swift
import WebKit
import SwiftUI

final class DataGridCoordinator: NSObject, WKScriptMessageHandler {
    let webView: WKWebView
    private let bridge: DataToolBridge

    init(bridge: DataToolBridge) {
        self.bridge = bridge

        let content = WKUserContentController()
        let config = WKWebViewConfiguration()
        content.add(self, name: "epistemos")
        config.userContentController = content
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.setValue(false, forKey: "allowUniversalAccessFromFileURLs")

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.setValue(false, forKey: "drawsBackground")
        webView.loadFileURL(
            Bundle.main.url(forResource: "data-grid", withExtension: "html")!,
            allowingReadAccessTo: Bundle.main.resourceURL!
        )
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "epistemos",
              let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else { return }

        switch kind {
        case "setCell":
            Task {
                try await bridge.setCell(
                    tableId: body["tableId"] as! String,
                    row: body["row"] as! Int64,
                    fieldId: body["fieldId"] as! String,
                    rawInput: body["rawInput"] as! String
                )
            }
        case "requestViewport":
            Task {
                let payload = try await bridge.viewportPayload(
                    tableId: body["tableId"] as! String,
                    rowStart: body["rowStart"] as! Int,
                    rowCount: body["rowCount"] as! Int,
                    colStart: body["colStart"] as! Int,
                    colCount: body["colCount"] as! Int
                )
                let json = String(data: try JSONEncoder().encode(payload), encoding: .utf8)!
                webView.evaluateJavaScript("window.Epistemos.applyViewport(\(json))")
            }
        default:
            break
        }
    }
}
```

## Unified hybrid data core

### The core modeling decision

The hardest tension in this project is real: a spreadsheet is a cell graph, while an Airtable-style base is typed records plus relational views. The clean answer is **not** to choose one and fake the other. The clean answer is to keep **typed records as the canonical persistence model** and maintain a **hidden sheet projection per table** for formula/evaluation semantics.

That gives you one data core and two valid projections:

- **Record projection**: tables, fields, typed values, links, views, filters, sorts, grouping.
- **Sheet projection**: rows map to records, columns map to fields, every visible cell has raw input and evaluated output, and IronCalc computes formulas.

This is also how to reconcile “real spreadsheet feel” with “Airtable-style data model.” Baserow’s formula-field docs are a useful donor pattern here: one formula can apply to a whole field, and each row’s value is computed from same-row references. But Epistemos should go one step further and let the grid expose genuine cell formulas where the field kind allows it. citeturn45view2turn31view0turn32view0

### Concrete recommended rules

The defensible v1 rules are:

- Every table has ordered fields.
- Every record has an immutable `sheet_row_index` in the canonical workbook projection.
- Every field has a `field_kind` and optionally a `formula_mode`.
- Every cell stores `raw_input` and a typed/evaluated cache.
- A “formula field” is a field-level template propagated to all rows.
- A normal typed field may still accept a formula if the resulting computed value conforms to the field’s type.
- Linked-record, lookup, and rollup fields are **relational first** and mirrored into the sheet as read-only computed cells.
- Per-view sorting/filtering/grouping **does not rewrite canonical A1 coordinates**; the sheet order remains stable beneath views.

That last rule matters. If “sort the view” renumbered A1 references, the spreadsheet semantics would become untrustworthy. A view is therefore a projection over records, not a mutation of the canonical sheet order. citeturn41view0turn41view1turn45view2

### SQLite schema sketch

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE data_table (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL
);

CREATE TABLE data_field (
  id TEXT PRIMARY KEY,
  table_id TEXT NOT NULL REFERENCES data_table(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  ordinal INTEGER NOT NULL,
  kind TEXT NOT NULL,               -- text, number, date, checkbox, select, multiselect,
                                    -- link, lookup, rollup, formula, attachment, rating, user
  config_json TEXT NOT NULL DEFAULT '{}',
  formula_template TEXT,            -- optional field-level formula
  is_formula_locked INTEGER NOT NULL DEFAULT 0,
  is_primary INTEGER NOT NULL DEFAULT 0,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  UNIQUE(table_id, ordinal),
  UNIQUE(table_id, name)
);

CREATE TABLE data_record (
  id TEXT PRIMARY KEY,
  table_id TEXT NOT NULL REFERENCES data_table(id) ON DELETE CASCADE,
  sheet_row_index INTEGER NOT NULL, -- canonical workbook row mapping
  sort_key REAL NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  deleted_at REAL,
  UNIQUE(table_id, sheet_row_index)
);

CREATE TABLE record_cell (
  record_id TEXT NOT NULL REFERENCES data_record(id) ON DELETE CASCADE,
  field_id  TEXT NOT NULL REFERENCES data_field(id)  ON DELETE CASCADE,
  raw_input TEXT,                   -- literal or "=SUM(A1:A10)"
  typed_json TEXT,                  -- canonical typed cache
  display_text TEXT NOT NULL DEFAULT '',
  eval_status TEXT NOT NULL DEFAULT 'clean', -- clean, dirty, error
  error_text TEXT,
  source_kind TEXT NOT NULL DEFAULT 'user',  -- user, formula_template, lookup, rollup, import
  updated_at REAL NOT NULL,
  PRIMARY KEY(record_id, field_id)
);

CREATE TABLE record_link (
  id TEXT PRIMARY KEY,
  from_record_id TEXT NOT NULL REFERENCES data_record(id) ON DELETE CASCADE,
  from_field_id  TEXT NOT NULL REFERENCES data_field(id)  ON DELETE CASCADE,
  to_record_id   TEXT NOT NULL REFERENCES data_record(id) ON DELETE CASCADE,
  created_at REAL NOT NULL,
  UNIQUE(from_record_id, from_field_id, to_record_id)
);

CREATE TABLE data_view (
  id TEXT PRIMARY KEY,
  table_id TEXT NOT NULL REFERENCES data_table(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,               -- grid, kanban, gallery, calendar, form
  config_json TEXT NOT NULL,        -- hidden fields, card cover, calendar date field, etc.
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL
);

CREATE TABLE view_filter (
  id TEXT PRIMARY KEY,
  view_id TEXT NOT NULL REFERENCES data_view(id) ON DELETE CASCADE,
  field_id TEXT NOT NULL REFERENCES data_field(id) ON DELETE CASCADE,
  op TEXT NOT NULL,
  value_json TEXT NOT NULL,
  position INTEGER NOT NULL,
  logical_group TEXT NOT NULL DEFAULT 'root'
);

CREATE TABLE view_sort (
  id TEXT PRIMARY KEY,
  view_id TEXT NOT NULL REFERENCES data_view(id) ON DELETE CASCADE,
  field_id TEXT NOT NULL REFERENCES data_field(id) ON DELETE CASCADE,
  direction TEXT NOT NULL,          -- asc, desc
  position INTEGER NOT NULL
);

CREATE TABLE view_group (
  id TEXT PRIMARY KEY,
  view_id TEXT NOT NULL REFERENCES data_view(id) ON DELETE CASCADE,
  field_id TEXT NOT NULL REFERENCES data_field(id) ON DELETE CASCADE,
  position INTEGER NOT NULL
);

CREATE TABLE field_option (
  id TEXT PRIMARY KEY,
  field_id TEXT NOT NULL REFERENCES data_field(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  color TEXT,
  position INTEGER NOT NULL
);

CREATE TABLE attachment_blob (
  id TEXT PRIMARY KEY,
  vault_path TEXT NOT NULL,
  mime_type TEXT,
  byte_size INTEGER,
  sha256 TEXT,
  created_at REAL NOT NULL
);

CREATE TABLE record_attachment (
  record_id TEXT NOT NULL REFERENCES data_record(id) ON DELETE CASCADE,
  field_id  TEXT NOT NULL REFERENCES data_field(id)  ON DELETE CASCADE,
  blob_id   TEXT NOT NULL REFERENCES attachment_blob(id) ON DELETE CASCADE,
  position  INTEGER NOT NULL,
  PRIMARY KEY(record_id, field_id, blob_id)
);

CREATE TABLE provenance_source (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,               -- image, pdf, csv, pasted_text, json
  vault_path TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at REAL NOT NULL
);

CREATE TABLE provenance_edge (
  source_id TEXT NOT NULL REFERENCES provenance_source(id) ON DELETE CASCADE,
  record_id TEXT NOT NULL REFERENCES data_record(id) ON DELETE CASCADE,
  field_id  TEXT REFERENCES data_field(id) ON DELETE SET NULL,
  confidence REAL,
  PRIMARY KEY(source_id, record_id, field_id)
);

CREATE TABLE schema_tx_log (
  id TEXT PRIMARY KEY,
  created_at REAL NOT NULL,
  actor TEXT NOT NULL,              -- user, june, openchamber
  dry_run_json TEXT NOT NULL,
  inverse_ops_json TEXT NOT NULL,
  applied_at REAL,
  reverted_at REAL
);
```

SQLite’s foreign keys must be enabled per connection, and JSON can live cleanly in SQLite text/JSONB representations with `json_*` helpers when that is useful for view configs and field configs. citeturn41view0turn41view1turn41view2turn41view3turn41view4

### Formula routing

```swift
struct FormulaRouter {
    let db: DatabaseQueue
    let calc: WorkbookHandle

    func syncTableToSheet(tableId: String) throws {
        try db.write { db in
            let fields = try Field
                .filter(Column("table_id") == tableId)
                .order(Column("ordinal"))
                .fetchAll(db)

            let records = try Record
                .filter(Column("table_id") == tableId && Column("deleted_at") == nil)
                .order(Column("sheet_row_index"))
                .fetchAll(db)

            for (colIndex, field) in fields.enumerated() {
                for record in records {
                    let sheetRow = UInt32(record.sheetRowIndex)
                    let sheetCol = UInt32(colIndex + 1)
                    let input = try RecordCell
                        .filter(Column("record_id") == record.id && Column("field_id") == field.id)
                        .fetchOne(db)?
                        .rawInput ?? ""

                    try calc.setUserInput(
                        addr: CellAddress(sheet: 0, row: sheetRow, col: sheetCol),
                        input: input
                    )
                }
            }
        }

        try calc.evaluate()
        try pullEvaluatedCellsBack()
    }

    private func pullEvaluatedCellsBack() throws {
        // Production implementation should read display/evaluated values from the wrapper crate
        // and write back to record_cell.display_text / typed_json / error_text.
    }
}
```

The important product policy is this: **IronCalc owns spreadsheet-style formula evaluation; GRDB/SQLite own relational semantics.** Linked-record traversal, lookup, and rollup should be evaluated relationally and then mirrored into the grid, not forced awkwardly through Excel formulas in v1. That is how you keep the hybrid model coherent instead of magical. citeturn45view2turn31view0turn32view3

## Agent layer and ingest

### Shared agent tool surface

The app should expose one tool contract regardless of build. MAS and Pro differ only in orchestration:

- **MAS**: June + `agent_core` call tools in-process.
- **Pro**: OpenChamber + goose/OpenCode call the exact same tools over the app-hosted MCP seam.

That means the tool layer is product infrastructure, not model infrastructure. This is the right moat. fileciteturn1file0L11-L23 fileciteturn1file1L1-L28

```json
{
  "tools": [
    {
      "name": "plan_schema_change",
      "description": "Return a dry-run migration plan for natural-language database restructuring.",
      "input_schema": {
        "type": "object",
        "properties": {
          "intent": { "type": "string" },
          "operations": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "op": {
                  "type": "string",
                  "enum": [
                    "create_table",
                    "rename_table",
                    "delete_table",
                    "add_field",
                    "rename_field",
                    "delete_field",
                    "change_field_type",
                    "set_formula",
                    "add_link",
                    "create_view",
                    "update_view",
                    "bulk_transform",
                    "populate_records"
                  ]
                },
                "args": { "type": "object" }
              },
              "required": ["op", "args"]
            }
          }
        },
        "required": ["intent", "operations"]
      }
    },
    {
      "name": "apply_schema_change",
      "description": "Apply a previously previewed plan atomically.",
      "input_schema": {
        "type": "object",
        "properties": {
          "plan_id": { "type": "string" },
          "user_confirmed": { "type": "boolean" }
        },
        "required": ["plan_id", "user_confirmed"]
      }
    },
    {
      "name": "undo_schema_change",
      "description": "Rollback the latest applied change-set or a specific transaction id.",
      "input_schema": {
        "type": "object",
        "properties": {
          "tx_id": { "type": "string" }
        }
      }
    },
    {
      "name": "query_data",
      "description": "Run a safe table/query operation and return structured rows for chat rendering.",
      "input_schema": {
        "type": "object",
        "properties": {
          "table_id": { "type": "string" },
          "select": { "type": "array", "items": { "type": "string" } },
          "filters": { "type": "array", "items": { "type": "object" } },
          "sort": { "type": "array", "items": { "type": "object" } },
          "limit": { "type": "integer" }
        },
        "required": ["table_id"]
      }
    }
  ]
}
```

### Preview, confirm, apply, undo

Destructive NL DB operations need a real migration discipline. The right flow is:

1. **Plan**: the agent produces structured ops and the app compiles them into dry-run SQL/GRDB mutations, a field/view diff, data-loss warnings, and a reversible inverse-op log.
2. **Confirm**: the UI presents the plan as a schema diff, not as raw natural language.
3. **Apply**: run inside one SQLite transaction.
4. **Undo**: persist inverse ops in `schema_tx_log`, then execute them in another transaction.

SQLite deferred foreign keys and transactional DDL/data mutation patterns are enough for this if you design your migrations carefully and never treat the LLM call as the source of truth. The source of truth is the validated op plan. citeturn41view0

```swift
struct PlannedChange: Codable {
    let id: String
    let dryRunSummary: String
    let operations: [SchemaOp]
    let inverseOps: [SchemaOp]
    let warnings: [String]
}

final class DataSchemaExecutor {
    let db: DatabaseQueue

    func plan(_ ops: [SchemaOp], actor: String) throws -> PlannedChange {
        let inverse = try makeInverseOps(for: ops)
        let summary = try renderDryRunSummary(ops)
        let plan = PlannedChange(
            id: UUID().uuidString,
            dryRunSummary: summary,
            operations: ops,
            inverseOps: inverse,
            warnings: try collectWarnings(ops)
        )
        try db.write { db in
            try SchemaTxLog(
                id: plan.id,
                createdAt: Date().timeIntervalSince1970,
                actor: actor,
                dryRunJSON: try JSONEncoder().encode(plan).utf8String,
                inverseOpsJSON: try JSONEncoder().encode(inverse).utf8String
            ).insert(db)
        }
        return plan
    }

    func apply(plan: PlannedChange) throws {
        try db.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            for op in plan.operations {
                try apply(op, db: db)
            }
            try markApplied(plan.id, db: db)
        }
    }

    func undo(txId: String) throws {
        let inverseOps = try loadInverseOps(txId)
        try db.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            for op in inverseOps {
                try apply(op, db: db)
            }
            try markReverted(txId, db: db)
        }
    }
}
```

### Ingest pipeline

The ingest story is one of the strongest parts of the plan because it maps unusually well to your constraints.

- **Receipt photo / image**: on-device OCR first, then agent structuring, then schema proposal, then insert typed records with provenance.
- **PDF**: prefer the app’s existing parse stack; use PDFKit for native viewing and extraction, and rely on PDFKit’s Live Text support for scanned PDFs when appropriate.
- **CSV / JSON**: native parse directly into typed candidate schema.
- **Pasted messy text**: ask the agent to infer rows/fields using a dynamic schema or normal structured tool call.

Apple’s PDFKit session explicitly describes PDFKit as a full-featured framework for viewing, editing, and writing PDFs, and says Live Text in PDFs works on demand without OCR-ing the whole document up front. Apple’s Foundation Models session explicitly describes on-device structured output, dynamic schemas, and tool calling. That combination is exactly what you want for MAS-safe ingest and local-first structuring. citeturn20view3turn21view0turn21view1turn21view2turn21view4

```swift
import Vision
import AppKit
import GRDB

struct ReceiptLine: Codable {
    let merchant: String?
    let total: Decimal?
    let date: String?
    let category: String?
}

final class ReceiptIngestor {
    let db: DatabaseQueue
    let agent: StructuredAgent

    func ingestReceiptImage(url: URL, into tableId: String) async throws {
        let image = NSImage(contentsOf: url)!
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        let schema = """
        Extract one receipt record with fields:
        merchant (string), total (number), date (string), category (string).
        Return null for unknown values.
        """

        let record: ReceiptLine = try await agent.generateStructured(
            prompt: "Convert this OCR into a receipt record:\n\(text)",
            schema: schema
        )

        try db.write { db in
            let sourceId = UUID().uuidString
            try ProvenanceSource(
                id: sourceId,
                kind: "image",
                vaultPath: url.path,
                metadataJSON: "{}",
                createdAt: Date().timeIntervalSince1970
            ).insert(db)

            let recordId = UUID().uuidString
            try DataRecord(
                id: recordId,
                tableId: tableId,
                sheetRowIndex: nextSheetRowIndex(db, tableId: tableId),
                sortKey: Date().timeIntervalSince1970,
                createdAt: Date().timeIntervalSince1970,
                updatedAt: Date().timeIntervalSince1970,
                deletedAt: nil
            ).insert(db)

            try upsertCell(db, recordId, tableId, "Merchant", record.merchant)
            try upsertCell(db, recordId, tableId, "Total", record.total?.description)
            try upsertCell(db, recordId, tableId, "Date", record.date)
            try upsertCell(db, recordId, tableId, "Category", record.category)

            try ProvenanceEdge(
                sourceId: sourceId,
                recordId: recordId,
                fieldId: nil,
                confidence: 0.86
            ).insert(db)
        }
    }
}
```

The right product behavior here is not “auto-import without friction.” It is **propose schema → preview mapping → insert → keep source attached**. That keeps ingest powerful without turning local data entry into a hallucination machine. citeturn21view4turn20view3

## Vault integration and donor patterns

### Records as first-class vault objects

This project gets much stronger if records are not “just database rows.” They should be vault objects with stable IDs, backlinks, graph presence, and note-embed identities. Then the same data core is reachable four ways: the tab, inline note blocks, chat, and agent tools. That is the correct Epistemos moat, because Teable/Baserow-style products do not naturally live inside a local PKM graph in the same way. fileciteturn1file1L41-L55

```swift
struct VaultRecordRef: Codable, Hashable {
    let tableId: String
    let recordId: String
}

struct GraphEdge: PersistableRecord {
    var id: String
    var fromNodeId: String
    var toNodeId: String
    var kind: String // linked_record, note_reference, attachment_source
}

func wikilink(for ref: VaultRecordRef, primaryValue: String) -> String {
    "[[\(primaryValue)|record:\(ref.tableId):\(ref.recordId)]]"
}
```

### Inline note-embed block

Because your editor already lives in a WKWebView/Tiptap world, the most practical note embed is a dedicated block node that stores a `viewId` and render mode, while the actual data comes from the same local store. That preserves one data core rather than copying tables into notes. fileciteturn1file0L1-L10

```ts
// Tiptap extension sketch
import { Node } from '@tiptap/core'

export const DataViewBlock = Node.create({
  name: 'dataViewBlock',
  group: 'block',
  atom: true,

  addAttributes() {
    return {
      viewId: { default: null },
      mode: { default: 'grid' },
      height: { default: 320 }
    }
  },

  parseHTML() {
    return [{ tag: 'epistemos-data-view' }]
  },

  renderHTML({ HTMLAttributes }) {
    return ['epistemos-data-view', HTMLAttributes]
  }
})
```


```swift
struct NoteEmbedDescriptor: Codable {
    let viewId: String
    let mode: String
    let height: Double
}

final class NoteEmbedResolver {
    func renderEmbed(_ d: NoteEmbedDescriptor) -> NSView {
        DataViewEmbedHost(viewId: d.viewId, mode: d.mode, preferredHeight: d.height)
    }
}
```

### What to borrow from Baserow and Teable

Baserow is the better **code-structure donor** because its plugin docs explicitly show field types, view types, and filter types as registries with backend/frontend registration points. That registry pattern is exactly the right mental model for Epistemos field kinds, view renderers, and ingest adapters, even though your implementation will be Swift/Rust instead of Django/Vue. Baserow’s formula docs are also a strong donor for the “one formula for a whole field” mental model. citeturn31view0turn32view5turn32view3turn45view2

Teable is the better **UX/behavior donor** but only in clean-room form. Its repo makes clear that it is an AGPL product with AGPL apps/plugins and a Postgres/Next.js/NestJS deployment story. That is precisely the opposite of your MAS-safe architecture, so the right move is to study behaviors and interaction patterns, not code. citeturn30view4turn30view5turn30view6turn30view7

The donor summary is simple:

- Borrow from **Baserow**: registry thinking, field/view/filter abstraction boundaries, relational view semantics, and formula-field UX concepts. citeturn31view0turn32view5turn32view3turn30view3
- Borrow from **Teable**: modern Airtable-like UX behavior only, not implementation. citeturn30view4turn30view5
- Reference from **Airtable/Notion/Coda**: product feel, not code. This is design guidance, not source borrowing. fileciteturn1file1L1-L15

## Compliance, phased build, and open questions

### MAS and license verification

| Item | MAS-safe? | Notes | Confidence | Sources |
|---|---|---|---|---|
| GRDB + SQLite local vault | Yes | Embedded local DB toolkit; no server required | High | citeturn27view0turn41view0turn41view3 |
| IronCalc wrapper crate | Yes | Local Rust static lib is compatible with UniFFI/Xcode integration model | High | citeturn50view0turn38view0turn38view1 |
| WKWebView-hosted local grid | Yes | Embedded view, no local server required if assets are bundled | High | citeturn12view3 |
| Vision/PDFKit/on-device ingest | Yes | On-device frameworks; no server required | Medium-high | citeturn20view3turn21view0 |
| June + `agent_core` in-process tools | Yes by design assumption | This is part of the fixed product spec; nothing in the proposed stack adds a server/subprocess dependency | Medium-high | fileciteturn1file0L11-L23 fileciteturn1file1L29-L40 |
| OpenChamber + goose/OpenCode | Pro-only | Fine for Developer ID build; not needed for MAS path | High | fileciteturn1file0L11-L23 |
| IronCalc license | Safe | MIT or Apache-2.0 | Verified | citeturn48view0turn50view0 |
| Univer license | Safe in OSS core, but not recommended as base | Apache-2.0 OSS; important features segmented into Pro/commercial | Verified | citeturn47view0turn47view3 |
| Baserow core license | Safe to study/borrow where MIT-covered | MIT for non-premium / non-enterprise features | Verified | citeturn30view3 |
| Teable code reuse | **No** | Clean-room only; AGPL footprint across app/plugin surfaces | Verified | citeturn30view4turn30view5 |

My bottom-line verification is therefore: **the all-embedded stack is viable for MAS if you keep everything in-process, bundle local assets, and do not introduce a local server or subprocess requirement.** The proposed architecture satisfies that. The only parts that are meaningfully Pro-only are the external agent orchestration route and any optional cloud OCR/parse enhancements. fileciteturn1file0L11-L23 fileciteturn1file1L29-L40

### Tight v1 scope

A disciplined v1 should ship these first:

- Views: **grid, kanban, calendar, form**; gallery can follow quickly if attachment cover art is already present.
- Field kinds: text, number, date, checkbox, single-select, multi-select, link, attachment, formula, rating.
- Agent ops: create/rename table, add/rename/delete field, change field type with dry-run warnings, create/update view, populate records, bulk transform.
- Ingest: CSV/JSON/pasted text day one; image receipt and PDF shortly after if OCR/provenance path is already solid.
- Charts: native summary charts outside the grid, not embedded spreadsheet chart objects.

That gives you the whole thesis of the product without overcommitting to the hardest edges like pivot tables, embedded spreadsheet charts, arbitrary cross-table formulas, or spreadsheet-style collaborative editing. citeturn6view0turn47view3turn31view0turn32view0

### Phased build plan

**Phase one** should build the data core and tool surface first, not the prettiest views first. Stand up the SQLite schema, record/view system, and agent tool contracts; then wire CSV/JSON import and a native simple grid for validation. This de-risks the modeling tension early. citeturn27view0turn41view0turn45view2

**Phase two** should add the IronCalc projection layer and the hosted web spreadsheet grid. Only once raw input, evaluated caches, canonical row mapping, and dirty-range refresh work should the project try to hit “real spreadsheet feel.” citeturn50view0turn36view1

**Phase three** should add the native alternative views and note/graph integration. That is where Epistemos becomes differentiated rather than just “local Airtable.” fileciteturn1file1L41-L55

**Phase four** should add the ingest luxuries and higher-risk computed fields: image/PDF extraction, better lookup/rollup functions, charts, and richer agent transforms. citeturn20view3turn21view4

### Open questions and limitations

A few points remain genuinely open.

The first is **how far you want to allow arbitrary per-cell formulas in typed fields**. My recommendation above allows them where output type remains valid, but that is a product decision, not a purely technical one.

The second is **cross-table formula semantics**. A clean v1 should keep linked-record/lookup/rollup as relational computations, not promise arbitrary Excel-like formulas over linked collections.

The third is **how much of the spreadsheet UI you want inside the hosted grid versus in native chrome**. I recommend putting formula bar, name box, sheet tabs, and autofill behavior with the hosted grid, while keeping record previews, inspectors, and chat native.

The fourth is **Foundation Models versus your existing agent stack for local structuring on MAS**. Apple’s framework clearly supports on-device structured output and tool calling, but the product already has June + `agent_core`. The best answer may be: keep `agent_core` primary and use Foundation Models opportunistically for narrow local extract/normalize tasks where latency and privacy matter most. citeturn21view0turn21view1turn21view2

If I reduce the whole dossier to one sentence, it is this: **build Plan 9 as a records-first local database with a real spreadsheet projection, not as a spreadsheet app with database cosmetics.** IronCalc gives you the right local computation substrate, and the native ceiling map says the dense grid should be the one carefully-contained web surface inside an otherwise native Epistemos feature. citeturn50view0turn36view1turn45view2
