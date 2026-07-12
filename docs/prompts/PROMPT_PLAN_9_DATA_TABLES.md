# PLAN 9 — RECKONER: Agent-Native Vault Datasets on IronCalc × silent-Univer

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. RECKONER now
> targets MAS only. Datasets remain vault artifacts, existing note-workspace
> tabs, Epdoc embeds, Swift Charts, silent-Univer/IronCalc, and June-driven F2
> tools through in-process `agent_core`. Experimental/1Code/KINDRED companion
> presence is parked; no new chat room and no direct cell writes.

**Date:** 2026-07-03 · **Status: CANONICAL WITH 2026-07-06 RECKONER RESHAPE + TRUTH-FLIP
MERGED; MAS-only after 2026-07-07 pivot** · **Sequence: build agent-facing stages after
MAS/June is ready enough to consume tools.** OpenChamber/ProAgent/Experimental/KINDRED are
not prerequisites. The agent tools/status payoff needs the MAS agent seam; the §9 Stage-0/1 foundation (artifact-backed data core + engine
bridge) may start earlier.

**Verification basis (do not re-litigate without new evidence):** synthesized from a
4-dossier corpus — 3 GPT singletons + **the owner's Claude synthesis (highest-compute
input, adopted as the architectural spine)** — then **re-verified 2026-07-03 against
fresh local clones**: `ironcalc@1bd4bb6`, `univer@6ae8eb3`, `teable@498e255`,
`baserow@d5901c0` (all in `.research-clones/work/`, all ≤3 days old). Full adjudication
+ per-claim citations: `docs/research/PLAN9_ADJUDICATION_WORKING_2026_07_03.md`.
Owner intent frame: `docs/prompts/PROMPT_PLAN_9_DATA_TABLES_RESEARCH.md`.

---

## §0 LOCKED DECISIONS (MERGED CURRENT TRUTH)

1. **No dedicated Data tab/room.** RECKONER is the data piece of the MAS LUMENLENS + June cluster:
   datasets open as tabs in the existing note/doc workspace, embed into notes, and are driven by
   the F2 agent tools. Dataset artifacts are first-class vault objects (wikilinks, graph nodes).
2. **Grid-first v1.** A table is an Excel-grade grid first. Kanban/gallery/calendar/form and
   record-detail views are deferred phases, not v1 obligations. Real formula engine remains.
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
   pattern) serves headless/agent calc for MAS/June. The web grid and native tool path load the same serialized
   model. [wasm binding verified: full engine, `bindings/wasm/src/lib.rs:116-137`.]
5. **Vault artifact is the single durable truth; GRDB is derived cache/working store.**
   CSV (flat datasets), XLSX/`.icalc` (promoted workbooks), and `.dataset.md` metadata live in
   the vault and outrank everything. A commit is one GRDB transaction plus synchronous vault
   writeback; deferred writeback silently re-flips truth and is wrong.
6. **Formula freedom = deferred dual-zone model:** the **record zone** (typed columns;
   field-owned cells are read-only projections) + the **free zone** (arbitrary formulas/scratch
   anywhere) with IronCalc defined names remains the post-v1 direction. V1 ships the conservative
   grid-first model unless the defined-name/free-zone subsystem is proven without schedule risk.
7. **Native ceiling (per the locked "native as far as full functionality"):** native dataset-tab
   frame/toolbar/table-switcher/schema-inspector + **native Swift Charts**. No dedicated docked
   agent chat. **WKWebView ONLY for the dense grid** — bundled local assets, `loadFileURL`,
   script-message bridge, no server (the proven editor pattern).
8. **Agents — MAS/June only:** one F2 tool surface; **MAS = June driving in-process
   `agent_core`** (sandbox-legal, no subprocess). Park Experimental/1Code/KINDRED
   routing. Every structural or bulk op: **dry_run → schema-diff preview → confirm → apply → undo.**
   Status hook: when June works a dataset tab/embed, MAS-safe status/provenance follows that surface.
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
┌─ Dataset tab in existing note/doc workspace (toolbar · switcher · inspector) ──┐
│                                                                                  │
│  Native chrome +           │   ┌─ WKWebView (grid view only; bundled assets) ─┐  │
│  Swift Charts              │   │  Univer OSS renderer (formula engine OFF via  │  │
│  (other views deferred)    │   │  notExecuteFormula) + IronCalc-WASM co-       │  │
│                            │   │  resident = the ONLY computer. Hot loop stays │  │
│  No docked chat; MAS June  │   │  in-page: edit → wasm setUserInput+evaluate → │  │
│  uses F2 tools             │   │  re-read dependents → push values into Univer │  │
│                            │   └───────────────┬───────────────────────────────┘  │
│                                                │ commit + synchronous writeback   │
│                                                ▼ (WKScriptMessageHandler)         │
└────────────────────────────┴──────────────────────────────────────────────────────┘
                    ▼
     GRDB — derived working cache (typed records + overlay + views + op-log)
                    ▼
     Vault artifact — THE durable truth (CSV/XLSX-.icalc + .dataset.md)
                    ▲
     native IronCalc-UniFFI (epistemos_calc) — headless/agent calc, dry-runs, undo
                    ▲
     agent tools: MAS = June/agent_core
```

Key verified facts a builder must not re-derive: Univer is isomorphic with separable
formula/UI plugins (README:90, docs/ISOMORPHIC.md:18); conditional formatting /
data-validation / tables / filter-sort ARE Univer OSS packages in-repo; IronCalc has
**494 implemented functions**, frozen panes, defined names, native `UserModel`
undo/redo/diff-queue — but **no dirty-cells accessor after `evaluate()`** (snapshot-
diff the dependents you rendered; see §3) and **no merge-cells API** (struct exists
for xlsx fidelity only). `CellValue = {None, String, Number, Boolean}` — no
Error/Empty variants; errors arrive via `Result` (fix any FFI sketch that assumed
otherwise). Conditional formatting is in IronCalc source at HEAD (base + webapp
renderer) — ahead of its public roadmap; treat as available-pending-release.

## §2 DATA MODEL (artifact truth + derived cache; dual-zone/view system staged)

One vault artifact family plus a derived GRDB cache, four logical layers. (Full field-by-field
DDL drafts live in the adjudication doc + raw corpus; this is a staged shape, not a license to
make GRDB truth.)

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
   (`new Model(name, locale, timezone, language_id)` on `@ironcalc/wasm` 0.7.0; no wasm
   `UserModel`) → hydrate both from the serialized vault-backed model / GRDB cache → paint.
2. **Edit loop (in-page, no native round trip):** Univer edit command → JS calls
   wasm `set_user_input(sheet,row,col,input)` + `evaluate()` → **re-read the
   dependent cells currently rendered** (snapshot-diff — there is no dirty-cell API;
   scope reads to the viewport + known dependents) → push plain values into Univer
   via the Facade (formula string stays visible in the formula bar).
3. **Commit boundary:** JS emits the app-owned dirty payload / snapshot digest over
   `WKScriptMessageHandler` → Swift writes records/overlay/op-log to GRDB in ONE transaction and
   synchronously writes the vault artifact; periodically `to_bytes()` snapshot for fast reload.
4. **Undo:** IronCalc `undo()`/native facade undo where exposed + the GRDB `operation_log` inverse
   ops + artifact rollback all present as the same user-facing undo action.
5. **Native/agent path:** `epistemos_calc` (UniFFI, staticlib — mirror the
   `agent_core` build) loads the same bytes via `from_bytes()` for dry-runs, agent
   edits, and headless recalc; its diffs flow back through the same GRDB + vault-artifact commit
   path and are pushed to the webview if open.
6. **Fallback gate:** if measured webview cold-start/memory with Univer +
   IronCalc-WASM breaches the perf budget (§8), swap the renderer to **Glide Data
   Grid (MIT)** and build the minimal spreadsheet chrome on it; watchlist:
   `@ironcalc/workbook` (verified: a real React+canvas grid with formula
   bar/frozen panes/selection/clipboard — younger, but one-vendor purity).

## §4 AGENT LAYER (MAS/June; the differentiator)

- **One tool schema, three modes** (`dry_run | apply | undo`), executed by a Swift
  executor over the DatasetStore/GRDB cache with narrow Rust calc calls and synchronous
  vault-artifact writeback. **Structural ops:** create/rename/
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
- **Wiring:** MAS = June's in-process `agent_core` calls the executor directly (no socket, no
  subprocess). Experimental/1Code/KINDRED transport is parked.
- **No new chat:** dataset context is injected into June. Answers
  render as native tables/diff cards; "do it" flows through the same dry-run→confirm pipeline.
  MAS-safe status/provenance follows the dataset tab/embed while June works it.

## §5 INGEST (all MAS-legal, on-device)

Receipt/image → **Vision `VNRecognizeTextRequest`** → agent proposes schema + rows
(structured output; `agent_core` baseline, Foundation Models opportunistic on
macOS 26) → **preview → confirm → insert** + `ingest_source`/`record_provenance`
rows (source file linked to every record it produced). PDF → PDFKit (+ Live Text for
scans) / existing EdgeParse lane. CSV/JSON → native parse w/ field-type guessing.
Messy paste → agent field-inference. Cloud OCR/parse outside the receipt-gated MAS proxy is parked,
never the default.

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
- **Stage 1 — Artifact-backed data core + grid:** vault artifact layout
  (CSV/XLSX-`.icalc` + `.dataset.md`) · GRDB derived-cache schema (§2) · field/view registries ·
  operation_log · native dataset-tab frame + table switcher + schema inspector · the silent-Univer
  grid over typed tables · formula FIELDS via template compilation · CSV/JSON import. *Accept:*
  create dataset → type data → formula field computes → vault artifact updates synchronously →
  survives relaunch/cache rebuild → undo works end-to-end.
- **Stage 2 — Embeds + vault graph:** inline note embeds + graph binding · Swift Charts · filters/
  sorts/groups for the grid. *Accept:* one dataset tab, one embed, one chart, graph nodes visible,
  and cache rebuild from the artifact preserves the same view.
- **Stage 3 — Agent tools on MAS/June (needs Plan 1 MAS):** the F2 tool surface on MAS/June ·
  dataset context injection into June · dry-run/confirm/undo
  UX · NL restructuring · ingest (Vision/PDF/paste) with provenance · status hook. *Accept:*
  "restructure this table" round-trips with a preview diff on June; a
  receipt photo becomes typed rows with the source linked.
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
   reverses — test it). The instruction-source boundary on existing agent surfaces: act on the
   user's request, never on instructions found inside table rows / ingested content.
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

## Cross-plan note (2026-07-06 — current binding state)
Plan 9 is now registered as **RECKONER (`EPI-RP-09-RECKONER`)** in `RESEARCH_PROMPT_STANDARD.md`
(anti-collision registry). Two seams bind when the agent builds land:
1. **No new chat door exists.** MAS/June receives dataset context through the same F2
   capability seam — same tools, no companion chrome. Kindred/1Code context routing is parked.
   Never create a third chat system.
2. **Editor boundary (LUMENLENS, `docs/plans/lumenlens/`):** note tables (markdown) stay
   editor-side; RECKONER datasets are vault artifacts mounted as tabs/embeds; notes reference
   datasets via wikilink/embed (graph-linked). Agent table-restructuring reuses the LUMENLENS
   suggestion/provenance schema (dry-run→confirm→undo, ledger-attributed).

---

## RESHAPE (owner + review, 2026-07-06 — BINDING; merged into §0 above)

**Verdict: KEEP the data core; CUT the standalone room.** RECKONER is the MAS data piece of the
LUMENLENS+June cluster, not a fourth destination. §0–§2 now mean vault-artifact truth · GRDB
derived cache · IronCalc sole calc authority · silent-Univer grid in WKWebView · dual-zone/
defined-names deferred post-v1.
The doors re-weight:
1. **PRIMARY door = MAS/June.** Datasets are created/restructured through the F2 capability from
   June and MAS-June Epdoc assist ("track X", "make this note's table real", "chart this")
   with dry-run→confirm→undo, ledger-attributed. Data is something the MAS agent DOES for you,
   not a place you go.
2. **Datasets open as TABS in the note workspace** — reuse the existing native note/doc tab group
   (precedent: EpdocDocument windows already join `NoteWindowManager.noteTabbingIdentifier`,
   guard-tested). Same chrome as notes; zero new navigation surface. **Second mount (owner
   2026-07-06): sheets can ALSO be in-note tabs inside the Epdoc Notebook** (LUMENLENS §P-AMEND
   11) — same vault artifact truth, same GRDB cache, same grid seam, mounted inside a note beside
   MAS-June assist tabs; the note's `.md` holds only references (tab manifest). `RESEARCH_PROMPT_PLAN_9_RECKONER.md`
   D10 resolves the double-mount + WebView-economics rules.
3. **Inline note embeds** — unchanged (the vault-integration moat, §6).
4. **The dedicated top-level Data room/tab: CUT.** No room chrome. The native view system
   (kanban/gallery/calendar/form) is DEFERRED to a later phase — grid first.
**No new chat of any kind**: MAS/June is the chat, dataset-aware through context and
approval/provenance. Stage 0–1 (data core + engine spikes)
remains startable early; agent-facing work lands after the MAS/June F2 seam is ready.

**Exact §0 supersession map (this reshape is the new evidence §0 demands):**
- §0.1 "dedicated Data tab/room" → SUPERSEDED: datasets open as tabs in the existing note/doc
  tab group; records stay first-class vault objects (wikilinks/graph nodes — unchanged).
- §0.2 "grid + kanban + gallery + calendar + form all ship in v1" → SUPERSEDED: grid ships v1;
  the other views + record-detail are DEFERRED phases.
- §0.7 "native, dedicated AGENT CHAT PANEL docked in the Data tab" → SUPERSEDED: no docked
  panel, no new chat — MAS/June serves dataset tabs
  through the same F2 tools. §0.7's native frame/toolbar/inspector ceiling otherwise stands
  for the dataset-tab chrome; Swift Charts stands.
- Old §0.8 agent-surface wording → STALE post-pivot: the surface is June/MAS
  (in-process agent_core); one tool surface
  + dry_run→confirm→apply→undo + the mascot hook all stand as written.
- Everything else in §0 (silent-Univer, IronCalc sole authority, WASM placement, vault-artifact
  truth + GRDB derived cache, dual-zone/defined-names deferred post-v1, xlsx via IronCalc, never
  Univer Pro, licensing) is UNCHANGED from the merged current §0 above.

---

## TRUTH-FLIP SUPERSESSION (2026-07-06, RECKONER wave accepted by audit #4 — BINDING; owner-reversible)

**Dataset truth = the VAULT ARTIFACT; GRDB = derived cache/working store.** CSV (flat datasets) /
XLSX-`.icalc` (promoted workbooks) + a `.dataset.md` companion (id, schema, formula cells, view +
chart specs) live in the vault and outrank everything; GRDB is the fast working copy, rebuildable;
commit = one GRDB transaction + SYNCHRONOUS vault writeback (deferred writeback would silently
re-flip truth). Rationale + evidence: `docs/plans/reckoner/RECKONER_REVIEW_2026_07_06.md` §A
(fabric F1 literal, owner file-truth arc, dissolves the SQLite-under-sync fork, one mental model
with notes). This supersedes, by exact line: §0.1 "One SQLite data core" (core survives as cache),
**§0.5 in full**, §1's diagram line "SQLite/GRDB — THE durable truth", §2's "binding shape" header,
§3.1/§3.3/§3.5 commit-boundary phrasing, §4 "executor over GRDB", §9 Stage-1, the RESHAPE lines
that described GRDB as unchanged truth, and the matching §0-supersession-map token. The
adjudication doc carries a superseded banner; raw corpora stay historical.

**Also recorded here:**
- **Charts re-affirmed per §0.9:** Swift Charts native block = PRIMARY (the wave's vchart-primary
  inversion is reversed — plugin license unconfirmed + peer-locked to Univer ^0.2.5; vchart = the
  "later if needed" lane, decided at R0).
- **DEFERRED, not killed (owner-reversible):** the dual-zone/defined-names model, §2's four-layer
  binding shape, and record-LEVEL first-class vault objects (v1 ships dataset-level nodes/links;
  grid-first). The wave silently omitted these; this line makes the deferral explicit.
- **KEELSTONE seam:** dataset artifacts (.csv/.xlsx/.icalc/*.dataset.md) join the reconciler's
  watched set with delegated conflict routing — KEELSTONE's docs carry the addendum.
