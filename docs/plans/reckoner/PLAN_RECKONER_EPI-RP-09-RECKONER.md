# PLAN_RECKONER — Data Tables, Grid-First
ID: EPI-RP-09-RECKONER · Codename: RECKONER

## Executive thesis
RECKONER is a file-truth spreadsheet living inside the app's existing surfaces — no standalone Data room, no new chat. Datasets open as tabs in the note workspace, embed as live blocks inside notes, and expose one F2 tool surface that June (MAS) and the KINDRED companion (1Code) both drive, honestly gated per turn. The engine canon is locked and now verified against primary sources: Univer OSS renders and is silenced (notExecuteFormula on the sheets-formula plugin — it parses formula strings and computes nothing), IronCalc-WASM is the sole calc authority (setUserInput → evaluate → read back), and GRDB persists as a derived cache under a vault artifact that remains the truth. The whole design collapses to one sentence: GRDB is truth's working copy, IronCalc is the calculator, Univer is the screen — and the vault file outranks them all. What nobody else ships, and RECKONER does: a real calc grid over plain vault files with agent edits arriving as cell-level tracked changes, one calc authority shared by tab and embed so divergence is impossible by construction, and charts that carry ledger provenance back to their exact source range.

## Locked canon (binding — not re-litigated)
Univer OSS (Apache-2.0) = renderer only, formula engine silenced. IronCalc (dual MIT/Apache-2.0, pinned =0.7.1) = sole calc authority via WASM in the WebView and the Rust crate in agent_core. GRDB/SQLite = durable working store, WAL via DatabasePool, never authoritative over the vault. Grid-first triad: workspace tab + note embed + F2 tools. No Data room. No new chat.

## Three-cycle evidence (what changed)
Cycle 1 produced the raw mechanics and an initial design with a SQLite sidecar as truth and Univer's engine left on "for display." Cycle 2's adversarial pass killed four violations: sidecar-as-truth broke F1 (CSV promoted to vault truth, GRDB demoted to cache); display-mode Univer calc broke the renderer-never-authority rule (hard-silenced via notExecuteFormula); inline embed data broke minimal-diff writeback (embed became a Tier-B file reference); and direct agent setValues broke the reviewable-edits rule (all agent ops became TabularSuggestions crossing the ApprovalGate). Cycle 3 unified the tabular provenance schema onto the locked ledger shape instead of a parallel one, routed presence onto the existing companion bus, and produced the contradiction sweep (8 items, none unresolved) and five handoff cards shipped beside this plan.

## Dimensions, condensed
**D1 silent-Univer.** Intercept at onBeforeCommandExecute (throwing cancels — the documented read-only pattern); route input to IronCalc; paint evaluated results back via setValues inside a suppression window; repaint dirty cells only. Version-gated items flagged: where notExecuteFormula registers (sheets-formula vs engine-formula config — the Phase-0 smoke test arbitrates) and IronCalc's constructor arity (2-arg archived README vs 4-arg 0.7.1 sibling — read the shipped .d.ts).
**D2 representation.** CSV in the vault is truth for flat datasets — human-readable, diffable, survives sync and survives Epistemos being uninstalled. Formula/style/multi-sheet workbooks promote to XLSX/.icalc truth written by agent_core (xlsx is verifiably absent from the wasm build). A companion .dataset.md / frontmatter block carries id, schema, formula cells, view and chart specs. Notes link by id + vault-relative path; a separating move triggers embedInvalidated and relink, never a crash. GRDB schema: dataset/sheet/cell/formula, composite-key WITHOUT ROWID with the 1/4-page payload caveat respected, sparse cells only.
**D3 surfaces.** One new NoteWorkspaceMode case mounts the grid WebView; the lens state machine is untouched. The embed is a Tiptap atom carrying only a reference; inline edits route through the same calc path; structural ops offer "Open in Data tab." Tiny static tables stay Tier-A markdown until explicitly converted.
**D4 tools.** query/transform/chart/clean/summarize as one schema; June runs in-process (no subprocess on MAS), the companion streams with presence; destructive ops (delete column, overwrite range) cross the ApprovalGate before staging; every op renders as before/after chips, accept per cell/range/turn, ledger-recorded.
**D5 charts.** Univer's first-party charts are Pro-gated (@univerjs-pro/*) and off-limits. OSS path: the MIT @visactor/univer-vchart-plugin for grid overlays, with its low maturity named honestly and a native chart-block fallback pre-decided. Every chart carries a ledger pointer to dataset+range and flags stale on source change.
**D6 scale + failure.** Univer's canvas viewport rendering plus facade setRowCount(100000) says the render side scales; RECKONER's obligations are virtualized hydration from GRDB (visible window + buffer, never 100k rows across the bridge — bulk import builds the model in Rust and hands to_bytes to the WebView) and dirty-cell-only repaint. Failure table: WASM crash → roll back to last GRDB commit, re-init from snapshot, never persist partials; bridge drop → rehydrate from truth, replay ledger tail; moved/deleted file → relink UI; agent/user cell conflict → user wins live, agent suggestion rebases or flags, in the diff3-v1 spirit; orphaned embed → placeholder with relink. Ledger retention: checkpoint accepted dataset state + keep a recent op tail, tabular-tuned caps after the Phase-7 bench.
**D7 competitive.** Obsidian Bases/Dataview are computed views, not editable grids; Notion/Airtable/Tana are cloud-authoritative; AnyType is local-first but not file-diffable. RECKONER copies Notion's embed ergonomics and Obsidian's file truth, avoids cloud authority and binary-only truth, and owns the three novelties above.
**D★ fabric.** F1 vault artifact + propagation (Swift + agent_core). F2 one tool schema, two callers (Rust impls, Swift gate wiring). F3 run-state so the mascot pins to the Data tab — 1Code only. F4 dataset↔note↔entity edges via the public graph API. F5 every tabular op + chart provenance in the ledger. F6 datasetChanged / calcCompleted / embedInvalidated on the existing bus.

## Phased build order (witnessable done-bars)
**R0 — Silent-Univer spike.** Bar: in a throwaway WebView, "=1+1" leaves Univer holding the string, IronCalc returns 2, the 2 paints back through the suppression path, and "=A1*3" recomputes on A1 edit. This single test converts the two version-gated unknowns into facts.
**R1 — Truth + persistence.** Bar: 1k-row CSV imports to GRDB + model + grid; a cell edit updates the vault CSV via row-level writeback; reopen reproduces identical state; a vault move still resolves.
**R2 — Tab mount.** Bar: a dataset opens as the new mode case emitting zero change/autosave during load (asserted via the suppression hooks); the first post-load user edit emits exactly one.
**R3 — Note embed.** Bar: the note's markdown contains only the fenced reference; an embed edit is instantly visible in the full tab; serializer round-trip is byte-stable.
**R4 — Tools + tracked changes.** Bar: June's "clean column C" stages as chips, never a blind write; accept/reject works per cell and per turn; delete-column blocks until per-turn approval; every op lands in the ledger in the locked shape.
**R5 — Presence (1Code only).** Bar: the mascot pins to the Data tab streaming "cleaning column C" bound to the real op; the MAS build contains zero presence symbols.
**R6 — Charts + provenance.** Bar: an OSS chart renders from a selected range; its note block carries the ledger pointer; editing the source flags it stale.
**R7 — Scale + hardening.** Bar: 100k rows open and scroll smoothly with windowed hydration; every failure-table row has a witnessed graceful path; the ledger stays bounded under a 10k-cell synthetic agent edit.

## Dependencies / hand-off seams
EPI-RP-02-LUMENLENS: lens host, epoch pattern, suggestion schema + ledger, serializer tiers, minimal-diff writeback — RECKONER consumes, never modifies. EPI-RP-05-KINDRED: presence bus, run-state enum, ApprovalGate, KINDRED_ENABLED gating — RECKONER publishes and routes through. EPI-RP-07-KEELSTONE: vault storage, sync/move, watcher — RECKONER's artifacts live under it. Full contracts in HANDOFF_CARDS.md; coherence proven in CONTRADICTION_SWEEP.md.

## Open questions (preserved, sharp)
1. IronCalc 0.7.x wasm surface: constructor arity and full exported method set — read the shipped ironcalc.d.ts; blocks ironcalc-client.ts.
2. Does the wasm build export UserModel (diff history, undo, to_bytes, apply_external_diffs)? Decides where tracked-changes diffing lives.
3. Exhaustive Univer value-mutating command enumeration (paste, fill, cut, clear, structural, sort) — a missed command is a renderer-authority breach.
4. vchart-plugin version compatibility against the pinned Univer; if it lags, execute the native-chart fallback early.
5. WebAssembly.instantiateStreaming through the custom scheme with brotli pre-decompression and application/wasm MIME on macOS WebKit.
6. Measured 100k×30 IronCalc memory + evaluate latency; sets the active-sheet scoping threshold.
7. The exact tabular conflict rule for simultaneous agent+user edits to one cell (rebase vs flag), consistent with diff3-v1.
8. The CSV→workbook promotion rule: the precise moment formulas/styles/sheets force XLSX truth, surfaced to the user, never silent.

## Self-critique + rubric
Weakest three: the IronCalc wasm edge surface is inferred beyond the verified core loop (OQ-1/2 are the highest-leverage unknowns and R0 exists to kill them); Univer interception completeness is asserted for set-range-values and assumed for the rest (OQ-3); and the 100k envelope is argued from design, not measured (OQ-5/6). Rubric: Grounded 5 · Alternatives named 4 · Build-actionable 5 · No fabrication 5 · Constraint-fidelity 5 · Integration depth 4 · Depth/novelty 4. All axes ≥4; the two 4s convert directly into R0 and R7 work rather than another paper cycle.

---

## §R-AMEND — Repo-audited binding amendments (2026-07-06; evidence in RECKONER_REVIEW_2026_07_06.md; these override the body)

1. **The truth-flip is ACCEPTED and now PROPERLY superseded upstream** (canon §0.5 + 7 sibling
   docs — see review §E). The "Locked canon" section above understated this as not-re-litigated;
   it WAS a re-litigation, and the supersession record is what makes it legitimate. Owner-reversible.
2. **IronCalc facts corrected (tarball-settled):** wasm pin **=0.7.0** (no wasm 0.7.1); Model ctor
   4-arg; NO UserModel in wasm (Model carries applyExternalDiffs/undo/redo/toBytes/
   from_bytes(bytes,language_id)); `getCellValueByIndex` does not exist. OQ-1/OQ-2 are CLOSED —
   remove the UserModel branch from D1/D6 reasoning; native-crate UserModel remains available
   Rust-side only.
3. **Charts inverted back to canon:** Swift Charts native block = PRIMARY (same provenance
   contract); vchart = experimental overlay lane, license-UNCONFIRMED (npm manifest has no license
   field) + peer-locked to Univer ^0.2.5 — decide OQ-4 at R0. D5/R6 read accordingly.
4. **`.dataset` is a plain enum case** (String raw-value enum, guard-pinned) with ~6 mechanical
   touch points (enum switches, noteModeOptions csv/xlsx→[.dataset], preferredInitialMode,
   openInEditor lane, two exhaustive switches, the surface mount) — "one case + registration,
   nothing else" is amended to this exact list. resolvedNoteMode untouched.
5. **Suggestion schema UNIFIED with the locked LUMENLENS shape** (typed Author; AcceptState
   Pending/Accepted/Rejected — Superseded needs explicit negotiation into the locked schema or is
   dropped; updated_at_ms restored) + the append-only events idiom (SuggestionStaged/Resolved on
   the ledger pattern). Sweep item 2's "resolved" was premature.
6. **F2 tools land in the REAL registry:** ToolRegistry::register_default_tools (registry.rs:942),
   dot-namespaced dataset.* async ToolHandlers with real JSON schemas, deps captured at
   registration, MAS mutation-allowlist entries. The bespoke ToolDispatch trait is a design sketch
   only. UniFFI surface per bridge.rs contract (Records, AgentErrorFFI+ffi_guard, opaque handles,
   AgentEventDelegate frames for streaming; no tuples/String errors/Box<dyn Fn> across FFI).
7. **Grid load-state ports the FULL locked pattern** (loading flag + time-window suppression +
   inbound epoch validation; depth counter = re-entry guard only); edit-intercept **fails CLOSED**;
   the intercept API is re-proven at the pin (onBeforeCommandExecute is deprecated at 0.25.1 —
   addEvent path).
8. **Write path:** CSV writeback = splice-in-memory → AtomicVaultWriter whole-buffer; XLSX needs a
   Data overload (KEELSTONE seam item); Rust returns bytes, SWIFT persists (Rust never writes GRDB
   or vault files). DatasetStore: `nonisolated`, pool pinned to SearchIndexService's existing DB
   (B4 — the derived cache joins the one derived store), FormulaRow + writes added.
9. **Packaging seam added to scope:** web/reckoner-grid needs package.json + webpack config +
   build-reckoner-grid.sh + project.yml preBuild entries + Resources staging + a LAZY chunk so the
   shared js-editor bundle (MAS included) never eagerly absorbs Univer+IronCalc-WASM. Budget in
   R0/R2.
10. **Deferred-not-killed (recorded upstream):** dual-zone/defined-names, the §2 four-layer binding
   shape, and record-LEVEL first-class vault objects (v1 = dataset-level nodes/links) — the wave
   silently dropped them; they are now explicit post-v1 deferrals, owner-reversible.
11. **KEELSTONE addendum required and issued** (indexed-set/artifact routes + conflict delegation +
   soak extensions — review §F); Handoff Card 3 now names it. **KINDRED K-AMEND 11 required and
   issued** (dataTab Surface variant, datasetId Location slot, live detail field; emit to the Swift
   hub). Handoff Card 2 updated accordingly.
12. **Guard pins:** any dataset slash item updates the exact-count/ID-set pins in the same commit;
   the .dataset enum work must not disturb NoteEditorLayoutTests:238's pinned declaration.
