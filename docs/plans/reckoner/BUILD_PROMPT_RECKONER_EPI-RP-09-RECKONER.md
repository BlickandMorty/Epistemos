# BUILD_PROMPT_RECKONER
ID: EPI-RP-09-RECKONER · Codename: RECKONER
Audience: (a) the coding agent implementing against the private repo; (b) reviewing agents pressure-testing before code lands. The spine/ folder beside this file is the binding contract — juxtapose it against the repo and extend the real files it names. CONTRADICTION_SWEEP.md and HANDOFF_CARDS.md define the coherence obligations; a change that breaks either is a failed change regardless of local correctness.

## Ground rules (violating any is a failed change)
- The vault artifact (CSV flat / XLSX-.icalc workbook) is truth. GRDB is a derived cache and working store — it never becomes authoritative.
- Univer is a renderer. No value computed by Univer may ever reach persistence. IronCalc evaluates everything; the silent-Univer registration plus the command intercept are the enforcement, and the R0 smoke test is the proof.
- Loading a dataset emits zero change/autosave events — the grid epoch/suppression pattern extends the locked editor pattern, it does not reinvent it.
- No agent tool writes cells directly. Every proposed change is a TabularSuggestion in the locked provenance shape, staged as chips, destructive ops gated per turn, committed only on accept through the normal calc path.
- xlsx never runs in the WebView — the wasm build does not contain it. All xlsx lives in agent_core/src/reckoner/csv_xlsx.rs.
- Presence is 1Code-only behind KINDRED_ENABLED; June runs identical tools with no presence. Grid presence rides the existing companion bus with the existing run-state enum — no new channel, no new states.
- Platform hygiene: @Observable; never block @MainActor; DispatchQueue.main.async never .sync in UniFFI callbacks; keys in Keychain; no subprocess on MAS; graph via public API only; never hand-edit .xcodeproj.

## Coding agent — phase by phase
**R0 — Silent-Univer spike (do this before anything else).** Stand up a throwaway WebView with the pinned Univer + @ironcalc/wasm. Implement silent-univer.ts registration and the smoke test: "=1+1" must leave Univer holding the string while IronCalc returns 2 through the paint-back path, and "=A1*3" must recompute on A1 edit. While in there, settle OQ-1 and OQ-2 by reading the shipped ironcalc.d.ts (constructor arity; whether UserModel is exported) and record the answers in ironcalc-client.ts and calc_facade.rs. If notExecuteFormula turns out to register elsewhere on the pinned version, fix silent-univer.ts and note it — the test, not the comment, is the contract.

**R1 — Truth + persistence.** Implement csv_xlsx.rs import (stream-parse in Rust, build the model, hand to_bytes to Swift), DatasetMigrations + DatasetStore batch commit and windowed reads, and VaultArtifact row-level CSV writeback that preserves delimiter/quoting/line endings outside changed rows. Wire the frontmatter link per DatasetRef.

**R2 — Tab mount.** Add the single .dataset case to NoteWorkspaceMode (LUMENLENS-owned file — one enum case and a host registration, nothing else), implement DatasetTabHost with the custom-scheme bundle (root HTML through the scheme so wasm fetches route through the handler; application/wasm MIME — verify OQ-5 here), and GridBridge with epoch ownership and stale-drop. Assert zero change/autosave during load via the suppression hooks.

**R3 — Embed.** Implement dataset-embed.ts node view hosting embed-grid.ts against the same dataset; register into Tier B through the LUMENLENS serializer registry; round-trip test asserts the note carries zero cell data. Implement the relink placeholder on embedInvalidated.

**R4 — Tools + tracked changes.** Implement dataset_ops.rs (refine is_destructive per-op, erring gated), the ApprovalGate routing, suggestion-layer.ts chips, and ledger append/accept in the locked shape. Encode the regression: an agent edit may never apply without its suggestion UI.

**R5 — Presence.** Implement ReckonerRunState emit onto the companion bus; verify the MAS build contains zero presence symbols (extend the existing leak-detector CI row to scan for Reckoner presence symbols too).

**R6 — Charts.** Pin @visactor/univer-vchart-plugin against the pinned Univer (OQ-4 — if incompatible, build the native chart block instead, same provenance contract); write the ledger provenance record before the overlay exists; wire staleness on datasetChanged.

**R7 — Scale + hardening.** Windowed hydration; dirty-cell repaint audit; the 100k×30 bench (OQ-6) with real numbers recorded; every failure-table row exercised; tabular retention caps set from the bench.

## Reviewing agents — pressure-test assignments
1. Enumerate every value-mutating Univer command on the pinned version (paste, fill/autofill, cut, clear, insert/remove row/col, sort) and prove each either routes through the intercept or cannot alter values — publish the list into VALUE_MUTATING_COMMANDS. Any bypass is a P0 (renderer became an authority).
2. Read the shipped ironcalc.d.ts and certify the full Model/UserModel surface against calc_facade.rs; flag any facade method IronCalc cannot back.
3. Attack the load path: rapid open/close, reload mid-load, stale-epoch injection — any emitted autosave during load is a P0.
4. Attempt to make GRDB authoritative: delete the vault CSV, edit, and check what wins on reopen; the correct behavior is relink/conflict surfacing, never silent GRDB resurrection.
5. Try to sneak an agent write past the suggestion layer (direct setValues, forged accepted state). Any success is a P0.
6. Fuzz the CSV writeback for fidelity: exotic quoting, embedded newlines, BOM, CRLF — the untouched rows must be byte-identical.
7. Verify the MAS build has zero presence symbols and that the KINDRED_ENABLED row still compiles the full path.
8. Bench the embed: ten embeds of one 100k-row dataset in one note — memory and scroll must stay sane (shared model, not ten copies).

## Embedded research questions (investigate, don't assume)
The eight open questions in PLAN_RECKONER §Open-questions are the assignment list; OQ-1 through OQ-3 block R0/R4 and come first. Additionally: measure whether a second small Univer instance or a canvas view is the right embed renderer (memory per instance decides), and whether IronCalc's to_bytes snapshot round-trips styles well enough to be the tab-handoff format or GRDB hydration should remain primary.

---

## REPO REALITY ADDENDUM (2026-07-06 audit — binds like the ground rules; spine headers carry the per-file detail)

1. **Read the AUDIT AMENDMENT header atop every spine file first** — they encode tarball-settled
   facts (wasm =0.7.0, 4-arg ctor, no UserModel, no getCellValueByIndex, deprecated
   onBeforeCommandExecute) and the P0 fixes (fail-CLOSED intercept, full load-state port, wired
   loop + inbound dispatcher, plain `.dataset` case + 6 touch points, mod.rs + registry-based
   tools + UniFFI surface, unified suggestion schema, AtomicVaultWriter write path,
   nonisolated+pinned-pool DatasetStore, teardown on the tab host, lazy-chunk packaging).
2. **OQ-1/OQ-2 are CLOSED** (see §R-AMEND 2) — do not re-investigate; R0's spike now VERIFIES the
   settled facts on the pinned versions instead of discovering them.
3. **Charts:** build the native Swift-Charts block as primary in R6; vchart only if OQ-4 clears
   license + compat at R0.
4. **Phases unchanged in intent; scope adjustments:** R0 also stands up the web/reckoner-grid
   packaging (build script + preBuild + lazy chunk); R2's enum work follows the 6-touch-point list
   + guard-pin discipline; R4 lands tools in ToolRegistry::register_default_tools with JSON
   schemas + MAS allowlist + the UniFFI Records; R5 emits to the SWIFT presence hub and needs
   KINDRED's K-AMEND 11 contract additions; R6 provenance contract unchanged.
5. **KEELSTONE seam:** dataset artifacts join the reconciler's watched set via the KEELSTONE
   addendum (its docs now carry it) — coordinate, don't fork the watcher. CSV/workbook writes go
   through AtomicVaultWriter (Data overload for binary).
6. **Build discipline:** isolated DerivedData; BUILD SUCCEEDED both targets per phase; never two
   xcodebuilds; pathspec-scoped commits; never commit .research-clones/; js-editor changes restage
   via build-tiptap-bundle.sh; new grid bundle via its own script; update pinned guard tests in the
   same commit as the change they pin.
