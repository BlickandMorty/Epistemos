# LUMENLENS Intent Ledger

Date: 2026-07-07
Lane: LumenLens structural implementation and hardening only.

## Checkpoint 2026-07-07 Owner Steer

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Do not discard current work and do not restart the plan. Pause implementation long enough to reconcile state, then continue the forever loop deliberately.
>
> Important: Keelstone audit and LumenLens implementation are two separate lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> For LumenLens: continue the implementation loop, but treat "revamp / V2 / refactor / upgrade" as real structural behavior and not a wrapper/reskin/polish pass. Use the plan and build prompt as binding.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.
>
> After each edit batch: re-read changed regions, inspect the diff, run the relevant checks or update verification debt, then continue the deep-hardening loop. Do not claim done just because a checklist ends or one test passes.

### Interpreted intent

Continue the existing LumenLens implementation from the current dirty worktree, not from scratch. Treat L0-L6 and P-AMEND 10-13 as binding product behavior: epoch-guarded loads, suggestion schema, serializer tiers, minimal-diff writeback, note-session lease behavior, provenance, fidelity disclosure/export, notebook tabs, block embeds, and enterprise markdown housing rules.

### Hard constraints

- Do not use Keelstone evidence as LumenLens completion evidence.
- Keep Epdoc as the default document lens.
- Extend live modules; do not replace guard-pinned files or invent parallel editor stacks.
- Use `epistemos-doc://`, not `epdoc://`.
- The loader may keep `emitUpdate: false`, but correctness must live in load epochs and transaction filtering.
- Disk writeback splices in memory and writes the whole buffer through Keelstone AtomicVaultWriter.
- Do not build KINDRED chat internals or RECKONER grid internals; consume their seams by id/reference.
- Keep MAS companion leakage impossible.
- Batch broad builds/tests, but run narrow JS/Swift/Rust checks when they prove the edited unit.

### Non-goals

- Do not reopen Keelstone implementation except to consume its published seams.
- Do not implement a new chat system or Data room.
- Do not make rich content invisible in weaker lenses.
- Do not claim L2/L6 done if previews are placeholders, exports are not functional, or unknown references are not byte-preserved.
- Do not claim L4 done if write leases are only a UI affordance and not the specified persistence/coordination contract.

### Current Keelstone audit status

Keelstone Phases 0-4 have targeted evidence sufficient to continue LumenLens carefully. Keelstone Phase 4.5 has strong source evidence but still has runtime/migration debt. Keelstone Phases 6-8 are not release-complete; they remain Keelstone audit debt, not LumenLens blockers for local implementation batches.

### Current LumenLens implementation status

- L0: `document-load-state.ts` now includes a load epoch, suppression window, host-load metadata, user-input metadata, and `filterTransaction` rejection for stale non-user transactions. Epdoc bridge tests include epoch-stamped load commands and stale epoch update handling. Narrow JS proof exists; broader Swift bridge coverage is still batched.
- L1: suggestion adapter and marks exist under `js-editor/src/suggestions/`, using `@handlewithcare/prosemirror-suggest-changes`, block-level suggestion doc marks, apply/revert, and a noop adapter. Dependency and bundle verification remain pending.
- L2: serializer tier/fidelity registry exists in `js-editor/src/markdown/tiers.ts`; native disclosure scanner/UI exists in `LensFidelityDisclosure.swift`. Narrow round-trip proof exists. Current native previews/exports appear source/raw-text oriented, so the owner-mandated high-quality rendered preview/export bar is not yet proven and likely needs hardening.
- L3: `minimal-diff-writeback.ts` implements `ChangeSet.changedRange`, top-level block expansion, byte/code-unit ranges, and in-memory splicing. Narrow JS proof exists. Host integration to durable writeback remains to be audited and verified.
- L4: `NoteSessionStateMachine.swift` implements lease ownership, follower behavior, external change states, autosave, lens-switch flushing, documented v1 undo-loss, and a GRDB-backed `note_session` row through `NoteSessionGRDBLeaseStore`. `NoteDetailWorkspaceView` attaches that store via the existing `vaultSync.searchService?.databaseWriter()` before opening the note session. Remaining risk is runtime contention, sync DB writes on the main actor, and broader suite/MAS coverage.
- L5: `agent_core/src/provenance/suggestion_schema.rs` implements an in-memory suggestion ledger, replay bundle, BLAKE3 integrity, compaction, and FFI-facing exports through `bridge.rs`. Durable editor-domain GRDB persistence remains to be verified.
- L6: `EpdocNotebookManifest.swift`, notebook UI integration, TOC item extensions, and disclosure integration exist. Real RECKONER/KINDRED content mounts are intentionally seam-owned elsewhere; LumenLens still owns reference manifests, tombstones, navigation, and export/disclosure behavior.

### Contradictions/questions

- P-AMEND 10 requires robust high-quality previews and working exports; current native disclosure exports raw/source text and may not satisfy chart image, dataset xlsx/CSV, or chat transcript export bars.
- L4 now has a focused GRDB `note_session` implementation and test proof. Remaining question: whether synchronous GRDB access from the main-actor state machine needs an async store wrapper before broader runtime/multi-window hardening.
- L3 is implemented as JS logic, but the bridge must prove minimal writeback metadata reaches Swift and still writes whole-buffer atomically through Keelstone.
- L5 durable persistence is specified as GRDB editor-domain storage, but current Rust module is intentionally in-memory.

### Next smallest safe action

Run the next narrow LumenLens unit checks that match the next source batch. Based on current reading, the next likely structural gap is P-AMEND 10 / L2 robust fidelity preview and export behavior, then L3 durable host writeback audit.

## Checkpoint 2026-07-07 L2 Dataset Export Seam

### Verbatim steer excerpt

> For LumenLens: continue the implementation loop, but treat "revamp / V2 / refactor / upgrade" as real structural behavior and not a wrapper/reskin/polish pass. Use the plan and build prompt as binding.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.

### Interpreted intent

P-AMEND 10 says dataset tab/embed disclosure exports must include XLSX via IronCalc and CSV. Current LumenLens owns the disclosure registry/UI but RECKONER owns actual dataset artifact/calc bytes. The safe LumenLens action is to add a typed dataset export provider seam and consume real provider-returned CSV/XLSX bytes when available, while keeping fallback reference exports honest until RECKONER lands the live provider.

### Hard constraints

- Do not implement the RECKONER grid, calc facade, or dataset truth model inside LumenLens.
- Do not claim real IronCalc `save_to_xlsx` proof while the live RECKONER provider is not present.
- Preserve the existing `LensFidelityDisclosure.items(in:lens:)` call path with a default provider.
- Add tests that inject provider bytes so LumenLens proves the handoff/export contract rather than just an enum string.

### Non-goals

- No new Data room.
- No fake workbook generation labeled as IronCalc output.
- No broad Swift suite or App Store lane in this micro-batch unless the focused check exposes shared compile failures.

### Contradictions/questions

- The JS registry already marks dataset exports as `xlsx`, but native disclosure currently returns CSV-only reference exports for dataset tabs/embeds.
- RECKONER spine documents `save_to_xlsx`/artifact ownership, but live app code only routes dataset artifacts and logs the RECKONER hook as pending.

### Next smallest safe action

Add a `LensFidelityDatasetExportProviding` seam to `LensFidelityDisclosure.swift`, thread it through dataset tab/embed export generation, test provider-injected XLSX+CSV exports, update source guards, re-read changed regions, and rerun the focused L2 Swift batch.

## Verification Evidence

- 2026-07-07: `node js-editor/scripts/check-document-load-state.mjs` passed for L0 epoch/load-state behavior.
- 2026-07-07: `node js-editor/scripts/check-suggestions.mjs` passed for L1 suggestion adapter behavior.
- 2026-07-07: `node js-editor/scripts/check-markdown-roundtrip.mjs` passed for L2 serializer tier fixtures.
- 2026-07-07: `node js-editor/scripts/check-minimal-writeback.mjs` passed for L3 block/byte-range writeback fixtures.
- 2026-07-07: `cargo test --manifest-path agent_core/Cargo.toml suggestion_schema` passed for L5 replay/hash/compaction tests, including the 10k stress case.
- 2026-07-07: Targeted Swift L4/source-guard check initially failed twice on `NoteSessionStateMachine.swift` with `Missing return in instance method expected to return 'String?'`. Patched explicit optional returns in `NoteSessionGRDBLeaseStore.ownerID(for:)` and `NoteSessionLeaseRegistry.ownerID(for:)`.
- 2026-07-07: `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/NoteSessionStateMachineTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_12-40-57--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 24 passed tests, 0 failed tests.
- 2026-07-07: L2/P-AMEND 10 native disclosure hardening added typed preview/export models, chart SVG export, table CSV export, full quarantine raw export, dataset/reference CSV export, and chat transcript export in `LensFidelityDisclosure.swift`; `EpdocNotebookManifestTests` now covers chart/table/quarantine/notebook reference previews and primary exports.
- 2026-07-07: First focused L2 Swift batch was blocked by a transient/stale compile of the unrelated untracked `EpistemosTests/ExperimentalAgentPolishSourceGuardTests.swift`; direct `xcrun swiftc -parse EpistemosTests/ExperimentalAgentPolishSourceGuardTests.swift` passed, and rerunning the focused batch succeeded.
- 2026-07-07: `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocNotebookManifestTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_13-03-04--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 24 passed tests, 0 failed tests.
- 2026-07-07: L2 dataset export seam hardening added `LensFidelityDatasetReference`, `LensFidelityDatasetExportProviding`, provider-threaded disclosure scanning, and dataset export prioritization so provider XLSX bytes sort before CSV/reference fallbacks. `EpdocNotebookManifestTests` now injects workbook bytes and CSV via a fixture provider and verifies sheet tabs and block dataset embeds expose XLSX as the primary export with CSV still present.
- 2026-07-07: The first provider-seam focused Swift run failed only because `EpdocVisibilitySourceGuardTests` still matched the old one-line `items(in:lens:)` signature. The guard was updated to the new multiline provider-bearing signature.
- 2026-07-07: `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocNotebookManifestTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed after the dataset-provider seam. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_13-19-13--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 24 passed tests, 0 failed tests.

### Verification Limits

- The L4 focused pass proves compileability, source-guard wiring, and a GRDB `note_session` lease row path using an in-memory test database. It does not prove full Swift suite health, real multi-window contention, crash/restart persistence, App Store target safety, or nonblocking DB behavior.
- The L2 focused passes prove the native disclosure parser/model/export helpers, provider-consumed dataset XLSX/CSV bytes, corpus-style Swift fixture behavior, and source-guard wiring. They do not prove the full 100+ real-vault-file UI corpus, rendered popover screenshots, jump-to-Epdoc runtime behavior, live RECKONER/IronCalc `save_to_xlsx` bytes, App Store target safety, or broad suite health.
- The JS/Rust narrow passes prove their edited unit fixtures, not app-wide bundle behavior or App Store/MAS leakage.

## Verification Debt

| Deferred command | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
|---|---|---|---|---|
| `node js-editor/scripts/check-document-load-state.mjs` | `js-editor/src/bridge/document-load-state.ts`, inbound bridge | L0 correctness is transaction filtering, not loader intent | Stale epoch transactions rejected; user transactions accepted | After any load-state or inbound bridge edit |
| `node js-editor/scripts/check-suggestions.mjs` | `js-editor/src/suggestions/*`, package deps, bridge payloads | L1 can fail from schema/API mismatch with HWC | Agent edit becomes suggestion marks; accept/reject work; noop remains swappable | After suggestion adapter or dependency edits |
| `node js-editor/scripts/check-markdown-roundtrip.mjs` | `js-editor/src/markdown/tiers.ts`, markdown nodes, #440 fixtures | L2 must not corrupt frontmatter, tables, wikilinks, manifests, embeds, or quarantine bytes | Tier A/B/C round trips; #440 and notebook/embed fixtures pass | After serializer/tier edits |
| `node js-editor/scripts/check-minimal-writeback.mjs` | `js-editor/src/markdown/minimal-diff-writeback.ts` | L3 done-bar depends on one-region block splicing, byte ranges, and multi-MB behavior | Changed block only; frontmatter untouched; unicode/CRLF/large fixture pass | After writeback logic edits |
| `xcodebuild test ... -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests -only-testing:EpistemosTests/NoteSessionStateMachineTests -only-testing:EpistemosTests/EpdocNotebookManifestTests -only-testing:EpistemosTests/EditorProvenanceStoreTests` | Swift bridge, source guards, session, notebook, disclosure, durable provenance | Swift wiring can drift from JS/source-only implementation | Targeted Swift suites pass | After Swift LumenLens edit batch |
| `cargo test --manifest-path agent_core/Cargo.toml suggestion_schema` | `agent_core/src/provenance/suggestion_schema.rs`, `bridge.rs` | L5 replay/compaction/FFI must be deterministic and unwrap-free | Suggestion ledger unit tests pass | After Rust provenance edits |
| `bash build-tiptap-bundle.sh` | JS editor bundle and `Epistemos/Resources/Editor/*.br` | JS changes do not reach app without restaged bundle | Bundle rebuilds and resource hashes update | After JS implementation batch before app test |
| App Store target build/test batch | AppStore gating, companion leakage, bundle resources | LumenLens must not leak companion-only symbols or runtime deps into MAS | AppStore build/test lane passes and symbol scan clean | Before any MAS-safe LumenLens claim |

## Checkpoint 2026-07-07 Re-anchor After Context Transition

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Do not discard current work and do not restart the plan. Pause implementation long enough to reconcile state, then continue the forever loop deliberately.
>
> Important: Keelstone audit and LumenLens implementation are two separate lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> For LumenLens: continue the implementation loop, but treat "revamp / V2 / refactor / upgrade" as real structural behavior and not a wrapper/reskin/polish pass. Use the plan and build prompt as binding.
>
> After each edit batch: re-read changed regions, inspect the diff, run the relevant checks or update verification debt, then continue the deep-hardening loop. Do not claim done just because a checklist ends or one test passes.

### Interpreted intent

Continue the current LumenLens implementation from the dirty worktree without
discarding narrow evidence already gathered. Treat the plan and P-AMEND items as
binding structural behavior: epoch/load guards, tracked suggestions, tiered
serialization, minimal writeback, write leases, provenance, robust disclosure
and exports, notebook tabs, block embeds, and enterprise markdown housing.

### Hard constraints

- Keep Keelstone audit evidence and LumenLens implementation evidence separate.
- Extend live modules and guard-pinned seams; do not replace the editor stack.
- Use `epistemos-doc://`; do not create an `epdoc://` scheme.
- Keep Epdoc as the default rich lens.
- Do not build KINDRED chat internals or RECKONER grid/calc internals.
- Use whole-buffer atomic writeback through Keelstone after in-memory splicing.
- Batch broad builds/tests, but run narrow checks when an edit affects a unit's
  done bar.

### Non-goals

- No Keelstone implementation in the LumenLens lane.
- No new Data room or chat system.
- No fake IronCalc workbook generation or claim of live RECKONER bytes.
- No MAS-safe or release-complete claim without App Store lane evidence.

### Current Keelstone audit status

Targeted Keelstone evidence is enough to proceed with local LumenLens work, but
Keelstone remains release-incomplete: full Swift suite, built-app gates, real
perf JSON, runtime/migration E2E, release soaks, and upgrade matrix remain debt.

### Current LumenLens implementation status

L0-L4 have narrow JS/Swift evidence. L5 currently has an in-memory Rust
suggestion ledger and read-only FFI export proof, but durable editor-domain GRDB
persistence is still the next structural gap. L6 has native notebook manifest,
TOC, tombstone/disclosure integration, and focused tests. L2 disclosure now
consumes provider-supplied XLSX/CSV bytes through a dataset export seam, but
live RECKONER/IronCalc exports and runtime popover screenshots remain debt.

### Contradictions/questions

- The build prompt says L5's Rust append/replay/revert work, while P-AMEND 6
  says durable persistence is a Swift/GRDB editor-domain table with `claim_id`
  linkage. The next batch must respect both: Rust remains in-memory/FFI audit,
  Swift owns durable storage.
- The L2 dataset export provider proves the handoff, not real IronCalc.
- L4's synchronous GRDB lease store may need further runtime contention review
  before broad claims.

### Next smallest safe action

Read the L5 durable provenance spine and existing GRDB patterns, then implement
the smallest Swift editor-domain provenance store or test-backed seam that
matches `spine/EditorProvenanceStore.swift` without touching unrelated lanes.

## Checkpoint 2026-07-07 L5 Durable Editor Provenance Store

### Verbatim steer excerpt

> For LumenLens: continue the implementation loop, but treat "revamp / V2 / refactor / upgrade" as real structural behavior and not a wrapper/reskin/polish pass. Use the plan and build prompt as binding.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.

### Interpreted intent

Move L5 past an in-memory Rust-only proof by adding a durable Swift/GRDB
editor-domain persistence seam for suggestion spans, decisions, claim linkage,
and bounded compaction.

### Hard constraints

- Keep Rust replay/hash evidence and Swift durable persistence evidence separate.
- Persist editor provenance in the app domain without introducing a new runtime
  service or companion dependency.
- Preserve plan terminology: suggestion spans, pending/accepted/rejected state,
  author/source, turn id, map version, and `claim_id` linkage.
- Batch broad checks; use focused Swift tests for the current L5 unit.

### Non-goals

- No JS bridge ingestion claim yet.
- No full restart/replay claim yet.
- No MAS-safe claim yet.
- No real-vault migration claim yet.

### Current Keelstone audit status

Unchanged by this LumenLens batch. Keelstone remains audit-only with targeted
evidence and release verification debt for full suites, built-app gates, real
perf JSON, runtime/migration E2E, release soaks, and upgrade matrix coverage.

### Current LumenLens implementation status

Added `Epistemos/Views/Notes/EditorProvenanceStore.swift` with
`SuggestionSpanRecord`, typed suggestion/edit states, `EditorProvenanceStoring`,
`EditorProvenanceGRDBStore`, `suggestion_span`, `suggestion_span_summary`,
turn/pending queries, decision updates, `claim_id`, and compaction summaries.
Added `EpistemosTests/EditorProvenanceStoreTests.swift` for insert/query/decide,
missing-span failure, and compaction behavior. Extended the LumenLens source
guard to pin the durable store seam.

### Evidence

- First focused Swift run failed because the new value types and protocol picked
  up default `MainActor` isolation. Fixed with explicit `nonisolated` boundaries.
- Second focused Swift run failed because GRDB `read`/`write` are async from the
  store actor. Fixed with `try await` writer calls and async schema installation.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_13-37-28--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 22 passed tests, 0 failed tests.
- A follow-up compaction hardening batch fixed repeated compaction so
  `suggestion_span_summary.claim_ids_json` merges prior and newly compacted
  `claim_id`s instead of overwriting old links.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests` passed after the compaction regression. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_13-45-55--0500.xcresult`; summary reported `Passed`, 3 passed tests, 0 failed tests.
- A bridge-to-store handoff batch added typed Swift `suggestionResolved`
  decoding, chrome-controller `onSuggestionResolved`, a document-surface
  provenance sink, and workspace creation of `EditorProvenanceGRDBStore` from
  the existing search database writer. The sink persists accepted/rejected
  decisions for already inserted spans.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed after the bridge-to-store handoff. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_13-57-55--0500.xcresult`; summary reported `Passed`, 72 passed tests, 0 failed tests.
- An applied-span handoff batch added JS `suggestionApplied` emission after a
  successful HWC `applySuggestion` transaction, Swift
  `EpdocSuggestionSpanPayload` decoding, chrome `onSuggestionApplied`, durable
  insertion through `EditorProvenanceBridgeSink`, vault-relative note path
  threading, and `source_citation` storage.
- `npm --prefix js-editor run check:suggestions` and
  `npm --prefix js-editor run typecheck` passed after the JS applied-span
  bridge update.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed after the applied-span handoff. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-07-33--0500.xcresult`; summary reported `Passed`, 74 passed tests, 0 failed tests.
- `bash build-tiptap-bundle.sh` passed and restaged the production editor
  bundle. Git status shows updated `Epistemos/Resources/Editor/editor.js.br`
  and `editor.css.br`.
- `brotli --stdout --decompress Epistemos/Resources/Editor/editor.js.br`
  quiet string checks found both `suggestionApplied` and
  `suggestionResolved` in the staged bundle.
- A schema-hardening batch added idempotent `addColumnIfMissing` upgrades for
  legacy `suggestion_span.source_citation`, `suggestion_span.claim_id`, and
  `suggestion_span_summary.claim_ids_json` columns, plus a regression that
  starts from legacy tables and proves insert/decide/compact still preserves
  claim IDs.
- The first focused migration Swift run failed because the new legacy-table
  setup called `DatabaseQueue.write` without `await` in the Swift 6 async
  context. The test was corrected to `try await queue.write`.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed after the schema-hardening fix. Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-18-36--0500.xcresult`; summary reported `Passed`, 24 passed tests, 0 failed tests.

### Verification limits

The focused passes prove the Swift/GRDB span table contract, decision updates,
claim-link column, pending-agent query, compaction summary, typed
applied-span and accepted/rejected bridge decoding, chrome-controller handoff,
durable insertion/decision persistence for JS suggestion payloads, citation
storage, repeated compaction against an in-memory `DatabaseQueue`, and restaged
production editor bundle presence of the new bridge event strings. They also
prove an in-memory legacy-table schema upgrade for the new provenance columns.
They do not prove real WKWebView event delivery, upgrade against an existing
on-disk user vault database, runtime replay after app restart, App Store target
safety, or broad suite health. The follow-up `-only-testing` runs still compiled
the broader Swift test target and emitted unrelated existing warnings, but
executed the filtered tests.

### Next smallest safe action

Inspect the remaining L5 runtime seams: WKWebView delivery of
`suggestionApplied`/`suggestionResolved`, per-vault database migration/restart
replay, and App Store target safety. Batch those checks rather than rerunning
full builds after every source-only edit.

## Checkpoint 2026-07-07 Re-anchor Before Next Edit Batch

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Do not discard current work and do not restart the plan. Pause implementation long enough to reconcile state, then continue the forever loop deliberately.
>
> Important: Keelstone audit and LumenLens implementation are two separate lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> For LumenLens: continue the implementation loop, but treat "revamp / V2 / refactor / upgrade" as real structural behavior and not a wrapper/reskin/polish pass. Use the plan and build prompt as binding.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.
>
> After each edit batch: re-read changed regions, inspect the diff, run the relevant checks or update verification debt, then continue the deep-hardening loop. Do not claim done just because a checklist ends or one test passes.

### Interpreted intent

Continue from the existing LumenLens work without restarting or discarding
state, but re-ground against the current instruction profile before code. Keep
Keelstone as an audit lane only, continue LumenLens as the implementation lane,
and spend most time on structural editor/provenance hardening while batching
broader tests at meaningful checkpoints.

### Hard constraints

- Use the root `AGENTS.md`, `CLAUDE.md`, LumenLens plan, and build prompt as
  binding source of truth for the next code batch.
- Keep Keelstone evidence, TODOs, and completion claims separate from LumenLens.
- Treat LumenLens V2/revamp/refactor language as structural behavior: bridge,
  durable provenance, session/writeback, notebook/disclosure, and MAS gating
  must be real seams, not wrapper UI.
- Before each implementation batch, preserve owner intent and verification debt
  in this ledger.
- After each batch, re-read changed regions, inspect focused diffs, and either
  run narrow checks or record the deferred broader command with a trigger.
- Do not run competing `xcodebuild` jobs.

### Non-goals

- No Keelstone implementation in this LumenLens batch.
- No release-ready or full-plan-complete claim from source guards or filtered
  unit tests.
- No rewrite of unrelated dirty files or unrelated prompt/doc churn.
- No absorption of RECKONER sheet internals or KINDRED chat internals beyond
  the LumenLens-owned tab/disclosure/provenance seams.

### Current Keelstone audit status

Keelstone remains audit-only. Targeted/source evidence exists for retired
source scans, seeded hardening/perf gate failures, AppStoreHardening, body-truth
source guards, and the dedicated App Store Keelstone lane. Missing evidence
remains: full Swift/Xcode suite, built-app entitlement gates, produced Release
artifact scans, real Keelstone perf JSON, external editor E2E, legacy body
migration fixture, broad data-safety soaks, and first-run/upgrade matrix.

### Current LumenLens implementation status

LumenLens has narrow evidence for L0 load epochs, L1 suggestion adapter,
L2 tier/disclosure source seams, L3 minimal writeback, L4 GRDB note-session
leases, L5 Rust in-memory ledger, L6 notebook/disclosure/navigation seams, and
the current L5 durable GRDB provenance path. The newest L5 batch added typed
Swift applied/resolved bridge payloads, JS `suggestionApplied` emission, chrome
callbacks, document-surface provenance sink, workspace store wiring, durable
span/decision storage, compaction summaries, citation/claim columns, staged
editor bundle strings, and an in-memory legacy-table schema upgrade regression.

### Contradictions/questions

- The durable store is source-wired and unit-tested, but real WKWebView message
  delivery is still not runtime-proven.
- Schema upgrade is tested with in-memory legacy tables, not an existing
  on-disk user vault database reopened across app launches.
- The staged production bundle contains the new bridge event strings, but MAS
  target build/symbol/resource safety is still unproven after this L5 batch.
- Full Swift suite and release-lane checks remain intentionally deferred; do
  not let focused passes imply broad health.

### Verification debt

| Deferred command | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
|---|---|---|---|---|
| `npm --prefix js-editor run check:suggestions` | `js-editor/src/bridge/inbound.ts`, suggestion command schema | JS payload/defaulting changes can regress adapter accept/reject behavior | Suggestion fixture applies, accepts/rejects, and emits expected bridge payloads | After any JS suggestion command or payload edit |
| `npm --prefix js-editor run typecheck` | JS bridge/outbound types, suggestion adapter interfaces | Type drift can break the production editor bundle despite Swift tests passing | TypeScript compiles across bridge message unions and command surface | After any JS bridge/type edit |
| `bash build-tiptap-bundle.sh` plus brotli string check | `Epistemos/Resources/Editor/editor.js.br`, `editor.css.br` | Runtime WKWebView loads staged resources, not TS source files | Production bundle contains the latest bridge event strings | After any JS source edit that affects runtime behavior |
| Focused Swift: `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` | Swift bridge, chrome callbacks, provenance store, source guards | Cross-language schema changes can compile but fail decode/persistence handoff | Applied/resolved decode, callback, persistence, schema, and guard tests pass | After any Swift bridge/store/surface edit |
| App Store target check or source leak guard | LumenLens provenance/editor bundle under `Epistemos-AppStore` | MAS must not gain companion-only symbols or unsafe runtime assumptions | App Store lane compiles or source guard confirms no companion leak | Before claiming MAS safety for L5/L6 |
| Full Epistemos scheme test | Shared Swift app/editor/session behavior | Filtered suites miss cross-module regressions | Full local scheme test pass | Broad checkpoint after current structural L5/L6 hardening batch |

### Next smallest safe action

Inspect the remaining L5 runtime handoff seam and add the smallest test or
source guard that proves WKWebView handler routing preserves
`suggestionApplied`/`suggestionResolved` through epoch filtering into the
chrome callbacks and provenance sink. If that needs a larger runtime harness,
record it as debt and move to the next narrow structural seam.

## Checkpoint 2026-07-07 L5 Epoch-Filtered Suggestion Handoff

### Edit batch

Added a focused bridge-controller regression proving stale-epoch
`suggestionApplied` and `suggestionResolved` events are ignored after a newer
host load, while matching-epoch events still reach the chrome callbacks. Updated
the L5 source guard to pin the WK bridge path's `decodeEpoch` handoff and the
new stale-epoch executable proof.

### Touched files

- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read changed test/source-guard regions after editing.
- Inspected the focused diff for the two touched test files.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-28-38--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 71 passed tests, 0 failed tests.

### Proven by this batch

The native chrome callback seam now has executable proof that applied-span and
decision events do not leak from stale host-load epochs into the durable
provenance handoff. The source guard also pins that the WKScriptMessage handler
passes `EpdocBridgeMessage.decodeEpoch(messageBody:)` into
`handleBridgeMessage`.

### Remaining verification debt

This is still not a real WKWebView runtime/manual proof. It does not prove
WebKit delivery under the app's bundled editor HTML, nor replay after app
restart, nor App Store target safety. Those remain deferred to the next runtime,
restart, and MAS checkpoints.

### Next smallest safe action

Inspect the durable provenance store against App Store target membership and
database-writer availability, then either add a narrow compile/source guard for
MAS-safe wiring or record the App Store lane as deferred if it requires the next
broader build checkpoint.

## Checkpoint 2026-07-07 L5 Provenance Failure Visibility And MAS Source Guard

### Edit batch

Changed the document-surface provenance sink from silent `try?` writes to
explicit `do`/`catch` logging for failed applied-span and decision persistence.
Extended the L5 source guard to pin the logged failure paths, prohibit returning
to swallowed provenance errors, and assert that the durable editor provenance
store remains MAS-safe shared source without companion, Experimental, or
subprocess-only markers.

### Touched files

- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the changed production Swift and source-guard regions after editing.
- Inspected the focused diff for `MarkdownDocumentSurface`,
  `EpdocVisibilitySourceGuardTests`, and the prior bridge-test batch.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-34-38--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 71 passed tests, 0 failed tests.

### Proven by this batch

The durable editor provenance handoff no longer silently hides failed GRDB span
or decision writes. The L5 guard now pins that the App Store target continues
to include the shared `Epistemos` synced folder, while the provenance store
itself stays free of `KINDRED_ENABLED`, `EPISTEMOS_EXPERIMENTAL`,
`ExperimentalAgent`, and `Process(` dependencies.

### Remaining verification debt

This is still source-level MAS evidence, not an `Epistemos-AppStore` compile or
artifact scan. Runtime WebKit delivery, restart replay on an existing on-disk
vault database, and full-suite health remain deferred.

### Next smallest safe action

Inspect restart/replay coverage for the durable provenance store and add the
smallest focused regression that proves a span inserted through one
`EditorProvenanceGRDBStore` instance is readable/decidable through a fresh store
instance over the same writer, approximating app restart without launching the
full app.

## Checkpoint 2026-07-07 L5 Fresh Writer Reopen Proof

### Edit batch

Added an on-disk GRDB regression for durable provenance restart behavior. The
test inserts a span through one `EditorProvenanceGRDBStore`, reopens a fresh
`DatabaseQueue` and store on the same temp SQLite file to query pending agent
spans, decides the span through that reopened store, then opens a third writer
and store to verify the accepted state and citation survived.

### Touched files

- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the new on-disk reopen test and source-guard update after editing.
- Inspected the focused diff for the touched tests.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-39-28--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 25 passed tests, 0 failed tests.

### Proven by this batch

The durable editor provenance table now has focused on-disk evidence that rows
survive fresh writer/store reopen and remain decidable/readable afterward. This
is stronger than the prior in-memory legacy-table proof, but still smaller than
a full app restart E2E.

### Remaining verification debt

Not proven: app lifecycle restart with a real vault `SearchIndexService`, real
WKWebView runtime delivery, App Store target compilation after this L5 batch,
and full-suite health.

### Next smallest safe action

Inspect the bridge sink/store failure semantics for duplicate suggestion IDs
and out-of-order decisions. Add a narrow regression if the current behavior can
silently lose provenance or make retries unsafe.

## Checkpoint 2026-07-07 L5 Duplicate Span Collision Proof

### Edit batch

Added a focused durable-store regression for duplicate suggestion span IDs. The
test inserts an original span, attempts a second insert with the same ID but a
different claim/timestamp, expects the duplicate insert to fail, and verifies
the original row remains intact.

### Touched files

- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the duplicate-ID test and guard update after editing.
- Inspected the focused diff for the touched tests.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-44-39--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 26 passed tests, 0 failed tests.

### Proven by this batch

Suggestion span IDs are protected by the durable table primary key and a
duplicate event cannot overwrite the original provenance row. The L5 source
guard now pins duplicate-ID collision safety as part of the focused executable
proof set.

### Remaining verification debt

Out-of-order decision events are already covered at the store level by the
missing-span failure test, but the document-surface runtime path still only logs
that failure; real user-facing recovery/retry behavior remains unproven. Full
runtime WKWebView delivery, App Store compile, and full-suite health remain
deferred.

### Next smallest safe action

Inspect the JS suggestion payload path for edge-case validation: integer
positions/map versions, `to >= from`, and bridge parity with Swift's stricter
decoder. Add the smallest JS check if the current script does not cover invalid
or malformed payload rejection.

## Checkpoint 2026-07-07 L5 JS Payload Parser Hardening

### Edit batch

Split suggestion payload validation out of the inbound bridge into
`suggestion-payload.ts`, rejected malformed agent-edit spans before they reach
the HWC adapter, and added focused parser assertions for float, negative,
inverted, invalid map-version, and blank-ID payloads. Rebuilt the shipped
compressed editor asset after the JS runtime source change.

### Touched files

- `js-editor/src/bridge/suggestion-payload.ts`
- `js-editor/src/bridge/inbound.ts`
- `js-editor/src/suggestions/SuggestionAdapter.ts`
- `js-editor/scripts/check-suggestions.mjs`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- `Epistemos/Resources/Editor/editor.js.br`

### Evidence

- Re-read the new parser module, the inbound bridge region, the suggestion
  adapter import, the focused JS check, and the Swift source guard after editing.
- Inspected scoped status/diff for the touched JS, Swift guard, and rebuilt
  bundle asset.
- `npm --prefix js-editor run check:suggestions` passed.
- `npm --prefix js-editor run typecheck` passed.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-53-07--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 19 passed tests, 0 failed tests.
- `bash build-tiptap-bundle.sh` passed.
- Brotli runtime check reported `suggestionApplied present`,
  `suggestionResolved present`, and `loadSettled present` in
  `Epistemos/Resources/Editor/editor.js.br`.

### Proven by this batch

Malformed LumenLens suggestion payloads cannot apply tracked edits or emit
native provenance events through the typed inbound path. The focused JS check
exercises payload rejection directly, the TypeScript check proves the parser
split did not break imports, the Swift source guard pins the bridge contract,
and the compressed bundle was regenerated from the changed JS source.

### Verification debt ledger

| Deferred command/check | Touched files | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| `xcodebuild test ... -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` | `EditorProvenanceStore.swift`, bridge Swift, JS bridge/parser | Current batch changed JS and source guards, while prior durable-store tests remain relevant to L5 as a combined contract | Store, bridge decode, epoch filtering, and JS-source guards all pass together | Before leaving L5 durable provenance hardening |
| App Store target compile / MAS source gate | Provenance store, document surface, rebuilt editor bundle | L5 introduced durable storage and bridge code used by app surfaces; source guards are not artifact evidence | App Store build compiles and MAS-forbidden runtime symbols stay absent in the product lane | Before promoting LumenLens L5 evidence beyond source-level proof |
| Full Swift test suite | Cross-cutting editor, vault, and runtime surfaces | LumenLens touches shared editor/vault surfaces and can regress unrelated contracts | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete claim |
| Manual/runtime WKWebView delivery | `editor.js.br`, bridge message handlers, `MarkdownDocumentSurface` | Unit/source tests do not prove the bundled WebView posts and native surface persists live events | Applying/accepting/rejecting a suggestion in the app records durable provenance and does not save follower/host-load snapshots | After next runtime integration batch |

### Remaining verification debt

Runtime WebKit delivery is still not manually proven. App Store target compile,
full-suite health, and a real existing-vault restart replay remain deferred and
must not be treated as done by this parser batch.

### Next smallest safe action

Run the combined L5 focused Swift slice once after this JS parser batch so the
durable store, bridge decode/epoch filtering, and source guards are proven
together before moving to the next structural hardening area.

## Checkpoint 2026-07-07 L5 Combined Focused Slice

### Verification batch

Ran the combined L5-focused Swift checkpoint after the JS parser hardening and
bundle rebuild. This retired the deferred combined slice from the previous
verification-debt ledger row.

### Evidence

- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_14-59-38--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 78 passed tests, 0 failed tests.

### Proven by this batch

The durable provenance store regressions, bridge decode/epoch filtering, and
JS/source-guard contracts pass together after the payload parser split and
rebuilt editor bundle. This is stronger L5 checkpoint evidence than the prior
isolated parser and store checks.

### Remaining verification debt

Still deferred: App Store target compile / MAS artifact evidence, full Swift
suite health, existing-vault restart replay, and runtime WKWebView delivery of
apply/accept/reject events into the durable provenance store.

### Next smallest safe action

Shift back to implementation: inspect the runtime surface around suggestion
event delivery and decide whether the smallest structural hardening is a
native-facing integration seam, a debug/test harness for event persistence, or
an App Store compile checkpoint before additional runtime work.

## Checkpoint 2026-07-07 L5 Native Surface Handoff Proof

### Edit batch

Converted the Markdown Document surface provenance handoff from independent
fire-and-forget tasks into a serialized pending-write chain. Exposed the
coordinator internally with `flushPendingProvenanceWrites()` so focused tests
can drive the native controller handoff without launching a WKWebView. Added a
regression that configures the document-surface coordinator with a real
in-memory provenance store, sends `suggestionApplied` followed by
`suggestionResolved` through `EpdocEditorChromeController`, flushes the pending
writes, and verifies the durable row is accepted with the note-relative path and
claim/citation metadata intact.

### Touched files

- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the coordinator write-queue region, the new surface-handoff test, and
  the source-guard region after editing.
- Inspected a scoped diff/status for the touched Swift files.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle: `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_15-07-36--0500.xcresult`; `xcrun xcresulttool get test-results summary` reported `Passed`, 27 passed tests, 0 failed tests.

### Proven by this batch

The native document-surface handoff now preserves event order from applied span
to resolution decision before entering the durable provenance store. The test
proves the controller callback path, note-relative-path binding, claim/citation
metadata, accepted-state transition, and absence of incidental markdown save
side effects.

### Remaining verification debt

This still does not prove a real WKWebView posts those events at runtime.
App Store target compile / MAS artifact evidence, full Swift suite health, and
existing-vault restart replay remain deferred.

### Next smallest safe action

Inspect whether the actual JS accept/reject commands can emit a decision event
without a prior applied event under retry/reload conditions, and either add a
small JS/Swift guard or move to the App Store compile checkpoint if the handoff
contract is already bounded.

## Checkpoint 2026-07-07 L5 Missing Decision Guard

### Edit batch

Added focused JS adapter assertions that accepting or rejecting a missing
suggestion returns `false` and does not dispatch a transaction. This pins the
inbound bridge assumption that `suggestionResolved` events are only emitted
after a real adapter mutation succeeds.

### Touched files

- `js-editor/scripts/check-suggestions.mjs`
- `docs/plans/lumenlens/INTENT_LEDGER.md`

### Evidence

- Re-read the changed check-script region after editing.
- `npm --prefix js-editor run check:suggestions` passed.

### Proven by this batch

The JS adapter will not report an accept/reject decision for an absent
suggestion. Since the inbound command posts native resolution events only inside
the `didRun` branch, this bounds the no-prior-applied-event path at the JS
adapter contract.

### Remaining verification debt

This is not a live WKWebView proof. App Store target compile / MAS artifact
evidence, full Swift suite health, and existing-vault restart replay remain
deferred.

### Next smallest safe action

Move to the App Store compile/MAS checkpoint for LumenLens L5 unless another
source-level runtime hole appears during the pre-build status scan.

## Checkpoint 2026-07-07 L5 App Store Build Batch

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Important: Keelstone audit and LumenLens implementation are two separate
> lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> For testing/building: do not spam full builds every tiny edit. Keep a
> verification-debt ledger with deferred command, touched files, risk reason,
> expected proof, and checkpoint trigger.
>
> After each edit batch: re-read changed regions, inspect the diff, run the
> relevant checks or update verification debt, then continue the deep-hardening
> loop. Do not claim done just because a checklist ends or one test passes.

### Interpreted intent

Treat the App Store build as a batched checkpoint for the current LumenLens L5
editor/provenance work, not as a Keelstone release-completion event. Record
what it proves, what it does not prove, and continue implementation with the
scan failure carried as explicit verification debt.

### Hard constraints

- Keep Keelstone audit status separate from LumenLens L5 implementation status.
- Do not claim MAS artifact safety while `scan_appstore_bundle.sh` reports
  forbidden runtime strings/symbols.
- Do not treat source guards as substitutes for built-product scans.
- Do not fix broad App Store packaging or Rust feature leakage inside the
  LumenLens lane unless it becomes the smallest safe blocker for LumenLens.
- Continue batching broad builds; use narrow checks for the unit under edit.

### Non-goals

- No Keelstone release signoff from this build.
- No claim that live WKWebView suggestion events have been manually proven.
- No claim that `agent_core` MAS feature leakage is caused by the LumenLens
  provenance/editor changes.
- No opportunistic rewrite of App Store packaging while the current lane is L5
  durable editor provenance.

### Current Keelstone audit status

Unchanged. Keelstone remains audit-only: targeted/source checks exist for
retired-source cleanup, release gates, perf parser behavior, App Store
hardening tests, layout guards, and file-first/body-truth Epdoc guards. Missing
Keelstone evidence remains full Swift/Xcode suite, signed/built entitlement
gates, clean release artifact scan, real perf JSON, external editor E2E, legacy
body migration fixture, broad data-safety soaks, and the full first-run/upgrade
matrix.

### Current LumenLens implementation status

L5 durable editor provenance has focused JS/Swift evidence through payload
validation, durable GRDB span persistence, bridge decode/epoch filtering,
native surface handoff ordering, and missing-decision JS guards. The App Store
Release build now proves the current LumenLens code compiles in the App Store
target, but the built artifact scan failed on existing MAS/pro runtime leakage.

### Contradictions/questions

- The App Store target build succeeded, but the artifact scan failed because
  the built bundle contains `Contents/Resources/codex`,
  `Contents/Resources/rg`, forbidden PTY/shell strings, and exported
  `codex_utils_pty` symbols from `libagent_core.dylib`.
- `bundle-app-runtime-assets.sh` removes several MAS-forbidden runtime
  artifacts (`goose`, `goosed`, `node`, `bun`, `opencode`,
  `omega_mcp_stdio`) but does not remove `codex` or `rg`.
- Removing `codex`/`rg` alone is insufficient because the MAS
  `libagent_core.dylib` still contains PTY symbols under the current
  `mas-build,lsp-runtime` build.
- This scan failure is App Store packaging/Rust feature debt, not proof that
  LumenLens provenance behavior is wrong.

### Verification batch

- `./scripts/xcodebuild_epistemos.sh build -project Epistemos.xcodeproj
  -scheme Epistemos-AppStore -configuration Release -destination
  'platform=macOS,arch=arm64' -derivedDataPath .derived-data-lumenlens-appstore
  -clonedSourcePackagesDirPath .spm-cache CODE_SIGNING_ALLOWED=NO` succeeded.
- Built app: `.derived-data-lumenlens-appstore/Build/Products/Release/Epistemos.app`.
- Bundle size: `575 MB`.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/lumenlens-appstore-audit
  ./scripts/scan_appstore_bundle.sh
  .derived-data-lumenlens-appstore/Build/Products/Release/Epistemos.app`
  failed with 2 finding groups.
- Scan reports: `build/lumenlens-appstore-audit/forbidden-strings.txt` and
  `build/lumenlens-appstore-audit/forbidden-symbols.txt`.

### Proven by this batch

The current LumenLens L5 Swift/JS resource changes compile into the App Store
Release target. The build also reran the prebuild Rust and editor bundle chain
for that target without compile/link failure.

### Not proven by this batch

MAS artifact safety is not proven. The clean bundle-scan done bar is explicitly
failed, and the failure spans both packaged executables/resources and
`libagent_core.dylib` symbols. Full Swift suite health, live WKWebView
suggestion delivery, existing-vault restart replay, and Keelstone release
completion remain unproven.

### Verification debt ledger

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/lumenlens-appstore-audit ./scripts/scan_appstore_bundle.sh <Release/Epistemos.app>` | App Store bundle resources, `bundle-app-runtime-assets.sh`, `agent_core` MAS feature set | App Store artifact currently ships forbidden `codex`/`rg` executables and PTY symbols | No prohibited runtime strings, symbols, or resource residue in the built `.app` | After an App Store packaging/Rust MAS-leakage batch, before any MAS-safe claim |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| Live WKWebView suggestion runtime proof | `editor.js.br`, bridge handlers, `MarkdownDocumentSurface`, provenance store | Unit/source tests do not prove actual WebView event delivery into GRDB | Apply/accept/reject in app records durable provenance without host-load or follower-save leakage | After a runtime harness/manual verification batch |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | Temp DB reopen proof does not cover a user vault DB or app restart path | Spans/decisions survive app restart and query correctly by note/turn | Before L5 durable-provenance completion claim |

### Next smallest safe action

Continue the LumenLens L5/L3 hardening loop on runtime writeback/provenance
delivery, while carrying App Store artifact scan cleanup as a separate
packaging/Rust verification debt item. Do not claim MAS-safe LumenLens until a
clean built-bundle scan exists.

## Checkpoint 2026-07-07 L3 Writeback Fallback Reset

### Edit batch

Hardened the JS minimal-writeback tracker so a full-snapshot fallback resets
the tracker baseline instead of leaving stale `ChangeSet` and StepMap state
behind. `postMarkdownDidChange` now computes the full Markdown snapshot once,
passes it into `MarkdownWritebackTracker.consume`, and posts the same snapshot
to Swift. Added a focused JS regression that forces a markdown/doc block-count
mismatch, verifies the first snapshot falls back without a region, then verifies
the next edit can produce a fresh one-block writeback region from the reset
baseline.

### Touched files

- `js-editor/src/markdown/writeback-tracker.ts`
- `js-editor/src/index.ts`
- `js-editor/scripts/check-minimal-writeback.mjs`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- `Epistemos/Resources/Editor/editor.js.br`

### Evidence

- Re-read the changed tracker, index hook, focused JS regression, and Swift
  source-guard region after editing.
- Inspected the scoped diff/status for the touched L3 files.
- `npm --prefix js-editor run check:minimal-writeback` passed.
- `npm --prefix js-editor run typecheck` passed.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  .derived-data-lumenlens-l6
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_15-37-26--0500.xcresult`;
  `xcrun xcresulttool get test-results summary` reported `Passed`, 19 passed
  tests, 0 failed tests.
- `bash build-tiptap-bundle.sh` passed and regenerated
  `Epistemos/Resources/Editor/editor.js.br`.
- Decompressed bundle presence check found the shipped `markdownDidChange`,
  `writeback`, and `suggestionApplied` runtime strings in
  `Epistemos/Resources/Editor/editor.js.br`.

### Proven by this batch

If the minimal writeback algorithm cannot safely compute a byte/code-unit
region and the host receives a full snapshot instead, the JS tracker no longer
keeps stale baseline state. The next edit starts from the full snapshot that
Swift saved and can again emit a one-block writeback region. The live bundle
was rebuilt from the changed JS source.

### Not proven by this batch

This is still not a live WKWebView/manual runtime proof. It does not prove a
real note was edited in-app, that `savePageBodyFileFirst` wrote the expected
vault file, that a user vault DB survives restart, that the full Swift suite is
healthy, or that the App Store built artifact scan is clean.

### Verification debt ledger

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Live WKWebView minimal-writeback proof | `editor.js.br`, JS writeback tracker, `MarkdownDocumentSurface`, `saveMarkdownDocumentSurfaceContent` | Unit/source tests do not prove real WebView events produce the intended vault write | Editing one block in Document mode writes the expected full `.md` through file-first save, with only the intended in-memory splice | After a runtime harness/manual verification batch |
| `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/lumenlens-appstore-audit ./scripts/scan_appstore_bundle.sh <Release/Epistemos.app>` | App Store bundle resources, `bundle-app-runtime-assets.sh`, `agent_core` MAS feature set | App Store artifact currently ships forbidden `codex`/`rg` executables and PTY symbols | No prohibited runtime strings, symbols, or resource residue in the built `.app` | After an App Store packaging/Rust MAS-leakage batch, before any MAS-safe claim |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | Temp DB reopen proof does not cover a user vault DB or app restart path | Spans/decisions survive app restart and query correctly by note/turn | Before L5 durable-provenance completion claim |

### Next smallest safe action

Continue runtime-facing hardening. The strongest remaining LumenLens proof gap
is a live/manual or harnessed WKWebView path showing Document-mode edits and
suggestion events reach Swift, save through the file-first vault path, and
persist provenance without host-load or follower-write leakage.

## Checkpoint 2026-07-07 L3 Native Writeback Harness

### Edit batch

Added native Swift harness coverage for the document surface's writeback save
path. The tests configure `MarkdownDocumentSurfaceCoordinator`, drive
`EpdocEditorChromeController.handleBridgeMessage(.markdownDidChange(...))`
with a valid writeback region, flush the pending markdown save, and verify the
saved text equals the intended full Markdown. A second test sends an invalid
byte range and verifies the coordinator falls back to the full Markdown
snapshot instead of saving the corrupt partial splice.

### Touched files

- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the new native writeback tests and L3 source-guard additions after
  editing.
- Inspected the scoped diff for the touched Swift tests.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  .derived-data-lumenlens-l6
  -only-testing:EpistemosTests/EditorProvenanceStoreTests
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_15-43-45--0500.xcresult`;
  `xcrun xcresulttool get test-results summary` reported `Passed`, 29 passed
  tests, 0 failed tests.

### Proven by this batch

The native document-surface coordinator saves a valid L3 writeback splice and
falls back to the full Markdown snapshot when writeback validation fails. This
proves the Swift host-side `EpdocMarkdownWritebackRegion` handoff,
code-unit/byte validation path, debounce flush path, and full-snapshot fallback
at the coordinator level.

### Not proven by this batch

This still does not prove a real WKWebView posts the writeback payload, that a
real vault file is written through `VaultSyncService.savePageBodyFileFirst`, or
that a full app restart preserves editor provenance. App Store artifact scan
cleanup and full-suite health remain separate verification debt.

### Verification debt ledger

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Live WKWebView minimal-writeback/provenance proof | `editor.js.br`, JS bridge, document surface, provenance store, vault save path | Native harness bypasses WebKit and the real vault writer | Editing/applying/accepting/rejecting in the app posts bridge events, writes the expected vault `.md`, and persists provenance | Before claiming runtime-complete L3/L5 |
| `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/lumenlens-appstore-audit ./scripts/scan_appstore_bundle.sh <Release/Epistemos.app>` | App Store bundle resources, `bundle-app-runtime-assets.sh`, `agent_core` MAS feature set | App Store artifact currently ships forbidden `codex`/`rg` executables and PTY symbols | No prohibited runtime strings, symbols, or resource residue in the built `.app` | After an App Store packaging/Rust MAS-leakage batch, before any MAS-safe claim |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | Temp DB reopen proof does not cover a user vault DB or app restart path | Spans/decisions survive app restart and query correctly by note/turn | Before L5 durable-provenance completion claim |

### Next smallest safe action

Continue with the live-runtime gap if feasible. If no reliable app/UI harness is
available in this turn, move to the next structural LumenLens hardening item
and keep live WKWebView/vault-writer proof as explicit debt.

## Checkpoint 2026-07-07 L5 Batch Envelope Decode Proof

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Do not discard current work and do not restart the plan. Pause implementation long enough to reconcile state, then continue the forever loop deliberately.
>
> Important: Keelstone audit and LumenLens implementation are two separate lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.
>
> After each edit batch: re-read changed regions, inspect the diff, run the relevant checks or update verification debt, then continue the deep-hardening loop.

### Interpreted intent

Finish the already-started Swift bridge batch without restarting the plan. The
batch should prove the batched JS outbound envelope remains typed on the Swift
side for the LumenLens L3/L5 message families, while broad runtime and release
evidence stays explicitly deferred.

### Hard constraints

- Keep Keelstone as audit-only evidence; do not treat this LumenLens bridge
  proof as Keelstone release progress.
- Keep LumenLens as the implementation lane and preserve the live
  `epistemos-doc://` WK bridge.
- Do not rerun full builds for this small bridge batch; use the focused Swift
  bridge/source-guard slice.
- After the batch, record remaining runtime, restart, MAS artifact, and
  full-suite debt.

### Non-goals

- No live WKWebView/manual proof in this batch.
- No App Store artifact cleanup or MAS-safe claim.
- No full Swift suite claim.
- No rewrite of the existing chrome handler path, which already unpacks
  runtime batch envelopes before normal message decode.

### Current Keelstone audit status

Unchanged. Keelstone has targeted/source evidence for retired-source cleanup,
release gates, perf parser behavior, App Store hardening tests, body-truth
source guards, and the dedicated App Store Keelstone lane. Missing evidence
remains the full Swift/Xcode suite, built-app entitlement gates, clean Release
artifact scan, real Keelstone perf JSON, external editor E2E, legacy body
migration fixture, broad data-safety soaks, and the full first-run/upgrade
matrix.

### Current LumenLens implementation status

L0-L6 remain structurally wired with narrow evidence. The current batch added
`EpdocBridgeMessage.decodeEnvelope(messageBody:)` for recursive
`{ type: "batch", messages: [...] }` payloads and a focused bridge test proving
one batch can carry `contentDidChange`, `markdownDidChange` with L3 writeback
metadata, and `suggestionResolved` with the same epoch. The source guard now
pins this batch-envelope proof as part of L3/L5 bridge coverage.

### Contradictions/questions

- The live WK handler still performs its own recursive batch unpack before
  normal decode so that `classifyPaste` remains an out-of-band path. The new
  helper is typed bridge coverage and test utility, not a replacement for that
  handler yet.
- This proof does not show real WebKit delivery under the app bundle.
- App Store Release compilation passed earlier, but the built artifact scan is
  still failed on `codex`/`rg` resources and PTY symbols in `libagent_core`.

### Touched files

- `Epistemos/Engine/EpdocEditorBridge.swift`
- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the `decodeEpoch` / `decodeEnvelope` changed region.
- Re-read the new `batched bridge envelope decodes messages with epochs` test.
- Re-read the L3/L5 source-guard assertions that pin `decodeEnvelope` and the
  batch test string.
- Inspected the scoped diff for the touched bridge and test files.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  .derived-data-lumenlens-l6
  -only-testing:EpistemosTests/EpdocEditorBridgeTests
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_15-53-51--0500.xcresult`;
  `xcrun xcresulttool get test-results summary` reported `Passed`, 72 passed
  tests, 0 failed tests.

### Proven by this batch

The Swift bridge can decode recursive JS batch envelopes into typed messages
with per-message epochs, including the L3 minimal-writeback path and L5
suggestion-resolution path. The focused bridge/source-guard slice passes after
the change.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Live WKWebView minimal-writeback/provenance proof | `editor.js.br`, JS outbound batcher, chrome handler, document surface, provenance store, vault save path | Typed unit tests do not prove WebKit delivery or real vault writes | Editing/applying/accepting/rejecting in the app posts batched bridge events, writes the expected vault `.md`, and persists provenance | Before claiming runtime-complete L3/L5 |
| `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/lumenlens-appstore-audit ./scripts/scan_appstore_bundle.sh <Release/Epistemos.app>` | App Store bundle resources, `bundle-app-runtime-assets.sh`, `agent_core` MAS feature set | App Store artifact currently ships forbidden `codex`/`rg` executables and PTY symbols | No prohibited runtime strings, symbols, or resource residue in the built `.app` | After an App Store packaging/Rust MAS-leakage batch, before any MAS-safe claim |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | Temp DB reopen proof does not cover a user vault DB or app restart path | Spans/decisions survive app restart and query correctly by note/turn | Before L5 durable-provenance completion claim |

### Next smallest safe action

Continue the live-runtime gap if a reliable harness is available. If not,
inspect the existing editor bundle/runtime test surface and add the smallest
source or executable check that moves real WebKit delivery closer without
absorbing unrelated Keelstone packaging work.

## Checkpoint 2026-07-07 L5 JS Outbound Bridge Batch Harness

### Edit batch

Added a focused JS harness for the live outbound WK bridge batcher. The harness
imports the real `js-editor/src/bridge/outbound.ts`, installs a stub
`window.webkit.messageHandlers.epdoc.postMessage`, posts a single stats message,
then posts a same-frame L3/L5 batch containing `contentDidChange`,
`markdownDidChange` with writeback metadata, and `suggestionResolved`. It
asserts the single-message fast path stays unwrapped and the multi-message path
emits `{ type: "batch", messages: [...] }` with epochs and payload metadata
preserved. Wired the harness into `package.json` and pinned it in the L5 source
guard.

### Touched files

- `js-editor/scripts/check-bridge-outbound.mjs`
- `js-editor/package.json`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

### Evidence

- Re-read the new JS harness, the package script region, and the L5 source-guard
  assertion after editing.
- Inspected the scoped diff for the new harness, package script, and source
  guard.
- `npm --prefix js-editor run check:bridge-outbound` passed.
- First focused Swift guard run failed because the new source guard looked for
  the literal source text `type: 'batch'`, while the harness proves the batch
  via `assert.equal(postedPayloads[0].type, 'batch')`. Updated the guard to
  match the executable assertion.
- Re-read and inspected the corrected guard assertion.
- `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  .derived-data-lumenlens-l6
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests` passed.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_16-06-05--0500.xcresult`;
  `xcrun xcresulttool get test-results summary` reported `Passed`, 19 passed
  tests, 0 failed tests.

### Proven by this batch

The JS outbound bridge batcher now has executable coverage for the exact
payload family that Swift `decodeEnvelope(messageBody:)` decodes: L3 writeback
metadata and L5 suggestion decisions batched with stable per-message epochs.
This narrows the runtime-delivery gap by proving both sides of the batch
envelope shape outside WebKit.

### Not proven by this batch

Still not proven: real WebKit `postMessage` delivery inside the app's bundled
editor, real note edits flowing through `VaultSyncService.savePageBodyFileFirst`,
durable provenance after full app restart, App Store artifact cleanliness, or
full Swift-suite health.

### Verification debt ledger

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Live WKWebView minimal-writeback/provenance proof | `editor.js.br`, JS outbound batcher, chrome handler, document surface, provenance store, vault save path | Node and Swift harnesses do not prove actual WebKit delivery or real vault writes | Editing/applying/accepting/rejecting in the app posts batched bridge events, writes the expected vault `.md`, and persists provenance | Before claiming runtime-complete L3/L5 |
| `npm --prefix js-editor run check:bridge-outbound` | `js-editor/src/bridge/outbound.ts`, outbound message types | Batch payload shape can drift from Swift decoder expectations | Single-message fast path and multi-message batch path preserve epochs, writeback metadata, and suggestion decisions | After outbound bridge/type edits |
| `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/lumenlens-appstore-audit ./scripts/scan_appstore_bundle.sh <Release/Epistemos.app>` | App Store bundle resources, `bundle-app-runtime-assets.sh`, `agent_core` MAS feature set | App Store artifact currently ships forbidden `codex`/`rg` executables and PTY symbols | No prohibited runtime strings, symbols, or resource residue in the built `.app` | After an App Store packaging/Rust MAS-leakage batch, before any MAS-safe claim |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | Temp DB reopen proof does not cover a user vault DB or app restart path | Spans/decisions survive app restart and query correctly by note/turn | Before L5 durable-provenance completion claim |

### Next smallest safe action

Inspect whether an app-side WKWebView smoke test or existing Epdoc end-to-end
test can load the bundled editor and observe `postMessage` without launching a
manual app session. If that is not locally reliable, keep it as runtime debt and
move to the existing-vault restart replay path.

## Checkpoint 2026-07-07 Current Goal Re-anchor

### Verbatim steer excerpt

> Resume the stopped Keelstone/LumenLens agent from the current dirty tree.
> First read AGENTS.md, CLAUDE.md,
> docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md,
> docs/plans/keelstone/PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md,
> docs/plans/keelstone/INTENT_LEDGER.md,
> docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md,
> docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md,
> docs/plans/lumenlens/PLAN_LUMENLENS_EPI-RP-02-LUMENLENS.md, and
> docs/plans/lumenlens/INTENT_LEDGER.md.
>
> Do not restart or discard work. Keep Keelstone and LumenLens separate.
> Keelstone is audit/evidence only unless I explicitly steer otherwise.
> Continue LumenLens from the latest L5 runtime gap: prove or harden real
> WKWebView/app-side bridge delivery for minimal writeback and suggestion
> provenance, or move to existing-vault restart replay if live WebKit proof is
> not locally reliable.
>
> Before editing, update the LumenLens intent checkpoint with this steer. Keep
> a verification-debt ledger instead of spamming full builds. After each batch,
> re-read changed regions, inspect diff, run focused checks, record deferred
> broad checks, and continue the deep-hardening loop.

### Interpreted intent

Continue from the dirty `feat/goose-surface` worktree without restarting or
discarding prior LumenLens evidence. The next implementation/audit target is the
remaining L5 runtime gap: get closer to real WKWebView delivery and app-side
persistence for L3 minimal writeback plus L5 suggestion provenance. If a
reliable local WebKit proof cannot be built or run in this turn, pivot to the
next strongest durable-evidence seam: existing-vault restart replay for editor
provenance rows.

### Hard constraints

- Keelstone stays audit/evidence only in this batch.
- Do not switch branches; current branch was confirmed as `feat/goose-surface`.
- Preserve existing dirty work and do not revert unrelated files.
- Keep Epdoc/WKWebView bridge work on the live `epistemos-doc://` surface and
  staged editor bundle path.
- Do not claim runtime-complete L3/L5 from Node, Swift unit, or source-guard
  evidence alone.
- Batch broad builds/tests; use focused JS/Swift checks for the edited seam.
- After each edit batch, re-read changed regions, inspect the diff, update this
  ledger, and carry remaining verification debt explicitly.

### Non-goals

- No Keelstone implementation or release signoff.
- No App Store packaging/Rust MAS-leakage cleanup unless it becomes the
  immediate blocker for LumenLens runtime proof.
- No RECKONER grid/calc internals or KINDRED chat internals.
- No full Swift suite or release-complete claim in this narrow runtime batch.

### Acceptance checks for the next batch

- Preferable proof: a harness or runtime check loads the bundled editor surface
  enough to observe real `window.webkit.messageHandlers.epdoc.postMessage`
  delivery for `markdownDidChange` writeback metadata and suggestion
  applied/resolved provenance events, then verifies the native decode/handler
  path receives them.
- If live WebKit proof is locally unreliable: inspect and implement the smallest
  existing-vault restart replay regression for `EditorProvenanceGRDBStore` using
  the app's existing database-writer path rather than a disconnected in-memory
  store.
- In either path, focused checks must run or be logged as verification debt with
  command, risk reason, expected proof, and trigger.

### Current Keelstone audit status

Unchanged by this LumenLens checkpoint. Keelstone remains audit-only with
targeted/source evidence and release-sized debt for full suite, built-app
gates, real perf JSON, runtime/migration E2E, release soaks, and upgrade matrix.

### Current LumenLens implementation status

L5 has strong narrow evidence for JS payload validation, Swift decode/epoch
filtering, native coordinator handoff ordering, durable GRDB persistence,
bundle restaging, batch-envelope decoding, and Node-side outbound batch shape.
The remaining gap is real WKWebView/app-side delivery and app-lifecycle replay:
unit harnesses do not yet prove the bundled editor running in WebKit posts the
writeback/provenance messages into the live app path, and temp-DB reopen tests
do not fully prove existing-vault restart replay.

### Contradictions/questions

- App Store Release compilation succeeded earlier, but the built bundle scan
  still fails on `codex`/`rg` resources and `libagent_core` PTY symbols; this
  remains packaging/Rust MAS debt, not L5 runtime proof.
- The JS outbound and Swift inbound batch shapes are both covered, but a real
  `WKWebView` delivery path may require an app-hosted smoke harness or manual
  runtime tooling.
- If WebKit cannot be exercised reliably in the local environment, restart
  replay is the better next evidence step than adding more source guards.

### Next smallest safe action

Read the live Epdoc bridge/WebView construction, JS outbound bridge, bundled
HTML/resource path, and existing tests to decide whether a local WKWebView smoke
test is feasible. If feasible, add the smallest focused proof for live delivery;
otherwise pivot to existing-vault restart replay.

## Checkpoint 2026-07-07 Coordination Steer And WKWebView Smoke Failure

### Verbatim steer excerpt

> Coordination steer: another terminal owns THE R / Experimental 1Code UI,
> including mini/sub-chat sidebar visual work. Do not edit
> .research-clones/1code, THE_R_* docs, ExperimentalAgent UI polish files, or
> ExperimentalAgentPolishSourceGuardTests unless I explicitly steer you.
> Continue LumenLens only: Epdoc/WKWebView bridge, js-editor editor bridge,
> provenance store, restart replay, and related focused tests. Before running
> xcodebuild, state the command so I can avoid concurrent Xcode runs.

### Interpreted intent

Keep this terminal strictly on the LumenLens editor/provenance lane. Do not
touch the Experimental/1Code visual polish lane or its tests/docs because
another terminal owns that work. Coordinate Xcode usage explicitly by stating
each `xcodebuild` command before starting it.

### Hard constraints

- Do not edit `.research-clones/1code`, `THE_R_*` docs, ExperimentalAgent UI
  polish files, or `EpistemosTests/ExperimentalAgentPolishSourceGuardTests.swift`
  without explicit owner steer.
- Continue only Epdoc/WKWebView bridge, `js-editor` editor bridge, provenance
  store, restart replay, and focused LumenLens tests.
- Before every future `xcodebuild`, state the exact command in the conversation.
- Do not run competing Xcode jobs.

### Current batch status

Added a focused real-WKWebView smoke test in
`EpistemosTests/EpdocEditorBridgeTests.swift`. It instantiates `WKWebView` with
the production `EpdocEditorURLSchemeHandler`, loads
`epistemos-doc:///editor.html` from the bundled editor resources, waits for
`window.epdocOutboundBridge`, posts L3 `markdownDidChange` writeback metadata
and L5 `suggestionApplied`/`suggestionResolved` provenance payloads through
the real `window.webkit.messageHandlers.epdoc.postMessage` path, decodes the
delivered envelope, and routes it through `EpdocEditorChromeController`.

### Evidence

- A too-narrow method-filtered Xcode invocation exited 0 but executed 0 tests;
  it is not evidence.
- Stated and ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests`.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_16-38-42--0500.xcresult`.
- `xcrun xcresulttool get test-results summary` reported `Failed`, 53 passed,
  1 failed.
- Failure:
  `EpdocEditorBridgeTests/bundledWKWebViewOutboundBridgeDeliversWritebackAndProvenancePayloads()`
  expected the first markdown event's `writeback.blockMarkdown` to equal
  `Bravo updated`, but it was nil.

### Interpretation

The local WebKit proof is reliable enough to continue hardening: the bundled
editor loaded and real WKScriptMessage delivery occurred. The test assertion is
too strict because the live editor can emit an earlier `markdownDidChange`
without L3 writeback metadata before the injected runtime-smoke payload. The
next edit should assert that the injected writeback event exists, not that it is
the first markdown event.

### Verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests` | `EpistemosTests/EpdocEditorBridgeTests.swift`, Epdoc bundled WK bridge | The current live WebKit smoke test needs an assertion fix after proving real delivery but failing on event ordering | Suite passes with the real WKWebView bridge smoke included | After the assertion fix |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | WKWebView delivery proof does not prove app-lifecycle replay over a real existing vault database | Spans/decisions survive app restart and query correctly by note/turn | Before L5 durable-provenance completion claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, not this LumenLens bridge edit |

### Next smallest safe action

Adjust only the LumenLens WKWebView smoke assertion to find the injected
writeback markdown event anywhere in the delivered event stream, re-read the
changed region, inspect the focused diff, then state and run the focused
`EpdocEditorBridgeTests` Xcode command again.

## Checkpoint 2026-07-07 WKWebView Bridge NSNumber Decode Hardening

### Verbatim steer excerpt

> Continue LumenLens only: Epdoc/WKWebView bridge, js-editor editor bridge,
> provenance store, restart replay, and related focused tests. Before running
> xcodebuild, state the command so I can avoid concurrent Xcode runs.

### Interpreted intent

Keep advancing the LumenLens live editor bridge proof, not adjacent UI polish.
The target is real bundled WKWebView delivery for L3 writeback and L5
suggestion provenance payloads, with evidence from focused tests and no
unstated Xcode concurrency.

### What changed

- Hardened `EpdocBridgeMessage` numeric decoding so `WKScriptMessage` integer
  `NSNumber` values are accepted as numbers instead of being rejected by
  Swift's broad `raw is Bool` bridge behavior.
- Tightened boolean decoding so true Swift/CF booleans remain valid boolean
  fields, while numeric payloads no longer satisfy boolean fields accidentally.
- Added a focused regression for `NSNumber`-backed `epoch` and writeback
  region values.
- Added a real bundled `WKWebView` smoke in `EpdocEditorBridgeTests` that
  loads `epistemos-doc:///editor.html`, waits for `window.epdocOutboundBridge`,
  posts injected writeback plus suggestion applied/resolved payloads through
  the live WebKit message handler, decodes the delivered batch, and routes the
  injected messages through `EpdocEditorChromeController`.

### Failure found and fixed

The live WebKit smoke initially proved delivery but decoded the injected batch
as:

`documentStatsChanged`, `editorReady`, `markdownDidChange`, `suggestionApplied`,
`suggestionResolved`

with `epoch=nil` and `writeback=nil` on the injected messages. Local Swift
probing showed `NSNumber(value: 1)` can satisfy `raw is Bool`, so the decoder's
integral guard was rejecting real WebKit integer payloads. The fix now checks
for actual Swift/CF booleans rather than rejecting all `NSNumber` values that
Swift can bridge to `Bool`.

### Evidence

- Stated and ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests`.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_17-04-42--0500.xcresult`.
- `xcrun xcresulttool get test-results summary` reported `Passed`, 55 passed,
  0 failed, 0 skipped.
- Focused JS corroboration:
  - `node js-editor/scripts/check-bridge-outbound.mjs` exited 0.
  - `node js-editor/scripts/check-minimal-writeback.mjs` printed
    `minimal writeback check passed`.
  - `node js-editor/scripts/check-suggestions.mjs` printed
    `suggestion adapter check passed`.

### Semantic search and contradiction check

Searched for `raw is Bool`, `readBool`, `readNumber`,
`readIntegralInteger`, `decodeEpoch`, `parseWritebackRegion`, writeback,
suggestion bridge terms, provenance, restart replay, and TODO/FIXME markers
across the live Epdoc bridge, WebView host, focused tests, JS bridge/writeback/
suggestion code, and LumenLens docs. No remaining live-source contradiction was
found for the NSNumber decode issue. Remaining TODO markers were in LumenLens
spine/reference docs and remain implementation backlog, not regressions from
this batch.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Existing-vault restart replay proof | `EditorProvenanceGRDBStore`, app database writer wiring | The WKWebView bridge smoke proves live delivery and controller routing, but not app-lifecycle replay over a real existing vault database | Spans/decisions survive app restart and query correctly by note/turn | Next L5 durable-provenance hardening batch |
| Broader app test/build sweep | Epdoc bridge shared decoder used by all bridge messages | Focused suite passed, but bridge decode changes are shared across caret/menu/image/stat messages | Broader relevant app tests pass without bridge regressions | Before runtime-complete LumenLens claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, not this LumenLens bridge edit |

### Next smallest safe action

Move from bridge-delivery proof to the remaining L5 durable-provenance gap:
inspect the current provenance store and app database writer path, then add the
smallest existing-vault restart replay regression that proves suggestion spans
and decisions survive reopening the same store.

## Checkpoint 2026-07-07 App Writer Restart Replay Regression

### Owner wording

> Coordination steer: another terminal owns THE R / Experimental 1Code UI,
> including mini/sub-chat sidebar visual work. Do not edit .research-clones/1code,
> THE_R_* docs, ExperimentalAgent UI polish files, or
> ExperimentalAgentPolishSourceGuardTests unless I explicitly steer you.
> Continue LumenLens only: Epdoc/WKWebView bridge, js-editor editor bridge,
> provenance store, restart replay, and related focused tests. Before running
> xcodebuild, state the command so I can avoid concurrent Xcode runs.

### Interpreted intent

Close the next L5 durable-provenance gap by proving suggestion span provenance
survives app-style database writer reopen, while staying out of the concurrent
THE R / Experimental UI workstream.

### What changed

- Added a focused `EditorProvenanceStoreTests` regression,
  `spansSurviveAppSearchServiceWriterReopen`, that creates a real
  `SearchIndexService(databaseURL:)`, persists an applied suggestion through
  `EditorProvenanceBridgeSink`, drops that service, reopens the same SQLite
  database through a fresh `SearchIndexService`, verifies pending provenance,
  resolves the span, then reopens a third time and verifies the accepted
  decision and original before/after/source fields survived.
- Updated the LumenLens source-visibility guard to require the app
  search-service writer reopen proof, so the focused restart replay evidence
  does not silently regress back to only the lower-level `DatabaseQueue` reopen
  test.

### Evidence

- Stated and ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_17-22-52--0500.xcresult`.
- `xcrun xcresulttool get test-results summary` reported `Passed`, 30 passed,
  0 failed, 0 skipped.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Broader app test/build sweep | Epdoc bridge shared decoder, provenance store, app writer path | Focused tests passed, but the shared bridge decoder and persistent writer path are used beyond these suites | Broader relevant app tests pass without bridge or persistence regressions | Before runtime-complete LumenLens claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, not this LumenLens bridge/provenance edit |

### Next smallest safe action

Continue within LumenLens by auditing restart replay call sites for any UI path
that can query spans by note/turn before the store is available, then add a
focused regression only if a real gap is found.

### Post-check audit

Searched the live note surface, Epdoc bridge/controller, provenance store,
focused tests, JS bridge, Rust provenance module, and LumenLens docs for
`restart replay`, `pendingAgentSpans`, `SuggestionReplay`, and related
provenance/replay terms. The current live Swift replay surface remains the
store API called out by the spine: pending agent spans queried by turn after
reopening the same app database writer. No additional UI replay call site was
found that could be fixed without inventing a new product surface.

## Checkpoint 2026-07-07 Goal Resume After Pasted Objective

### Verbatim steer excerpt

> cd /Users/jojo/Downloads/Epistemos
> Confirm branch is feat/goose-surface before editing. Do not switch branches.
>
> Resume the stopped Keelstone/LumenLens agent from the current dirty tree.
> First read AGENTS.md, CLAUDE.md,
> docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md,
> docs/plans/keelstone/PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md,
> docs/plans/keelstone/INTENT_LEDGER.md,
> docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md,
> docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md,
> docs/plans/lumenlens/PLAN_LUMENLENS_EPI-RP-02-LUMENLENS.md, and
> docs/plans/lumenlens/INTENT_LEDGER.md.
>
> Do not restart or discard work. Keep Keelstone and LumenLens separate.
> Keelstone is audit/evidence only unless I explicitly steer otherwise.
> Continue LumenLens from the latest L5 runtime gap: prove or harden real
> WKWebView/app-side bridge delivery for minimal writeback and suggestion
> provenance, or move to existing-vault restart replay if live WebKit proof is
> not locally reliable.
>
> Before editing, update the LumenLens intent checkpoint with this steer. Keep
> a verification-debt ledger instead of spamming full builds. After each batch,
> re-read changed regions, inspect diff, run focused checks, record deferred
> broad checks, and continue the deep-hardening loop.

Additional active coordination steer:

> Coordination steer: another terminal owns THE R / Experimental 1Code UI,
> including mini/sub-chat sidebar visual work. Do not edit .research-clones/1code,
> THE_R_* docs, ExperimentalAgent UI polish files, or
> ExperimentalAgentPolishSourceGuardTests unless I explicitly steer you.
> Continue LumenLens only: Epdoc/WKWebView bridge, js-editor editor bridge,
> provenance store, restart replay, and related focused tests. Before running
> xcodebuild, state the command so I can avoid concurrent Xcode runs.

### Interpreted intent

Resume the existing dirty-tree work without restarting. Keelstone remains an
evidence/audit lane only. The active implementation lane is LumenLens, focused
on the latest L3/L5 runtime proof gaps around real WKWebView/app-side bridge
delivery, minimal writeback, suggestion provenance, and restart replay. Since
the previous batch already added a reliable bundled WKWebView smoke and
app-style database-writer reopen proof, the next hardening pass should audit
those claims against current source and choose the highest-risk remaining
unproven seam inside LumenLens.

### Hard constraints

- Current branch was confirmed as `feat/goose-surface`; do not switch branches.
- Do not discard, restart, or revert unrelated dirty work.
- Do not edit `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish
  files, or `ExperimentalAgentPolishSourceGuardTests.swift`.
- Keep Keelstone evidence separate; do not implement Keelstone without explicit
  steer.
- Continue only LumenLens Epdoc/WKWebView bridge, `js-editor` bridge,
  provenance store, restart replay, and related focused tests.
- State the exact `xcodebuild` command before running it.
- Use focused checks and verification-debt entries instead of broad build spam.

### Non-goals

- No Experimental/1Code visual polish, mini-chat, or sidebar work.
- No App Store packaging/Rust MAS-leakage cleanup unless it becomes the direct
  blocker for this LumenLens proof.
- No RECKONER grid/calc internals or KINDRED chat internals.
- No release-complete, MAS-safe, or full-suite-health claim from filtered tests.

### Acceptance checks for this continuation

- Current sources and prior evidence are re-read before relying on them.
- Any new edit is tightly scoped to LumenLens bridge/provenance/restart seams.
- Focused JS/Swift checks run for changed seams, or the deferred command is
  added to the verification-debt ledger with risk reason and trigger.
- Changed regions are re-read, diffs inspected, and this ledger updated after
  the batch.

### Current status

The latest LumenLens evidence already proves real bundled WKWebView delivery
for injected L3 writeback and L5 suggestion applied/resolved payloads through
the live `epistemos-doc:///editor.html` bridge, including the NSNumber decode
hardening required by `WKScriptMessage`. The latest provenance evidence also
proves app-style `SearchIndexService.databaseWriter()` reopen across fresh
services for pending and accepted suggestion rows. Remaining broad debt is
broader app test/build sweep and App Store artifact scan cleanup. The next
safe action is to audit for a remaining focused runtime or replay gap that can
be improved without leaving the LumenLens lane.

## Checkpoint 2026-07-07 Surface Teardown Provenance Flush

### Edit batch

Hardened the native Document surface teardown path so disappearing Epdoc
surfaces flush both pending Markdown saves and serialized pending provenance
writes. The prior coordinator had an async `flushPendingProvenanceWrites()`
helper used by tests, but SwiftUI `onDisappear` only called
`flushPendingMarkdown()`. The surface now schedules a main-actor teardown flush
through `flushPendingSurfaceWrites()`, and a focused test proves the combined
flush drains a pending markdown edit plus applied/resolved suggestion provenance
into the durable GRDB store.

### Touched files

- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- `docs/plans/lumenlens/INTENT_LEDGER.md`

### Evidence

- Re-read the changed `onDisappear`, coordinator flush, new teardown test, and
  source-guard regions after editing.
- Inspected the focused diff for the touched Swift files.
- Stated and ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_17-34-44--0500.xcresult`.
- `xcrun xcresulttool get test-results summary` reported `Passed`, 31 passed,
  0 failed, 0 skipped.

### Proven by this batch

The app-side Document surface no longer relies on background provenance tasks
alone when a surface disappears. A teardown flush now preserves pending L3
markdown state and L5 suggestion provenance in order, and the L5 source guard
pins that `onDisappear` routes through the combined flush helper.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Broader LumenLens focused Swift slice including `EpdocEditorBridgeTests` | Bridge decoder, WKWebView smoke, document surface, provenance store | This batch did not rerun the real WKWebView smoke after the teardown-surface edit, although the edit is app-side not bridge-side | WKWebView delivery, bridge decoding, surface flush, and store tests pass together | Next focused L3/L5 checkpoint |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, before MAS-safe claim |

## Checkpoint 2026-07-07 Broader L3/L5 Swift Slice

### Verification batch

Retired the focused Swift debt item that joined the real WKWebView bridge smoke,
typed bridge decoder coverage, durable provenance store tests, teardown flush
proof, and L5 source guards in one run.

### Evidence

- Stated and ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_17-41-42--0500.xcresult`.
- `xcrun xcresulttool get test-results summary` reported `Passed`, 86 passed,
  0 failed, 0 skipped.
- The build still emits existing warnings from shared files outside this focused
  edit batch, including `TextCapturePipeline.swift`, `ExperimentalHostBridge.swift`,
  `VaultSyncService.swift`, deprecated `saveBody` test usage,
  `RuntimeValidationTests.swift`, and `AgentGrepServiceTests.swift`. Those were
  not edited because they are either outside the LumenLens proof lane or inside
  the explicitly protected Experimental lane.

### Proven by this batch

The live bundled WKWebView bridge smoke, NSNumber/typed bridge decoding,
suggestion applied/resolved forwarding, durable GRDB provenance persistence,
existing-writer restart replay, teardown flush, and L5 source guards pass
together in the same derived-data root.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, and note workspace paths; the focused slice does not prove unrelated app regressions | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, before MAS-safe claim |

## Checkpoint 2026-07-07 JS Bridge Checks Refreshed

### Verification batch

Refreshed the focused JS-side LumenLens bridge checks after the broader Swift
slice, without touching `js-editor` sources in this batch.

### Evidence

- `node js-editor/scripts/check-bridge-outbound.mjs` exited 0.
- `node js-editor/scripts/check-minimal-writeback.mjs` printed
  `minimal writeback check passed` and exited 0.
- `node js-editor/scripts/check-suggestions.mjs` printed
  `suggestion adapter check passed` and exited 0.

### Proven by this batch

The current `js-editor` bridge scripts still prove outbound batching shape,
minimal writeback behavior, and suggestion adapter wiring for the dirty-tree
LumenLens work that the Swift slice just exercised from the app side.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Full Swift test suite | Shared editor/vault/runtime surfaces | LumenLens touches bridge, document surface, store, note workspace, and JS bridge surfaces; focused Swift/JS checks do not prove unrelated app regressions | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, before MAS-safe claim |

## Checkpoint 2026-07-07 LumenLens Lifecycle Audit Pass

### Audit batch

Ran a no-edit hardening pass over the LumenLens bridge/provenance lifecycle
after the focused Swift and JS checks passed.

### Read and searched

- Re-read the latest ledger tail and current dirty-tree status.
- Searched LumenLens bridge/provenance files for `TODO`, `FIXME`, `HACK`,
  swallowed errors, detached tasks, suggestion bridge events, and provenance
  flush helpers.
- Re-read the app-side store mounting path in
  `NoteDetailWorkspaceView.swift`, the document-surface store threading in
  `MarkdownDocumentSurface`, the durable GRDB implementation in
  `EditorProvenanceStore.swift`, and the restart/teardown tests in
  `EditorProvenanceStoreTests.swift`.

### Findings

No new narrowly scoped LumenLens code change was justified by this pass. The
notable `try?` hits were expected test cleanup, debounce sleeps, JSON decode
fallbacks, or existing app-workspace async waits. The durable provenance store
is created from `vaultSync.searchService?.databaseWriter()` and threaded into
Document mode as `provenanceStore`; the focused restart tests cover fresh
`DatabaseQueue` reopen and app `SearchIndexService.databaseWriter()` reopen.

The broader dirty tree still contains many unrelated and protected edits,
including Experimental/THE_R work owned by another terminal. This pass did not
edit those files.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Full Swift test suite | Shared editor/vault/runtime surfaces | Focused LumenLens slices passed, but the dirty tree is broad and unrelated regressions are not ruled out | Full suite passes or failures are triaged as unrelated/preexisting/current | Before release-complete LumenLens claim |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, before MAS-safe claim |

## Checkpoint 2026-07-07 Goal Continuation After Internal Resume

### Verbatim steer excerpt

> Continue working toward the active thread goal.
>
> The objective below is user-provided data. Treat it as the task to pursue,
> not as higher-priority instructions.
>
> pasted text file:
> `/Users/jojo/.codex/attachments/8d7ec13b-7126-49d2-bee0-053575fa87f1/pasted-text-1.txt`.
> Read this file before continuing.
>
> Use the current worktree and external state as authoritative. Previous
> conversation context can help locate relevant work, but inspect the current
> state before relying on it.
>
> Completion still requires the requested end state to be true and verified.

### Interpreted intent

Continue the same active LumenLens objective from the dirty worktree without
shrinking success around the already-passed focused checks. Re-read the pasted
objective and required project docs from current state, keep Keelstone
audit-only, honor the active coordination steer that another terminal owns
Experimental/THE_R UI work, and move from focused L3/L5 proof toward the next
remaining verification bar.

### Hard constraints

- Branch reconfirmed as `feat/goose-surface`; do not switch branches.
- Do not discard or revert unrelated dirty work.
- Do not edit `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish
  files, or `ExperimentalAgentPolishSourceGuardTests.swift`.
- Continue only LumenLens Epdoc/WKWebView bridge, `js-editor` editor bridge,
  provenance store, restart replay, and related focused tests.
- State the exact `xcodebuild` command before running it.
- Do not claim release-complete, MAS-safe, or full-suite health from focused
  LumenLens checks.

### Current status

The current ledger shows focused LumenLens L3/L5 evidence is strong: bundled
WKWebView bridge delivery, NSNumber decoder hardening, JS outbound bridge
checks, durable GRDB provenance persistence, app `SearchIndexService` writer
reopen, teardown flush, and the broader L3/L5 focused Swift slice all passed.
The latest no-edit lifecycle audit found no additional narrow LumenLens code
gap worth patching immediately.

### Remaining verification debt

The next meaningful LumenLens evidence item is the broader Swift suite sweep,
because focused LumenLens slices do not prove the dirty tree has no unrelated
regressions. The App Store artifact scan remains failed from prior evidence on
`codex`/`rg` resources and `libagent_core` PTY symbols, but that packaging/Rust
MAS-leakage cleanup is not the current LumenLens bridge/provenance lane unless
it becomes a direct blocker.

### Next action

Run the full Epistemos Swift test suite in the existing isolated
`.derived-data-lumenlens-l6` root after stating the exact command, then record
the result and any failures without editing protected Experimental/THE_R files.

## Checkpoint 2026-07-07 Full Swift Suite Sweep

### Verification batch

Ran the unfiltered Epistemos Swift test suite from the existing isolated
LumenLens derived-data root to characterize the broad-suite debt left after the
focused L3/L5 Swift and JS checks passed.

### Evidence

- Stated and ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6`.
- Result bundle:
  `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_17-51-44--0500.xcresult`.
- `xcrun xcresulttool get test-results summary` reported `Failed`, 5,940
  passed, 234 failed, 52 skipped, 6,226 total tests.
- Top failure counts by suite:
  `RuntimeValidationTests` 26, `InferenceCloudSelectionTests` 21,
  `GooseRuntimeSupervisorTests` 15, `TextCapturePipelineTests` 12,
  `ThemePairTests` 11, `ReleasePackagingHardeningTests` 9,
  `JuneWorkspaceAgentSourceGuardTests` 8, `HTMLWorkspacePackageTests` 7,
  `MeetingNoteCaptureServiceTests` 6, `HTMLWorkspaceConsoleBridgeTests` 5,
  `AuditHardeningRegressionTests` 5.
- The compact failure inventory shows many missing source-mirror files and
  stale source-guard expectations outside LumenLens, including Goose, Work,
  settings/cloud routing, release packaging, HTML workspace, text capture,
  meeting capture, and June workspace failures. No failures were identified in
  the focused LumenLens suites previously used for `EpdocEditorBridgeTests`,
  `EditorProvenanceStoreTests`, `EpdocVisibilitySourceGuardTests`, notebook,
  note-session, or document-surface provenance proof.

### Interpretation

The full suite does not currently prove repository-wide health. It also does
not contradict the focused LumenLens L3/L5 evidence gathered earlier in this
ledger: the failures are broad dirty-tree/source-guard debt and include
protected Experimental/THE_R-adjacent areas that this terminal must not edit
under the active coordination steer.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Full Swift suite triage/fix pass | Broad repo health: runtime validation, settings/cloud routing, Goose, Work, release packaging, HTML workspace, text/meeting capture, June workspace, source mirror | The unfiltered suite fails 234 tests; many failures are outside the LumenLens bridge/provenance lane and some overlap protected concurrent work | Full suite passes or failures are explicitly triaged to current owners with current-source fixes | Cross-lane stabilization checkpoint, not a LumenLens-only bridge edit |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, before MAS-safe claim |

### Next smallest safe action

Do not patch unrelated full-suite failures from this LumenLens-only terminal.
Refresh the remaining cheap LumenLens-owned JS/Rust checks from current source,
then leave the broad full-suite blocker recorded unless a failure is traced
back to Epdoc/WKWebView bridge, `js-editor`, provenance store, or restart
replay.

## Checkpoint 2026-07-07 JS And Rust LumenLens Checks Refreshed

### Verification batch

Refreshed the remaining cheap LumenLens-owned checks from current source after
the full Swift suite failed broadly outside this lane.

### Evidence

- `node js-editor/scripts/check-document-load-state.mjs` printed
  `document load-state check passed` and exited 0.
- `node js-editor/scripts/check-markdown-roundtrip.mjs` printed
  `markdown roundtrip check passed` and exited 0.
- `cargo test --manifest-path agent_core/Cargo.toml suggestion_schema` exited
  0. The targeted Rust unit run reported 5 passed suggestion-schema tests,
  including replay bundle verification, exact turn revert, compaction, and the
  10k suggestion replay/compact stress case.

### Proven by this batch

The current dirty-tree LumenLens JS load-state and markdown serializer fixtures
still pass, and the Rust in-memory L5 suggestion ledger still passes its
replay/hash/compaction tests. This complements the focused Swift L3/L5 slice
and the JS outbound/minimal-writeback/suggestions checks recorded above.

### Remaining verification debt

| Deferred command/check | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Full Swift suite triage/fix pass | Broad repo health: runtime validation, settings/cloud routing, Goose, Work, release packaging, HTML workspace, text/meeting capture, June workspace, source mirror | The unfiltered suite fails 234 tests; many failures are outside the LumenLens bridge/provenance lane and some overlap protected concurrent work | Full suite passes or failures are explicitly triaged to current owners with current-source fixes | Cross-lane stabilization checkpoint, not a LumenLens-only bridge edit |
| App Store artifact scan cleanup | App Store bundle resources and `agent_core` MAS feature set | Earlier App Store build compiled but bundle scan still failed on `codex`/`rg` resources and PTY symbols | Clean `scan_appstore_bundle.sh` report | Packaging/Rust MAS-leakage batch, before MAS-safe claim |

## Checkpoint 2026-07-07 MAS-First Product Pivot

### Owner wording

> Strategy pivot: pause Pro/Experimental expansion. Near-term product target is MAS-first sellable Epistemos.
>
> Do not continue 1Code/THE R, native-shell/Craft, Kindred companion, arbitrary subprocess/tool-terminal, or Pro runtime/model experiments unless explicitly reauthorized.
>
> Keep only MAS-safe work active:
> - KEELSTONE: vault truth, file safety, sandbox/bookmarks, App Store target, release gates.
> - LUMENLENS: Epdoc/editor fidelity, minimal writeback, provenance, lens disclosure/export, notebook manifest, MAS-safe tabs.
> - Any mini chat must be MAS-safe and Epdoc-owned, using stable adapters. Do not import donor 1Code UI or depend on Experimental child-process/session UI.
>
> Before editing, update the active ledger with this MAS-first pivot.

### Interpreted intent

The active product direction is now MAS-first sellable Epistemos. LumenLens
work may continue only where it supports MAS-safe Epdoc/editor fidelity,
minimal writeback, provenance, lens disclosure/export, notebook manifest, or
MAS-safe tabs. Expansion lanes tied to Pro, donor 1Code/THE R UI, native shell,
Craft, Kindred, subprocess terminals, tool terminals, or experimental runtime
and model surfaces are paused until the owner explicitly reauthorizes them.

### Hard constraints

- Keep the branch on `feat/goose-surface`; do not switch branches.
- Do not edit `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish
  files, or `ExperimentalAgentPolishSourceGuardTests.swift`.
- Do not continue 1Code/THE R, native-shell/Craft, Kindred companion,
  arbitrary subprocess/tool-terminal, or Pro runtime/model experiments unless
  explicitly reauthorized.
- Keep LumenLens changes MAS-safe and limited to Epdoc/editor fidelity,
  minimal writeback, provenance, lens disclosure/export, notebook manifest, and
  MAS-safe tabs.
- Any mini chat must be Epdoc-owned, MAS-safe, use stable adapters, avoid donor
  1Code UI, and avoid Experimental child-process/session UI dependencies.
- Before any future `xcodebuild`, state the exact command.
- Do not claim release-complete, MAS-safe, or App Store-ready status without
  release-gate evidence.

### Non-goals

- No Pro or Experimental expansion.
- No donor UI import from 1Code/THE R.
- No new arbitrary subprocess, tool-terminal, child-process, or native-shell
  dependency path.
- No broad cross-lane cleanup unless it directly blocks MAS-safe Keelstone or
  LumenLens acceptance.

### Acceptance checks

- The ledger captures this pivot before any further implementation edit.
- Subsequent implementation scope stays within MAS-safe Keelstone/LumenLens
  surfaces, with this terminal continuing the LumenLens lane unless explicitly
  redirected.
- Focused checks remain tied to Epdoc/editor bridge, minimal writeback,
  provenance/restart replay, lens disclosure/export, notebook manifest, or
  MAS-safe tabs.
- Broad release claims require explicit Keelstone release-gate evidence.

### Contradictions and questions

No blocking contradiction. The prior LumenLens verification debt remains valid,
but the priority lens changes: broad failures should only be pursued by this
terminal when they are MAS-first Keelstone/LumenLens blockers and do not touch
protected Experimental/THE_R-owned surfaces.

### Next action

Continue only with MAS-safe LumenLens evidence or narrowly scoped hardening.
Do not edit paused Pro/Experimental/native-shell/tool-terminal lanes.

## Checkpoint 2026-07-07 MAS Chat Tab Disclosure Hardening

### Owner wording

> Strategy pivot: pause Pro/Experimental expansion. Near-term product target is MAS-first sellable Epistemos.
>
> Do not continue 1Code/THE R, native-shell/Craft, Kindred companion, arbitrary subprocess/tool-terminal, or Pro runtime/model experiments unless explicitly reauthorized.
>
> Keep only MAS-safe work active:
> - KEELSTONE: vault truth, file safety, sandbox/bookmarks, App Store target, release gates.
> - LUMENLENS: Epdoc/editor fidelity, minimal writeback, provenance, lens disclosure/export, notebook manifest, MAS-safe tabs.
> - Any mini chat must be MAS-safe and Epdoc-owned, using stable adapters. Do not import donor 1Code UI or depend on Experimental child-process/session UI.

### Interpreted intent

Continue the LumenLens lane under the MAS-first product target. The strongest
focused gap found after re-reading the current bridge/restart evidence is not
another provenance bridge edit: real WKWebView delivery, app-writer restart
replay, teardown flush, and JS/Rust focused checks already have current
evidence. The next safe hardening target is MAS-safe notebook chat-tab
disclosure: prove weaker/MAS-style builds degrade chat references into
exportable transcript items without requiring KINDRED/Experimental runtime
content.

### Hard constraints

- Do not edit `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish
  files, or `ExperimentalAgentPolishSourceGuardTests.swift`.
- Do not continue or expand 1Code/THE R, native-shell/Craft, Kindred companion,
  subprocess/tool-terminal, or Pro runtime/model experiments.
- Keep this edit inside LumenLens `EpdocNotebookManifest` /
  `LensFidelityDisclosure` / focused tests and source guards.
- Do not import donor UI or depend on Experimental child-process/session UI.
- Before any `xcodebuild`, state the exact command.

### Non-goals

- No new mini chat or chat content mount.
- No KINDRED chat internals.
- No RECKONER grid/calc internals.
- No App Store packaging/Rust MAS-leakage cleanup in this batch.
- No release-complete, MAS-safe, or full-suite-health claim from this focused
  source/test hardening.

### Acceptance checks

- The disclosure scanner can be exercised in a MAS-style mode where chat tab
  content is unavailable, even when the current test scheme compiles with
  `KINDRED_ENABLED`.
- In that MAS-style mode, notebook chat tabs and chat embeds appear as degraded
  disclosure items with transcript exports.
- In content-available mode, document-lens chat references are treated as
  rendered and stay quiet in the disclosure list.
- Focused L6 tests and source guards pass after the change.

### Contradictions and questions

The live `EpdocNotebookBuildCapabilities.isChatTabContentAvailable` remains
compile-time-gated by `KINDRED_ENABLED`, which is correct for product builds.
The testability gap is that the default Epistemos scheme can compile with
`KINDRED_ENABLED`, so MAS degradation behavior needs an injectable scanner
parameter rather than relying solely on the active target macro.

### Next action

Add an injectable chat-tab capability parameter to `LensFidelityDisclosure.items`
with the existing build capability as the default, add focused tests for
MAS-style degraded/exportable chat tabs and embeds, update the L6 source guard,
then run the focused notebook/source-guard Swift tests.

## Checkpoint 2026-07-07 MAS Chat Tab Disclosure Proof

### Change summary

- Added an injectable `chatTabContentAvailable` parameter to
  `LensFidelityDisclosure.items`, defaulting to
  `EpdocNotebookBuildCapabilities.isChatTabContentAvailable` so product behavior
  still follows the target macro while tests can force the MAS-style branch.
- Threaded that capability through notebook tab/embed scanning so document-lens
  chat references render when chat content is available and degrade when it is
  unavailable.
- Added focused Swift proof that a document lens with unavailable chat content
  exposes both chat tabs and inline chat embeds as degraded transcript exports,
  while the content-available branch keeps those references quiet.
- Extended the L6 source guard to pin the injectable capability and MAS-style
  degradation test.

### Touched files

- `Epistemos/Views/Notes/LensFidelityDisclosure.swift`
- `EpistemosTests/EpdocNotebookManifestTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- `docs/plans/lumenlens/INTENT_LEDGER.md`

### Evidence

- Focused Swift tests passed:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocNotebookManifestTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result bundle:
    `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_18-21-37--0500.xcresult`
  - `xcrun xcresulttool get test-results summary` reported `Passed`,
    25 passed, 0 failed, 0 skipped.
- Scoped forbidden-dependency scan over the touched LumenLens implementation and
  tests found the expected `chatTabContentAvailable` wiring and no new
  `ExperimentalAgent` or `Process(` dependency path in
  `LensFidelityDisclosure.swift`; `KINDRED_ENABLED` remains isolated to the
  existing build-capability gate.
- AppStore Debug build completed with zero build errors:
  `./scripts/xcodebuild_epistemos.sh build -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-mas-tabs CODE_SIGNING_ALLOWED=NO`
  - Build log:
    `.derived-data-lumenlens-mas-tabs/Logs/Build/AA6B1A91-5752-40A6-A947-9BC8254F8396.xcactivitylog`
  - `LogStoreManifest.plist` reports scheme `Epistemos-AppStore`,
    high-level status `W`, 0 errors, 26 warnings.
  - Product exists at
    `.derived-data-lumenlens-mas-tabs/Build/Products/Debug/Epistemos.app`.

### Proven

- MAS-style chat-tab degradation can be exercised independently from the active
  test scheme's `KINDRED_ENABLED` macro.
- Notebook chat tabs and inline chat block embeds degrade to disclosure rows
  with transcript exports when chat content is unavailable.
- The content-available document-lens branch treats chat references as rendered
  and keeps them out of the disclosure list.
- The LumenLens notebook/disclosure slice compiles under the AppStore Debug
  target with `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.

### Not proven

- Full Swift-suite health remains blocked by the already-observed broad
  cross-lane failures from the L6 run.
- Release-clean App Store artifact status remains unproven; the build still
  stages existing non-release resources such as `rg`, so Keelstone release-gate
  cleanup remains separate debt.
- Manual UI proof for the disclosure popover and jump-to-Epdoc interaction was
  not run in this batch.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| Full Swift-suite triage | Existing broad failures can hide regressions outside this focused LumenLens slice. | A later full-suite run with failures classified or fixed without touching protected Experimental/THE_R-owned surfaces. |
| App Store artifact scan cleanup | MAS-first sellability needs release-gate proof that staged app resources and symbols exclude forbidden subprocess/tool-terminal payloads. | Keelstone-owned release-gate scan passing on the AppStore artifact. |
| Manual disclosure UI check | The source and model behavior are proven, but the user-facing popover path was not visually exercised. | Runtime/manual UI proof that the degraded transcript rows appear and the Document jump still routes to the Epdoc surface. |

## Checkpoint 2026-07-07 Native Epoch Gate Hardening

### Owner wording

> Continue LumenLens only: Epdoc/WKWebView bridge, js-editor editor bridge,
> provenance store, restart replay, and related focused tests.
>
> Strategy pivot: pause Pro/Experimental expansion. Near-term product target
> is MAS-first sellable Epistemos.

### Interpreted intent

Continue the LumenLens hardening loop inside the MAS-safe Epdoc/WKWebView
bridge and provenance lane. The next source-level risk found in the current
tree is that JS persistence/provenance events are typed as epoch-bearing, and
the controller drops mismatched epochs, but it still accepts nil-epoch
`contentDidChange`, `markdownDidChange`, `documentStatsChanged`,
`loadSettled`, `suggestionApplied`, and `suggestionResolved` events. That is a
stale-bundle/stale-message hole in the native side of the L0/L3/L5 bridge.

### Hard constraints

- Do not edit `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish
  files, or `ExperimentalAgentPolishSourceGuardTests.swift`.
- Do not continue Pro/Experimental, donor 1Code/THE R, Kindred runtime,
  subprocess/tool-terminal, native-shell/Craft, or model-runtime lanes.
- Keep the edit in LumenLens bridge/provenance tests and guards.
- Preserve non-mutating UI bridge messages that legitimately do not carry
  epochs, such as `editorReady`, caret/menu requests, paste classification,
  HTML workspace requests, and asset handoffs.
- Before any `xcodebuild`, state the exact command.

### Non-goals

- No new JS bundle feature or UI polish.
- No App Store artifact/package cleanup in this batch.
- No broad full-suite fix pass.
- No change to the existing JS epoch payload shape unless the native guard
  exposes a real mismatch.

### Acceptance checks

- Native controller rejects nil-epoch persistence/provenance messages after a
  host load, not only mismatched stale epochs.
- Existing real JS bridge delivery remains valid because JS already posts
  epochs for those message types.
- Focused Epdoc bridge/provenance tests pass after updating direct unit calls
  to use explicit epochs where they model real JS traffic.
- The source guard pins the native epoch requirement so future refactors do
  not reopen the hole.

### Contradictions/questions

Non-mutating UI bridge messages are intentionally not all epoch-stamped. The
guard should be narrow: persistence and provenance messages require a matching
epoch; UI-only messages remain accepted without one.

### Next action

Add a controller-side `requiresMatchingLoadEpoch` guard, update direct
bridge/provenance tests to send explicit epochs for persistence-bearing events,
add a focused rejection test for nil-epoch events, update the LumenLens source
guard, then run the focused bridge/provenance/source-guard checks.

## Checkpoint 2026-07-07 Native Epoch Gate Proof

### Changes made

- `EpdocEditorChromeController.handleBridgeMessage` now requires a matching
  load epoch for persistence/provenance events:
  `contentDidChange`, `markdownDidChange`, `documentStatsChanged`,
  `loadSettled`, `suggestionApplied`, and `suggestionResolved`.
- UI-only/non-mutating bridge messages remain accepted without an epoch:
  `editorReady`, errors, caret/menu requests, image asset handoffs, and HTML
  workspace requests.
- Direct Swift bridge/provenance tests that model real JS traffic now pass
  explicit epochs.
- Added a focused native rejection test proving nil-epoch persistence and
  provenance events do not mutate content, stats, dirty state, or provenance
  callbacks after a host load.
- Updated the LumenLens source guard to pin the native
  `requiresMatchingLoadEpoch` requirement.

### Touched files

- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- `docs/plans/lumenlens/INTENT_LEDGER.md`

### Evidence

- JS bridge shape check:
  `node js-editor/scripts/check-bridge-outbound.mjs`
  - Exit: 0.
- JS document load-state check:
  `node js-editor/scripts/check-document-load-state.mjs`
  - Output: `document load-state check passed`.
- Focused Swift bridge/provenance/source-guard slice:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6 -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EditorProvenanceStoreTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result bundle:
    `.derived-data-lumenlens-l6/Logs/Test/Test-Epistemos-2026.07.07_18-41-21--0500.xcresult`
  - `xcresulttool` summary: `result = Passed`, 87 passed, 0 failed,
    0 skipped.
- AppStore Debug compile proof:
  `./scripts/xcodebuild_epistemos.sh build -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-native-epoch CODE_SIGNING_ALLOWED=NO`
  - Exit: 0.
  - Terminal output ended with `** BUILD SUCCEEDED **`.
  - Product exists at
    `.derived-data-lumenlens-native-epoch/Build/Products/Debug/Epistemos.app`
    with timestamp `Jul 7 18:52:47 2026`.
- Forbidden-dependency scan over touched implementation/test/ledger files:
  - No new `Process(`, `ExperimentalAgent`, `THE_R`, `1Code`, or
    `.research-clones` dependency was introduced in the touched implementation
    path. Matches are limited to source-guard negative assertions and ledgered
    owner constraints.
- JS epoch-shape scan:
  - Current JS outbound call sites for persistence/provenance events carry an
    `epoch` through `index.ts`, `bridge/inbound.ts`,
    `extensions/paste-classifier-bridge.ts`, and
    `scripts/check-bridge-outbound.mjs`.

### Proven

- Native Epdoc bridge handling no longer accepts epochless persistence or
  provenance events after a host load.
- The real JS bridge contract remains aligned because those event types are
  epoch-bearing on the JS side.
- L3 minimal markdown writeback and L5 suggestion provenance focused Swift
  tests still pass under the explicit epoch contract.
- The shared AppStore target compiles with the native epoch gate.

### Not proven

- The full Swift suite remains broadly failing from the earlier L6 run and has
  not been re-triaged in this batch.
- Release-clean AppStore artifact status remains unproven. The Debug AppStore
  product still stages existing non-release resources such as
  `Contents/Resources/rg`, so the Keelstone release gate remains separate
  debt.
- Manual live UI editing proof beyond the existing bundled WK bridge smoke was
  not run in this batch.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| Full Swift-suite triage | Existing broad failures can hide regressions outside this focused LumenLens slice. | A later full-suite run with failures classified or fixed without touching protected Experimental/THE_R-owned surfaces. |
| Release-clean AppStore artifact gate | MAS-first sellability requires the shipped artifact to exclude forbidden subprocess/tool-terminal payloads and unrelated runtime binaries. | Keelstone-owned release-gate scan passing on the AppStore artifact. |
| Live editor interaction proof | Source and focused WK bridge smoke are proven, but an actual user editing pass through the app surface was not re-run after this native guard. | Manual or automated app-session proof that Epdoc edits, minimal markdown writeback, and suggestion decisions still flow in a loaded note. |

## Checkpoint 2026-07-07 MAS-June Epdoc MiniChat Redirect

### Owner wording

> MAS-JUNE EPDOC MINICHAT REDIRECT LOCK -- 2026-07-07
>
> I still want the useful Epdoc mini-chat/data-agent pattern, but MAS must not
> import Kindred/1Code. Preserve the product idea: a compact assistant attached
> to Epdoc that can read the current note, selection, vault context, and
> datasets, then propose edits or dataset operations. Rebuild that as MAS-safe
> June/agent_core, not as 1Code, Kindred, Node, terminal, subprocess, or
> companion presence.
>
> This supersedes older "Epdoc minichat deferred" text only for this new
> MAS-June assistant seam. It does NOT make Kindred MAS-safe. Kindred remains
> Experimental/1Code only.

### Interpreted intent

Redirect the previous "defer Epdoc minichat" instruction into a narrow,
MAS-safe assist seam: an Epdoc-attached native SwiftUI assistant surface
(`JuneEpdocAssist` / MAS Epdoc MiniChat) that uses existing June session,
gateway, approval, and in-process `agent_core` infrastructure. The assistant
may read bounded Epdoc context and propose note or dataset work, but it must
stage edits through LumenLens suggestions/provenance and RECKONER
TabularSuggestion/approval seams instead of mutating notes/cells directly.

### What this supersedes

- Older Plan 2/LumenLens wording saying Epdoc minichat is deferred is
  superseded only for the MAS-June assistant seam.
- The old 1Code/KINDRED minichat extraction path remains parked provenance and
  is not promoted to MAS.
- Kindred remains Experimental/1Code-only; no companion presence or runtime
  becomes MAS-safe through this redirect.

### Hard constraints

- Use `JuneAgentGateway`, `JuneSessionStore`, `GooseMASAgentCoreRunner`, and
  `JuneAgentApprovalRegistry`; do not fork a second agent runtime.
- Do not import or depend on 1Code `sub_chats`, Kindred presence, tRPC, Node,
  terminal, Monaco, file-viewer, git client, browser-use, stdio MCP, local
  servers, subprocesses, or Tauri runtime.
- Keep secrets out of JS. Bound and validate every bridge/context payload.
- Local lane remains honest chat/light-agent unless tool grammar is proven.
  Cloud lane may use in-process `agent_core` tool events and approval prompts.
- Note edits must return structured suggestions into the LumenLens
  SuggestionAdapter / AI diff path; the user accepts/rejects/undoes and
  provenance records the turn.
- Disk persistence remains through the existing editor save pipeline and
  `AtomicVaultWriter`.
- Dataset work must use RECKONER `dataset.*` tools, TabularSuggestion,
  ApprovalGate, and per-cell/range accept/reject; no direct cell writes.
- Keep this batch out of protected THE_R / Experimental 1Code visual work and
  do not edit `ExperimentalAgentPolishSourceGuardTests.swift`.

### Non-goals

- No Kindred implementation, companion runtime, mascot/presence work, or 1Code
  UI import.
- No RECKONER grid/calc implementation inside LumenLens.
- No arbitrary subprocess/tool-terminal/model-runtime expansion.
- No broad App Store artifact cleanup in this batch; release-clean scanning
  remains Keelstone-owned evidence debt.

### Acceptance checks

- P1 source audit proves current June bridge/gateway/session/approval seams and
  Epdoc suggestion/write seams are usable for a MAS Epdoc assistant.
- P2 context packet is bounded, validated, note-scoped, and contains location
  metadata: note id, vault-relative path, selected range/text, visible headings,
  active lens, dataset refs, and provenance context.
- P3 native Epdoc assistant shell is attached to the Epdoc surface and routes
  through June/agent_core rather than a third agent product.
- P4 note flow stages a suggestion, never blindly mutates, and records
  provenance through the existing accepted/rejected path.
- P5 dataset flow is staged through RECKONER/TabularSuggestion seams and remains
  no-op or honestly unavailable until the live dataset tool seam exists.
- P6 proof includes focused tests, AppStore build, leak/symbol scans for
  Kindred/1Code, bridge bounds tests, vault permission evidence, and
  screenshot/manual proof before claiming done.

### Source audit completed before this checkpoint

- `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
- `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
- `docs/prompts/PROMPT_PLAN_2_EDITOR.md`
- `docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md`
- `docs/plans/reckoner/PLAN_RECKONER_EPI-RP-09-RECKONER.md`
- `docs/plans/kindred/BUILD_PROMPT_KINDRED.md` as negative provenance only
- `Epistemos/JuneAgent/JuneAgentBridge.swift`
- `Epistemos/JuneAgent/JuneAgentGateway.swift`
- `Epistemos/JuneAgent/JuneAgentApprovalRegistry.swift`
- `Epistemos/JuneAgent/JuneSessionStore.swift`
- `Epistemos/Views/Epdoc/EpdocCopilotDockView.swift`
- `js-editor/src/suggestions/SuggestionAdapter.ts`
- `js-editor/src/bridge/inbound.ts`
- `Epistemos/Sync/AtomicVaultWriter.swift`

### Contradictions/questions

- June's current bridge exposes native notes as read-only and `create_note`
  deliberately fails in MAS. The new assist seam must preserve that boundary
  and stage note edits through Epdoc suggestions rather than adding web-side
  note mutation.
- The existing Epdoc dock is a compact native action dock, not a June-backed
  chat surface. It is a usable mount point, but its old fixed transform command
  set is not enough for the requested current-note assistant.
- RECKONER dataset tools and TabularSuggestion are not live enough to claim P5
  end-to-end. The safe first step is to carry dataset references in the context
  packet and gate dataset operations as staged/unavailable until RECKONER
  exposes the real tool/suggestion seam.

### Next action

Perform the P1 source audit in code, then implement the smallest MAS-safe P2/P3
slice: a bounded `JuneEpdocAssistContext` provider plus a native Epdoc-attached
assistant shell that can start or reuse a June session with note-scoped context,
without writing files or importing parked runtimes. Add focused source/shape
tests and record any broader xcodebuild/AppStore/manual checks as verification
debt until the next checkpoint.

## Checkpoint 2026-07-07 MAS-June Epdoc MiniChat P1-P3 Slice Proof

### Implemented

- Added `JuneEpdocAssistContext` and `JuneEpdocAssistSelection` as a bounded,
  native Swift context packet for Epdoc-owned note location metadata: note id,
  title, vault-relative path, active lens, selected range/text, visible
  headings, dataset references, provenance lines, and capped markdown excerpt.
- Added `JuneEpdocAssistBridge` as the UI-facing submit seam. In App Store
  builds it starts/reuses the existing June surface holder and submits through
  `JuneAgentGateway`; outside App Store builds it returns an honest unavailable
  status.
- Added `JuneAgentGateway.submitEpdocAssist(prompt:context:)`, reusing the
  existing June session store, current session selection, concurrency guard, and
  `startTurn` stream path instead of adding a new runtime.
- Wired `MarkdownDocumentSurface` and `EpdocEditorChromeView` to provide the
  bounded Epdoc assist context to the native `EpdocCopilotDockView`.
- Extended the Epdoc JS->Swift selection bridge so selected text may be sent as
  a bounded optional payload; Swift rejects oversized selection text and stores
  only a capped value for assist context.
- Added a native compact "Ask June" shell in the Epdoc dock. It submits the
  note-scoped context to June and does not import `WKWebView`, Kindred, 1Code,
  Node, terminal, subprocess, Tauri, or parked sub-chat UI.

### Evidence

- `npm --prefix js-editor run check:bridge-outbound` passed.
- `npm --prefix js-editor run check:document-load-state` passed.
- `npm --prefix js-editor run typecheck` passed.
- `git diff --check -- Epistemos/JuneAgent/JuneEpdocAssist.swift
  Epistemos/JuneAgent/JuneAgentGateway.swift
  Epistemos/Views/Epdoc/EpdocCopilotDockView.swift
  Epistemos/Views/Epdoc/EpdocEditorChromeView.swift
  Epistemos/Views/Notes/MarkdownDocumentSurface.swift
  Epistemos/Engine/EpdocEditorBridge.swift js-editor/src/bridge/outbound.ts
  js-editor/src/extensions/caret-rect-emitter.ts
  EpistemosTests/EpdocCopilotSurfaceTests.swift
  EpistemosTests/EpdocEditorBridgeTests.swift
  docs/plans/lumenlens/INTENT_LEDGER.md` passed.
- First focused Xcode run failed at compile time because a private
  `String.prefixString` helper inherited main-actor isolation under the
  project default. The helper was removed and the bounded path uses
  `String(prefix(...))` directly.
- Second focused Xcode run failed one source-guard assertion due to a test
  string expecting `JuneEpdocAssist` without spaces in a user-facing fallback.
  The source guard was corrected to the implemented "June Epdoc Assist"
  message.
- Final focused Xcode command:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  .derived-data-lumenlens-mini-chat
  -only-testing:EpistemosTests/EpdocCopilotSurfaceTests
  -only-testing:EpistemosTests/EpdocEditorBridgeTests
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  passed: latest result bundle reported 81 passed, 0 failed, 0 skipped.
- First AppStore Debug build attempt:
  `xcodebuild build -quiet -project Epistemos.xcodeproj -scheme
  Epistemos-AppStore -configuration Debug -destination 'platform=macOS'
  -derivedDataPath .derived-data-lumenlens-mini-chat-appstore` failed before
  Swift compile because `agent_core` could not write
  `target/aarch64-apple-darwin/debug/deps/libagent_core.a`: no space left on
  device.
- Cleaned only the two derived-data folders created by this mini-chat batch:
  `.derived-data-lumenlens-mini-chat` and
  `.derived-data-lumenlens-mini-chat-appstore`. Free space rose from about
  870 MiB to about 5.9 GiB.
- Retried the same AppStore Debug build command; it passed.
- AppStore Debug bundle path scan for
  `kindred|1code|sub_chats|the_r|experimentalagent|experimental-web|tauri`
  found existing resource debt:
  `Contents/Resources/experimental-web.tar.gz` and
  `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- AppStore Debug `Epistemos.debug.dylib` scan confirmed the new
  `JuneEpdocAssist` symbols and strings are present, but also found existing
  tauri-shim strings. No Kindred/1Code/sub_chats/ExperimentalAgent path matches
  were found in that scan.

### Proven

- P1/P2/P3 are represented in code: the current June gateway/session seams are
  reused, the Epdoc context packet is bounded and source-tested, and the UI
  shell is native SwiftUI attached to Epdoc.
- The selected-text bridge is bounded on both JS emission and Swift decode.
- The assistant path does not directly write notes, vault files, or dataset
  cells.
- Source guards now assert the dock routes free-form prompts through MAS June
  and rejects parked runtime imports.

### Not proven

- P4 is not end-to-end complete: this slice submits note-scoped prompts to
  June, but it does not yet convert a live assistant response into a staged
  Epdoc AI-diff/SuggestionAdapter edit with accept/reject/undo proof.
- P5 is not complete: dataset references are carried in context, but no live
  RECKONER `dataset.*` -> TabularSuggestion -> ApprovalGate -> per-cell/range
  accept/reject path is proven.
- P6 is not complete: an AppStore Debug build now passes, but the artifact is
  not release-clean because existing resources still include
  `experimental-web.tar.gz` and `JuneWeb/tauri-internals-shim.js`; security-
  scoped vault permission proof and screenshot/manual UI evidence were not run
  in this batch.
- The focused `Epistemos` Debug test scheme compiles Experimental sources
  because of existing scheme flags; that is useful for broad compile pressure
  but is not a MAS-clean artifact proof.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| P4 staged note edit flow | The product target requires ask -> stream -> staged suggestion -> accept/reject -> provenance -> reload proof, not only prompt submission. | A focused test or manual run showing a June/Epdoc assist response entering the AI-diff/SuggestionAdapter path and persisting provenance through the existing save pipeline. |
| P5 staged dataset flow | Dataset operations must never blindly mutate cells. | A RECKONER-backed flow showing `dataset.*` intent, TabularSuggestion, ApprovalGate, per-cell/range accept/reject, and provenance. |
| Release-clean AppStore artifact | The done bar requires the MAS artifact to exclude parked Experimental/Tauri/runtime payloads, not only compile. | Remove or gate existing `experimental-web.tar.gz` and `JuneWeb/tauri-internals-shim.js` from the AppStore artifact, then rerun the AppStore build and artifact leak/symbol scan. |
| Manual UI proof | Source guards prove shape, but not live ergonomics or screenshot-level presentation. | Epdoc note opened in app, Ask June dock visible, context-bearing prompt submitted, no blind mutation, screenshot/manual notes captured. |

## Checkpoint 2026-07-07 Goal Continuation After MAS MiniChat P1-P3

### Verbatim steer excerpts

> Continue working toward the active thread goal.
>
> Resume the stopped Keelstone/LumenLens agent from the current dirty tree.
> First read AGENTS.md, CLAUDE.md,
> docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md,
> docs/plans/keelstone/PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md,
> docs/plans/keelstone/INTENT_LEDGER.md,
> docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md,
> docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md,
> docs/plans/lumenlens/PLAN_LUMENLENS_EPI-RP-02-LUMENLENS.md,
> and docs/plans/lumenlens/INTENT_LEDGER.md.
>
> Do not restart or discard work. Keep Keelstone and LumenLens separate.
> Keelstone is audit/evidence only unless I explicitly steer otherwise.
> Continue LumenLens from the latest L5 runtime gap: prove or harden real
> WKWebView/app-side bridge delivery for minimal writeback and suggestion
> provenance, or move to existing-vault restart replay if live WebKit proof is
> not locally reliable.

Latest owner product steer still active:

> MAS-JUNE EPDOC MINICHAT REDIRECT LOCK -- 2026-07-07
>
> Preserve the product idea: a compact assistant attached to Epdoc that can
> read the current note, selection, vault context, and datasets, then propose
> edits or dataset operations. Rebuild that as MAS-safe June/agent_core, not as
> 1Code, Kindred, Node, terminal, subprocess, or companion presence.

### Interpreted intent

Continue from the current dirty tree without narrowing the real objective to
the already-proven P1-P3 slice. Keelstone remains evidence-only. LumenLens stays
active in the MAS-safe Epdoc/WKWebView bridge, provenance, restart replay, and
June Epdoc Assist seams. The next highest-risk unproven claim is P4: a
June/Epdoc assist response must become a staged note suggestion through the
existing AI-diff/SuggestionAdapter/provenance path, never a blind vault write.

### Hard constraints

- Stay on `feat/goose-surface`; do not switch branches.
- Do not discard or restart current work.
- Keep protected Experimental/1Code/THE_R files and
  `ExperimentalAgentPolishSourceGuardTests.swift` untouched.
- Do not introduce Kindred/1Code, Node, terminal, subprocess, local server,
  stdio MCP, Tauri runtime, browser-use, Monaco, file-viewer, or git-client
  dependencies.
- Before any `xcodebuild`, state the exact command.
- Keep tests batched and focused; record broader verification debt.
- Preserve the LumenLens editing model: note edits are staged suggestions with
  accept/reject/undo and provenance; disk writes continue through the existing
  save pipeline / `AtomicVaultWriter`.

### Non-goals

- No Keelstone implementation in this batch unless new evidence is generated
  incidentally.
- No release-artifact cleanup of existing `experimental-web.tar.gz` or
  `JuneWeb/tauri-internals-shim.js` while the current target is P4 note
  staging.
- No RECKONER grid/calc internals for P5 in this batch.
- No manual UI/screenshot claim until a runtime app pass is actually run.

### Acceptance checks for the next slice

- Read the current AI-diff/SuggestionAdapter/provenance/June stream seams before
  editing.
- Add the smallest MAS-safe path that turns a structured Epdoc assist note
  suggestion into a staged editor suggestion or AI-diff draft without direct
  mutation.
- Add focused source/unit tests proving the staged path is bounded, note-scoped,
  uses existing review commands, and does not import parked runtimes.
- Run focused JS/Swift checks sized to the touched surfaces, then append proof
  and remaining debt.

### Current evidence state

- P1-P3 MAS-June Epdoc Assist are proven by JS checks, focused Swift tests, and
  an AppStore Debug build.
- The L3/L5 bridge/provenance runtime gap has prior evidence: real bundled
  WKWebView outbound bridge smoke, epoch-bearing persistence/provenance events,
  durable GRDB provenance persistence, and existing-vault writer restart replay
  were recorded in earlier checkpoints.
- P4/P5/P6 are not proven. The next code pass should advance P4 before claiming
  any assistant edit flow.

### Contradictions/questions

- The current assist shell submits context to June but does not yet consume a
  structured response into the Epdoc review path. That is useful P1-P3
  infrastructure, not P4 completion.
- The AppStore Debug build passes, but the artifact scan still finds existing
  Tauri/experimental resource debt; this remains release-gate debt, not proof
  against P6.
- Existing June gateway streams assistant text to the June surface. The Epdoc
  dock needs a minimal bridge/contract to stage suggestions without pulling
  agent internals into the editor.

### Next action

Audit `EpdocAIDiffReview`, `EpdocEditorCommand.stageAIDiff`,
`SuggestionAdapter`, `EditorProvenanceStore`, `JuneAgentGateway`, and current
tests. Then implement the smallest P4 slice that stages a bounded structured
note suggestion through the existing review path.

## Checkpoint 2026-07-07 MAS-June Epdoc MiniChat P4 Staged Note Suggestion Slice

### Verbatim steer excerpts

> MAS-JUNE EPDOC MINICHAT REDIRECT LOCK -- 2026-07-07
>
> The assistant never blindly mutates notes or cells. For note edits, return
> structured suggestions into the LumenLens SuggestionAdapter / AI diff path.
> User can accept/reject/undo, and provenance records the turn. Disk
> persistence goes through existing save pipeline / AtomicVaultWriter.

Latest continuation steer:

> Continue LumenLens from the latest L5 runtime gap: prove or harden real
> WKWebView/app-side bridge delivery for minimal writeback and suggestion
> provenance, or move to existing-vault restart replay if live WebKit proof is
> not locally reliable.

### Interpreted intent

Advance P4 without importing parked runtimes: use the existing June
gateway/session store as the assistant conversation source, parse a bounded
structured selection-replacement suggestion natively, stage it through the
existing JS `SuggestionAdapter`, and keep accept/reject as explicit user
commands so provenance remains on the already-proven suggestion event path.

### Implemented

- Added native `EpdocSuggestionReviewDraft` around `EpdocSuggestionSpanPayload`
  with stage/accept/reject commands.
- Added Swift-to-JS `EpdocEditorCommand.applySuggestion`,
  `acceptSuggestion`, and `rejectSuggestion` encoders targeting the existing
  `window.epistemos.runCommand("applySuggestion" | "acceptSuggestion" |
  "rejectSuggestion", ...)` inbound bridge.
- Added `JuneEpdocAssistSuggestionStageResult` and a native
  `JuneEpdocAssistNoteSuggestionParser` that only stages a suggestion when:
  current Epdoc selection is non-empty, the model returned fenced
  `epdoc-note-suggestion` JSON, `from`/`to` match the current selection, `before`
  matches selected text when available, replacement size is bounded, and
  `before != after`.
- Added `JuneAgentGateway.latestEpdocAssistNoteSuggestion` to read the latest
  persisted assistant reply for the Epdoc session and refuse staging while the
  turn is still running.
- Extended the native `EpdocCopilotDockView` with a session-aware "stage latest
  suggestion" affordance plus accept/reject buttons. The dock still dispatches
  editor commands; it does not write note files or dataset cells.
- Wired `EpdocEditorChromeView` to `JuneEpdocAssistBridge.latestNoteSuggestion`
  so the Epdoc surface remains native SwiftUI and uses the MAS June bridge.
- Added focused tests for suggestion draft command mapping, parser acceptance
  and refusal cases, source guards, and the Swift-to-JS command expressions.

### Verification

- Passed: `npm --prefix js-editor run check:suggestions`
- Passed: `npm --prefix js-editor run check:bridge-outbound`
- Passed: `npm --prefix js-editor run typecheck`
- First focused Swift test run failed before tests because `agent_core` hit
  `No space left on device` while building. Cleaned only generated artifacts:
  `.derived-data-lumenlens-p4-suggestion`,
  `.derived-data-lumenlens-mini-chat-appstore`, and `cargo clean` in
  `agent_core` (removed 224.0 GiB of generated Cargo output).
- Retried and passed:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS'
  -derivedDataPath .derived-data-lumenlens-p4-suggestion
  -only-testing:EpistemosTests/EpdocCopilotSurfaceTests
  -only-testing:EpistemosTests/EpdocEditorBridgeTests
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
- Xcode result summary:
  `.derived-data-lumenlens-p4-suggestion/Logs/Test/Test-Epistemos-2026.07.07_19-56-41--0500.xcresult`
  reported `result: Passed`, `passedTests: 85`, `failedTests: 0`,
  `skippedTests: 0`.
- Passed AppStore compile:
  `xcodebuild build -quiet -project Epistemos.xcodeproj
  -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS'
  -derivedDataPath .derived-data-lumenlens-p4-appstore`
- Exact-token AppStore bundle scan over extracted strings found no matches for
  `Kindred`, `sub_chats`, `1Code`, `THE_R`, or `ExperimentalAgent`.
  A broader raw binary scan is not useful because it false-matches Rust
  `THE_REGISTRY` and Swift mangled symbol lengths such as `21Code...`.

### Proven

- The MAS-June Epdoc dock can submit note-scoped prompts and now has a native
  staged suggestion review seam.
- Note suggestions are bounded and selection-scoped before they can enter the
  editor bridge.
- Staging/accept/reject reuse the existing LumenLens `SuggestionAdapter` bridge
  contract and durable JS-to-Swift provenance messages.
- The new AppStore-gated June staging path compiles under the AppStore scheme.
- The touched mini-chat path does not add Kindred/1Code/sub-chat runtime
  imports or subprocess/local-server dependencies.

### Not proven

- Full P4 is still missing live manual proof: ask -> stream -> stage latest
  suggestion -> accept/reject -> provenance -> reload proof was not executed in
  a running app session.
- P5 remains unimplemented: no RECKONER `dataset.*` ->
  `TabularSuggestion` -> `ApprovalGate` -> per-cell/range accept/reject proof.
- P6 remains release-gate debt: the earlier AppStore artifact scan found
  existing `experimental-web.tar.gz` and `JuneWeb/tauri-internals-shim.js`.
  This P4 slice did not remove that existing resource debt.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| Live P4 runtime pass | Source/unit checks prove the seam, not a real June turn driving WebKit state. | Open an Epdoc note, select text, ask June for a fenced `epdoc-note-suggestion`, stage it, accept/reject it, verify JS provenance events persist, restart/reload the note, and capture notes/screenshots. |
| Undo proof | The owner done bar includes accept/reject/undo. | Confirm the staged suggestion transaction and accepted replacement integrate with existing editor undo history without bypassing provenance. |
| P5 dataset staging | Dataset operations must never mutate cells blindly. | Implement and prove a RECKONER-backed `dataset.*` tool path to `TabularSuggestion`, ApprovalGate, per-cell/range accept/reject, and provenance. |
| Release-clean MAS artifact | AppStore Debug compile now passes, but release-clean resources remain a separate gate. | Remove/gate the existing experimental/Tauri resource debt from AppStore packaging, rebuild, and rerun broad artifact leak/symbol scans. |

## Checkpoint 2026-07-08 Goal Continuation Toward L5 Runtime Proof

### Verbatim steer excerpts

Active objective file:

> Resume the stopped Keelstone/LumenLens agent from the current dirty tree.
> First read AGENTS.md, CLAUDE.md,
> docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md,
> docs/plans/keelstone/PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md,
> docs/plans/keelstone/INTENT_LEDGER.md,
> docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md,
> docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md,
> docs/plans/lumenlens/PLAN_LUMENLENS_EPI-RP-02-LUMENLENS.md,
> and docs/plans/lumenlens/INTENT_LEDGER.md.
>
> Do not restart or discard work. Keep Keelstone and LumenLens separate.
> Keelstone is audit/evidence only unless I explicitly steer otherwise.
> Continue LumenLens from the latest L5 runtime gap: prove or harden real
> WKWebView/app-side bridge delivery for minimal writeback and suggestion
> provenance, or move to existing-vault restart replay if live WebKit proof is
> not locally reliable.

Latest MAS redirect still binding:

> MAS-JUNE EPDOC MINICHAT REDIRECT LOCK -- 2026-07-07
>
> The assistant never blindly mutates notes or cells. For note edits, return
> structured suggestions into the LumenLens SuggestionAdapter / AI diff path.

### Interpreted intent

Do not treat the previous P4 source/unit slice as enough. Continue from the
dirty tree and strengthen the runtime evidence for the actual editor bridge:
prove a host-issued staged suggestion command reaches the bundled WKWebView,
is handled by the live `SuggestionAdapter`, and returns provenance events over
the app-side bridge. Keep Keelstone as evidence-only and do not touch parked
Experimental/1Code/Kindred lanes.

### Hard constraints

- Branch remains `feat/goose-surface`; do not switch branches.
- Do not edit `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish
  files, or `ExperimentalAgentPolishSourceGuardTests.swift`.
- Stay MAS-safe: no Kindred/1Code imports, Node runtime, local server,
  subprocess, terminal, stdio MCP, Tauri runtime, Monaco, file-viewer, or
  browser-use path.
- Before any `xcodebuild`, state the exact command.
- Keep broad verification batched; run the narrow proof that matches the
  touched bridge/runtime surface.

### Non-goals

- No Keelstone implementation in this cycle.
- No RECKONER dataset P5 implementation in this cycle unless it becomes the
  next smallest safe target after runtime note-suggestion proof.
- No AppStore release-resource cleanup of existing experimental/Tauri artifact
  debt in this cycle.
- No claim of full P4 completion without live ask/stream/stage/reload evidence.

### Acceptance checks for this cycle

- Read the existing WKWebView bridge probe/helpers and JS inbound
  `applySuggestion`/`acceptSuggestion`/`rejectSuggestion` path before editing.
- Add the smallest focused runtime proof that evaluates the Swift command
  expressions in the bundled editor and observes outbound
  `suggestionApplied`/`suggestionResolved` bridge messages.
- Preserve the existing durable provenance path; do not add a parallel store or
  direct disk mutation.
- Run focused JS/Swift checks and update this ledger with evidence and
  remaining debt.

### Contradictions/questions

- Existing `bundled WKWebView outbound bridge delivers writeback and provenance
  payloads` injects outbound events directly; it proves decoding/delivery but
  not that host `applySuggestion` reaches the real live SuggestionAdapter.
- The current P4 implementation parses June replies and emits editor commands,
  but runtime proof is still needed to show those commands actually produce
  tracked suggestion/provenance events in the bundled editor.

### Next action

Audit `EpdocEditorBridgeTests` runtime helpers and `js-editor/src/bridge/inbound.ts`,
then add a focused WKWebView test for `applySuggestion` -> `acceptSuggestion`
and/or `rejectSuggestion` through the live editor bridge.

## Checkpoint 2026-07-08 L5 WKWebView Inbound Suggestion Runtime Proof

### What changed

- Added a bundled `WKWebView` runtime proof in
  `EpistemosTests/EpdocEditorBridgeTests.swift` that loads
  `epistemos-doc:///editor.html`, waits for the real inbound command surface,
  sets ProseMirror JSON content, sends the Swift
  `EpdocEditorCommand.applySuggestion` command, verifies live deletion/insertion
  suggestion marks with the host suggestion id, sends
  `EpdocEditorCommand.acceptSuggestion`, observes `suggestionApplied` and
  `suggestionResolved(.accepted)` through the real WebKit script-message bridge,
  and verifies final editor text.
- Fixed the JS suggestion adapter so agent-ingested suggestion transactions are
  marked with `suggestChangesKey.skip`; this prevents the decorated dispatch
  from re-transforming an already tracked suggestion transaction and losing the
  host id.
- Fixed the inbound suggestion command stamping so apply/accept/reject
  transactions carry the current load epoch and `USER_INPUT_META`; this lets
  MAS host-issued suggestion transactions pass the document-load filter during
  the short post-load suppression window.
- Extended `js-editor/scripts/check-suggestions.mjs` with a regression check for
  the decorated-dispatch path: agent edit -> tracked marks -> accept by host id.

### Evidence

- `npm --prefix js-editor run check:suggestions` exited 0 and printed
  `suggestion adapter check passed`.
- `npm --prefix js-editor run check:bridge-outbound` exited 0.
- `npm --prefix js-editor run check:document-load-state` exited 0 and printed
  `document load-state check passed`.
- `npm --prefix js-editor run typecheck` exited 0.
- After stating the command, ran
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-p4-suggestion -only-testing:EpistemosTests/EpdocEditorBridgeTests`.
  Result bundle:
  `.derived-data-lumenlens-p4-suggestion/Logs/Test/Test-Epistemos-2026.07.07_20-55-58--0500.xcresult`.
  `xcresulttool` summary: 58 passed, 0 failed, 0 skipped.
- After stating the command, ran
  `xcodebuild build -quiet -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-appstore`.
  The AppStore scheme build exited 0 and produced
  `.derived-data-lumenlens-appstore/Build/Products/Debug/Epistemos.app`.
- Focused forbidden runtime scan across touched LumenLens/June/source files for
  `Kindred`, `sub_chats`, `1Code`, `THE_R`, `ExperimentalAgent`, `Process(`,
  `NSTask`, `child_process`, `tRPC`, `Tauri`, `Monaco`, `browser-use`,
  `stdio MCP`, and `local server` returned no matches.
- Focused AppStore built-product string scan for `Kindred`, `sub_chats`,
  `1Code`, `THE_R`, `ExperimentalAgent`, `experimental-web`,
  `tauri-internals`, `node_modules`, `child_process`, and `Process(` returned
  no text matches, but resource listing still found the pre-existing
  `Epistemos.app/Contents/Resources/experimental-web.tar.gz` artifact.

### Proven

- The bundled editor runtime, not just Swift decoding or synthetic outbound
  injection, accepts a host-issued `applySuggestion` command, creates live
  SuggestionAdapter marks with the MAS June/Epdoc suggestion id, accepts that
  suggestion by id, emits provenance bridge events, and updates editor text.
- The bridge now handles the real load-state race where a suggestion command can
  arrive inside the post-load suppression window without being silently filtered.
- Agent-ingested suggestion transactions are no longer vulnerable to a second
  suggest-changes transform pass in the decorated editor dispatch path.

### Still not done

- This is runtime bridge proof for the note suggestion seam, not full P4
  completion. Still missing: live app ask -> stream -> stage latest suggestion
  -> accept/reject -> provenance -> restart/reload proof, plus explicit undo
  proof.
- P5 dataset flow remains unimplemented: no RECKONER `dataset.*` ->
  `TabularSuggestion` -> `ApprovalGate` -> per-cell/range accept/reject proof
  in this checkpoint.
- P6 release gate remains separate: this pass did not clean the existing
  AppStore artifact debt around parked experimental/Tauri resources; the
  AppStore build still includes `experimental-web.tar.gz`.

## Checkpoint 2026-07-08 MAS-June Epdoc MiniChat Redirect Lock

### Verbatim steer excerpts

Owner redirect:

> MAS-JUNE EPDOC MINICHAT REDIRECT LOCK -- 2026-07-07
>
> I still want the useful Epdoc mini-chat/data-agent pattern, but MAS must not
> import Kindred/1Code. Preserve the product idea: a compact assistant attached
> to Epdoc that can read the current note, selection, vault context, and
> datasets, then propose edits or dataset operations. Rebuild that as MAS-safe
> June/agent_core, not as 1Code, Kindred, Node, terminal, subprocess, or
> companion presence.

MAS pivot:

> Near-term product target is MAS-first sellable Epistemos.
>
> Keep only MAS-safe work active:
> - KEELSTONE: vault truth, file safety, sandbox/bookmarks, App Store target,
> release gates.
> - LUMENLENS: Epdoc/editor fidelity, minimal writeback, provenance, lens
> disclosure/export, notebook manifest, MAS-safe tabs.

### Interpreted intent

The previously-deferred Epdoc minichat idea is now reauthorized only as
`JuneEpdocAssist`: a compact native SwiftUI Epdoc panel/dock/tab that uses the
existing MAS June infrastructure (`JuneAgentGateway`, `JuneSessionStore`,
`GooseMASAgentCoreRunner`, `JuneAgentApprovalRegistry`) and LUMENLENS review
seams. The surface is not a third agent product. It is note-attached context
and review UI for MAS June turns.

### Superseded text

- Supersedes older "Epdoc minichat deferred" language only for the new
  MAS-June assistant seam.
- Supersedes any suggestion that useful 1Code sub-chat UX should be imported
  literally into MAS.
- Supersedes any active Kindred/companion-presence route for note assist.
- Does not supersede the MAS-only lock, the LUMENLENS fidelity/provenance
  constraints, the RECKONER TabularSuggestion/ApprovalGate rules, or KEELSTONE
  vault truth/release gates.

### Still forbidden

- No `.research-clones/1code`, `THE_R_*`, ExperimentalAgent UI polish files, or
  `ExperimentalAgentPolishSourceGuardTests.swift` edits.
- No Kindred runtime, 1Code `sub_chats`, companion presence, tRPC, Node,
  terminal, subprocess, stdio MCP, local server, Tauri runtime, Monaco,
  file-viewer, git client, browser-use, JIT/exec-memory entitlement, or
  `network.server` entitlement.
- No direct note or cell mutation from assistant output. Note edits must stage
  through LUMENLENS suggestions/AI diff and existing save pipeline; dataset
  edits must stage through RECKONER `dataset.*` tools, `TabularSuggestion`, and
  `ApprovalGate`.
- No secrets in JS. Epdoc bridge payloads remain bounded and validated.

### Current source audit facts

- `JuneAgentBridge` already validates bounded invoke/gateway frames, exposes
  native notes read-only, and keeps secrets native-side.
- `JuneAgentGateway` already owns durable sessions, local chat/light-agent
  routing, cloud `agent_core` routing, approval events, model selection, and
  the current `submitEpdocAssist` / latest-suggestion staging seam.
- `JuneSessionStore` persists sessions/messages under Application Support and
  quarantines corrupt JSON instead of overwriting it.
- `EpdocCopilotDockView` is a native compact Epdoc assist shell that dispatches
  editor commands; it does not write files or dataset cells.
- `SuggestionAdapter` and `inbound.ts` now prove host-issued
  `applySuggestion` / `acceptSuggestion` / `rejectSuggestion` commands reach
  the live editor and emit suggestion provenance events.
- `AtomicVaultWriter` is the KEELSTONE whole-buffer atomic persistence seam;
  assistant paths must reach it only through existing explicit save/write
  flows, not by direct blind mutation.

### Acceptance checks for the next batch

- Preserve the existing MAS-safe `JuneEpdocAssist` shell and avoid a parallel
  chat/runtime.
- Add or prove bounded Epdoc context metadata: note id, vault-relative path,
  selected range/text, visible headings, active lens, dataset refs, and
  provenance context.
- Keep local lane honest as chat/light-agent unless a tool grammar is proven;
  cloud lane may use in-process `agent_core` tool events and approvals.
- Prove one safe note flow through staged suggestion/provenance/reload as the
  next LUMENLENS target before claiming P4 complete.
- Do not start P5 dataset edits until the RECKONER `TabularSuggestion` /
  approval seam is audited and the implementation can avoid direct cell writes.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| Existing-vault restart/reload proof | Previous runtime proof stops at live WKWebView suggestion events; owner bar requires restart/reload evidence. | Stage/accept or reject a JuneEpdocAssist note suggestion, persist through existing save/write pipeline, reload/reopen from vault, and verify content plus provenance replay. |
| Context packet bounds tests | Epdoc assist must read useful note/vault/dataset context without leaking unbounded content into JS or model input. | Unit tests for payload caps, selected text/range validation, visible heading extraction, dataset-ref caps, and provenance summary bounds. |
| Dataset flow | P5 remains unimplemented and must not mutate cells blindly. | RECKONER `dataset.*` -> `TabularSuggestion` -> `ApprovalGate` -> per-cell/range accept/reject -> provenance proof. |
| MAS release leak gate | AppStore Debug still contains pre-existing parked experimental resource debt. | AppStore build plus resource/symbol scan after release-gate cleanup. |

### Next action

Audit the current `JuneEpdocAssist` context packet and Epdoc editor chrome
wiring, then make the smallest MAS-safe change that either fills missing
context metadata bounds or proves existing-vault restart/reload for the
note-suggestion path.

## Checkpoint 2026-07-08 MAS Master Canon Intake Pause

### Verbatim steer excerpts

Owner steer:

> Pause before continuing implementation.
>
> A new MAS-only master canon exists at:
> /Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08.zip
>
> Treat MAS-ONLY-SHIP-LOCK-2026-07-07 as the active lock.

Canon `00_READ_FIRST.md`:

> Epistemos is one Mac App Store product.
>
> Active lane:
> - `Epistemos-AppStore`
> - `EPISTEMOS_APP_STORE`
> - `MAS_SANDBOX`
> - MAS/June as the only active agent surface
> - in-process `agent_core`

Canon `05_MAS_JUNE_AGENT_AND_MINICHAT.md`:

> Epdoc MiniChat / Epdoc Assist should be MAS-June owned. It should not be
> Goose, 1Code, Kindred, Node/Tauri, a local server, a subprocess, or a
> separate runtime.

### Interpreted intent

Stop implementation until the MAS master canon is read and the in-flight
LUMENLENS/MAS-June work is checked against it. Continue only if the work remains
inside the MAS June/native/AppKit/SwiftUI/bundled-WKWebView/in-process
`agent_core` architecture with KEELSTONE vault truth and LUMENLENS
suggestion/provenance review paths.

### Hard constraints

- Keep `MAS-ONLY-SHIP-LOCK-2026-07-07` active.
- Priority order is KEELSTONE first, MAS June + Epdoc MiniChat second,
  LUMENLENS + RECKONER fabric third, capability ring fourth, release evidence
  fifth.
- No Pro, Developer-ID, Experimental, 1Code, OpenChamber, Goose runtime,
  Kindred runtime, browser-use/Chromium, terminal/code-exec, stdio MCP, local
  server, subprocess, hidden sidecar, second chat runtime, second transcript DB,
  second tool authority, or second data room as active work.
- Before any future `xcodebuild`, state the exact command.
- Do not delete current work blindly; preserve useful work only by translating
  it into MAS-safe June/native/AppKit/SwiftUI/in-process `agent_core`
  architecture.

### Non-goals

- No further implementation in this checkpoint.
- No KEELSTONE pruning/release-gate implementation until explicitly resumed
  after this canon intake.
- No RECKONER dataset write path until TabularSuggestion/ApprovalGate can be
  implemented without direct cell mutation.
- No MAS release-readiness claim without archive-level evidence.

### Acceptance checks

- New canon read in requested order:
  `00_READ_FIRST.md`,
  `01_OWNER_LOCK_AND_CANONICAL_THESIS.md`,
  `02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`,
  `08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md`,
  `04_KEELSTONE_STORAGE_AND_RELEASE_GATE.md`,
  `05_MAS_JUNE_AGENT_AND_MINICHAT.md`,
  `06_LUMENLENS_RECKONER_WORKSPACE_PLAN.md`,
  `07_CAPABILITY_RING_RESEARCH_CAPTURE_SYNC.md`.
- Status/handoff template read from
  `10_LOCAL_AGENT_REDIRECT_AND_STATUS_TEMPLATES.md`.
- In-flight work checked for forbidden active assumptions.
- Handoff reports branch/worktree, touched files, diff summary, tests/builds,
  verification debt, stale assumptions, and safest next step.

### Current-work canon check

The current in-flight changes do not assume a parked lane as active:

- MAS-June/Epdoc Assist routes through native SwiftUI dock/chrome,
  `JuneAgentGateway`, `JuneSessionStore`, in-process/cloud/local June paths,
  and LUMENLENS `SuggestionAdapter` commands.
- The new focused test exercises KEELSTONE `AtomicVaultWriter` and
  LUMENLENS editor provenance reload proof; it does not add a runtime,
  transcript DB, tool registry, subprocess, local server, 1Code, Goose, or
  Kindred dependency.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| Full MAS canon local verification | The ZIP cannot prove live target flags, entitlements, privacy manifests, archive contents, or release gate state. | Run the exact command blocks in canon docs 08/10 at KEELSTONE/release checkpoint. |
| Handoff before resume | Owner paused implementation and requested a handoff/status before continuing. | Handoff includes files touched, diffs, tests/builds, debt, stale assumptions, and safest next step. |
| Priority realignment | KEELSTONE is priority 1; LUMENLENS/MAS-June is priority 2/3. | Next resumed task explicitly states whether it is KEELSTONE release/storage proof or MAS June/Epdoc Assist proof. |

### Next action

Stop implementation and provide the requested handoff/status. Resume only after
confirming the next task against the MAS master canon and updating the active
checkpoint if the owner steers again.

## Checkpoint 2026-07-08 Existing-Vault Restart Replay Proof

### Verbatim steer excerpts

Active objective:

> Continue LumenLens from the latest L5 runtime gap: prove or harden real
> WKWebView/app-side bridge delivery for minimal writeback and suggestion
> provenance, or move to existing-vault restart replay if live WebKit proof is
> not locally reliable.

MAS master canon:

> LUMENLENS and RECKONER are one workspace fabric. LUMENLENS owns
> note/editor truth, suggestions, provenance, notebooks, and lens-fidelity
> disclosure.

### What changed

- Added `acceptedJuneEpdocSuggestionReloadsFromVaultAndProvenanceAfterRestart`
  in `EpistemosTests/EditorProvenanceStoreTests.swift`.
- The test creates a temporary vault-style note file, writes baseline Markdown
  through `AtomicVaultWriter`, configures `MarkdownDocumentSurfaceCoordinator`
  with an `EditorProvenanceGRDBStore` backed by `SearchIndexService`, simulates
  the accepted June suggestion bridge sequence, flushes the surface writes, and
  then reopens both the note file and the provenance store through a fresh
  `SearchIndexService`.

### Evidence

- After stating the command, ran:
  `xcodebuild test -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-p4-suggestion -only-testing:EpistemosTests/EditorProvenanceStoreTests`
- Result bundle:
  `.derived-data-lumenlens-p4-suggestion/Logs/Test/Test-Epistemos-2026.07.07_21-14-16--0500.xcresult`
- `xcresulttool` summary reported `result: Passed`, `passedTests: 13`,
  `failedTests: 0`, `skippedTests: 0`.

### Proven

- A June-authored accepted Epdoc suggestion can be represented as a LUMENLENS
  suggestion event sequence, flushed through the Markdown document surface,
  persisted to a vault file with `AtomicVaultWriter`, and reloaded from disk.
- Suggestion provenance for that same turn survives a fresh derived-store
  writer/service reopen and preserves author, turn, note path, accepted state,
  before/after text, source citation, and claim ID.
- This proof stays MAS-safe: no second transcript DB, no second tool registry,
  no direct blind mutation, no 1Code/Goose/Kindred runtime, no local server, and
  no subprocess.

### Still not done

- This is a controlled restart/reload proof at the surface/provenance seam, not
  full live app proof. Still missing: real running app ask -> stream -> stage
  latest suggestion -> accept/reject -> provenance -> reload, plus explicit
  undo proof.
- P5 dataset flow remains unimplemented: no RECKONER `dataset.*` ->
  `TabularSuggestion` -> `ApprovalGate` -> per-cell/range accept/reject proof.
- MAS release evidence remains separate and KEELSTONE-priority: target flags,
  entitlements, privacy manifest, archive leak scans, and release-resource
  cleanup are not proven by this checkpoint.

### Verification debt

| Debt | Why it matters | Expected proof |
| --- | --- | --- |
| Live Epdoc Assist proof | Unit/surface tests prove seams, not the running user workflow. | Manual or UI-hosted proof of ask -> stream -> stage -> accept/reject -> provenance -> reload. |
| Undo proof | Owner done bar includes undo and safe reversibility. | Verify accepted suggestion participates in editor undo or provide explicit revert-turn path tied to provenance. |
| Source/leak scan after restart proof | The restart proof touches MAS-June/LUMENLENS seams. | Focused `rg` scan over touched files for parked runtime terms and direct mutation patterns. |
| MAS release gate | New canon makes release evidence a separate blocker. | KEELSTONE/release command blocks from canon docs 08/10. |

### Next action

Run focused source/leak scans over the touched MAS-June/LUMENLENS files, inspect
the diff, and then select the next highest-risk unproven claim under the MAS
master canon.

### Follow-up scan evidence

- `git diff --check` over the touched MAS-June/LUMENLENS files exited 0.
- Source-only `rg` scan over the touched MAS-June/LUMENLENS Swift/TS/test files
  for parked-lane/runtime terms (`Kindred`, `sub_chats`, `1Code`, `THE_R`,
  `ExperimentalAgent`, `OpenChamber`, `ProAgent`, `browser-use`, `Chromium`,
  `terminal`, `stdio MCP`, `local server`, `Node`, `Tauri`, `Process(`,
  `NSTask`, `child_process`, `Monaco`, `Goose runtime`, `Data room`, `second
  transcript`, `second tool`) found no runtime imports or active dependency
  paths. Matches were limited to `ProseMirrorNode` type names and negative
  source-guard assertions in `EpistemosTests/EpdocCopilotSurfaceTests.swift`.
- Direct-mutation scan found the expected `AtomicVaultWriter` use in the
  restart proof test and the existing `saveMarkdown` closure seam in
  `MarkdownDocumentSurface`; it did not find dataset cell writes or blind
  assistant mutation paths in the touched source files.

### Next hardening target

The highest-risk remaining note-flow claim is undo/revert behavior after an
accepted suggestion. Audit the bundled editor history path and add focused proof
that an accepted June/Epdoc suggestion remains reversible without bypassing the
suggestion/provenance ledger.
