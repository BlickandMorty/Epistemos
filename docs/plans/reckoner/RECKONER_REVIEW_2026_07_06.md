# RECKONER — Deliberate pre-build review (#4) (Claude, 2026-07-06)

ID: EPI-RP-09-RECKONER · Codename: RECKONER
Reviewed: the wave (plan + prompt + 20-file spine + its own sweep + 5 handoff cards) via a
5-auditor workflow (web-grid / native / rust / doc-coherence / spine-deep — the last pulled LIVE
npm tarballs: @ironcalc/wasm 0.7.0, @univerjs/* 0.25.1, @visactor/univer-vchart-plugin 2.0.0).
**Verdict: GO — with the largest amendment set of any wave.** The architecture is right (including
its boldest move); the spine needed more correction than any prior wave because it is the most
code-ambitious. Every fix is bound in the spine headers, §R-AMEND, and the upstream supersessions.

## A. THE TRUTH-FLIP — ACCEPTED (owner-reversible, properly superseded)
The wave flipped dataset truth: canon §0.5 (LOCKED) said "SQLite/GRDB is the single durable truth";
the wave makes the **vault artifact (CSV flat / XLSX-.icalc workbook + .dataset.md companion) the
truth, GRDB a derived cache/working store**. Accepted because: (1) it honors fabric F1 literally
(no private store authoritative over the vault); (2) it matches the owner's whole arc — files as
real Finder paths, KEELSTONE 4.5, "survives Epistemos being uninstalled"; (3) it **dissolves D6**,
the hardest open fork (no SQLite-under-third-party-sync exposure — the durable file is a sync-safe
format, the cache is rebuildable); (4) datasets become architecturally identical to notes (file
truth + derived cache + reconcile) — one mental model.
**Process foul corrected:** PLAN:8 silently REWROTE the locked canon to the flipped version under a
"not re-litigated" banner. The flip is legitimate only WITH a supersession record — now written
across all upstream docs (see §E). The sweep's "no unresolved contradictions" was false at the
parent-canon layer; its scope ("vs sibling decisions") structurally excluded the parent.

## B. EMPIRICALLY SETTLED (tarball evidence — the wave's open questions shrink)
- **OQ-1 SETTLED:** wasm `Model` ctor is **4-arg** (name, locale, timezone, language_id); the wasm
  pin is **=0.7.0** (0.7.1 exists only for @ironcalc/nodejs — the wave conflated siblings).
- **OQ-2 SETTLED:** the wasm build exports **NO UserModel**; `Model` carries applyExternalDiffs /
  undo / redo / toBytes / from_bytes(bytes, language_id). (The NATIVE Rust crate's UserModel remains
  canon-verified — the distinction is wasm-vs-native, now explicit in calc_facade's header.)
- `notExecuteFormula` VERIFIED real (sheets-formula 0.25.1 config.d.ts:38). `set-range-values`
  command ids + `setRowCount(100000)` VERIFIED. `onBeforeCommandExecute` VERIFIED **but DEPRECATED**
  at 0.25.1 → use `addEvent(Event.BeforeCommandExecute)` or re-prove throw-cancel at the pin (R0).
- `getCellValueByIndex` **DOES NOT EXIST** (fabrication; real reads: getCellContent/-Style/-Type/
  getFormattedCellValue).
- vchart plugin: exists, but its npm manifest declares **NO license** ("MIT VERIFIED" was half-true),
  peer-locked to Univer ^0.2.5 + React 18, stale since 2024-11.

## C. CHARTS — verdict inverted back to canon
Canon §0.9 + RESHAPE: "**Swift Charts** stands." The wave made vchart primary with a non-Swift
"native fallback" and zero Swift-Charts mentions — an unrecorded inversion, now REVERSED:
**Swift Charts native chart block = primary** (same provenance contract: ledger pointer before the
chart exists, staleness on datasetChanged); vchart = the "later if needed" webview overlay lane,
license+compat-gated, decided at R0 not R6.

## D. Defect summary (all bound in spine headers; top items)
**P0** — edit-intercept **fails OPEN** (null intent → Univer commits as authority — the exact breach
it warns about; must fail CLOSED) · the web loop is **unwired** (no index.ts, paintBack/postOutbound
never called, no inbound dispatcher) · suppression is a sync depth counter — **weaker than the
locked LUMENLENS pattern** (needs grid-load-state.ts: loading flag + time-window + inbound epoch
validation) · IronCalc facts (B) · `.dataset(DatasetRef)` **impossible** (String raw-value enum,
guard-pinned) → plain case + ~6 mechanical touch points (exact list in the native audit + spine
header) · Rust spine uncompilable (no mod.rs) + `&dyn CalcEngine` cannot dry-run + the bespoke
ToolDispatch is **unreachable by June** (real seam: ToolRegistry::register_default_tools,
registry.rs:942, async ToolHandlers + JSON schemas + MAS mutation allowlist) + **zero UniFFI surface
designed** (tuples/String-errors/Box<dyn Fn> all violate the bridge contract).
**P1** — dataset-embed.ts: content hole on an atom leaf (runtime throw), broken attr round-trip,
invalid null addNodeView, **no markdown serialization → silent data loss into the .md**, never
registered · TabularSuggestion "field-for-field" claim FALSE (typed Author, 3-vs-4 accept states,
missing updated_at_ms) + no append-only events idiom · GridBridgeMessage "drift = build failure"
has zero enforcement (custom Codable + parity fixture needed) · presence seam: KINDRED's
CompanionPresence lacks a Data-tab Surface variant / datasetId / live detail (→ K-AMEND 11) and the
emit target must be the Swift hub, not agent_core · DatasetStore not `nonisolated` under the
module's MainActor default (main-thread DB IO) + pool unpinned (one sentence from a B4 violation)
· VaultArtifact writeback language invites in-place partial IO (must be splice-in-memory +
AtomicVaultWriter whole-buffer; XLSX needs a Data overload; the Rust workbook write path needs an
atomic story) · guard pins (slash 18/19 + ID-set) break on any dataset slash item.
**P2** — DatasetTabHost missing dismantle/teardown (the exact 40–60MB leak Epdoc fixed) +
nonPersistent store + coordinator pattern · the entire web/reckoner-grid **packaging seam is
missing** (new top-level dir, build script, preBuild entries, staging, lazy chunk so MAS's shared
bundle doesn't absorb Univer+WASM) · dataset_ops is_destructive polarity wrong both directions ·
formula table never written · ironcalc dep = optional `reckoner` cargo feature in agent_core
(lsp-runtime precedent; canon's separate epistemos_calc crate line superseded).

## E. Upstream supersession set (written + committed alongside this review)
1. **PROMPT_PLAN_9 canon:** TRUTH-FLIP block appended — supersedes §0.5 (+§0.1 wording, §1 diagram,
   §2 header, §3.1/3.3/3.5, §4, §9-Stage-1, RESHAPE lines, supersession-map line) → vault artifact
   = dataset truth, GRDB = derived cache, commit = GRDB txn + synchronous vault writeback. Also:
   charts re-affirmed Swift-Charts-primary; **dual-zone/defined-names + §2 binding shape + record-
   level first-class objects = DEFERRED (not killed)** — the wave silently dropped them; recorded
   as explicit deferrals to post-v1 phases, owner-reversible.
2. **RESEARCH_PROMPT_PLAN_9:** annotation — constraint 3/3c, locked-keystones line, D2/D6/D10
   "GRDB truth" phrasing superseded by the accepted flip; D6's B4-exemption argument collapses
   (the reckoner GRDB is now DERIVED → B4 binds → pool = SearchIndexService's DB).
3. **MASTER_PLAN_INDEX:48** + **RESEARCH_PROMPT_STANDARD registry row**: reworded to vault-artifact
   truth. **PLAN9_ADJUDICATION**: superseded-banner (raw corpus left as history).
4. **LUMENLENS:** P-AMEND 9 rewritten (vault-artifact truth; "Data room"→dataset surfaces);
   P-AMEND 11's "Dataset truth stays GRDB" line corrected; BUILD_PROMPT item 9 wording.
5. **KINDRED:** K-AMEND 9 wording (mascot pins the Data TAB; the in-tab chat door per RESHAPE) +
   **new K-AMEND 11**: presence contract extension RECKONER needs (dataTab Surface variant,
   datasetId in Location, live detail field) + emit-to-Swift-hub.
6. **KEELSTONE:** plan §15.10 + prompt coordination item — the dataset-artifact seam (below).

## F. KEELSTONE — the inflight agent DOES need one addendum now
CONFIRMED gap: the reconciler's `isIndexedFile` covers `.md`+`.json` only — external changes to
`.csv/.xlsx/.icalc` are silently DROPPED, and `.dataset.md` would be mis-routed into the note
indexer. Handoff Card 3 assigns KEELSTONE watcher/merge duties it currently cannot perform. The
addendum (now in KEELSTONE's docs; reprompt text in the checkpoint message): (a) extensible
indexed-set / artifact-route registration (csv/xlsx/icalc → dataset re-derive hook; *.dataset.md →
companion parser); (b) conflict DELEGATION for artifacts (KEELSTONE detects+routes; RECKONER
resolves: clean→re-derive+repaint, dirty→user-wins/rebase-or-flag, moved/deleted→embedInvalidated
+relink — never conflict-copy a CSV); (c) release-gate soak extensions (kill-9 mid CSV-writeback,
sync-storm on a CSV, cache-rebuild==re-derive equivalence, delete-CSV-then-edit → relink never
silent GRDB resurrection); (d) Phase 4.5's grep-leg is UNAFFECTED (note-body scoped).

## G. What the wave got right (keep exactly)
The truth-flip architecture; the R0 spike-first discipline (settle unknowns by test, not comment);
honest version-gating with the smoke test as arbiter; TabularSuggestion-through-ApprovalGate (no
blind agent writes); reference-only embeds; xlsx quarantined to Rust; presence as a KINDRED subset;
the failure table; the reviewer pressure-tests (esp. #1 command enumeration, #5 sneak-a-write,
#6 CSV fuzz); five handoff cards as a form. R0–R7 phase bars stand with the amendments folded in.
