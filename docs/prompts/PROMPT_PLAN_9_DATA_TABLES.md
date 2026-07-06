# PLAN 9 — The "Data" Tab: Agent-Native Spreadsheet+Database on IronCalc × silent-Univer

**Date:** 2026-07-03 · **Status: CANONICAL** · **Sequence: build AFTER the two agent
builds** (Plan 1-PRO + Plan 1-MAS) — the agent chat/tools/mascot payoff needs real
agents; the §9 Stage-0/1 foundation (data core + engine bridge) may start earlier.

**Verification basis (do not re-litigate without new evidence):** synthesized from a
4-dossier corpus — 3 GPT singletons + **the owner's Claude synthesis (highest-compute
input, adopted as the architectural spine)** — then **re-verified 2026-07-03 against
fresh local clones**: `ironcalc@1bd4bb6`, `univer@6ae8eb3`, `teable@498e255`,
`baserow@d5901c0` (all in `.research-clones/work/`, all ≤3 days old). Full adjudication
+ per-claim citations: `docs/research/PLAN9_ADJUDICATION_WORKING_2026_07_03.md`.
Owner intent frame: `docs/prompts/PROMPT_PLAN_9_DATA_TABLES_RESEARCH.md`.

---

## §0 LOCKED DECISIONS

1. **A dedicated "Data" tab/room** — integrated like arXiv/Browser/Notes. One SQLite
   data core, **four doors**: the tab · inline note embeds · the in-tab agent chat ·
   the agent tools. Records are first-class vault objects (wikilinks, graph nodes).
2. **Unified hybrid** — any table is an Excel-grade grid AND Airtable-style views
   (grid + kanban + gallery + calendar + form all ship in v1). Real formula engine.
3. **THE ARCHITECTURE — "silent-Univer":** **Univer OSS (Apache-2.0) is the grid
   RENDERER with its formula engine DISABLED** via `notExecuteFormula: true`
   [VERIFIED-CODE `packages/engine-formula/src/config/config.ts:32` +
   `plugin.ts:118` `shouldPerformComputing = !notExecuteFormula`]; **IronCalc is the
   ONLY calc authority.** Never dual-compute — one engine, one truth, zero
   formula-semantics divergence. Univer shows the formula string in its formula bar;
   cell values are pushed in as plain `v` values computed by IronCalc.
4. **Engine placement:** **IronCalc compiled to WASM lives INSIDE the WKWebView**
   beside Univer (the type→compute→repaint hot loop never crosses the Swift bridge);
   **native IronCalc via UniFFI** (`epistemos_calc` wrapper crate, the `agent_core`
   pattern) serves headless/agent calc on BOTH builds. Both load the same serialized
   model. [wasm binding verified: full engine, `bindings/wasm/src/lib.rs:116-137`.]
5. **SQLite/GRDB is the single durable truth.** IronCalc/Univer are projections.
   Sync at transaction boundaries via IronCalc `UserModel`'s verified surface:
   `flush_send_queue() → Vec<u8>` bitcode diffs, `apply_external_diffs()`,
   `to_bytes()/from_bytes()`, native `undo()/redo()`, `pause_evaluation()`
   [VERIFIED-CODE `base/src/user_model/common.rs:259-392`].
6. **Formula freedom = the dual-zone model:** the **record zone** (typed columns;
   field-owned cells are read-only projections) + the **free zone** (arbitrary
   formulas/scratch anywhere, stored in `cell_overlay`). Durable references into
   record data go through **IronCalc defined names** (one per typed column, e.g.
   `Invoices_Amount`) maintained by the app on insert/delete/reorder/rename —
   Excel-`Table1[Column]`-equivalent durability without waiting for IronCalc's
   roadmap [defined-names CRUD VERIFIED-CODE `model.rs:3521/3621/3644` +
   `user_model/common.rs:2006-2025`]. Raw A1 refs into the record zone allowed but
   UI-flagged fragile. **De-risk gate (synthesis threshold):** if the
   reference-durability subsystem threatens v1, ship the conservative model first
   (formula FIELDS + grid-only helper columns) behind a flag and layer free zones in
   later — the schema below supports both.
7. **Native ceiling (per the locked "native as far as full functionality"):** native
   frame/toolbar/table-switcher/schema-inspector + **native kanban, gallery,
   calendar, form, record-detail** + **native Swift Charts** + **a native, dedicated
   AGENT CHAT PANEL docked in the Data tab** (owner-confirmed; all dossiers
   converged). **WKWebView ONLY for the dense grid** — bundled local assets,
   `loadFileURL`, script-message bridge, no server (the proven editor pattern).
8. **Agents — deeply wired to BOTH builds, same seam as ResearchHub (Plan 8):** one
   tool surface; **MAS = June driving in-process `agent_core`** (sandbox-legal, no
   subprocess); **Pro = OpenChamber/goose/OpenCode via the app-hosted MCP**. The
   in-tab chat and the main agent surfaces call the SAME tools. Every structural or
   bulk op: **dry_run → schema-diff preview → confirm → apply → undo.** Mascot hook:
   when an agent works the Data room, its mascot appears there (Plan 5 pattern).
9. **Never:** Univer Pro (commercial license + server + Node — verified boundary:
   Pro holds collab/history/**import-export**/print/charts/pivots; the OSS repo has
   NO `-pro` packages). No server, no Postgres, no subprocess on MAS, ever.
   **Charts = Swift Charts** (ECharts-in-webview later if needed). **Pivots = SQLite
   queries.** **xlsx import/export = IronCalc** (`load_from_xlsx`/`save_to_xlsx`
   verified) — necessity, since Univer OSS can't.
10. **Licensing discipline [all VERIFIED in clone LICENSE files]:** Univer
    Apache-2.0 · IronCalc MIT/Apache-2.0 dual · Baserow MIT-core = borrowable code
    donor · **Teable AGPL apps = CLEAN-ROOM behavior reference ONLY** (never port
    its code). Airtable/Notion/Coda = feel only.

---

## §1 VERIFIED ARCHITECTURE

```
┌─ Data tab (native frame: toolbar · table switcher · view switcher · inspector) ─┐
│                                                                                  │
│  NATIVE views ─────────────┐   ┌─ WKWebView (grid view only; bundled assets) ─┐  │
│  kanban · gallery ·        │   │  Univer OSS renderer (formula engine OFF via  │  │
│  calendar · form ·         │   │  notExecuteFormula) + IronCalc-WASM co-       │  │
│  record detail ·           │   │  resident = the ONLY computer. Hot loop stays │  │
│  Swift Charts              │   │  in-page: edit → wasm setUserInput+evaluate → │  │
│                            │   │  re-read dependents → push values into Univer │  │
│  NATIVE agent chat panel ──┤   └───────────────┬───────────────────────────────┘  │
│  (docked; drives the same  │            commit │ flush_send_queue() bitcode diff  │
│   tool surface)            │                   ▼ (WKScriptMessageHandler)         │
└────────────────────────────┴──────────────────────────────────────────────────────┘
                    ▼
     SQLite/GRDB — THE durable truth (typed records + overlay + views + op-log)
                    ▲
     native IronCalc-UniFFI (epistemos_calc) — headless/agent calc, dry-runs, undo
                    ▲
     agent tools: MAS = in-process agent_core · Pro = app-hosted MCP (OpenChamber/goose)
```

Key verified facts a builder must not re-derive: Univer is isomorphic with separable
formula/UI plugins (README:90, docs/ISOMORPHIC.md:18); conditional formatting /
data-validation / tables / filter-sort ARE Univer OSS packages in-repo; IronCalc has
**494 implemented functions**, frozen panes, defined names, `UserModel`
undo/redo/diff-queue — but **no dirty-cells accessor after `evaluate()`** (snapshot-
diff the dependents you rendered; see §3) and **no merge-cells API** (struct exists
for xlsx fidelity only). `CellValue = {None, String, Number, Boolean}` — no
Error/Empty variants; errors arrive via `Result` (fix any FFI sketch that assumed
otherwise). Conditional formatting is in IronCalc source at HEAD (base + webapp
renderer) — ahead of its public roadmap; treat as available-pending-release.

## §2 DATA MODEL (consolidated: synthesis dual-zone + singletons' view system)

One SQLite store, four layers. (Full field-by-field DDL drafts live in the
adjudication doc + raw corpus; this is the binding shape.)

- **Typed layer:** `data_table` · `data_field` (kind: text/long-text/number/date/
  checkbox/single-select/multi-select/link/attachment/rating/formula/lookup/rollup;
  `stable_col_uuid` for durable identity; `calc_col` = stable engine column;
  `visibility_scope: all_views | grid_only` for helper columns) · `data_record`
  (`calc_row` stable engine row + fractional `sort_key`) · `record_value` (typed
  payload + cached display/sort text) · `record_link` (relations) · `field_option`.
- **Dual-zone layer:** `sheet_region` (record_zone/free_zone extents) ·
  `cell_overlay` (`table_id,row,col, raw_input, cached_value, cached_kind`) ·
  `named_range` (`name, ref_kind: field_column|record_cell|static, stable_col_uuid,
  a1_fallback`) — the durable-reference registry mirrored into IronCalc defined names.
- **View layer:** `data_view` (grid/kanban/gallery/calendar/form + `config_json`) ·
  `view_field` (visible/width/position) · `view_filter` / `view_sort` / `view_group`.
  **View-stability rule (binding):** per-view sort/filter/group NEVER renumbers
  `calc_row` — views are projections; the canonical engine mapping is immutable
  per record. Formula fields are stored as **field-ID templates** (`{qty}*{price}`)
  compiled to row-relative A1 at sync; **link/lookup/rollup are computed
  RELATIONALLY** and mirrored into the sheet as read-only cells — never forced
  through A1.
- **Provenance + safety layer:** `ingest_source` (image/pdf/csv/paste + vault path +
  raw text) · `record_provenance` · `attachment_blob`/`record_attachment` ·
  `operation_log` (forward + inverse ops JSON, preview hash, agent attribution,
  applied/reverted timestamps).

**Conflict semantics (binding):** field-owned cells in the record zone are read-only
projections (a formula may not overwrite them); overlay cells live in the free zone
or in explicit formula/helper columns; agent structural ops update named-range
extents **in the same transaction** as the schema change.

## §3 THE SILENT-UNIVER GRID (the seam, precisely)

1. **Boot:** WKWebView `loadFileURL` on bundled assets → init Univer with the
   formula plugin registered `{ notExecuteFormula: true }` → init IronCalc-WASM
   (same 4-arg constructor as Rust: `new(name, locale, tz, lang)`) → hydrate both
   from the serialized model / GRDB snapshot → paint.
2. **Edit loop (in-page, no native round trip):** Univer edit command → JS calls
   wasm `set_user_input(sheet,row,col,input)` + `evaluate()` → **re-read the
   dependent cells currently rendered** (snapshot-diff — there is no dirty-cell API;
   scope reads to the viewport + known dependents) → push plain values into Univer
   via the Facade (formula string stays visible in the formula bar).
3. **Commit boundary:** JS calls `flush_send_queue()` → bitcode `Vec<u8>` →
   `WKScriptMessageHandler` → Swift writes records/overlay/op-log to GRDB in ONE
   transaction; periodically `to_bytes()` snapshot for fast reload.
4. **Undo:** `UserModel.undo()` in-engine + the GRDB `operation_log` inverse ops —
   both in the same user-facing undo action.
5. **Native/agent path:** `epistemos_calc` (UniFFI, staticlib — mirror the
   `agent_core` build) loads the same bytes via `from_bytes()` for dry-runs, agent
   edits, and headless recalc; its diffs flow back through the same GRDB commit path
   and are pushed to the webview if open.
6. **Fallback gate:** if measured webview cold-start/memory with Univer +
   IronCalc-WASM breaches the perf budget (§8), swap the renderer to **Glide Data
   Grid (MIT)** and build the minimal spreadsheet chrome on it; watchlist:
   `@ironcalc/workbook` (verified: a real React+canvas grid with formula
   bar/frozen panes/selection/clipboard — younger, but one-vendor purity).

## §4 AGENT LAYER (both builds; the differentiator)

- **One tool schema, three modes** (`dry_run | apply | undo`), executed by a Swift
  executor over GRDB with narrow Rust calc calls. **Structural ops:** create/rename/
  delete table · add/rename/delete field · change_field_type (coercion policy:
  strict/best_effort/null_on_failure) · add_link · create/update view ·
  populate_records · bounded bulk_transform · **promote_helper_column** (free-zone →
  typed field — the signature dual-zone agent move). **Range ops (synthesis):**
  `get_range` · `set_range` · `apply_formula_to_range` · `describe_region` (agent
  reads formulas + cached values to explain a scratch region). **Ingest ops:** §5.
- **Safety pattern (binding):** every structural/bulk op returns a dry-run plan
  (schema diff, rows affected, coercion warnings, cell-level diffs via the engine
  diff queue) → rendered as a native review sheet → explicit confirm → apply in one
  transaction → inverse ops persisted → undo replays them. Agent attribution on
  every op-log row.
- **Wiring:** MAS = June's in-process `agent_core` calls the executor directly
  (no socket, no subprocess). Pro = the same tools registered on the app-hosted MCP
  for OpenChamber/goose/OpenCode. Identical semantics, transport-swapped — exactly
  the ResearchHub (Plan 8) seam.
- **The in-tab agent chat (owner-locked):** a native chat panel docked in the Data
  tab, context-primed with the active table/view/selection; answers render as native
  tables/diff cards; "do it" flows through the same dry-run→confirm pipeline. The
  main agent surfaces (June Surface B / OpenChamber) reach the same tools for
  cross-room work ("build me a table from this note"). Mascot presence on the Data
  room while an agent works it (Plan 5).

## §5 INGEST (all MAS-legal, on-device)

Receipt/image → **Vision `VNRecognizeTextRequest`** → agent proposes schema + rows
(structured output; `agent_core` baseline, Foundation Models opportunistic on
macOS 26) → **preview → confirm → insert** + `ingest_source`/`record_provenance`
rows (source file linked to every record it produced). PDF → PDFKit (+ Live Text for
scans) / existing EdgeParse lane. CSV/JSON → native parse w/ field-type guessing.
Messy paste → agent field-inference. Cloud OCR/parse = Pro-only enhancement, never
the default.

## §6 VAULT INTEGRATION (the moat)

Records get stable vault IDs + `epistemos://record/<table>/<id>` URIs +
`[[wikilinks]]` + graph nodes; `record_link` edges and note→record references become
graph edges. **Inline note embed** = a block storing only
`{tableId, viewId, mode, height}` (never copied data) rendering the native view
in-place (Tiptap block on the web editor side). Swift Charts render from typed
query results. One data core — tab, embed, chat, agent all point at it.

## §7 DONOR MAP (license-aware, verified paths)

- **Baserow (MIT — borrowable):** registry pattern → `backend/src/baserow/contrib/
  database/fields/registries.py`, `views/registries.py`, the core action registry
  (do/undo/redo); filters → `fields/field_filters.py`; formula-field model →
  `fields/models.py:626 FormulaField`.
- **Teable (AGPL — CLEAN-ROOM, behavior only):** view models →
  `packages/core/src/models/view/derivate/{grid,kanban,calendar,gallery,form}.view.ts`;
  field models → `packages/core/src/models/field/`; grid UX →
  `packages/sdk/src/components/grid/`. Study, never port.
- **Univer:** interaction/perf reference (canvas, published 50-60fps at 100k-6M
  cells) + the renderer itself per §3. **Never** `@univerjs-pro/*`.

## §8 PERFORMANCE + GUARDRAILS

- The **instant-open doctrine applies** (`docs/research/AGENT_SURFACE_PERFORMANCE_
  DOCTRINE_2026_07_03.md`): eager WebView + placeholder, off-main engine init, keep
  the webview/model warm across tab switches, non-persistent data store, bundled
  assets. Add Data-tab budgets to `perf-budgets.toml` when Stage 1 lands (webview
  cold-start, wasm+Univer bundle size, keystroke→repaint p99, 100k-row scroll) —
  target-only until measured, per the `[agent_surface]` pattern.
- Never `git add -A`; never commit `.research-clones/`; no worktrees. Swift builds
  on isolated DerivedData, both schemes, BUILD SUCCEEDED before commit; never two
  xcodebuilds at once. Keys in Keychain. UniFFI callbacks hop main via async.
- Don't touch the graph internals, the editors (Plan 2), or the agent surfaces
  (Plan 1) beyond the defined seams. Commit per phase.

## §9 PHASES + ACCEPTANCE

- **Stage 0 — Spikes (de-risk, 2 proofs):** (a) WKWebView loads bundled Univer +
  IronCalc-WASM offline, `notExecuteFormula` on, one edit computes in wasm and
  paints in Univer with the formula visible in the bar; measure cold-start/bundle/
  memory against the Glide fallback gate. (b) `epistemos_calc` UniFFI crate: Swift
  loads a workbook `from_bytes`, sets a cell, evaluates, reads the value.
- **Stage 1 — Data core + grid:** GRDB schema (§2) · field/view registries ·
  operation_log · native frame + table/view switcher + schema inspector · the
  silent-Univer grid over typed tables · formula FIELDS via template compilation ·
  CSV/JSON import. *Accept:* create table → type data → formula field computes →
  survives relaunch → undo works end-to-end.
- **Stage 2 — Views + vault:** native kanban/gallery/calendar/form over the same
  records · filters/sorts/groups · record detail · linked records + lookup/rollup ·
  inline note embeds + graph binding · Swift Charts. *Accept:* one table, five
  views, one embed, graph nodes visible.
- **Stage 3 — Agent + chat (needs Plan 1 agents):** the tool surface on both builds ·
  the in-tab chat panel · dry-run/confirm/undo UX · NL restructuring · ingest
  (Vision/PDF/paste) with provenance · mascot hook. *Accept:* "restructure this
  table" round-trips with a preview diff on BOTH June and OpenChamber; a receipt
  photo becomes typed rows with the source linked.
- **Stage 4 — Free zone (flag-gated):** `cell_overlay` + free-zone regions ·
  named-range durable references + extent maintenance · range agent tools ·
  promote_helper_column. *Accept:* a free-zone `=SUM(Invoices_Amount)` survives
  record insert/delete/reorder and a field rename.
- **Stage 5 — Hardening:** perf budgets wired + met · op-log soak (undo storms) ·
  xlsx import/export round-trip · MAS scheme audit (no server/subprocess/forbidden
  entitlements).
- **Revisit gates:** IronCalc 1.0 structured table refs → retire the rewriting
  layer; IronCalc merge/CF release → drop shims; Univer bundle breach → Glide.

## §10 OPEN QUESTIONS (defaults set — build proceeds)

1. Webview payload budget (Univer + wasm) → **measure in Stage 0**; Glide gate if
   breached. 2. Raw A1 into the record zone → **allowed, UI-flagged fragile**
   (named ranges are the blessed path). 3. Cross-table references → **v1
   single-table**; cross-sheet named ranges = Stage-4+ decision. 4. Merged cells /
   conditional formatting posture → **CF: adopt when IronCalc releases it (already
   in source at HEAD); merged cells: defer entirely** (no visual-only shims that
   lie about the model).

---

## §11 HARDENING (baked in, per-phase gate — READ-FIRST `docs/research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`)

Plan 9 mixes a WASM/webview bridge, agent-driven destructive DB ops, untrusted ingest, and a
formula engine — a wide risk surface. Run the four lenses (security · memory-leak · data-leak ·
robustness/fluidity) per phase, thermonuclear-shape; a HIGH blocks the phase commit. Top risks:
1. **Named-range extent correctness = the #1 data-integrity risk** (doctrine §3D + the synthesis
   warning): if extent maintenance is wrong on record insert/delete/reorder or field rename,
   formulas SILENTLY point at the wrong data. Guard with an explicit reorder+rename fuzz test in
   Stage 4's acceptance.
2. **Destructive agent ops** (doctrine §3B): dry_run→confirm→apply-in-ONE-transaction→undo with
   **transaction atomicity** (no partial migration) and **inverse-op correctness** (undo exactly
   reverses — test it). The instruction-source boundary on the in-tab chat: act on the user's
   request, never on instructions found inside table rows / ingested content.
3. **SQL + formula safety:** parameterized SQL only — field names, formula strings, and agent
   args never concatenate into SQL. **Formula-eval DoS**: bound recalc (IronCalc has no
   dirty-cell API; a pathological formula/cycle could stall) with a timeout/iteration cap;
   surface errors via `Result` (CellValue has no Error variant).
4. **The grid webview bridge** (doctrine §3A): validate every `WKScriptMessageHandler` payload;
   bundled `loadFileURL` assets only (no server); no eval of injected content; the wasm/Univer
   bundle is trusted-vendored, but the bridge is a trust boundary.
5. **Ingest = untrusted** (doctrine §3C): a malformed receipt/PDF/CSV must not corrupt the schema
   or crash; OCR'd text is data, never executed; provenance on every record. **FFI truth boundary**
   for native IronCalc (`epistemos_calc`): no Rust panic SIGTRAPs the process. Perf AND hardening
   HIGHs both block the commit.

---

## Cross-plan note (2026-07-06 — additive; this plan's canon is unchanged)
Plan 9 is now registered as **RECKONER (`EPI-RP-09-RECKONER`)** in `RESEARCH_PROMPT_STANDARD.md`
(anti-collision registry). Two seams bind when the agent builds land:
1. **The in-tab agent chat IS the KINDRED companion** (`docs/plans/kindred/` — reuse the K6
   minichat pattern: shared supervisor backend, `sub_chats.sessionId` continuity, presence bus,
   `Location.surface = dataTab`). Never a third chat system.
2. **Editor boundary (LUMENLENS, `docs/plans/lumenlens/`):** note tables (markdown) stay
   editor-side; Data-room datasets are RECKONER's; notes reference datasets via wikilink/embed
   (graph-linked). Agent table-restructuring reuses the LUMENLENS suggestion/provenance schema
   (dry-run→confirm→undo, ledger-attributed).
