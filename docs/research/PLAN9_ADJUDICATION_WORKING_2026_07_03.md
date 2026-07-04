# Plan 9 — Research Adjudication (CLOSED 2026-07-03)

**Status: CLOSED — superseded by the canonical plan
[`docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`](../prompts/PROMPT_PLAN_9_DATA_TABLES.md).**
All four conflicts resolved by the owner's Claude synthesis (weighted spine) +
clone-level verification. This file remains as the adjudication provenance.

**Corpus:** GPT-1/2/3 singletons + the owner's Claude synthesis (highest weight).
**Verification substrate:** fresh shallow clones in `.research-clones/work/`
(ironcalc@1bd4bb6, univer@6ae8eb3, teable@498e255, baserow@d5901c0 — all ≤3 days old).

---

## §1 CONSENSUS MAP (all three singletons agree — unusually convergent)

1. **Engine base = IronCalc as the calc KERNEL, not Univer.** IronCalc: Rust,
   engine-first, dual MIT/Apache-2.0, `.xlsx` IO, hundreds of functions, fits the
   Swift↔Rust UniFFI stack. Univer: impressive TS/browser office SDK (Apache-2.0 core)
   but its center of gravity is canvas/plugins/Node, and import-export/charts/pivots/
   collaboration sit in **Pro + server** territory — wrong gravity for local-first MAS.
   Univer survives as an interaction/perf REFERENCE (published 50-60fps at 100k-6M cells).
2. **SQLite/GRDB = the SINGLE source of truth** (typed tables/fields/records/links/views).
   IronCalc = a **hidden computational projection per table** (rows↔records,
   cols↔fields), regenerated/incrementally synced — never a second truth.
3. **UI composition:** native frame + native simple views (kanban/gallery/calendar/form/
   chat/record-inspector) + **Swift Charts native** + **WKWebView ONLY for the dense
   editable grid** (bundled local assets, script-message bridge, no server). Building an
   Excel-grade grid natively = a spreadsheet-product program, wrong v1 investment.
   NSTableView is record-oriented, not a spreadsheet interaction stack.
4. **Formula policy:** formula FIELDS stored as field-ID templates (e.g. `{qty}*{price}`)
   compiled to row-relative A1 at sync time (rename/reorder-safe). Relational fields
   (link / lookup / rollup) computed RELATIONALLY and mirrored into the sheet as
   read-only cells — never forced through A1.
5. **View stability rule (GPT-3, keep):** per-view sort/filter/group NEVER renumbers the
   canonical sheet mapping (`calc_row`/`sheet_row_index` is stable per record; views are
   projections, not mutations).
6. **Agent layer:** ONE JSON tool contract, three modes `dry_run → apply → undo`;
   inverse-ops persisted in an op-log table; plan rendered as a schema diff for
   confirmation; identical semantics on MAS (in-process `agent_core`) and Pro
   (app-hosted MCP for goose/OpenCode). Donor precedents: Baserow action registry
   (do/undo/redo), Teable AI-chat "list plan → confirm → execute".
7. **Ingest (all MAS-legal, on-device):** Vision `VNRecognizeTextRequest` (receipts/
   images) → agent structuring → schema proposal → preview → insert + provenance rows;
   PDFKit (+ Live Text for scans) / existing EdgeParse; CSV/JSON native; messy paste via
   structured output. Foundation Models = opportunistic accelerator where available;
   `agent_core` = the portability baseline. Cloud OCR/parse = Pro-only enhancement.
8. **Vault moat:** records are first-class vault objects — stable IDs, wikilinks
   (`[[record:table:id]]` / `epistemos://record/...`), graph nodes + `record_link`
   edges, inline note-embed block storing only `{tableId, viewId, mode, height}`
   (never copied data). One data core, four doors: tab · inline block · chat · agent.
9. **Donor discipline:** Baserow (MIT core) = code-structure donor (registry pattern for
   field/view/filter/action types). Teable (AGPL apps) = UX-behavior donor, CLEAN-ROOM
   ONLY. Univer = interaction/perf reference. Airtable/Notion/Coda = feel only.
10. **Licenses (3× consistent, to re-verify in source):** IronCalc dual MIT/Apache-2.0 ·
    Univer core Apache-2.0 / Pro commercial+server · Baserow MIT core (premium/enterprise
    carve-outs) · Teable AGPL-3.0 apps + MIT packages.
11. **MAS verdict:** the all-embedded stack (GRDB + IronCalc-in-process + bundled-asset
    WKWebView + Vision/PDFKit + in-process agent tools) is sandbox-legal; NO localhost
    server, NO subprocess; `network.server` never needed.
12. **v1 scope convergence:** field kinds ≈ text/long-text/number/date/checkbox/single+
    multi-select/link/attachment/formula/rating (+lookup/rollup); views = grid/kanban/
    gallery/calendar/form; agent ops = create/rename table, add/rename/delete field,
    change type (w/ coercion warnings), create/update view, populate, bounded
    bulk-transform; charts = native summaries, NOT embedded sheet chart objects;
    NO pivots/collaboration/cross-table A1 in v1.

## §2 CONFLICTS TO ADJUDICATE (the only real disagreements)

| # | Question | GPT-1 | GPT-2 | GPT-3 | Working lean (final call after Claude synthesis) |
|---|---|---|---|---|---|
| C1 | Per-cell formula freedom in typed tables | None in v1; "analysis sheets" later | **Grid-only helper columns** (`visibility_scope=grid_only`), promotable to real fields | Allowed if computed value conforms to the field's type | Lean **GPT-2**: helper columns give the spreadsheet feel + schema safety + a natural agent "promote" op; GPT-3's type-conforming variant is a possible v1.5 |
| C2 | What renders the WEB grid | Open ("renderer compromise vs purity") | Open (web grid, engine-agnostic shell) | Open | **Sharpest open question.** Candidate worth verifying: IronCalc's OWN wasm+web UI vendored (ONE engine both sides: wasm in the webview, native FFI for agent/headless — zero double-truth). Univer-as-renderer = two formula engines = reject unless the synthesis shows a clean headless-render mode. Custom-thin-grid = fallback |
| C3 | Recalc/dirty-cell events over FFI | Stub (fill when API exists) | Before/after diff of all cells (works, O(n) per edit) | Diff cached evaluated cells | Verify in source whether IronCalc 0.7.x exposes changed-cells after `evaluate()`; if not, diff-based batching per edit-transaction (GPT-2) with viewport-scoped invalidation |
| C4 | Executor home | Rust ops enum + Swift host | Swift executor + narrow Rust calls | Swift executor | Lean Swift executor over GRDB with Rust only for calc (matches existing app split); ops enum shape from GPT-1 is good either way |

## §3 VERIFICATION TARGETS (run against clones + web; results appended below)

1. IronCalc: real `Model` API names used by the sketches (`new_empty`, `set_user_input`,
   `evaluate`, `get_formatted_cell_value`, `get_cell_value_by_index`, `get_cell_formula`,
   `load_from_xlsx`/`save_to_xlsx`), version, dual-license files, workspace layout
   (base/xlsx/bindings/**wasm/webapp/widget?** ← feeds C2), any changed-cells/dirty API
   (← C3), UserModel vs Model distinction.
2. Univer: LICENSE of core; where the OSS/Pro boundary shows in-repo; is there any
   headless/render-only mode that could take an external engine (← C2 rejection check).
3. Teable: AGPL-3.0 on apps/, MIT on packages/ (confirm split); view renderer layout
   (donor-study map only, clean-room).
4. Baserow: MIT core + premium/enterprise dirs; the registry pattern files
   (field_types/view_types/action registries) for the donor map.
5. GRDB/SQLite claims: none contentious (already the app's stack).

## §4 VERIFICATION RESULTS [VERIFIED-CODE against local clones, 2026-07-03]

**The Claude synthesis's load-bearing claims — all confirmed:**
| Claim | Verdict | Evidence |
|---|---|---|
| Univer `notExecuteFormula` flag exists + gates compute | **CONFIRMED** | `packages/engine-formula/src/config/config.ts:32`; `plugin.ts:98,109,118,173` (`shouldPerformComputing = !notExecuteFormula`) — the silent-Univer pattern is real |
| Univer isomorphic/headless-capable, formula plugin separable | CONFIRMED | README:90 + docs/ISOMORPHIC.md:18 (engine/UI plugin split) |
| Univer OSS/Pro boundary (Pro = collab/history/**import-export**/print/charts/pivots) | CONFIRMED | README:129; NO `-pro` packages in the OSS repo; CF/data-validation/tables ARE OSS packages |
| Univer Apache-2.0 clean | CONFIRMED | root LICENSE |
| IronCalc `UserModel` diff/undo layer | **CONFIRMED** | `base/src/user_model/common.rs`: `from_bytes:259, to_bytes:273, undo:296, redo:311, pause_evaluation:337, flush_send_queue:366, apply_external_diffs:379` (bitcode; "keep two remote models in sync") |
| IronCalc defined-names CRUD (durable-reference keystone) | **CONFIRMED** | `model.rs:3521 new_defined_name, :3621 delete, :3644 update, :2747 list` + UserModel `common.rs:2006/2011/2025` |
| No dirty-cells accessor after `evaluate()` (C3) | CONFIRMED (absence) | `evaluate()` returns (); send_queue = user diffs only → snapshot-diff dependents |
| IronCalc core API names in FFI sketches | CONFIRMED w/ corrections | `new_empty(name,locale,tz,lang)→Result`; `set_user_input(u32,i32,i32,String)`; `get_formatted_cell_value/get_cell_value_by_index(u32,i32,i32)→Result`; **CellValue = {None,String,Number,Boolean}** (no Error/Empty variants — errors via Result) |
| xlsx IO names | CONFIRMED | `import/mod.rs:181-204 load_from_xlsx(+_bytes, +icalc)`; `export/mod.rs:64-152 save_to_xlsx(+writer, +icalc)` |
| wasm binding = full engine in-page | CONFIRMED | `bindings/wasm/src/lib.rs:116-137` — same 4-arg constructor, set_user_input/evaluate/undo/redo exposed |
| "Hundreds of functions" | CONFIRMED | **494** Function enum variants |
| IronCalc dual MIT/Apache | CONFIRMED | LICENSE-MIT + LICENSE-Apache-2.0 + per-crate `license = "MIT OR Apache-2.0"` |
| Teable license split (apps AGPL / packages MIT / plugins AGPL) | CONFIRMED | root LICENSE:8-17 + plugins/LICENSE |
| Baserow MIT core + proprietary premium/enterprise | CONFIRMED | root LICENSE:5-10 + premium/LICENSE:22 |

**Corrections/refinements to the synthesis (clone is fresher than its 0.7.1 basis):**
1. **Conditional formatting is IN SOURCE at HEAD** (base `cf_types.rs` + `conditional_formatting.rs` + webapp renderer) — ahead of the "roadmap" claim. Positive.
2. **Merged cells: synthesis RIGHT** — `merge_cells` struct exists (xlsx fidelity) but NO public merge API (`grep "pub fn .*merge"` = 0). (An earlier agent pass overstated this; the grep settles it.)
3. `@ironcalc/workbook` is more real than billed — React+canvas grid WITH formula bar/frozen panes/selection/clipboard/CF renderer — still not chosen (maturity), but it joins Glide as a watchlist fallback.
4. CellValue enum shape (above) — FFI sketches must not pattern-match Error/Empty variants.

**Donor-study map (verified paths):**
- Teable (CLEAN-ROOM): `packages/core/src/models/view/derivate/{grid,kanban,calendar,gallery,form}.view.ts` · `packages/core/src/models/field/` · `packages/sdk/src/components/grid/`.
- Baserow (MIT, borrowable): `backend/src/baserow/contrib/database/fields/registries.py` · `views/registries.py` · action registry (do/undo/redo) in core · `fields/field_filters.py` · `FormulaField` at `fields/models.py:626`.

## §4b CONFLICT RESOLUTIONS (final)
- **C1 formula freedom → dual-zone** (record zone read-only at field-owned cells + free zone w/ `cell_overlay`), durable refs via defined names; **gate:** ship conservative (formula fields + helper columns) first behind a flag if the reference-durability subsystem threatens v1 (synthesis threshold).
- **C2 grid renderer → Univer OSS as silent renderer** (`notExecuteFormula:true`), IronCalc-WASM co-resident in the webview as sole calc authority; fallback = Glide Data Grid (MIT), watchlist = `@ironcalc/workbook`.
- **C3 recalc events → snapshot-diff dependents after `evaluate()`** (no dirty API; `flush_send_queue` = user-diff sync for persistence, not repaint); optional upstream patch later.
- **C4 executor → Swift executor over GRDB** + narrow Rust calc calls; GPT-1's ops-enum shape adopted for the op-log.

## §5 NOTES FOR THE FINAL SYNTHESIS PASS

- Owner instruction: the incoming Claude synthesis = highest-compute input → treat as the
  spine of the canonical plan; still source-verify its load-bearing claims (precedent:
  the MAS round's heavyweight synthesis was wrong about goose-sdk; the clone settled it).
- The three singletons' convergence means the Claude synthesis mostly needs to settle
  C1-C4 + anything novel it adds; large disagreement with §1 would itself be a flag to
  check against source.
- Locked owner decisions (from PROMPT_PLAN_9_DATA_TABLES_RESEARCH.md §0) remain the
  outer frame: dedicated tab; unified hybrid; real formula engine; native-as-far-as-
  full-functionality; agent-native (restructure/chat/ingest, both builds); no server;
  Teable clean-room.
