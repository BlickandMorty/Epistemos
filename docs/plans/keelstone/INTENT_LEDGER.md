# KEELSTONE Intent Ledger

Date: 2026-07-07
Lane: Keelstone audit and verification evidence only.

## Checkpoint 2026-07-15 — Remove Custom Theme Capability

### Verbatim owner steer excerpt

> "also get rid of the custom theme i still wnat to keep my three preset themes but get rid of custom theme capabilitiy. and the specific onotlgies that come with custm theme"

### Interpreted intent

- Preserve exactly the three current preset pairs: Platinum Violet, Classic, and Ember.
- Remove the editable Custom theme pair and its complete supporting capability: palette-slot model, color pickers, custom previews, typography overrides, cache/notification path, and persistence.
- Treat "ontologies that come with custom theme" as the custom palette-slot ontology (`AppCustomThemeColorSlot`), not the unrelated knowledge-graph ontology.

### Hard constraints and non-goals

- A migrated stored `epistemos.theme.pair = custom` must land safely on Platinum Violet and erase all retired custom-theme keys; it must never leave a half-custom UI.
- Keep the three preset palettes, their typography, the general Font Library preview, and non-theme features named `custom` (such as custom ambient audio) intact.
- Do not touch Graph/OntologyClassifier or user graph-node visibility as they are not part of the visual theme system.
- Preserve concurrent dirty work outside the scoped theme, Settings, tests, and ledger files.

### Acceptance checks and next action

- No Settings route or persisted preference can activate an editable custom palette or heading override.
- `ThemePair.allCases` contains only the three presets and all custom-theme-specific source is absent except one-time preference cleanup.
- Add a fail-first App Store test for legacy migration, the three-preset contract, and Settings absence; then implement, source-scan, and run the focused App Store test leg after resource preflight.

### Hardening checkpoint — 2026-07-15

- Read: MAS pivot and research index, theme resolver, `UIState`, all Settings appearance routes, theme call sites, focused App Store tests, and legacy theme tests.
- Changed: removed the editable Custom pair, `AppCustomThemeColorSlot`, palette persistence/cache/notification code, custom color/font/scale controls, previews, and obsolete custom-only tests. The three supported pairs are Platinum Violet, Classic, and Ember.
- Migration: a persisted `epistemos.theme.pair = custom` becomes Platinum Violet on launch and all retired custom palette, experimental, and heading-override keys are cleared. The graph-domain `OntologyClassifier` and graph-node visibility remain untouched.
- Settings hardening: runtime inspection exposed stale category shells around the already-pruned rows. The sidebar now renders the seven allowed rows directly, without the misleading Capture/Graph/Advanced category shells; Appearance text and search no longer advertise Custom.
- Proven: resource preflight passed before each build (swap 7.0–7.7 GiB, 56–59% free memory, zero throttled pages, no competing compiler/app process). `SettingsSimplificationTests` plus `FreeV1ProductCapabilityPolicyTests` passed 23/23 in `build/xcode-results/2026-07-15-195826-86691.xcresult`; the final rebuilt `SettingsSimplificationTests` passed 4/4 in `build/xcode-results/2026-07-15-201040-97139.xcresult`.
- UI evidence: the final debug app at `build/custom-theme-removal-derived/Build/Products/Debug/Epistemos.app` was opened through Computer Use. Its flat sidebar shows General, Ambient Frequencies, Voice, Landing, Appearance, Vault, and Privacy; Appearance shows exactly Platinum Violet, Classic, and Ember with no Custom theme editor.
- Verification debt: full App Store regression suite was not run for this scoped UI/persistence change. An attempted source-file test guard stalled under the test host, so it was removed rather than retained as a brittle test; source scans, focused behavior tests, and the live visual pass cover this scope. No release-readiness claim is made.

## Checkpoint 2026-07-15 Settings Simplification Directive

### Verbatim owner steer excerpt

> "/goal for the settigns i have a lot of stale thigns so i want you to start deeply pruning the settigns as much as u can. i even see thigns related to the old susbtrate work and failed deferred thignso n the settigns i want to get rid of alot of that stuff please. ... get rid of eco mode as well ... make the perforomance as roust as it can be leae only necessary eprformacne settigs like the memory stuff, and the pro moton should all be maxed out max everythign."

### Interpreted intent

Resume only the Settings simplification leg. Remove user-facing substrate, falsifier, deferred-runtime, and otherwise non-actionable diagnostic material; remove Eco Mode completely and migrate all users to an always-on performance posture. Keep only settings that are an honest, current user choice or necessary safety/recovery information. System Low Power and critical thermal protection remain automatic safety behavior, not a user-facing performance setting.

### Hard constraints

- Preserve the Free V1 / MAS-only boundary: no agent, model, provider, June, RuntimeRouter, or old substrate control may remain reachable through Settings.
- Do not merely hide Eco Mode: stale `epistemos.ecoMode` values must no longer slow background work, and the legacy preference must be cleared.
- Do not remove safety reactions to system Low Power mode or critical thermal pressure.
- Keep user-meaningful non-AI settings such as vault/session/privacy/appearance/voice and retention controls.
- Preserve the dirty worktree and edit only the scoped source/tests/ledger after reading each file.

### Non-goals

- No broad deletion of diagnostic implementation, historical research, or compatibility decoders in this first Settings batch.
- No new performance tuning UI, model/runtime work, or App Store release claim.
- No Xcode work without the required resource preflight and one-current-artifact discipline.

### Acceptance checks

- Settings has no selectable Foundation/substrate panel, no stale deferred diagnostics block, and no runtime-lane control.
- Eco Mode and its legacy persisted preference no longer determine app behavior; first launch and migrated installs start in full-performance mode unless macOS itself declares Low Power or critical thermal state.
- Deferred startup/idle toggles are removed rather than shown as unwired preferences.
- Graph defaults prefer maximum frame pacing/quality, while memory pressure and macOS safety signals can still protect the machine.
- Focused settings/power tests and source guards pass; current broader build/runtime evidence is recorded separately.

### Next smallest safe action

Add a focused fail-first Settings simplification guard, then remove the stale Settings controls and migrate the power policy.

### Owner steer update — thermal defaults

#### Verbatim owner excerpt

> "the thermal stuff as well i want to be uncapped by default ad the user can set it if they please or just get rid of the control because i want the app to appear as high performace as possibel"

#### Updated interpretation and action

- Do not expose a thermal, Eco, frame-cap, or performance-mode control in Settings.
- Ignore retired user frame and thermal throttling preferences at launch; graph frame pacing and quality launch at their maximum-performance defaults.
- Preserve only the non-configurable emergency response to macOS Low Power mode or a *critical* thermal state. It is not a Settings control and cannot leave the app permanently throttled from stale preferences.

### Hardening checkpoint — 2026-07-15

- Read: MAS pivot/current canon, Settings, PowerGuard, GraphState, MetalGraphView, memory control, call sites, and focused test target.
- Changed: visible Settings now contains only the current Free V1 categories; legacy links route to General. Removed the Foundation panel route, diagnostics/deferred-runtime block, Eco Mode, unwired performance settings, and Settings-level graph frame controls. Kept one user-actionable Memory section with an idle-cache release action.
- Performance policy: removes saved Eco, render-mode, FPS-cap, and force-FPS keys at startup; starts responsive/uncapped with maximum graph quality and ProMotion request. Low Power Mode and *critical* thermal state remain automatic emergency-only fallbacks.
- Proven: the focused three-test leg passed in `build/xcode-results/2026-07-15-193627-71525.xcresult`; the final current artifact `build/settings-simplification-td0-derived/Build/Products/Debug/Epistemos.app` then passed all 22 tests from `SettingsSimplificationTests` and `FreeV1ProductCapabilityPolicyTests` in `build/xcode-results/2026-07-15-194051-76266.xcresult`. The runtime log reports `PowerGuard ... mode: Full`.
- UI evidence: the rebuilt debug app launches. The computer-use accessibility bridge timed out while navigating to Settings; a direct window capture confirmed the app launch but not the Settings panel. Source-level reachability and focused runtime tests cover the visual surface pending a stable UI-automation pass.
- Remaining verification debt: the full App Store suite and a direct visual Settings walkthrough; neither is required for this scoped behavior change to be source/test proven, and neither is a release-readiness claim.

## Checkpoint 2026-07-07 Owner Steer

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Do not discard current work and do not restart the plan. Pause implementation long enough to reconcile state, then continue the forever loop deliberately.
>
> Important: Keelstone audit and LumenLens implementation are two separate lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> Before editing again, write/update an intent checkpoint with:
> - my verbatim steer or exact excerpt
> - interpreted intent
> - hard constraints
> - non-goals
> - current Keelstone audit status
> - current LumenLens implementation status
> - contradictions/questions
> - next smallest safe action
>
> For Keelstone: audit the work against the plan's actual done bars. Say what is proven, what is not proven, what evidence exists, what evidence is missing, and what remains verification debt.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.

### Interpreted intent

Continue the existing Keelstone audit without restarting, but downgrade any broad completion claim to the actual evidence. Keep Keelstone as an evidence lane: prove, record, or defer against the plan bars without pulling in LumenLens implementation scope.

### Hard constraints

- Read AGENTS.md, CLAUDE.md, Keelstone plan and prompt, LumenLens plan and prompt, active notes, and current diff before more edits.
- Never run competing xcodebuild jobs.
- Do not revert unrelated dirty work.
- Treat source guards, targeted tests, app-lane tests, built-app gates, perf measurements, and manual/runtime soaks as separate evidence classes.
- Keep verification batching explicit with commands, touched files, risk reason, expected proof, and checkpoint trigger.
- Do not claim Keelstone done because a targeted suite or source scan passed.

### Non-goals

- Do not implement LumenLens behavior in this lane.
- Do not clean unrelated docs, research files, or generated assets.
- Do not delete non-source archival artifacts such as the root `pro-agent-screenshots` directory without owner direction.
- Do not broaden Keelstone into KINDRED, RECKONER, SIGILRY, LODESTAR, or EMBERCATCH implementation.

### Current Keelstone audit status

- Phase 0: source-level retired-surface scan is clean across guarded paths. Evidence: `rg -n "OpenChamber|openchamber|ProAgent|PRO_BUILD|pro-agent" Epistemos project.yml scripts .github EpistemosTests build-*.sh` returned no matches; release gate retired-surface section passed; AppStoreHardening source guard passed.
- Phase 1: targeted durable-write proof passed. Evidence: AppStoreHardening kill-9 replacement test ran in the 53-test suite and passed.
- Phase 2: FSEvents replay/escalation tests passed in AppStoreHardening.
- Phase 3: reconcile convergence test passed in AppStoreHardening.
- Phase 4: dirty external-edit conflict path guard passed in AppStoreHardening.
- Phase 4.5: file-first body-truth source guards and targeted NoteEditor/Epdoc guards passed, but Finder/vim live E2E and legacy body migration fixture evidence remain missing.
- Phase 5: search-index corruption quarantine and rebuild tests passed in AppStoreHardening.
- Phase 6: source residue, macro/build wiring, and App Store lane evidence are strong, including `EpistemosAppStoreKeelstoneTests` pass. Full Swift/Xcode suite remains missing.
- Phase 7: seeded HIGH hardening failure, seeded perf-regression failure, and 100-cycle child cleanup passed. Real Keelstone perf measurement JSON is still missing.
- Phase 8: source-level release gate passed. Built-app entitlement gates, release artifact scan, broad data-safety soak, and full first-run/upgrade matrix remain verification debt.

### LumenLens status, kept separate

LumenLens implementation is active but not evaluated as Keelstone proof. Keelstone only records the dependency boundary: Keelstone 0-4 have targeted evidence sufficient to continue LumenLens carefully, while Keelstone 6-8 still require broader release evidence before any ship claim.

### Contradictions/questions

- The plan checkboxes are still unchecked even where targeted evidence exists. This is correct until the missing broad bars are proven.
- The source-level retired-surface gate excludes historical docs and some non-source artifacts by design; that is not the same as whole-repo textual absence.
- Phase 4.5 has strong source evidence but not all owner-visible live-editor evidence.

### Next smallest safe action

Update `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md` with the latest AppStoreHardening 53-test pass, App Store lane pass, and remaining debt; then continue LumenLens work in its separate ledger.

## Verification Debt

| Deferred command | Touched files/surfaces | Risk reason | Expected proof | Checkpoint trigger |
|---|---|---|---|---|
| `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-lumenlens-l6` | Shared Swift app/tests, body-truth, AppSurface, editor sessions | Phase 6 requires full suite green; targeted suites may miss cross-test regressions | Full Epistemos scheme test pass | Before any Keelstone Phase 6/8 completion claim or after next shared Swift batch |
| `./scripts/keelstone-release-gate.sh --appstore-app <Epistemos.app>` and `./scripts/keelstone-release-gate.sh --direct-app <Epistemos.app>` | Release gate, entitlements, bundle scan paths | Source gate cannot prove final app entitlements or packaged residues | Both built-app gate invocations pass | Next archive/release checkpoint |
| `./scripts/check-perf-budgets.sh` with real `build/perf-budgets-keelstone.json` | Perf budgets and measurement producer | Seeded failures prove parser behavior, not actual 10k/100k envelope performance | Real measurement file parsed and budgets pass | Phase 7 perf checkpoint |
| Final App Store artifact scan against produced Release bundle | AppStore target, resources, binary strings/symbols | Source scan can miss packaged resources or linked symbols | Scan passes on produced app | Release-lane checkpoint |
| External editor E2E: Finder/vim edit against live vault | Note save/load, FSEvents, conflict flow | Phase 4.5 needs owner-visible external edit behavior, not only source guards | Clean editor reloads; dirty editor conflicts; in-app edit visible in `.md` | Next body-truth runtime checkpoint |
| Legacy body migration fixture run | `NoteFileStorage`, `SDPage.body`, vault `.md` migration | Zero-loss migration from pre-collapse state remains unproven in this pass | Legacy `note-bodies` and `SDPage.body` open with no loss and no dual-write | Body-truth broad checkpoint |
| Release-style soak: external storms, sync races, random kill-9 boundaries | Vault sync, AtomicVaultWriter, index reconcile | Targeted kill-9 and convergence tests do not equal full release soak | Full rescan equals clean rebuild after each soak | Phase 8 checkpoint |

## Checkpoint 2026-07-09 MAS Base-App Completion Lock And Owner-Visible Blockers

### Verbatim steer excerpt

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

> voice still doesnt work so add that to known issues

> remember the main issues were the loading of epdoc, and also switchign fromotehr surfaces to epdoc and from epdoc meses up epdoc's formatting that should not happen ans the other issues are the voice is not in english ... graph embedded and hologram graph when i go to ndes it takes a long time ... june mas still is not rlly working it is not producing outputs

### Interpreted intent

The current lane is MAS-only Prompt 2. Broad edits are allowed when needed to resolve the product blockers, but the proof target remains the exact App Store product reality: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`, and the normal/base `Epistemos` scheme mapping to MAS/June. Owner-visible bugs outrank feature work: voice must speak English through Kokoro, June send must work without prompt-upgrade/Hermes drift, Epdoc must preserve rich formatting across surface switches, and graph/editor surfaces must stop hanging.

### Hard constraints

- Do not use the old 1Code/Experimental objective or scope rules.
- Do not count stale `goosed`, OpenChamber, ExperimentalWeb, debug DerivedData, node/dev-server, or local subprocesses as MAS evidence.
- Runtime proof must use the exact archived AppStore app path when claiming owner-visible behavior.
- Legacy lanes may be deleted or quarantined after inventory; they are not product lanes to preserve.
- Keep useful shared code only through MAS-safe in-process seams.

### Non-goals

- No Prompt 3 claim until Prompt 2 base-app ambiguity, MAS archive contents, vault restore/save, voice, June send, and editor/graph/Epdoc blockers are either fixed or logged as exact high blockers with next commands.
- No Apple AVSpeech fallback unless the owner explicitly changes the Kokoro-only policy.
- No broad dirty-state staging/commit in this checkpoint.

### Current evidence and findings

- Exact AppStore archive proof and base scheme mapping have been generated in the durable Prompt 1/2 checkpoint file.
- Exact archive relaunch restored the selected Kimi vault and wrote a non-nil vault path in `.epcache/diagnostics/crash-recorder-ready.json`; live save-path proof remains debt.
- Kokoro package exists in the MAS container at `~/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro/kokoro-82m-coreml`.
- Current MAS defaults show `EPISTEMOS_KOKORO_VOICE_PRO_V0 = 1`, global Kokoro voice `af_bella`, and read-aloud effect `pixelArt`. The installed Kokoro voices are English voice packs (`af_*`, `am_*`, `bf_*`), so the "not English" owner report is most likely distorted English from the persisted effect or an unsafe voice/effect routing bug, not a non-English model.

### Contradictions/questions

- Source guards already assert visible read-aloud wiring, but the owner-visible voice still fails. Treat guard coverage as insufficient until exact archive preview/read-aloud logs and audible/manual proof pass.
- Some graph/editor source guards assert performance policies, but the owner still observes hangs. Treat performance as open until real app interactions and profiling prove otherwise.

### Next smallest safe action

Patch Kokoro read-aloud to enforce a clean English MAS default and reject/repair unsafe voice/effect routing; add regression coverage that an existing distorted effect preference cannot silently make MAS voice preview/read-aloud sound non-English. Then run focused MAS tests before the next archive rebuild.

## Checkpoint 2026-07-09 Owner Broad-Edit Permission For MAS Prompt 2

### Verbatim steer excerpt

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

### Interpreted intent

The active lock remains MAS-only Prompt 2 / Keelstone, but the agent should stop treating broad dirty-state caution as a blocker. If the shortest safe path to one MAS/June product reality requires pruning stale app registrations, deleting generated/debug artifacts, quarantining legacy targets, or touching broad project/source ownership, proceed after inventory and source grounding.

### Hard constraints

- Proof target remains `Epistemos-AppStore` with `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.
- Normal/base launch must resolve to the same MAS/June product reality, not stale Debug/DerivedData/cache apps and not 1Code/OpenChamber/Experimental.
- Stale `goosed`, OpenChamber, ExperimentalWeb, opencode, node/local-server, debug DerivedData, and old app processes remain invalid MAS evidence.
- Voice must be English Kokoro-only unless the owner explicitly changes policy.
- Vault restore/save, June send, Epdoc fidelity/performance, graph/editor hangs, and base-app ambiguity remain Prompt 2 blockers until fixed or logged with exact next actions.

### Non-goals

- Do not preserve 1Code/OpenChamber/Goose runtime/ExperimentalWeb as product lanes merely because older docs mention inventory-before-delete.
- Do not claim Prompt 3 readiness while the owner-visible MAS blockers remain open.

### Current verified evidence

- Latest AppStore archive after English/clean voice routing succeeded: `build/appstore-release-archive-2026-07-09-voice-english-clean-20260709-153639.xcarchive/Products/Applications/Epistemos.app`.
- Latest release gate passed for that exact archive and verified `JuneWeb/dist/index.html`, `JuneWeb/tauri-internals-shim.js`, MAS entitlements, AppStore compile conditions, and no prohibited runtime/resource residue.
- Latest bundle scan report path: `build/visible-mas-proof-2026-07-09-voice-english-clean-20260709-153639`.
- Exact archive PID `11804` launched from the archive path with bundle id `com.epistemos.appstore`; screenshot evidence showed June/MAS loaded with no missing-bundle panel or vault warning.
- Generic app activation accidentally launched stale Debug app PID `11614` from `/Users/jojo/.cache/epistemos-dd-codex-kokoro-tiers-mas/Build/Products/Debug/Epistemos.app`, proving LaunchServices/base-app ambiguity is still a real Prompt 2 blocker even though that PID is not archive evidence.

### Verification debt

- Runtime voice preview/read-aloud proof from the exact archive is still missing; source/tests/archive proof are insufficient.
- Base LaunchServices cleanup must prove generic owner launch no longer resolves to stale Debug/cache apps.
- Exact archive vault save proof must show no `no vault URL` after relaunch.
- June send must produce visible output or a clear MAS-safe configuration/status error, with prompt-upgrade/Hermes drift removed from the shipped path.
- Epdoc/graph/editor performance and formatting/fidelity regressions need source fixes plus targeted tests and runtime profiling/screenshots.

### Next smallest safe action

Inventory and repair normal/base app resolution so a generic owner launch opens the MAS archive/product path instead of stale Debug/cache builds; then resume exact-archive runtime proof for voice and vault before moving deeper into editor/graph fixes.

## Checkpoint 2026-07-07 Re-anchor After Context Transition

### Verbatim steer excerpt

> Steer: before any next edit, re-anchor to the updated instruction profile.
>
> Do not discard current work and do not restart the plan. Pause implementation long enough to reconcile state, then continue the forever loop deliberately.
>
> Important: Keelstone audit and LumenLens implementation are two separate lanes. Do not let evidence, TODOs, or assumptions bleed between them.
>
> For Keelstone: audit the work against the plan's actual done bars. Say what is proven, what is not proven, what evidence exists, what evidence is missing, and what remains verification debt.
>
> For testing/building: do not spam full builds every tiny edit. Keep a verification-debt ledger with deferred command, touched files, risk reason, expected proof, and checkpoint trigger.

### Interpreted intent

After the context transition, keep Keelstone in audit mode only. Do not restart
or rewrite the already gathered evidence. Reconcile the current source/tests
against the plan's real done bars, keep all release-sized proof gaps explicit,
and continue LumenLens implementation in its own lane.

### Hard constraints

- Do not treat LumenLens tests, ledgers, or code as Keelstone completion proof.
- Do not mark any Keelstone phase done unless the plan's behavioral bar is met.
- Keep source-level gates, targeted Swift tests, built-app checks, perf
  measurements, manual/runtime tests, and release soaks as separate evidence.
- Batch broad `xcodebuild`/release checks at meaningful checkpoints; never run
  competing `xcodebuild` jobs.
- Preserve unrelated dirty work and generated artifacts.

### Non-goals

- No Keelstone implementation batch in this checkpoint.
- No deletion of historical/non-source artifacts solely to satisfy source scans.
- No broad release-ready claim.
- No absorption of LumenLens, KINDRED, RECKONER, or Experimental renderer scope.

### Current Keelstone audit status

Proven with targeted evidence: retired-source scan on guarded source paths,
source-level release gate pass, seeded HIGH failure, perf parser pass and
seeded regression failure, AppStoreHardening 53-test lane, NoteEditorLayout
guard updates, EpdocVisibility file-first/body-truth guards, and the dedicated
App Store Keelstone test lane. Not proven: full Swift/Xcode suite, built-app
entitlement gates, produced Release artifact scans, real Keelstone perf JSON,
external editor E2E, legacy body migration fixture, broad data-safety soaks,
and full first-run/upgrade matrix.

### Current LumenLens implementation status

LumenLens has separate local evidence for L0-L6 narrow units and an active L2
dataset export seam. That evidence is not Keelstone proof. The only Keelstone
dependency read is that targeted Phases 0-4 evidence is sufficient for careful
local LumenLens batches, while release debt remains in this ledger.

### Contradictions/questions

- Phase 4.5 source guards are strong, but owner-visible runtime/migration legs
  remain open.
- Phase 7/8 gates exist in source form, but real artifact/perf/soak evidence is
  still missing.
- The plan checkboxes remain conservative by design; targeted passes do not
  equal plan completion.

### Next smallest safe action

Leave Keelstone unchanged and continue the LumenLens L5 durable provenance seam
read. Add or update Keelstone debt only if new Keelstone evidence is generated.

## Checkpoint 2026-07-09 MAS Archive/Base Launch/English Voice Proof

### Verbatim steer excerpt

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

> im asking am i able to do english or how does that shit work

## Checkpoint 2026-07-09 Epdoc Blanking Regression Reopened Again

### Verbatim steer excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Interpreted intent

Epdoc blanking is the active Prompt 2 blocker. Source guards and prior focused AppStore tests are not sufficient because the owner can still reproduce a visible blank document when opening Epdoc or switching between Epdoc and other surfaces. The fix must protect the real MAS/June app path from empty editor echoes, empty lens snapshots, and remount/load races that can erase or hide rich Epdoc content.

### Hard constraints

- Stay in the MAS-only lane: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`.
- Do not count stale Debug/DerivedData apps, stale processes, local servers, or Experimental/OpenChamber/goosed runtime as proof.
- Do not move to Prompt 3 while the visible Epdoc blanking path is still reproducible or unproven.
- Treat a blank-on-open or blank-on-surface-switch as data-loss/release risk even if persisted bytes are still recoverable.

### Non-goals

- Do not mask blanking with a placeholder panel.
- Do not downgrade Epdoc to a plain Markdown copy path that loses tables/rich formatting.
- Do not claim fixed from tests only; exact archive runtime proof remains required after source changes.

### Acceptance checks

- Switching into Epdoc from Prose/Source/Graph-owned routes renders the existing non-empty document, including rich table/formatting state where present.
- Switching away from Epdoc and back does not save or snapshot an empty body over a non-empty source.
- WebKit initial empty bridge messages are ignored or retried without changing the host source of truth.
- Focused AppStore Epdoc tests pass, then the AppStore archive rebuilds, release gates pass, and exact archive launch/manual proof shows Epdoc content instead of a blank surface.

### Next smallest safe action

Re-read the host lens-switch/writeback path plus the JS editor load-state/outbound bridge path, then patch the missing lifecycle edge that still allows a non-empty Epdoc source to render or persist as blank.

### Evidence update

- Root cause class found in source: `EpdocTiptapWebView.Coordinator.webViewWebContentProcessDidTerminate(_:)` intentionally left the editor as a dead blank view and told the user to reopen the note. Under graph/editor memory pressure or surface switching, that can reproduce the owner-visible blank even when persisted Markdown is still non-empty.
- Patch: `EpdocEditorChromeController.prepareForWebContentProcessRecovery()` now preserves the latest non-empty Markdown snapshot, advances the load epoch, re-arms the host load, and reloads `epistemos-doc:///editor.html` so the next `editorReady` pushes the host Markdown source instead of an empty editor.
- MAS test command passed: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-recovery-appstore-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRecoversEpdocAfterWebKitBlankingWithLastMarkdownSource()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho()'`.
- Result bundle: `build/xcode-results/2026-07-09-182347-17745.xcresult`.
- Result: `** TEST SUCCEEDED **`; Swift Testing reported 3 AppStore Keelstone tests passed. The compile line included `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`.
- Non-MAS test debt: `EpistemosTests/EpdocEditorBridgeTests.swift` now has a matching bridge regression, but `EpistemosTests` is only wired into `Epistemos-LegacyDev`; `Epistemos` and `Epistemos-AppStore` schemes currently include `EpistemosAppStoreKeelstoneTests` only. Do not count LegacyDev as MAS proof.

### Next smallest safe action

Rebuild the exact `Epistemos-AppStore` Release archive, run release gates/scans on the produced app, then launch the exact archive for owner-visible Epdoc proof.

### Interpreted intent

Broad edits and cleanup are allowed, but the proof chain remains MAS-only. The normal app the owner opens must resolve to the App Store MAS/June product, and voice must prove an English Kokoro path from the exact archived app instead of source guards or stale Debug evidence.

### Archive/build evidence

- Command completed: `./scripts/xcodebuild_epistemos.sh archive -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build/appstore-release-archive-derived-2026-07-09-voice-launch-proof-20260709-160246 -archivePath build/appstore-release-archive-2026-07-09-voice-launch-proof-20260709-160246.xcarchive CODE_SIGNING_ALLOWED=YES`.
- Result: `** ARCHIVE SUCCEEDED **`.
- Exact archived app: `build/appstore-release-archive-2026-07-09-voice-launch-proof-20260709-160246.xcarchive/Products/Applications/Epistemos.app`.
- Built bundle id: `com.epistemos.appstore`.
- Active compile flags observed in archive output: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`; no `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED` observed for the AppStore target.

### Gate/scan evidence

- Release gate passed: `./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-voice-launch-proof-20260709-160246.xcarchive/Products/Applications/Epistemos.app`.
- Bundle scan passed: `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-voice-launch-proof-20260709-160246 ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-voice-launch-proof-20260709-160246.xcarchive/Products/Applications/Epistemos.app`.
- Scan report path: `build/visible-mas-proof-2026-07-09-voice-launch-proof-20260709-160246`.
- JuneWeb archive proof: `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js` are present.
- Release gate and scan both report no prohibited runtime/resource residue for ExperimentalWeb, 1Code, OpenChamber, goosed, opencode, codex, node, bun, rg, or experimental-runtime inside the MAS app bundle.

### Normal/base app proof

- Installed exact archive to `/Applications/Epistemos.app` with `/usr/bin/ditto`, after quitting `Epistemos` and unregistering stale Debug/cache/archive app registrations.
- Codesign result: `/Applications/Epistemos.app: valid on disk` and `satisfies its Designated Requirement`.
- Installed bundle id: `com.epistemos.appstore`.
- Exact path launch: `open -n /Applications/Epistemos.app` produced PID `20008`, path `/Applications/Epistemos.app/Contents/MacOS/Epistemos`, bundle `com.epistemos.appstore`.
- Bundle id launch: `open -b com.epistemos.appstore` produced PID `20040`, path `/Applications/Epistemos.app/Contents/MacOS/Epistemos`, bundle `com.epistemos.appstore`.
- Normal owner launch: `open -a Epistemos` produced PID `20059`, path `/Applications/Epistemos.app/Contents/MacOS/Epistemos`, bundle `com.epistemos.appstore`.
- Visible screenshot proof from the installed MAS app: `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_16-12-29-w53213.png`, `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_16-12-29-w53217.png`, `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_16-12-29-w53215.png`. Screenshots show the MAS app surfaces loaded, not the missing Workspace bundle panel.

### English Kokoro runtime proof

- Exact launch command: `open -n /Applications/Epistemos.app --args --epistemos-run-kokoro-proof-on-launch`.
- Launched PID `20162`, path `/Applications/Epistemos.app/Contents/MacOS/Epistemos`, bundle `com.epistemos.appstore`.
- Readiness log: `Kokoro readiness context=launch-voice-proof gateResolved=true modelRoot=/Users/jojo/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro manifestValid=true KokoroPipelineLinked=true isTextToSpeechAvailable=true`.
- Evidence log: `modelPackages=22 voices=7 runtimeAssets=2 manifestFiles=75 declaredBytes=987229282`.
- English proof request log: `Kokoro launch proof requested phraseLanguage=en`.
- TTS queue/render/playback logs: `Kokoro TTS queued chars=46 effect=clean`, `Kokoro TTS render started ... voice=af_bella`, `Kokoro TTS render finished ...`, and `Kokoro TTS playback started ... playerPlaying=true`.
- No `Kokoro TTS failed`, `Startup integrity warning`, `missing or unreadable`, `Workspace bundle is missing`, `no vault URL`, or `Cannot save page body` lines appeared in the proof log filter.

### Runtime/process classification

- Active MAS proof process is `/Applications/Epistemos.app/Contents/MacOS/Epistemos --epistemos-run-kokoro-proof-on-launch`.
- No active `goosed`, OpenChamber, ExperimentalWeb, opencode, bun, experimental-runtime, or local-server dependency was present in the process scan.
- Numerous `node headless/dist/index.cjs` and Codex node processes are Codex/tooling leftovers and are not MAS evidence or MAS dependencies.

### Dirty file grouping snapshot

- MAS-safe/product files: AppStore plist/entitlements, `project.yml`, Xcode project/schemes, App/June/Voice/Vault/Graph/Epdoc/Notes views, MAS gate/scan scripts, AppStore/voice/vault/editor tests.
- Shared substrate: `agent_core`, `epistemos-core`, `LocalPackages/KokoroPipeline`, shared Rust/build scripts, shared storage/editor/graph source.
- Parked-lane/legacy: ExperimentalAgent, Goose direct-lane files, Work/OpenCode/MCP/VaultMCP guarded files, legacy scheme/docs/provenance files.
- Generated/build artifact: `build/*` evidence, `syntax-core/target/*`, compressed editor resources, generated archive/scan outputs.

### Remaining Prompt 2 blockers

- Vault exact-archive save proof still needs a real note/body save after relaunch with no `no vault URL`.
- June MAS send still needs visible output or a clear MAS-safe status/error; prompt-upgrade/Hermes drift must stay removed from the shipped path.
- Epdoc rich formatting must survive surface switches; Epdoc load/edit latency still needs profiling and fixes.
- Graph embedded/hologram node transitions and editor typing hangs remain owner-visible performance blockers.
- Code editor view-only/editability issue remains open.

### Next smallest safe action

Keep the installed MAS archive as the normal/base app proof, then move to the next owner-visible blocker in Prompt 2: start with source/runtime diagnosis of June send and prompt-upgrade drift, while keeping vault save proof and Epdoc/graph/editor performance on the verification ledger.

## Owner Steer 2026-07-09 Broad MAS Authority

### Verbatim steer excerpt

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

### Interpreted intent

The MAS Prompt 2 completion lock overrides narrow caution about broad dirty state. Broad source, project, generated-web, gate, and legacy-quarantine edits are allowed when they materially move the MAS App Store product toward one active June reality.

### Hard constraints

- Keep validation MAS-only: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`, and exact archived or installed MAS app paths remain the proof lane.
- Do not treat stale Debug, goosed, OpenChamber, ExperimentalWeb, or cached DerivedData processes as product evidence.
- Do not preserve 1Code/OpenChamber/Goose/Experimental runtime lanes merely because they exist; inventory ownership first, then quarantine/delete where safe.
- Do not move past Prompt 2 while base-app ambiguity, June send failure, vault restore/save loss, voice English/read-aloud failure, Epdoc formatting/performance loss, graph/editor hangs, or code-editor editability remain unclassified.

### Current acceptance checks

- June MAS send either produces output or surfaces a clear MAS-safe configuration/status error; per-message prompt upgrade/Hermes drift is removed from the shipped path.
- Vault restore/save survives exact MAS app relaunch without `no vault URL`.
- Kokoro voice remains English by default and read-aloud wiring is product-real, not just button presence.
- Epdoc preserves rich tables/formatting across surface switches and avoids main-thread load/edit hangs.
- Graph embedded/hologram node transitions do not stall editor load or typing.
- Normal/base owner launch continues to resolve to the MAS App Store app.

### Next action

Patch June model/default and bridge drift first, rebuild the JuneWeb bundle if shipped web assets change, then move into Epdoc/editor/graph performance fixes with targeted tests and MAS archive proof at the next meaningful checkpoint.

## Checkpoint 2026-07-09 Epdoc/Editor Hot-Path MAS Guard

### Verbatim steer excerpt

> remembr the main issues were the loading of epdoc, and also switchign fromotehr surfaces to epdoc and from epdoc meses up epdoc's formatting that should not happen

> graph embedded and hologram graph when i go to ndes it takes a long time to lead them up and when i edit anythign in the graph hologram or embedded graoh they hang

> it also wont let me edit on code editor at all for some reason it just has me view it

### Interpreted intent

Treat editor latency, Epdoc surface-switch fidelity, graph-to-editor stalls, and read-only editor drift as Prompt 2 MAS release blockers, not polish. Keep proof on `Epistemos-AppStore` with `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.

### Source changes in this checkpoint

- `Epistemos/Views/Notes/EpdocNotebookManifest.swift`: bounded notebook-manifest scanning so ordinary large Markdown bodies do not scan/allocate the whole note while deciding whether Epdoc tabs exist.
- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`: added active/hidden state to the rich document surface; clean same-page markdown churn no longer remounts the rich editor, while hidden surfaces reload once on reactivation if another lens changed the source.
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`: retains the Epdoc document surface across source/prose/document switches when the note supports Document mode, hiding it instead of destroying it during simple lens switches.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` and shared editor tests: added MAS guards for bounded parsing, no same-page remount, hidden reactivation reload, and surface-switch hot paths.

### Verification evidence

- Failed pre-patch compile check: `build/xcode-results/2026-07-09-164056-27158.xcresult`; failure was stale test coordinator calls missing the new `isActive` argument.
- Passing MAS focused command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-editor-hotpath-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneBoundsEpdocNotebookManifestParsingOnLargeNormalNotes()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'`
- Result: `** TEST SUCCEEDED **`; Swift Testing ran 5 tests, 5 passed.
- Result bundle: `build/xcode-results/2026-07-09-164539-28169.xcresult`.
- Compile flags observed in the passing log include `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

### Remaining verification debt

- Exact Release MAS archive rebuild/rescan/relaunch after these source changes.
- Manual Epdoc proof on the installed/archive app: rich tables and formatting survive switching from other surfaces into Epdoc and back.
- Graph embedded/hologram route proof: opening node editors and typing no longer stalls.
- Code editor editability proof: code editor allows editing when the selected note should have an editable lease.

### Next action

Investigate the code-editor read-only path and graph embedded/hologram node transition path next. The likely shared risk is note-session lease/editability state plus expensive editor/outline work on route transition.

## Checkpoint 2026-07-09 Graph Editor Lease Handoff

### Interpreted intent

The owner-reported “code editor only lets me view” issue is a MAS release blocker when it happens from graph embedded or hologram node routes. The fix must not allow two dirty writers for the same note.

### Source changes in this checkpoint

- `Epistemos/Views/Notes/NoteSessionStateMachine.swift`: the lease registry now tracks live session objects, can transfer a lease from a clean active owner, refreshes all live sessions for that note after transfer, and still blocks dirty/autosaving/conflict owners.
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`: graph-embedded note routes attempt a clean lease handoff after opening; normal note windows retain the prior conservative follower behavior.
- `EpistemosTests/NoteSessionStateMachineTests.swift`: added clean active handoff and dirty-owner block regression tests.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: added MAS-lane executable tests and source guards for graph embedded clean handoff.

### Verification evidence

- Passing MAS focused command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-editor-hotpath-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneLetsGraphEmbeddedEditorTakeCleanActiveLease()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneBlocksGraphEmbeddedEditorWhileOwnerIsDirty()'`
- Result: `** TEST SUCCEEDED **`; Swift Testing ran 3 tests, 3 passed.
- Result bundle: `build/xcode-results/2026-07-09-165124-29367.xcresult`.

### Remaining verification debt

- Exact archive/manual proof that graph embedded and hologram note/code editor routes are editable when no dirty owner blocks them.
- Confirm dirty-owner conflict is visible enough for the user instead of silently looking like an inert editor.
- Continue graph route performance work: opening a node should not run inspector/profile/summarization work on the hot path.

## Checkpoint 2026-07-09 Graph Route Hot-Path Guard

### Interpreted intent

Opening nodes from embedded graph or hologram graph must not keep graph inspector/profile/summarization work alive on the editor route hot path. Graph surfaces should hand off cleanly to MAS-owned editor surfaces instead of competing with them during load and typing.

### Source changes in this checkpoint

- `Epistemos/Graph/GraphState.swift`: note and folder node routes clear graph selection before pushing the note/folder route, preventing selected-node inspector work from remaining active while the editor loads.
- `Epistemos/Views/Graph/HologramOverlay.swift`: leaving the canvas route now clears graph selection and the inspector state after pausing overlay physics/Metal rendering.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: expanded the graph startup MAS guard so it checks selection/inspector cleanup in the route transition path.

### Verification evidence

- Passing MAS focused command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-editor-hotpath-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()'`
- Result: `** TEST SUCCEEDED **`; Swift Testing ran 1 test, 1 passed.
- Result bundle: `build/xcode-results/2026-07-09-165526-30350.xcresult`.
- Compile flags observed in the passing log include `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

### Remaining verification debt

- Run a broader combined MAS focused suite for Epdoc, graph routing, graph editability, and voice guards after the English voice patch.
- Exact Release MAS archive rebuild/rescan/relaunch after the next meaningful source checkpoint.
- Manual graph proof on the archive app: open nodes from embedded graph and hologram graph, then type in code/prose/Epdoc without stalls.

## Checkpoint 2026-07-09 Kokoro English Voice Policy

### Verbatim steer excerpt

> the voice is not in english i need it to be in english if it is not an english model then idk why we are even using it

> im asking am i able to do english or how does that shit work

### Interpreted intent

Kokoro itself is acceptable only if MAS read-aloud speaks English by default and cannot silently drift to a non-English installed voice. English voice proof must be tied to the exact AppStore/MAS target, not a generic settings claim.

### Source changes in this checkpoint

- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`: added an English-only installed Kokoro catalogue; `speak()` now resolves to an English Kokoro voice every time and logs `Kokoro TTS voice resolved requested=... selected=... englishOnly=true`. If no explicit/global English voice is valid, it selects `af_heart`.
- `Epistemos/Views/Shared/ModelVoicePickerSection.swift`: the shipped picker now lists English Kokoro voices only and labels the nil/default row as `English default`.
- `EpistemosTests/KokoroVoiceSelectionTests.swift`: added coverage for English-only catalogue filtering and the `af_heart` fallback.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: expanded the AppStore Kokoro guard to require the English-only picker, resolved-voice log, and fallback behavior.

### Verification evidence

- Mixed-target attempt:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-editor-hotpath-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()' -only-testing:'EpistemosTests/KokoroVoiceSelectionTests'`
- Result: failed before build/test because `EpistemosTests` is not a member of the `Epistemos-AppStore` test plan/scheme. This is not MAS source failure.
- Passing MAS focused command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-editor-hotpath-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()'`
- Result: `** TEST SUCCEEDED **`; Swift Testing ran 1 test, 1 passed.
- Result bundle: `build/xcode-results/2026-07-09-170043-31677.xcresult`.
- Compile flags observed in the passing log include `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

### Remaining verification debt

- Exact archive audible proof must show readiness plus `Kokoro TTS voice resolved ... selected=af_heart` or another English `af_*/am_*/bf_*/bm_*` voice.
- Run non-AppStore shared `KokoroVoiceSelectionTests` if/when using a scheme that includes `EpistemosTests`; MAS acceptance currently rests on the AppStore lane guard.

## Checkpoint 2026-07-09 June Send/Prompt-Upgrade Drift and MAS Bundle Scan

### Verbatim steer excerpt

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

### Interpreted intent

Prompt 2 remains MAS-only, but broad dirty-state caution is no longer a blocker. Remove shipped prompt-upgrade/Hermes drift and make June either answer or show a clear MAS-safe status error from the `Epistemos-AppStore` lane.

### Source and generated changes in this checkpoint

- `Epistemos/JuneAgent/JuneAgentGateway.swift`: the default model now resolves configured cloud first, Apple Intelligence second when available, and only falls back to generic cloud when no runnable local lane exists. The startup path remains off synchronous Keychain reads.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` and `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`: updated MAS guards for the new June default and expanded Hermes/prompt-upgrade drift checks.
- `/Users/jojo/dev/june-epistemos`: cleaned shipped visible Hermes/prompt-upgrade failure copy in the vendored June fork, then restaged `JuneWeb`.
- `.june-web-stage`: rebuilt staged MAS JuneWeb; main chunk `dist/assets/main-D9E8v6t9.js` hash `c67e2f678a8984d529e750606e6a5b5eac0acfb617b15203bdf71311f9141338`, shim hash `7c579a10ae17106f7df9c357a923d0a90f8018313a8035c2b6a96fad96c39c9f`.
- `Epistemos/Views/Sidebar/VaultSelectorView.swift`: removed the Debug preview `opencode-provider` sample tag that landed in the AppStore Debug dylib.
- `scripts/keelstone-release-gate.sh`: tightened retired-lane string scanning so real retired tokens still fail but incidental substrings such as `decodeXPCObject` do not.
- `scripts/scan_appstore_bundle.sh`: same token-bound retired-lane pattern, plus product-file scanning that excludes Debug XCTest harness plug-ins/frameworks from product runtime evidence.

### Verification evidence

- Failed pre-fix focused run: `build/xcode-results/2026-07-09-171205-34756.xcresult`; only failure was stale source-guard wording after June default repair.
- Passing focused rerun: `build/xcode-results/2026-07-09-171501-36376.xcresult`; `appStoreLaneKeepsJuneStartupOffSynchronousKeychainReads()` passed.
- Passing rebuilt focused rerun after removing `opencode-provider`: `build/xcode-results/2026-07-09-171940-40387.xcresult`; `appStoreLaneKeepsJuneStartupOffSynchronousKeychainReads()` passed.
- Built Debug AppStore product path scanned: `build/derived-mas-june-drift-2026-07-09/Build/Products/Debug/Epistemos.app`.
- Built bundle id: `com.epistemos.appstore`.
- Built Debug app contains `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- Built Debug JuneWeb scan returned no matches for prompt-upgrade UI, send-review hooks, or expanded Hermes-branded visible failure copy.
- `./scripts/keelstone-release-gate.sh --appstore-app build/derived-mas-june-drift-2026-07-09/Build/Products/Debug/Epistemos.app` result: `KEELSTONE release gate passed`.
- Standalone product bundle scan result: `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-debug-2026-07-09-june-drift ./scripts/scan_appstore_bundle.sh build/derived-mas-june-drift-2026-07-09/Build/Products/Debug/Epistemos.app` result: `[scan] complete`.

### Remaining verification debt

- Rebuild an exact Release `Epistemos-AppStore` archive after these source/generated changes, then rescan and relaunch that archive path.
- Manual June proof from the exact Release archive: send a short prompt and show either assistant output or one visible, non-Hermes MAS configuration/status reason.
- Vault restore/save proof remains a Prompt 2 release blocker: exact archive relaunch must restore `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)` without the missing/unreadable bookmark toast and without `Cannot save page body: no vault URL`.
- Voice proof remains open on the exact archive: Kokoro must resolve an English `af_*/am_*/bf_*/bm_*` voice, queue/render/play, and surface a visible reason if unavailable.
- Epdoc/editor/graph manual proof remains open: rich formatting survives surface switches; graph embedded/hologram routes do not stall editor open/typing; code editor is editable when no dirty-owner lease blocks it.

### Next action

Move to the vault restore/save blocker first, then rebuild/rescan/relaunch the Release AppStore archive after meaningful source fixes.

## Checkpoint 2026-07-09 Vault Restore Bookmark and MAS Bundle Gate

### Verbatim steer excerpt

> STOP normal feature work. Treat this as a MAS data-loss/release blocker.

> User-visible bug: after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault. The app shows “Saved vault bookmark points to a missing or unreadable directory. Automatic vault restore was paused,” then notes/files lose source access and saves fail.

### Interpreted intent

The MAS archive is not acceptable unless a user-selected vault bookmark restores after relaunch without a false missing/unreadable warning, without destructive local-state clearing, and without falling through to `Cannot save page body: no vault URL`.

### Source changes in this checkpoint

- `Epistemos/Sync/VaultSyncService.swift`: startup restore now retries readable-directory validation while the security scope remains active, preserves the bookmark on transient scope/readability failures, and reports bookmark persistence failure to the caller instead of pretending the relaunch permission was saved.
- `Epistemos/App/AppBootstrap.swift`: startup integrity now defers vault-source-loss warnings whenever a saved bookmark exists, so a bookmark restore path does not stack a misleading “notes have no vault source” warning before restore has a chance to complete.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: added/updated MAS guards for scoped readability, transient restore failures, deferred vault-source warnings, root-unavailable write freeze, and plain bookmark fallback refusal.
- `EpistemosTests/VaultSyncServiceAuditTests.swift`: shared audit tests now assert the new `persistVaultSelection` success/failure return contract.
- `scripts/keelstone-release-gate.sh`: release gate now requires the deferred bookmark/source-loss witness and the `persistVaultSelection` return contract; ACP loopback bundle scanning was narrowed to implementation/request markers rather than a standalone `/acp` regex fragment.

### Verification evidence

- Failed pre-fix focused run: `build/xcode-results/2026-07-09-172823-49761.xcresult`; failure was a stale source-section guard after replacing the one-shot `fileExists` check with scoped retry validation.
- Passing focused MAS vault restore run:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-vault-restore-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRetriesTransientMASBookmarkPreflightInsteadOfWarning()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneStartupRestoreFailurePreservesLocalVaultState()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLanePreservesBookmarkOnTransientRestoreFailures()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersVaultSourceLossWarningsForBlockedBookmarksToo()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRootUnavailabilityFreezesWrites()'`
- Result: `** TEST SUCCEEDED **`; Swift Testing ran 6 tests, 6 passed.
- Result bundle: `build/xcode-results/2026-07-09-173203-50684.xcresult`.
- Passing focused MAS bookmark-persist run:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-vault-restore-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRefusesPlainBookmarkFallback()'`
- Result: `** TEST SUCCEEDED **`; Swift Testing ran 1 test, 1 passed.
- Result bundle: `build/xcode-results/2026-07-09-173515-55538.xcresult`.
- Debug AppStore bundle scanned: `build/derived-mas-vault-restore-2026-07-09/Build/Products/Debug/Epistemos.app`.
- Standalone scan:
  `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-debug-2026-07-09-vault-restore ./scripts/scan_appstore_bundle.sh build/derived-mas-vault-restore-2026-07-09/Build/Products/Debug/Epistemos.app`
- Result: `[scan] complete`; no prohibited runtime strings, retired-lane strings, 1Code strings, prohibited runtime symbols, or quarantine xattrs detected.
- Release gate:
  `./scripts/keelstone-release-gate.sh --appstore-app build/derived-mas-vault-restore-2026-07-09/Build/Products/Debug/Epistemos.app`
- Result: `KEELSTONE release gate passed`.

### Remaining verification debt

- Exact Release `Epistemos-AppStore` archive rebuild/rescan/relaunch after these source changes.
- Manual archive proof for vault `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`: select vault, quit exact archive app, reopen exact archive app, restore same vault, no missing/unreadable toast, `vaultSync.vaultURL` non-nil, no `Cannot save page body: no vault URL` while saving.
- Manual archive proof for June output/prompt drift, English Kokoro read-aloud, Epdoc formatting/performance, graph editor route performance, and code editor editability remains open.

### Next action

Rebuild a Release AppStore archive, run source/target/archive leak scans against that archive, then launch the exact archive app for visible MAS/vault/Juńe proof.

## Checkpoint 2026-07-09 Visible MAS Archive and Normal-App Proof

### Verbatim steer excerpt

> The running MAS archive shows “The Workspace bundle is missing from this build.”

> Package JuneWeb into the MAS archive at Contents/Resources/JuneWeb. Required files: JuneWeb/dist/index.html and JuneWeb/tauri-internals-shim.js.

> One active product reality: MAS/June. The normal/base app the owner opens must match the MAS App Store product.

### Interpreted intent

Prompt 2 is not complete until the exact `Epistemos-AppStore` Release archive visibly launches June, the archive carries the MAS-only resource/runtime posture, and the normal owner-facing `/Applications/Epistemos.app` no longer opens an old 1Code/OpenChamber/Experimental surface.

### Exact archive proof

- Archive command:
  `./scripts/xcodebuild_epistemos.sh archive -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'generic/platform=macOS' -archivePath build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive -derivedDataPath build/derived-mas-archive-2026-07-09-vault-june-proof`
- Result: `** ARCHIVE SUCCEEDED **`.
- Scheme built: `Epistemos-AppStore`.
- Target built: `Epistemos-AppStore`.
- Configuration: `Release`.
- Archive app path: `build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app`.
- Built bundle identifier: `com.epistemos.appstore`.
- Built executable: `Epistemos`.
- Required JuneWeb files: `Contents/Resources/JuneWeb/dist/index.html` present; `Contents/Resources/JuneWeb/tauri-internals-shim.js` present; `JuneWeb` contains 28 files.
- Release build settings command:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -showBuildSettings`
- Active Swift flags: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` are absent from the `Epistemos-AppStore` Release Swift conditions.
- Built entitlements include App Sandbox, app-scope bookmarks, user-selected read-write, network client, audio input, and `group.com.epistemos.shared`; they omit JIT, disabled library validation, and network server entitlement.

### Archive scan proof

- Release gate:
  `./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app`
- Result: `KEELSTONE release gate passed`.
- Standalone archive scan:
  `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-release-2026-07-09-vault-june-proof ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app`
- Result: `[scan] complete`.
- Scan report path: `build/appstore-audit-release-2026-07-09-vault-june-proof`.
- `forbidden-strings.txt`, `forbidden-retired-lane-strings.txt`, `forbidden-1code-strings.txt`, `forbidden-account-runtime-strings.txt`, `forbidden-symbols.txt`, `forbidden-resources.txt`, and `quarantine-xattrs.txt` are empty.
- Exact artifact-name scan: `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, and `experimental-runtime` are absent from archive bundle paths.
- Exact executable-name scan: `node`, `bun`, `rg`, `goosed`, `opencode`, and `codex` are absent from archive executable/resource paths.
- Token-bounded bundle string scan: `1Code`, `ExperimentalWeb`, `OpenChamber`, `goosed`, `opencode`, and `experimental-runtime` are absent. A raw substring probe hit `v1Codestral` inside `libagent_core.dylib`; this is a provider URL/name substring, not the retired 1Code product/runtime.

### Exact archive launch proof

- Stale process before proof: `/Applications/Epistemos.app/Contents/MacOS/Epistemos --epistemos-run-kokoro-proof-on-launch`; classified as a stale prior app process and terminated before evidence collection.
- Exact archive launch command: `open -n build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app`.
- Exact launched process path: `build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Launched process bundle id: `com.epistemos.appstore`.
- Screenshot proof path: `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_17-49-51-w53477.png`.
- Screenshot result: June home loaded; no “Workspace bundle is missing from this build” panel.
- Secondary restored-window screenshot path: `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_17-49-51-w53479.png`.

### Normal/base app proof

- Previous `/Applications/Epistemos.app` was already `com.epistemos.appstore` and contained `JuneWeb`, but it was not used as archive evidence.
- Replaced `/Applications/Epistemos.app` with the verified archive build.
- Backup of prior normal app: `/Applications/Epistemos.app.pre-keelstone-20260709-175106.bak`.
- Normal app path owner should open going forward: `/Applications/Epistemos.app`.
- Normal app bundle id: `com.epistemos.appstore`.
- Normal launch proof process path: `/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Normal launch proof bundle id: `com.epistemos.appstore`.
- Normal screenshot proof path: `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_17-51-27-w53569.png`.
- Screenshot result: normal app opens the MAS June shell/resume checkpoint, not 1Code/OpenChamber and not the missing-bundle panel.
- Secondary restored-window screenshot path: `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_17-51-27-w53587.png`.

### Stale process classification

- Stale `goosed`/OpenChamber/ExperimentalWeb processes are not MAS evidence and were not used as proof.
- The many `node headless/dist/index.cjs` processes and Codex app/node processes visible in `pgrep` are external/stale/non-MAS process noise; the verified MAS app bundle does not package `node`, `bun`, `rg`, `goosed`, `opencode`, `codex`, OpenChamber, ExperimentalWeb, or `experimental-runtime`.

### Current verification debt

- Vault runtime proof remains open: select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen the exact MAS app, confirm no missing/unreadable bookmark toast, confirm `vaultSync.vaultURL` non-nil, and confirm save path does not log `Cannot save page body: no vault URL`.
- June runtime proof remains open: send a short prompt in the MAS app and show assistant output or a clear non-Hermes MAS configuration/status reason.
- English Kokoro proof remains open: exact MAS app must show Kokoro gate ready, resolve an English `af_*`, `am_*`, `bf_*`, or `bm_*` voice, queue playback, and not silently no-op.
- Epdoc/editor/graph proof remains open: rich Epdoc formatting must survive surface switches; Epdoc, Prose, Source, Code Editor, embedded graph, and hologram graph routes must not hang on load/typing; Code Editor must be editable when no dirty-owner lease blocks it.
- Prompt-upgrade/Hermes drift source and bundle scans are clean, but manual June send proof is still required.

### Next action

Continue Prompt 2 on the remaining product blockers in this order: vault runtime restore/save proof, English Kokoro/read-aloud proof/fix, June send/output proof/fix, then Epdoc/graph/editor performance and formatting hardening. Do not advance past Prompt 2 while any of these remain unproven or a HIGH blocker without exact next actions.

## Checkpoint 2026-07-09 Exact Archive Kokoro English Runtime Proof

### Verbatim steer excerpt

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work

> the vocie is in another lanugage big issue

> im asking am i able to do english or how does that shit work

### Interpreted intent

Kokoro is acceptable for MAS only if the exact AppStore archive can resolve a checked English Kokoro voice and actually queue/render/play audio without falling back to Apple AVSpeech or silently no-oping.

### Proof evidence

- Exact app launched for proof: `build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app`.
- Launch command: `open -n build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app --args --epistemos-run-kokoro-proof-on-launch`.
- Launched process path: `build/appstore-release-archive-2026-07-09-vault-june-proof.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos --epistemos-run-kokoro-proof-on-launch`.
- Bundle id: `com.epistemos.appstore`.
- AppStore defaults gate: `EPISTEMOS_KOKORO_VOICE_PRO_V0 = 1`.
- Installed English-capable voice IDs observed in the package: `af_bella`, `af_heart`, `af_nicole`, `am_fenrir`, `am_michael`, `am_puck`, `bf_emma`.
- Runtime log evidence from unified log:
  - `Kokoro launch proof requested phraseLanguage=en`.
  - `Kokoro readiness context=launch-voice-proof gateResolved=true modelRoot=/Users/jojo/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro manifestValid=true KokoroPipelineLinked=true isTextToSpeechAvailable=true headline=Kokoro voice: native CoreML playback ready`.
  - `Kokoro readiness evidence context=launch-voice-proof modelPackages=22 voices=7 runtimeAssets=2 manifestFiles=75 declaredBytes=987229282`.
  - `Kokoro TTS voice resolved requested=af_bella selected=af_bella englishOnly=true`.
  - `Kokoro TTS render started chars=46 voice=af_bella speed=1.000000`.
  - `Kokoro TTS queued chars=46 effect=clean`.
  - `Kokoro launch proof queued utteranceID=C2A0ADA0-B84F-47DE-8D6C-462EC415DD4C`.
  - `Kokoro TTS render finished chars=46 samples=111480 sampleRate=24000 chunks=2 elapsedMs=7270`.
  - `Kokoro TTS playback started samples=111480 playerPlaying=true`.
  - `Kokoro TTS playback completed`.

### Answer to owner question

Yes, English is available. In this codebase, English Kokoro voices are the `af_*`, `am_*`, `bf_*`, and `bm_*` voice IDs. The exact MAS archive selected `af_bella`, which is an American-English female Kokoro voice. If a previous app instance spoke another language, that was stale-build/selection drift, not a model limitation.

### Remaining verification debt

- Manual ear-confirmation is still owner-observable debt because Codex can prove queue/render/playback logs but cannot hear the speaker output.
- Surface-by-surface read-aloud matrix still needs live MAS proof: June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, and other active MAS surfaces.

## Checkpoint 2026-07-09 Epdoc Blanking Regression Reopened

### Verbatim steer excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Interpreted intent

Epdoc blanking on open or surface switch is an active Prompt 2 release blocker. The MAS product must preserve the existing Markdown/Epdoc body and rich formatting when moving between Prose, Source, Code, graph-linked routes, and Epdoc; a transient empty editor snapshot or initial bridge echo must not overwrite a non-empty persisted document.

### Constraints and non-goals

- Keep current proof lane MAS-only: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`.
- Do not use stale debug/DerivedData apps as evidence.
- Do not treat source guards alone as final runtime proof.
- Do not stage or commit broad dirty state.
- Keep the fix scoped to the blanking path unless the trace shows a wider data-flow cause.

### Acceptance checks

- Epdoc opens from non-Epdoc surfaces with non-empty content intact.
- Switching away from and back to Epdoc does not replace the document with an empty body.
- Initial Epdoc bridge load cannot save or snapshot an empty Markdown echo over a non-empty source.
- Focused MAS tests cover the guard paths before the next archive proof.

### Fix checkpoint

- `NoteDetailWorkspaceView` now ignores a clean empty editor snapshot during lens-switch flush when the persisted body is non-empty and no write lease is pending.
- `EpdocEditorChromeController` now preserves the non-empty initial Markdown source when JS emits an empty Markdown echo during initial load; it re-pushes the source and suppresses any blank save over the source.
- AppStore lane executable regression added: `appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho`.
- Shared bridge regression added: `chromeControllerRepushesNonEmptyMarkdownSourceAfterEmptyInitialEcho`.

### MAS test evidence

- Command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-blank-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown()'`
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-180416-47524.xcresult`.
- Active compile flags observed in the test build: `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.
- Executed tests: 4 AppStore Keelstone tests, including the new empty-initial-echo regression.
- Runtime test log observed: `Epdoc initial Markdown load echoed empty content; re-pushing non-empty Markdown source`.

### Remaining verification debt

- Release AppStore archive must be rebuilt after this source change.
- AppStore archive gate and bundle scans must be rerun.
- Exact archive app should be relaunched before claiming visible Epdoc proof; source/MAS unit evidence alone is not final manual proof.

## Checkpoint 2026-07-09 Epdoc Blank Runtime Proof Failed

### Verbatim steer excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Runtime evidence

- Exact archive built and launched:
  `build/appstore-release-archive-2026-07-09-epdoc-recovery-proof.xcarchive/Products/Applications/Epistemos.app`.
- Archive command result: `** ARCHIVE SUCCEEDED **`.
- Bundle id from archive and running process: `com.epistemos.appstore`.
- Running process path:
  `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-epdoc-recovery-proof.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Release gate result: `KEELSTONE release gate passed`.
- Bundle scan report directory:
  `build/appstore-audit-release-2026-07-09-epdoc-recovery-proof`.
- Bundle scan result: no prohibited runtime strings, no prohibited runtime symbols, no prohibited research/tool residue, no quarantine xattrs.
- Screenshot evidence:
  `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_18-38-56-w54130.png`.
- Screenshot result: the MAS archive opened a note titled `scope_rex_final...` in the rich Document/Epdoc surface, but the editor showed `Start writing your Epistemos document...` and `0 words 0 chars`, while the resume checkpoint simultaneously reported `scope_rex_final_architecture.converted [note tab] 498 lines, 3451 words`.

### Refined root cause

- The previous WebKit-process-termination recovery patch is necessary but insufficient for the owner-visible bug.
- The failing path is the in-note `MarkdownDocumentSurface`, not only standalone `.epdoc` windows.
- `NoteDetailWorkspaceView` initializes `persistedBody` as empty, schedules the real body load asynchronously, and mounts the Document surface immediately.
- `MarkdownDocumentSurfaceCoordinator.configure(...)` treats the same page as already configured and, with `reloadSamePageExternalMarkdown = false`, can refuse to reload the clean editor when the inbound Markdown changes from an initial empty value to the loaded non-empty persisted body.
- Result: the rich editor stays mounted on the empty initial Markdown even after the host view has the real body.

### Next patch target

- Add a same-page clean recovery path that reloads the Document surface when the current rich-editor Markdown is empty, the inbound Markdown is non-empty, and the controller is not dirty.
- Preserve the existing performance guard for ordinary same-page clean Markdown churn so surface switches do not remount rich formatting unnecessarily.
- Extend AppStore Keelstone tests to prove empty-to-non-empty same-page reload and keep the old no-remount/hidden-reload guards.

### Patch and MAS test evidence

- `MarkdownDocumentSurfaceCoordinator.configure(...)` now detects `shouldRecoverCleanEmptyInitialLoad` for the exact async body-load failure mode: same page, active surface, clean controller, current rich-editor Markdown empty, inbound Markdown non-empty.
- The recovery path calls `controller.loadInitialContent(...)` with the newly loaded Markdown, while the existing `reloadSamePageExternalMarkdown = false` guard still protects ordinary same-page clean updates from remounting rich formatting.
- AppStore test added: `appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount`.
- Shared regression added: `samePageMarkdownDocumentReloadsWhenAsyncBodyArrivesAfterEmptyMount`.
- Focused MAS command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-empty-load-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRecoversEpdocAfterWebKitBlankingWithLastMarkdownSource()'`
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-184303-92100.xcresult`.
- Executed Swift Testing tests: 6 tests in `KEELSTONE App Store Lane`.
- Active AppStore test compile flags included `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.

### Remaining proof debt

- Rebuild the exact `Epistemos-AppStore` Release archive after this source change.
- Rerun KEELSTONE release gate and AppStore bundle scan on the new archive.
- Relaunch the exact archive app and prove the `scope_rex_final...` rich Document/Epdoc surface is no longer blank after restore/open/surface switch.

## Checkpoint 2026-07-09 Epdoc Empty-Load Archive Proof

### Verbatim steer excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Archive and gate evidence

- Exact archive command:
  `./scripts/xcodebuild_epistemos.sh archive -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'generic/platform=macOS' -archivePath build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive -derivedDataPath build/derived-mas-archive-2026-07-09-epdoc-empty-load-proof`
- Result: `** ARCHIVE SUCCEEDED **`.
- Exact archive app:
  `build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app`.
- Bundle id: `com.epistemos.appstore`.
- Build settings proof:
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- Built binary compile output also showed `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- Architecture: `x86_64 arm64`.
- Entitlements: sandbox enabled, app-scope bookmarks enabled, user-selected read-write enabled, network client enabled, audio input enabled; JIT/library-validation/network-server entitlements absent.
- Required JuneWeb files present:
  `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- KEELSTONE gate command:
  `./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app`.
- KEELSTONE gate result: `KEELSTONE release gate passed`.

### Bundle scan evidence

- First scan command:
  `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-release-2026-07-09-epdoc-empty-load-proof ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app`.
- First scan result: failed only the resource-name pass because the full archive parent path contained `empty`, which matched the unbounded `pty` resource regex. Runtime strings, account/backend strings, retired-lane strings, 1Code strings, symbol/linkage, and quarantine checks all passed before that false-positive.
- Scanner patch: `scripts/scan_appstore_bundle.sh` now creates `resource-files.txt` relative to the `.app` root and runs the resource-name regex against that relative list. Full paths are still used for string/linkage evidence.
- Syntax check: `bash -n scripts/scan_appstore_bundle.sh` passed.
- Rescan command:
  `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-release-2026-07-09-epdoc-empty-load-proof-rescan ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app`.
- Rescan result: `[scan] complete`.
- Rescan report directory:
  `build/appstore-audit-release-2026-07-09-epdoc-empty-load-proof-rescan`.
- Exact basename prohibited path scan for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, and `experimental-runtime` returned no matches in the archive app bundle.

### Runtime visible proof

- Stale previous failed proof app was identified and quit:
  PID `76266`, path `build/appstore-release-archive-2026-07-09-epdoc-recovery-proof.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Launch command:
  `open -n build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app`.
- Running process:
  PID `41757`, path `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Running bundle id: `com.epistemos.appstore`.
- Process scan after launch showed no active `goosed`, OpenChamber, ExperimentalWeb, opencode, bun, or local-server dependency tied to the MAS app. External `node headless/dist/index.cjs` and Codex node processes remain non-MAS process noise and are not evidence.
- Screenshot evidence before overlay dismissal:
  `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_18-59-34-w54179.png`.
- Screenshot result: the previously blank `scope_rex_final...` rich Document/Epdoc surface now renders the real body, headed `SCOPE-Rex: The Definitive Architecture`, with `2,775 words` and `19,274 chars`; it no longer shows the `Start writing...` placeholder or `0 words 0 chars`.
- Overlay dismissal proof:
  `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_19-03-50-w54177.png` shows the Welcome Back overlay gone.
- Post-interaction Epdoc screenshot:
  `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_19-04-38-w54179.png` still shows non-empty Epdoc content with the same nonzero word/character count.

### Result and remaining debt

- Fixed/proven for the owner-visible blank-on-open restore path in the exact MAS archive.
- Automated source/Document toggle clicks were attempted after dismissing the overlay, but the custom SwiftUI toolbar did not switch surfaces through coordinate automation. Do not count that as complete manual surface-switch proof.
- AppStore executable regressions still cover the switch/load state path:
  `appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState`,
  `appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown`,
  `appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount`,
  `appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho`,
  and `appStoreLaneRecoversEpdocAfterWebKitBlankingWithLastMarkdownSource`.
- Remaining Prompt 2 debt: add a deterministic internal/manual proof path for surface toggling, then continue Epdoc/graph/editor performance hardening.

### Normal/base app replacement proof

- Previous normal `/Applications/Epistemos.app` was already `com.epistemos.appstore` but came from an older MAS archive.
- Replacement backup:
  `/Applications/Epistemos.app.pre-epdoc-empty-load-20260709-190710.bak`.
- Replacement source:
  `build/appstore-release-archive-2026-07-09-epdoc-empty-load-proof.xcarchive/Products/Applications/Epistemos.app`.
- New normal app path:
  `/Applications/Epistemos.app`.
- Normal app bundle id: `com.epistemos.appstore`.
- Normal app required JuneWeb files present:
  `/Applications/Epistemos.app/Contents/Resources/JuneWeb/dist/index.html` and `/Applications/Epistemos.app/Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- Normal app launch command:
  `open -n /Applications/Epistemos.app`.
- Running normal process:
  PID `56089`, path `/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Normal app screenshot:
  `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_19-08-00-w54200.png`.
- Screenshot result: normal/base app opens the MAS/June shell with the resume checkpoint; it does not open the old 1Code/OpenChamber/Experimental surface.

## Checkpoint 2026-07-09 Epdoc Reactivation Blank Regression

### Verbatim steer excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Interpreted intent

- Treat Epdoc blanking as an active Prompt 2 MAS release blocker.
- Fix the real in-app surface-switch/open regression, not only source guards.
- Preserve rich Epdoc formatting while preventing blank Document surfaces after switching away and back.
- Keep working in the MAS proof lane: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`.

### Current evidence before next patch

- Previous focused MAS hot-path/source guard command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-hotpath-current-body-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount()'`.
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-191235-63486.xcresult`.
- Swift Testing result: 3 tests passed in `KEELSTONE App Store Lane`.

### New suspected missing case

- The previous patch covers async empty-to-non-empty Markdown arrival while the Document surface is already active.
- The recurrence can still happen when the hidden Epdoc WebView remains mounted across surface switches: the controller can retain a non-empty `latestMarkdownSnapshot`, but the visible editor DOM/stat state can be blank on reactivation.
- A safe recovery should re-push the non-empty host Markdown only when the surface becomes active, the controller is clean, and the visible stats are empty. It must not reload on every normal same-page update, because that can destroy rich in-editor formatting/cursor state.

### Next patch target

- Add a reactivation-only blank recovery path to `MarkdownDocumentSurfaceCoordinator.configure(...)`.
- Add shared and AppStore executable regressions proving a hidden/blank Epdoc surface re-pushes non-empty Markdown on activation.
- Re-run focused MAS tests, then rebuild/rescan/relaunch the AppStore archive after source changes.

### Patch and focused MAS test evidence

- `MarkdownDocumentSurfaceCoordinator.configure(...)` now tracks `becameActive` and calls `shouldRecoverVisibleBlankOnReactivation(...)` before the ordinary same-page no-remount guard.
- The recovery path is limited to hidden-to-active transitions where the controller is clean, the visible editor character count is `0`, and the host/remembered Markdown is non-empty and matches the current page Markdown.
- This preserves the `reloadSamePageExternalMarkdown = false` protection for normal clean same-page updates, so rich Epdoc formatting is not remounted during routine surface switches.
- AppStore executable regression added:
  `appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation`.
- Shared regression added:
  `hiddenMarkdownDocumentSurfaceRepushesNonEmptyMarkdownWhenBlankOnReactivation`.
- Focused MAS command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-reactivation-blank-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRecoversEpdocAfterWebKitBlankingWithLastMarkdownSource()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'`.
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-191929-77843.xcresult`.
- Swift Testing result: 8 tests passed in `KEELSTONE App Store Lane`.

### Remaining proof debt

- Rebuild exact `Epistemos-AppStore` Release archive after this reactivation fix.
- Run KEELSTONE release gate and AppStore bundle scan on the new archive.
- Relaunch the exact archive app and capture visible proof that Epdoc loads non-empty after open/reactivation, without using stale debug apps as evidence.

## Checkpoint 2026-07-09 Source Mount + No-UI-Testing Pause

### Verbatim owner steer excerpt

> stop testing it until i say go back go back u can resume what u were doing im trying to work on my laptop so when i type 'go back' resume literally everythign u were doig before this promot

### Interpreted intent

- Stop all live app interaction, screenshots, launches, Accessibility/window automation, and manual UI proof until the owner types `go back`.
- Continue source-only Prompt 2 work, CLI builds/tests/scans, ledger updates, and release hardening that does not touch the visible running app.
- Keep MAS proof scoped to `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, and `MAS_SANDBOX`.

### Archive/gate/scan evidence before pause

- Release archive command:
  `./scripts/xcodebuild_epistemos.sh archive -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'generic/platform=macOS' -archivePath build/appstore-release-archive-2026-07-09-source-mount-proof.xcarchive -derivedDataPath build/derived-mas-archive-2026-07-09-source-mount-proof`.
- Result: `** ARCHIVE SUCCEEDED **`.
- Compile flags observed in archive log: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.
- Release gate command:
  `./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-source-mount-proof.xcarchive/Products/Applications/Epistemos.app`.
- Result: passed. The gate verified the normal `Epistemos` scheme maps to the MAS AppStore target, AppStore flags/entitlements are present, JuneWeb required files are bundled, and retired/runtime residue is absent.
- Bundle scan command:
  `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-release-2026-07-09-source-mount-proof ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-source-mount-proof.xcarchive/Products/Applications/Epistemos.app`.
- Result: passed. No quarantine xattrs, no prohibited runtime strings, no retired-lane/1Code strings, no prohibited symbols/resources.
- Bundle id: `com.epistemos.appstore`.
- Required JuneWeb files present in archive:
  `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.

### Runtime evidence captured before owner pause

- Stale old archive process for `build/appstore-release-archive-2026-07-09-epdoc-reactivation-blank-proof.xcarchive/...` was killed before launching the new archive.
- Exact archive app launched before the owner pause:
  `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-source-mount-proof.xcarchive/Products/Applications/Epistemos.app`.
- Running PID confirmed before pause: `50891`.
- Running process path confirmed before pause:
  `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-source-mount-proof.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Bundle id confirmed before pause: `com.epistemos.appstore`.
- Partial screenshot proof captured before pause:
  `build/proof-screenshots/mas-source-mount-note-raised-2026-07-09-w54580.png`.
- Screenshot result: SCOPE-Rex Body/Epdoc note was nonblank with rich layout and nonzero word/character count.
- Manual Source/Document surface-switch proof did not complete before the owner paused UI testing. Do not claim runtime switch proof from this checkpoint until `go back` permits relaunch/screenshot/manual proof.

### Source patch and focused MAS test evidence

- `NoteDetailWorkspaceView.cachedSourceEditorContent(page:route:)` now mounts Markdown Source synchronously from `markdownSourceFallbackContent(for:filePath:)` when no source snapshot exists, instead of falling through to a potentially empty code-file/body cache.
- AppStore guard added to `appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()`.
- Shared source guard added to `CodeEditorPolishTests`.
- Focused MAS command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-source-mount-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'`.
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-195253-18284.xcresult`.
- Non-evidence: a previous `EpistemosTests/CodeEditorPolishTests` run under `Epistemos-AppStore` failed with exit 70 because `EpistemosTests` is not in the MAS scheme/test plan. That is a scheme membership rejection, not a source failure.

### Manual proof debt while owner pause is active

- Do not use stale cached `goosed`, `OpenChamber`, `ExperimentalWeb`, debug DerivedData apps, or old archive apps as evidence.
- Do not interact with PID `50891` or any visible app window until the owner says `go back`.
- After `go back`, quit stale preview/debug processes if safe, relaunch the exact latest MAS archive by path, then capture visible proof for open/reactivation/source-document switching.

## Checkpoint 2026-07-09 Epdoc Stale-Stats Reactivation Probe

### Verbatim owner issue excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Interpreted intent

- Treat Epdoc blanking on open/surface-switch as a live Prompt 2 blocker.
- Fix both the visible blank and the data-loss edge where an empty JS snapshot could overwrite non-empty host Markdown.
- Preserve rich table/formatting state: do not remount on every normal clean switch.

### Source patch

- `EpdocEditorChromeController` now supports a clean reactivation probe:
  `requestCleanReactivationMarkdownProbe(expectedMarkdown:)`.
- Probe `contentDidChange` snapshots are suppressed from `onContentChanged`, so they cannot enqueue JSON saves or mark the document dirty.
- If the probe's Markdown snapshot is empty while the host Markdown is non-empty, the controller logs:
  `Epdoc clean reactivation probe returned empty content; re-pushing non-empty host Markdown source`.
- The controller then re-pushes the host Markdown through load-epoch guarded `.setMarkdownForLoad` and `.focusStart`.
- `MarkdownDocumentSurfaceCoordinator.configure(...)` keeps the earlier immediate recovery for `characterCount == 0`, and now probes on clean hidden-to-active reactivation when stats may be stale/nonzero.

### Focused MAS test evidence

- Focused MAS command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-reactivation-probe-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneProbesStaleEpdocStatsAndSuppressesBlankReactivationSnapshots()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation()'`.
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-202026-64582.xcresult`.
- Swift Testing result: 3 tests passed in `KEELSTONE App Store Lane`.
- The test log included the expected probe recovery log and proved no blank Markdown/JSON save was emitted during the probe path.

### Archive/gate/scan evidence after probe patch

- Release archive command:
  `./scripts/xcodebuild_epistemos.sh archive -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'generic/platform=macOS' -archivePath build/appstore-release-archive-2026-07-09-epdoc-stale-stats-proof.xcarchive -derivedDataPath build/derived-mas-archive-2026-07-09-epdoc-stale-stats-proof`.
- Result: `** ARCHIVE SUCCEEDED **`.
- Exact archived app path:
  `build/appstore-release-archive-2026-07-09-epdoc-stale-stats-proof.xcarchive/Products/Applications/Epistemos.app`.
- Release gate command:
  `./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-epdoc-stale-stats-proof.xcarchive/Products/Applications/Epistemos.app`.
- Result: passed. The gate verified normal `Epistemos` scheme mapping to the MAS AppStore target, MAS target flags/entitlements, AppStore artifact JuneWeb files, no prompt-upgrade/Hermes shipped drift, and no prohibited parked runtime/resource residue.
- Bundle scan command:
  `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit-release-2026-07-09-epdoc-stale-stats-proof ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-epdoc-stale-stats-proof.xcarchive/Products/Applications/Epistemos.app`.
- Result: passed. The scan reported no quarantine extended attributes, no prohibited runtime strings, no parked account/backend runtime strings, no retired-lane strings, no `1Code` strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.
- Scan report path:
  `build/appstore-audit-release-2026-07-09-epdoc-stale-stats-proof`.
- Required JuneWeb files present by gate:
  `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.

### Verification debt

- `EpistemosTests/EditorProvenanceStoreTests/hiddenMarkdownDocumentSurfaceProbesStaleStatsAndSuppressesBlankReactivationSnapshots()` was added as a shared regression, but the normal `Epistemos` scheme now runs the MAS KEELSTONE test target and rejected `EpistemosTests` with exit 70:
  `build/xcode-results/2026-07-09-202416-81181.xcresult`.
- This is not a source failure, but the shared target compile remains debt unless/until a legacy-dev-only compile is intentionally run or the shared regression is moved fully into the MAS target.
- Manual visible proof remains paused by owner instruction until `go back`: do not launch, click, screenshot, focus, or otherwise interact with the running app while the owner is working.

## Checkpoint 2026-07-09 Graph/Editor Hot-Path Source Guard

### Verbatim owner issue excerpt

> graph embedded and hologram graph when i go to ndes it takes a long time to lead them up and when i edit anythign in the graph hologram or embedded graoh they hang so editting anyhtig through the graph surfaces makes tehm hang badly and lots of performance issues.

> it also wont let me edit on code editor at all for some reason it just has me view it

### Interpreted intent

- Treat graph-embedded/hologram node editor hangs and read-only code/source editors as Prompt 2 MAS blockers.
- Keep graph inspector previews read-only and bounded; do not let preview loading take write leases or run heavy save/sync paths.
- Restore editability when a stale/deallocated editor owner was only kept alive by weak lease bookkeeping.

### Source patch

- `NoteSessionStateMachine.ownerSessionIsActive(_:)` now removes a deallocated weak owner from both `activeSessionsByID` and `activeSessionIDs`, so Source/Code/graph embedded editors are not kept read-only by a stale owner id.
- `HologramNodeInspector` now uses `HologramInspectorPreviewPolicy` with a bounded preview body, `.utility` priority loading, route guards, and explicit cancellation when leaving canvas routes.
- `AppStoreKeelstoneLaneTests` now guards stale-owner cleanup and the graph inspector preview policy.

### Focused MAS test evidence

- Focused MAS command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-graph-editor-hotpath-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneLetsGraphEmbeddedEditorTakeCleanActiveLease()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReclaimsDeallocatedGraphEditorOwnerSoSourceStaysEditable()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneBlocksGraphEmbeddedEditorWhileOwnerIsDirty()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsHologramInspectorPreviewReadOnly()'`.
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-204405-15117.xcresult`.
- Swift Testing result: 5 tests passed in `KEELSTONE App Store Lane`.
- Prior non-terminal guard run failed only because the test still expected the old `.userInitiated` preview task string:
  `build/xcode-results/2026-07-09-204031-3554.xcresult`.

### Verification debt

- Manual graph route/editing latency proof remains paused until `go back`.
- Exact Release archive/gate/scan must be rerun after the current source batch before using this as release evidence.

## Checkpoint 2026-07-09 Epdoc Remount Blank/Data-Loss Guard

### Verbatim owner issue excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Interpreted intent

- The previous stale-stats probe was not sufficient if a WebView is dismantled and later remounted with the same controller.
- A remounted Epdoc WebView must receive the host Markdown again, and an empty renderer snapshot must never become a saved blank over a non-empty Markdown note.

### Source patch

- `EpdocEditorChromeController.detachEditorDispatch()` now resets WebView-lifetime state:
  `editorIsReady`, `didPushInitialContent`, initial-echo/probe flags, and load epoch.
- The detach path preserves remembered Markdown, dirty state, and document identity, so a new WebView can re-push the last host Markdown instead of appearing blank.
- `MarkdownDocumentSurfaceCoordinator.requestCurrentMarkdownSnapshotFromEditor()` now refuses an empty direct editor snapshot when the coordinator still has non-empty Markdown, logging:
  `MarkdownDocumentSurface: ignored empty direct editor snapshot over non-empty Markdown source`.
- `AppStoreKeelstoneLaneTests` adds direct regressions for WebView remount re-push and empty direct snapshot refusal.

### Focused MAS test evidence

- Focused MAS command:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-mas-epdoc-remount-guard-2026-07-09 -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesEpdocMarkdownAfterWebViewRemount()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRefusesEmptyDirectEpdocFlushOverNonEmptyMarkdown()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneProbesStaleEpdocStatsAndSuppressesBlankReactivationSnapshots()' -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation()'`.
- Result: `** TEST SUCCEEDED **`.
- Result bundle: `build/xcode-results/2026-07-09-205044-31005.xcresult`.
- Swift Testing result: 5 tests passed in `KEELSTONE App Store Lane`.
- Test logs included:
  `MarkdownDocumentSurface: ignored empty direct editor snapshot over non-empty Markdown source`
  and
  `Epdoc clean reactivation probe returned empty content; re-pushing non-empty host Markdown source`.

### Verification debt

- Manual exact-archive proof remains paused until `go back`; do not claim visible Epdoc switching proof yet.
- Rebuild Release archive and rerun KEELSTONE gate/AppStore bundle scan after the current source-only batch.

## Checkpoint 2026-07-09 Owner Pause: No Live App Testing Until `go back`

### Verbatim owner steer

> stop testing it until i say go back go back u can resume what u were doing im trying to work on my laptop so when i type 'go back' resume literally everythign u were doig before this promot

### Interpreted intent

- Stop interacting with the visible/running app while the owner is using the laptop.
- Do not launch the archive app, focus windows, click, type, screenshot, automate UI, or treat stale running processes as evidence until the owner explicitly types `go back`.
- Continue only source-side MAS hardening and non-UI inspection/editing that does not interfere with the owner.

### Constraints

- No stale cached `goosed`, `OpenChamber`, `ExperimentalWeb`, debug DerivedData app, or old archive app may be used as MAS evidence.
- Manual visible proof for vault restore, Epdoc switching, graph/editor latency, June send output, and audible Kokoro voice remains blocked by this pause.
- Source changes still need Release archive/gate/scan after the current source batch; visible app proof must wait for `go back`.

### Current next source actions

- Patch June MAS send so a successful-but-empty model stream becomes a visible MAS-safe error/status instead of a silent blank turn.
- Tighten Kokoro English source hygiene and keep read-aloud verification debt explicit.
- Re-run only CLI-safe source/gate checks that do not drive the visible app, or defer them if they would launch/focus the app.

## Checkpoint 2026-07-09 June Blank Send + Kokoro English Source Patch

### Verbatim owner issue excerpts

> june mas still is not rlly working it is not producing outputs and i cant tell if it even works

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

> voice is not in english i need it to be in english if it is not an english model then idk why we are even using it.

### Interpreted intent

- June must never present an empty successful MAS turn as if it answered.
- MAS Prompt Forge / prompt-upgrade behavior must be disabled or literal-preserving; no Hermes/model rewrite path should run on send.
- Kokoro read-aloud must resolve to English Kokoro voices only; a non-English Kokoro voice id must not win through a misleading label.

### Source patch

- `JuneAgentGateway.startTurn(...)` now calls `requireVisibleAssistantReply(full, modelID:)` before emitting an OK `message.complete` for both explicit stream completion and the fallback no-complete path.
- A successful stream with empty/whitespace reply text now throws `JuneGatewayError.modelPreparing(...)`, routes through the existing error catch, persists an assistant error message, and emits `message.complete` with `status: "error"` instead of a blank OK completion.
- The existing MAS `prompt.forge_preview`/`system_prompt_forge_preview` behavior remains disabled/literal-preserving: send goes straight to `startTurn`, System Prompt Forge returns `upgradedText: original`, `changed: false`, and no Hermes/model/vault rewrite path.
- `EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(...)` now builds selectable IDs through `isEnglishKokoroVoiceOption`, requiring both an English label and English Kokoro id prefix (`af_`, `am_`, `bf_`, `bm_`).
- `preferredEnglishKokoroVoiceIdentifier(...)` now falls back only to `voices.first(where: isEnglishKokoroVoiceOption)`.
- `KokoroCoreMLSynthesizer.englishPhonemeSymbols(...)` no longer carries both the literal em dash and `\u{2014}` in the same Swift `case`, removing the duplicate-literal warning in the English phoneme path.
- `AppStoreKeelstoneLaneTests` source guards now cover blank June completion failure and mislabeled non-English Kokoro voice rejection.

### Source-only checks run under owner pause

- `rg` verified the new June guard strings in `JuneAgentGateway.swift` and `AppStoreKeelstoneLaneTests.swift`.
- `rg` verified the Kokoro English filter source strings and that the duplicate `"` + em dash + `", "\u{2010}"` switch literal sequence is absent.
- `rg`/`sed` confirmed the MAS System Prompt Forge handler is synchronous, bounded, uses `activeVaultURL: nil`, returns original prompt text unchanged, and uses no detached Hermes/model rewrite work.
- Static project/scheme scan confirmed the normal `Epistemos.xcscheme` build/run/archive entries point at `Epistemos-AppStore`, while `Epistemos-LegacyDev` and `Epistemos-Experimental` point at the quarantined legacy target.
- Static gate/source scan confirmed the KEELSTONE gate still checks bundled `JuneWeb/dist/index.html`, `JuneWeb/tauri-internals-shim.js`, prompt-upgrade/Hermes copy drift, and parked runtime residue (`ExperimentalWeb`, `OpenChamber`, `1Code`, `goosed`, `opencode`, `codex`, `node`, `bun`, `experimental-runtime`).
- `git diff --check -- Epistemos/JuneAgent/JuneAgentGateway.swift Epistemos/Engine/EpistemosSpeechSynthesizer.swift Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift Epistemos/Views/Epdoc/EpdocEditorChromeView.swift Epistemos/Views/Notes/MarkdownDocumentSurface.swift docs/plans/keelstone/INTENT_LEDGER.md` passed with no whitespace errors.

### Verification debt

- No xcodebuild test/build/archive was run for this checkpoint because the owner paused live app testing while using the laptop. The exact focused MAS tests to run after `go back` are:
  `AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()`,
  `AppStoreKeelstoneLaneTests/appStoreLaneDisablesSystemPromptForgeRuntimeComposition()`,
  `AppStoreKeelstoneLaneTests/appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()`,
  and `AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()`.
- Exact MAS archive/gate/scan must be rerun after these source edits.
- Manual proof remains blocked until `go back`: June send must produce either answer text or the new visible error; voice must be tested audibly in English from the exact MAS archive.

## Checkpoint 2026-07-09 Epdoc Clean Reactivation Probe De-duplication

### Verbatim owner issue excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

> one bad thing i noticed is that th epdoc takes a long tme to load ... transition from one surface to epdoc makes the epdoc lose uts rich tables and formattig ... changing from views makes the epdco copy instead of just rerenderi t in epdoc.

### Interpreted intent

- Keep the blank-Epdoc recovery path, but do not make every clean surface switch pay a full JS snapshot/probe cost after the editor has already proven it is nonblank for the same host Markdown.
- Preserve rich Tiptap/table state: normal clean switches should reuse the mounted editor and avoid unnecessary reloads or snapshot churn.

### Source patch

- `EpdocEditorChromeController` now tracks `verifiedCleanReactivationMarkdown`.
- `requestCleanReactivationMarkdownProbe(expectedMarkdown:)` refuses repeated probes for the same unchanged host Markdown once a previous clean reactivation returned any non-empty Markdown snapshot.
- The verified key is the host Markdown, not the serialized probe bytes, because Tiptap can normalize table separator rows (`| - | - |` to `| --- | --- |`) while still proving the WebView is not blank.
- The verified cache is cleared on initial load, WebView dispatch detach/remount, WebContent process recovery, re-push recovery, and real user content changes.
- Existing stale/blank recovery remains intact: first clean reactivation can still issue `.flushDocumentSnapshot`; empty probe result still re-pushes the non-empty host Markdown and suppresses save/writeback.

### Source-only checks run under owner pause

- Added MAS regression `appStoreLaneSkipsRepeatedCleanEpdocReactivationProbeAfterVerifiedSnapshot()`.
- Added shared regression `verifiedCleanMarkdownDocumentSurfaceReactivationSkipsRepeatedSnapshotProbe()`.
- Both regressions use normalized table Markdown as the probe result to guard against byte-equality cache bugs.
- `git diff --check -- Epistemos/Views/Epdoc/EpdocEditorChromeView.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift EpistemosTests/EditorProvenanceStoreTests.swift` passed with no whitespace errors.
- `rg` verified `verifiedCleanReactivationMarkdown`, the new MAS regression, and the new shared regression are present.

### Verification debt

- Focused xcodebuild tests were not run because the owner has not typed `go back`.
- After `go back`, run at minimum:
  `AppStoreKeelstoneLaneTests/appStoreLaneProbesStaleEpdocStatsAndSuppressesBlankReactivationSnapshots()`,
  `AppStoreKeelstoneLaneTests/appStoreLaneSkipsRepeatedCleanEpdocReactivationProbeAfterVerifiedSnapshot()`,
  `AppStoreKeelstoneLaneTests/appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation()`,
  and `AppStoreKeelstoneLaneTests/appStoreLaneRepushesEpdocMarkdownAfterWebViewRemount()`.
- Manual exact-archive proof still required for Epdoc open/switching, rich table preservation, and no blank panel.

## Checkpoint 2026-07-09 Owner Pause: No Live Testing Until `go back`

### Verbatim owner steer excerpt

> stop testing it until i say go back go back u can resume what u were doing im trying to work on my laptop so when i type 'go back' resume literally everythign u were doig before this promot

### Interpreted intent

- Do not launch, focus, quit, screenshot, drive, or otherwise interact with the visible Epistemos app while the owner is using the laptop.
- Do not use stale or live app state as MAS evidence during this pause.
- Continue only source/static work that does not take over the app or produce live-app proof.

### Current constraint

- No xcodebuild/archive/manual MAS proof runs until the owner types `go back` or explicitly overrides this pause.
- Any source patches made under this pause must carry verification debt until focused tests and exact archive proof can run.

## Checkpoint 2026-07-09 Epdoc Blank Snapshot + Editor Hot-Path Source Patch

### Verbatim owner issue excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

### Interpreted intent

- Epdoc must not receive or preserve transient empty editor snapshots over a non-empty persisted note body during open, lens switch, or graph route transitions.
- Editing hot paths should keep immediate text local while delaying expensive save/reparse/table-overlay work enough to stop active typing stalls.
- Graph/editor fixes remain source-only until the owner types `go back`.

### Source patch

- `NoteDetailWorkspaceView.isSpuriousCleanEmptySnapshot(...)` now treats every empty snapshot over a non-empty persisted body as spurious, including during dirty/autosaving lens-switch states.
- `lensSwitchBody(...)` now falls back to the non-empty persisted baseline for those empty snapshots and logs the broader guard.
- `clearCleanModeBodySnapshotIfStale(...)` now clears an empty snapshot over a non-empty reloaded body even when the session is in a write state, while still preserving other dirty snapshots.
- `CodeEditorContentDebouncer.defaultQuietWindowMs` moved from `300` to `900` so code/source saves do not run during normal typing bursts; teardown flush remains immediate.
- `ProseTextView2.didChangeText()` now uses a dynamic large-document reparse debounce (`0.16s` for 20k-80k chars, `0.28s` for 80k+ chars) while preserving the explicit synchronous override when `reparseDebounceWindow == 0`.
- Rendered table overlay refresh moved from `120ms` to `220ms` to reduce table-heavy note churn during active typing.

### Source-only checks run under owner pause

- `git diff --check -- Epistemos/Views/Notes/NoteDetailWorkspaceView.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift Epistemos/Engine/CodeEditorContentDebouncer.swift Epistemos/Views/Notes/ProseTextView2.swift EpistemosTests/CodeEditorPolishTests.swift EpistemosTests/LocalReparseDebounceTests.swift EpistemosTests/NoteEditorLayoutTests.swift docs/plans/keelstone/INTENT_LEDGER.md` passed.
- `rg` verified the new empty-snapshot guard, dynamic prose reparse policy, 900ms code-save debounce, and 220ms table overlay refresh.
- A stale-string search found only the intentional negative source guard for the old `body.isEmpty && !persistedBody.isEmpty && !noteSession.state.needsWriteLease` pattern.

### Verification debt

- No focused xcodebuild tests were run because the owner has not typed `go back`.
- After `go back`, run focused tests covering `AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()`, `AppStoreKeelstoneLaneTests/appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState()`, `AppStoreKeelstoneLaneTests/appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount()`, `LocalReparseDebounceTests`, `CodeEditorPolishTests/defaultQuietWindowIs900()`, and `NoteEditorLayoutTests/topSpacingStaysTightBelowToolbar()`.
- Manual exact-archive proof remains required for Epdoc open/surface switching, graph node to editor latency, code/source editability, and table formatting preservation.

## Checkpoint 2026-07-09 Embedded Graph Startup Load Kick

### Verbatim owner issue excerpt

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

> graph embedded and hologram graph when i go to ndes it takes a long time to lead them up

### Interpreted intent

- Embedded-home graph startup must not depend on a previous floating-panel load or some later render-side rebuild.
- Opening the graph should start the same async graph load path as the mini-panel while keeping the UI responsive.

### Source patch

- `KnowledgeGraphShortcutDispatcher.openGraph(...)` now calls `ensureEmbeddedGraphLoadStarted(bootstrap:)` before flipping the home content to `.graph`.
- The helper resets graph state when there is no active vault, starts `graphState.loadGraph(container:)` on the existing utility task path when the graph is not loaded, and defers dirty structural refresh through `deferStructuralRefreshUntilGraphIsVisible()` when data is already loaded.
- This reuses `GraphState.loadGraph(container:)`; no synchronous GraphBuilder path was added to embedded graph startup.

### Source-only checks run under owner pause

- `git diff --check -- Epistemos/App/EpistemosApp.swift EpistemosTests/BackgroundGraphLoadingTests.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` passed.
- `rg` verified `ensureEmbeddedGraphLoadStarted`, `await graphState.loadGraph(container: modelContainer)`, and `graphState.deferStructuralRefreshUntilGraphIsVisible()` in source and guards.

### Verification debt

- No focused xcodebuild tests were run because the owner has not typed `go back`.
- After `go back`, run `BackgroundGraphLoadingTests/fragileGraphFirstOpenWiringKeepsAsyncBootstrapAndRecommitHooksIntact()` and `AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()`.
- Manual exact-archive proof remains required for embedded graph startup latency and graph node to editor latency.

## Checkpoint 2026-07-09 Vault Restore Must Win Over Repairable Local Body Cache Gaps

### Verbatim owner issue excerpt

> after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault. The app shows “Saved vault bookmark points to a missing or unreadable directory. Automatic vault restore was paused,” then notes/files lose source access and saves fail. Logs include “Cannot save page body: no vault URL.”

> vault keeps disconnecting eveyrtime i open it and it gies me weird warnign

### Interpreted intent

- MAS startup must restore the saved security-scoped vault bookmark before treating cached body/source gaps as unrecoverable.
- A retryable MAS bookmark preflight or repairable managed-body cache miss must not strand the app with `vaultSync.vaultURL == nil`.
- Startup integrity can still block on truly blocking bookmark failures such as stale or non-security-scoped bookmarks.

### Source patch

- `StartupIntegrityReport.shouldBlockAutomaticVaultRestore` now blocks on corrupted managed body samples only when no vault bookmark exists.
- When a vault bookmark exists and is not a blocking bookmark failure, startup integrity suppresses the corrupted-body toast segment so the user does not see “Automatic vault restore was paused” for a path the bookmark restore should repair.
- Existing source behavior already checks MAS startup bookmark readability while security-scoped access is active; this patch targets the remaining gate that could still prevent restore from running.

### Source-only checks run under owner pause

- Added shared regression `startupIntegrityLetsSavedVaultRestoreRepairNoteBodyVerificationFailures()`.
- Added MAS lane regression `appStoreLaneLetsSavedVaultRestoreRepairManagedBodyCacheGaps()`.
- `git diff --check -- Epistemos/App/AppBootstrap.swift EpistemosTests/WorkspaceSnapshotTests.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` passed.
- `rg` verified the new restore-over-cache-gap gate and regression names are present.

### Verification debt

- No xcodebuild tests, archive, app launch, log capture, or manual vault proof were run because the owner has not typed `go back`.
- After `go back`, run focused startup/vault tests including `WorkspaceSnapshotTests/startupIntegrityLetsSavedVaultRestoreRepairNoteBodyVerificationFailures()` and `AppStoreKeelstoneLaneTests/appStoreLaneLetsSavedVaultRestoreRepairManagedBodyCacheGaps()`.
- Exact MAS archive proof still required for vault `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`: select, quit archive app, reopen exact archive app, confirm no startup restore warning, confirm `vaultSync.vaultURL` is non-nil, and confirm saves do not log `no vault URL`.

## Checkpoint 2026-07-09 Graph Node Open Routes Note-Like Nodes To Real Editors

### Verbatim owner issue excerpt

> it also wont let me edit on code editor at all for some reason it just has me view it

> graph embedded and hologram graph when i go to ndes it takes a long time to lead them up and when i edit anythign in the graph hologram or embedded graoh they hang

### Interpreted intent

- Opening a document-like graph node should route into the canonical editable note workspace, not leave the user in a preview-only inspector.
- The preview inspector can remain read-only, but it must not be the only path for note-like graph node kinds.

### Source patch

- `GraphState.openNode(_:)` now routes `.person`, `.project`, `.topic`, `.decision`, `.event`, and `.resource` through `openNote(resolvedId)` with `.note`, matching `GraphSurfaceInlineEditability.opensInlineToday(...)`.
- `.folder` still routes to `openFolder(resolvedId)`.
- Non-editable graph artifacts still remain selected in the inspector.

### Source-only checks run under owner pause

- Updated MAS lane source guard in `appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()` to require the note-like case list and reject preview-only `.person`/`.resource` branches.
- `git diff --check -- Epistemos/Graph/GraphState.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` passed.
- `rg -F` verified the new note-like `openNode` case in source and guard.

### Verification debt

- No xcodebuild tests or manual graph interaction were run because the owner has not typed `go back`.
- After `go back`, run `AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()` plus manual exact-archive proof that embedded graph and hologram graph open note-like nodes into editable surfaces rather than preview-only inspector state.

## Checkpoint 2026-07-09 Kokoro Renderer English Voice Defense

### Verbatim owner issue excerpt

> the voice is not in english i need it to be in english if it is not an english model then idk why we are even using it.

> voice is in another lanugage big issue

### Interpreted intent

- MAS read-aloud must use English Kokoro voices only.
- A non-English voice pack must not be loadable through a lower-level renderer bypass, even if the settings picker and high-level synthesizer already filter it out.

### Source patch

- `KokoroCoreMLSynthesizer.renderRawText(...)` now accepts a selected voice embedding only when the requested identifier has an English Kokoro prefix: `af_`, `am_`, `bf_`, or `bm_`.
- Unknown or non-English IDs fall back to the checked starter English voice embedding.
- This complements the existing `EpistemosSpeechSynthesizer.installedEnglishKokoroVoices()` and `effectiveKokoroVoiceIdentifier(...)` filters.

### Source-only checks run under owner pause

- Updated MAS lane source guards to require `isEnglishKokoroVoiceIdentifier(voiceIdentifier)` in the CoreML renderer.
- `git diff --check -- Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` passed.
- `rg -F` verified the renderer-level English gate in source and guards.

### Verification debt

- No xcodebuild tests, archive launch, settings preview, log capture, or audible proof were run because the owner has not typed `go back`.
- After `go back`, run `AppStoreKeelstoneLaneTests/appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()` and exact-archive manual audible proof with Settings > Voice preview plus June/prose/epdoc/quick-capture read-aloud surfaces.

## Checkpoint 2026-07-09 Release Gate Witnesses For New MAS Regression Fixes

### Verbatim owner steer excerpt

> Treat this as a MAS data-loss/release blocker.

> voice is in another lanugage big issue

### Interpreted intent

- Vault restore/cache-gap and English Kokoro fixes should become release-gated MAS proof, not one-off source patches.
- The no-live-testing pause still applies; release proof remains static-only until the owner types `go back`.

### Source patch

- `scripts/keelstone-release-gate.sh` now includes a Kokoro English voice witness section requiring:
  - high-level Kokoro voice catalog filtering through `isEnglishKokoroVoiceOption`;
  - English-only voice resolution/logging;
  - Core ML renderer-level `isEnglishKokoroVoiceIdentifier(...)` validation;
  - `af_`, `am_`, `bf_`, and `bm_` English Kokoro voice prefixes;
  - the App Store lane `appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()` regression.
- The data-safety/upgrade witness section now requires:
  - `WorkspaceSnapshotTests/startupIntegrityLetsSavedVaultRestoreRepairNoteBodyVerificationFailures()`;
  - `AppStoreKeelstoneLaneTests/appStoreLaneLetsSavedVaultRestoreRepairManagedBodyCacheGaps()`.

### Source-only checks run under owner pause

- `git diff --check -- scripts/keelstone-release-gate.sh` passed.
- `bash -n scripts/keelstone-release-gate.sh` passed.
- `rg` verified the new release-gate witness strings.

### Verification debt

- The gate itself was not executed because full gate/archive proof is deferred until the owner types `go back`.
- After `go back`, run KEELSTONE source/bundle/archive gates as part of the MAS archive proof batch.

## Checkpoint 2026-07-09 Epdoc Clean Post-Load Blank Snapshot Guard

### Verbatim owner issue excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

### Interpreted intent

- Epdoc must not accept a transient clean empty Markdown snapshot after the initial load has settled when the host still has a non-empty Markdown source.
- The fix must preserve legitimate user deletion: a dirty editor may still save an empty document.

### Source patch

- `EpdocEditorChromeController.handleBridgeMessage(.markdownDidChange)` now detects a clean empty Markdown snapshot after initial echo handling.
- When the controller is not dirty and a non-empty host source exists, it logs `Epdoc clean Markdown snapshot was empty; re-pushing non-empty host Markdown source`, calls `reloadMarkdownSourceForCleanReactivation(...)`, and returns without invoking `onMarkdownChanged`.
- Added `preferredNonEmptyMarkdownSource()` so recovery falls back from an empty latest snapshot to the original non-empty host Markdown source.
- Added shared bridge regression `chromeControllerRepushesNonEmptyMarkdownSourceAfterCleanPostLoadBlankSnapshot()`.
- Added MAS lane regression `appStoreLaneRepushesEpdocMarkdownAfterCleanPostLoadBlankSnapshot()`.
- Added KEELSTONE release-gate witness requiring the MAS lane regression.

### Source-only checks run under owner pause

- `git diff --check -- Epistemos/Views/Epdoc/EpdocEditorChromeView.swift EpistemosTests/EpdocEditorBridgeTests.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift scripts/keelstone-release-gate.sh` passed.
- `bash -n scripts/keelstone-release-gate.sh` passed.
- `rg` verified the new controller guard, shared regression, MAS regression, and release-gate witness.

### Verification debt

- No xcodebuild tests or exact-archive manual Epdoc proof were run because the owner has not typed `go back`.
- After `go back`, run the focused Epdoc bridge and App Store lane tests, then exact MAS archive proof for open/switch/reopen Epdoc table preservation and no blank document.

## Checkpoint 2026-07-09 June Shim No Canned Fallback Submit

### Verbatim owner issue excerpt

> june mas still is not rlly working it is not producing outputs and i cant tell if it even works

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work

### Interpreted intent

- MAS June send must use the native in-process gateway as the only product answer path.
- A missing host bridge must fail visibly; it must not generate a fake/canned success that can be mistaken for working MAS June.
- Per-message Prompt Forge remains disabled for normal send.

### Source patch

- Updated the canonical June fork shim at `/Users/jojo/dev/june-epistemos/epistemos/tauri-internals-shim.js`.
- Updated the current staged shim at `.june-web-stage/tauri-internals-shim.js`.
- Non-host `prompt.submit` now replies with error code `5030` and emits a visible error completion instead of streaming the old canned echo.
- `scripts/keelstone-release-gate.sh` now requires the visible host-mode failure message and rejects `Echo from the Epistemos in-process gateway bridge` in both staged and built App Store shims.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` now source-guards those release-gate witnesses.

### Source-only checks run under owner pause

- `git diff --check -- .june-web-stage/tauri-internals-shim.js scripts/keelstone-release-gate.sh EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` passed.
- `bash -n scripts/keelstone-release-gate.sh` passed.
- `node --check .june-web-stage/tauri-internals-shim.js` passed.
- `node --check /Users/jojo/dev/june-epistemos/epistemos/tauri-internals-shim.js` passed.
- `rg` verified the new host-bridge error string and no remaining canned echo in the checked shim paths.

### Verification debt

- No June web rebuild, App Store archive, exact archive launch, or manual send proof was run because the owner has not typed `go back`.
- After `go back`, rebuild/stage JuneWeb if needed, archive App Store, launch the exact archive app, and prove prompt submit routes through `JuneAgentGateway` with either streamed model output or the visible provider/model error.

## Checkpoint 2026-07-10 Source-Only Epdoc Reactivation And Kokoro English Picker Hardening

### Verbatim owner issue excerpt

> the epdoc is still going blank when i open n it or change to it and from it form ay other surfaces so that issue came back.

> the voice is not in english i need it to be in english if it is not an english model then idk why we are even using it.

### Interpreted intent

- Epdoc reactivation must not let an empty WebKit/bridge snapshot suppress recovery when the Swift host still has a non-empty Markdown source.
- MAS voice selection must not retain a stale Apple or non-English Kokoro ID in the visible picker; it must normalize back to the English default/starter path.
- The owner has not typed `go back`, so this checkpoint is source-only/static-only.

### Source patch

- `MarkdownDocumentSurfaceCoordinator` now uses `preferredNonEmptyRememberedMarkdown(hostMarkdown:)` for clean reactivation recovery/probe decisions, choosing from `controller.latestMarkdownSnapshot`, `latestMarkdown`, and the incoming host `markdown` instead of letting an empty `controller.latestMarkdownSnapshot` dominate.
- `MarkdownDocumentSurfaceCoordinator` now uses `visibleMarkdownSnapshotIsEmptyOverNonEmptyHost(_:)` for clean empty initial-load recovery.
- `EpistemosSpeechSynthesizer` now exposes `normalizedEnglishKokoroVoiceIdentifier(_:installedVoices:)`.
- `ModelVoicePickerSection.refreshVoicesAndHints()` now loads `installedEnglishKokoroVoices()`, calls `normalizeBoundVoiceIdentifier(against:)`, and clears stale non-English/Apple IDs to `nil` so the shipped English default path wins.
- Updated source guards in `SSQCGlobalVoiceTests`, `VoiceCodepackPlan3Tests`, and `AppStoreKeelstoneLaneTests` to protect the English-only picker and normalizer.

### Source-only checks run under owner pause

- `git diff --check -- Epistemos/Views/Notes/MarkdownDocumentSurface.swift Epistemos/Engine/EpistemosSpeechSynthesizer.swift Epistemos/Views/Shared/ModelVoicePickerSection.swift EpistemosTests/EpdocEditorBridgeTests.swift EpistemosTests/KokoroVoiceSelectionTests.swift EpistemosTests/SSQCGlobalVoiceTests.swift EpistemosTests/VoiceCodepackPlan3Tests.swift EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` passed.
- `bash -n scripts/keelstone-release-gate.sh` passed.
- `rg` confirmed no remaining `controller.latestMarkdownSnapshot ?? latestMarkdown` in the Epdoc coordinator and no remaining `EpistemosSpeechSynthesizer.installedKokoroVoices()` source-guard expectations in the touched picker guards.
- `rg` verified the new regression/source-guard symbols:
  - `markdownDocumentSurfaceReactivatesFromNonEmptyHostWhenWebKitSnapshotWasEmpty`
  - `appStoreLaneRecoversHiddenEpdocWhenWebKitSnapshotIsEmptyButHostMarkdownIsNonEmpty`
  - `normalizesStalePickerSelectionsToEnglishKokoroVoices`
  - `normalizeBoundVoiceIdentifier`
  - `normalizedEnglishKokoroVoiceIdentifier`

### Verification debt

- No xcodebuild tests, archive, app launch, screenshot, or audible/manual proof were run because the owner has not typed `go back`.
- After `go back`, run focused Epdoc and Kokoro tests, rebuild/archive AppStore, and prove exact-archive Epdoc switching plus English Kokoro preview/read-aloud behavior.

## Checkpoint 2026-07-10 Clean Prompt 2 Continuation Authorization

### Verbatim owner steer excerpt

> OWNER AUTHORIZATION: This is a new agent session. Resume all in-scope source work, tests, builds, exact MAS archive launches, and manual/runtime verification now. The previous “wait until go back” pause is lifted for this session. ID: EPISTEMOS-MAS-PROMPT2-CLEAN-CONTINUATION-2026-07-10

> Continue the Epistemos MAS plan autonomously from the current verified repository state. This is a clean continuation of Prompt 2, not a request to restart old plans or blindly repeat completed work.

> Prompt 2—KEELSTONE storage and MAS release gate—is active and incomplete.

> If a standalone “go back” was not provided before this prompt, do not launch, focus, quit, screenshot, click, type into, or otherwise control Epistemos. Continue source-only work and static verification. If “go back” was provided, runtime and exact-archive verification are authorized within this scope.

### Interpreted intent

- Resume the MAS-only Prompt 2 cursor from current repository truth. Reconcile the existing Epdoc, Kokoro, vault, graph, editor, and June patches before making any new implementation change.
- Prompt 1 receives only a lightweight source/settings revalidation. Prompt 3, LumenLens expansion, Reckoner, June/MiniChat expansion, and the capability ring remain out of scope.
- The session-level authorization explicitly reopens non-interactive source checks, focused tests, builds, archive construction, release gates, and bundle scans. Because no standalone `go back` appears before the objective, the later and more specific condition still withholds app launch/control and manual/runtime UI proof.

### Hard constraints

- Active product only: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`, MAS/June, in-process `agent_core`, native Swift/AppKit/SwiftUI, bundled WKWebView assets, Keychain secrets, and security-scoped vault access.
- Preserve the extremely dirty owner/agent/generated worktree. Do not reset, revert, discard, broadly reformat, stage, commit, or overwrite unrelated work.
- Read each target and its diff before editing; use surgical test-first changes when behavior must change; never run competing `xcodebuild` jobs.
- Do not revive Pro, Developer-ID, Experimental, 1Code, OpenChamber, Goose runtime, Kindred runtime, terminal/code-exec, stdio MCP, Node/Bun backend, local server, subprocess, hidden sidecar, or duplicate authority lanes.
- Do not launch, focus, quit, screenshot, click, type into, or otherwise control Epistemos without a fresh standalone `go back`.

### Non-goals

- No restart of Prompt 1 reporting or older prompt stacks.
- No Prompt 3/LumenLens/Reckoner/capability-ring implementation.
- No release-ready, fixed, or Prompt 2 complete claim from source guards, compilation, tests, archive construction, or old runtime evidence alone.
- No broad dirty-state cleanup, staging, commit, or parked-lane resurrection.

### Acceptance checks

- Current base and App Store schemes resolve to `Epistemos-AppStore` with bundle ID `com.epistemos.appstore`, App Store entitlements, and only the expected MAS compile conditions.
- Focused MAS tests pass for the current Epdoc blanking/fidelity guards, English Kokoro selection, vault restore/cache-gap behavior, graph routing/startup, editor editability/hot paths, and literal June send/no Prompt Forge path.
- JuneWeb source and staged shim are syntax-clean and synchronized when their source differs; the App Store Release archive contains the required JuneWeb assets.
- KEELSTONE release gate and App Store bundle scan pass against a fresh current archive with parked runtime residue absent.
- Exact-archive manual evidence remains explicitly HIGH OPEN until standalone `go back` authorizes control: vault restore/save, Epdoc rich fidelity, editor/code/graph responsiveness and editability, audible English Kokoro, and real June output or precise visible provider/model failure.

### Contradictions/questions

- The opening authorization says exact archive launches and manual/runtime verification resume now, while the later conditional says not to control Epistemos unless a standalone `go back` preceded the prompt. The conservative resolution is to allow non-interactive tests/build/archive/gate/scan work but withhold app launch and manual UI control.
- `EpistemosTests` remains hosted by the quarantined legacy target and is not a testable in the MAS schemes; the dedicated `EpistemosAppStoreKeelstoneTests` lane is the current MAS proof root. Shared tests may require a separate non-product host repair or explicit legacy-host invocation and must not be misrepresented as MAS archive proof.

### Reconciliation evidence before this checkpoint

- Branch `feat/goose-surface`, HEAD `0c7123ba442c959b23b87528d3fdff1560320498`; branch name remains historical only.
- `git diff --check` passed for `MetalGraphView.swift`, `GraphState.swift`, `AppStoreKeelstoneLaneTests.swift`, and `GraphWorkspaceRouteTests.swift` after the latest graph routing patch.
- Both `Epistemos` and `Epistemos-AppStore` Release build settings resolve to target `Epistemos-AppStore`, product `Epistemos`, bundle ID `com.epistemos.appstore`, `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos-AppStore-Info.plist`, and compile conditions `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- Current source contains `preferredNonEmptyRememberedMarkdown(hostMarkdown:)`, `visibleMarkdownSnapshotIsEmptyOverNonEmptyHost(_:)`, `normalizedEnglishKokoroVoiceIdentifier`, picker-level English normalization, vault restore-over-cache-gap guards, literal `prompt.submit`, and the graph context/open-edit route through `GraphState.openNode(_:)`.

### Verification debt opened for this continuation

| Deferred/evidence command | Touched surfaces | Risk reason | Expected proof | Checkpoint trigger |
| --- | --- | --- | --- | --- |
| Focused `Epistemos-AppStore` test batch for Epdoc/Kokoro/vault/graph/editor/June | Current source-only patches and final graph route | Latest graph patch and July 10 fixes were not compiled/tested together | Selected MAS Swift Testing cases pass under App Store flags | Immediate, before any new behavior patch |
| `bash -n`, `node --check`, JuneWeb source/stage comparison | Release gate and JuneWeb shim | Staged bundle can drift from canonical fork/source | Syntax-clean and either identical or rebuilt/staged | Before archive |
| Fresh `Epistemos-AppStore` Release archive + KEELSTONE gate + bundle scan | Current dirty MAS product source | Old archive predates latest graph/Epdoc/Kokoro changes | Archive succeeds, required JuneWeb exists, gates/scans pass | After focused tests and any necessary fixes |
| Exact archive launch/manual/log proof | All HIGH owner-visible blockers | Explicit standalone `go back` is absent | Log-correlated manual evidence for every Prompt 2 HIGH blocker | Only after standalone `go back` |

### Next action

Run the narrow focused MAS test batch for the already-patched Epdoc, Kokoro, vault restore, graph routing/startup, editor editability/hot paths, and June literal-send paths. Diagnose and surgically fix only concrete failures before broadening to JuneWeb synchronization and a fresh Release archive/gate/scan.

## Checkpoint 2026-07-10 Privacy Manifest Hardening And Fresh Static Archive Proof

### Owner steer preserved

> Continue the Epistemos MAS plan autonomously from the current verified repository state. This is a clean continuation of Prompt 2, not a request to restart old plans or blindly repeat completed work.

> If a standalone “go back” was not provided before this prompt, do not launch, focus, quit, screenshot, click, type into, or otherwise control Epistemos. Continue source-only work and static verification.

### Interpreted intent

- Complete every safe non-interactive Prompt 2 verification step, repair
  concrete MAS release defects test-first, and preserve manual exact-archive
  blockers honestly until app control is authorized.
- Treat current Apple privacy requirements as release truth and bind the
  shipping manifest, source tests, user disclosure, and exact artifact gate to
  the same required-reason API posture.

### Hard constraints and non-goals

- MAS-only locks and the dirty-worktree preservation rules remain unchanged.
- No Epistemos launch/control, no external submission, no credential change,
  no Prompt 3 work, and no Prompt 2 completion or release-ready claim.

### Concrete finding and correction

- Official Apple required-reason documentation distinguishes `C617.1` for
  timestamps in the app's container from `3B52.1` for files or directories the
  user specifically grants access to.
- Current source reads modification-date metadata in user-selected vaults, but
  `Epistemos/Resources/PrivacyInfo.xcprivacy` declared only `C617.1`.
- Added a dedicated MAS regression that parses the FileTimestamp category and
  requires exactly `C617.1` plus `3B52.1`. It failed first with one issue in a
  55-test suite, then passed after the correction.
- Updated the manifest, shared hardening expectation, category-bound source
  and built-artifact release gate, Privacy Settings copy, current release/audit
  canon, and release-audit materializer.

### Acceptance evidence

- Focused MAS batch: 12/12 passed at
  `build/xcode-results/2026-07-09-223559-9817.xcresult`.
- Privacy red: 54 passed and the new test failed as intended at
  `build/xcode-results/2026-07-09-225422-37418.xcresult`.
- Privacy green: 55/55 passed at
  `build/xcode-results/2026-07-09-225835-42832.xcresult`.
- Source KEELSTONE gate passed; the MAS release-audit Rust materializer
  compiled; plist/shell/diff checks passed.
- Negative artifact falsifier passed: the strengthened gate rejected the
  immediately preceding archive specifically for missing FileTimestamp reason
  `3B52.1`.
- Fresh archive:
  `build/appstore-release-archive-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100.xcarchive`.
- The exact archived app passed KEELSTONE, the App Store bundle scan, deep
  strict signature verification, effective entitlement review, quarantine
  review, and bundled privacy-manifest comparison.
- Bundle scan reports:
  `build/visible-mas-proof-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100`.

### Contradictions/questions and remaining debt

- No new owner contradiction arose. The standalone `go back` condition still
  overrides the opening runtime authorization for UI control.
- Static/archive Prompt 2 evidence is current, but all manual HIGH blockers
  remain open: vault restore/save, Epdoc rich fidelity, editor/code/graph
  responsiveness, audible English Kokoro, visible MAS/June base product, and
  real June output or precise provider/model error with no prompt rewriting.

### Next action

When a standalone `go back` authorizes app control, launch only the exact fresh
archive above and execute the manual HIGH-blocker matrix with log-correlated
evidence. Until then, do not represent Prompt 2 as complete or advance to
Prompt 3.

## Checkpoint 2026-07-10 Autonomous Master-Plan Continuation

### Owner steer preserved verbatim

> neve stop if u ever get done with one part of the plan just move to the next prompt in that large plan dir etc. reactivate goals as needed as well to wrk completely autonomously.

### Interpreted intent

- Keep the MAS-only program active without waiting for a new prompt after each
  completed phase: finish the current prompt to its real done bar, select the
  next dependency-eligible prompt from the master plan, and continue.
- Reactivate the Codex goal when needed so a stale blocked checkpoint cannot
  become an artificial stopping condition.
- Apply the deep-hardening loop inside each prompt: resolve the most important
  open risk, verify it, update evidence, and immediately select the next useful
  unit of work.

### Hard constraints

- `MAS-ONLY-SHIP-LOCK-2026-07-07` and
  `OWNER-INTENT-HARDENING-LOCK-2026-07-07` remain controlling.
- Prompt 2 remains the active dependency gate. Prompt 3 starts only after the
  Prompt 2 acceptance bar is actually evidenced, not because a source slice or
  archive gate passed.
- Preserve the dirty worktree; read before writing; work test-first; edit
  surgically; never run competing `xcodebuild` jobs.
- This steer is not the standalone `go back` control token. Do not launch,
  focus, quit, screenshot, click, type into, or otherwise control Epistemos.

### Non-goals

- No parked Pro, Developer-ID, Experimental, 1Code, OpenChamber, Goose runtime,
  Kindred runtime, subprocess, local-server, terminal/code-exec, or stdio-MCP
  work.
- No blind march into later prompts while a dependency or release blocker is
  still open.
- No claim that owner-visible behavior is fixed from source, unit, build, or
  archive evidence alone.

### Acceptance checks

- The Codex goal is active with the ongoing MAS master-plan objective.
- Each hardening slice begins from current canon/code/evidence, has a falsifier
  or failing test when behavior changes, and records exact proof plus remaining
  debt.
- Prompt 2 retains the HIGH manual matrix until exact-archive/log-correlated
  evidence closes vault, Epdoc, editor/code/graph, Kokoro, base-product, and
  June-send behavior.
- When Prompt 2 reaches its complete done bar, immediately load the next
  dependency-eligible master prompt and repeat the same evidence loop.

### Contradictions/questions

- “Move to the next prompt” applies after a part is genuinely done. It does not
  override the master dependency rule or convert the current static archive
  proof into manual product proof.
- The exact app-control condition remains unmet, so safe source/static work is
  the only authorized lane for this cycle.

### Next action

Audit the highest-risk safe Prompt 2 seam still named by the current evidence:
the file-first body-save path's synchronous `BlockMirror.sync` work. Ground the
cost in canon, callers, tests, actor/thread ownership, and current diffs; add a
failing regression or measurement before making the smallest canonical fix.

## Checkpoint 2026-07-10 Continuous Loop Reinforcement

### Owner steer preserved verbatim

> like i said please stop stopping just continue the loop idk what u hae to do to keep the loop going justkep it going

### Interpreted intent

- Keep the active MAS goal and deep-hardening loop running across successive
  Prompt 2 units without yielding merely because one audit item is closed.
- When a candidate defect proves stale or already fixed, correct the evidence
  and immediately select the next highest-risk dependency-eligible unit.

### Constraints, non-goals, and acceptance

- Existing MAS-only, read-first, test-first, dirty-worktree, dependency-order,
  and standalone-`go back` app-control boundaries remain unchanged.
- Do not manufacture evidence or advance to Prompt 3 while Prompt 2's manual
  HIGH matrix remains open.
- Acceptance for this steer is continuous useful progress: every closed item
  records proof and is followed by the next grounded audit/fix/verification
  cycle without a user prompt.

### Reconciliation and next action

- Current source and MAS guards prove the previously named inline
  `BlockMirror.sync` debt is stale: `savePageBodyFileFirst` schedules the
  coalescing `BlockMirrorSyncCoordinator` after the vault export and metadata
  save, and the current MAS suite compiled that guard.
- The 10k/100k perf JSON cannot yet be produced honestly because the repo has a
  consumer but no producer, and several metrics require authorized app runtime.
- Continue immediately by auditing synchronous derived-state, title, Spotlight,
  and model-context work that remains in the canonical file-first save
  completion path; test and fix only a concrete bottleneck.

## Checkpoint 2026-07-10 Full-Plan Runtime Authorization

### Owner steer preserved verbatim

> and i mena beyo just go back like i am ot llaing the keyword shit anymroe stop sahing i ned to type go back i not typingthat shit just do the full plan

### Interpreted intent

- Remove the special-keyword requirement completely. The owner explicitly
  authorizes the agent to continue the full MAS plan, including launching and
  controlling Epistemos for exact-archive manual/runtime verification.
- Do not mention, request, or wait for a standalone control token again.
- Keep working autonomously through the Prompt 2 HIGH matrix and subsequent
  dependency-eligible prompts.

### Hard constraints and non-goals

- MAS-only architecture, dependency order, evidence honesty, dirty-worktree
  preservation, read-first/test-first edits, and no competing `xcodebuild`
  remain controlling.
- Use only the exact current archived MAS app for Prompt 2 runtime evidence;
  stale Debug/DerivedData/direct-lane apps are not proof.
- Use a disposable test vault or reversible test note for destructive checks;
  do not submit, publish, change credentials, or mutate unrelated user data.
- No Prompt 3 work until the Prompt 2 manual, automated, distribution, and
  repeated-zero-fail bars close.

### Acceptance checks

- Launch the exact current archive and prove visible MAS/June base identity.
- Exercise security-scoped vault select/restore/save, Epdoc rich fidelity,
  Prose/Source/Code/Quick Capture/graph editability and responsiveness, audible
  English Kokoro, and June literal send with correlated logs.
- Fix concrete failures test-first, rebuild the exact archive after source
  changes, reset the zero-fail counter, and repeat.

### Next action

Load the native computer-control workflow, launch the exact archived
`com.epistemos.appstore` product, capture initial UI/process/log evidence, and
begin the HIGH matrix with base-product identity and vault selection/restore.

## Checkpoint 2026-07-10 Source Rename Remount Falsifier

### Owner intent carried forward

- Continue the full MAS plan autonomously without a special control keyword or
  a pause after each hardening unit.
- Keep Prompt 2 open until exact-archive runtime evidence, not only source or
  automated checks, proves the affected editor path stable.

### Exact evidence

- The canonical-snapshot source regression passed, the adjacent file-first
  rename regression passed, and the full MAS suite passed 57/57.
- Fresh exact archive:
  `build/appstore-release-archive-2026-07-10-prompt2-source-canonical-snapshot-20260710-014400.xcarchive`.
- The archive passed deep strict signature verification, MAS entitlements,
  privacy-manifest byte comparison, KEELSTONE, and the standalone bundle scan.
- In the exact archived app, a new Source note with page id
  `7F85F15C-C43F-4F17-9F44-21A98F35C47F` and probe UUID
  `d8aa6d73-80ec-419e-ba18-29a618103b46` renamed once to
  `Codex Prompt 2 Canonical Snapshot Pass 2026-07-10.md`, then blanked after
  the timed settle.
- Disk stayed singular and canonical, while the app held about 1.37 GB RSS and
  about 105% CPU. Filtered logs showed a same-path rename plus paired
  `ShadowIndexingService` code-3 failures every roughly 350 ms.

### Revised diagnosis and acceptance

- Rebuilding the parent Source snapshot after save is necessary but
  insufficient.
- `CodeEditorView` is keyed by `page.id` plus the mutable Source path. The first
  title-derived file rename destroys the old editor, whose `onDisappear`
  immediately flushes its captured pre-rename text and path.
- `saveMarkdownSourceContent` then assigns that captured path back to
  `page.filePath`, allowing route identity and teardown flushes to feed each
  other even though the file-first writer keeps one canonical disk file.
- Acceptance now requires a stable editor identity across an in-place Markdown
  title rename, no reassignment from a stale captured path, one canonical file,
  a mounted Source surface after two timed revisions, settled CPU, and no
  repeating rename/shadow-error loop in the exact fresh archive.

### Next action

Add a failing MAS regression for stable Source identity and stale-path
rejection, then make the smallest source-route fix and repeat focused, full,
archive, distribution, and exact-runtime proof.

## Checkpoint 2026-07-10 Exact-Archive Epdoc Activation Falsifier

### Owner intent carried forward

- Continue the full MAS plan autonomously and do not pause after a completed
  hardening unit.
- Keep Prompt 2 open until the exact Release archive proves rich-document
  fidelity and responsiveness across Source, Document, and Prose transitions.

### Exact evidence

- Fresh archive
  `build/appstore-release-archive-2026-07-10-prompt2-source-rename-stable-identity-20260710-020800.xcarchive`
  passed deep signature verification, MAS entitlement review, privacy-manifest
  byte comparison, KEELSTONE, and the standalone bundle scan.
- In that exact archive, page `3DA442EE-ECAA-4A5F-976C-552EFF240137`
  survived two Source revisions with one canonical disk file and settled CPU.
- A third Source revision persisted heading, bold/italic text, a two-column
  Markdown table, a list, a quote, and marker
  `c4c365bc-a716-48d9-bf0a-b10a761137e9`.
- Switching directly to Document left Epdoc blank indefinitely. The visible
  editor reported `0 words 0 chars` and its placeholder remained visible after
  more than five seconds, while the host toolbar still estimated about 67
  tokens from the non-empty live Markdown.

### Interpreted diagnosis and constraints

- This is a Prompt 2 release blocker, not acceptable load latency: the host has
  the correct Markdown while the WKWebView never applies the activation load.
- The inactive Document surface dispatches Swift-to-JavaScript commands through
  a view-owned `CADisplayLink`. A display-linked batch can be starved while the
  view is transparent/occluded during the Source-to-Document state transition;
  the current unit tests intercept controller commands before this scheduler
  and therefore cannot falsify the runtime seam.
- Preserve one-shot batching and quiescent energy behavior. Do not add polling,
  a repeating timer, a per-frame allocation, or a remount workaround.
- Preserve clean-switch non-writeback and rich-table source fidelity.

### Acceptance checks

- A failing MAS regression first proves outbound Epdoc bridge batches have no
  non-display fallback when the display link cannot tick.
- The smallest scheduler fix guarantees a bounded one-shot main-runloop flush,
  cancels redundant scheduled work, and retains bridge-command ordering.
- Focused and full MAS suites pass; a new exact Release archive passes all
  static/distribution gates.
- The exact archive renders the rich table and formatting after Source to
  Document, survives Document/Prose/Source round trips without rewriting clean
  Markdown, accepts a real Document edit, settles CPU, and preserves one file.

### Next action

Add the deterministic scheduler regression, prove it red, then repair the
outbound bridge flush scheduler and repeat the full archive/runtime evidence
chain before advancing to the remaining Prompt 2 matrix.

## Checkpoint 2026-07-10 Exact-Payload Epdoc Parse Falsifier

### Owner steer preserved verbatim

> and i mena beyo just go back like i am ot llaing the keyword shit anymroe stop sahing i ned to type go back i not typingthat shit just do the full plan

### Interpreted intent

- Continue the full MAS plan autonomously; do not pause for a control keyword
  or after a single Prompt 2 hardening unit.
- Treat the exact-archive blank document as a release blocker and follow the
  evidence through the native/JavaScript seam until the real cause is fixed.

### Exact evidence and revised diagnosis

- The 50 ms outbound fallback passed its focused regression, the full MAS
  suite passed 59/59, and archive
  `build/appstore-release-archive-2026-07-10-prompt2-epdoc-outbound-fallback-20260710-023700.xcarchive`
  passed signature, entitlement, privacy, KEELSTONE, and bundle-scan gates.
- That exact archive still blanks after Source to Document: the host reports
  about 67 Markdown tokens while Epdoc remains at `0 words 0 chars`.
- The archive editor assets byte-match `js-editor/dist`. A real browser run of
  those exact assets and the exact vault payload reproduces the blank and logs
  `RangeError: Invalid content for node listItem: <blockquote(...)>`.
- The persisted source contains a CommonMark nested-quote list item (`- > ...`).
  Tiptap's list parser emits a blockquote as the first child, but its list-item
  schema requires a paragraph first. The inbound bridge catches and swallows
  the exception, leaving the whole document empty.
- The scheduler fallback was necessary hardening but not sufficient for this
  payload. Do not claim the runtime blocker fixed from its green tests.

### Hard constraints and non-goals

- Preserve the original Markdown as durable vault truth; do not silently
  rewrite the source merely to appease the editor parser.
- Keep standard list editing behavior and the paragraph-first list-item schema;
  avoid a broad schema relaxation unless focused evidence proves it necessary.
- Preserve rich headings, emphasis, tables, lists, and quotes. A plain-text
  downgrade is only a last-resort safety fallback, not the normal fix.
- Keep bridge failures observable and fail closed against empty autosave over a
  non-empty host source.

### Acceptance checks

- Add an exact-payload regression that fails because the nested-quote list item
  lacks the schema-required leading paragraph.
- Repair the list Markdown parse shape at the narrow parser seam and prove the
  exact payload produces a valid, non-empty document containing its heading,
  rich marks, list, and quote.
- Typecheck, rebuild/stage the editor bundle, run focused and full MAS checks,
  archive again, and repeat exact-archive Source/Document/Prose fidelity proof.

### Next action

Land and run the deterministic JavaScript regression first, then implement the
smallest parser-shape repair and validate it from source through the exact
signed MAS archive.

## Checkpoint 2026-07-10 Repaired-List Serializer Falsifier

### Owner intent carried forward

- Continue the full plan autonomously and keep Prompt 2 open until the exact
  archive proves both visible fidelity and data-safe writeback.

### New evidence

- The exact nested-quote fixture now passes the paragraph-first schema
  regression and renders all expected blocks in a fresh real-browser editor.
- The repaired document's `window.epistemos.getMarkdown()` returns an empty
  string even though its visible ProseMirror document is non-empty.
- Therefore parser validity alone is insufficient: the inherited list-item
  Markdown renderer does not serialize the synthetic leading empty paragraph
  plus nested block shape. Shipping this intermediate state could expose a
  formatting/data-loss path on the next real edit.

### Constraints and acceptance

- Do not accept visible rendering with empty Markdown writeback.
- Preserve the nested list/quote structure and marker; do not flatten the
  entire document to visible plain text.
- Add a deterministic red serialization assertion before changing the custom
  list-item renderer.
- The repaired fixture must serialize non-empty Markdown, parse again to a
  schema-valid fixed point, and retain the nested quote text.

### Next action

Prove the empty serializer result in the JavaScript check, then make the custom
list-item renderer omit only its synthetic leading paragraph when delegating to
Tiptap's canonical list renderer.

## Checkpoint 2026-07-10 Custom Document Renderer Correction

### Corrected diagnosis

- The standalone Markdown manager serializes the repaired nested-list fixture
  successfully, so the preceding list-renderer hypothesis is falsified.
- The live editor differs because it disables StarterKit's standard Document
  node and installs `EpdocSuggestionDocument`. That custom top node copies the
  schema fields but omits the standard Document node's `renderMarkdown`
  contract, causing the Markdown manager to serialize every live document as
  empty regardless of list content.
- This is a separate pre-existing loss seam exposed by the exact-payload run;
  do not add a redundant list renderer workaround.

### Acceptance and next action

- Reconfigure the deterministic Markdown test with the live custom Document
  extension and prove serialization red.
- Make the suggestion-aware Document extend Tiptap's canonical Document node so
  it inherits the upstream Markdown renderer while changing only the allowed
  suggestion marks.
- Keep the nested-list parser repair; both fixes are required for exact payload
  render plus non-empty writeback.

## Checkpoint 2026-07-10 Ordinary Blockquote Semantic-Drift Falsifier

### Owner intent carried forward

- Continue the full MAS plan autonomously without a control keyword or a pause
  after one hardening unit.
- Keep Prompt 2 open until real archived-app edits preserve document meaning,
  not merely visible text and a non-empty serializer result.

### Exact archive evidence

- Fresh archive
  `build/appstore-release-archive-2026-07-10-prompt2-epdoc-markdown-contract-20260710-030800.xcarchive`
  passed strict signature, MAS entitlement, universal-binary, privacy-manifest,
  KEELSTONE, and standalone App Store bundle-scan checks.
- Its real Document surface renders the previously fatal heading, table,
  nested list, and nested ordinary blockquote. A live edit changes the status
  from `0 words 0 chars` to `39 words 221 chars` and persists marker
  `7c6d476f-52f2-4f8d-908f-517bcb4838df` to the one canonical vault file.
- Frontmatter and rich blocks survive, but the ordinary Markdown blockquote is
  silently rewritten as an `[!INFO]` callout on the first Document edit.
  This is semantic drift, not acceptable normalization.

### Constraints and acceptance

- Preserve explicit Epistemos callouts such as `> [!NOTE]`, while keeping an
  ordinary `> quote` ordinary across parse, edit, serialize, and reparse.
- Do not flatten the nested list/quote or weaken list-item schema validation.
- Add a deterministic red fixed-point assertion before changing extension
  ownership. The exact archive fixture must serialize without a synthetic
  callout marker and reparse without a `callout` node.
- Rebuild the editor, rerun JavaScript and native checks, then repeat the real
  archive edit/save proof before advancing Prompt 2.

### Next action

Prove the ordinary-quote drift red in the exact-payload Markdown regression,
then separate ordinary blockquote and callout Markdown renderer ownership at
the narrow extension seam.

## Checkpoint 2026-07-10 Prose Self-Write Conflict-Copy Falsifier

### Owner intent carried forward

- Continue the MAS-only master plan autonomously without a control keyword or
  a pause after one hardening unit.
- Keep Prompt 2 open until exact-archive edits are singular, durable, and safe
  across Source, Document, and Prose; do not count a visibly successful edit
  if the vault reconciler manufactures a false conflict.

### Exact archive evidence

- Fresh archive
  `build/appstore-release-archive-2026-07-10-prompt2-epdoc-blockquote-fidelity-20260710-032900.xcarchive`
  passed 59/59 MAS tests, strict signature, MAS entitlement, universal-binary,
  privacy-manifest, KEELSTONE, and standalone bundle-scan checks.
- Its exact signed app preserved frontmatter, heading, table, nested list,
  ordinary blockquote, and both Document edit markers through Document to
  Source to Document to Prose reactivation.
- The Document reactivation visibly loaded all rich content but still reported
  `0 words 0 chars`; this remains a separate stale-statistics blocker.
- A real Prose edit appended marker
  `5b0eebd8-7b0d-4e72-8bd2-10f5d71da1b5`, persisted the marker without an
  `[!INFO]` rewrite, and kept the rich Markdown intact.
- Seven seconds after the canonical save, the running archive created an
  identical sibling named
  `Codex Prompt 2 Stable Identity Archive Pass 2026-07-10-external-conflict-19c981cceaea.md`.
  Both files were 606 bytes and had the same full SHA-256 digest
  `19c981cceaea952496a65d40ab423d54deefd50980b3da031c10bfe258f40ee1`.

### Revised diagnosis and constraints

- `VaultIndexActor.upsertPage` classifies a live editor as dirty by comparing
  its body hash only with the actor context's stored `lastSyncedBodyHash`.
  The file-first save updates the main context after the actor writes the file;
  a later FSEvents reconciliation can therefore see a stale actor-context hash
  even when the live editor body is byte-for-byte identical to the incoming
  disk body.
- An editor body identical to the incoming disk body cannot be an external-edit
  conflict. That equality must win before comparing either side with the older
  base hash.
- Preserve genuine dirty-local versus changed-remote conflict copies. Do not
  disable reconciliation, lengthen a timing window, ignore external events, or
  weaken the existing never-clobber policy.

### Acceptance checks and next action

- Add a deterministic failing MAS regression proving an identical live editor
  and incoming disk body is not a conflict even when the stored base hash is
  stale, while a genuinely divergent live body remains a conflict.
- Extract the smallest pure conflict predicate at the existing comparison seam,
  make the regression green, rerun focused and full MAS checks, rebuild a fresh
  Release archive, and repeat a real Prose edit with exactly one canonical file.
- Then return to the stale initial Document statistics blocker and continue the
  remaining Prompt 2 surface/product matrix.

## Checkpoint 2026-07-10 Markdown Document Status Rollback Falsifier

### Owner intent carried forward

- Continue Prompt 2 autonomously through real archived-app evidence; a rich
  document that renders while its visible status reports zero is not complete.
- Keep fixes test-first, narrow, and evidence-backed without pausing the larger
  MAS-only plan.

### Exact runtime and browser evidence

- The signed blockquote-fidelity archive loaded the complete exact note after
  Source to Document reactivation but settled at `0 words 0 chars`.
- The same staged `editor.html` and bundle, run in headed Chrome with a mocked
  WKWebView message handler, emitted the following for the exact vault payload:
  one batch containing `loadSettled(epoch: 1)` followed by
  `documentStatsChanged(epoch: 1, wordCount: 42, characterCount: 475)`, plus
  two later identical statistics messages. The live editor storage also
  reported 42 words and 475 characters.
- Therefore JavaScript parsing, CharacterCount storage, message payloads, and
  load epoch are correct. The zero is introduced after those messages reach
  native state.

### Revised diagnosis and constraints

- `EpdocEditorChromeController.flushInitialContentIfPossible()` schedules a
  250 ms `scheduleInitialStatusRefresh(for:)` using `initialContentJSON`.
- Markdown Document surfaces intentionally pass an empty placeholder JSON while
  loading the real content through `markdownSource`. The delayed fallback runs
  after the correct bridge statistics and unconditionally recomputes the status
  from that empty placeholder, rolling the visible count back to zero.
- Preserve the delayed JSON fallback for package/JSON loads and preserve empty
  document behavior. Do not add polling, timers, or a second Markdown parser.
  A delayed fallback may update counts only while no nonzero live statistics
  have arrived.

### Acceptance checks and next action

- Add a deterministic failing MAS controller regression that delivers nonzero
  bridge statistics for a Markdown load, waits beyond 250 ms, and proves those
  live counts must not be replaced by the empty placeholder JSON.
- Add the smallest guard to the existing delayed fallback, rerun the focused
  conflict and status tests, then run the full MAS suite and fresh archive
  evidence for both blockers together.

## Checkpoint 2026-07-10 Self-Write Reconciliation Notification Falsifier

### Owner intent carried forward

- "just do the full plan" and continue autonomously without requiring a
  keyword or pausing after one hardening unit.
- Keep Prompt 2 open until a real edit in the exact signed archive converges to
  one canonical vault file and the live editor remains on the saved body.

### Fresh-archive falsifier

- Archive
  `build/appstore-release-archive-2026-07-10-prompt2-conflict-stats-20260710-040400.xcarchive`
  passed 61/61 MAS tests plus signature, sandbox-entitlement, universal-binary,
  privacy-manifest, KEELSTONE, and standalone bundle-scan checks.
- Its initial Document status remained nonzero, proving the delayed placeholder
  rollback repair in the signed runtime.
- A Prose edit persisted marker
  `86cc2d55-61fa-43c7-a2bd-438fb5a4d111`, but seven seconds later the app again
  created an identical conflict sibling. Canonical and sibling were both 678
  bytes with SHA-256
  `b9a15c42bd4464ed9c99b10edab1e54f2d40773852d2489d43c05817851b2002`.
- The live editor then exposed the pre-edit body while disk retained the saved
  marker. Unified logging recorded a deferred external body change immediately
  after the app's coordinated write, before the conflict-copy write.

### Revised diagnosis, constraints, and acceptance

- The background actor can retain both stale `needsVaultSync`/draft state and a
  stale base hash after the main-context file-first save. Even when the open
  live editor initially equals the new disk body, the stale draft branch still
  sets `preserveBody`; the non-conflict branch also emits an unnecessary body
  change whenever only actor metadata is stale.
- While a live editor body exists it is the current local authority; an older
  stored draft must not independently manufacture a conflict. If that live
  body equals the vault body, reconciliation must update tracking metadata
  without notifying the editor to reload.
- Preserve genuine live-versus-vault divergence, preserve draft protection
  when no live editor is available, and continue processing external events.
- Add a deterministic regression for stale draft precedence and same-body
  notification suppression, make it fail before the fix, then repeat focused,
  full-suite, fresh-archive, single-file, and live-body evidence.

## Checkpoint 2026-07-10 Repeated Self-Write Reload Falsifier

### Owner intent carried forward

- Continue the complete MAS-only plan autonomously; do not require a keyword
  or pause after an apparently green implementation unit.
- Prompt 2 remains open until the exact signed archive retains a Prose edit in
  the live editor and converges to one canonical vault file.

### Fresh evidence

- Focused self-write and path-identity regressions passed, and the complete MAS
  suite passed 61/61 in
  `build/xcode-results/2026-07-10-045200-prompt2-self-write-full-green.xcresult`.
- Repository source guards were moved into generated test-bundle fixtures after
  the MAS test host reproducibly blocked in a kernel `open(project.yml)` call;
  the isolated source guard then completed in 0.004 seconds.
- Fresh archive
  `build/appstore-release-archive-2026-07-10-prompt2-self-write-precedence-20260710-045452.xcarchive`
  passed strict signing, sandbox/bookmark entitlements, universal-binary,
  privacy-manifest, compressed-editor hash, KEELSTONE, and forbidden-runtime
  bundle-scan checks.
- Its Document surface loaded the complete rich payload and settled at
  `33 words 442 chars`, confirming the status rollback repair.
- A Prose edit appended marker
  `bd3e6ba5-a5c7-4129-a820-88c294ceea30` and advanced the visible count to 80
  words. After fourteen seconds the marker disappeared from the live editor,
  while both the canonical file and a newly created conflict sibling retained
  the marker as identical 751-byte files with SHA-256
  `b11d8729c220c17519f0d05d86056e08362a3e614a14cdc6cca57f46950381ad`.
- Unified logging again recorded
  `NoteDetailWorkspaceView: deferred external body change for dirty note session
  3DA442EE` during the self-write cycle.

### Contradiction and next action

- The pure `VaultIndexActor` predicates are green but do not model the full
  event chain that mutates or reloads the live editor. A second producer or a
  stale snapshot between the actor and `NoteDetailWorkspaceView` still emits a
  body-change notification, destabilizes the editor, and enables the following
  watcher pass to manufacture an identical conflict copy.
- Do not suppress FSEvents, lengthen debounce windows, or weaken genuine
  external-edit conflicts. Trace every `NoteFileStorage` body-change publisher,
  live-editor cache mutation, dirty-session deferral, and reconcile call using
  current source. Add the next regression at the first unmodeled transition,
  then rebuild and repeat the exact archive proof.

## Checkpoint 2026-07-10 Active First-Responder Precedence Falsifier

### Owner intent carried forward

- Continue the complete MAS-only plan autonomously without a control keyword
  or a pause between plan units.
- Keep Prompt 2 open until the exact signed archive retains a real Prose edit
  across watcher cycles and no identical conflict sibling is manufactured.

### Fresh red evidence

- The page-scoped live-body selector regression passed, and the full MAS lane
  passed 62/62 in
  `build/xcode-results/2026-07-10-051700-prompt2-live-body-full.xcresult`.
- Fresh signed universal archive
  `build/appstore-release-archive-2026-07-10-prompt2-live-body-selector-20260710-052000.xcarchive`
  passed strict signing, MAS entitlements, both privacy manifests, the exact
  compressed-editor hash, KEELSTONE, and standalone bundle scanning.
- In that exact archive, Prose marker
  `[archive-prose-live-body-selector:23e6e4f6-3fe2-48fb-b809-6cee6633f514]`
  first appeared in the live editor and canonical file. The watcher then made
  `Codex Prompt 2 Stable Identity Archive Pass 2026-07-10-external-conflict-bd1484b81281.md`.
  Canonical and sibling were identical 826-byte files with SHA-256
  `bd1484b81281ab2d710a75a6616c4e7e16dd46a36b06db6466cf0b3b6b69902d`.
- After the watcher cycle the live Prose editor reverted to its pre-edit body,
  while disk retained the marker. Unified logging recorded
  `NoteDetailWorkspaceView: deferred external body change for dirty note session
  3DA442EE` at 05:31:25.

### Revised contradiction, constraints, and next action

- Matching only `ProseTextView2.pageId` is still insufficient. The production
  manager recursively searches `window.contentView`, while the existing
  `NoteEditorViewFinder.findEditorTextView` path deliberately checks the
  window first responder before its hierarchy. A retained or hidden Prose view
  for the same page can therefore beat the actively edited view even though
  both have the correct page ID.
- Preserve page scoping and background-tab fallback, but make the active
  window first responder authoritative when it is an editable matching
  `ProseTextView2`. Do not fall back to an unrelated or wrong-page first
  responder.
- Add a deterministic red regression containing two same-page Prose views: a
  stale hierarchy-first view and a current first-responder view. Then expose
  the existing window-scoped finder path, route `NoteWindowManager` through it,
  rerun focused/full tests, and repeat the exact signed-archive replay.

## Checkpoint 2026-07-10 No-Keyword Full-Plan Continuation Lock

### Verbatim owner steer

> like i said please stop stopping just continue the loop idk what u hae to do to keep the loop going justkep it going

> and i mena beyo just go back like i am ot llaing the keyword shit anymroe stop sahing i ned to type go back i not typingthat shit just do the full plan

### Interpreted intent

- The earlier temporary `go back` interaction pause is explicitly revoked.
- Continue the MAS-only master plan autonomously through implementation,
  testing, signed-archive runtime proof, hardening, and subsequent prompts.
- Finishing a part is a transition to the next dependency-eligible unit, not a
  reason to stop or wait for another owner message.

### Hard constraints

- Preserve `MAS-ONLY-SHIP-LOCK-2026-07-07`: only `Epistemos-AppStore`, June,
  in-process `agent_core`, native Swift/AppKit/SwiftUI, bundled WKWebView
  assets, security-scoped vault access, Keychain, and App Sandbox are active.
- Preserve dependency order and evidence honesty. Prompt 2 closes only after
  current exact signed-archive behavior passes its runtime, automated,
  packaging, and release-risk checks.
- Preserve unrelated dirty-worktree changes; do not stage, commit, reset, or
  revert them.

### Non-goals

- Do not revive Pro, Developer-ID, Experimental, 1Code, OpenChamber, Kindred,
  sidecar, subprocess, local-server, terminal/code-exec, or stdio-MCP runtime
  work.
- Do not require the owner to type a keyword to resume or cross a plan phase.
- Do not call a source test, build, archive, or one successful manual action
  sufficient by itself for a broad completion claim.

### Acceptance checks

- The first-responder regression must execute non-vacuously and pass.
- The complete MAS suite must pass with the new regression included.
- A fresh signed universal Release archive must pass signature, entitlement,
  privacy, bundled-resource, KEELSTONE, and forbidden-runtime checks.
- In that exact archive, a fresh Prose marker must remain live and on disk
  across watcher cycles, produce no new identical conflict sibling, and emit
  no new dirty-session self-write deferral.
- After the remaining Prompt 2 product matrix is proven, immediately load and
  execute the next active prompt from the master index.

### Current evidence and next action

- Intentional red compile evidence is retained at
  `build/xcode-results/2026-07-10-053600-first-responder-red.xcresult`.
- The corrected focused filter executed one test and passed at
  `build/xcode-results/2026-07-10-054200-first-responder-green.xcresult`.
- The complete MAS lane passed 63/63 at
  `build/xcode-results/2026-07-10-054600-prompt2-first-responder-full.xcresult`.
- The failed-runtime conflict sibling was read, SHA-256 matched against the
  canonical note, and removed while preserving the canonical file.
- Build a fresh signed universal archive, run the complete static gate set,
  then replay the exact archive. If the watcher conflict remains, continue at
  the notification/session-ordering boundary with another deterministic red
  regression instead of stopping.

## Checkpoint 2026-07-10 Local-Save Notification-Origin Falsifier

### Owner intent carried forward

- Continue the full MAS-only plan without a control keyword or phase-boundary
  pause.
- Do not call Prompt 2 complete while an exact archived app still classifies
  its own durable editor save as an external dirty-session conflict.

### Fresh automated and distribution evidence

- The active-first-responder regression executed non-vacuously and passed in
  `build/xcode-results/2026-07-10-054200-first-responder-green.xcresult`.
- The complete MAS lane passed 63/63 in
  `build/xcode-results/2026-07-10-054600-prompt2-first-responder-full.xcresult`.
- Fresh signed universal archive:
  `build/appstore-release-archive-2026-07-10-prompt2-first-responder-20260710-055000.xcarchive`.
- The exact archived app passed strict deep signing, `x86_64 arm64`, MAS
  sandbox/bookmark/audio/network-client entitlements, both privacy manifests,
  source-identical compressed editor hash, KEELSTONE, JuneWeb completeness,
  and standalone bundle scanning. Scan reports:
  `build/appstore-audit/2026-07-10-prompt2-first-responder-055000`.

### Exact-runtime result

- Document loaded the complete rich note at `35 words 588 chars`.
- Prose marker
  `[archive-prose-first-responder-proof:e1f59e8c-2e03-4a52-a6e1-50c3b84677c4]`
  remained visible after more than 24 seconds and remained in the canonical
  vault file.
- The vault converged to one 902-byte canonical file with SHA-256
  `801c416db57d8688d7f591a91b3ea534324f0513341f1eb05061f781cb3ecca9`;
  no conflict sibling was created.
- Unified logging still emitted at `05:58:50.571`:
  `NoteDetailWorkspaceView: deferred external body change for dirty note
  session 3DA442EE`.

### Revised contradiction and constraints

- `ProseEditorView.debouncedSave` durably saves, advances
  `lastPersistedBody`, then posts `NoteFileStorage.pageBodyDidChange` with only
  `pageId`. That notification is documented and consumed as an external-change
  signal.
- `NoteDetailWorkspaceView` can still hold an older `persistedBody`. It sees
  the active editor's newly saved body differ from that snapshot, calls
  `recordUserEdit`, and then calls `externalBodyChanged`, manufacturing a
  dirty external classification for the app's own local save.
- Preserve real external-edit conflict behavior and sibling-editor refreshes.
  Do not suppress FSEvents, weaken conflict protection, or add debounce time.

### Acceptance checks and next action

- Add a deterministic red regression that requires local durable-save
  notifications to be distinguishable from external body-change notifications.
- Route the existing Prose post through that explicit origin and make the
  workspace accept/refresh local saves without invoking
  `externalBodyChanged`; external notifications must retain the current
  dirty-session conflict path.
- Rerun the focused test, the complete MAS suite, a fresh signed archive, all
  static gates, and the exact runtime marker/log replay. Continue until both
  file convergence and zero new self-write deferral pass.

## Checkpoint 2026-07-10 Epdoc Dirty Lens-Switch Falsifier

### Owner intent carried forward

- Continue the complete MAS-only plan autonomously without a keyword or pause
  between plan units.
- Treat the owner's reported Epdoc surface-switch formatting/data-loss problem
  as a Prompt 2 HIGH until the exact signed archive preserves live Document
  edits through a lens switch and a canonical-file round trip.

### Fresh exact-archive evidence

- The local-save-origin regression executed one focused test and passed in
  `build/xcode-results/2026-07-10-060600-local-save-origin-green.xcresult`.
- The complete MAS lane passed 64/64 in
  `build/xcode-results/2026-07-10-060900-prompt2-local-save-origin-full.xcresult`.
- Fresh signed universal archive:
  `build/appstore-release-archive-2026-07-10-prompt2-local-save-origin-20260710-061200.xcarchive`.
- That archive passed strict deep signing, `x86_64 arm64`, MAS entitlements,
  both privacy manifests, the source-identical editor hash, bundled JuneWeb,
  KEELSTONE, and standalone App Store scanning. Scan reports:
  `build/appstore-audit/2026-07-10-prompt2-local-save-origin-061200`.
- In the exact archived app, Prose marker
  `[archive-local-save-origin-green:089b7bf1-9b35-4c66-96ad-57cda7e51142]`
  remained live and canonical after more than 25 seconds. It produced no
  conflict sibling and no `deferred external body change`, `external-conflict`,
  or `NOTE-3` log event. The canonical file was 974 bytes with SHA-256
  `9c9db18440c20443239dc577a9426b2d9d95a1afbd0aaeb582233394338952d4`.
- A Source edit then persisted marker
  `[archive-source-edit-green:e96eab85-a1ea-4fa0-9b10-c9d3fdf0776d]` and
  reopened in Document with the heading, table, bold/italic cells, nested list,
  quote, and all prior markers intact.

### New HIGH contradiction

- In that same exact archive, Document accepted the complete live marker
  `[archive-document-edit-green:41c446fb-4e86-47aa-9875-640bc3d9b38d]`
  and updated its visible status to `38 words 862 chars`.
- Switching directly from Document to Source discarded that marker. Source
  reloaded the pre-edit Markdown, and the canonical file never received the
  marker. No product log reported a flush failure.
- Existing source and coordinator tests claim dirty Document switches save a
  direct snapshot, so the current production transition is either failing to
  observe the pending WebKit snapshot or deactivating/reloading the editor
  before the asynchronous flush can obtain it.

### Constraints, acceptance checks, and next action

- Preserve the clean-switch rule that must not rewrite normalized Epdoc
  Markdown. Only a genuinely dirty Document transition may write.
- Preserve file-first vault persistence, rich Markdown constructs, same-page
  stable editor identity, and true external-conflict behavior.
- Add a deterministic red regression at the production lens-transition seam,
  not only the isolated coordinator. The switch must await or receive the
  latest dirty editor snapshot before Source becomes authoritative.
- Rerun the focused regression and full MAS lane, then rebuild and replay the
  exact signed archive with a new Document marker. Do not resume the remaining
  Prompt 2 matrix until this data-loss path is closed.

### Test-first repair evidence

- The new production-seam regression lives in
  `EpistemosAppStoreKeelstoneTests/MarkdownDocumentLensSwitchTests.swift` and
  models an editor update arriving before Swift receives the coalesced
  `loadSettled`/initial-Markdown echo.
- Intentional non-vacuous red result:
  `build/xcode-results/2026-07-10-064100-document-lens-early-edit-red.xcresult`.
  The single test failed because the current controller made zero direct
  snapshot requests and saved zero Markdown.
- The controller now marks that first early content update dirty
  conservatively. A matching host Markdown echo clears the flag synchronously;
  a real edit stays eligible for the existing direct-snapshot lens flush.
- Focused non-vacuous green result:
  `build/xcode-results/2026-07-10-064500-document-lens-early-edit-green.xcresult`
  (1/1).
- Full MAS lane:
  `build/xcode-results/2026-07-10-064700-prompt2-document-lens-full.xcresult`
  (65/65 across two suites). Existing clean normalized-table, blank recovery,
  direct snapshot, Source, vault, voice-default, June-literal-send, and graph
  guards remained green.
- Next action remains a fresh signed universal archive plus an exact-runtime
  Document edit -> Source switch -> canonical-file round trip. The source fix
  is not sufficient evidence by itself.

### Exact signed-archive closure evidence

- Fresh signed universal archive:
  `build/appstore-release-archive-2026-07-10-prompt2-document-lens-20260710-065000.xcarchive`.
- The archive passed strict deep signing, `x86_64 arm64`, MAS entitlements,
  both privacy manifests, source-identical editor hashing, KEELSTONE, and the
  standalone App Store scan. Scan reports:
  `build/appstore-audit/2026-07-10-prompt2-document-lens-065000`.
- The exact archived app reopened the canonical note in Document with a rich
  heading, table, bold/italic cells, nested list, quote, and all earlier
  persistence markers. Document settled at `38 words 796 chars` before the
  edit.
- Document marker
  `[archive-document-early-switch-green:8cb9363f-bd3c-44d7-a3b2-585d056285e4]`
  was typed and Source was selected immediately afterward. Source displayed
  the complete marker and the canonical file persisted it exactly once.
- The canonical file was 1114 bytes after the switch. No conflict sibling was
  created and unified logging contained no `deferred external body change`,
  `external-conflict`, or `NOTE-3` event in the correlated five-minute window.
- Closing the edited tab and reopening the note loaded the marker in Document
  while preserving the heading, rich table, bold/italic cells, nested list,
  and quote. Document settled at `38 words 870 chars`.

### Transition

- The reproduced Document -> Source data-loss path is now closed by a
  non-vacuous red/green test, a complete 65/65 MAS run, a fresh signed archive,
  and an exact UI/disk/reopen proof.
- Continue the Prompt 2 HIGH runtime matrix without pausing: editor/code/Quick
  Capture/embedded graph/hologram graph responsiveness and editability, audible
  English Kokoro behavior or an exact truthful blocker, literal June send
  output or its exact provider/model failure, and broader repeated release
  validation.

## Checkpoint 2026-07-10 Resource-Bounded Continuation

### Owner steer

> gpt is taking 25 gb of ram pleasw stop doing massive tests bro

### Interpreted intent and constraints

- Stop broad clean Xcode builds and other high-memory validation immediately.
- Continue the MAS-only plan with narrow source work, lightweight checks, and
  reuse of retained evidence/build state. Do not restart a broad/full suite or
  clean archive unless the owner later permits it or a release checkpoint
  cannot be proved any other way.
- Preserve the current dirty worktree, vault data, retained archives, and
  xcresult evidence.

### Evidence and next action

- The in-flight clean focused-test build was interrupted before completion and
  is not evidence. No `xcodebuild`, Swift compiler, or clang process remained
  afterward.
- A prior exact-archive Settings navigation stress exposed a separate real hang:
  process RSS/physical footprint reached 11.8 GB and Accessibility plus normal
  quit AppleEvents stopped responding. Main-thread sample:
  `build/runtime-samples/2026-07-10-settings-navigation-hang-sample.txt`.
- The sample pins the main thread in a SwiftUI/AppKit layout and preference
  update cycle while rapid sidebar navigation was constructing heavyweight
  Settings detail views. Continue with a surgical, source-level coalescing fix
  and only low-memory parse/diff checks for now.

### Runtime matrix evidence retained before the resource steer

- Code editor: created
  `Code/Codex Prompt 2 Code Edit 2026-07-10.swift`, edited it through the
  exact archive's code surface, and persisted
  `// archive-code-edit-green:4ca32139-08ca-4815-8222-f0682ed91312`.
  The final file SHA-256 is
  `16f110e8c85788f634589e6586eb2e0704f68a0b49032e0a2905706171e92f08`.
  No `Cannot save` or `no vault URL` log appeared.
- Quick Capture accepted a 69-character thought in a measured 894 ms UI-tool
  round trip, captured it, wrote the exact Markdown marker to the vault, and
  exposed the saved note in Notes and Document (`6 words 69 chars`).
- Hologram graph loaded the real vault tree, selected a code node, routed it
  through `Open Node` to the graph-owned editable code surface, and persisted
  `archive-embedded-graph-code-edit-green:95036c08-42ff-4550-974a-773da1db79c0`
  to the canonical Swift file. The measured typing-tool round trip was 1206 ms.
- The hologram graph also opened the canonical rich note into Document at
  `38 words 870 chars`. A controlled two-chunk automation marker avoided the
  Computer Use text injection's 64-character limit, switched immediately to
  Source, and persisted the complete marker
  `[archive-hologram-chunked-switch-green:4c71b618-c224-4d4d-8f39-f59f3ed2b55b]`.
  No save/conflict/`NOTE-3` log appeared.

### Resource-bounded Settings repair

- Added a failing App Store source regression requiring separate committed
  detail selection, cancellable `.task(id: selection)` coalescing, a bounded
  debounce, and animation-free detail replacement. Its attempted clean Xcode
  run was interrupted per owner direction and is not counted.
- `SettingsView` now keeps sidebar selection immediate while committing a
  heavyweight detail view only after 120 ms of settled selection. SwiftUI
  cancels the task when the selection changes; the commit disables transition
  animations so rapid keyboard navigation cannot stack detail transitions.
- Low-memory validation only: both changed Swift files pass `swiftc -frontend
  -parse`; `git diff --check` passes; all regression source markers are present.
- Broad build/runtime revalidation is intentionally deferred under the latest
  owner resource constraint.

### Bounded embedded-graph follow-up

- Reused the existing signed archive without rebuilding. The process launched
  at about 194 MB RSS and stayed below 500 MB during the pass.
- With persisted `epistemos.graph.viewLocation = embedded`, the home graph
  reached its real inline Metal canvas in a measured 2972 ms UI-tool round
  trip (including the 900 ms observation wait and Accessibility snapshot).
- Node/sidebar automation was stopped when foreground control collided with
  the owner's active desktop. The archive process was terminated and no
  compiler/model process was left running. Embedded node-to-editor editing
  remains open rather than being overclaimed.

### Resource-bounded June failure diagnosis

- Reused the retained exact-archive send proof instead of launching or
  rebuilding the app. The literal prompt reached the native MAS gateway, but
  the 2026-07-09 archive exposed only `Epistemos.AgentErrorFfi code=0`.
- Source chronology confirms that archive predates the current typed
  `AgentErrorFfi.AgentError(message:)` extraction. The retained generic error
  therefore cannot safely distinguish a missing credential, vault/index
  failure, provider rejection, or transport failure.
- Hardened `EngineLogDiagnostics` so short credential-free Rust messages remain
  visible. Path-bearing tokens are replaced with `<redacted-path>` instead of
  causing the entire actionable error to be discarded; credential-bearing
  messages still fall back to domain/code without exposing secrets.
- Added App Store regression expectations and lightweight release-gate guards.
  Low-memory evidence only: the changed Swift sources parse, the shell gate
  parses, and `git diff --check` passes. A fresh runtime send remains deferred
  under the owner's resource constraint; no provider/vault root cause is
  claimed from the obsolete generic archive error.
- The matching persisted `agent_core` receipt was then found at
  `Kimi_Agent_Deterministic AI Deep Dive (2)/sessions/2026-07-09_44E452F0/session.json`.
  Its modification time is exactly `2026-07-09 09:09:30`, matching the retained
  June error log. It records provider/model `openai_gpt55`, status `failed`,
  `turn_count=0`, and the exact error `provider error: OPENAI_API_KEY is not
  configured`.
- That receipt proves security-scoped vault access, session-folder creation,
  and receipt finalization succeeded. The request failed before the first model
  turn because no OpenAI API key reached the MAS `agent_core` environment; no
  credential value was read or exposed during this diagnosis.
- Current uncommitted MAS source, added after that archive, compile-parks the
  OpenAI Codex OAuth mode and excludes OpenAI OAuth environment propagation.
  June's current cached-model repair therefore cannot treat a legacy ChatGPT/
  Codex account receipt as a runnable MAS OpenAI agent credential. OpenAI in MAS
  requires its Keychain API-key lane. A subsequent source/canon audit found the
  Anthropic account-import claim was also not valid for MAS and superseded it
  with the API-key-only boundary recorded below.
- Tightened June's generic configuration copy; the subsequent credential-truth
  pass superseded it with `Add an OpenAI or Anthropic API key in Settings, or
  pick Apple Intelligence.` The typed/callback
  diagnostic path now also prevents raw Rust callback errors from bypassing
  path and credential redaction.

### Resource-bounded Kokoro matrix audit

- Reused the retained exact-archive voice artifact rather than loading Core ML
  again. Its correlated logs prove gate resolution, manifest validation,
  `KokoroPipeline` linkage, render completion, `AVAudioEngine` start, playback
  start, and playback completion with no Kokoro failure log. Human audibility
  remains deliberately unclaimed.
- The current native visible-read registry covers Landing, June, Prose,
  Source/Code, Epdoc selection, Quick Capture, Meeting transcript, and HTML
  Workspace source. Settings exposes two identified Kokoro preview controls;
  missing-runtime controls remain visible and route to the installer instead of
  silently disabling themselves.
- Removed stale user-facing rationale that still said Kokoro playback was not
  wired. Quick Capture now says auto read-back operates when the checked Kokoro
  runtime is installed and ready; Apple AVSpeech remains explicitly excluded.
- Routed long-note auto-read through `EpistemosAgentReadAloud` so it shares the
  global English Kokoro voice, MAS-clean effect, readiness logging, and visible
  failure/unavailable diagnostics used by manual read-aloud.
- Added lightweight source and release-gate witnesses. Changed Swift files
  parse, the shell gate parses, `git diff --check` passes, and no compiler,
  Xcode, model, or app process remains running.

## Checkpoint 2026-07-10 MAS Credential Truth Hardening

### Owner steer

> gpt is taking 25 gb of ram pleasw stop doing massive tests bro

### Interpreted intent

- Keep advancing the MAS-only Prompt 2 plan autonomously without broad or
  memory-heavy validation.
- Prefer source inspection, retained receipts, surgical fixes, and lightweight
  parse/diff checks until the owner changes the resource constraint.

### Hard constraints and non-goals

- Do not run Xcode builds/tests/archives, launch a model, or launch Epistemos.
- Preserve the dirty worktree and existing evidence. Do not expose or inspect
  credential values.
- Keep MAS provider setup truthful: Keychain may store secrets, while any file
  import must be valid under App Sandbox and the MAS-only canon's
  security-scoped-access rule.
- Do not invent a replacement OAuth flow or weaken authentication merely to
  keep an account-connection label visible.

### Acceptance checks, contradiction, and next action

- Current MAS UI prefers importing a Claude Code account, while
  `CloudProviderAuthService` reads `~/.claude/.credentials.json` directly.
  That appears to contradict the active sandbox-safe-storage canon unless an
  explicit sandbox-safe grant/import flow exists.
- Read the exact auth service, provider UI state, environment bridge, tests,
  and release guards; validate App Sandbox and provider-auth facts against
  official sources; then either prove the flow valid or compile-park it in MAS
  and expose the already-supported Keychain API-key path honestly.
- Verification for any repair is limited to `swiftc -frontend -parse`,
  `bash -n`, focused source guards, `git diff --check`, and a process/RSS check.

### Outcome and next hardening target

- Official Apple, Anthropic, and Google documentation confirmed the conflict:
  sandboxed home-directory access requires an explicit grant; Claude Code uses
  macOS Keychain rather than `.claude/.credentials.json`; the documented Claude
  API route is API key or workload federation; and the implemented Google
  desktop flow requires the callback path already parked from MAS.
- MAS provider rows are now uniformly API-key-only. Legacy OAuth snapshots are
  not loaded, OAuth lookups return `nil`, non-`nil` OAuth writes are refused,
  Anthropic/Google OAuth environment overrides are direct-lane-only, Claude
  Code import fails before filesystem access, and Google OAuth controls are
  compile-parked. June and Settings copy now describe API keys truthfully.
- Added a focused App Store source regression plus release-gate witnesses.
  Both MAS and direct Swift parser branches pass, the test sources parse,
  `bash -n scripts/keelstone-release-gate.sh` passes, and scoped
  `git diff --check` passes. No build/test/app/model/provider process ran.
- Runtime proof remains deferred. Continue Prompt 2 source hardening at the
  next highest unproven seam while preserving the low-memory constraint.

## Checkpoint 2026-07-10 MAS OAuth Artifact-Leakage Follow-up

### Owner steer and interpreted intent

> gpt is taking 25 gb of ram pleasw stop doing massive tests bro

- Continue the same autonomous Prompt 2 hardening loop with source-only,
  low-memory evidence.

### Constraint, finding, and next action

- The Settings/auth boundary is now API-key-only, but the runtime credential
  enum still exposes Anthropic/Google OAuth cases to MAS compilation and
  `LLMService` still compiles Claude CLI headers and Google bearer-token request
  branches. They are unreachable after the first repair, but may leave parked
  account-runtime strings/logic in a future MAS artifact.
- Compile-park resolved account credentials and every dependent LLM request
  branch together, extend artifact scanners to reject Claude credential/import
  and token-refresh markers, add a focused source witness, then use parser,
  shell-syntax, diff, and RSS checks only.

### Outcome and next action

- `CloudProviderResolvedCredential` now exposes only `.apiKey` to MAS;
  OpenAI/Anthropic/Google account credential cases are one direct-lane block.
  Every matching `LLMService` switch branch, including the Claude CLI user
  agent and OAuth beta headers, is in the same direct-lane compile boundary.
- `scan_appstore_bundle.sh` and the built-app KEELSTONE scan now reject Claude
  home-credential paths, OAuth refresh endpoints, CLI user-agent markers, and
  account-only beta markers. App Store source guards pin the enum, LLM request
  boundaries, and scanner patterns.
- MAS and direct Swift parse passes, test-source parsing, both shell syntax
  checks, and scoped `git diff --check` pass. No Xcode/test runner, app, model,
  or provider process ran.
- Continue with a source-only contradiction scan of the remaining MAS provider
  setup seam, then return to other Prompt 2 HIGHs that can advance without a
  runtime launch.

## Checkpoint 2026-07-10 MAS Settings Credential-State Follow-up

- Owner constraint remains source-only and low-memory.
- The contradiction scan found that MAS hides Google desktop OAuth controls but
  still initializes their UserDefaults/Keychain-backed state when Cloud Settings
  is constructed, reloads it on appearance, and carries the OpenAI device-auth
  sheet state. This is dead MAS work and an avoidable seam in the Settings
  surface that previously exhibited an extreme memory/layout hang.
- Compile-park account-only Settings state, bindings, sheet/reload behavior, and
  Google OAuth setup storage helpers while preserving the common API-key paste,
  save, validation, and Keychain flow. Verify only with both parser branches,
  source guards, shell syntax, diff checks, and RSS inspection.

## Checkpoint 2026-07-10 Owner Steer — MAS Settings Must Be June-Only

### Verbatim owner steer

> rmemeber i just want mas june if it is not june then it should ot be in my app the ai models i seen in the settings of my app they msut be connected to june f thye are not im confused on why they are thee

### Interpreted intent

- The App Store product has one agent/model surface: June.
- Every AI provider/model visible in MAS Settings must be a real input to June's
  active model catalog and send path. A provider row retained for regular chat,
  parked lanes, research, or future wiring must not appear in MAS.
- Current source violates that expectation: June's active agent catalog owns
  OpenAI and Anthropic, while MAS Settings/fallback provider order still exposes
  Google, Z.AI/GLM, Kimi, MiniMax, and DeepSeek.

### Constraints, non-goals, and acceptance checks

- Preserve OpenAI and Anthropic because they are June's current direct cloud
  providers. Preserve Apple Intelligence/local rows only inside June's own model
  picker where their chat-only capability limits are already explicit.
- Do not delete parked/direct provider implementations or widen June to pretend
  disconnected providers work. Compile/filter them out of MAS product behavior.
- Create one canonical MAS June cloud-provider list and reuse it in Settings,
  June's model catalog, fallback routing, and source/release guards.
- Verify source-only under the owner's RAM constraint: both parser branches,
  focused guards, shell syntax, diff checks, and RSS inspection. Runtime/archive
  proof remains deferred.

### Next action

- Read provider capability/routing call sites and tests, then replace duplicated
  MAS provider lists with the canonical June list and scan for any remaining
  non-June provider rows or default routes in the App Store branch.

### Outcome and continuing verification debt

- MAS Cloud Settings now renders only `CloudModelProvider.juneAgentProviders`:
  OpenAI and Anthropic. Google, Z.AI/GLM, Kimi, MiniMax, and DeepSeek remain
  parked for direct builds and no longer enter the MAS provider row list.
- `CloudTextModelID.juneAgentModels(for:)` is now the single exact model
  allowlist shared by Settings, June's model payload/selectable IDs,
  `InferenceState`, and the gateway admission check. The list contains only
  fixed `agent_core` constructors: GPT-5.5, the GPT-5.4 family, GPT-5.2,
  GPT-4.1/mini, o3-mini, and Claude Sonnet 4.6, Opus 4.7, and Haiku 4.5.
  Generic `o3` and future/legacy Claude labels that previously collapsed to a
  different constructor are excluded.
- Persisted non-June providers normalize to OpenAI in MAS; stale non-allowlisted
  model IDs normalize to the provider's connected default. The gateway also
  rejects a disconnected model before slug resolution instead of silently
  substituting a family default.
- MAS credential bootstrap, validation state, brain catalog, live provider
  model counts, and scoped `agent_core` Keychain environment now use only the
  active June providers. Parked-provider Keychain entries are neither loaded nor
  forwarded by the MAS path.
- The secondary Settings surfaces now agree with the same product truth. MAS
  Runtime Lanes contains only Apple Intelligence, local GGUF, OpenAI, and
  Claude; Privacy names only June's OpenAI/Anthropic requests; and Deployment
  Profile describes active MAS June boundaries instead of listing parked
  provider/CLI products as visible options.
- Defense in depth now reaches the retained cloud-chat client: every MAS
  generate, stream, structured-output, and connection-test entry rejects models
  outside the exact June allowlist before resolving credentials or starting a
  provider request. The retired all-provider chat-tool flag is direct-lane-only,
  and MAS missing-access copy asks only for an API key.
- Rust Claude OAuth constants, enum variants, environment reads, bearer request
  headers, and OAuth tests are compile-parked behind
  `not(feature = "mas-build")`; the MAS source branch selects
  `ClaudeAuth::ApiKey` directly.
- The June boot/send compatibility layer no longer hardcodes provider success.
  Native `bootstrap_app` computes `providerConfigured` from cached access for
  the canonical OpenAI/Anthropic June providers, while the web fallback reports
  `providerConfigured: false`. The fallback submit path still fails visibly
  with code `5030` instead of generating a canned response, and the native and
  staged shims are byte-identical.
- Visible bootstrap status now says June uses the in-process MAS agent gateway;
  it no longer names Hermes or implies an external runtime/server. The retained
  signed archive predates these source/shim changes and is therefore not
  current runtime evidence for this checkpoint.
- Low-memory checks passed: MAS/direct Swift parsing for changed product files,
  parser checks for the focused source guards, shell syntax, `rustfmt --check`,
  scoped diff checks, and RSS inspection. No Xcode build/test/archive, app
  launch, model launch, provider call, or Cargo build/check ran.
- Runtime and artifact proof remain open. At the next resource-safe checkpoint,
  build the MAS Rust feature and a reusable App Store app, confirm Settings
  visibly contains only the exact June provider/model rows, save/check an API
  key, prove `bootstrap_app.providerConfigured` changes only from cached June
  access, run a literal June send, and scan the resulting binary for parked
  OAuth/Hermes markers.

## Checkpoint 2026-07-10 Owner Clarification — Preserve Voice Models

### Verbatim owner steer

> but istill want to keep my voice models i forgot about that

### Interpreted intent, constraints, and next action

- “MAS June-only” narrows agent/chat providers and language-model pickers. It
  does not remove Kokoro, speech, dictation, read-aloud, or voice-model assets
  and choices.
- Preserve the existing voice-model catalog and the Prompt 2 English Kokoro
  repair/proof lane. Do not treat voice models as disconnected chat models.
- Agent Command Center recommendations now use
  `CloudModelProvider.activeProductProviders` instead of a hardcoded list that
  still mentioned Google. Voice Settings still mounts Kokoro Voice Pro and its
  picker still derives choices from installed English Kokoro voices.
- Source/release guards now protect both halves of the boundary. MAS/direct
  parsing, shell syntax, and scoped diff checks pass; no heavyweight validation
  or runtime launch ran.
- Continue auditing agent/chat fallback seams against the canonical June list
  while leaving the voice lane intact.

## Checkpoint 2026-07-10 MAS Diagnostics Product-Truth Follow-up

### Owner wording and interpreted intent

> i just want mas june if it is not june then it should ot be in my app

- MAS-safe native product surfaces such as Kokoro voice and the bundled WebKit
  Browser remain valid. Parked Pro/browser-use and owner-cut Obscura runtime
  claims must not appear in the MAS Settings product ledger.
- Current `BrowserCapabilityStatus` mixes real MAS Browser/scraper capability
  with visible browser-use Pro and Obscura deferred rows, despite the strategic
  pivot explicitly parking browser-use/Chromium and Pro.

### Constraints, acceptance checks, and next action

- Preserve native WebKit Browser, privacy/content blocking, and MAS-safe web
  extraction capabilities that are genuinely wired.
- Give MAS a list/summary containing only active MAS capabilities; retain the
  historical Pro/Obscura ledger only in the direct branch.
- Update source guards first, then edit the status boundary. Use parser,
  shell-syntax, and diff checks only.

### Outcome and continuing debt

- MAS Browser diagnostics now count and describe only the active native
  Browser/scraper/privacy capabilities. The in-app privacy note no longer names
  browser-use Pro; Obscura and anti-fingerprint rows are direct-lane-only.
- Native WebKit Browser, content blocking, web extraction/crawl/search, and
  schema extraction remain intact. This does not alter the preserved Kokoro
  voice boundary or the canonical June chat/model boundary.
- A conditional regression and release-gate source witnesses pin the split.
  MAS/direct Swift parsing, shell syntax, and scoped diff checks pass. Runtime
  Settings evidence remains deferred under the owner RAM constraint.

## Checkpoint 2026-07-10 MAS Rust Provider-Admission Follow-up

### Owner wording and interpreted intent

> the ai models i seen in the settings of my app they msut be connected to june

- Swift Settings and June now share an exact allowlist, but the MAS Rust FFI
  bridge still treats Gemini, Perplexity, OpenRouter, Ollama/llama.cpp, multiple
  API aggregators, dynamic provider/model slugs, GPT-4o, and o1 as supported
  provider overrides. Its MAS error message also advertises those parked lanes.
- A bypass or future caller could therefore reach a provider/model that MAS
  Settings correctly refuses. June's product boundary must be enforced again at
  the final Rust provider-admission seam.

### Constraints, non-goals, acceptance checks, and next action

- MAS admits only Claude Sonnet/Opus/Haiku and the exact OpenAI constructors
  surfaced by June: GPT-5.5, GPT-5.4/mini/nano, GPT-5.2, GPT-4.1/mini, and
  o3-mini. The bare `openai` alias remains the GPT-5.4 default.
- Preserve all broader provider implementations and auto-routing behavior for
  the direct branch; do not delete historical/provider research.
- MAS `auto`, dynamic provider/model slugs, and every parked named provider
  must fail closed before instantiation. Add Rust regression cases first, then
  compile-park the non-June bridge arms and align the MAS available-model error.
- Verification remains `rustfmt --check`, source guards, shell syntax, diff,
  and process/RSS only. Cargo build/check/test remains deferred.

### Outcome and continuing debt

- The MAS provider preview now admits only the exact June Claude/OpenAI slugs.
  `auto`, dynamic provider/model slugs, GPT-4o, o1, Gemini, Perplexity,
  OpenRouter, Ollama/llama.cpp, and every other parked named provider fail with
  an explicit June-boundary result.
- `instantiate_provider` now has a dedicated `mas-build` implementation with
  only the same exact constructors and a separate direct implementation that
  retains the broader provider ecosystem.
- Gemini, Perplexity, and the generic OpenAI-compatible provider modules are
  no longer compiled into `mas-build`; Claude and OpenAI remain.
- Added a MAS Rust admission regression covering every admitted slug plus
  representative parked/dynamic slugs, and a module-gate regression. Rustfmt,
  Swift test-source parsing, shell syntax, diff, and RSS checks pass. Cargo
  execution and current-artifact proof remain deferred under the RAM limit.

## Checkpoint 2026-07-10 MAS Settings Label Clarity

### Owner wording, interpretation, and acceptance check

> if thye are not im confused on why they are thee

- Even after filtering, a generic “Cloud Models” / “Cloud Provider Setup” label
  leaves the owner to infer whether these are June models or a second AI stack.
- In MAS, label the sidebar “June Models” and the form section “June Provider
  Setup.” Keep direct-build labels unchanged and keep Voice as its own preserved
  section. Search should match the visible MAS title.
- Add the source regression first, edit only Settings labels/search, then parse
  both compilation branches and run diff/shell checks.

### Outcome and continuing debt

- MAS now visibly calls the sidebar destination “June Models” and the form
  section “June Provider Setup.” Settings search indexes the visible title.
- Direct builds retain “Cloud Models” and “Cloud Provider Setup.” Voice remains
  a separate, unchanged Settings destination with Kokoro choices preserved.
- MAS/direct Settings parsing, focused test-source parsing, shell syntax, and
  scoped diff checks pass. Visible proof awaits a later resource-safe build.

## Checkpoint 2026-07-10 June Settings Transcription/Agent Model Separation

### Owner wording and interpreted intent

> the ai models i seen in the settings of my app they msut be connected to june
>
> but istill want to keep my voice models i forgot about that

- June's embedded Settings requests separate `transcription` and `generation`
  catalogs. The native bridge currently returns the entire June text-agent
  catalog for every mode, so GPT/Claude/local chat models appear in the
  transcription picker.
- Worse, `set_venice_model` ignores mode: selecting a transcription row can
  mutate June's default agent/chat model. This conflates speech configuration
  with the agent-model boundary and plausibly explains the owner's confusion.

### Constraints, acceptance checks, and next action

- Keep June's transcription row, native dictation settings, and all separate
  Kokoro TTS voice choices. Do not replace or remove voice models.
- `generation` alone receives the exact June agent/chat catalog and may mutate
  the June default model. `transcription` receives one honest local-dictation
  row and cannot change the agent default. Image/unknown modes receive no text
  rows from this native endpoint.
- Add source regressions first, edit the bridge mode switch, then use Swift
  parsing, shell/diff guards, and June shim syntax only.

### Outcome and continuing debt

- `list_venice_models` now returns the exact June agent/chat catalog only for
  `generation`. `transcription` returns one private “On-device dictation” row;
  image/unknown modes receive no text-model rows.
- `set_venice_model` mutates June's default model only for `generation`, so a
  transcription choice cannot reroute the agent.
- June's static Venice/FLUX/Qwen image-model section is now capability-driven.
  The MAS host already returns an empty `imageModel` because it implements no
  native `generate_image` command, so the next staged June build hides that
  disconnected section; standalone June retains it when its backend supplies a
  real image model.
- The embedded Settings sidebar also relabels its generic “Models” row to
  “June models” in the MAS host mode (`localDev` compatibility state), while
  standalone/account-backed June keeps its existing label.
- June's transcription Settings row remains, native dictation remains local,
  and the separate Kokoro TTS voice catalog remains untouched.
- `build-june-web.sh` now refuses a donor missing that capability guard. MAS/
  direct bridge and test-source parsing, low-memory TypeScript syntax parsing,
  release-gate shell syntax, shim JavaScript syntax, and scoped diff checks
  pass. The staged `dist` is intentionally not rebuilt under the RAM limit, so
  current embedded-Settings visual proof remains open.

## Checkpoint 2026-07-10 June Settings Disconnected Skill Tabs

### Owner wording and interpreted intent

> if it is not june then it should ot be in my app

- The MAS-hosted June Settings sidebar still exposes “Installed skills” and
  “External skill directories.” The native bridge returns no connected skill
  inventory/directory roots, and the legacy arbitrary-directory UX is not an
  admitted App Sandbox path.
- These are disconnected controls, not the MAS-safe skill capability itself.
  Hide them in the MAS host's `localDev` compatibility mode while preserving
  their standalone June implementation for future/native reconnection.

### Constraints and acceptance checks

- Keep Agent, June models, dictation/audio, shortcuts, General, and About.
- Keep all native Kokoro voice settings outside the web surface unchanged.
- Local-dev/MAS Settings must omit Billing, Installed skills, and External skill
  directories. Account-backed standalone June retains its current tabs.
- Pin the donor and build guard; use TypeScript syntax parse and diff checks
  only, with no web rebuild.

### Outcome and continuing debt

- A shared `MAS_HOST_HIDDEN_SETTINGS_TABS` boundary now removes Billing,
  Installed skills, and External skill directories from both controlled sidebar
  navigation and direct panel resolution whenever the MAS host's `localDev`
  compatibility state is active.
- Agent, June models, dictation/audio, shortcuts, General, and About remain.
  Standalone June retains its account/skill tabs.
- The MAS-hosted model page heading now says “June models” rather than generic
  “AI models,” matching the sidebar and native Settings labels.
- Donor regression source, build-stage guard, low-memory TypeScript syntax
  parsing, Swift source-guard parsing, shell syntax, and diff checks pass. The
  staged web bundle still awaits a resource-safe rebuild.

## Checkpoint 2026-07-10 June Settings Model-Selection Failure Truth

### Owner wording and interpreted intent

> the ai models i seen in the settings of my app they msut be connected to june
>
> but istill want to keep my voice models i forgot about that

- The visible generation picker now receives June's exact catalog, but a stale
  web bundle or crafted bridge event can still submit a disconnected model ID.
  `JuneAgentGateway.setDefaultModel` correctly rejects it, while the bridge
  currently ignores that result and lets Settings announce “Text model
  updated.” That false success undermines the June-only boundary.
- Voice remains a separate preserved product organ: on-device dictation may
  select only its local row, and native Kokoro voice models/settings remain
  untouched.

### Constraints, non-goals, acceptance checks, and next action

- A generation selection succeeds only when the gateway admits the model as a
  currently runnable June choice. Missing, stale, or disconnected IDs must
  reject the invoke with a precise June error so Settings shows failure.
- Transcription may accept only the honest `local` dictation row and must never
  call the agent-model setter. Image/unknown model modes must reject because
  the MAS host exposes no connected model in those categories.
- Do not remove or alter Kokoro models, voice preferences, or read-aloud. Add
  source regressions first, then make the smallest bridge change and run only
  parser/shell/diff checks under the RAM constraint.

### Outcome and continuing debt

- `set_venice_model` now has a dedicated validating invoke handler. Generation
  reports success only when `JuneAgentGateway` admits the selected model;
  stale, missing, or disconnected IDs reject with an explicit MAS June error.
- Transcription accepts only the local on-device dictation row and never calls
  the generation-model setter. Image and unknown categories reject as
  unavailable instead of pretending a preference changed.
- The existing shim converts native rejection into the Settings error path, so
  the UI no longer announces a false “Text model updated.” Kokoro code and
  voice preferences were untouched.
- MAS/direct Swift parsing, test-source parsing, shell syntax, scoped diff, and
  process/RSS checks pass. Visible behavior still awaits a resource-safe June
  web stage and current MAS build.

## Checkpoint 2026-07-10 MAS Agent Callback Product Truth

### Owner wording and interpreted intent

> i just want mas june if it is not june then it should ot be in my app

- The active MAS `agent_core` delegate is an implementation seam consumed by
  June, but several unavailable-tool callback payloads visibly say “Pro-only”
  and “App Store Goose backend,” and its fallback scratch directory also keeps
  a Goose product name. Those messages can escape through a June tool result
  and contradict the single-product boundary.
- Internal legacy Swift type names are not a second runtime and are outside
  this surgical copy/path correction; the product-visible contract and new
  scratch namespace must identify MAS June only.

### Constraints, acceptance checks, and next action

- Replace callback errors with truthful “unavailable in MAS June” language and
  remove NightBrain/Pro/Goose product advertising from the active MAS file.
- Move only the disposable fallback scratch namespace to
  `Epistemos/JuneAgentCore`; do not touch selected vault data or durable notes.
- Preserve the exact allowed June tools, approval flow, in-process FFI, and all
  Kokoro voice code. Add source guards first, then edit the active MAS runner
  and use Swift parser/shell/diff checks only.

### Outcome and continuing debt

- Every unavailable callback in the active MAS runner now identifies MAS June
  and no longer advertises Pro, a Goose backend, or NightBrain. Generic FFI
  failures now say “MAS June agent run failed.”
- The disposable empty-vault fallback path now uses
  `Epistemos/JuneAgentCore/agent-core-scratch`; selected vault paths and durable
  note storage were not changed.
- Source guards pin both the required June copy and absence of retired product
  wording. MAS/direct Swift parsing, shell syntax, scoped diff, and RSS checks
  pass; current binary/runtime proof remains deferred under the RAM limit.

## Checkpoint 2026-07-10 MAS Swift Provider-Slug Admission

### Owner wording and interpreted intent

> the ai models i seen in the settings of my app they msut be connected to june

- Settings, the June gateway, and Rust now enforce the exact June catalog, but
  the shared Swift model-to-`agent_core` slug mapper still recognizes dynamic
  slash paths plus Gemini, Kimi, DeepSeek, MiniMax, Z.AI, Perplexity, Mistral,
  Grok, GPT-4o, and o1 in the MAS compilation branch.
- The later Rust gate rejects these today, but the earlier mapper should not
  encode an alternate MAS model universe or leave a bypass-shaped seam.

### Constraints, acceptance checks, and next action

- MAS accepts only the exact raw model IDs emitted by June's current catalog:
  eight OpenAI IDs and Claude Sonnet 4.6, Opus 4.7, and Haiku 4.5.
- No substring guessing, provider-family fallback, arbitrary slash slug, or
  parked-provider mapping belongs in the MAS branch. Unknown IDs return `nil`
  and the gateway/Rust boundaries continue to fail closed.
- Preserve the existing broad resolver in the direct branch. Add a focused
  conditional source regression first, then edit only this mapper and use
  parser/shell/diff checks without a Cargo or Xcode build.

### Outcome and continuing debt

- The MAS Swift slug resolver is now an exact switch over the eleven raw model
  IDs emitted by the June catalog. Unknown, dynamic, provider-family, and every
  parked provider/model signal return `nil` before the Rust seam.
- The broad heuristic resolver remains unchanged in the direct branch. June's
  gateway admission and Rust factory remain additional fail-closed layers.
- Focused source guards, MAS/direct Swift parsing, release-gate shell syntax,
  scoped diff, and process/RSS checks pass. Cargo/Xcode/runtime proof remains
  deferred under the owner's memory constraint.

## Checkpoint 2026-07-10 MAS June Provider-Help Clarity

### Owner wording and interpreted intent

> if thye are not im confused on why they are thee

- The MAS provider rows are correctly limited to OpenAI and Anthropic, but
  their visible help still describes parked account-session import and an
  “outside the MAS product” alternative. That creates the exact impression of
  a second model stack even though those controls are absent.
- MAS help should explain only the active June route: provider API key, Apple
  Keychain storage, and the June model catalog. Google fallback help must say it
  is not connected if a stale/deep link ever reaches it.

### Constraints, acceptance checks, and next action

- Remove parked-account/alternate-product advertising from MAS-only help and
  setup copy while retaining the detailed direct-build guidance unchanged.
- Do not change credentials, provider URLs, model routing, or voice/Kokoro.
- Add source expectations first, make string-only edits, then parse both Swift
  branches and run shell/diff/RSS checks only.

### Outcome and continuing debt

- MAS OpenAI and Anthropic help now says only that their API keys power MAS
  June and are stored in Apple Keychain. Setup hints name MAS June directly.
- Stale Google setup surfaces state that Google is not connected to MAS June;
  they no longer describe a hidden MAS credential route. Direct-build account
  and OAuth guidance remains unchanged behind its compilation branch.
- Voice/Kokoro and all credential/routing behavior were untouched. MAS/direct
  Swift parsing, shell syntax, scoped diff, and RSS checks pass; visible proof
  remains pending a current resource-safe build.

## Checkpoint 2026-07-10 MAS Landing Names June

### Owner wording and interpreted intent

> i just want mas june

- The active MAS landing tile still says `agent`, the mounted page title says
  `Agent`, and its help describes a generic App Store workspace. They do mount
  June, but the visible labels force the owner to infer that relationship.
- MAS entry-point copy must say June directly; the direct target keeps its
  generic/coding-agent labels.

### Constraints, acceptance checks, and next action

- MAS landing tile title is `june`, the embedded page title is `June`, and the
  help begins `June` while honestly naming Cloud Agent and Apple
  Intelligence.
- Remove unreachable MAS Pro-only fallback copy for that tile. Do not change
  navigation, surface mounting, agent behavior, or voice/Kokoro.
- Add focused source expectations first, edit only labels/title selection, then
  use MAS/direct Swift parsing plus shell/diff/RSS checks.

### Outcome and continuing debt

- The MAS landing tile now says `june`, its hover/help text begins `June
  Workspace`, and the mounted page title is `June`. The direct build retains
  its existing agent/coding-agent labels.
- The unreachable MAS unavailable message now identifies June instead of Pro.
  Surface routing still mounts `JuneAgentSurfaceView`; no navigation, model,
  credential, or Kokoro behavior changed.
- Focused source guards, MAS/direct Swift parsing, shell syntax, scoped diff,
  and process/RSS checks pass. Current visible artifact proof remains deferred.

## Checkpoint 2026-07-10 MAS Onboarding Product Truth

### Owner wording and interpreted intent

> if it is not june then it should ot be in my app
>
> but istill want to keep my voice models

- First-run onboarding currently claims “skills, tools, and MCP connections” as
  completed foundation features and says model chat uses generic provider
  surfaces. MAS hides disconnected skill management and forbids stdio MCP, so
  this is visible stale product advertising before the user even reaches June.
- The next onboarding step correctly offers optional checked Kokoro voice
  packages and must remain intact.

### Constraints, acceptance checks, and next action

- MAS onboarding names `June Foundation`, describes the actual June vault,
  search, provenance, approved-tool, OpenAI/Anthropic, and Apple Intelligence
  boundary, and contains no MCP/hidden-skill claim in its compiled branch.
- Direct onboarding retains its existing broader foundation copy. Preserve the
  Kokoro voice step and download/status controls without modification.
- Add source expectations first, make only target-scoped onboarding copy/status
  edits, then use Swift parser/shell/diff/RSS checks.

### Outcome and continuing debt

- MAS first-run now says `June Foundation` and describes the actual vault,
  search, provenance, approval-gated tools, connected OpenAI/Anthropic models,
  and Apple Intelligence lane. The MAS branch no longer claims MCP or generic
  provider surfaces are active.
- Direct onboarding retains its existing skills/tools/MCP copy. The following
  Kokoro voice step, tier selector, checked download controls, readiness state,
  and completion summary remain unchanged and source-guarded.
- MAS/direct Swift parsing, shell syntax, scoped diff, and RSS checks pass.
  Current onboarding visuals/runtime remain unproven without a new build.

## Checkpoint 2026-07-10 Retired GGUF Removed From Active MAS Truth

### Owner wording and interpreted intent

> if it is not june then it should ot be in my app

- General Settings currently lists “local GGUF chat lanes” under active MAS
  June boundaries, and the Runtime Lanes inventory/policy table includes GGUF.
  The actual `LocalGGUFQuickChatBackend` is a retired adapter with
  `isAvailableInThisBuild == false`, so the diagnostics and witness router are
  claiming a model lane that cannot run.
- Apple Intelligence remains a real conditional June chat lane; GGUF model
  types/contracts may remain in shared/direct research code but must not appear
  in the MAS active inventory or default route chain.

### Constraints, acceptance checks, and next action

- MAS active boundaries name Apple Intelligence only, not local GGUF.
- `RuntimeLane.knownLanes`, MAS model-preference chains, and Runtime Lanes UI
  omit GGUF; OpenAI/Anthropic remain first and Apple Intelligence remains the
  only local chat fallback before the internal stub.
- Direct routing keeps its GGUF lane and shared enum/capability contracts. Add
  Swift/Rust source regressions first, then make conditional surgical edits and
  use parser/rustfmt/shell/diff/RSS checks only.

## Owner Steer 2026-07-10 — June Keeps Selected Local Models

### Verbatim owner wording and interpreted intent

> why is gguf disabled i wanted jue to have my seelct few local models nad ofc the cloud models

- The owner intends MAS June to expose and run a deliberately small local-model
  catalog in addition to the June-connected OpenAI/Anthropic cloud catalog.
  Kokoro voice models remain a separate preserved voice lane.
- GGUF was not disabled by the immediately preceding diagnostics edit: current
  source already defines `LocalGGUFQuickChatBackend` as a retired fail-closed
  stub with `isAvailableInThisBuild == false`. The diagnostics edit removed a
  false active claim while that runtime was absent.
- This steer reopens the MAS local-model product lane. The correct response is
  to reconnect the selected models through June's in-process, sandbox-safe
  architecture, then restore exact truthful catalog/diagnostic visibility.

### Hard constraints, non-goals, acceptance checks, and next action

- Keep OpenAI/Anthropic June models and Kokoro voices. Local chat models are an
  addition, not a replacement or cloud fallback hidden from the user.
- No subprocess, `llama-server`, local HTTP/stdio service, Node backend,
  terminal/code-exec path, hidden download, or unbounded resident model. Model
  selection/download/load/cancel/teardown must be explicit and memory-bounded.
- Do not call GGUF active merely by restoring labels. Done requires an actual
  in-process MAS-linked runtime, the selected catalog, sandbox-safe package
  storage/download receipts, June selection/routing, cancellation/teardown,
  and honest unavailable/error states.
- First reconcile the MAS pivot/master canon, exact intended local catalog,
  current target/package linkage, retired implementation history, and existing
  tests. Keep heavyweight Xcode/Cargo/model execution deferred under the RAM
  constraint; use source inspection and narrow static checks while rebuilding
  the lane.

### Historical finding and superseded checkpoint

- Commit `39df11d0f` (`Remove App Store llama runtime dependency`, 2026-07-06)
  deliberately replaced the live `EpistemosLlama` adapter with an unavailable
  stub and removed that package from `Epistemos-AppStore`. Its source comment
  says the purpose was preventing the MAS lane from importing or linking a
  llama runtime through stale DerivedData package artifacts.
- This is evidence of a conservative release-hardening rollback, not a
  categorical App Store prohibition on GGUF model data or an owner decision to
  abandon local models. Commit `813af1923` had added June local-model
  see/download/switch behavior two days earlier, and the repository still
  carries the pinned, in-process `EpistemosLlama` package/XCFramework path.
- The preceding `Retired GGUF Removed From Active MAS Truth` checkpoint remains
  correct only as an honesty repair for the then-disconnected runtime. Its
  product conclusion is now superseded by this explicit owner steer: keep GGUF
  absent from active diagnostics only until the real runtime is reconnected,
  then restore the exact truthful June local-model inventory and route.
- Next action: compare the last live backend and package linkage with current
  June selection/routing, downloader, sandbox, memory/cancellation, and release
  guards; add failing source-level contract tests before restoring linkage.

### Outcome and continuing debt

- The proven July 4 catalog is restored as the owner-selected boundary:
  Qwen3 4B, Qwen3 8B, and Qwen2.5 7B. Later Phi-3.5/TinyLlama rows are removed
  from June rather than silently expanding “selected few.” OpenAI/Anthropic
  cloud rows and all Kokoro voice code remain present.
- `Epistemos-AppStore` again links `EpistemosLlama` explicitly. The backend
  uses a direct `#if EPISTEMOS_APP_STORE` import instead of `canImport`, so
  stale DerivedData cannot activate or substitute the runtime. A temporary
  XcodeGen project produced the same ten package/product/framework references
  as the surgically preserved dirty project.
- The linked runtime remains the pinned b9870 llama.cpp XCFramework and is
  called only through the in-process `LlamaLocalChatEngine`. No subprocess,
  server, local port, JIT, downloaded runtime, or executable model asset was
  introduced. Cancellation, one-generation-at-a-time admission, memory-
  pressure teardown, bounded outer/inner streams, context refusal, and dynamic
  token-piece sizing are source-pinned.
- Each GGUF is now immutable-pinned to a repository commit, exact byte count,
  and LFS SHA-256. The downloader no longer trusts mutable `main` metadata. It
  caps transfer size, hashes with an 8 MB buffer, moves atomically inside the
  sandbox, and writes a deterministic verification receipt. Existing files
  must pass a one-time background hash before the backend can open them;
  subsequent launches validate receipt identity plus byte count without a
  multi-GB rehash.
- The existing sandbox Qwen3 4B file remains present at exactly 2,497,280,256
  bytes. It was not hashed or loaded in this session. The next current build
  will verify it in the background before exposing it as installed.
- The machine has 16 GB physical memory. Current conservative residency policy
  admits Qwen3 4B (5.2 GB estimated working set under a 5.44 GB local-lane
  ceiling) and leaves Qwen3 8B/Qwen2.5 7B visible but truthfully memory-gated.
  This preserves the selected catalog without risking swap to pretend every
  row is runnable on this Mac.
- The runtime fetcher now verifies the official GitHub release archive receipt
  plus pinned macOS binary/module-map/Info.plist digests before reusing its
  ignored XCFramework. The current artifact passes that verification without a
  network download.
- The App Review source audit now treats GGUF weights as pinned model data in
  Application Support while still rejecting executable-code downloads. Its
  MAS preprocessor evaluator was fixed after a red run falsely included
  compile-parked Experimental/Goose subprocess branches; the rerun passes all
  four checks with zero MAS subprocess surface.
- Low-memory evidence passes: strict Swift concurrency typecheck for the
  catalog/downloader/backend direct branch, MAS/direct parsing, package manifest
  dump, test-source parsing, PBX plist validation, fresh temporary XcodeGen
  linkage comparison, XCFramework digest verification, Rust formatting, shell
  syntax, App Review audit, source-contract checks, and `git diff --check`.
- No Xcode build/test/archive, Cargo build/check, app launch, provider request,
  or model load ran. A resource-bounded future build must prove the MAS module
  link, background receipt migration, June picker/download/switch behavior,
  one Qwen3 4B answer/cancel/teardown, exact bundle signing, and cloud/Kokoro
  coexistence before this becomes current-runtime or release-ready evidence.
- A clean checkout cannot resolve the local Swift package unless its ignored
  binary target exists. The shared Xcode wrapper now verifies/fetches the
  pinned b9870 XCFramework before package resolution, and CI caches then runs
  the same digest-verifying fetcher before XcodeGen/SPM work. Focused source
  tests lock that order so a warm developer checkout cannot hide the gap.
- The previous signed app is 222 MB with 91 MB of frameworks; the verified
  macOS llama framework is about 140 MB on disk. Their conservative additive
  estimate is about 362 MB, below the 600 MB release-gate ceiling. This is
  planning evidence only: a current archive and exact bundle scan still have
  to prove the actual packaged size, architecture slicing, signing, and MAS
  legality.
- The stale 2.5 MB staged June web tree was rebuilt from the current dirty but
  reviewed donor source under `NODE_OPTIONS=--max-old-space-size=768`. TypeScript
  and Vite completed in 11 seconds at 755,367,936 bytes maximum RSS with zero
  swap. The 27-file stage now contains the visible `June models` label, matches
  the donor shim byte-for-byte, parses as JavaScript, and contains no service
  worker, source map, or excluded commercial font.
- The post-stage KEELSTONE source gate initially exposed two guard defects: a
  multiline import prefix was compared as one line, and the OAuth guard
  expected a weaker obsolete spelling. The production OAuth branch already
  rejects every non-nil MAS credential and every non-June provider. The source
  assertions were corrected to that stronger contract; the complete gate now
  passes in about 2.1 seconds at roughly 10 MB RSS with zero swap.

## Checkpoint 2026-07-10 June Cloud Data Consent And Review Truth

### Verbatim owner steer and interpreted intent

> rmemeber i just want mas june if it is not june then it should ot be in my app
> the ai models i seen in the settings of my app they msut be connected to june
>
> but istill want to keep my voice models
>
> why is gguf disabled i wanted jue to have my seelct few local models nad ofc
> the cloud models

- The active product is one MAS June surface with admitted OpenAI/Anthropic
  cloud models, selected local GGUF chat, and separate Kokoro voice data.
- Release notes must describe that product literally. They currently claim no
  local model/runtime/download and server-held provider keys, while current
  MAS source bundles a precompiled llama runtime, downloads verified model
  data, and stores the user's OpenAI/Anthropic keys in Keychain.
- The same notes claim per-provider third-party AI consent, but the old consent
  store has no June call site. That is a real compliance gap, not a copy-only
  mismatch.

### Constraints, non-goals, acceptance checks, and next action

- Before any June cloud stream/provider request can receive prompt, history,
  selected vault context, or tool context, require explicit provider-specific
  consent. Local Apple/GGUF/Kokoro paths never require cloud consent.
- Consent is off by default, names OpenAI/Anthropic and the exact destination,
  persists only as a non-secret preference, is revocable in MAS Settings, and
  produces a precise visible June error when absent. API keys remain in
  Keychain and never enter June JavaScript.
- Do not revive OAuth/account-session, proxy/subscription, hidden provider,
  local server, or subprocess paths. Do not fabricate a report/block or
  content-moderation feature in review notes.
- Acceptance evidence is source-level first: a failing consent contract,
  guard at the final June cloud admission seam before `agentCoreRunner`,
  Settings grant/revoke control, honest Privacy/App Review copy, MAS/direct
  Swift parse, release gate, and diff checks. Runtime consent presentation and
  exact network non-transmission remain current-archive debt under the RAM
  constraint.

### Official policy validation and privacy-manifest consequence

- Apple's current App Privacy guidance defines collection as off-device
  transmission retained beyond real-time service, says ongoing collection
  after one consent must be disclosed, and lists `Other User Content` plus
  account-level `User ID` as collected-data categories. Guideline 5.1.2 also
  requires clear third-party AI disclosure and explicit permission.
- OpenAI's official API data-controls page says abuse-monitoring logs may retain
  prompts/responses for up to 30 days by default. Anthropic's official Privacy
  Center says API inputs/outputs are normally deleted within 30 days. The app
  cannot assume owner API keys have a special zero-retention agreement.
- Therefore the current empty `NSPrivacyCollectedDataTypes` array and “Never
  collected” UI are incorrect for the optional cloud lane. Declare Other User
  Content and provider account identifier as linked, non-tracking, App
  Functionality data; explain that local-only use transmits neither. App Store
  Connect privacy answers must match the manifest at submission.

### Outcome and continuing debt

- `AgentCloudConsentStore` is now the single app-lifetime, provider-specific
  preference authority. OpenAI and Anthropic start off, persist independently,
  and can be granted or revoked from their MAS June Settings cards. The control
  names the exact API host and the prompt/history/tool/vault-context boundary.
- Both explicit cloud-model selection and generic Cloud Agent resolution call
  `requireCloudDataConsent` before returning an `agent_core` provider slug.
  `makeAgentCoreCloudStream` resolves that guarded slug before invoking the
  runner. Missing consent yields a visible Settings path and `Nothing was
  sent`; local Apple/GGUF/Kokoro paths never enter this guard.
- `PrivacyInfo.xcprivacy` now declares exactly Other User Content and User ID,
  each linked, non-tracking, and App Functionality-only. The Privacy pane,
  App Review notes, root Phase S audit, and consolidated mirror use the same
  truth. App Store Connect answers still require owner submission access.
- The reviewed June web stage is now a source-control artifact contract rather
  than a self-ignored developer cache. Donor-present rebuilds use a frozen Bun
  lockfile; donor-absent clean CI validates and reuses the stage. The generated
  2.5 MB tree remains untracked in this dirty worktree because no staging or
  commit was authorized; clean-checkout reproducibility becomes real only when
  these generated files are eventually included in the repository history.
- Expected-red consent and empty-manifest probes preceded implementation.
  Exact plist validation, MAS/direct Swift parsing, test-source parsing, CI
  YAML parsing, donor-absent June stage validation, App Review source audit,
  `git diff --check`, and the complete KEELSTONE source gate pass with no
  Xcode/Cargo/model/application workload.
- Runtime debt: in the exact current archive, prove no provider request occurs
  before consent, grant/revoke OpenAI and Anthropic visibly, verify App Store
  Connect privacy metadata matches, and then prove literal June cloud output or
  the precise provider/model error.

## Owner Steer 2026-07-10 — Why Locals Were Disabled / Keep June Literal

### Verbatim owner wording and interpreted intent

> why was the locals disabled in the first place tho

- The owner wants the historical cause recorded plainly, not another removal:
  local GGUF was disabled by commit `39df11d0f` to prevent an App Store build
  from appearing to have a linked llama runtime only because stale DerivedData
  happened to contain the old package. It was a conservative dependency-
  integrity rollback, not a MAS policy ban or a product decision to discard
  the selected local models.
- “MAS June only” is literal visible identity. June must not be renamed to
  Workspace in the hosted UI, native chrome, prompt identity, diagnostics,
  loading/errors, or landing copy. Generic vault/document workspace concepts
  elsewhere are not additional AI products.

### Constraints, acceptance checks, outcome, and next action

- Keep the restored Qwen3 4B/Qwen3 8B/Qwen2.5 7B set, admitted cloud models,
  and Kokoro voices. Do not revive the old subscription/proxy cloud product.
- The MAS June overlay now preserves the June name and removes the DOM-wide
  June-to-Workspace rewrite. Native chat chrome, system prompts, transcript
  speaker labels, diagnostics, read-aloud fallback, and landing copy also say
  June. Source tests and the KEELSTONE gate reject future rebranding drift.
- `EpistemosProxyClient`, `AgentSubscriptionService`, and `JuneCloudEngine`
  are compile-parked behind an undefined legacy flag; no active target enables
  it and the active June gateway has no call into it. The visible Cloud Agent
  row describes only owner API keys, direct provider traffic, and consent.
- Cloud consent now also blocks Settings validation/Paste + Save and the
  retained direct `CloudLLMClient`, closing request paths outside the final
  June gateway guard before they can resolve credentials or send traffic.
- Kokoro remains a distinct preserved voice lane. Its remote manifest intake
  now rejects unsafe/duplicate paths, malformed SHA-256 digests, excess file
  fanout, aggregate-byte overflow/oversize, and downloaded byte-count mismatch
  before install. This changes no voice tier or installed voice choice.
- Expected-red source gates preceded each correction. MAS/direct Swift parse,
  focused test-source parse, shell syntax, `git diff --check`, and the complete
  low-memory KEELSTONE source gate pass. No Xcode/Cargo build, app/model launch,
  provider call, GGUF hash, or Kokoro download ran.
- Next action remains source-only Prompt 2 contradiction/bypass auditing under
  the RAM constraint, followed later by one resource-safe exact-archive/runtime
  proof batch for June naming, consent/no-network, GGUF, and audible Kokoro.
- A generated-byte sweep then found donor-owned visible `Workspace runs in
  Epistemos`, false “local June API” account copy, a mixed dictation/chat model
  section, and reachable Agent/skill/MCP/integration settings tabs. The donor
  now says June, describes the native MAS host, separates `June text models`
  from a clearly non-chat dictation model, hides every disconnected settings
  route in `localDev`, and hides server-verification copy for MAS. A single
  768 MB-capped rebuild completed in 10.50 seconds at 774,094,848 bytes maximum
  RSS with zero swap; post-stage validation initially failed only because the
  first guard targeted a tree-shaken header string, then passed against the
  actual visible native-host row without a second build.
- Native Settings received the same product-truth pass: Kokoro's visible
  refresh control no longer says Pro, and MAS Foundation/Privacy copy says
  June tools rather than advertising MCP configuration. Direct-only MCP/Pro
  branches remain compile-parked.
- The MAS call graph contains one admitted `runAgentSession` path after target
  exclusions: `JuneAgentGateway` -> `GooseMASAgentCoreRunner`. The runner now
  independently reverse-maps only the exact June OpenAI/Anthropic slugs and
  rechecks consent on the main actor immediately before the scoped agent_core
  environment/run. An unsupported slug or missing consent fails with `Nothing
  was sent`, so a future accidental caller cannot bypass June's gateway guard.

## Continuation Checkpoint 2026-07-10 — Vault Relaunch Grant Transaction

### Owner wording carried into this slice

> like i said please stop stopping just continue the loop idk what u hae to do
> to keep the loop going justkep it going
>
> gpt is taking 25 gb of ram pleasw stop doing massive tests bro

- Continue Prompt 2 autonomously, but use source-only and narrowly bounded
  verification until a resource-safe archive/runtime window is appropriate.
- Vault persistence is data-loss-class product scope. A vault that opens for
  one session but silently disappears after relaunch is not partial success.

### Constraints, acceptance checks, outcome, and next action

- A new MAS vault may not replace the active vault until Epistemos creates the
  security-scoped bookmark needed to restore it. Failed preparation must not
  alter the previous bookmark, path, suspicious-folder trust, or first-connect
  state. The new selection commits only after a successful switch.
- Expected-red guards proved the old flow switched before persistence and
  mutated `lastVaultPath` before bookmark creation could fail.
- `VaultSyncService` now uses an explicit prepare/commit transaction. Folder
  selection and recovery prepare relaunch permission before destructive state
  replacement; folder selection commits only after the switch succeeds.
- Focused tests lock fresh failure, preservation of a previous grant, and the
  prepare -> switch -> commit order. Swift parsing passed in 0.60 seconds at
  44,548,096 bytes maximum RSS with zero swap. The full KEELSTONE source gate
  passed in 2.52 seconds at 10,321,920 bytes maximum RSS with zero swap.
- Do not claim cross-relaunch sandbox proof from source. Exact signed-archive
  select/quit/relaunch/save evidence remains HIGH OPEN. Continue with source-
  only Prompt 2 editor/Epdoc/graph contradiction auditing.

## Continuation Checkpoint 2026-07-10 — Cooperative Graph First Open

- The remaining first-open graph path fetched and converted SwiftData records
  off-main, then synchronously built every GraphStore dictionary, adjacency
  list, created-order index, and trigram entry in one uninterrupted MainActor
  pass. On a large vault that can still present as a startup hang.
- `loadFromRecordsCooperatively` reuses the same node/edge insertion helpers and
  yields after bounded batches. Only `loadGraph(container:)` first-open loading
  uses it; the existing synchronous loader and semantics remain available.
- A focused async test locks 600 nodes/599 edges through the cooperative path.
  Source/test parse passed in 0.48 seconds at 39,960,576 bytes maximum RSS with
  zero swap. Exact archive startup timing remains runtime evidence debt.

## Continuation Checkpoint 2026-07-10 — Epdoc Save Registry Ownership

- The retained Document surface already avoids clean lens-switch serialization,
  but its async teardown could unregister a newer same-page surface because the
  save registry was keyed only by page ID.
- Every coordinator now owns a UUID registration token. Replacement surfaces
  overwrite the page entry, while stale teardown removes it only if its token
  still owns that entry. A focused regression test exercises the replacement
  race and confirms the new flusher remains callable.
- Focused source/test parse passed in 0.17 seconds at 41,598,976 bytes maximum
  RSS with zero swap. Rich-table fidelity still requires exact archive proof.

## Continuation Checkpoint 2026-07-10 — Source Lease Dirtiness Before Save Debounce

- CoreEditor already emitted a lightweight `contentDirty` metadata snapshot
  before its delayed full-text snapshot, but native code used it only to avoid
  reload. The note session stayed clean until the 900 ms persistence debounce,
  so another clean surface could take the lease while a keystroke was buffered.
- The dirty signal now reaches `NoteSessionStateMachine.recordUserEdit` once per
  pending text snapshot, before disk/index work. Debounced persistence remains
  unchanged and later advances dirty -> autosaving -> clean.
- The bridge's one-second fallback now checks `contentDirty.value`; the prior
  object check was always true and scheduled unnecessary snapshot work while
  idle.
- Focused six-file Swift parse passed in 0.36 seconds at 44,466,176 bytes
  maximum RSS with zero swap. Exact Code/Source typing/save proof remains HIGH
  OPEN in the signed archive.

## Continuation Checkpoint 2026-07-10 — Shared Document/Source Dirty Seam

- Epdoc's accepted Markdown change now calls the same
  `markEditorDirtyBeforeDebouncedSave` seam as Source before scheduling its
  two-second autosave. Matching initial-load echoes remain filtered by the
  controller and do not reach this callback.
- The early-edit lens-switch test now proves one dirty transition plus the
  existing fresh-snapshot save. Focused parse passed in 0.38 seconds at
  43,778,048 bytes maximum RSS with zero swap.
- The complete low-memory KEELSTONE gate passes after the combined vault,
  graph, Epdoc-registry, and editor-lease changes. Exact archive behavior is
  still required before Prompt 2 can close.

## Owner Steer 2026-07-10 — Preserve Installed Kokoro Voice Models

### Verbatim owner wording and interpreted intent

> but istill want to keep my voice models i forgot about that

- MAS June is chat/agent product scope, not a reason to remove or hide the
  separate Kokoro read-aloud models. A previously installed checked Kokoro
  package must remain discoverable and usable after upgrade.
- The audit found a legacy feature-gate mismatch rather than a MAS runtime ban:
  `EPISTEMOS_KOKORO_VOICE_PRO_V0` defaulted off, so an older valid package
  could display as `Kokoro voice: off` even though Settings no longer offered
  an enable toggle. New installs set the flag, but migrated installs could be
  stranded.

### Constraints, acceptance checks, outcome, and next action

- Package presence is only a validation trigger. Kokoro becomes ready only
  after the existing manifest, path/symlink, byte-count, digest, Core ML shape,
  runtime-asset, voice, and linked-runtime checks pass. Apple AVSpeech remains
  unavailable as a hidden fallback.
- `KokoroVoiceGateStatus` now considers an installed package candidate even
  when the obsolete flag is absent, then applies the complete existing safety
  validation. Missing packages say `not installed` and point to installation
  rather than implying a hidden toggle. Readiness logs distinguish the legacy
  flag from installed-package discovery.
- A hermetic regression fixture leaves the override absent and requires the
  checked installed package to reach native Core ML readiness. The expected-red
  source probe preceded implementation.
- Focused Swift parse and semantic checks pass at 42,582,016 bytes maximum RSS
  with zero swap. The complete KEELSTONE source gate passes at 10,059,776 bytes
  maximum RSS with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-kokoro-reactivation.log`.
- No voice package/model bytes were opened or hashed, and no Xcode build/test,
  app launch, or audio playback ran. Exact signed-archive discovery and audible
  Kokoro playback remain HIGH OPEN runtime proof. Continue Prompt 2 source-only
  hardening under the owner's RAM limit.

## Continuation Checkpoint 2026-07-10 — Same-Instance Epdoc Reactivation Ownership

- The earlier registry token fix protected a new coordinator from an old
  coordinator's teardown, but one coordinator retained a fixed token across
  reconfiguration. A rapid disappear/reappear could therefore let its delayed
  teardown unregister its newly active save flusher.
- Document registration ownership is renewed on each real surface appearance;
  ordinary Markdown/configuration updates reuse the active token.
  `onDisappear` captures the exact page/token pair synchronously before its
  async flush, then unregisters only that captured pair. Reactivation replaces
  the registry entry with a new token, so stale teardown cannot remove it.
- A serialized MAS regression covers same-coordinator reconfiguration and
  delayed old-token removal. Focused Swift parse passed at 41,500,672 bytes
  maximum RSS with zero swap. The full KEELSTONE source gate passed at
  10,289,152 bytes maximum RSS with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-epdoc-reactivation-registration.log`.
- No Xcode/WebKit/app workload ran. Exact archive rapid lens/notebook-tab
  switching and save durability remain HIGH OPEN. Continue to the Prompt 2
  code-editor editability path.

Appearance-scoping was added by the immediate self-audit: renewing on every
configuration could let a save-triggered update create a token after
disappearance captured the old one, leaking a registry entry. The revised
policy passed focused parse at 41,517,056 bytes maximum RSS and the full
KEELSTONE gate at 10,141,696 bytes maximum RSS, both with zero swap. Retained
log: `/tmp/keelstone-source-gate-20260710-epdoc-appearance-token.log`.

## Continuation Checkpoint 2026-07-10 — Source Lease Unlocks In Place

- Source/Code correctly threaded lease ownership into CoreEditor's
  `readOnlyMode`, but every writable/read-only transition was classified as a
  full editor reload. During initial lease acquisition or clean graph handoff,
  that could rebuild the WebView-backed editor, lose focus, or leave the owner
  perceiving the Source surface as view-only.
- Editability is now excluded from full-reload comparison and applied through
  MarkEdit CoreEditor's existing `webModules.config.setReadOnlyMode` bridge.
  The coordinator verifies `window.editor.state.readOnly`, invalidates stale
  callbacks by generation, and reloads only as a fail-closed fallback when the
  bridge fails and no editor text snapshot is pending.
- Expected-red source tests preceded implementation. Focused Swift parse and
  source-policy checks passed at 40,747,008 bytes maximum RSS with zero swap.
  The full KEELSTONE source gate passed at 10,665,984 bytes maximum RSS with
  zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-code-editability-inplace.log`.
- No WebKit/app interaction or compiled test ran. Exact archive Source/Code
  focus, typing, lease handoff, save, and relaunch durability remain HIGH OPEN.
  Continue source-only editor recovery/performance auditing.

## Continuation Checkpoint 2026-07-10 — Source Web-Process Recovery

- The default MarkEdit/CoreEditor path explicitly left a dead blank editor
  after WebKit content-process termination and required a manual reopen. That
  contradicted Prompt 2's recovered, editable Source requirement.
- Termination now selects pending, last-applied, or loading state in that order,
  prevents an empty renderer state from dominating non-empty host text, and
  reloads the same WebView from the recovered state. No save callback is fired
  by recovery. If WebKit died after an edit-dirty signal but before the full
  text snapshot, the log states that limitation rather than implying every
  keystroke was recovered.
- A pure regression pins empty-renderer/non-empty-host precedence and source
  guards pin automatic reload. Focused parse passed at 40,648,704 bytes maximum
  RSS with zero swap. Full KEELSTONE passed at 10,518,528 bytes maximum RSS
  with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-code-process-recovery.log`.
- No WebKit process was killed and no app/Xcode workload ran. Exact archive
  process-recovery, typing, and save durability remain HIGH OPEN.

## Continuation Checkpoint 2026-07-10 — Reactivated Note Session Survives Stale Close

- `NoteDetailWorkspaceView.onDisappear` awaited the file-first editor flush and
  then unconditionally closed the note lease. If the same SwiftUI workspace
  reappeared before that await completed, the old task could close its newly
  active session and push Source/Code back toward follower/read-only state.
- The workspace now advances an appearance generation on appear and disappear.
  Owner teardown captures its generation, performs the required flush, and
  closes only if no later appearance superseded it. Normal completed teardown
  still releases the lease; follower teardown remains immediate.
- Expected-red MAS source guards preceded implementation. Focused parse and
  order proof passed at 43,614,208 bytes maximum RSS with zero swap. Full
  KEELSTONE passed at 10,469,376 bytes maximum RSS with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-note-session-reactivation.log`.
- No UI lifecycle or Xcode test ran. Exact archive rapid disappear/reappear,
  lease ownership, continued typing, and save proof remain HIGH OPEN.

## Continuation Checkpoint 2026-07-10 — Cooperative Structural Graph Fallback

- Graph first-open indexing already yielded cooperatively, but
  `refreshStructuralDataAsync` still used one synchronous MainActor
  `loadFromRecords` pass when label/type/edge changes made incremental refresh
  impossible. That fallback can run while the graph-embedded editor is visible.
- The full-reload fallback now awaits the same bounded cooperative loader as
  first open. BackgroundGraphActor still owns SwiftData build/persistence; the
  change bounds only the remaining Swift dictionary, adjacency, order, and
  trigram-index work before the renderer's eventual recommit.
- Expected-red source checks preceded the one-path change. Focused parse and
  semantic proof passed at 43,073,536 bytes maximum RSS with zero swap. Full
  KEELSTONE passed at 10,256,384 bytes maximum RSS with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-graph-structural-cooperative.log`.
- No graph runtime/Xcode workload ran. Exact archive structural-refresh timing,
  partial-load visibility, embedded typing responsiveness, and final recommit
  remain HIGH OPEN.

## Continuation Checkpoint 2026-07-10 — Automatic Restore Retains Vault Selection

- Despite earlier transient-scope/readability preservation, automatic launch
  restore still deleted `epistemos.vaultBookmark` on generic resolution,
  non-security-scoped, stale-refresh, and suspicious-folder reconfirmation
  branches. A second transient resolution failure after preflight could thus
  permanently unselect the owner's vault.
- Automatic restore is now non-destructive: every failure may block access and
  request re-selection, but the saved bookmark remains available for retry or
  replacement. Suspicious-folder trust is still cleared when reconfirmation is
  required. Explicit disconnect/disconnect-in-progress remains the authorized
  path that clears the persisted selection.
- Expected-red source isolation counted four destructive branches before the
  patch. Focused parse and no-removal section proof passed at 43,909,120 bytes
  maximum RSS with zero swap. Full KEELSTONE passed at 10,158,080 bytes maximum
  RSS with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-vault-restore-retention.log`.
- No bookmark was resolved under the sandbox and no app/Xcode workload ran.
  Exact archive quit/relaunch/restore/edit/save remains HIGH OPEN.

## Continuation Checkpoint 2026-07-10 — Source Must Flush The Live Web Buffer

### Owner intent and constraints

- Continue Prompt 2 autonomously without a keyword or stop between plan units.
- Preserve the selected June local GGUF models and Kokoro voice, while keeping
  this pass source-only because the owner reported roughly 25 GB RAM use from
  prior heavy verification. Do not run Xcode, Cargo, app, model, or broad test
  workloads during this unit.
- Source saves must not trade responsiveness for durability: retain adaptive,
  debounced full-text IPC during typing, but obtain the exact live buffer for
  explicit save, lens switch, and teardown.

### Finding, done bar, and next action

- MarkEdit sends an early dirty signal, then intentionally delays its complete
  text snapshot by 240–700 ms. `flushCurrentEditor` currently reads only the
  last host snapshot, so a rapid switch/close can start persistence before the
  newest WebKit buffer reaches Swift. `CodeEditorView.onDisappear` has the same
  stale-host risk even though it correctly flushes its save debouncer.
- Add one registration-token-owned live-text query for the mounted CoreEditor,
  thread a workspace-unique key through Source, and make the parent flush query
  it before deciding what to persist. The query must be on-demand only; no new
  polling or per-keystroke full-buffer copy is allowed. Preserve legacy editor
  fallback and fail closed to the last host snapshot if the WebView is already
  unavailable.
- Acceptance checks: exact buffer query precedes Source persistence; Markdown
  frontmatter/body and non-Markdown code paths retain their existing writers;
  stale representable teardown cannot unregister a replacement; focused Swift
  parse/source guards and the low-memory KEELSTONE gate pass with zero swap.
  Exact archive rapid-type -> switch/close -> reopen proof remains HIGH OPEN.
- The expected-red source probe found no live-text registry/query symbols. Next
  action: implement the narrow registry/query and async Source flush, then
  inspect the diff and run only low-memory verification.

### Outcome and continuing debt

- The mounted CoreEditor now owns a workspace-keyed, token-protected live-text
  query. Explicit save, lens switch, and disappearance query
  `getEditorText()` before selecting a Source payload and await the existing
  Markdown/code persistence paths. A dirty Source fails closed if an exact
  buffer cannot be obtained; failed persistence prevents lease close.
- Dismantle replaces its registry closure with a bounded final WebView query
  before detaching, retains it for two seconds, and unregisters by the captured
  token. A newly mounted replacement cannot be removed by that stale cleanup.
  The registry retries once when detach supersedes an in-flight query.
- Parent-owned teardown suppresses CodeEditorView's old host-snapshot debouncer
  flush, preventing a stale duplicate write from racing and landing after the
  exact parent write. Normal 900 ms autosave and adaptive 240–700 ms typing
  snapshots remain unchanged.
- Focused source/test parsing and scoped diff checks pass at 44,843,008 bytes
  maximum RSS with zero swap. The expanded KEELSTONE source gate passes at
  10,272,768 bytes maximum RSS with zero swap; retained log:
  `/tmp/keelstone-source-gate-20260710-source-live-flush.log`.
- No Xcode build/typecheck/test, WebKit/app runtime, model, or archive workload
  ran. Exact archive rapid-type -> Save/switch/close -> reopen byte fidelity,
  frontmatter fidelity, code-file fidelity, query timeout behavior, and focus
  remain HIGH OPEN. Continue to the next Prompt 2 save/lifecycle seam.

## Continuation Checkpoint 2026-07-10 — Source Writes Must Commit In Order

- The 900 ms Source debounce bounds write frequency but does not serialize its
  asynchronous Markdown/code writer. A second burst or final flush can start
  while the first filesystem write is suspended, allowing older content to
  finish last and overwrite newer content.
- Keep the existing debounce and exact live-buffer final query. Add one
  workspace-owned persistence task chain so each write awaits its predecessor;
  final save/switch/teardown must drain the queued writer before querying and
  persisting the newest live buffer. Do not cancel an in-flight durability task
  merely because the SwiftUI surface disappeared.
- Acceptance: normal debounced writes and final writes share the same writer,
  enqueue order equals commit order, final flush waits for prior work, failures
  leave the session dirty for the exact final retry, and low-memory parse/gate
  checks pass. The expected-red probe found no persistence-chain state/helper.

### Outcome and continuing debt

- All Source writes now enqueue behind the previous workspace persistence task;
  the final live-buffer save uses the same queue and awaits its result. The task
  is not canceled during SwiftUI disappearance.
- Source editor revisions advance on the early dirty signal and on a changed
  host snapshot. A write captures its revision; completion updates the host
  snapshot and marks clean only when no newer revision exists. Otherwise it
  leaves the newer edit dirty and cannot overwrite the newer in-memory Source
  snapshot with older canonical content.
- Focused Swift source/test parse and diff checks pass at 44,417,024 bytes
  maximum RSS with zero swap. The expanded KEELSTONE source gate passes at
  9,846,784 bytes maximum RSS with zero swap; log:
  `/tmp/keelstone-source-gate-20260710-source-save-order.log`.
- No compiled typecheck/test, filesystem concurrency runtime, app, model, or
  archive workload ran. Exact archive multi-burst ordering and failure/retry
  behavior remain HIGH OPEN. Continue Prompt 2 lifecycle/write auditing.

## Continuation Checkpoint 2026-07-10 — Epdoc Autosave Must Be Ordered

- Epdoc's two-second debounce cancels `saveTask`, but cancellation does not
  guarantee that an already-started async `saveMarkdown` stops. A later edit or
  direct flush can therefore write concurrently, let old Markdown finish last,
  or let an old completion mark newer content clean.
- Separate debounce ownership from durability ownership. Serialize every Epdoc
  Markdown writer behind a task tail, capture page identity and editor revision,
  keep newer revisions dirty, and coalesce concurrent explicit/parent flushes.
  A flush must restore the current content after any outstanding older writer,
  even when the current content equals the last known flushed baseline.
- The expected-red source probe found no revision, write-tail, or coalesced
  flush symbols. Verification remains low-memory parse/source gate only; exact
  runtime delayed-write ordering stays HIGH OPEN.

### Outcome and continuing debt

- Debounce tasks no longer own durability. Every Epdoc Markdown write captures
  its writer, page identity, content, and editor revision, then awaits the
  preceding write tail. Cancellation can suppress a not-yet-enqueued debounce,
  but cannot create a competing filesystem writer.
- Successful same-page completion always records which Markdown actually
  reached disk, but marks the editor clean only if its revision is still
  current. Page replacement queues the old page's final content using the old
  writer before installing the new writer.
- Concurrent flush calls coalesce. The active flush cancels newer debounce work
  it subsumes, loops through edits arriving during an awaited write, restores
  baseline content after an outstanding older writer, and fails closed after
  three unstable revisions rather than claiming a clean switch.
- A deterministic MAS test now gates a delayed first writer, injects a second
  edit and joined flush, and requires save order `[first, second]` with a clean
  newest state. It was added but not compiled/executed under the RAM constraint.
- Focused parse/diff checks pass at 42,565,632 bytes maximum RSS, zero swap.
  Expanded KEELSTONE source gate passes at 10,715,136 bytes maximum RSS, zero
  swap; log `/tmp/keelstone-source-gate-20260710-epdoc-save-order.log`.
- Exact archive delayed-write execution, byte order, error retry, table
  fidelity, and reopen remain HIGH OPEN. Continue Prompt 2 source hardening.

## Continuation Checkpoint 2026-07-10 — File-First Note Writes Need One Service Order

- Prose still owns an independent five-second async writer, while parent lens
  teardown, Epdoc, Source, graph inline edit, intents, and diff application all
  call `VaultSyncService.savePageBodyFileFirst`. Local per-surface queues cannot
  order writes across those callers.
- Add one per-page service queue around the complete file-first transaction,
  preserving the existing implementation as a private operation. Invocation
  order must determine transaction order across every lens/caller; unrelated
  pages may continue independently. Remove completed tails by generation.
- This is a narrow data-safety spine, not a save-frequency or UI change. The
  expected-red probe found no service-level file-first task tail. Verification
  stays parse/source-gate only; exact cross-lens delayed-write runtime proof is
  HIGH OPEN.

### Outcome and continuing debt

- `savePageBodyFileFirst` now enqueues the complete transaction behind the last
  task for the same page ID, then invokes the prior implementation through
  `performPageBodyFileFirstSave`. Generation-checked cleanup removes only the
  current completed tail. Different page IDs retain independent queues.
- Added a deterministic audit test whose first export blocks inside the test
  override; a second same-page save must not enter the override until the first
  is released. The test is source-added but not compiled/executed in this
  low-memory pass.
- Focused Swift parse/diff checks pass at 44,122,112 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,633,216 bytes maximum RSS,
  zero swap; log `/tmp/keelstone-source-gate-20260710-file-first-order.log`.
- No real filesystem concurrency, Xcode, app, model, or archive workload ran.
  Exact cross-lens ordering, failure progression, and final disk bytes remain
  HIGH OPEN. Continue Prompt 2 save/quit lifecycle auditing.

## Continuation Checkpoint 2026-07-10 — Quit Must Await Live Note Surfaces

- `applicationShouldTerminate` currently calls synchronous teardown before
  `applicationWillTerminate` and SwiftUI termination publishers run. Prose's
  termination handler can therefore stage its newest buffer too late, while
  Source/Epdoc async file-first tasks can still be suspended when process exit
  is approved.
- Add a renewable workspace final-flush registry, expose all-Document flush,
  and add a per-page file-first tail drain. Quit approval must become
  `.terminateLater`: stage visible Prose buffers, await workspace/Document
  flushes, drain file-first and dirty-save work, synchronously persist recovery
  drafts, then perform teardown and reply exactly once.
- Preserve cancel semantics in the existing quit panel and do not turn app
  termination into an unbounded wait. A failed surface flush should retain
  local drafts and log honestly; the user-authorized quit may still proceed.
- Expected-red probing found none of the required registry/drain/async-quit
  seams. Verification remains low-memory source-only; exact signed-archive
  quit/relaunch byte proof stays HIGH OPEN.

### Outcome and continuing debt

- Each mounted note workspace now registers a renewable final-flush closure;
  disappearance unregisters only its captured token. Document's save registry
  can also flush every mounted surface. The service can drain all per-page
  file-first tails with generation-safe cleanup.
- Quit now always returns `.terminateLater` once authorized. It synchronously
  flushes standalone Epdoc pipelines, requests live Prose staging, awaits active
  workspace and Document flushes, drains file-first writes, awaits dirty-page
  export, drains again, persists recovery drafts, then tears down and replies
  exactly once. A 12-second one-shot deadline logs incomplete durability,
  retains recovery drafts, cancels the waiter, and allows the authorized quit.
- Added source regression `quitAwaitsActiveNoteDurability`; no compiled/runtime
  execution under the RAM constraint.
- Focused Swift parse/diff checks pass at 44,285,952 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,240,000 bytes maximum RSS,
  zero swap; log `/tmp/keelstone-source-gate-20260710-termination-flush.log`.
- Exact archive Cmd-Q/cancel/timeout/relaunch, newest Source/Document/Prose
  bytes, and UI responsiveness remain HIGH OPEN. Continue Prompt 2 audit.

## Continuation Checkpoint 2026-07-10 — GGUF Unload Must Exclude New Turns

- June's 16 GB gate remains intentionally narrow: Qwen3 4B's estimated 5.2 GB
  working set fits the 5.44 GB constrained-machine limit; Qwen3 8B (7.6 GB)
  and Qwen2.5 7B (6.8 GB) remain visible but cannot download/run there.
- The memory-pressure unload path has a race: when no generation is active it
  schedules `engine.unload()` asynchronously without marking the backend as
  unloading. A new turn can observe the old model as loaded, skip load, and
  queue generation behind an unload that removes its context.
- Add lock-owned unloading state. Immediate and post-generation unload must
  clear loaded identity and exclude new generations before scheduling engine
  work; unload completion reopens generation. Repeated pressure while unloading
  is a no-op. Do not change the selected three-model catalog or default keep-warm
  policy.
- Expected-red probing found no unload-state seam. No model bytes, engine, app,
  Xcode, or memory workload may run; source-only verification remains the bar.

### Outcome and continuing debt

- `LocalGGUFQuickChatBackend` now owns explicit `isUnloading` state. Both an
  immediate pressure unload and a deferred post-generation unload clear the
  loaded model identity and exclude new turns before scheduling engine work.
  Completion reopens generation; repeated pressure while unloading coalesces.
- The selected catalog and 16 GB policy are unchanged: Qwen3 4B remains the
  admitted local model, while Qwen3 8B and Qwen2.5 7B remain visible and
  memory-gated. Normal keep-warm behavior also remains unchanged.
- Focused Swift source/test parse and scoped diff checks pass at 40,468,480
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate passes at
  10,665,984 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-gguf-unload-race.log`.
- No GGUF bytes, llama engine, app, Xcode, archive, or provider workload ran.
  Exact archive model load, pressure notification, in-flight completion,
  unload, next-turn reload, and memory reclamation remain HIGH OPEN. Continue
  Prompt 2 source hardening without widening the model catalog.

## Continuation Checkpoint 2026-07-10 — Epdoc Assist Must Not See A Clean Blank Snapshot

- Owner continuation remains: “just do the full plan,” with the later resource
  constraint “gpt is taking 25 gb of ram pleasw stop doing massive tests bro.”
- Interpreted intent: continue Prompt 2 autonomously with low-memory source
  hardening; do not substitute a blank Epdoc bridge projection for the
  non-empty canonical Markdown passed to June.
- Current contradiction: visible Epdoc reactivation already rejects a clean
  empty WebKit snapshot over non-empty host Markdown, but
  `JuneEpdocAssistContext` still uses `latestMarkdownSnapshot ?? markdown`.
  A present-but-empty clean snapshot therefore hides the host body from June.
- Add one coordinator-owned assist-context resolver. Clean context prefers a
  non-empty host body; dirty context preserves the live editor snapshot,
  including an intentional empty edit. Add focused regressions and source-gate
  witnesses. Do not change the editor bridge, Markdown writer, model routing,
  or any parked chat surface.
- Verification remains Swift parse, scoped diff, and the low-memory KEELSTONE
  source gate only. Exact Epdoc + June runtime context proof remains HIGH OPEN.

### Outcome and continuing debt

- `MarkdownDocumentSurface` now resolves June assist Markdown through its
  coordinator. Clean state uses the canonical host Markdown instead of a
  present-but-empty bridge snapshot; dirty state preserves the latest live
  bridge snapshot, including an intentional empty document.
- Added focused resolver regressions plus MAS source witnesses. The tests are
  source-added but were not compiled or executed under the owner RAM limit.
- Focused Swift source/test parse passes at 45,809,664 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,469,376 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-assist-context.log`.
- No WebKit, app, Xcode, model, or provider runtime ran. Exact archive proof
  that June receives rich tables/current unsaved edits after Epdoc reactivation
  remains HIGH OPEN. Continue Prompt 2 source hardening.

## Continuation Checkpoint 2026-07-10 — Epdoc Parent Lease Must Follow Revisions

- Epdoc's coordinator now orders writes and preserves its own dirty toolbar,
  but `saveMarkdownDocumentSurfaceContent` still calls
  `noteSession.finishAutosave(succeeded: true)` after every successful write.
  If a newer Epdoc edit arrives while an older write is suspended, the older
  completion can incorrectly mark the shared note lease clean.
- Add a Document editor revision owned by the note workspace. Advance it on
  each immediate Epdoc edit signal, capture it when the parent save starts,
  and clear the shared lease only when the captured revision is still current.
  A stale success may update persisted truth but must leave the note dirty and
  must not overwrite the newer mode snapshot.
- Do not change save frequency, Epdoc bridge serialization, or the single
  Markdown source of truth. Verification stays parse/source-gate only; exact
  delayed-write lens-handoff execution remains HIGH OPEN.

### Outcome and continuing debt

- The workspace now advances `documentEditorRevision` on Epdoc's immediate
  edit signal and captures it when a parent file-first save starts.
- A successful current-revision write updates the lens snapshot/metrics and
  clears the note lease. A stale success updates only persisted truth and
  explicitly leaves the shared note session dirty, so it cannot authorize a
  clean handoff or hide the newer edit.
- Focused Swift source/test parse passes at 47,218,688 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,108,928 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-parent-revision.log`.
- No Xcode, delayed writer, app, WebKit, or archive runtime ran. Exact old-save
  completion versus newer Epdoc edit, lens handoff, and reopen bytes remain
  HIGH OPEN. Continue Prompt 2 source hardening.

## Continuation Checkpoint 2026-07-10 — Prose Draft Cleanup Must Match Durable Bytes

- A canceled Prose debounce does not necessarily stop an already-awaited
  file-first save. If save A completes after edit B has written a newer crash
  draft, A currently calls unconditional `NoteDraftStore.delete(pageId:)` and
  can erase B's only short-window recovery copy.
- `NoteDraftStore.write` also refuses empty bodies, so an intentional clear is
  not crash-recoverable before the five-second durable save and a stale older
  non-empty draft can win on relaunch.
- Serialize draft write/delete decisions with a small process-local lock. A
  durable completion may delete only a draft whose exact bytes match that
  completion. Permit and reconcile empty draft bodies as intentional state.
  Keep drafts non-canonical and keep recovery through the file-first writer.
- No filesystem stress, app, Xcode, or crash loop under the RAM constraint;
  add pure matching regression/source witnesses and retain exact crash/relaunch
  behavior as HIGH OPEN.

### Outcome and continuing debt

- `NoteDraftStore` now serializes atomic writes and conditional cleanup with a
  process-local lock. Prose save completion deletes a draft only when its text
  exactly matches the body that just became durable.
- Empty bodies are written and reconciled as intentional recovery state.
  Launch reconciliation also uses matching cleanup after its awaited vault
  operation, so it cannot remove a draft replaced while recovery was in flight.
- Added a pure exact-match regression plus MAS source witnesses. Focused Swift
  source/test parse passes at 45,105,152 bytes maximum RSS, zero swap. Expanded
  KEELSTONE source gate passes at 10,584,064 bytes maximum RSS, zero swap;
  retained log `/tmp/keelstone-source-gate-20260710-prose-draft-order.log`.
- No real crash, relaunch, concurrent draft filesystem workload, Xcode, or app
  ran. Exact empty-edit recovery, older-save/newer-draft ordering, and cleanup
  after successful/stale recovery remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Prose Must Mark The Shared Lease Dirty Early

- Document and Source report dirty state before their debounced snapshots, but
  `ProseEditorView` currently schedules its durable save and recovery draft
  without notifying `NoteSessionStateMachine` when the accepted body changes.
- This leaves a window where a second note session can interpret the current
  lease as clean even though Prose contains unsaved text.
- Add a defaulted Prose `onEditStarted` callback and invoke it after the same
  loaded-page/persisted-body guards that already admit a real change. The note
  workspace wires it to the existing shared early-dirty function. Do not alter
  TextKit input, save debounce, or other Prose call sites.
- Verification stays parse/source-only; exact two-window lease-handoff behavior
  remains HIGH OPEN.

### Outcome and continuing debt

- `ProseEditorView` now has a defaulted early-edit callback. Its guarded
  `bodyText` change path invokes the callback before scheduling the five-second
  durable save and 1.5-second crash draft.
- The note workspace wires that callback to the same
  `NoteSessionStateMachine.recordUserEdit` seam used by Document and Source.
  Programmatic loads that already match the persisted body remain filtered.
- Focused Swift source/test parse passes at 46,841,856 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,305,536 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-early-dirty.log`.
- No TextKit app runtime, two-window handoff, compiled test, Xcode, or archive
  ran. Exact typing/lease/focus/save behavior remains HIGH OPEN. Continue
  Prompt 2 source hardening.

## Continuation Checkpoint 2026-07-10 — Quick Capture Preview Leaves The Keystroke Path

- The Prompt 2 blocker list names Quick Capture typing hangs. Current source
  recomputes `PreviewSignals(text: captureText)` as a derived property and reads
  it from both the header and preview strip during SwiftUI rendering. That
  multi-pass text scan therefore runs repeatedly on MainActor for every edit.
- The Quick Capture canon preserves immediate deterministic feedback, but does
  not require preview-only signal extraction in the input event itself; the
  authoritative structured extraction remains submit-time pipeline work.
- Cache preview signals in view state, cancel superseded work, wait for a short
  quiet window, compute off-main, and apply only when the captured text is still
  current. Do not change capture submission, graph writes, voice behavior, or
  visible signal semantics.
- Verification stays parse/source-gate only. Exact typing latency and UI update
  behavior in the signed archive remain HIGH OPEN.

### Outcome and continuing debt

- Quick Capture now stores preview signals in state, cancels superseded work,
  waits 120 ms for input to settle, computes its multi-pass scan on a utility
  task, and applies the result only if the captured text is still current.
- The header and chip strip reuse the same cached result. Submit-time
  `TextCapturePipeline` extraction, graph writes, voice, and visible signal
  categories are unchanged.
- Focused Swift source/test parse passes at 45,481,984 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,305,536 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-quick-capture-preview.log`.
- No app typing, long paste, SwiftUI render measurement, Xcode, or archive ran.
  Exact keystroke latency and preview freshness remain HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — Graph Startup Ordering Leaves MainActor

- Background SwiftData fetch and cooperative node/edge ingestion are already
  off-main/yielding, but `loadFromRecordsCooperatively` immediately calls
  `rebuildCreatedOrderIndex()`, which sorts the full node dictionary on
  MainActor without a yield.
- Preserve newest-first order and the existing ID tie-break while computing the
  order from Sendable records in a utility task. Assign the completed order on
  MainActor before edge intake continues. Hidden graph node types remain
  excluded exactly as today.
- Do not change graph contents, route behavior, physics, filters, or renderer
  payloads. Add an order regression and source witnesses. Verification remains
  parse/source-only; exact large-vault startup timing remains HIGH OPEN.

### Outcome and continuing debt

- Cooperative graph loading now starts a utility-priority deterministic order
  task from the Sendable node records, performs bounded MainActor node intake,
  then installs the completed newest-first order. Hidden types and the existing
  equal-date ID tie-break remain unchanged.
- The synchronous load paths reuse the same ordering helper, preventing
  semantic drift. Added an order regression through
  `forEachNodeNewestFirst`; source-added, not executed here.
- Focused Swift source/test parse passes at 45,481,984 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,469,376 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-graph-created-order.log`.
- No large graph, app, Metal renderer, Xcode, or archive ran. Exact large-vault
  startup duration, editor transition latency, and content correctness remain
  HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Hidden Hologram Sidebar Must Quiesce

- The overlay hides its graph sidebar host on note/folder routes but keeps the
  SwiftUI hierarchy mounted. `expandedSidebar.onChange(graphDataVersion)` can
  therefore snapshot every node and edge and rebuild its cache while the user
  types/saves inside the graph-native note editor.
- Cancel/skip sidebar cache work whenever the route is not canvas. Observe route
  changes so returning to canvas rebuilds any cache that became stale while
  hidden. Embedded-home behavior remains compatible because its sidebar is
  already conditionally mounted only on canvas.
- Do not change graph search results, cache builder semantics, editor behavior,
  or renderer state. Verify with parse/source gates only; exact hologram typing
  latency remains HIGH OPEN.

### Outcome and continuing debt

- Hologram sidebar graph-version changes now return immediately off-canvas.
  Route changes cancel any in-flight cache build when entering a note/folder
  and refresh stale cache/search state when the canvas becomes active again.
- `refreshGraphSidebarCachesIfNeeded` also fails closed off-canvas, covering
  indirect callers. Cache builder and visible search semantics are unchanged.
- Focused Swift source/test parse passes at 45,219,840 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 9,945,088 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-hologram-sidebar-quiesce.log`.
- No hologram, editor typing, topology mutation, Xcode, or archive runtime ran.
  Exact route-transition/cache-freshness and typing latency remain HIGH OPEN.
  Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Explicit June Model Selection Must Be Exact

- Owner asks why local GGUF was disabled and why models appear in Settings if
  they are not connected to June. Current explicit selection calls the same
  `repairedDefaultModelID` used for stale restore. For a configured cloud
  provider, that repair can substitute the provider's previously preferred
  model instead of the exact row the user just selected.
- Memory-gated GGUF selection correctly rejects, but the bridge collapses that
  into “not connected to MAS June,” hiding that the model is connected and only
  blocked by this Mac's memory policy.
- Separate explicit exact admission from restore-time fallback repair. Explicit
  selection must persist the requested admitted ID or fail. Surface a precise
  connected-but-memory-gated local message and a precise cloud-configuration
  message. Do not broaden the three GGUFs, cloud providers, or runtime routes.
- Verification stays parse/source-gate only; no model bytes, downloads, keychain
  access, provider calls, app, or Xcode runtime.

### Outcome and continuing debt

- `explicitlyAdmittedModelID` now owns user-initiated model changes. It returns
  the exact requested ID only after the current June cloud/local admission
  checks. `repairedDefaultModelID` remains limited to stale restore/turn repair.
- Settings and `/model` failures now use `modelSelectionFailureMessage`: a
  memory-gated GGUF says it is connected to June but cannot run on this Mac and
  includes the gate copy; a cloud row names the provider that must be configured.
- Focused Swift source/test parse passes at 44,269,568 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,977,280 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-exact-model-selection.log`.
- No keychain read, provider call, download, GGUF/model byte, app, Xcode, or
  archive ran. Exact June picker selection/error rendering and persistence
  remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Prompt Submit Cannot Hide Model Rejection

- Follow-up contradiction audit found `prompt.submit` reduces its requested
  model through `validModelID`, replies success, then `startTurn` ignores the
  Bool returned by `setSessionModel`. A memory-gated local ID is catalog-valid
  but explicitly inadmissible, so the turn can silently retain its prior model.
- Admit and persist any requested model before replying to submit. On failure,
  return the same precise model-selection error and do not append the prompt or
  start a turn. Remove the ignored model-setting branch from `startTurn`.
- Keep Epdoc assist/default-model behavior unchanged. Verification remains
  source-only with zero model/provider execution.

### Outcome and continuing debt

- `session.create` now exact-admits a non-empty requested model before creating
  the session. `prompt.submit` exact-admits/persists its requested model before
  replying success or appending the prompt. `startTurn` no longer contains an
  ignored `setSessionModel` result.
- Catalog-only `validModelID` was removed so catalog visibility cannot be
  mistaken for runtime admission. Session/model-change entry points share the
  precise connected-memory/cloud-configuration failure copy.
- Focused Swift source/test parse passes at 44,105,728 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,534,912 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-submit-model-admission.log`.
- No model/provider/download/keychain/app/Xcode/archive runtime ran. Exact UI
  error propagation, session persistence, and next-turn routing remain HIGH
  OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — No Keyword Pause; Keep The RAM-Safe Loop Moving

### Verbatim owner wording

> and i mena beyo just go back like i am ot llaing the keyword shit anymroe stop sahing i ned to type go back i not typingthat shit just do the full plan

> gpt is taking 25 gb of ram pleasw stop doing massive tests bro

### Interpreted intent

- The earlier temporary `go back` control-word condition is revoked. Continue
  the dependency-ordered MAS-only plan without asking for or awaiting a keyword
  and without stopping at prompt boundaries.
- The RAM steer limits proof workload, not implementation progress: keep doing
  focused source hardening and low-RAM static verification, then consolidate
  heavyweight archive/runtime/manual evidence into one resource-safe batch.

### Hard constraints and non-goals

- Do not run Xcode/Cargo build-test-archive work, models, broad app automation,
  or competing heavyweight jobs while the active RAM constraint remains.
- Do not use a stale app/archive as current-source runtime proof. Do not claim
  Prompt 2 complete or advance to Prompt 3 while its exact-runtime blockers are
  still open.
- Historical owner quotations may remain in durable ledgers, but no active
  handoff or operating rule may require the revoked keyword.

### Acceptance checks and outcome

- `HANDOFF_MAS_BASE_APP_COMPLETION_2026_07_10.md` now explicitly requires
  autonomous continuation, forbids keyword waits, and separates current
  source/static work from the later resource-safe exact evidence batch.
- A focused stale-directive search finds no actionable wait-for-keyword or
  `go back` condition in the active handoff. `git diff --check` passes for it.
- Continue Prompt 2 source hardening now; exact archive/runtime evidence remains
  HIGH OPEN and queued for the controlled batch.

## Continuation Checkpoint 2026-07-10 — Session Ensure Cannot Ignore June Model Admission

- June's built web UI calls `ensure_hermes_bridge_session` with the session's
  chosen model before `prompt.submit`; normal submit then sends only the runtime
  session ID and text. The native bridge currently discards the Bool returned by
  `gateway.setSessionModel`, so this compatibility seam can report success even
  when the requested model was rejected.
- Route this command through a validating invoke handler. A non-empty model must
  persist exactly or reject with `modelSelectionFailureMessage`; title-only
  ensure behavior remains supported and bounded. Remove the ignored Bool.
- Do not change model allowlists, RAM policy, downloader behavior, provider
  consent, session creation, or prompt contents. Verification stays focused
  Swift parsing plus the low-RAM KEELSTONE source gate; no Xcode, app, provider,
  download, or model runtime.

### Outcome and continuing debt

- `ensure_hermes_bridge_session` now routes through a dedicated validating
  invoke handler. A non-empty requested model must pass exact session admission
  or the invoke rejects with `modelSelectionFailureMessage`; the ignored Bool
  path is removed. Bounded title synchronization remains intact.
- The focused source regression and KEELSTONE gate now pin the handler, exact
  admission guard, precise error path, and absence of the discarded result.
- Focused Swift source/test parse passes at 40,943,616 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,502,144 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-session-model-sync.log`.
- No compiled test, app, provider, keychain, download, model, Xcode, or archive
  runtime ran. Exact web invoke rejection rendering and subsequent send routing
  remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Persisted June Sessions Must Not Change Models Silently

- Turn startup currently filters and then repairs a persisted session model
  through global-default fallback logic. A removed provider credential, changed
  RAM gate, unsupported legacy ID, or changed provider preference can therefore
  mutate the session and run another lane without an explicit model change.
- Preserve any non-empty persisted session model as the exact turn identity.
  Let the selected cloud/local lane surface its current credential, consent,
  memory, download, or connectivity blocker. Unknown legacy IDs must fail with
  clear MAS June copy instead of falling through to an arbitrary local model.
- A still-valid persisted global cloud default must also keep its exact allowed
  model ID rather than adopting the provider's separately preferred model.
- Do not change the June model set, default choice for a genuinely unset model,
  local download behavior, RAM numbers, provider consent, or Apple guardrail
  fallback. Verification remains parse/source-only under the RAM constraint.

### Outcome and continuing debt

- Turn startup now preserves a non-empty persisted session model verbatim; it
  no longer filters through picker availability or invokes a fallback repair.
  The chosen lane reports its own current consent, credential, RAM, download,
  runtime, or connectivity blocker.
- Unknown persisted IDs now fail with bounded MAS June copy rather than falling
  into Apple Intelligence or whichever GGUF happens to be installed. A valid
  restored cloud default also retains its exact allowed model ID instead of
  adopting the provider's separate preferred-model setting.
- Focused Swift source/test parse passes at 40,861,696 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,436,608 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-persisted-model-identity.log`.
- No compiled test, credential/consent mutation, provider, app, model, Xcode,
  or archive runtime ran. Exact restored-session errors and reply model identity
  remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — June Stream Bounds Must Apply Before UI Emission

- Text deltas are currently appended and emitted before checking the nominal
  512 KB response cap, so one oversized event can exceed the cap. Reasoning is
  bounded only in persisted state while the original unbounded delta is still
  emitted into June's webview.
- The existing bounded helper constructs `text + delta` and repeatedly removes
  trailing characters, creating avoidable allocation and potentially quadratic
  work for a malformed large event.
- Use one UTF-8-aware bounded append operation for reply and reasoning deltas.
  Track accumulated byte counts incrementally, emit only the accepted valid-
  Unicode slice, and stop the stream at the exact cap. Apply the same path to
  Apple-FM-to-GGUF fallback streaming.
- Preserve normal streamed text, first-token measurement, response/reasoning
  limits, persistence, and AnswerPacket behavior. Verification remains low-RAM
  parse/source-only; no model, provider, app, Xcode, or archive runtime.

### Outcome and continuing debt

- Reply and reasoning streams now share a bounded Unicode-scalar append helper
  with incremental per-turn byte accounting. Only the accepted slice is emitted
  to June and retained; a delta that exhausts the remaining budget seals the
  channel instead of allowing later output to skip past truncated content.
- The primary cloud/local loop and Apple-FM-to-GGUF fallback both use the same
  cap. The old append-before-check, unbounded reasoning emission, whole-response
  recount, combined-string allocation, and repeated tail removal are gone.
- Focused Swift source/test parse passes at 40,910,848 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,731,520 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-stream-bounds.log`.
- No compiled streaming test, adversarial FFI event, provider, model, app,
  Xcode, or archive runtime ran. Exact webview memory/reply-bound evidence
  remains HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Kokoro Readiness Must Not Rehash The Package Per Render

- `KokoroVoiceGateStatus.status()` cryptographically reads every declared
  CoreML/runtime/voice file, but default-package callers invoke it from many
  SwiftUI derived properties and read-aloud checks. A ready Starter/Full package
  can therefore trigger repeated 0.5–1 GB validation work during one UI render
  or button action.
- Add a thread-safe process cache only for the default installed package and
  normal environment/defaults request. Explicit custom roots, installer staging
  roots, test fixtures, and nonstandard environments must remain uncached and
  fully validated.
- Invalidate the default cache before installed-package mutation and replace it
  with the already fully validated installed/removed status after finalization.
  Preserve every manifest, file-size, SHA-256, symlink, runtime-shape, language,
  and package-coverage gate.
- Verification stays parse/source-only. Do not hash or load real Kokoro/model
  bytes, launch audio, run Xcode, or start an app/archive under the RAM steer.

### Outcome and continuing debt

- Normal default-root/default-environment status calls now reuse a thread-safe
  process cache after one complete cryptographic validation. Custom file
  managers, roots, defaults, environments, installer sources, and staging roots
  still execute the full manifest/shape/size/SHA-256/coverage path.
- Install/remove invalidate before mutation. Successful install replaces the
  cache only with its already fully validated final status; removal leaves it
  invalidated so the next default call derives correct normal-environment copy.
- A tiny Foundation compile probe confirmed the identity and `NSLock.withLock`
  primitives at 133,660,672 bytes maximum RSS, zero swap. Focused Swift source/
  test parse passes at 42,532,864 bytes maximum RSS, zero swap. Expanded
  KEELSTONE source gate passes at 10,272,768 bytes maximum RSS, zero swap;
  retained log `/tmp/keelstone-source-gate-20260710-kokoro-readiness-cache.log`.
- No real Kokoro/model file was hashed or loaded and no audio/app/Xcode/archive
  ran. Cold first-process validation duration and audible English playback remain
  HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Source Detach Must Not Query A Loading WebView

- `MarkEditCoreEditorCoordinator.detach` currently requests live editor text
  through `evaluateJavaScript` whenever a registry entry exists, even when the
  CoreEditor page is still loading. It then immediately removes handlers, stops
  the load, and detaches the view.
- Query WebKit only when the editor has finished loading and is not currently
  navigating. Otherwise resolve the final live-text handoff from the host-owned
  binding, which is the only authoritative text available before editor readiness.
- Preserve the two-second live-text registry grace period, loaded-editor final
  query, quit/save plumbing, and normal teardown. Add a source regression and
  low-RAM gate; no app, Xcode, WebKit runtime, or archive run.

### Outcome and continuing debt

- Source dismantle now requests `getEditorText` only when CoreEditor has loaded
  and its WKWebView is not navigating. Otherwise the final registry promise is
  resolved immediately with the host binding before handlers/load are torn down.
- The loaded exact-buffer path, two-second registry grace period, pagehide
  snapshot, ordered persistence, and dirty-lease failure behavior are unchanged.
- Focused Swift source/test parse passes at 40,583,168 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,076,160 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-detach-safety.log`.
- No WebKit/editor/app/Xcode/archive runtime ran. Exact rapid lens-switch,
  appearance-toggle, quit, and saved-byte behavior remain HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — Source Timeout Failure Must Not Inject Into A Loading Page

- The terminal CoreEditor readiness timeout calls `showLoadFailure(force: true)`,
  whose current guard explicitly permits `evaluateJavaScript` while the WKWebView
  is still loading. This contradicts the appearance/lifecycle crash boundary.
- On a forced loading failure, stop the navigation and load a static, escaped
  local error document instead of evaluating page JavaScript. Mark that load
  generation terminal so its `didFinish` callback cannot restart the CoreEditor
  readiness loop. Normal non-loading failure presentation may remain in-place.
- Reset terminal-failure state on a real editor reload/detach. Preserve the
  visible diagnostic and recovery path. Verify with source parse/gates only;
  no WebKit/app/Xcode/archive runtime.

### Outcome and continuing debt

- A forced timeout while CoreEditor is loading now stops that navigation and
  loads a static escaped error document. It performs no page-world JavaScript
  evaluation against the loading document.
- The error navigation is tagged with the current load generation, and
  `didFinish` exits for that generation so it cannot start another 160-attempt
  readiness loop. A real editor load or detach clears the terminal marker.
- Focused Swift source/test parse passes at 40,648,704 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,452,992 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-loading-failure.log`.
- No WebKit hang/timeout, rapid appearance toggle, app, Xcode, or archive runtime
  ran. Exact failure/reload UI and crash absence remain HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — Retained v1 Source Fallback Must Recover In Place

- The explicit legacy v1 WebKit source fallback still handles a content-process
  termination by logging “editor blanked; reopen to recover” and leaving the
  mounted editor unusable.
- Capture its pending-or-last-applied host state and selection, reload the same
  in-process editor document, then restore those values through the existing
  pending-state flush after readiness. Do not add storage, autosave, or another
  editor engine.
- If no host state exists, log a precise recovery failure rather than writing an
  empty document. Add a source regression/gate; no WebKit/app/Xcode/archive run.

### Outcome and continuing debt

- The v1 fallback now captures `pendingState ?? lastAppliedState` plus any
  pending selection, reloads its in-process document, and restores both through
  the existing post-readiness pending-state flush.
- A termination with no retained state logs a precise safe-recovery failure and
  does not create or persist empty text. No new storage or autosave path exists.
- Focused Swift source/test parse passes at 38,895,616 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,469,376 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-legacy-source-recovery.log`.
- No legacy WebKit process termination, editor input, save, app, Xcode, or
  archive runtime ran. Exact fallback recovery/editability remains HIGH OPEN.
  Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Epdoc Snapshot Queries Must Respect Loading State

- Epdoc's installed Markdown snapshot provider guards detach but not
  `webView.isLoading`, so a save/lens/quit query can still evaluate getMarkdown
  against a page that has not finished loading or is being recovered.
- When detached or no WebView exists, retain the existing nil/fail-closed path.
  When the WebView is loading, return the controller's last full-fidelity host
  Markdown snapshot without evaluating JavaScript. Once stable, keep the JS
  getMarkdown result authoritative.
- Do not introduce projector fallback, empty substitution, or another writer.
  Verify with source regression/gate only; no WebKit/app/Xcode/archive runtime.

### Outcome and continuing debt

- The installed Epdoc snapshot provider now returns retained
  `latestMarkdownSnapshot` while its WKWebView is loading and never evaluates
  getMarkdown in that lifecycle state. Detached/missing-view queries remain nil
  and stable-page queries still use the full-fidelity JS bridge.
- No projector, JSON-to-Markdown fallback, writer, or empty replacement was
  introduced.
- Focused Swift source/test parse passes at 40,583,168 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,256,384 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-loading-snapshot.log`.
- No WebKit recovery, table/format round-trip, lens switch, app, Xcode, or
  archive runtime ran. Exact rich-fidelity behavior remains HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — Epdoc Must Invalidate Callbacks Before Stopping WebKit

- `EpdocTiptapWebView.dismantleNSView` currently calls `view.stopLoading()`
  before `coordinator.shutdown()`, delegate removal, and script-handler removal.
  A queued navigation/message callback can therefore observe a still-attached
  coordinator during teardown.
- Mark the coordinator detached and sever controller/autosave/dispatch state
  first, remove navigation/UI delegates and handlers next, then stop loading.
  Preserve leak cleanup and dismantle accounting.
- Add an ordering regression/gate; no WebKit/app/Xcode/archive runtime.

### Outcome and continuing debt

- Epdoc dismantle now calls `coordinator.shutdown()` first, then removes its
  navigation/UI delegates and script message handler, and only then stops the
  WebView load. Queued bridge/navigation callbacks therefore see detached host
  state instead of an apparently live coordinator during teardown.
- Focused Swift source/test parse passes at 40,468,480 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,305,536 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-dismantle-order.log`.
- No WebKit callback race, process termination, lens switch, app, Xcode, or
  archive runtime ran. Exact teardown safety remains HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — HTML App-Bridge Replies Must Be Navigation-Safe

- Owner wording remains: stop massive tests, continue autonomously, ship only
  MAS/June while preserving the selected local models and Kokoro voices.
- `HTMLWorkspacePreviewView.Coordinator.dispatchAppBridgeResponse` currently
  guards a missing/detached WebView but can still evaluate its response script
  after a new preview navigation has started. A queued message from the prior
  document can therefore inject JavaScript into a loading/replaced page.
- Add a focused source regression first, then require both coordinator and
  WebView loading state to be stable before evaluating the response. Dropping a
  stale prior-document reply during navigation is correct; do not queue it into
  the replacement document.
- Preserve the MAS-safe app-bridge policy and all June/local-model/Kokoro
  behavior. Use parse/source gates only; no WebKit/app/Xcode/archive runtime.

### Outcome and continuing debt

- HTML Workspace now drops an app-bridge response if either the coordinator or
  WebView is loading, before constructing/evaluating the response script. A
  stale request from the replaced document is never replayed into the new one.
- Focused Swift source/test parse passes at 39,174,144 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,420,224 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-html-app-bridge-navigation.log`.
- No HTML Workspace navigation, bridge message, appearance toggle, app, Xcode,
  or archive runtime ran. Exact lifecycle behavior remains HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — Stale HTML Data Patches Cannot Replace Newer Renders

- `patchDataJSON` records the requested shell/data before its asynchronous
  JavaScript completion, but the completion currently checks only detach. If a
  newer patch or full preview render begins first, the older callback can call
  `startRender` with its stale fallback HTML and overwrite the newer document.
- Add a regression first. At completion, require a stable, non-loading WebView
  and exact current shell/data/HTML identities before either fallback reload or
  live-DOM refresh. A superseded patch completion must become a no-op.
- Preserve data-only patching, full fallback rendering, DOM refresh, MAS
  sandbox policy, June/local models, and voice behavior. Use parse/source gates
  only; no WebKit/app/Xcode/archive runtime.

### Outcome and continuing debt

- A data-only patch completion now requires a stable WebView plus exact current
  shell, data, and fallback-HTML identities before it may reload fallback HTML
  or refresh the live DOM. A completion superseded by any newer patch/render is
  discarded.
- Focused Swift source/test parse passes at 39,272,448 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,289,152 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-html-data-patch-revision.log`.
- No delayed JavaScript completion, rapid data feed, preview reload, app,
  Xcode, or archive runtime ran. Exact ordering remains HIGH OPEN. Continue
  Prompt 2.

## Continuation Checkpoint 2026-07-10 — HTML Navigation Callbacks Must Match The Active Load

- HTML preview tracks a boolean loading state but not the `WKNavigation` it
  started. A delayed fail/finish callback from a cancelled prior load can clear
  the boolean for a newer load and run pending render/probe/DOM work against the
  wrong document.
- Add a regression first. Retain the navigation token returned by
  `loadHTMLString`; every finish/fail callback must match that exact object
  before it mutates state. Clear the token on accepted completion and detach.
- Preserve latest-render coalescing and the existing load/failure behavior.
  Use parse/source gates only; no WebKit/app/Xcode/archive runtime.

### Outcome and continuing debt

- Each HTML preview load now retains its returned `WKNavigation`. Finish and
  failure callbacks must match that exact token before clearing loading state,
  starting a pending render, or running probes. Detach clears the token.
- Focused Swift source/test parse passes at 39,288,832 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,371,072 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-html-navigation-identity.log`.
- No cancelled/reordered WebKit navigation, app, Xcode, or archive runtime ran;
  the new identity expressions are parsed but not typechecked in this
  low-memory slice. Exact behavior remains HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Bounded Local June Streams Must Never Silently Drop Tokens

- Owner requires the selected GGUF models connected to June and warned that
  GPT consumed roughly 25 GB RAM. Keep every local stream buffer bounded.
- The llama engine, GGUF adapter, and June text-event wrapper all use
  `.bufferingNewest(256)` but ignore `Continuation.yield` results. Under
  backpressure, each can silently discard a token/event and still finish as a
  successful but corrupted answer.
- Add source regressions first. Every layer must inspect `.dropped`, cancel or
  end upstream work, and finish with a precise visible error. `.terminated`
  must stop producing. Do not replace bounds with unbounded buffering and do
  not load any model.
- Preserve Qwen3 4B admission, 8B/7B visible RAM gates, cloud lanes, Kokoro,
  and MAS-only in-process execution. Use parse/source gates only.

### Outcome and continuing debt

- The llama engine, GGUF adapter, and June local event wrapper still use their
  256-event bounded buffers. Each now inspects `yield`: `.dropped` finishes
  with an explicit backpressure error, while `.terminated` stops production.
  The adapter cancels llama generation when its downstream cannot keep up.
- Qwen3 4B remains admitted; Qwen3 8B and Qwen2.5 7B remain visible and
  RAM-gated. No catalog, provider, Kokoro, or route was removed.
- Focused Swift source/test parse passes at 40,992,768 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,731,520 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-local-stream-backpressure-final.log`.
- No focused typecheck, model load, generation, induced slow consumer, app,
  Xcode, or archive runtime ran. Exact visible error/cancellation behavior
  remains HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Bounded Cloud June Events Must Fail Closed Too

- OpenAI/Anthropic turns enter June through the active in-process
  `GooseMASAgentCoreRunner`. Its `.bufferingNewest(256)` event stream also
  ignores `yield`, so text, thinking, tool, permission, or completion events can
  be silently lost while the agent continues running.
- Add a source regression first. The active MAS runner delegate must receive a
  Bool from bounded emission; a drop must finish with a precise error, mark the
  delegate stream terminated, and cancel the scoped `agent_core` session.
  Terminated continuations stop accepting callbacks.
- Do not change the parked ACP runner, provider list, credentials, model list,
  tool policy, buffer size, local GGUF routes, or Kokoro. Use parse/source gates
  only; no provider request, app, Xcode, or archive runtime.

### Outcome and continuing debt

- The active MAS `agent_core` delegate now emits through a Bool-returning
  bounded closure. A dropped event finishes with a visible cloud-output
  backpressure error, schedules cancellation for that exact session, marks the
  delegate terminated, clears pending permissions, and rejects later callbacks.
- OpenAI/Anthropic admission, credentials/consent, tools, and the 256-event
  bound are unchanged. The parked ACP runner was not modified.
- Focused Swift source/test parse passes at 41,795,584 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,502,144 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-cloud-stream-backpressure.log`.
- No focused typecheck, provider request, induced slow consumer, agent session,
  app, Xcode, or archive runtime ran. Exact cancellation and visible error
  remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — June Bridge Must Recover From Web Content Loss

- The process-lifetime June WebView currently has no
  `webViewWebContentProcessDidTerminate` recovery. Its `runJS` closure also
  evaluates whenever the WKWebView object exists, including while a page is
  loading or after its renderer died. This can leave June blank or lose output
  into an unstable document.
- Add source regressions first. The holder must own page readiness and the exact
  active `WKNavigation`; bridge JavaScript requires ready + non-loading state.
  Renderer termination must mark not-ready, cancel all in-flight June turns and
  approvals, and reload only the bundled `june://` entry. Only the matching
  navigation completion may restore readiness.
- Native session persistence remains authoritative, so recovery may discard
  stale web frames while retaining the cancelled/error turn for session reload.
  No canned reply, external server, subprocess, route fallback, model removal,
  or provider request. Use parse/source gates only.

### Outcome and continuing debt

- `JuneAgentSurfaceHolder` now owns `pageReady` and the exact active
  `WKNavigation`. Native JavaScript runs only for a ready, non-loading page;
  stale finish/failure callbacks cannot restore readiness.
- Web-content termination marks June not-ready, cancels every in-flight turn
  and pending approval through the native gateway, and reloads only the bundled
  `june://` entry. Native session persistence remains the recovery truth.
- Focused Swift source/test parse passes at 40,960,000 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,485,760 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-webcontent-recovery.log`.
- No focused typecheck, induced renderer termination, local/cloud turn, visible
  session reload, app, Xcode, or archive runtime ran. Exact recovery and output
  visibility remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — June WebKit IPC Must Be Bounded And Serialized

- Owner reported GPT using roughly 25 GB RAM and asked to stop massive tests.
  The model and event streams are now bounded, but every accepted gateway delta
  still invokes asynchronous `WKWebView.evaluateJavaScript` immediately. That
  creates an unbounded WebKit IPC/completion backlog outside the stream buffers.
- Add a source regression first. The June holder must queue native JavaScript
  behind one in-flight evaluation, batch ordered scripts, and cap both queued
  script count and UTF-8 bytes. Completion must be generation-guarded.
- Queue overflow or controlled-script evaluation failure must clear the queue,
  cancel native turns/approvals, mark the page unready, and reload the bundled
  June entry. Renderer recovery shares the same queue reset. Preserve order,
  page readiness, session persistence, local/cloud model sets, and Kokoro.
- Use parse/source gates only; no WebKit/app/model/provider/Xcode/archive run.

### Outcome and continuing debt

- Native-to-June scripts now enter one serialized queue, batch in original
  order up to 32 at a time, and permit at most 256 queued scripts / 2 MiB. One
  `evaluateJavaScript` is in flight; its completion is dispatch-generation
  guarded.
- Count/byte overflow or controlled-script evaluation failure resets the queue,
  cancels turns/approvals, marks June unready, and reloads the exact bundled
  surface. Renderer recovery uses the same reset, so stale completions cannot
  restart the old queue.
- Focused Swift source/test parse passes at 41,254,912 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,207,232 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-webkit-ipc-bounds.log`.
- No focused typecheck, WebKit IPC stress, model/provider turn, induced
  overflow, recovered-session UI, app, Xcode, or archive runtime ran. Exact
  throughput/error behavior remains HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Any New June Document Must Invalidate Bridge Readiness

- Active navigation identity is registered for host initial/recovery loads, but
  there is no `didStartProvisionalNavigation` path. A full same-origin
  navigation initiated by the June page can therefore leave `pageReady=true`
  while its document is being replaced.
- Add a regression first. Every main-frame navigation start must register its
  exact token, mark the page unready, reset the bounded JavaScript queue, and—if
  it supersedes a ready document—cancel turns/approvals before replacement.
  A start for the already registered host load must remain idempotent.
- Preserve SPA same-document routing, origin policy, session persistence,
  local/cloud models, and Kokoro. Parse/source gates only.

### Outcome and continuing debt

- Every June main-frame provisional navigation now enters the holder. An
  already registered host load is idempotent; a replacement document marks the
  page unready, installs its exact token, resets queued/in-flight JavaScript,
  and cancels turns/approvals when replacing a ready page.
- Focused Swift source/test parse passes at 41,254,912 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,289,152 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-navigation-start.log`.
- No focused typecheck, self-navigation, active turn, app, Xcode, or archive
  runtime ran. Exact same-origin replacement behavior remains HIGH OPEN.
  Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Vault Bookmark Timeout Must Actually Return

- `resolveVaultBookmarkWithTimeout` races synchronous Foundation bookmark
  resolution inside `withThrowingTaskGroup`. When timeout wins, structured
  concurrency still waits for the cancelled synchronous resolver child before
  leaving the group, so a blocked resolver can hang startup past five seconds.
- Add a source regression first. Replace the task group with a lock-protected
  one-shot checked continuation and two unstructured tasks. The first result
  resumes exactly once; timeout returns without waiting for a late synchronous
  resolution, whose later result is ignored safely.
- Preserve bookmark bytes, security-scope requirements, retryable persisted
  selection, current recovery UI, and exact five-second policy. Do not open or
  mutate the owner's vault. Parse/source gates only.

### Outcome and continuing debt

- Bookmark resolution and the five-second timer now race through a
  lock-protected one-shot checked continuation. Timeout no longer enters a
  structured scope that waits for the synchronous resolver to stop; any late
  result observes a cleared continuation and becomes a no-op.
- The persisted bookmark remains intact on timeout and the existing visible
  retry/reattach recovery path is unchanged.
- Focused Swift source/test parse passes at 44,204,032 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,764,288 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-vault-bookmark-real-timeout.log`.
- No focused typecheck, blocked-resolver injection, security-scope resolution,
  owner vault read/write, app, Xcode, or archive runtime ran. Exact timeout and
  restore UI remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Startup Preflight Must Use The Bookmark Deadline

- Production still calls synchronous `startupBookmarkValidation()` in both
  startup integrity and automatic restore before `restoreVaultFromBookmark`.
  That preflight resolves the same bookmark without a timeout, so a block there
  prevents the new async restore deadline from ever running.
- Add a source regression first. Introduce an async timeout-backed startup
  validator using the same one-shot resolver and security-scope/readability
  policy. Both production bootstrap call sites must await it. Preserve the
  synchronous validator for focused existing tests only.
- Timeout remains fail-closed and retryable: report the bookmark as existing
  but not ready, never delete bytes or clear local data. No owner-vault access,
  app, Xcode, or archive runtime.

### Outcome and continuing debt

- Startup integrity now awaits `startupBookmarkValidationWithTimeout()`, and
  automatic restore reuses the validation stored in that integrity report.
  Production no longer enters the synchronous preflight or resolves a blocked
  bookmark twice.
- Timeout reports an existing but not-ready bookmark through the existing
  fail-closed/retryable policy; it does not delete the bookmark or local data.
- Focused Swift source/test parse with the repo-required bare-regex flag passes
  at 46,333,952 bytes maximum RSS, zero swap. Expanded KEELSTONE source gate
  passes at 10,240,000 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-vault-preflight-timeout-final.log`.
- No focused typecheck, blocked preflight, security scope, owner-vault access,
  app, Xcode, or archive runtime ran. Exact startup timing and restore UI remain
  HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Successful Vault Preflight Resolution Must Be Reused

- The bootstrap now performs one bounded validation, but
  `restoreVaultFromBookmark` still resolves the same bookmark bytes again. A
  valid launch therefore pays duplicate Foundation/security-bookmark work and a
  pathological resolver can consume another deadline.
- Cache only the successful preflight `ResolvedVaultBookmark` in memory beside
  its exact bookmark `Data`. Restore consumes it once only when current saved
  bytes are identical; otherwise it uses the bounded resolver. Clear the cache
  when startup restore is cleared.
- Do not persist resolved URLs, bypass scope/readability/stale checks, or mutate
  bookmark bytes. Parse/source gates only; no owner-vault or app runtime.

### Outcome and continuing debt

- Successful bounded preflight now retains one in-memory resolved bookmark with
  its exact source `Data`. Restore consumes it once only when saved bytes still
  match; mismatches and missing cache use the bounded resolver. Clearing pending
  startup restore also clears the transient cache.
- Security-scope acquisition, readability, stale refresh, suspicious-folder
  confirmation, and persisted bookmark bytes remain unchanged.
- Focused Swift source/test parse with bare-regex enabled passes at 46,186,496
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate passes at
  10,567,680 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-vault-preflight-reuse.log`.
- No focused typecheck, successful/timeout bookmark resolution, owner-vault
  access, app, Xcode, or archive runtime ran. Exact one-resolution startup and
  restore remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Kokoro Cancellation Must Stop CoreML Work

- `speak()` stores/cancels an outer playback task, but starts synthesis with an
  unstructured `Task.detached` and awaits only its value. Cancellation does not
  automatically reach that detached task, so rapid preview/read-aloud actions
  can leave old CoreML renders running and start new ones concurrently.
- Add regressions first. Keep a render task handle and forward outer
  cancellation with `withTaskCancellationHandler`. Serialize
  `renderRawText` process-wide and call `Task.checkCancellation()` before
  runtime loading, between every synthesized chunk, and after synthesis.
- Preserve installed English voice selection, Kokoro-only MAS policy, audio
  playback, package cache, model files, and all voice surfaces. No CoreML/audio,
  app, Xcode, or archive runtime; parse/source gates only.

### Outcome and continuing debt

- `speak()` now retains the detached render handle and forwards outer playback
  cancellation through `withTaskCancellationHandler`. `renderRawText` is
  process-wide single-flight and checks cancellation before loading, before and
  after every chunk, and before returning joined audio.
- Rapid stop/preview/read-aloud can no longer start overlapping Kokoro CoreML
  synthesis. English-only voice selection and starter fallback are unchanged.
- Focused Swift source/test parse passes at 42,811,392 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,436,608 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-kokoro-render-cancellation.log`.
- No focused typecheck, CoreML package/model load, audio, rapid preview, app,
  Xcode, or archive runtime ran. Exact cancellation latency, memory reclamation,
  and audible English remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Kokoro Failures Must Explain The Actual Blocker

- `failKokoroPlayback` logs only sanitized domain/code and always shows the same
  generic “check Settings” toast. Package, runtime asset, unsupported input,
  synthesis, and audio playback failures are therefore indistinguishable to the
  owner.
- Add a source regression first. Prefer the curated `LocalizedError` reason
  already produced by Kokoro loader/synthesizer errors, bound and normalize it
  through `VoiceCapturePresentationBounds`; otherwise show safe domain/code.
- Do not expose raw paths, model bytes, prompts, or arbitrary exception text.
  Preserve English voices, cancellation, and playback. Source checks only.

### Outcome and continuing debt

- Kokoro failure toasts now prefer only curated synthesizer/loader
  `LocalizedError` descriptions, normalize/bound them through the shared voice
  presentation policy, and otherwise show sanitized domain/code. Raw arbitrary
  error text and paths are not surfaced.
- Focused Swift source/test parse passes at 42,778,624 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 10,076,160 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-kokoro-visible-errors.log`.
- No focused typecheck, induced loader/synthesis/audio failure, toast UI, CoreML,
  app, Xcode, or archive runtime ran. Exact visible reason and audible English
  remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Newly Mounted Editors Must Reclaim Clean Leases

- `NoteDetailWorkspaceView.onAppear` opens a session but calls
  `acquireCleanLeaseHandoffIfAvailable()` only for graph-embedded presentation.
  In a normal note window/tab, an older clean mounted session can therefore keep
  the write lease and force the newly opened Source/Prose/Epdoc surface into
  read-only mode with no effective handoff path.
- Update the existing regression first, then attempt clean handoff after every
  session open. The registry already refuses handoff from a dirty owner, so
  unsaved edits remain protected; only clean ownership follows the newly
  mounted surface.
- Preserve one-writer semantics, lifecycle-generation close safety, all editor
  engines, and save paths. Parse/source gates only; no app/Xcode/archive run.

### Outcome and continuing debt

- Every newly mounted note session now attempts the registry's existing clean
  handoff immediately after `open()`, not only graph-embedded sessions. A clean
  older owner transfers and all registered sessions refresh; a dirty owner is
  still protected and refuses transfer.
- Source, Prose, and Epdoc continue to share the same one-writer lease and save
  paths; no editor-specific bypass was added.
- Focused Swift source/test parse with bare-regex enabled passes at 44,253,184
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate passes at
  10,125,312 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-editor-clean-lease-handoff.log`.
- No focused typecheck, two-window handoff, dirty-owner conflict, editing,
  app, Xcode, or archive runtime ran. Exact editability and save proof remain
  HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Prose Telemetry Must Not Spawn A Task Per Input Event

- `ProseTextView2` creates a detached task for every edit and cursor move to
  call the friction actor, plus a MainActor task for activity tracking even
  though `didChangeText` already runs on the main actor. Rapid typing can create
  an avoidable task/actor-hop backlog.
- Add a source regression first. Queue the complete timestamped telemetry
  events in the text view, flush them as one batch after a 50 ms window, and add
  an actor batch method that reads the live enable flag once then processes each
  event with existing semantics. Keep activity tracking direct.
- Preserve every telemetry event, ordering, session/window flush behavior,
  friction setting, editor parsing, and saves. Parse/source gates only.

### Outcome and continuing debt

- Prose now retains timestamped edit/cursor telemetry in order and crosses to
  `FrictionMonitorService` once per 50 ms batch. Activity tracking stays on the
  already-main-actor edit path, and teardown cancels an outstanding flush.
- The actor reads the live friction-enabled setting once for each batch, then
  processes every event through the existing note/session/window semantics.
- Focused Swift source/test parse passes at 10,158,608 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,703,672 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-friction-batching.log`.
- No focused typecheck, live typing/cursor stress, telemetry-store inspection,
  app, Xcode, or archive runtime ran. Exact typing latency and telemetry
  preservation remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Initial Hologram Commit Must Leave MainActor

- Hologram mini/full presentation and `MetalGraphNSView.viewDidMoveToWindow`
  still call `commitGraphData()` directly. That method snapshots the complete
  store and builds visible node/edge payloads synchronously before the first
  graph frame, despite an existing utility-priority payload builder used by the
  render-loop bootstrap.
- Extend the existing source regression first. Expose one idempotent initial
  scheduling seam on `MetalGraphNSView`, route all three presentation call
  sites through it, and let the existing version guard coalesce duplicates.
- Preserve exact filtering, node/edge payloads, graph mode, entrance behavior,
  camera behavior, physics, and renderer commit semantics. Parse/source gates
  only; no large graph, Metal runtime, Xcode, or archive run.

### Outcome and continuing debt

- Mini hologram setup, full hologram setup, and window attachment now use one
  version-coalesced initial commit seam. Store/filter snapshots are captured,
  while complete visible node/edge payload construction runs in the existing
  utility task rather than synchronously in the presentation callback.
- Page-mode anchor setup still precedes the commit, and its close camera action
  is carried into commit completion instead of running against an empty engine.
  Filtering, entrance, force, theme, physics, and renderer application remain
  on the existing commit path.
- Focused Swift source/test parse passes at 10,289,704 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,752,824 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-hologram-initial-commit-final.log`.
- No large-vault graph, Metal frame, page camera, focused typecheck, app, Xcode,
  or archive runtime ran. Exact startup duration and graph-to-editor latency
  remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Source Snapshot Debounce Must Not Retain Every Revision

- `CodeEditorView.scheduleTextSnapshotPublish(_:)` cancels and recreates a task
  on every accepted edit, capturing that complete String revision for 140 ms.
  On large documents, canceled tasks and retained copy-on-write buffers can
  amplify typing memory/copy pressure before the executor drains them.
- Update source regressions first. Keep one retained worker, advance a small
  revision counter per edit, wait until the revision remains stable for the
  existing 140 ms window, then publish the current `text` once. Teardown must
  still cancel the worker and synchronously publish the exact visible buffer.
- Preserve dirty-before-debounce, the separate 900 ms durability debounce,
  live WebKit query ownership, lens switching, and final save ordering. Parse/
  source gates only; no large editor, Xcode, app, or archive run.

### Outcome and continuing debt

- Source/Code live snapshots now increment a scalar revision and retain at most
  one quiet-window worker. The worker repeats the existing 140 ms wait until
  stable, then reads the current `text`; it captures no per-keystroke String.
- Teardown invalidates/cancels that worker and still publishes the exact current
  text before the separate durability debouncer flush/detach sequence.
- Focused Swift source/test parse passes at 10,240,528 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,703,672 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-snapshot-single-worker.log`.
- No large-document typing, memory allocation profile, lens switch, focused
  typecheck, app, Xcode, or archive runtime ran. Exact typing latency and final
  Source save remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — MAS Must Not Say All Local Models Were Removed

- The active MAS build now links the selected GGUF runtime in-process, but
  startup still logs `App-local model stack removed`, June's empty-success
  error directs the owner only to cloud/Apple choices, and the retired MLX enum
  labels itself generically as `Local Models Removed`. Together these stale
  strings make the admitted GGUF models look disconnected or disabled.
- Add source regressions first. Report the exact MAS June GGUF runtime linkage,
  direct empty-reply recovery toward June Models or an installed GGUF, and name
  only the retired MLX selection as unavailable.
- Preserve the three-model GGUF catalog, RAM gates, cloud consent, Kokoro voice
  models, and all routing. Parse/source gates only; no model load/provider call.

### Outcome and continuing debt

- MAS startup now reports `MAS June model stack` and compile-time in-process
  GGUF linkage instead of saying every app-local model was removed. The log
  does not instantiate the GGUF backend, load bytes, or inspect Keychain.
- An empty successful June turn now directs recovery to Settings > June Models,
  Apple Intelligence, or an installed local GGUF. The legacy enum now names
  only retired MLX state as unavailable, not all local models.
- The three Qwen GGUF rows, 16 GB RAM admission, OpenAI/Anthropic June routes,
  and Kokoro voice models are unchanged.
- Focused Swift source/test parse with bare-regex enabled passes at 10,289,680
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate passes at
  2,752,824 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-local-truth-copy-final.log`.
- No GGUF/backend/model allocation, download, provider/Keychain access, app,
  focused typecheck, Xcode, or archive runtime ran. Exact June local/cloud turn
  output remains HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Prose Debouncers Must Not Capture Every Full Note

- `textDidChange` currently copies `tv.string` and captures it into a newly
  canceled/recreated 300 ms binding task and one-second data-detection task on
  every keystroke. Optional contextual recall also retains the same full-note
  snapshot even though it later prefers a bounded live cursor window.
- Add source regressions first. Give binding and data detection one revision-
  driven worker apiece; read the current TextKit buffer only after the quiet
  window. Let contextual recall read only its live bounded window after delay.
- Preserve exact binding/save flushes, external-sync exclusion while dirty,
  data-detection styling, contextual recall semantics, IME guards, and teardown.
  Parse/source gates only; no large note, TextKit UI, Xcode, or archive run.

### Outcome and continuing debt

- Prose binding sync and data detection now each use one generation-safe,
  revision-driven worker. They wait for the existing quiet window and only then
  read current TextKit content; no task captures every keystroke's full note.
- Edits arriving during data detection advance the revision and force the same
  worker to wait/detect again before styling. Page switches, flushes, and
  teardown invalidate old workers without letting their deferred cleanup clear
  a newer worker.
- Optional contextual recall now reads only its existing bounded live cursor
  window after the 200 ms delay and retains no full-note fallback snapshot.
- Focused Swift source/test parse passes at 10,240,504 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,736,440 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-single-workers.log`.
- No large-note typing/allocation profile, data-detection UI, contextual recall,
  TextKit lifecycle, focused typecheck, app, Xcode, or archive runtime ran.
  Exact Prose latency and fidelity remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Source Live Preview Must Retain One Worker

- When Code/Source live preview is visible, every edit cancels/recreates a 260
  ms task capturing the complete content String. Large-file typing can retain
  many canceled copy-on-write revisions until those tasks drain.
- Add source regressions first. Track a scalar preview revision, keep one
  generation-safe worker, and read current `text` only after the existing quiet
  window. Preview enable still seeds immediately; disable/teardown cancels.
- Preserve HTML/CSS/JS/JSON preview construction, save/snapshot debouncers,
  editor text, and selection. Parse/source gates only; no WebKit preview run.

### Outcome and continuing debt

- Visible Code/Source live preview now increments a scalar revision and keeps
  one generation-safe worker through the existing 260 ms quiet window. It reads
  current `text` only when stable and captures no per-keystroke full document.
- Preview enable still seeds immediately. Disable and editor teardown invalidate
  the worker without letting stale deferred cleanup clear a replacement task.
- Focused Swift source/test parse passes at 10,224,168 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,752,824 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-live-preview-worker.log`.
- No large-file typing/allocation profile, HTML/CSS/JS/JSON preview WebKit run,
  focused typecheck, app, Xcode, or archive ran. Exact Source preview latency
  and fidelity remain HIGH OPEN. Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Source Outline Must Retain One Worker

- With the outline navigator visible, each edit currently computes full String
  length on the event path, then cancels/recreates a task capturing the complete
  content until its adaptive delay expires.
- Add source regressions first. Use a scalar revision and one generation-safe
  worker, determine the adaptive delay from current state inside that worker,
  and parse current text only after quiet. Explicit outline reveal stays
  immediate; hide/teardown cancels.
- Preserve the 256 KiB parse cap, cache semantics, language selection, outline
  results, and navigation. Parse/source gates only; no large-file UI run.

### Outcome and continuing debt

- The visible Source outline now advances a scalar revision and retains one
  generation-safe worker. Adaptive length calculation and full text capture
  occur inside the worker, after input leaves the event path, and parsing waits
  until the revision remains quiet.
- Explicit reveal/external document replacement still refreshes immediately.
  Hide and teardown invalidate safely; the cache, 256 KiB cap, language, and
  outline results are unchanged.
- Focused Swift source/test parse passes at 10,224,144 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,752,824 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-outline-worker.log`.
- No large-file outline parse, navigation, typing/allocation profile, focused
  typecheck, app, Xcode, or archive ran. Exact Source latency remains HIGH OPEN.
  Continue Prompt 2.

## Continuation Checkpoint 2026-07-10 — Epdoc Autosave Must Retain One Debounce Worker

- `scheduleMarkdownSave` already owns authoritative `latestMarkdown`, but still
  cancels/recreates a two-second task capturing the complete Markdown revision
  for every editor change. Large Epdocs can retain canceled full snapshots.
- Extend source regressions first. Keep one generation-safe worker that watches
  the existing debounce generation, reads `latestMarkdown` only after quiet,
  and loops if a new edit arrives during an in-flight serialized write.
- Preserve minimal writeback application, exact latest snapshot, two-second
  window, serialized durability tail, dirty state, flush/page-switch semantics,
  and table/format fidelity. Parse/source gates only; no Epdoc runtime.

### Outcome and continuing debt

- Epdoc autosave now retains one generation-safe worker. Each editor change
  updates authoritative `latestMarkdown` and a scalar debounce generation; the
  worker waits for two seconds of quiet, then reads that current snapshot.
- An edit arriving during a serialized write makes the same worker loop through
  another quiet window. Flush/page switch explicitly invalidate it, while the
  existing write tail still preserves durability order and dirty revision truth.
- Minimal writeback validation/application, exact snapshot fallback, and
  table/format source remain unchanged.
- Focused Swift source/test parse passes at 10,404,392 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,703,672 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-autosave-worker-final.log`.
- No Epdoc editing, large Markdown allocation profile, save failure, surface
  switch, focused typecheck, app, Xcode, or archive ran. Exact autosave and rich
  fidelity remain HIGH OPEN. Continue Prompt 2.

## Owner Steer 2026-07-10 — Exhaustive Coding Must Not Stall The Master Plan

### Verbatim owner wording

> where are u at now rememebr i only rmemebr propt 1 and proot 2 keelstone and a little but of lumenlens of whcih ther are luke 6 or so other feature sets with theur ow research so idk if my way of exhauative coding is causing these isssues and stalling please hel pme out here

### Interpreted intent

- Give a concrete map of `EPISTEMOS-MAS-PROGRAM-DIRECTOR-2026-07-08`,
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`,
  `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`, and the later
  capability key instead of making the owner infer progress from implementation
  details.
- Prevent recursive hardening from turning into unbounded source churn. The
  loop must converge on KEELSTONE's evidence bar, then advance in dependency
  order; exhaustive review is a quality mechanism, not permission to remain in
  Keelstone forever.
- Distinguish real blockers from optional hardening. Stop opening new micro-
  optimizations after the current worker-deduplication batch; close or defer
  them, reconcile verification debt, and prioritize the smallest controlled MAS
  runtime proof that does not recreate the reported 25 GB memory event.

### Hard constraints and non-goals

- MAS-only; June is the sole agent/chat product. Keep the selected GGUF and
  OpenAI/Anthropic June lanes plus Kokoro voice models.
- Do not run broad Xcode suites, parallel builds, model loads, archives, or
  other high-RAM evidence while the owner has asked to avoid massive tests.
- Do not declare KEELSTONE complete from source gates. Do not advance LumenLens
  or later prompts until Keelstone's real blocker matrix is honestly closed.
- Do not expand into unrelated feature work under the name of hardening.

### Acceptance checks and next action

- Inventory the authoritative prompt/feature plan directory and report the
  actual dependency order/status.
- Finish or cleanly unwind the in-progress shared quiet-worker extraction so
  the worktree is not left half-migrated.
- Set a convergence boundary: source freeze after this batch, lightweight
  compile/source reconciliation, then one explicitly resource-capped Keelstone
  evidence plan focused on vault, Epdoc, Source/Prose, graph, June, and Kokoro.

## Owner Steer 2026-07-10 — KEELSTONE Remaining Issues And Exit Order

### Verbatim owner wording

> but ofc the main issues that i flagged were issues iwth the vouce model, the perforacen of the editting surfaces and the editting itself data loss on epdoc, formatting loss. on epdoc etc. i thk u fixed it. hafe not noticed issues but i have ot test ed out hte swictcghinfr to and from epdoc to otehr editor surfaces. and i still see the haniging when. edittig on the graph surfaces so weh i edit code editor epdoc adn any of hte other surfaces on embeddedgraph and the hologram graph it hangs and takes. a long time to load them so yea and then foc the june angent was not working on local models and i have not tried the cloud models but not sure if they work so those were the ian issues and beyind that i wated to contiue the restof the large master plan ipolementations from prompt 2

### Interpreted intent

- Treat graph-embedded and hologram editor load/typing hangs as the first
  currently reproduced KEELSTONE failure. It affects Code/Source, Epdoc, Prose,
  and other editor surfaces and is not closed by prior source guards.
- June local models are still owner-observed nonworking. Cloud June is untested,
  not presumed working. Both require exact selected-model output or precise
  visible error evidence.
- Epdoc data-loss/formatting work may be improved, but switching among Epdoc and
  other editor surfaces remains untested and therefore open.
- Kokoro/voice remains an original blocker until audible English or a precise
  visible blocker is proven.
- After these owner-visible KEELSTONE checks close, continue the rest of the
  active MAS master plans rather than extending Keelstone indefinitely.

### Constraints, acceptance, and next action

- Keep the source-freeze rule except for a reproduced exit-check failure. The
  graph hang and June local failure qualify; unrelated micro-optimizations do
  not.
- Diagnose graph route ownership first: prove that canvas renderer, physics,
  inspectors, cache builders, graph observers, and hidden editor instances
  quiesce while a graph-native editor is active.
- Preserve all note formats and the single canonical editor/save paths. Do not
  create graph-specific editor copies or alternate persistence.
- Continue source-only/low-RAM checks until a controlled runtime evidence pass;
  no broad suites, parallel builds, or model loads.

### First focused outcome and continuing debt

- Embedded graph editor routes previously froze physics but left
  `NodeInspectorState` selection/profile/summary tasks alive. Hologram routes
  already cleared both graph and inspector selection. Embedded routes now call
  the same quiescence behavior before the editor owns the surface.
- This stops background body reads, profile derivation, and possible Apple/
  configured-model summary work from competing with embedded Epdoc, Source,
  Prose, or Code load/typing.
- Focused Swift source/test parse passes at 10,256,960 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate passes at 2,769,208 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-embedded-inspector-quiesce-final.log`.
- No embedded/hologram editor runtime, typing latency measurement, inspector
  cancellation trace, focused typecheck, app, Xcode, or archive ran. The owner-
  observed graph hang remains HIGH OPEN until exact runtime proof.

## Owner Correction 2026-07-10 — July 8 MAS Canon Is Authoritative

### Canonical execution keys supplied by the owner

- `EPISTEMOS-MAS-PROGRAM-DIRECTOR-2026-07-08`
- `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`
- `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`
- `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`
- `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`

### Interpreted intent and authority

- The daily execution authority is
  `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/{00_READ_FIRST.md,02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md,03_MINIMAL_PROMPT_PACK.md}`.
- Older `docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md` and
  `PROMPT_PLAN_*.md` files are provenance/spec appendices only. They cannot name
  the active prompt order or revive parked lanes.
- Current work remains `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. Do
  not restart it and do not jump to LumenLens. After its exact evidence bar,
  advance to `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`, then
  `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`, then
  `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`.

### Required correction and next action

- Rewrite `docs/prompts/MAS_EXECUTION_STATUS_2026_07_10.md` around the five
  canonical execution keys. Any older numbered-plan list must be labeled
  provenance-only.
- Remove the newly added link from the older master index so it is not elevated
  as current authority; add an explicit supersession banner instead.
- Continue the reproduced graph editor hang and remaining KEELSTONE exit
  evidence after documentation authority is corrected.

## Owner Correction 2026-07-10 — Canonical IDs Replace Numeric Shorthand

### Exact owner rule

> From now on, do not use “Prompt N” or “Plan N” alone in dashboards, ledgers, progress updates, phase transitions, or autonomous goal reasoning.

Execution-state keys are exclusively:

- `EPISTEMOS-MAS-PROGRAM-DIRECTOR-2026-07-08`
- `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` (**current**)
- `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`
- `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`
- `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`

### Applied interpretation

- Numeric shorthand is retired from current dashboards, new ledger entries,
  progress messages, transition logic, and autonomous reasoning. If the July 8
  pack must be quoted, its number must be adjacent to the complete canonical ID.
- Older numbered files remain subordinate provenance/spec appendices only and
  cannot change current key, dependency order, MAS boundary, or parked status.
- Continue `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`; transition only
  after exact evidence to `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`,
  then `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`, then
  `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`.

## KEELSTONE Outcome 2026-07-10 — Hologram Editor Routes Stop Pinned-Panel Wakeups

- The hologram route already paused Metal and physics for an editor, but its
  pinned-inspector timer continued waking the main run loop at 30 Hz. Even an
  early-returning callback still competed with editor input on the main thread.
- Leaving canvas now stops that timer and clears its force-alive state. Canvas
  re-entry restarts it, while every other start site refuses a non-canvas route.
- Focused Swift source/test parsing passes at 45,580,288 bytes maximum RSS and
  11,043,344 bytes peak footprint, with zero swap. The expanded KEELSTONE source
  gate passes at 9,977,856 bytes maximum RSS and 2,720,056 bytes peak footprint,
  with zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-hologram-editor-timer.log`.
- No app, Metal, editor typing, model, Xcode build/test, or archive ran. The
  owner-observed graph hang remains HIGH OPEN until controlled runtime evidence.

## KEELSTONE Outcome 2026-07-10 — Retained MAS Archive Proves Why GGUF Was Disabled

- The sandbox contains the exact-size Qwen3 4B file, but it predates the
  current verification-receipt contract and has no receipt. No model bytes were
  opened or hashed during this diagnosis.
- The three immutable catalog filenames and SHA-256 pins match their hosted
  revision pages. The catalog itself is not the failure.
- The newest retained MAS archive contains the visible Qwen row but neither
  embeds `llama.framework` nor links it from the app executable. The older
  source baseline also implemented `LocalGGUFQuickChatBackend` as an always-
  unavailable retired adapter. That is why the owner-visible local lane was
  disabled despite model rows and downloaded data.
- The current worktree has re-enabled the in-process `EpistemosLlama` package,
  verifies pre-existing model data before writing a receipt, and keeps GGUF
  under June. A new KEELSTONE artifact check now fails unless the MAS app both
  embeds and links the runtime. Retained artifact evidence:
  `/tmp/keelstone-retained-archive-gguf-link-20260710.log`.
- Focused test-source parsing and shell syntax pass. The source-only KEELSTONE
  gate passes at 10,256,384 bytes maximum RSS and 2,736,440 bytes peak
  footprint, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-appstore-gguf-link.log`.
- No model load, token generation, app launch, Xcode build/test, or archive ran.
  Current MAS artifact linkage and real June output remain HIGH OPEN.
- The saved June default is `openai:gpt-5.5`, which remains on the exact MAS
  allowlist and has a matching `agent_core` provider slug. No per-provider
  cloud-consent preference is stored, so the current source should refuse a
  cloud turn with the explicit consent-required message before sending data.
  Keychain secrets were not read and no provider request ran; cloud output
  therefore remains untested rather than presumed broken or working.

## Resume Checkpoint 2026-07-12 — Durable Handoff Grounding And Release-Gate Drift

### Verbatim owner wording

> Resume the exact in-flight Epistemos feature from its durable GitHub handoff.
> Do not begin implementation until you have grounded yourself in current source
> and verified the remote state.

> Continue from the recorded next action. Preserve MAS-only June boundaries,
> use surgical edits, and do not claim runtime behavior without current exact
> evidence.

### Interpreted intent

- Resume the published KEELSTONE evidence chain without relying on hidden task
  memory or importing private Columbia/VA/funding context.
- Verify GitHub identity before changing source, then continue only the exact
  next evidence action recorded by the handoff.
- Treat any current-tip contract failure as a surgical KEELSTONE correction;
  do not reopen general source hardening or advance the execution key.

### Hard constraints and non-goals

- Current execution key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- Active product remains `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`,
  `MAS_SANDBOX`, MAS/June, in-process `agent_core`, bundled/native assets,
  security-scoped vault access, and Keychain secrets.
- Do not revive Goose as a product, Pro, Experimental, 1Code, OpenChamber,
  sidecars, subprocesses, local servers, Node, terminal/code execution, stdio
  MCP, or browser-use.
- Do not claim build, archive, linkage, JuneWeb, vault, editor, June, or Kokoro
  runtime behavior from source guards.
- Do not mutate an owner vault, inspect secrets, call a provider, load a model,
  or play audio while archive prerequisites are red or absent.

### Proven state, contradiction, and acceptance checks

- `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`,
  local `HEAD`, `origin/feat/goose-surface`, and `git ls-remote` all resolve to
  `f73b3244c09a76a14961050964969bcb5ac9fa70`.
- The resumed worktree was clean and the resource preflight was safe: 77% free
  memory, 0.25 MiB of 1 GiB swap used, 808 GiB free disk, and no competing
  Xcode/model/app process.
- The committed source contains the recorded vault, editor, graph, June,
  Kokoro, and GGUF seams, but the committed 177-line release gate performs only
  40 source checks. It lacks the JuneWeb drift and built-app GGUF
  embedding/linkage checks required by the committed App Store source-guard
  tests and recorded handoff evidence.
- The checked-in `.june-web-stage` required by `build-june-web.sh`, CI, and the
  App Store bundle step is absent, and the external June donor checkout is not
  present on this laptop.
- A focused App Store test could not reach the assertion: the first run failed
  for a missing development provisioning profile; the unsigned retry failed in
  the required Rust build phase because `cargo` is not installed.
- KEELSTONE remains incomplete. A fresh signed archive and every owner-visible
  runtime acceptance check remain unproven.

### Next action

- Correct only the focused release-gate drift already specified by the active
  tests: fail closed on missing/stale staged or built JuneWeb, and require the
  built MAS app to embed and link June's in-process `llama.framework`.
- Verify shell syntax, the explicit source-guard contract, and fail-closed
  behavior on this checkout. Do not archive until Rust, signing, and the exact
  JuneWeb stage/donor prerequisites are restored.

## Owner Continuity Steer 2026-07-12 — Canon-First Reset Recovery

### Verbatim owner wording

> whenver u are done with whatever u are doing i need to make sure that i am
> able to set everythign back up. teh main canon is that one folder - is the
> canon folder i attached that is the soruce of truth for my work.

> the most important thing is that i make sure that i can cotninue working in
> order.

The attached executive-planner correction further states:

> The external master-canon folder controls the plan. Repository handoffs and
> the preparation packet may help us understand evidence, but they must never
> become replacement prompts.

### Interpreted intent

- Make the reset/new-Mac path reconstruct the exact active Epistemos work and
  its prerequisites without depending on hidden chat memory.
- Keep the July 8 master canon's numbered
  `03_MINIMAL_PROMPT_PACK.md` as the sole execution-prompt authority.
- Resume only its exact Prompt 2, KEELSTONE. Handoffs, evidence ledgers, and
  corrected low-RAM preparation may report state but may not rename, replace,
  wrap, reorder, or broaden the canonical prompt.
- Preserve both GitHub and offline recovery paths so a later session can verify
  identity and continue even if one path is unavailable.

### Hard constraints and non-goals

- Current execution key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`; do not start Prompt 3 or
  any later canonical key.
- Do not create a custom Prompt A/B/C/D chain or elevate older numbered plans,
  `MAS_EXECUTION_STATUS`, the preparation packet, or this ledger above the
  master canon.
- Preserve MAS-only June boundaries and the existing uncommitted release-gate
  correction.
- Keep private Columbia/VA/funding, credentials, secrets, and personal data out
  of the public repository and the public handoff.
- Do not claim that missing June generated assets, Rust, Apple signing, or
  exact runtime evidence have been restored until current checks prove them.

### Current recovery truth and contradictions

- The expected external canon folder is absent from Downloads, but a verified
  full copy exists at
  `/Volumes/treasure/Epistemos-External-Plan-Assets-2026-07-12/epistemos_mas_master_canon_2026_07_08`.
- The repository contains the curated, post-autonomy-fix canon copy and the
  corrected preparation packet. The flash drive contains the full canon,
  including preserved original source archives.
- Both in-flight flash-drive Git bundles verify as complete histories at
  `f73b3244c09a76a14961050964969bcb5ac9fa70`, but they do not contain the
  current uncommitted release-gate and ledger corrections.
- The Codex-state archive exists and has a recorded SHA-256, but the planned
  full APFS restore image was never created. Existing backup scripts also
  assume the external canon folders already exist in Downloads.
- `.june-web-stage`, the owner-modified June donor checkout, Rust, and the App
  Store signing profile remain absent on this Mac.

### Acceptance checks and next action

- Restore the full canon and corrected preparation folders to their expected
  Downloads paths from the verified flash-drive copies, then recompute their
  recorded tree identities.
- Add one canon-first recovery entry point that restores/verifies the canon,
  verifies Git identity, reports all build prerequisites, and prints only the
  exact canonical Prompt 2 location and evidence resumption boundary.
- Update the durable handoff without turning it into a replacement prompt.
- Verify, commit, and push the current in-scope corrections; then create and
  checksum a new offline Git bundle at the new commit so GitHub and flash-drive
  recovery agree.

### Continuity recovery outcome

- The full external master canon and corrected preparation packet are restored
  at their original Downloads paths and recursively match the verified
  flash-drive copies, excluding only external-drive `._*` metadata.
- Canon authority is now explicit in the public recovery manifest and durable
  handoff: the external numbered `03_MINIMAL_PROMPT_PACK.md` controls prompt
  identity/order; handoffs, status files, the repository mirror, and
  preparation remain subordinate state/evidence.
- `scripts/resume-keelstone-after-reset.zsh` is the single canon-first recovery
  entry point. It restores/verifies external assets, verifies GitHub identity,
  reports prerequisites without auto-installing them, applies the exact owner
  resource thresholds, and points to canonical Prompt 2 without copying or
  rewriting it.
- June continuity is honest but incomplete. The durable `epistemos-vendor`
  branch exists, while local commit `7105c43c8622cc546075f7ff1e20680e2009f8bb`
  and the 92-file dirty overlay were not pushed. The prior Codex-state backup
  retains recorded patch evidence, and the three reviewed July 10 stage hashes
  are now explicit recovery oracles. No substitute donor or stage was invented.
- The reset entry point currently verifies canon/Git/resource identity but
  reports Rust, Bun, signing, the exact June donor, and `.june-web-stage` as
  blockers. These must be green before the Prompt 2 test/archive/runtime chain.
- The scoped continuity implementation is committed locally. GitHub push is
  still blocked because this Mac has no HTTPS credential, GitHub CLI, SSH key,
  or signed-in GitHub browser session. The live remote was not changed. A new
  checksum-verified complete-history flash-drive bundle preserves the local
  commit(s), and its README gives the non-force authenticated publication path.
  GitHub protection remains verification debt rather than a claimed success.

## Owner Continuity Steer 2026-07-12 — Final Treasure Drive Deep Audit

### Verbatim owner wording

> if u need to use my flas hdrive for any thign else please use it so that when
> i cme back i can unplug it and stop usng it please.

> please make sure the treasure drive is deepyl checked for anythign remaining
> that is not currently working please.

### Interpreted intent

- Treat `/Volumes/treasure` as the last active recovery medium before the owner
  unplugs it.
- Deeply validate the physical/filesystem surface and every Epistemos/Codex
  recovery artifact, rather than trusting earlier spot checks.
- Repair safe packaging, checksum, script, pointer, and recovery-instruction
  defects now; leave an exact final drive report and a single obvious entry
  point for later restoration.

### Hard constraints and non-goals

- The external July 8 master canon and its numbered
  `03_MINIMAL_PROMPT_PACK.md` remain the sole prompt authority. This drive audit
  does not begin Prompt 3 or change the active KEELSTONE execution key.
- Do not delete stale or duplicate recovery assets without explicit owner
  approval. Classify them and make the newest checkpoint unmistakable instead.
- Do not inspect or infer unrelated private Columbia/VA/funding content. Audit
  only filesystem metadata and the Epistemos/Codex recovery scope the owner put
  in bounds.
- Do not expose credentials, force-push GitHub, mutate an owner vault, launch
  Epistemos, load a model, call a provider, or claim runtime evidence.
- Do not call a full backup complete while Codex is open if the backup script
  requires a closed application for consistent database capture.

### Acceptance checks

- `diskutil verifyVolume` or the strongest available read-only filesystem check
  reports the mounted treasure volume healthy.
- Root inventory, filesystem type, ownership/permissions, free capacity, and
  unexpectedly large or partial files are reviewed.
- Every checksum manifest passes; every Git bundle verifies as a complete
  history and lists its expected branch/SHA; every script parses and resolves
  the files it expects.
- The latest bundle can be cloned into a temporary location, checked with
  `git fsck --full`, switched to the recorded branch, and matched to the handoff
  checkpoint without touching the working checkout.
- External canon/preparation copies recursively match their restored Downloads
  counterparts; the current Codex incremental checkpoint and attachment pass.
- Stale/duplicate packs, missing full-image state, GitHub-auth dependency, June
  donor/stage loss, Rust/Bun/signing prerequisites, and any new failure are
  clearly classified rather than hidden.
- A final audit report, root read-first pointer, checksums, publication helper,
  and latest complete Git bundle all agree on one final local checkpoint.

### Next action

- Run the drive/filesystem inventory and read-only volume verification first,
  then verify every recovery pack and run isolated restore drills. Repair only
  evidence-backed recovery defects, commit the audit checkpoint, create a new
  checksum-verified complete-history bundle, and finish with repeated final
  zero-fail checks before declaring the drive safe to unplug.

## Owner Continuity Steer 2026-07-12 — Authorized Treasure Cleanup

### Verbatim owner wording

> ok can u delete leftover things that i do not need so i dont get confused
> when im getting rid of thigs just whatever was used and created for these
> purposes includng the columbia stuff since i have that on my other laptop.

> also u can contiue with what u neded me for so anyhting unresovled or
> remainng because i was gone

### Interpreted intent

- Reduce the treasure drive to one obvious, current Epistemos continuation set
  and remove older duplicate packs created by these recovery tasks.
- Remove the explicitly authorized Columbia transfer artifacts from the drive;
  the owner reports that material is already retained on another laptop.
- Continue the unfinished checksum, final-report, bundle, and safe-eject work
  after cleanup instead of stopping at the earlier audit findings.

### Hard constraints and non-goals

- Deletion authority is scoped to artifacts created or used for the recovery,
  continuity, and Columbia-transfer work. Do not treat it as permission to
  remove unrelated personal or research material merely because it is on the
  same drive.
- Preserve the verified full restore image, independent Codex-state archive,
  complete external canon/preparation assets, one final Git bundle, one final
  current-thread checkpoint, and the scripts/read-first material needed to use
  them.
- Do not delete the Codex-state archive merely because it is old: it retains
  the only recorded recovery evidence for the unpushed June donor overlay.
- Preserve MAS-only June and canonical Prompt 2 authority. Cleanup must not
  begin Prompt 3, fabricate the June donor/stage, or claim GitHub publication.
- Re-inventory immediately before deletion and delete only individually
  classified paths. Do not use a broad wildcard, recursive root cleanup, or an
  inferred private-content search inside unrelated files.

### Acceptance checks and exact next action

- Reconnect and mount `/Volumes/treasure`; verify its identity before any
  deletion.
- Classify every root item as preserve, delete-authorized, or unrelated/leave.
- Remove only the explicitly classified duplicate recovery and Columbia
  transfer artifacts, then recreate the final bundle/thread checkpoint and
  refresh every affected pointer and checksum.
- Repeat the recovery drills and filesystem check, then software-eject the
  drive and report the exact retained and removed paths.

## Owner Continuity Steer 2026-07-12 — Forced-Shutdown Recovery And Resume

### Verbatim owner wording

> i had to force shut donw my alptop please contonue with it all as if it
> neveer shut donw and reruall the thigns that failed please and contonue

The owner then re-supplied the full continuity objective, the exact
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` resume authorization, the
mandatory resource thresholds, the ten-step serial evidence chain, and the
original attachment path.

### Interpreted intent

- Treat the forced shutdown as an integrity boundary, not as permission to
  skip interrupted verification or silently continue from volatile `/tmp`
  artifacts.
- Re-establish the exact clean committed recovery state, rebuild any temporary
  final packs lost across reboot, rerun every interrupted/failed drive check,
  finish the authorized cleanup, and leave a safe continuation set.
- After recovery is durable and the drive is safely ejectable, resume only the
  external canon's exact Prompt 2 from the recorded resource/prerequisite
  boundary.

### Hard constraints and non-goals

- The external July 8 master canon and numbered
  `03_MINIMAL_PROMPT_PACK.md` remain the sole prompt authority. The re-supplied
  custom Prompt A/B/C/D history is evidence of a withdrawn wrapper approach,
  not execution authority.
- Do not begin Prompt 3, reinterpret the KEELSTONE done bar, or substitute the
  divergent historical `0c7123ba...` evidence checkout for this branch.
- Before any drive deletion/write after the forced shutdown, require a current
  read-only ExFAT check. Before any test/build, require the exact resource and
  prerequisite checks.
- Preserve unowned worktree changes unless current evidence proves they are
  reboot/tool-generated drift from the last clean checkpoint.
- Do not launch the app, load a model, call a provider, access secrets, mutate
  the owner vault, or run audio until the narrow compile/archive and artifact
  gates authorize the corresponding evidence leg.

### Current post-reboot evidence

- Repository branch/HEAD survived at `feat/goose-surface` /
  `27f90f8aea0d7cb653566b781ff0bfb80eb723b1`.
- The worktree was clean at that commit before shutdown. After reboot, only
  `Package.resolved` changed, removing the same three indirect SwiftPM pins
  previously documented as tool-created package-resolution drift. Restore the
  exact committed pins surgically before the final recovery commit.
- The volatile replacement Git/thread packs were absent from `/tmp`, as
  expected after reboot; rebuild them from current durable sources.
- Treasure volume UUID `FC33F188-7A19-33E7-BCF7-65496C19C7DC` passed a fresh
  `fsck_exfat -n -x` with exit code zero and stable reads after remount.
- Resource preflight is safe: zero swap, 87% free memory, zero throttled pages,
  777 GiB internal free space, and no competing Xcode/compiler/model/Epistemos
  process.

### Exact next action

- Restore the known committed SwiftPM lock entries, verify and commit this
  forced-shutdown checkpoint, rebuild the one final bundle/thread pack, finish
  the drive cleanup and repeated verification/eject, then run the canon-first
  resume script. Proceed to compile/archive only if every prerequisite remains
  green; otherwise record the exact blocker and stop without source expansion.

## Owner Build-Artifact Steer 2026-07-12 — One Current Build Only

### Verbatim owner wording

> movig forward there must be oe build whever testung u must delte the stale
> builds before building an ew app make sure this is in the memory of codex and
> claude and in this session and beyond please.

### Interpreted intent

- Every Epistemos build, test-build, and archive evidence leg starts by
  removing stale Epistemos app/archive products from the selected build
  location.
- Only one current app artifact may remain for the active evidence leg, so a
  human or agent cannot accidentally test, inspect, or cite an older app.
- This is durable project guidance for Codex, Claude, later sessions, and
  delegated agents, not a one-session cleanup preference.

### Hard constraints and non-goals

- Stop a prior Epistemos test host before deleting its product.
- Delete only generated Epistemos app/archive products and explicitly selected
  build output; do not delete source, package checkouts, owner documents,
  signed evidence receipts, or unrelated applications.
- Record the exact surviving app/archive path and identity after each build.
- Never use an older DerivedData or archive product as current evidence.
- This rule does not relax the serial-resource gate, signing gate, artifact
  gates, MAS-only June boundary, or Prompt 2 execution-key boundary.

### Acceptance checks and next action

- The rule is present in both root agent instruction surfaces, `AGENTS.md` and
  `CLAUDE.md`.
- Before the next Xcode build/test/archive command, inventory and remove stale
  Epistemos app/archive products, confirm no Epistemos process remains, and
  capture the clean build-output baseline.
- Update the KEELSTONE evidence document with the exact cleanup and the single
  artifact produced; do not start another build while an older app/archive
  remains in the selected output location.

## Owner Continuity Steer 2026-07-12 — Resume After Restart

### Verbatim owner wording

> i restarted it please conitnue

### Interpreted intent

- Resume the interrupted forced-shutdown recovery and Treasure-drive closeout
  from the last durable checkpoint, without repeating completed source work or
  treating the restart as permission to skip verification.
- Preserve a current offline continuation copy of both the Epistemos feature
  branch and the reconstructed June donor before the drive is unplugged.
- Continue canonical Prompt 2 only as far as present exact evidence permits.

### Hard constraints and non-goals

- Re-verify repository identity, worktree cleanliness, system resources,
  Treasure volume health, signing state, and GitHub state after the restart.
- Do not reset or overwrite the intentional local-ahead history. Do not
  force-push, expose credentials, begin Prompt 3, or substitute an unsigned
  Debug product for signed Release evidence.
- Before any future build, test build, or archive, preserve the durable
  one-current-build rule. No build is authorized while Apple signing remains
  absent at the Release boundary.
- Remove the older drive continuation pack only after its current replacement
  passes checksum and complete-history verification.

### Current evidence, acceptance checks, and next action

- Main repository is clean at `2c019466b837e17a6ee938d6794896eddd3520ac`
  on `feat/goose-surface`; fetched `origin/feat/goose-surface` remains
  `f73b3244c09a76a14961050964969bcb5ac9fa70`, an intentional documented
  five-commit fast-forward publication debt.
- Reconstructed June donor is clean at
  `adffe8fdc6ed8da868b705ed37ace96ff182d314` on
  `codex/recover-june-exact-2026-07-12`.
- Restart preflight passes: zero swap, 88% free memory, zero throttled pages,
  and no competing Epistemos/build/model process. Treasure UUID
  `FC33F188-7A19-33E7-BCF7-65496C19C7DC` passes `diskutil verifyVolume` with
  ExFAT check exit code zero.
- Apple signing still reports zero valid identities and no provisioning-profile
  directory; GitHub CLI remains unauthenticated. KEELSTONE therefore remains
  `INCOMPLETE` at the signed Release-archive boundary.
- Commit this restart checkpoint, regenerate and verify current complete-history
  Epistemos and June bundles, install one unambiguous replacement pack on the
  Treasure drive, remove only its superseded recovery pack after verification,
  refresh the drive pointers/report, sync, and software-eject the drive.

### Post-restart evidence and environment update

- The replacement Epistemos/June recovery pack and current conversation
  checkpoint passed checksums, complete-history bundle verification,
  independent clone/strict-fsck restore checks, and on-drive readback. The
  superseded `a69f5bfc41` packs were then removed. Treasure passed a second
  post-write ExFAT verification and software eject.
- The final Xcode `.xcresult` survived in DerivedData and was copied into
  durable checksummed aftercare storage. Its exact summary reports 71 tests
  passed, zero failed, zero skipped. The lost temporary source-gate log was
  regenerated without a build; the durable replacement reports 49 passes.
- The external master canon and all 18 original ZIPs passed identity/integrity
  checks. The corrected preparation packet matches its repository import for
  all nine files.
- GitHub authentication for the correct owner account became available after
  restart. Publish only the final clean continuity commit as a normal
  fast-forward, fetch again, and require local/tracking/live/handoff equality.
- Apple signing remains absent. After GitHub publication, it is the only
  owner-account gate before the one-current-artifact signed Release leg.

## Owner Product Steer 2026-07-13 — Free V1 Has No AI

### Verbatim owner wording

> can i just skip a;; th payment stuff rn why does it keep askngfor that i
> worke d on it without. i need ti contiue buidling the app. i also wat the
> june to be hiden so the v1 release will have june all agetane ai stuff will
> be the paid part the v1 free versjon will have no ai at all.

> i wat to contuue teh build tho. sso is umnenlens keelstone adn the other
> thin fro th mas canon folder what. is left that does not rest on ai featur4ew

### Interpreted intent

- Defer Apple Developer payment, enrollment, signing, StoreKit, subscription,
  and paid-account work. Do not keep asking the owner about those branches.
- Continue building the non-AI MAS product now. The free V1 exposes no AI
  feature: June, MiniChat/Epdoc Assist, local or cloud models, agent tools,
  generative summaries, live-note generation, AI transcription, neural voice,
  and editor AI actions remain hidden and unavailable.
- Preserve June and agentic-AI source as future paid-edition work; do not delete
  or revive it as part of the free V1 surface.
- Continue the non-AI product spine: KEELSTONE vault/storage/reconcile/release
  safety; LUMENLENS editor, lens-fidelity, notebook, and writeback behavior;
  RECKONER dataset artifacts, tables, calculation, charts, tabs, and embeds;
  plus non-AI Quick Capture, sync, PDF, research metadata/import, WebKit
  browser-lite, graph, search, workspace, and export behavior.

### Hard constraints

- Current execution key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`; this steer changes the
  free-product boundary but does not invent a replacement execution key.
- MAS-only architecture remains controlling. Pro, Developer-ID, Experimental,
  1Code, OpenChamber, Goose, Kindred, sidecar, subprocess, local-server, Node,
  terminal/code-exec, stdio MCP, and browser-use lanes remain parked.
- The free V1 must fail closed at one centralized product-capability policy.
  Hiding one button while leaving another route, shortcut, automatic job, or
  settings deep link active is insufficient.
- Preserve AI implementation for a future paid edition, but do not add payment,
  StoreKit, receipt, account, entitlement, or signing behavior in this slice.
- Preserve the one-current-build rule. Before any Xcode test/build/archive,
  stop prior Epistemos hosts, delete stale Epistemos app/archive products, and
  retain exactly the current evidence artifact.
- Do not claim runtime behavior from source guards or historical tests.

### Non-goals

- No Apple enrollment, fee, certificate, profile, Team ID, bundle-ID transfer,
  StoreKit, subscription, paywall, or paid-feature activation work.
- No deletion of June, model, voice, agent, or provenance source needed by the
  future paid edition.
- No signed Release/archive claim and no transition to a later canonical
  execution key merely because the free-V1 visibility boundary is source-green.

### Acceptance checks

- A single free-V1 policy reports AI unavailable and is the source of truth for
  all affected UI and automatic-runtime gates.
- Landing and navigation do not expose or enter June or AI transcription.
- Settings do not expose June models, AI voice, generative summaries, or live
  notes, including notification/deep-link selection.
- Epdoc does not mount Ask June/AI assist controls in free V1.
- App Shortcuts do not advertise or execute AI-only actions in free V1.
- Primary launch does not populate agent-provider environment, start
  generative workspace-summary/live-note work, run meaning-anchor backfill, or
  otherwise schedule an automatic AI operation for free V1.
- Plain text Quick Capture, vault/editor/graph/workspace, sync, PDF/import,
  browser-lite, LUMENLENS, and RECKONER non-AI paths remain available.
- Focused tests and semantic source scans pass; exact runtime/manual and signed
  artifact evidence remain explicitly separate debt.

### Contradictions and resolution

- The July 8 canon makes MAS/June the only active agent and originally orders
  June before LUMENLENS/RECKONER. The later owner steer is a deliberate product
  change: the free V1 has no active agent at all, while June is retained as the
  sole future paid agent. This does not authorize another agent lane.
- The old KEELSTONE exit matrix requires visible June/model/Kokoro evidence.
  Those legs no longer gate the free V1 product surface; they become future
  paid-edition verification debt. Storage, editor fidelity, graph/editor
  responsiveness, privacy, and non-AI artifact truth remain active KEELSTONE
  obligations.
- Apple signing still blocks a final distributable Release verdict, but it does
  not block reversible source work, source checks, or a cleaned unsigned Debug
  regression build for the non-AI product.

### Exact next action

- Add a failing focused free-V1 boundary regression, then introduce the
  smallest centralized product-capability policy and route the main landing,
  settings, Epdoc assist, shortcuts, Quick Capture, and automatic launch jobs
  through it. Run source checks first; before any Xcode test build, remove the
  stale Debug app and all Epistemos archives under the selected build outputs.

## Owner Product Steer 2026-07-13 — Epdoc Planner, Meeting, Sync, and Kokoro

### Verbatim owner wording

> well lets continue also i want to fold thse into the feature sets. i wnat ot
> upgrade epdoc as muhc as i can. also meetng and other things are stiol not
> rlly connetred that much. i ofc want to keep the voicer model tho tha is what
> ll kee the kokoro model beause uts imoportant but i also wat toamke epdoc alot
> more useful taking all featres from things 3 ad the ohter creenshots adding
> that to the mas canon and remmeber idk if reckoner was the last thng i still
> had teh sync thing i ha oher thngs beyid reckoner.

### Interpreted intent

- Upgrade Epdoc from a note editor into the central non-agentic planning
  workspace: Markdown notes plus tasks, projects/areas, Today, Upcoming,
  scheduling, reminders, recurring work, daily/periodic planning, time blocks,
  goals, folders, meeting notes, and calendar context.
- Connect Meeting to Epdoc, tasks, calendar references, vault artifacts,
  provenance, search/graph, and export instead of leaving it as an isolated
  landing surface.
- Keep Kokoro local voice/read-aloud in free V1. Free V1 still excludes June,
  agentic behavior, cloud/local chat models, generative editing/summaries, and
  AI-only automatic jobs.
- RECKONER is not the end of the product sequence. The capability ring remains
  active after LUMENLENS/RECKONER and includes Sync, Meeting, Quick Capture,
  calendar/tasks, ResearchHub, PDF, browser-lite, voice, search/graph, and
  export.
- Fold the product motifs visible in the owner-supplied Things 3 and NotePlan
  screenshots into the MAS canon as Epistemos-native capabilities, not as a
  visual or proprietary-format clone.

### Hard constraints

- This checkpoint supersedes only the prior checkpoint's instruction to hide
  neural voice. Kokoro is an explicit free-V1 exception and must remain local,
  consent-aware where microphone input is used, and separate from generative
  AI/agent routing.
- Vault Markdown and approved artifacts remain durable truth. Today, Upcoming,
  calendar panes, task indexes, logbooks, and search views are derived
  projections, not a second authoritative database.
- Calendar and reminder access must be optional, user-initiated, least-
  privilege, sandbox-entitled, denial-safe, and represented by stable external
  references rather than silently importing a second calendar truth.
- Meeting recording/transcription requires visible consent and durable source
  artifacts. No hidden recording, sidecar, subprocess, Python voice engine,
  local server, or separate transcript database.
- Preserve MAS-only boundaries, the current KEELSTONE execution key, the
  one-current-build rule, and the deferral of Apple payment, StoreKit, signing,
  subscription, and paid-feature activation work.
- Do not copy Things 3 or NotePlan trade dress, copyrighted screenshots,
  proprietary sync, or proprietary file formats. Rebuild the useful concepts
  through Epistemos' existing native workspace, Epdoc, KEELSTONE, LUMENLENS,
  RECKONER, and capability-ring architecture.

### Non-goals

- No June, Epdoc Assist/MiniChat, generative task creation, AI scheduling,
  agent tool execution, model picker, cloud provider, or paid-feature runtime
  in the free-V1 implementation lane.
- No new task database, planner room, meeting database, sync authority, or
  duplicate provenance/event bus.
- No Apple enrollment/payment/signing work in this slice.

### Acceptance checks

- The external MAS master-canon folder and repository recovery mirror contain
  the same dated free-V1 Epdoc/planner/capability-ring addendum and active-doc
  updates.
- Canon order clearly continues beyond RECKONER into Meeting, Sync, Quick
  Capture, calendar/tasks, ResearchHub, PDF/browser-lite, Kokoro voice,
  search/graph, and export.
- Epdoc task/planner data remains readable Markdown with deterministic parsing,
  stable IDs, visible conflict behavior, and rebuildable projections.
- Meeting notes can reference an EventKit event, attendees, tasks, transcript/
  audio artifacts, sources, and follow-ups without requiring June or a second
  store.
- Kokoro remains visible and usable without exposing June or other AI-only
  surfaces.
- Focused source/tests prove the first selected slice; runtime and distributable
  claims remain separate until exact current evidence exists.

### Contradictions and resolution

- The immediately preceding checkpoint listed neural voice among hidden AI
  features. The owner's later explicit wording controls: Kokoro remains in free
  V1. This does not reactivate June, chat models, generative editing, agent
  tools, or automatic AI work.
- The July 8 build order placed MAS June before LUMENLENS/RECKONER and treated
  the capability ring as June-dependent. For free V1, June is deferred and the
  deterministic portions of LUMENLENS, RECKONER, Meeting, Sync, Capture,
  calendar/tasks, voice, research/import, browser-lite, graph/search, and
  export proceed without an active agent. June remains the sole future paid
  agent if the owner later reactivates that lane.

### Exact next action

- Add a dated active addendum to both MAS canon copies, update the active-doc
  manifest and affected build-order/domain docs, verify byte parity and
  contradiction searches, then inspect the live Epdoc/task/calendar/Meeting/
  Sync/Kokoro seams and choose the smallest test-first deterministic product
  slice. Do not begin another canonical execution key.

## Owner Product Steer 2026-07-13 — Browser and ResearchHub Are Paid-Only

### Verbatim owner wording

> add it all to the mas canon so that it i not forgotten and i eant to strt
> building. trh browser, research hub both are needing to be on paid version as
> well an hidden from v1 releawe s plaae ad that to that part.

### Interpreted intent

- Persist the complete Epdoc/planner/Meeting/Sync/Kokoro direction in the MAS
  canon and proceed into implementation after canon parity and grounding.
- Browser and ResearchHub join June and generative/agent features in the future
  paid capability set. They must be hidden and inert in free V1.
- Free V1 continues with KEELSTONE, LUMENLENS/Epdoc planner, RECKONER,
  Meeting, Sync, Quick Capture, calendar/tasks, PDF/import, Kokoro local voice,
  graph/search, workspace, and export.

### Hard constraints and non-goals

- One centralized free-V1 capability policy must gate Browser and ResearchHub
  routes, landing/navigation, settings, shortcuts, deep links, automatic jobs,
  and provider/network startup; hiding a tile alone is insufficient.
- Preserve Browser and ResearchHub source for the future paid MAS edition. Do
  not delete them, implement payment/StoreKit, or reactivate June.
- Keep ResearchHub official-source/OA/BYO legality rules and WebKit-only browser
  architecture in the paid canon; paid status never permits scraping,
  Chromium/browser-use, sidecars, credential harvesting, or illegal content.
- Continue the current KEELSTONE execution key and one-current-build rule.

### Acceptance checks and exact next action

- Both MAS canon copies explicitly classify Browser and ResearchHub as future
  paid and free-V1 hidden/inert, while retaining their safe architecture.
- Canon contradiction searches contain no active-free Browser/ResearchHub
  directive without a dated paid-only qualification.
- After canon verification, inspect the centralized product-capability seam and
  add a failing free-V1 boundary regression that covers June, Browser, and
  ResearchHub while preserving Kokoro, Meeting, Sync, and the Epdoc planner.

## Implementation and Evidence Checkpoint 2026-07-13 — Free V1 Boundary and Single Archive

### Verbatim owner wording

> the v1 free versjon will have no ai at all.

> browser, research hub both are needing to be on paid version as well an
> hidden from v1 releawe

> movig forward there must be oe build whever testung u must delte the stale
> builds before building an ew app

### Interpreted intent

- Build the free V1 now without waiting for payment, StoreKit, Apple enrollment,
  or paid-feature activation.
- Keep June, agent/generative/model features, Browser, and ResearchHub for the
  future paid MAS edition, but make them hidden and inert in free V1.
- Keep Kokoro and the deterministic free capability ring available.
- Produce and retain exactly one current app/archive for the active evidence
  leg, then continue the non-AI runtime matrix only when artifact gates pass.

### Implemented and proven state

- `ProductCapabilityPolicy` is the centralized free/paid seam. Free V1 fails
  closed across paid landing/navigation, settings, App Intents/shortcuts,
  restoration, startup, cloud-provider state, June, Browser, ResearchHub/arXiv,
  and generative editor/notes actions.
- `project.yml` declares `EPISTEMOS_PRODUCT_EDITION=FREE_V1` and
  `EPISTEMOS_FREE_V1`. Free packaging omits `JuneWeb`,
  `model_manifest.json`, and `DefaultSkills`.
- The focused policy result at `/tmp/Epistemos-FreeV1-Policy.xcresult` passes
  8/8 tests with zero failures or skips.
- The edition-aware KEELSTONE source gate passes.
- Exactly one Release archive exists at
  `/Users/jojo/Downloads/Epistemos/build/archives/Epistemos-FreeV1-current.xcarchive`.
  Its exact app is universal, bundle `com.epistemos.appstore`, version 1.0.0
  build 1, and passes strict deep local ad-hoc signing with the App Sandbox
  entitlement.
- The exact built-app KEELSTONE gate and comprehensive bundle scanner pass.
  The free archive omits paid web/model/skill resources and prohibited parked
  runtime/resource markers.

### Constraints, non-goals, and verification debt

- The local ad-hoc signature is evidence only. It is not Apple distribution
  signing and does not prove App Store submission readiness.
- The free target still links shared dormant native libraries, including
  `libagent_core`, `libomega_mcp`, and `llama.framework`. Removing them is
  build-topology/size debt; deleting them from a linked artifact is unsafe.
- No model, provider, secret, owner vault, network, microphone, or audio action
  ran in this checkpoint.
- The owner-visible matrix did not begin because the Mac was locked and the UI
  evidence tool correctly refused to bypass the lock. No Epistemos process or
  correlated runtime log was created.
- Do not change the owner's five-minute lock setting, ask about payment, or
  reactivate paid features merely to complete local evidence.

### Exact next action

- When the Mac is unlocked, repeat the owner resource preflight. If it passes,
  keep the sole archive immutable, launch its exact app, and run the finite
  free-V1 matrix serially with correlated logs and a disposable vault.
- Verify paid surfaces are absent/inert; then verify vault persistence, Epdoc
  fidelity, deterministic Meeting/Capture/planner/Sync/calendar/PDF/export
  entry points, graph/search routing, and English Kokoro without any agent,
  model, or provider startup.
- Update the existing exact-runtime evidence document and stop after the final
  KEELSTONE verdict. Do not begin another canonical execution key.

## Owner Program Steer 2026-07-13 — Canon-First Free V1 Workspace Continuation

### Verbatim owner excerpt

> updat the acual files in mas canon folder the pne that was in h te restore
> with thr minimal prompt thing i just nee to be able to acccessall thes
> features and ecisions so idl if intent ledgerand other things are in the mas
> canon but i want it in the minimal prompt doc as well just everywhere so its
> part of the canon please.

> the source surface part of the app i want it to look like teh mark edit or
> more like mark edit ... i still want to keep my theme palette ... the rigth
> hand side is a diff color like the line count strip is a diff color and i
> should be the same color as the rest of the surface instead of a grey color.

> there should eb no chats no ai other than kokoro ... i still see chats o the
> grsph whe there shoud not be chats at alll ... lots of settings parts and
> graph filters and just settigns nad things in general are stale and need to
> be removed.

### Interpreted intent

- The restored external MAS canon is the working source of truth and its
  minimal prompt must itself carry the current free-V1 execution boundary,
  feature sequence, clone/reference provenance, and next-action rules. The
  repository mirror must remain byte-identical.
- Continue beyond the KEELSTONE checkpoint into a visibly serious free-V1
  workspace product: LUMENLENS/Epdoc, RECKONER data surfaces, Meeting, Sync,
  Capture, calendar/tasks, PDF/import, Kokoro, graph/search, and export.
- Remove or completely hide every chat/AI/model/June/agent surface except
  Kokoro. This means navigation, restored state, graph cards/filters, settings,
  editor chrome, shortcuts, and visual residue—not merely feature tiles.
- Use the already-present MarkEdit clone as a reference for a structural Source
  editor upgrade while retaining the Epistemos palette: stronger readable type,
  unified editor/gutter/minimap colors, refined source chrome, and tabs moved
  out of the note-body/content area into a purposeful toolbar location.
- Recover the actual RECKONER clone/reference inventory before implementing
  datasets; do not invent or silently replace a spreadsheet/calc source.

### Hard constraints

- Active product edition is `FREE_V1`; Kokoro is the only allowed AI-adjacent
  capability. June, model/provider/generative/agent behavior, Browser, and
  ResearchHub remain preserved for future paid work but are hidden and inert.
- Keep the current execution key
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` until its remaining
  evidence is honestly closed. Do not treat the work as a new agent/runtime
  execution key.
- Use the external canon and repository mirror together. Every active-canon
  change must preserve byte parity and manifest identity.
- Preserve vault Markdown/artifact truth, KEELSTONE writes, existing themes,
  native Swift/AppKit/SwiftUI, sandbox boundaries, and the one-current-build
  rule. No sidecar, server, subprocess, Node product runtime, Chromium,
  browser-use, or hidden chat fallback.
- Read target files/call sites/tests before editing; use test-first work for the
  first source/editor or stale-surface correction.

### Non-goals

- Do not clone proprietary Things/NotePlan visuals or formats.
- Do not re-enable or delete the retained paid June/Browser/ResearchHub source.
- Do not start payment, StoreKit, provider, model, or Apple signing work.
- Do not claim performance or visual completion from static source edits alone.

### Acceptance checks

- External and repository canon contain the same dated execution update, and
  `03_MINIMAL_PROMPT_PACK.md` makes the free-V1 order, retained clone truth,
  anti-chat boundary, and next product slices explicit.
- An audit maps the current local MarkEdit and RECKONER-related sources before
  code changes; unresolved clone provenance is visibly recorded rather than
  guessed.
- Source/Code presentation has a tested, native structural improvement that
  preserves the Epistemos palette and removes the mismatched gray gutter/right
  strip behavior.
- Chat/AI/model surfaces have a complete current-source audit and the first
  highest-risk escape path is corrected with a regression test.
- Performance debt names exact hot paths, evidence, and a serial verification
  checkpoint rather than a vague promise.

### Contradictions/questions

- The old canon’s numbered Prompt 3 remains paid/deferred while the owner asks
  to continue all free feature sets. The dated free-V1 canon must make the
  deterministic Prompt 4/5 work eligible after the KEELSTONE evidence boundary
  without treating June as active.
- The current app already has a MarkEdit clone and RECKONER source references,
  but the exact intended spreadsheet/calc clone set has not yet been recovered
  from current source evidence. Inventory precedes implementation.
- Runtime matrix evidence is still blocked only by the locked Mac. Static and
  targeted source work can continue without bypassing that lock.

### Exact next action

- Audit the restored canon, local MarkEdit clone, RECKONER dependencies, and
  current stale chat/settings/graph paths in parallel; then update the active
  canon and minimal prompt before selecting the first test-first Source/Code or
  stale-surface implementation slice.

## Owner Correction 2026-07-13 — RECKONER Real-Source Stack

### Verbatim owner steer

> no the pla was to use the actual clone of the iron calc univer etc. but
> iron calc as the fromt end why was that taken off

### Interpreted intent

RECKONER must preserve the owner's actual-source direction, rather than be
weakened into a generic future package idea. The owner identifies IronCalc as
the intended spreadsheet front end and expects the real IronCalc/Univer source
clones to be part of the plan. RECKONER remains deterministic free-V1 workspace
work; it is not a June, chat, Browser, ResearchHub, or paid-AI feature.

### Current evidence and contradiction

The current checkout has no local IronCalc or Univer clone/package. Historical
July planning records that fresh verification clones existed under the ignored
`.research-clones/work/` area at the time, then settles the later grid split as
"IronCalc is the calculator, Univer is the screen." This was a historical
architecture choice, not a clone deletion performed in this session. It
conflicts with the owner's newer wording that IronCalc should be the front end.
The newer owner instruction controls product direction, but its exact desired
division of the IronCalc and Univer UI/source roles must be recovered before
any source fetch or grid wiring is started.

### Hard constraints

- Retain vault artifacts as truth, with derived GRDB only; no Data room or data
  chat.
- Do not silently fetch, install, or wire a missing third-party dependency.
  Record upstream URL, commit/tag, content digest, license, package-size impact,
  build script, and MAS packaging test first.
- Preserve one calc authority and make all edits pass through the same native
  workspace contract; do not run a second formula engine by accident.
- Keep the acquired grid as a free-V1 deterministic capability and keep all
  June/agent tool paths inert.

### Acceptance checks and next action

- The MAS canon records the owner correction and distinguishes verified local
  absence from intended, recoverable source.
- A source-recovery card names the historical clone evidence and the required
  exact-pinned acquisition proof; it does not pretend the bytes are present.
- Before RECKONER implementation, resolve the front-end split with an owner-
  traceable source review, then run a small license/package/MAS WebView spike.
- Continue the independent free-V1 stale-surface/graph fixes without waiting
  for the missing RECKONER sources.

## Free V1 Graph Projection Slice — 2026-07-13

### Exact owner intent carried into this slice

> there should eb no chats no ai other than kokoro ... i still see chats o the
> grsph whe there shoud not be chats at alll

### Implemented scope

- Added a single product-policy graph-projection rule for free V1 that excludes
  `chat`, `run`, `rawThought`, and `toolTrace` from graph presentation while
  retaining their durable vault records for a future paid edition.
- Applied that rule to graph filter menus/defaults, direct filter mutation,
  background filter snapshots, graph-state visibility checks, and GraphBuilder
  chat-node construction. Existing builder-owned chat nodes remain eligible for
  removal during a later normal graph persistence diff.
- Added the active App Store test-target contract in
  `FreeV1ProductCapabilityPolicyTests`: the hidden types cannot be visible or
  default-active, and an in-memory stored `SDChat` does not build a graph node.

### Preflight and evidence to date

- Before the test build: `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty-entry count 17; swap
  used 418.25 MB; free-memory percentage 69%; pages throttled 0; 749 GiB free
  in the temporary build volume; no competing compiler, model, or Epistemos
  process.
- The prior archive was deleted before this new evidence leg. The only current
  generated product is the temporary App Store test build at
  `/tmp/Epistemos-FreeV1-Graph-TDD/Build/Products/Debug/Epistemos.app`.
- `xcodebuild build-for-testing` for the App Store scheme completed with
  signing disabled, then the test host was ad-hoc signed and strict-verified.
  This is local test evidence only and is not distribution signing.
- The targeted `test-without-building` runner created
  `/tmp/Epistemos-FreeV1-Graph-TDD-result.xcresult` but failed during test-host
  bootstrap before it invoked any named test: one system failure, zero passed
  tests, “test runner exited with code 1 before establishing connection.”
  It is a test-host/runtime-environment failure, not a pass or a source-test
  failure.

### Verification debt and exact next action

- Rebuild the same single temporary product after the source change and rerun
  the targeted App Store test. Do not claim a test pass unless a real named
  test result is present. Preserve the host-bootstrap failure if it repeats.
- Run narrow source guards for all graph-projection seams, then proceed to the
  next audited free-V1 stale surface only after recording its own test-first
  contract.

### Post-change compilation result

- The post-change `build-for-testing` completed for the same App Store scheme
  and produced exactly one current temporary app plus its embedded
  `EpistemosAppStoreKeelstoneTests.xctest` bundle. The host was ad-hoc signed
  and `codesign --verify --deep --strict` passed.
- Source guards confirm the policy is consumed by the visible/default type
  lists, direct filter mutation, main and background visibility checks,
  graph-state type checks, and GraphBuilder's chat projection gate.
- The post-change targeted runner repeated the same pre-test bootstrap failure:
  `Epistemos (61642) encountered an error`, zero passed named tests, and no
  test body result. It neither validates nor falsifies the new assertion.
  Do not erase this retained result or report test success without a named-test
  record.

## Free V1 Epdoc Chat-Reference Projection Slice — 2026-07-13

### Exact owner intent carried into this slice

> i want the v1 free version will have no ai at all.

> there should eb no chats no ai other than kokoro

### Implemented scope

- Kept notebook and block-embed records parsed and serializable as the durable
  note truth, then added a free-V1 presentation rule that suppresses `chat`
  references only at the UI projection layer.
- Applied that rule to selectable tab restoration, the document tab strip, the
  new-tab launcher, reference-pane lookup, notebook outline rows, embedded
  reference outline rows, and lens-fidelity/transcript disclosures.
- Added an active App Store test contract that a parsed chat manifest tab
  remains present in `manifest.tabs` but is absent from selectable IDs and the
  table of contents. Updated the dormant focused notebook tests to preserve
  the same distinction.

### Deferred verification and remaining seam

- Test execution remains batched behind the already-recorded app-host bootstrap
  failure. The next single temporary App Store test build must compile both the
  graph and Epdoc contracts, then attempt the real named-test run again.
- `js-editor/src/markdown/tiers.ts` still classifies historical notebook chat
  lines for round-trip/fidelity accounting. It has not been changed in this
  narrow native projection slice; audit whether that classifier can surface a
  user-visible free-V1 disclosure before changing it. Do not claim that every
  chat residue is gone until this seam and the remaining source audit pass.

### Post-change compilation result

- The combined graph-plus-Epdoc App Store `build-for-testing` completed and
  compiled both newly added active test contracts. Its sole current temporary
  product is `/tmp/Epistemos-FreeV1-Graph-TDD/Build/Products/Debug/Epistemos.app`;
  the embedded test bundle is present and the local ad-hoc signature passed
  strict verification.
- The targeted runner again failed before invoking a named test: `Epistemos
  (66286) encountered an error`, with the same early host-bootstrap exit.
  This confirms the test-host blocker is reproducible across the graph and
  Epdoc source changes; it does not turn compiled contracts into runtime pass
  evidence.

### Embedded-editor classifier disposition

- Source tracing found `notebookChatTab` in `js-editor/src/markdown/tiers.ts`
  only for the development markdown round-trip checker. No native or bundled
  editor runtime path consumes `roundTrip` or `disclosureItemsForLens`; the
  checker preserves historic manifest bytes and verifies serializer behavior.
- Therefore this is not a current free-V1 visible-chat escape path. It remains
  intentionally unchanged as retention-only tooling, while native runtime
  tabs, outlines, launchers, and disclosures use the new presentation gate.

## Epdoc Source Surface — Unified Gutter Slice — 2026-07-13

### Exact owner intent carried into this slice

> the rigth hand side is a diff color like the line count strip is a diff
> color and i should be the same color as the rest of the surface instead of a
> grey color.

### Implemented scope

- Removed the 4.5–5.5% light/dark blend that made the MarkEdit CoreEditor
  line-number gutter a separate gray strip.
- The gutter now receives the same opaque editor-surface token as the content;
  its existing low-contrast divider, line-number contrast, semantic syntax,
  selection, and active-line tokens remain unchanged.
- Added a free-V1 active test contract for both a light and a dark Epistemos
  theme: `palette.gutter == palette.background`.

### Verification debt

- The current temporary test product predates this palette edit and is stale.
  Before any next run, remove it under the one-current-build rule, re-run the
  owner resource preflight, compile all three active contracts, and attempt
  the named-test runner. A build cannot prove the visible color result; a
  later unlocked manual editor check must inspect both themes.

### Post-change compilation and focused-run result

- The stale temporary product and its prior result bundle were removed before
  the next evidence leg. The preflight passed at `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, with 29 dirty entries, 402.25
  MB swap used, 67% free memory, zero throttled pages, 747 GiB available disk,
  and no competing Epistemos/compiler/model process. Codex helper processes
  were present but are not Epistemos build, model, or runtime processes.
- A single new App Store `build-for-testing` product was then created at
  `/tmp/Epistemos-FreeV1-Graph-TDD/Build/Products/Debug/Epistemos.app`; it
  includes the App Store test bundle. Its local ad-hoc signature passed
  `codesign --verify --deep --strict`. This is compilation/test-host evidence
  only, not a distributable app or runtime proof.
- The focused source guards locate the graph and Epdoc policy consumers and
  the unified-gutter assignment. `git diff --check` passed.
- The focused test runner was attempted only against
  `FreeV1ProductCapabilityPolicyTests`. It failed before named tests began:
  `Epistemos (70093) encountered an error` / `Early unexpected exit,
  operation never finished bootstrapping`; its result bundle reports one
  system failure, zero passed tests, and no assertion-level result. This is a
  repeated test-host bootstrap blocker, not a passing test and not evidence of
  the three contracts' runtime behavior.

### Exact next action

- Preserve the one current temporary test product. Before another build, read
  the next free-V1 stale-surface seam and its call sites, add a narrow failing
  contract, re-run the owner resource preflight, then replace this sole
  product and re-attempt the focused runner. Do not archive, launch, or make a
  visual-runtime claim while this bootstrap failure and manual editor evidence
  remain open.

## Free V1 HTML Workspace Chat-Context Projection — 2026-07-13

### Exact owner intent carried into this slice

> there should eb no chats no ai other than kokoro

> i want the v1 free version will have no ai at all.

### Grounded finding and interpreted intent

`HTMLWorkspaceDataFeedContextSources` currently recognizes chat queries,
fetches persisted `SDChat` records, and packages their title, preview, type,
and update time as `recent_chat` context. This is a free-V1 presentation path
for stored AI/chat material and conflicts with the owner direction. The
durable records must remain untouched for a future paid edition; the free-V1
workspace must neither classify nor return them.

### Hard constraints and acceptance checks

- Preserve normal note, PDF, folder, meeting, capture, clip, graph-note, and
  provenance data-feed behavior.
- In free V1, direct `recent_chat` requests and chat-like freeform queries
  return no `SDChat` result; freeform classification does not advertise the
  hidden context kind.
- Keep the source reusable for a future paid edition through the one product
  policy; do not delete records, schema, or the paid implementation.
- Add the active App Store test contract before production-source edits. Its
  executable result remains subject to the known host-bootstrap blocker.

### Non-goals

- Do not broaden this slice into HTML workspace generation, all provenance
  contexts, broad settings cleanup, or RECKONER source recovery.
- Do not make a visual/runtime claim from source or compile evidence.

### Exact next action

- Add the free-V1 context-policy contract and its App Store test, then gate
  only the `recent_chat` classification and result branch. Re-read the diff,
  rebuild only after the next resource preflight, and retain the current
  one-artifact discipline.

### Implemented projection boundary before verification

- The policy now denies the `recent_chat` workspace context in free V1.
  Direct source reads, freeform classification, and standalone-refresh
  scheduling therefore fail closed while preserving the source code and
  durable `SDChat` records for the future paid edition.
- Legacy generated feed envelopes are projected before presentation: stored
  chat results, context kinds, required-kind metadata, and chat provenance are
  removed from the derived data supplied to the data-feed status and to every
  `HTMLWorkspacePreviewDocument` render. The raw package data remains stored
  unchanged, so this is a visibility boundary rather than data destruction.
- The active App Store test contract covers both persisted-chat lookup and a
  legacy `data.json` envelope reaching the rendered preview. The dormant
  context-source tests now describe the same free-V1 expectation.
- Verification debt: the HTML Workspace code/data-source editor still exposes
  raw package source by design. It needs a separate, owner-visible surface
  audit before any claim that all developer/editor routes hide historical chat
  bytes; this slice proves the data-feed and rendered-preview paths only.

### Compilation and focused-run result

- Before this replacement build, preflight recorded HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, 34 dirty entries, 402.25 MB
  swap used, 68% free memory, zero throttled pages, 747 GiB free disk, and no
  competing Epistemos/compiler/model process. The prior temporary app/result
  were removed first, so the resulting App Store product is the sole current
  test artifact at `/tmp/Epistemos-FreeV1-Graph-TDD/Build/Products/Debug/Epistemos.app`.
- `build-for-testing` compiled the graph, Epdoc, unified-gutter, and both HTML
  workspace chat-projection contracts. The local ad-hoc test host passed
  strict deep signature verification. Existing unrelated async warnings in
  `VaultSyncService.swift` and `TextCapturePipeline.swift` remained warnings,
  not this slice's errors.
- The focused test runner was then attempted on
  `FreeV1ProductCapabilityPolicyTests`; it again stopped before named tests:
  `Epistemos (77054) encountered an error`, early unexpected bootstrap exit,
  exit 65, one system failure, zero passed named tests. The fresh result bundle
  is `/tmp/Epistemos-FreeV1-Graph-TDD-result.xcresult`. This does not prove the
  new assertions at runtime and must remain verification debt.

### Exact next action

- Preserve the current temporary artifact. Read and trace the next free-V1
  chat/AI user-presentation seam before edits, beginning with the workspace
  welcome/session-state and any source-data editor route. Keep the HTML
  workspace raw-data-editor question scoped separately; do not archive or
  launch until a dedicated evidence leg permits it.

## Free V1 Welcome-Back Projection — 2026-07-13

### Exact owner intent carried into this slice

> there should eb no chats no ai other than kokoro

> i want the v1 free version will have no ai at all.

### Grounded finding, scope, and acceptance checks

The workspace restore engine already sets its presented chat count to zero,
but the Landing Welcome Back view still rendered and read aloud a literal
`0 chats` statistic. `WelcomeBackInfo` also accepted a persisted model summary
and rendered it as the resume point. Free V1 must preserve the user's own
note, restored-note/graph/session context, and durable paid records, while
showing neither chat statistics nor a prior model narrative.

- The active App Store contract constructs a stored model summary plus four
  chats and expects no visible model summary, chat count, chat text, or
  spoken chat phrase.
- The presentation object now has paid-boundary accessors, and Landing uses
  those accessors for visual stats, speech, restored-surface text, and an
  optional saved session note.
- Durable storage and the future paid route remain unchanged; this is not a
  broad restore-engine or data-deletion change.
- The just-created temporary test artifact predates this source change. Keep
  it until the next explicitly preflighted batch; do not rebuild it now merely
  to chase the same known test-host bootstrap failure.

## Owner Clarification and Source-Recovery Check — RECKONER IronCalc Front End — 2026-07-13

### Verbatim owner steer

> no the pla was to use the actual clone of the iron calc univer etc. but
> iron calc as the fromt end why was that taken off

### Interpreted intent

The actual IronCalc source—not a generic replacement grid and not Univer—must
own the RECKONER free-V1 spreadsheet front end as well as calculation. The
historical IronCalc/Univer clone set remains a required provenance/recovery
input, but Univer must not displace IronCalc or become a second formula engine.

### Current exact evidence

- The old July source decision was a documented design pivot, not a current
  code deletion: `PLAN9_ADJUDICATION_WORKING_2026_07_03.md` chose
  silent-Univer as screen after judging its grid UI stronger at the time.
- The corresponding historical shallow clones were ignored working copies:
  IronCalc `1bd4bb6` and Univer `6ae8eb3` under
  `.research-clones/work/`; those folders are absent from this checkout.
- A read-only recovery check found no IronCalc/Univer directories in the
  accessible common local locations and no mounted external volume. This does
  not claim that no backup exists elsewhere.
- Official recovery sources have been recorded in the MAS canon:
  `https://github.com/ironcalc/IronCalc` and
  `https://github.com/dream-num/univer`.

### Hard constraints and next action

- IronCalc is now the canonically selected free-V1 front end and sole calc
  authority. The old silent-Univer-screen decision is superseded.
- Do not fetch, install, wire, or build either dependency until source pins,
  licenses, notices, content digests, package-size impact, build scripts, and
  the isolated MAS WebView proof plan are recorded.
- Continue the independently scoped free-V1 chat/AI presentation audit while
  the missing source recovery remains open; do not substitute a different grid.

## Free V1 Workspace History Presentation Audit — 2026-07-13

### Exact owner intent carried into this slice

> there should eb no chats no ai other than kokoro

> i want the v1 free version will have no ai at all.

### Grounded finding and interpreted intent

The live Workspace Switcher is mounted by both the root shortcut and landing
command palette. It rendered durable `SDWorkspace.summary` text as an “AI
summary” and rendered stored chat/message drift counts. The live Time Machine
also rendered historical summary text and reconstructed stored chats even
though its current view did not render the chat collection. These are active
free-V1 workspace paths, unlike the unmounted `SessionIntelligenceOverlay`,
which remains paid-source retention with no current instantiation.

### Hard constraints and acceptance checks

- Keep workspace snapshots, EventStore history, user notes, note drift, graph
  drift, and future paid source/data intact.
- In free V1, render no stored AI summary or chat activity in Workspace
  Switcher, landing greetings, or Time Machine.
- Time Machine must not reconstruct chat records or calculate chat deltas in
  free V1; it can retain the source for the future paid edition.
- Add the active App Store contract before source edits. Do not make a
  visual/runtime claim until the next one-current-artifact evidence leg.

### Non-goals and exact next action

- Do not delete snapshots, events, summaries, chats, or the retained paid
  Session Intelligence source.
- Do not alter note/graph workspace behavior, Time Machine restoration, or
  external source recovery.
- Add a policy contract, then make only the workspace/Time-Machine presentation
  projection fail closed; re-read the diff before the next build.

### Implemented workspace-history projection before verification

- Added one policy function that turns stored AI output into empty presentation
  text in free V1, while retaining the original stored string.
- Applied it to saved-workspace rows and landing greeting insights; user notes,
  snapshot summaries, notes, and graph state remain available through their
  existing deterministic paths.
- Added a policy-owned chat-activity projection to workspace drift. In free
  V1, a chat-only diff no longer renders an empty “Changes since save” block or
  any chat/message count; note and graph drift still render.
- Time Machine now hides historical summaries and does not query/reconstruct
  stored chats or calculate chat deltas in free V1. It retains the source and
  raw history for a future paid edition.
- `SessionIntelligenceOverlay.swift` was traced separately and has no current
  instantiation. Existing source guards keep it out of the active root and
  landing surfaces, so it remains retained paid-source material rather than a
  free-V1 change target.

### Exact build and focused-run evidence

- Rebuild preflight passed on `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`, with 42 dirty entries, 536.38
  MB swap used, 67% free memory, zero throttled pages, 747 GiB free disk, and
  no competing Xcode/compiler/Epistemos/model process.
- The first replacement build exposed a source compile error in the preexisting
  Welcome Back projection edit: its guarded computed getter lacked an explicit
  `return`. The exact one-line correction was made; no unrelated source was
  changed. The incomplete app was removed before rebuilding.
- The corrected `build-for-testing` created the sole current product at
  `/tmp/Epistemos-FreeV1-Graph-TDD/Build/Products/Debug/Epistemos.app`, with
  embedded `EpistemosAppStoreKeelstoneTests.xctest`. Local ad-hoc deep/strict
  signature verification passed. The app executable SHA-256 is
  `abb4e36e32a620cab43dcf936a807666bd484095d185baf5e41a989e7630d78b`.
- The current focused runner was attempted only for
  `FreeV1ProductCapabilityPolicyTests`. Its result bundle
  `/tmp/Epistemos-FreeV1-Graph-TDD-result.xcresult` reports result `Failed`,
  total test count 1, zero passed tests, and one system failure:
  `Epistemos (85626) encountered an error` / early unexpected bootstrap exit
  before establishing the test connection. No named test body ran. No archive,
  app launch, model, provider, secret, or audio runtime action occurred.

### Verification debt and exact next action

- Preserve this one current temporary app/result. Do not re-run the identical
  focused runner without a new test-host diagnosis or a meaningful changed
  test-host condition.
- The workspace-history source guards and compile output are evidence of source
  integration only, not visual or runtime proof. The next free-V1 stale-surface
  audit must read the active call sites and add its own narrow contract before
  any later replacement build.

## Free V1 Workspace-Summary Admission Audit — 2026-07-13

### Exact owner intent carried into this slice

> i want the v1 free version will have no ai at all.

> there should eb no chats no ai other than kokoro

### Grounded finding and interpreted intent

`AppBootstrap` already declines to start the automatic workspace-summary loop
or launch-time summary refresh when `generativeActions` is unavailable. The
active General settings surface nevertheless exposes a `Workspace Summaries`
section, an interval picker, and an AI-generated-summary/launch-refresh
control. `WorkspaceSummaryService` itself also accepts a direct invocation
without independently checking the edition. This leaves a visible free-V1 AI
configuration surface and an avoidable accidental-call seam.

### Hard constraints and acceptance checks

- Free V1 must show neither a Workspace Summaries settings section nor any
  AI-generated summary or Welcome Back model-refresh control.
- Keep saved workspaces, deterministic session restore, retention controls,
  existing stored summaries, and all future paid source/data intact.
- Add a focused App Store source contract before production changes, then make
  `WorkspaceSummaryService` fail closed before it schedules or invokes
  TriageService generation. Do not alter deterministic workspace persistence
  or the paid-edition behavior.
- Retain the current sole temporary artifact until a later meaningful evidence
  batch reaches the required preflight; do not rebuild merely to retry the
  known unchanged test-host bootstrap failure.

### Non-goals

- Do not remove the generic General settings route or settings search.
- Do not launch, archive, access a model/provider/secret, or begin RECKONER
  source acquisition.

### Scope correction before implementation

The target-file re-read found that the adjacent `Live Notes` section is also
visibly labelled as an AI feature and offers an AI-refresh switch. Its runtime
already stops in free V1, but visible configuration is itself a product-surface
leak. It is therefore included in this same narrowly bounded General-settings
correction: hide the entire Live Notes section behind the same
`generativeActions` policy and extend the focused source contract. This does
not broaden into changing its scheduler, data, or paid behavior.

### Exact next action

- Add the focused source contract, then gate only the visible summary and Live
  Notes controls plus direct summary-service entry points. Re-read the
  resulting diff, run source guards and formatting/diff checks, and record
  test-host/manual verification debt before any later one-artifact replacement
  build.

## Free V1 Inference and Agent Artifact Boundary — 2026-07-13

### Exact owner intent carried into this slice

> i want the v1 free version will have no ai at all.

> browser, research hub both are needing to be on paid version as well an
> hidden from v1 releawe s plaae ad that to that part.

### Current exact artifact evidence

The fresh, single App Store Debug `build-for-testing` artifact compiled the
new settings/service contract and passed local deep/strict ad-hoc signature
verification, but its framework directory contains `llama.framework`,
`libagent_core.dylib`, and `libomega_mcp.dylib`. Its
`Epistemos.debug.dylib` directly links all three. This is not an inert-source
question: a free-V1 host cannot be called an AI-free artifact while those
libraries are embedded and loader-visible.

The project confirms the cause: both free-V1 configurations link
`-lagent_core` and `-lomega_mcp`, expose their Swift FFI module paths, build
both Rust libraries unconditionally, and link the `EpistemosLlama` package.
The nominal `Scrub Pro Frameworks` build phase contains only its shell setup,
so it currently removes nothing. Removing the files after linking would make
the host unloadable and is explicitly not an acceptable fix.

### Interpreted intent, hard constraints, and done bar

- Preserve all paid June/agent/local-model source and package provenance in the
  repository, but make the active free-V1 product neither build, link, nor
  embed the local inference, `agent_core`, or `omega_mcp` runtime libraries.
- Keep Kokoro voice and the deterministic free workspace intact. Do not
  substitute a generic model runtime, fetch a model, access a provider/secret,
  launch the app, or delete retained paid source.
- Use existing `#if canImport(...)` fallback paths where they already provide
  an honest no-runtime implementation. Make the free local-GGUF backend
  unavailable at compile time rather than merely inactive at runtime.
- The first corrected artifact must have no loader reference or embedded file
  for `llama.framework`, `libagent_core.dylib`, or `libomega_mcp.dylib`, while
  keeping the needed graph/search/deterministic libraries. The artifact gate
  must enforce that absence before any host launch or runtime claim.

### Verification plan and exact next action

- Add active free-V1 artifact assertions before build-setting/source edits.
- Trace target package, linker, module-path, and build-script ownership; make
  the smallest free-target-only configuration change that permits existing
  fallback code to compile.
- Re-read the project/build-script diff, run source guards, then—only after a
  new safety preflight—replace the current temporary product with one fresh
  build and inspect linkage/framework contents before attempting the test host.

### Implemented source boundary before fresh artifact verification

- The free App Store Debug and Release target configurations no longer link
  `-lagent_core` or `-lomega_mcp`, expose their FFI include paths, or depend on
  the `EpistemosLlama` package product. The retained local package declaration
  is provenance for a future paid edition; it is no longer a free-target
  dependency.
- The authoritative `project.yml` now carries the same free-only link, module,
  package, build-script, and test-host settings as the generated Xcode project.
  A later project regeneration cannot reintroduce the removed paid linkage.
- The free App Store test target now also compiles with `EPISTEMOS_FREE_V1` and
  has only the deterministic `epistemos_coreFFI` include path. Its own sources
  do not directly import the removed agent or omega interfaces.
- `Build Rust Engine` builds `omega_mcp`, `agent_core`, and JuneWeb only for a
  non-free edition. `Scrub Pro Frameworks` is now an honest fail-closed
  assertion: it fails a free build that embeds `llama.framework`,
  `libagent_core.dylib`, or `libomega_mcp.dylib` rather than deleting a linked
  dependency after the fact.
- `LocalGGUFQuickChatBackend` compiles its local-llama import and engine only
  outside `EPISTEMOS_FREE_V1`; its free-build availability is false. The
  artifact contract and KEELSTONE release gate now check framework absence and
  executable linkage absence for the same three paid runtimes.
- Static evidence only: `git diff --check`, YAML parsing of `project.yml`, and
  `bash -n` of the release gate pass. The current temporary artifact predates
  these changes and remains red for the forbidden runtime files; no fresh
  host/test result has been claimed.
- The owner correction that IronCalc actual source is the RECKONER front end
  remains active and unchanged. This artifact-boundary slice does not fetch,
  install, wire, or substitute any IronCalc/Univer source.

### Verification debt and exact next action

- Re-record branch, HEAD, dirty count, swap, memory pressure, VM statistics,
  free disk, and competing Xcode/compiler/model/Epistemos processes. Proceed
  only if the stated owner thresholds pass.
- If they pass, stop any remaining Epistemos test host; remove the one stale
  `/tmp/Epistemos-FreeV1-Graph-TDD` product and its paired result bundle; run
  one fresh App Store `build-for-testing` in that same derived-data location.
  Do not archive or launch the app.
- Inspect that one artifact's framework list, `otool -L` output, code
  signature, release gate, and bundle scan before attempting the two narrow
  free-V1 test contracts. If compilation or an artifact gate fails, record the
  named failure and make only its minimal correction before another preflighted
  replacement build.

### First fresh-build attempt — environment signing stop

- Preflight passed on `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 49 dirty entries, 519.25 MB
  swap used, 67% free memory, zero throttled pages, 747 GiB free disk, and no
  active Epistemos, Xcode, compiler, or model job. The two persistent
  `MTLCompilerService` processes were idle system services at 0% CPU, not
  active build work.
- The prior temporary derived-data product and result bundle were removed
  before the one attempted replacement `build-for-testing` command.
- That command stopped at Xcode provisioning setup, before source compilation,
  build scripts, app creation, archive, app launch, model/provider/secret
  access, or audio work: `No profiles for 'com.epistemos.appstore' were found`.
  No provisioning update, Apple credential, password, or signing request was
  made.
- This is not a source or artifact failure. The next attempt must use the
  existing test-only local invocation with `CODE_SIGNING_ALLOWED=NO`; it still
  requires a new resource preflight and removal of the incomplete derived-data
  directory first. Do not infer any test result from this stopped build.

### Second fresh-build attempt — generated paid-binding compile stop

- A newly preflighted, locally unsigned `build-for-testing` ran through the
  free target's deterministic Rust/editor bundle phases without invoking a
  profile, Apple credential, provider, model, app launch, archive, or audio
  runtime. The resolved package graph still lists the retained local
  `EpistemosLlama` package record, but the App Store target dependency graph
  no longer lists it as a target dependency.
- The build stopped during Swift compilation before a valid app artifact or
  test result: the synchronized `build-rust/swift-bindings` folder still swept
  the pre-existing paid `agent_core.swift` generated binding into the free app.
  Its generated `ToolConfig` conflicted with the free fallback `ToolConfig` in
  `StreamingDelegate.swift`. This is direct evidence that removing a linker
  path alone does not remove source-folder membership.
- The incomplete temporary app/test bundle is not a valid artifact and has not
  been inspected as a pass or used to run tests.
- The narrow correction changes the authoritative source-folder allowlist from
  `*.swift` to `epistemos_core.swift` only and adds `agent_core.swift` plus
  `omega_mcp.swift` to the generated Xcode synchronized-folder membership
  exceptions. No generated paid binding was edited or deleted.
- Source guard coverage now requires that allowlist and both exclusions.
  A temporary XcodeGen generation from the corrected `project.yml` produced
  the same two membership exclusions and the same free-only linker/module
  settings as the checked-in project. `git diff --check`, YAML parsing, and
  release-gate shell syntax remain clean.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  this incomplete temporary derived-data product and retry exactly one local
  unsigned `build-for-testing` with `CODE_SIGNING_ALLOWED=NO`. Do not archive,
  launch, sign with Apple, enable provisioning updates, fetch a model, or run
  a test host before the rebuilt artifact passes its static absence gates.

### Third fresh-build attempt — retained direct agent-bridge compile stop

- A newly preflighted, locally unsigned `build-for-testing` confirmed that the
  `ToolConfig` collision was resolved, then stopped during Swift compilation
  before a valid artifact or test result. Four retained paid-source call sites
  still referenced generated `agent_coreFFI` symbols that are correctly absent
  from the free target: `listSessionFolders`, `readSessionMetadata`,
  `proposeSkillMutation`, and `vaultRecallTraceJson`.
- The incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` product is not valid
  evidence and must be removed before the next replacement build. No archive,
  app launch, Apple signing/provisioning update, provider/model/secret access,
  or audio runtime action occurred.
- The narrow correction preserves all paid implementations and adds a focused
  App Store source contract first. `SessionBrowser` and `SkillEvolutionService`
  now deny free-V1 `agentAutomation` before their binding boundary and compile
  their existing paid calls only when `agent_coreFFI` is importable.
  `VaultRecallBridge` denies the paid `researchHub` capability in free V1 and
  likewise compiles its Rust fallback only when that binding is present. The
  free fallback returns an empty/`nil` result rather than attempting a hidden
  runtime.
- Static re-read of all four changed regions completed. `git diff --check`,
  release-gate shell parsing, and `project.yml` YAML parsing pass. The new
  source contract asserts the fail-closed policy and conditional-binding shape;
  it has not yet been executed in a test host.

### Exact next action

- Run the complete owner resource/process preflight again. If it passes, stop
  only any orphaned Epistemos build helper left by the failed build, remove the
  incomplete temporary derived-data product and paired result bundle, and run
  exactly one locally unsigned App Store `build-for-testing` with
  `CODE_SIGNING_ALLOWED=NO`. Do not archive, launch, sign, enable provisioning,
  access a model/provider/secret, or run a test host before the resulting
  artifact passes the static paid-runtime absence gates.

### Fourth fresh-build attempt — retained local-package resolution stop

- The preflight passed at `668b52cfb43721de95db102260d9f327ae24e13e` with
  52 dirty entries, 503.25 MB swap used, 66% free memory, zero throttled
  pages, 748 GiB free disk, and no competing Xcode/compiler/model/Epistemos
  work. The only observed active processes were normal desktop/Codex services.
- After removing the prior incomplete derived-data and result locations, the
  single locally unsigned `build-for-testing` stopped before source compilation
  or app creation. Xcode reported: `Could not resolve package dependencies`
  because binary target `llama` could not be mapped to its expected artifact.
  The fresh temporary directory contains only package-resolution/log material,
  not a valid app or test result.
- This was not a request to fetch, repair, or activate the local Llama binary;
  that would contradict the free-V1 no-AI boundary and the owner's no-model
  instruction. The cause is narrower: Xcode resolves every top-level local
  package in the project even if no free target depends on its product.
- A source guard was added first. The authoritative `project.yml` and the
  generated project now unregister `LocalPackages/EpistemosLlama` entirely
  from the active project graph while preserving the full paid-only source
  folder on disk. The guard rejects any reintroduced local-package reference
  or product dependency. The manifest documents why this is required for a
  free-V1 build. Static diff, YAML, and shell checks pass, and a temporary
  XcodeGen projection contains no Llama package reference.

### Exact next action

- Run the full owner resource/process preflight again. If it passes, delete
  only the failed package-resolution derived-data directory and run exactly one
  locally unsigned App Store `build-for-testing` with `CODE_SIGNING_ALLOWED=NO`.
  Do not archive, launch, sign, provision, fetch/repair a model binary, access
  provider/secret data, or run a test host before a new app artifact passes the
  paid-runtime absence gates.

### Fifth fresh-build attempt — test-build artifact gate stop

- After the preflight passed again (495.25 MB swap, 66% free memory, zero
  throttled pages, 749 GiB disk, no competing build/runtime process), one
  locally unsigned App Store `build-for-testing` completed successfully. The
  retained paid-only `LocalPackages/EpistemosLlama` source remains present on
  disk and was not fetched, repaired, or registered in the free project graph.
- The resulting test-build bundle omits `llama.framework`,
  `libagent_core.dylib`, and `libomega_mcp.dylib`, which is positive framework
  absence evidence. However, its Info.plist declares `CFBundleExecutable`
  `Epistemos` while `Contents/MacOS/Epistemos` is absent; the bundle contains
  only `__preview.dylib` in that directory. There is therefore no host
  executable on which to perform the mandatory linkage inspection. This is a
  red artifact gate, not a successful app artifact or a permission to run the
  test host.
- The project still reports the expected standalone application build settings:
  `EXECUTABLE_PATH=Epistemos.app/Contents/MacOS/Epistemos`, executable Mach-O
  type, and `SKIP_INSTALL=NO`. The discrepancy is specific to this
  `build-for-testing` output shape, so no source or build-setting correction is
  justified yet.

### Exact next action

- After another complete owner resource/process preflight, delete only this
  invalid test-build derived-data directory and run exactly one locally unsigned
  standalone App Store `build` in the same location. It must produce the
  declared app executable before any framework/linkage, scanner, or test-host
  gate can proceed. Do not archive, launch, sign, provision, fetch/repair a
  model binary, access provider/secret data, or run a test host.

### Sixth fresh-build attempt — standalone artifact gate stop

- The next preflight passed with 495.25 MB swap, 65% free memory, zero
  throttled pages, 748 GiB disk, and no active competing build/runtime job
  after the single orphaned `ibtoold` helper from the prior attempt was stopped.
  The same free-V1 source/static checks remained clean.
- One locally unsigned standalone `build` was then attempted after deleting
  the invalid test-build directory. Its resulting wrapper again declares
  `CFBundleExecutable=Epistemos` but contains only `__preview.dylib` under
  `Contents/MacOS`; the required `Epistemos` Mach-O is absent. Two idle
  orphaned `ibtoold` helpers left by that attempt were stopped. No app/test was
  launched and no signing, provisioning, model, provider, secret, or audio
  action occurred.
- The bundle continues to omit the three paid runtime files, but without the
  actual executable no linkage, code-signature, full scanner, or test-host
  claim is valid. `xcodebuild -list` now resolves the free project graph with
  only GRDB, Grape, KokoroPipeline, and MarkEdit packages, confirming that the
  retained Llama package is no longer the current resolver blocker.

### Exact next action

- Re-run the full resource/process preflight. If it passes, remove only the
  invalid standalone derived-data directory and repeat exactly one standalone
  unsigned App Store `build` with non-quiet, error-filtered output and an
  explicit captured exit status. This is an evidence-collection correction,
  not a source change. Do not proceed to scanner/test host unless it creates
  the declared executable.

### Seventh fresh-build attempt — nonpersistent command-capture invalid

- The seventh attempt used the same standalone unsigned build command with
  filtered console output. The command runner returned before Xcode's child
  compiler processes finished; direct process inspection then showed the one
  active `xcodebuild` and Swift frontend set still compiling. No second build
  was started while they ran.
- When those child processes later exited, the retained wrapper still lacked
  `Contents/MacOS/Epistemos`; its build activity log was zero bytes and could
  not provide a terminal result (`unexpected end of file`). This is not valid
  pass or fail evidence for production source: the nonpersistent command
  capture did not preserve Xcode's final status or diagnostics.
- The only durable artifact fact remains red: there is no declared app
  executable. The paid framework absence remains positive but insufficient.

### Exact next action

- After a full resource/process preflight and stale-artifact removal, run
  exactly one standalone unsigned App Store `build` through a persistent
  terminal session, wait for its true exit, and retain its final diagnostics.
  Do not edit source, run a scanner, or start a test host before that command
  yields a valid `Contents/MacOS/Epistemos` binary.

### Eighth fresh-build attempt — paid MCP bridge compile stop and correction

- The persistent terminal evidence run is the first build command in this
  slice with a trustworthy final result: it exited `65` during Swift
  compilation, after deterministic Rust/editor asset phases completed. The
  exact source blocker was `Epistemos/Omega/MCPBridge.swift`: retained paid
  references to `McpDispatcher` and `builtinToolsJson` were unavailable after
  the free target correctly excluded `omega_mcp.swift` and `omega_mcpFFI`.
  No app executable, archive, test-host run, app launch, signing/provisioning,
  model/provider/secret action, or audio runtime action occurred.
- The focused source contract now covers this retained bridge before its
  implementation change. `OmegaToolRegistry` reads its Rust catalog only when
  `omega_mcpFFI` is importable and the paid `agentAutomation` capability is
  available; otherwise it produces an empty catalog. `MCPBridge` conditionally
  declares/uses its Rust dispatcher, opens no execution database in free V1,
  reports zero counts, performs no logging, returns no execution history, and
  fails direct dispatch with a bounded unavailable response. The paid source
  implementation remains intact behind the conditional boundary.
- Static re-read, diff whitespace check, release-gate shell parse, and project
  YAML parse pass. The source contract has not yet executed because no valid
  artifact/test host exists.

### Exact next action

- Re-run the full owner resource/process preflight. If it passes, remove only
  the incomplete derived-data product and run exactly one persistent-session
  standalone unsigned App Store `build`. Do not archive, launch, sign,
  provision, fetch/repair a model binary, access provider/secret data, or run
  a test host before a valid app executable passes the static absence gates.

## Checkpoint 2026-07-13 Free-V1 Boundary And RECKONER Source Correction

### Verbatim owner excerpts

> "no the pla was to use the actual clone of the iron calc univer etc. but iron calc as the fromt end why was that taken off"

> "I want to start building ... browser, research hub both are needing to be on paid version as well an hidden from v1 release"

### Interpreted intent

Keep the actual IronCalc and Univer source-clone plan for RECKONER. IronCalc is
the free-V1 visible front end and sole spreadsheet/formula authority; Univer is
a required bounded supporting source, never a silent second engine. Continue
the current free-V1 build evidence chain without restoring any paid agent or
local model runtime. Browser and Research Hub stay paid-only and hidden/inert
in the free V1 product.

### Hard constraints

- Do not fetch, install, wire, or substitute IronCalc/Univer source until its
  pin, license, notice, digest, package-size, and MAS WebView proof gate is
  prepared; neither source is currently cloned in this checkout.
- Free V1 contains no chat/generative AI. Retain Kokoro local read-aloud only.
- Preserve paid source and user data; hide/deny paid paths rather than delete
  them.
- Before every build/test/archive, remove only stale active-leg Epistemos
  products and archives, retain one current artifact, and record its identity.
- No archive, launch, signing/provisioning, model/provider/secret access,
  StoreKit/payment, or audio runtime action in this evidence leg.

### Proven state and active verification debt

- Canon now records both actual IronCalc and Univer source clones as required
  RECKONER inputs, with IronCalc as the future front end and formula authority.
  This is a plan correction, not an installed dependency or runtime claim.
- The free target excludes paid agent/omega/llama linkage and bindings, but no
  valid fresh executable exists yet. Tests and artifact gates remain deferred.
- Ninth persistent build stopped at three direct `agent_coreFFI` resource
  gateway symbols in `SDPage`; the same paid resource service is initialized
  by `AppBootstrap`. The existing free path already reads a normal vault file
  first, then legacy storage, so the correct narrow action is conditional
  compilation of only the paid resolver and initializer.

### Next smallest safe action

Add a source contract for the resource-service conditional boundaries, then
guard the existing `SDPage` resolver and `AppBootstrap` initializer behind
`canImport(agent_coreFFI)`. Re-read the changed regions and run static source
checks. Only then run another full resource preflight and one replacement
persistent unsigned build.

### Tenth fresh-build attempt — resource gateway corrected; chat attachment bridge stop

- The owner resource/process preflight passed at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 55 dirty entries, 1,003 MB
  swap used, 66% free memory, zero throttled pages, 747 GiB free disk, and no
  active Epistemos, Xcode, compiler, or model work. The matching macOS model
  catalog daemons were idle system services at 0% CPU.
- The sole stale `/tmp/Epistemos-FreeV1-Graph-TDD` directory was removed before
  the one persistent, locally unsigned Debug build. The run reached the app
  Swift compilation and exited `65`; it did not create a valid executable or
  authorize a test, archive, launch, signing/provisioning, model/provider/
  secret, payment, or audio-runtime action.
- This run proves the prior direct `resourceServiceIsReady`, `resourceResolve`,
  `resourceRead`, and `resourceServiceInit` failures no longer stop
  compilation. Its next exact error was
  `Epistemos/Models/ChatTypes.swift`: `AttachedResource`,
  `attachedResourceFromUi`, and `attachedResourceFromPaste` are paid
  `agent_coreFFI` symbols absent from the free target.
- A focused source contract was added before the correction. The existing
  `ContextAttachment` persisted metadata remains available in free V1, while
  only `toAttachedResource()` and its direct paid factories now compile when
  `agent_coreFFI` is importable. No call site in the free source directly calls
  that converter. This preserves the paid implementation without restoring the
  excluded binding.
- Re-read of the changed source and contract completed. `git diff --check`,
  the release-gate shell parse, and `project.yml` YAML parse pass. These are
  static checks only; the focused source contract has not run in a test host.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, stop
  only any orphaned Epistemos build helper left by the failed build, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory, and run one
  persistent locally unsigned App Store Debug `build`. Do not archive, launch,
  sign, provision, fetch/repair a model, access provider/secret/payment data,
  or run a test host until a fresh executable passes the static absence gates.

### Eleventh fresh-build attempt — chat attachment corrected; Eidos agent bridge stop

- A new resource/process preflight passed at the same branch and HEAD with 56
  dirty entries, 1,003 MB swap used, 65% free memory, zero throttled pages,
  747 GiB free disk, and no active Epistemos/Xcode/compiler/model job. There
  were no orphaned build helpers to stop.
- The incomplete temporary product was removed before one persistent locally
  unsigned Debug build. The run exited `65` during app Swift compilation,
  before a valid executable, test, archive, launch, signing/provisioning,
  model/provider/secret/payment, or audio-runtime action.
- This build proves the `ChatTypes` paid attachment symbols no longer stop the
  free target. The next exact diagnostics were in `EidosBridge` and
  `EidosWiring`: `eidosOpenVaultIndex`, `eidosVaultIndexInsertNote`,
  `eidosRetrieveJson`, citation validation/status/close functions, and
  `eidosSearchLexicalJson` are all retained `agent_coreFFI` symbols unavailable
  by design in free V1.
- The correction keeps the public Eidos API so existing free graph/search call
  sites still compile, but compiles the real vault/citation/search bridge only
  when `agent_coreFFI` exists. The free fallback returns unavailable (`nil`,
  `false`, or bounded bridge failure), allowing the regular search index to
  continue through its existing fallback path. App startup now skips Eidos
  production-index initialization entirely without the paid binding.
- Re-read of the two Eidos surfaces, their call sites, AppBootstrap seam, and
  the expanded source contract completed. `git diff --check`, release-gate
  shell parsing, and `project.yml` YAML parsing pass. No runtime or test-host
  behavior is claimed.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory and run one
  persistent locally unsigned App Store Debug build. Do not archive, launch,
  sign, provision, fetch/repair a model, access provider/secret/payment data,
  or run a test host until a fresh executable passes the static absence gates.

### Twelfth fresh-build attempt — diagnostics FFI boundary stop and correction

- The persistent, locally unsigned free-V1 Debug build exited `65` during app
  Swift compilation. It reached the existing `EngineLogDiagnostics` source
  after the deterministic Rust/editor asset phases, but no valid executable,
  test, archive, launch, signing/provisioning, model/provider/secret/payment,
  or audio-runtime action occurred.
- The exact diagnostic was `cannot find type 'AgentErrorFfi' in scope` at
  `Epistemos/Engine/EngineLogDiagnostics.swift`. The type belongs to the
  excluded paid `agent_coreFFI` binding. Its extraction branch is now compiled
  only when that binding is available; free V1 returns no FFI detail and keeps
  the safe non-FFI callback redaction path. The retained paid diagnostic path
  remains intact.
- The corresponding Keelstone test now compiles its `AgentErrorFfi` examples
  only when the paid binding exists, while still checking callback redaction in
  free V1. The free retained-bridge source contract now requires the new
  conditional boundary.
- Owner correction recorded in both the external master canon (the execution
  authority) and its repository recovery mirror: recover both actual IronCalc
  and Univer source clones; IronCalc is the RECKONER visible front end and sole
  calculation authority, while Univer remains a required bounded supporting
  source and cannot displace it or create a second engine.
- `swiftc -parse` on the changed diagnostics source, `git diff --check`,
  source-guard searches, and byte comparison of the two changed canon files
  between the external authority and repository mirror pass. These are static
  checks only; no test host or runtime behavior is claimed.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory and run one
  persistent locally unsigned App Store Debug build. Do not archive, launch,
  sign, provision, fetch/repair a model, access provider/secret/payment data,
  or run a test host until a fresh executable passes the static absence gates.

### Thirteenth fresh-build attempt — Lattice/WBO paid diagnostics stop and correction

- The full owner resource/process preflight passed at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 59 dirty entries, 1,373.75 MB
  swap used, 66% free memory, zero throttled pages, 747 GiB free disk, and no
  active Epistemos/Xcode/compiler/model workload. Idle macOS model catalog and
  Metal service processes were present at 0% CPU only.
- After removal of only the incomplete temporary derived-data directory, one
  persistent locally unsigned free-V1 Debug build exited `65` during app Swift
  compilation. It cleared the prior `AgentErrorFfi` diagnostics boundary. No
  valid executable, test, archive, launch, signing/provisioning,
  model/provider/secret/payment, or audio-runtime action occurred.
- The exact next error was in `LatticeWBOWiring`: the retained paid diagnostic
  snapshot called `oplogLatticeWboStatsJson`, an `agent_coreFFI` symbol absent
  from the free target. The focused source contract now covers that boundary;
  the live paid read/JSON decode remains under `canImport(agent_coreFFI)`, and
  free V1 returns no paid snapshot so the existing health-row fallback remains
  responsible for presentation.
- Re-read of the bridge and source contract completed. `swiftc -parse` on the
  changed Swift file and `git diff --check` pass. These are static checks only;
  no test-host or runtime behavior is claimed.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory and run one
  persistent locally unsigned App Store Debug build. Do not archive, launch,
  sign, provision, fetch/repair a model, access provider/secret/payment data,
  or run a test host until a fresh executable passes the static absence gates.

### Fourteenth fresh-build attempt — F-ULP and Goose paid-bridge correction

- The full owner resource/process preflight passed at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 60 dirty entries, 1,373.81 MB
  swap used, 66% free memory, zero throttled pages, 747 GiB free disk, and no
  active Epistemos, Xcode, compiler, or model workload. Idle macOS model
  catalog and Metal service processes were present at 0% CPU only.
- After removal of only the incomplete temporary derived-data directory, one
  persistent locally unsigned free-V1 Debug build exited `65` during app Swift
  compilation. It cleared the prior Lattice/WBO paid diagnostic boundary. No
  valid executable, test, archive, launch, signing/provisioning,
  model/provider/secret/payment, or audio-runtime action occurred.
- The exact next diagnostics were: `FUlpWiring` called the excluded
  `fulpOracleAcceptanceWitnessJson` binding, and
  `GooseMASAgentCoreRunner` retained a free-target cancellation call in the
  paid agent path. Both are paid-agent/research paths and must not remain live
  in Free V1.
- A focused source contract was added first. `FUlpBridge.run()` now compiles
  its real FFI work only when `agent_coreFFI` exists; Free V1 records a bounded
  unavailable diagnostic and returns `nil`. The Goose runner now finishes its
  stream with the existing bindings-unavailable error before constructing any
  paid tool/session configuration when that binding is excluded. The paid
  implementation remains unchanged behind its conditional compilation branch.
- Re-read of both bridge regions and the expanded Keelstone source contract
  completed. `swiftc -parse` for each changed bridge under the Free V1 define
  and `git diff --check` pass. These are static checks only; the source
  contract has not run in a test host and no runtime behavior is claimed.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory and run one
  persistent locally unsigned App Store Debug build. Do not archive, launch,
  sign, provision, fetch/repair a model, access provider/secret/payment data,
  or run a test host until a fresh executable passes the static absence gates.

### Fifteenth fresh-build attempt — ACS, memory-relief, and permission-store paid binding correction

- The full owner resource/process preflight passed at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 62 dirty entries, 1,365.81 MB
  swap used, 66% free memory, zero throttled pages, 747 GiB free disk, and no
  active Epistemos, Xcode, compiler, or model workload. Idle macOS model
  catalog and Metal service processes were present at 0% CPU only.
- Only the incomplete temporary derived-data directory and its matching result
  bundle were removed before one persistent locally unsigned free-V1 Debug
  build. It exited `65` during app Swift compilation, cleared the prior F-ULP
  and Goose paid-bridge boundary, and produced no valid app executable. No
  test, archive, launch, signing/provisioning, model/provider/secret/payment,
  or audio-runtime action occurred.
- The exact next diagnostics were direct excluded `agent_coreFFI` calls:
  `acsAdmissionStrictPolicySummaryJson` in `ACSAdmissionWiring`,
  `respondToMemoryPressure` in `EpistemosApp` and `AppBootstrap`, and
  `permissionStoreInitAtPath` in `AppBootstrap`.
- A focused source contract and ACS cross-configuration test expectations were
  added before the correction. The ACS diagnostic now records bounded
  unavailable state and returns `nil` in Free V1. Free V1 retains only its
  existing Swift-side search-cache cleanup and reports zero paid Rust relief in
  its diagnostics. The paid permission-store initializer is not compiled in
  Free V1. Paid behavior remains intact under `canImport(agent_coreFFI)`.
- Re-read of each changed region and contract completed. `swiftc -parse` with
  the project Swift mode for all five changed Swift files and `git diff --check`
  pass. These are static checks only; no test host or runtime behavior is
  claimed.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory and run one
  persistent locally unsigned App Store Debug build. Do not archive, launch,
  sign, provision, fetch/repair a model, access provider/secret/payment data,
  or run a test host until a fresh executable passes the static absence gates.

### Sixteenth fresh-build attempt — excluded agent-core C-ABI link-boundary correction

- The full owner resource/process preflight passed at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 65 dirty entries, 1,589.25 MB
  swap used, 67% free memory, zero throttled pages, 746 GiB free disk, and no
  active Epistemos, Xcode, compiler, or model workload. Idle macOS model
  catalog and Metal service processes were present at 0% CPU only.
- Only the incomplete temporary derived-data directory and its matching result
  bundle were removed before one persistent locally unsigned free-V1 Debug
  build. It compiled the app Swift sources, then exited `65` at link. No valid
  app executable, test, archive, launch, signing/provisioning,
  model/provider/secret/payment, or audio-runtime action occurred.
- The exact unresolved C symbols were ETL queue, grammar matcher, OpLog, and
  rope-handle exports. Current symbol inspection placed those exports in the
  deliberately excluded `build-rust/appstore/libagent_core.dylib`, not in the
  retained core or shadow libraries. Restoring or linking `agent_core` would
  violate the Free V1 no-agent/no-generative-AI boundary, so it was not done.
- A source contract was extended before the correction. In Free V1, the ETL,
  grammar, OpLog, and rope direct C-ABI declarations now compile to bounded
  unavailable stubs only; their paid declarations remain under
  `canImport(agent_coreFFI)`. App bootstrap still creates the retained event
  store, but creates the paid mutation-OpLog projection worker only when that
  paid binding is present. Two stale comments claiming unconditional
  `agent_core` linkage were corrected so the source describes the current
  product boundary accurately.
- Re-read of every changed bridge and source contract completed. `swiftc -parse`
  in the project Swift mode for the five production files and the source test,
  plus `git diff --check`, pass. These are static checks only; no test host or
  runtime behavior is claimed.

### Exact next action

- Re-run the complete owner resource/process preflight. If it passes, remove
  only the incomplete `/tmp/Epistemos-FreeV1-Graph-TDD` directory and matching
  result bundle, then run one persistent locally unsigned App Store Debug
  build. Do not archive, launch, sign, provision, fetch/repair a model, access
  provider/secret/payment data, or run a test host until a fresh executable
  passes the static absence gates.

### Seventeenth fresh-build attempt — Free V1 artifact produced; unsigned entitlement gate red

- The full owner resource/process preflight passed at
  `668b52cfb43721de95db102260d9f327ae24e13e`: 69 dirty entries, 1,643.50 MB
  swap used, 68% free memory, zero throttled pages, 746 GiB free disk, and no
  active Epistemos, Xcode, compiler, or model workload. Idle macOS model
  catalog and Metal service processes were present at 0% CPU only.
- Only the prior incomplete temporary derived-data directory and matching result
  bundle were removed. The one persistent, locally unsigned Free V1 Debug build
  succeeded. Its sole current application artifact is
  `/tmp/Epistemos-FreeV1-Graph-TDD/Build/Products/Debug/Epistemos.app`; its
  arm64 executable SHA-256 is
  `d6ac9565b3bb8aa60b20b2cf336c72cdedd132f84297e4d0c58a600dd99d3423`.
  No archive, app launch, test host, signing/provisioning, model/provider/
  secret/payment, or audio-runtime action occurred.
- Direct artifact checks on that exact executable passed: `llama.framework`,
  `libagent_core.dylib`, `libomega_mcp.dylib`, JuneWeb, the model manifest, and
  default agent skills are absent; the executable has no paid inference or
  agent linkage; and no packaged runtime name matches those excluded libraries.
  A first local manual-check attempt was discarded before reliance because a
  shell-local variable name invalidated two later checks; the complete check was
  then rerun cleanly and is the result recorded here.
- `scan_appstore_bundle.sh` passed with no quarantine attributes, prohibited
  runtime strings or symbols, parked account/backend strings, retired-lane or
  1Code strings, or prohibited research/tool resources. The full
  `keelstone-release-gate.sh` passed every source and Free V1 artifact
  exclusion, but returned red for exactly one condition: the intentionally
  unsigned Debug app has no App Sandbox entitlement to inspect. The gate is
  therefore **INCOMPLETE**, not release-ready.
- Build output repeated a compiler warning in unmodified
  `VaultSyncService.swift:4397` that an `await` contains no async operation.
  It is outside the focused Free V1 link-boundary fix and was not changed in
  this evidence leg. It is retained as separate warning debt, not treated as
  proof of runtime behavior.

### Exact next action

- Preserve this one current artifact and stop before any test host or runtime
  launch: the unsigned App Sandbox entitlement gate is red. No signing,
  provisioning, archive, or release action is authorized by this execution
  key. A later explicitly authorized signed-artifact evidence leg must begin
  from a fresh owner resource/process preflight, clear only this temporary
  artifact location, create exactly one current artifact, and rerun the full
  artifact gate before any runtime matrix. Do not begin a new canonical key.

### Eighteenth owner steer — executive continuity, full master-canon update, and Free V1 remediation

**Verbatim owner excerpts**

> updat the acual files in mas canon folder the pne that was in h te restore
> with thr minimal prompt thing i just nee to be able to acccessall thes
> features and ecisions ... i want it in the minimal prompt doc as well just
> everywhere so its part of the canon please.

> there should eb no chats no ai other than kokoro ... i still see chats o the
> grsph whe there shoud not be chats at alll ... settings parts and graph
> filters ... are stale and need to be removed.

> the source surface part of the app i want it to look like teh mark edit ...
> keep my theme palette ... the rigth hand side ... should be the same color as
> the rest of the surface instead of a grey color.

> no the pla was to use the actual clone of the iron calc univer etc. but iron
> calc as the fromt end why was that taken off.

**Interpreted intent**

- The external MAS master-canon folder is the working authority and its
  repository recovery mirror must remain byte-identical. The dated Free V1
  decisions, clone recovery plan, active execution key, and safe resumption
  boundary must be accessible from Read First, thesis, build order, minimal
  prompt, feature plans, and the live registry—not only a transient ledger.
- Continue as one executive session with bounded delegated audits but one edit
  owner per file/build. Preserve the canonical execution key
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`; do not create a competing
  key.
- Free V1 is deterministic: chat, June, general models, agents, generative
  actions, Browser, and ResearchHub are completely hidden/inert; stored paid
  source/data remains preserved. Kokoro local read-aloud is the sole AI-model
  exception.
- RECKONER must use the actual IronCalc and Univer sources, with IronCalc as
  the visible Free V1 front end and sole formula authority. Univer is required
  bounded supporting source, never a second engine or displaced front end.
  The owner does not authorize a generic substitute grid or a fake datasheet
  placeholder.
- The existing vendored MarkEdit source, rather than a new MarkEdit clone, is
  the Source-editor implementation reference. Epistemos retains its palette
  but adopts the requested coherent editor/gutter/right-strip surface,
  non-destructive readable defaults, toolbar-hosted controls, and measured
  editing performance work.
- Epdoc must become a real planner/meeting/task/datasheet workspace over time;
  chat and unfinished sheet controls must disappear from Free V1 until their
  actual deterministic feature slices exist.

**Hard constraints and non-goals**

- Preserve MAS-only boundaries, vault/artifact truth, the one-current-build
  rule, and all paid source/data. Do not access payment, StoreKit, signing,
  provisioning, accounts, providers, secrets, models, audio runtime, private
  Columbia/VA/funding material, or the current app/runtime matrix.
- The sole current unsigned Debug artifact remains preserved; its App Sandbox
  evidence gate is red, so no test host, launch, archive, or runtime claim may
  use it.
- No immediate dependency fetch, product wiring, source replacement, or
  Formula-engine activation. First resolve official source URL, full commit,
  license/notice obligations, ownership boundary, and a quarantined recovery
  clone policy; then perform a no-owner-data MAS packaging spike before any
  project dependency decision.
- Do not copy MarkEdit, Things, NotePlan, Univer, or other product shell/trade
  dress; retain only lawful source/reference motifs under their licenses.

**Acceptance checks**

- Canon contains a single active executive-continuity record, is linked from
  all daily prompt/control docs, records actual clone roles and recovery
  sequence, and is byte-identical between external authority and repo mirror.
- Manifest active-doc list/count/digest match the final canon; canonical
  cross-references and semantic contradiction sweeps pass.
- Next source batch begins with test-first Free V1 graph/notebook/settings
  hiding and MarkEdit surface contracts; it preserves data/paid source and
  records performance/runtime proof as debt until a future signed evidence leg.

**Contradictions/questions**

- The older MAS pivot describes June as active, whereas the dated Free V1
  owner addenda make it future paid and inert. The dated Free V1 canon controls
  this build.
- The old clone gate required a local content digest before acquisition. That
  is circular. Split it into a preflight, quarantined verification clone,
  local digest/license/package spike, and only then a wiring decision.
- Current source evidence says data sheets are not a completed feature. The
  Free V1 UI must hide their stub; real RECKONER remains a later source-backed
  feature phase, not a claim made by the placeholder.

**Exact next action**

- Update the external MAS master canon and byte-identical repository mirror
  with this continuity record and the repaired clone-recovery gate. Then begin
  the test-first P0 Free V1 stale-surface projection batch without rebuilding,
  launching, signing, fetching source dependencies, or starting another
  canonical execution key.

### Nineteenth owner steer — actual RECKONER source checkouts

**Verbatim owner excerpt**

> no the pla was to use the actual clone of the iron calc univer etc. but iron
> calc as the fromt end why was that taken off

**Interpreted intent**

- The real IronCalc and Univer source checkouts are required now as the local
  RECKONER source basis. IronCalc remains the eventual visible Free V1 grid
  front end and the sole calculation/formula authority. Univer remains a
  required bounded supporting source; it must not displace IronCalc or become
  a second active calculation engine.
- This steer supersedes the prior temporary instruction to defer all source
  fetching only as to the two recorded, quarantined upstream checkouts. It does
  not authorize package installation, Xcode target membership, product wiring,
  a build, archive, test host, launch, signing, a runtime claim, owner-data
  access, or any paid/AI capability.

**Hard constraints and acceptance checks**

- Check out only the documented upstream repositories at their exact historical
  full commits into the ignored `.research-clones/work/` quarantine; record
  origin URL, detached commit, license/notice texts, and local digest evidence.
- Keep both checkouts outside shipping sources until a separate isolated
  license/package/MAS-hosting spike succeeds. The first production proposal
  still requires an IronCalc-owned visible grid and single formula authority.
- Preserve the current unsigned KEELSTONE artifact and red entitlement gate;
  do not start another canonical execution key.

**Exact next action**

- Create the two quarantined, pinned source checkouts after the recorded safe
  resource preflight, inspect their license/provenance state without running
  either project, then synchronize their exact status and roles into the
  external MAS canon and repository mirror.

### Nineteenth steer outcome — pinned RECKONER source basis and canon seal

- Safe source-only preflight passed: swap 1,866.12 MB used, 69% system free
  memory, zero throttled pages, 745 GiB available disk, and no competing
  Xcode/compiler/model/Epistemos process. No app build, test host, archive,
  launch, signing, provider, model, secret, payment, or audio operation ran.
- Actual clean detached source checkouts now exist only in ignored
  `.research-clones/work/`: IronCalc at
  `1bd4bb6005ffda4fcb1f287f4d4e7b564e310ddc` and Univer at
  `6ae8eb3ef05c7645ed1425b13358bab1d8155a32`. They remain outside targets,
  packages, runtime assets, and shipping claims. IronCalc retains the eventual
  visible Free V1 grid/front-end and sole formula authority; Univer remains
  required bounded supporting source, never a replacement front end or second
  calculation engine.
- The external MAS authority and repository recovery mirror are byte-identical
  through active document 13. Their active-doc manifest now declares 14
  documents and exact digest
  `ec106fc1e779dc5166f627b50a8ded387f1891cde46edf5a3ee4e9ec8e537e11`.
  The old clone-later, Univer-renderer, and free-agent-suggestion contradictions
  were removed. The local `.research-clones/` path is ignored by the project.
- The one retained unsigned KEELSTONE artifact and its red entitlement gate are
  unchanged. Runtime and performance behavior remain unproven.

**Exact next action**

- Read the P0 Free V1 graph/notebook/settings source and its focused tests,
  write or update the failing source-contract test first, then make the
  smallest policy-projection correction. Do not run an app build or launch.

### P0 verification debt — graph sidebar paid-artifact projection

- **Touched files:** `Epistemos/Views/Graph/HologramSearchSidebar.swift` and
  `EpistemosTests/BackgroundGraphLoadingTests.swift`.
- **Risk:** the graph sidebar previously built its artifact list and searchable
  cache from every stored record, bypassing the shared Free V1 graph policy.
  A durable paid chat/run/raw-thought/tool-trace could therefore reappear in
  the sidebar even though the main graph path rejected it.
- **Test-first contract:** the focused sidebar test now supplies a normal
  document/note plus all four stored paid node types and expects only the
  document/note in sidebar/search projections. It would fail against the
  pre-fix source because the old cache passed all nodes through.
- **Source correction:** both direct tree construction and detached cache
  construction now project through
  `ProductCapabilityPolicy.allowsGraphProjection(of:)` before categorizing or
  sorting nodes. Stored source/data is not changed.
- **Current proof:** targeted Swift syntax parsing and `git diff --check`
  passed. **Deferred proof:** run the focused
  `BackgroundGraphLoadingTests` Xcode test only after a fresh owner-authorized
  one-current-artifact evidence leg clears the retained unsigned-app
  entitlement boundary. No test host, app build, archive, or launch ran here.

**Exact next action**

- Continue the P0 read/test-first sweep at the Epdoc notebook and HTML
  workspace projections, preserving this verification debt and the current
  unsigned KEELSTONE artifact.

### P0 verification debt — Epdoc sheet/chat stub presentation

- **Touched files:** `Epistemos/App/ProductCapabilityPolicy.swift`,
  `Epistemos/Views/Notes/EpdocNotebookManifest.swift`,
  `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, and the focused
  Epdoc/Free-V1 test contracts.
- **Risk:** the document already hid chat tabs, but still presented Sheet tabs,
  dataset embeds, a disabled Sheet launcher, and the empty new-tab launcher.
  Those were unfinished RECKONER presentation paths rather than a real
  IronCalc-backed workbook feature.
- **Test-first contract:** Free V1 now requires preserved raw sheet/chat
  references to be absent from selectable tabs, TOC, lens disclosure, launcher
  controls, and restored selection. Unknown tombstones remain visible as honest
  compatibility disclosures. The new expectations fail against the prior
  Sheet-visible policy.
- **Source correction:** the capability policy rejects both `.sheet` and
  `.chat` in Free V1; the tab strip and saved-selection recovery respect that
  policy, and the empty launcher is removed. No manifest line, reference, or
  owner data was deleted. The future paid launcher/source remains preserved.
- **Current proof:** targeted Swift syntax parsing and `git diff --check`
  passed. **Deferred proof:** run the focused Epdoc manifest/visibility and
  Free-V1 capability Xcode tests only in a future owner-authorized fresh
  one-current-artifact evidence leg after the unsigned entitlement boundary is
  cleared. No test host, app build, archive, or launch ran here.

**Exact next action**

- Continue the P0 source/test-first sweep at HTML workspace data feeds and
  legacy preview rendering, then revisit the shared graph/settings/landing
  projection boundaries. Preserve all verification debt and do not rebuild.

### P0 verification debt — HTML Workspace paid regeneration surface

- **Owner boundary applied:** Free V1 has no AI surface. Browser, Research Hub,
  June, model-backed actions, and HTML Workspace regeneration remain hidden and
  inert until a later paid edition. This does not delete their stored source or
  future paid capability classification.
- **Touched files:** `Epistemos/App/ProductCapabilityPolicy.swift`,
  `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift`,
  `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorRegeneration.swift`, and
  focused Free-V1/App-Store source-contract tests.
- **Risk:** the legacy Goose-backed Regenerate toolbar was compile-hidden in
  the MAS lane, but the sheet and recovery/apply helpers were controlled only
  by a compile flag. A non-MAS development build carrying the same Free V1
  edition could still expose or apply a generated surface; its old parking
  text also incorrectly redirected users to the now-hidden June/Epdoc Assist
  lane.
- **Test-first contract:** Free V1 must report the regeneration capability as
  unavailable; the toolbar and sheet require the same explicit policy; and
  every regenerate entry, stream preview/apply, and prompt-export path must
  fail closed before Goose streaming or stored generated output can be used.
  The source guards would fail against the old compile-flag-only code.
- **Source correction:** the policy now owns
  `allowsHTMLWorkspaceRegeneration`, tied to paid
  `generativeActions`. The toolbar and sheet binding use it, and every
  generation/recovery entry parks with the honest future-paid message before
  doing work. The App Store compile guard remains as a second boundary. No
  generated workspace, vault data, source clone, or user data was deleted.
- **Current proof:** the five changed source/test files parsed with focused
  Swift syntax checks and `git diff --check` passed. **Deferred proof:** run
  the focused Free-V1, HTML Workspace, and App Store source-contract Xcode
  tests only in a fresh owner-authorized one-current-artifact evidence leg
  after the retained unsigned-app entitlement gate is cleared. No test host,
  app build, archive, launch, model/provider request, secret access, or audio
  operation ran here.

**Exact next action**

- Continue the P0 source/test-first sweep at shared Free V1 settings and
  landing projections, then reconcile obsolete MAS-June source guards without
  restoring hidden paid surfaces. Preserve all verification debt and do not
  rebuild.

### P0 verification debt — Settings agent-extension deep-link projection

- **Touched files:** `Epistemos/Views/Settings/SettingsView.swift` and
  `EpistemosAppStoreKeelstoneTests/FreeV1ProductCapabilityPolicyTests.swift`.
- **Risk:** the visible Settings list hid model configuration through the
  Free V1 policy, but legacy extension/skills controls were omitted only for
  Store-sandbox compilation. A Free V1 development configuration could still
  surface that agent-automation route or retain it as a selected setting.
- **Test-first contract:** Free V1 must list neither models nor skills, and a
  direct request for either setting must resolve to General. The new skills
  expectations fail against the prior compile-flag-only settings route.
- **Source correction:** the legacy skills row now requires the paid
  `agentAutomation` capability in addition to its existing non-MAS compile
  condition, and safe selection fails closed to General when that capability
  is unavailable. The retained future paid source is untouched.
- **Current proof:** focused Swift syntax parsing and `git diff --check`
  passed. **Deferred proof:** run the focused Free-V1 capability and Settings
  Xcode tests only in a fresh owner-authorized one-current-artifact evidence
  leg after the retained unsigned-app entitlement gate is cleared. No test
  host, app build, archive, launch, model/provider request, secret access, or
  audio operation ran here.

**Exact next action**

- Continue the P0 source/test-first sweep at landing state restoration and
  dead paid-route presentation bindings. Preserve all verification debt and do
  not rebuild.

### P0 verification debt — landing debug agent launch boundary

- **Touched files:** `Epistemos/Views/Landing/LandingView.swift` and
  `EpistemosTests/AppStoreJuneHardeningTests.swift`.
- **Risk:** the normal landing state sanitizer already returned Browser,
  Research Hub, and June routes to Free V1's greeting, but a legacy debug
  environment switch still assigned the hidden agent route directly after
  landing appearance.
- **Test-first contract:** the debug launch switch must retain its explicit
  opt-in environment variable but also require the paid June capability before
  it requests the agent page. The new source contract fails against the prior
  debug-only condition.
- **Source correction:** the debug switch now checks
  `ProductCapabilityPolicy.isAvailable(.june)` first. This retains future
  paid debugging without allowing Free V1 to request the hidden surface.
- **Current proof:** focused Swift syntax parsing and `git diff --check`
  passed. **Deferred proof:** run the focused Free-V1 capability and landing
  source-contract Xcode tests only in a fresh owner-authorized one-current-
  artifact evidence leg after the retained unsigned-app entitlement gate is
  cleared. No test host, app build, archive, launch, model/provider request,
  secret access, or audio operation ran here.

**Exact next action**

- Reconcile the obsolete MAS-June source-contract tests and remaining dead
  paid-route bindings found by this P0 sweep, without restoring or executing
  any paid/AI surface. Preserve all verification debt and do not rebuild.

### P0 verification debt — obsolete MAS-June source-contract suite

- **Observed state:** `EpistemosTests/AppStoreJuneHardeningTests.swift` has
  25 legacy June/Goose hardening tests and 74 mirrored-source reads. Its
  historical source list still references 21 removed parked-lane files,
  including Goose ACP supervisors, VaultMCP host/server files, Work/OpenCode
  server files, and their Settings rows.
- **Risk:** this is no longer a valid Free V1 release contract. Restoring the
  missing sources merely to satisfy the old tests would reintroduce precisely
  the local-agent/MCP/AI surfaces the current owner policy hides. Leaving the
  stale assertions untouched would make a later focused test run report false
  failures unrelated to current Free V1 behavior.
- **Boundary:** no missing file was recreated, checked out, copied, or added
  to a target. No former June/Goose/MCP runtime was run. The targeted Free V1
  source guards added in this pass remain parse-checked but have not been run
  through Xcode because this obsolete suite requires a scoped rewrite first.
- **Required later repair:** replace this legacy suite with a small,
  Free-V1-specific source/artifact contract that asserts omission and
  fail-closed policy for paid agent, Browser, Research Hub, model, and
  generative surfaces. It must not resurrect its removed source fixtures or
  reclassify any paid feature as Free V1.

**Exact next action**

- Continue the P0 audit through remaining Free V1 presentation entry points
  and then prepare a narrowly scoped replacement plan for the obsolete
  MAS-June test suite. Preserve all verification debt and do not rebuild.

### Twentieth steer — unified editor title identity popover

**Owner wording (exact excerpt)**

> “i also want the code editor and the editro surfaces to have that this where
> i can seelct the title and the popover pops up with the name and teh where.
> and again i love the verbatim sizing of the text and the way the markedit
> looks but eith my epistemos palette stuff … might have to use markedits titel
> onotlgot but ofc still having my toolbar at the top and stuff so i still want
> my toolbar and such.”

**Interpreted intent**

- Add one real, Epistemos-native document-identity popover to the title control
  used by supported note/editor surfaces. It must expose the current name,
  tags, and vault location, and mutate the existing authoritative note/folder
  model rather than inventing a second MarkEdit title ontology.
- Retain the existing Epistemos toolbar and palette. Preserve the current
  MarkEdit CoreEditor text metrics and source-editor visual grammar; do not
  copy MarkEdit's product shell or trade dress.

**Hard constraints**

- Read each title, save, tag, folder/location, editor, and test contract before
  editing. Use a shared component only after mapping the supported callers.
- The popover must use real vault-backed fields; no fake location, duplicate
  title store, or silent data migration. It must respect existing write/lease
  safety and save/error paths.
- Free V1 remains deterministic and AI-free. This work must not expose June,
  models, Browser, Research Hub, or any hidden paid surface.
- Keep the existing top toolbar. Do not claim visual, typing, or interaction
  behavior without a later fresh one-current-artifact runtime evidence leg.

**Non-goals**

- No full MarkEdit window-shell replacement, no imported MarkEdit title schema,
  no RECKONER wiring, and no broad editor refactor.

**Acceptance checks**

- A supported editor title opens an accessible popover containing editable
  name/tags and the real current location; changes use the existing save path
  and propagate to all title presentations.
- The existing toolbar remains present; CoreEditor palette, gutter, scroll rail,
  font, and line-height contracts remain intact.
- Focused tests cover empty/trimmed title, tag normalization, location display,
  cancellation/failed-save behavior, and every adopted title caller. Build and
  runtime proof remain separately recorded.

**Contradictions/questions**

- The exact existing title-control topology and universal caller set are not
  yet mapped. Prefer a shared Epistemos adapter only if the current contracts
  permit it; otherwise land the first supported note/code surfaces with an
  explicit expansion seam.

**Exact next action**

- Map current title, tag, folder/location, editor-save, and toolbar call sites;
then update the relevant feature/canon plan and write the smallest failing
focused contract before any source implementation. Preserve existing build
debt and do not start a build during that grounding pass.

### Twentieth steer — editor identity implementation checkpoint

**Current implementation state**

- The active MAS canon and external source-of-truth mirror now require one
  Epistemos-native title identity popover across normal note-window and
  graph-embedded toolbar chrome. The refreshed active-document digest is
  `d3ab2108907ef876c567a25f924846e26ddcb441179df606308ddbd411ce92fd`.
- `NoteIdentityPopover` owns only the temporary form draft: name, normalized
  comma-separated tags, and selected real vault folder. It does not define a
  second document identity or use a MarkEdit title schema.
- `NoteDetailWorkspaceView` now provides the common clickable title control to
  Prose, Epdoc Document, Markdown Source, and code-note routes. It uses the
  existing `SDPage` title/tags/folder/subfolder fields plus the established
  vault move and rename paths, rolls SwiftData back on pre-write move/rename
  failures, and updates the current native window title.
- When a Markdown body has the existing supported leading H1 title, the
  identity save updates that H1 through `ProseEditorView`'s shared fenced-code
  aware parser before the file-first write. Code files remain raw code and
  retain their extension through the existing rename path.
- The active App Store `AppStoreKeelstoneLaneTests` contract was written before
  the source implementation. It covers title whitespace cleanup, tag
  de-duplication, fenced-code title safety, normal and graph title-control
  wiring, real vault move/rename calls, form labels, and the absence of a
  MarkEdit dependency.

**Current evidence**

- `swiftc -parse` passed for the new popover, title-heading helper, workspace,
  and focused test source.
- `git diff --check` passed.
- The 2026-07-13 resource preflight passed the owner's conservative thresholds:
  1.63 GB swap used, 66% free memory, zero throttled pages, 744 GiB free, no
  active Xcode build, compiler, model, or Epistemos runtime. Four zero-CPU,
  launchd-owned `MTLCompilerService` helpers were observed as idle system
  services, not an active build.
- The first signing-disabled Free V1 focused test compilation reached the new
  sources but stopped before executing a test. Its retained result bundle names
  a Swift compiler diagnostic failure at the ambiguous
  `sourceRoute?.isMarkdown ?? page.filePath == nil` expression; this is a
  source-compilation blocker, not evidence of feature behavior. The expression
  has been reduced to a named `hasNoFilePath` Boolean before any retry.
- A fresh serial signing-disabled Free V1 build then completed from the cleared
  `/tmp/Epistemos-TitleIdentity` location. It retained exactly one current
  Debug artifact at
  `/tmp/Epistemos-TitleIdentity/DerivedData/Build/Products/Debug/Epistemos.app`
  (ad-hoc Debug signature; executable SHA-256
  `bf0cb0edf708c6bfe280a5c5a424df42e709944dbb74cad997dbf56cb40a8145`).
  The build had no errors and three pre-existing warnings outside this feature:
  one future-Rust compatibility warning and two no-async-in-await warnings.
- The first selector invocation matched zero tests and is expressly not counted
  as proof. Reusing the same artifact without rebuilding, the corrected Swift
  Testing selector ran exactly
  `appStoreEditorIdentityPopoverWritesVaultBackedNoteFields()` and passed in
  0.009 seconds. Its isolated test host logged the Free V1 boundary as June,
  local GGUF runtime, and cloud models disabled; vault bookmark restoration was
  skipped under tests. No manual UI interaction, model/provider request,
  secret access, or audio operation was performed.

**Verification debt**

- Manual normal-window/graph/source/code popover interaction, real vault
  rename/move rollback behavior, and visible text-metric preservation are still
  unproven. Do not claim visual or full runtime behavior from the source and
  one focused test proof.
- Before any test build, use one fresh isolated DerivedData location, stop any
  prior test host, clear stale Epistemos products from that exact location, and
  retain only the resulting current test artifact. Do not touch the retained
  KEELSTONE Debug artifact.

**Exact next action**

- Begin the separately recorded Epdoc performance investigation with a
  read-first lifecycle and hot-path map. Preserve the current single Debug
  artifact and do not launch it manually or rebuild while that mapping is in
  progress.

### Twenty-first steer — Epdoc interaction and transition performance hardening

**Owner wording (exact excerpt)**

> “the main issue … were the performance of epdoc and sitchgn from and to
> edpco would hang take time cause lag andbugs etc. so it should be hardnened
> as well it jsut seems liek scrolling and typing feels very low qualtiy and
> dont know why.”

**Interpreted intent**

- Make Epdoc feel responsive and reliable during entry, exit, mode changes,
  scrolling, and typing. Diagnose actual sources of latency, hangs, or state
  bugs before choosing a correction; visual polish without measurable behavior
  improvement is not enough.

**Hard constraints**

- Finish the currently failing editor-identity compilation/test leg first.
  Then map the Epdoc lifecycle, WebKit/editor bridge, markdown projection,
  autosave, and workspace-mode transitions before modifying performance code.
- Preserve one document source of truth, existing editor/vault write safety,
  the Free V1 no-AI boundary, the retained KEELSTONE artifact, and the owner’s
  one-current-artifact build rule. No runtime performance claim without fresh
  correlated evidence.
- Do not make speculative broad rewrites, remove durability safeguards, or
  trade data integrity for perceived speed. Keep any correction narrow and
  test-first with cancellation, rapid mode switching, large text, and failed
  write cases covered.

**Non-goals**

- No visual reskin-only pass, no new Epdoc feature scope, no June/agent/model
  activation, and no claim that this is fixed from source inspection alone.

**Acceptance checks**

- A traceable baseline identifies the costly transition, scrolling, typing, or
  save/reload path and distinguishes main-thread work, WebKit bridge churn,
  Markdown re-projection, and persistence contention.
- A focused correction prevents unnecessary editor reload/recreation and
  duplicate save/transition work while preserving selection, content, and
  failure recovery.
- Focused automated tests plus fresh serial manual runtime evidence cover
  document entry/exit, rapid mode switching, sustained typing, scroll, and a
  normal save/reopen. Any remaining latency or unmeasured path is recorded
  honestly.

**Exact next action**

- After the editor-identity focused test resolves, read and map
  `MarkdownDocumentSurface`, `EpdocEditorChromeController`, its bridge/runtime
  resources, `NoteDetailWorkspaceView` mode transitions, and their current
  tests/logging. Establish an evidence plan and a failing narrow regression
  contract before changing performance behavior.

### Twenty-second steer — stable editor rendering and retained typography

**Owner wording (exact excerpt)**

> “make sure all other editors performacne is good not jumps or gltihes or
> shifts the main issue has been jumps and shfts ehre thigs are invisible then
> come inivisble and eidtting whiel scrollng causes issues and jumps bugs etc.
> so rlly all o them woul have issues with that. make sure i still have access
> to matrix bold matrix tye matrix fonts all matrix fonts and chonky and the
> greetings fnt as well. for he matrix bold i wnat that applied to the header
> 1 of source.”

**Interpreted intent**

- Harden every supported editor surface—not merely Epdoc—against content
  appearing late, disappearing, jumping, resizing, or losing scroll/selection
  continuity during entry, mode changes, scroll, and typing.
- Preserve access to every installed Matrix family variant, Chonky, and the
  Greeting font. Source-mode level-one headings must render with Matrix Bold
  while the existing Epistemos palette and readable source metrics remain
  intact.

**Hard constraints**

- Inventory actual registered font resources, their source/editor usage, and
  source H1 rendering before changing a font mapping. Never substitute or
  remove an owner font silently.
- Map visual-stability behavior across Document/Epdoc, Prose/Edit, Markdown
  Source/MarkEdit, code routes, Preview, graph-embedded editors, and any
  shared transition shell. Treat opacity/overlay masking, re-mount IDs, WebKit
  load epochs, selection restoration, scrolling, and editor snapshot writes as
  potentially coupled.
- No blanket animation suppression, forced reload, placeholder, or font change
  may hide a data-loss, selection, accessibility, or editor-readiness issue.
  Preserve motion/accessibility settings and the Free V1 no-AI boundary.

**Non-goals**

- No shallow typography-only response, no unverified performance claim, and no
  removal of Matrix, Chonky, Greeting, or existing editor palette choices.

**Acceptance checks**

- Current source and runtime evidence demonstrate no avoidable blank/invisible
  interval, layout shift, scroll reset, or selection jump through normal entry,
  repeated lens switching, sustained typing, and scrolling on each supported
  editor class.
- The registered Matrix variants, Chonky, and Greeting are available through
  the actual font registry; Source H1 resolves to Matrix Bold and a focused
  contract guards that mapping.
- Any untested route, device-dependent visual issue, or remaining latency is
  named as verification debt rather than called fixed.

**Exact next action**

- Extend the ongoing read-first map to the shared transition overlay, Prose,
  MarkEdit/CoreEditor, code editor, Preview, editor font registry, source CSS,
  and their tests. Write a narrow failing stability/font contract only after
  identifying the first proven regression seam.

### Twenty-second steer — editor stability grounding checkpoint

**Read-first evidence**

- `NoteDetailWorkspaceView` deliberately keeps Document/Epdoc mounted while
  another lens is visible, using opacity, hit-testing, and accessibility gates.
  Its historical `performGreetingTransition` overlay is currently unreferenced,
  so it cannot explain a live transition delay and must not be treated as a
  fix target without a caller.
- A clean Document lens exit does not force a document reload. A dirty exit
  waits for the existing file-first flush/snapshot path, which is a durability
  boundary and must not be bypassed merely to make a switch look faster.
- The live Epdoc bridge does, however, decode a full `ProseMirrorNode` and run
  `EpdocComplexityCalculator` on the main actor for every ordinary
  `contentDidChange` message. The bridge separately sends
  `documentStatsChanged`, so word/character status is already maintained
  without requiring that full tree walk on every keystroke. This is the first
  concrete input-path cost selected for a surgical correction.
- Prose already has visible-range-aware tokenization and scroll-overlay
  scheduling. MarkEdit/CoreEditor already applies theme/read-only changes
  in-place; user-driven source metric/config changes still correctly use its
  guarded reload path. No runtime evidence yet establishes that every route is
  free of visual shifts.
- The actual bundled and registered owner font set includes
  `MatrixtypeDisplay-9MyE5.ttf` (Matrix regular),
  `MatrixTypeDisplay-Bold.otf`, `MatrixDotsDemoRegular.ttf`,
  `ChonkyPixels.ttf`, and `GNF.ttf`. Source markdown H1 currently has a color
  selector but no Matrix Bold web-font resource/mapping, so native registration
  alone is not sufficient proof for the WebKit Source surface.

**Chosen narrow correction**

- Add a test-first Epdoc derived-status coalescer: ordinary typing keeps its
  bridge/persistence flow but schedules the latest full-document decode after a
  short quiet window on a utility task. Initial-load and clean-recovery paths
  retain their immediate status calculation; lifecycle generation checks prevent
  stale work from mutating a replacement document.
- Extend the existing CoreEditor resource handler only for bundled font assets,
  then add a scoped Source markdown H1 rule pointing to Matrix Bold. Preserve
  the base MarkEdit text face, size, line height, palette, and all user font
  preferences.

**Verification debt and next action**

- Add focused App Store source/behavior contracts before source edits, then run
  the narrow serial test leg from one fresh disposable artifact only after the
  owner resource preflight passes. Manual evidence is still required for
  Epdoc entry/exit, repeated lens switches, sustained typing/scrolling, Prose,
  Source, code, Preview, and graph-embedded presentation. No visual or runtime
  performance claim is earned by this map alone.

### Twenty-third steer — editor stability source correction and focused evidence

**Implemented source scope**

- Ordinary Epdoc `contentDidChange` now keeps its existing content-change and
  dirty-state path but coalesces full ProseMirror decode/complexity work for a
  120 ms quiet window. The snapshot resolves in a utility detached task and is
  applied only when the generation and load epoch still match. Initial echo and
  clean-recovery status paths remain immediate; dirty file-first flush,
  Markdown write-through, autosave, and recovery behavior were not bypassed.
- The CoreEditor URL handler now admits only the existing `chunks` host and a
  bounded bundled `fonts` host. It maps `.otf`/`.ttf` to font MIME types and
  does not create a general file bridge. The Source overlay defines the Matrix
  Bold font face from that bundled URL for `.cm-md-heading1` only, using
  `font-display: optional` to avoid a late mandatory font swap. Base MarkEdit
  typography, stored metric preferences, palette, and the other owner font
  registrations remain unchanged.

**Fresh resource and automated evidence**

- Before the one replacement build, current HEAD was
  `668b52cfb43721de95db102260d9f327ae24e13e`; the worktree had 85 dirty
  entries; swap was 3172.50 MB used; memory free percentage was 67%; pages
  throttled were zero; `/tmp` had 742 GiB free; and no competing
  Xcode/compiler/model/Epistemos process was present. These values pass the
  owner threshold, but are not a release-resource verdict.
- The stale `/tmp/Epistemos-TitleIdentity` test location was removed before
  the signing-disabled App Store build. The only current artifact for this
  focused leg is
  `/tmp/Epistemos-TitleIdentity/DerivedData/Build/Products/Debug/Epistemos.app`;
  its executable SHA-256 is
  `bf0cb0edf708c6bfe280a5c5a424df42e709944dbb74cad997dbf56cb40a8145`.
  No archive or manual application launch occurred.
- The first build selector spelling produced a result bundle with zero named
  tests. It is expressly not counted as evidence. Reusing the same app without
  rebuilding, the Swift Testing selectors with `()` ran and passed exactly
  three named tests in 0.424 seconds:
  `appStoreEditorIdentityPopoverWritesVaultBackedNoteFields()`,
  `appStoreEpdocAppliesOnlyLatestCoalescedDerivedStatusAfterTyping()`, and
  `appStoreEditorsKeepTypingStableAndSourceH1UsesMatrixBold()`. The definitive
  result bundle is
  `/tmp/Epistemos-TitleIdentity/DerivedData/Logs/Test/Test-Epistemos-AppStore-2026.07.13_10-00-42--0500.xcresult`
  with result `Passed`, three passed tests, zero failures, and zero skips.
  The isolated host logged the Free V1 model boundary as disabled; no model,
  provider, secret, or audio operation was exercised.

**Verification debt and exact next action**

- This is focused behavioral/source evidence, not a visual-performance pass.
  Normal-window Epdoc entry/exit, repeated lens switching, sustained typing
  while scrolling, selection/scroll retention, Source H1 rendering, Prose,
  code, Preview, and graph-embedded editor routes remain manually unverified.
  Do not call any of those surfaces smooth or complete.
- Continue the read-first map at the next concrete shared editor seam, starting
  with Prose and code/Preview mount/scroll/update paths and their current
  tests. Add only a test-first correction for an evidence-backed defect; retain
  the same one-current-artifact rule before a later focused test build.

### Twenty-fourth checkpoint — Source first-paint typography stabilization

**Read-first finding**

- The graph inspector currently mounts `CodeInspectorPreview`, which is
  read-only; its unused editable inspector helper is not the owner-reported
  typing path and was not changed. The live Source/code route uses the MarkEdit
  CoreEditor coordinator.
- That coordinator only applied the Source H1 Matrix Bold rule after the
  CoreEditor bridge reported ready. The bounded font request therefore began
  after the Web editor could first paint, leaving an avoidable fallback-font
  metric-settle window even though the font was bundled and registered.

**Narrow correction**

- The Markdown-Source initial HTML now injects a `preload` plus one
  `@font-face` declaration for the existing Matrix Bold bundle asset before
  the CoreEditor module loads. The normal document URL rewrite runs after that
  injection, so the preload and font both resolve only through the existing
  `chunk-loader://fonts` allowlist. Code mode does not receive this Source-only
  markup. The later palette overlay consumes the same font-family constant and
  owns the H1 selector, without creating a second font-face declaration.
- No editor reload policy, selection path, scroll path, vault persistence path,
  font registry entry, palette metric, paid capability, model, provider, audio,
  or secret path changed.

**Fresh evidence — 2026-07-13**

- Before the one fresh focused test build: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, 85 dirty entries, swap 3164.50
  MB, free memory 69%, zero throttled pages, 742 GiB free disk, and no competing
  Xcode/compiler/Epistemos process. This passed the owner resource threshold.
- The first command was rejected by the shell because unquoted Swift Testing
  selector parentheses were parsed before `xcodebuild` started. It produced no
  build, test host, or artifact and is not evidence.
- After clearing only `/tmp/Epistemos-EditorStability`, the sole current app
  for this focused leg is
  `/tmp/Epistemos-EditorStability/DerivedData/Build/Products/Debug/Epistemos.app`.
  Its executable SHA-256 is
  `4804165d849a6f95bb8d97af44eb4d88a00c78e5f574bb839983119f68ede285`.
  The exact result bundle is
  `/tmp/Epistemos-EditorStability/DerivedData/Logs/Test/Test-Epistemos-AppStore-2026.07.13_10-10-41--0500.xcresult`.
  Its summary is `Passed`: four selected tests passed, zero failed, zero
  skipped.
- The four actual selected tests were
  `appStoreEditorIdentityPopoverWritesVaultBackedNoteFields()`,
  `appStoreEpdocAppliesOnlyLatestCoalescedDerivedStatusAfterTyping()`,
  `appStoreEditorsKeepTypingStableAndSourceH1UsesMatrixBold()`, and
  `appStoreSourcePreloadsMatrixBoldBeforeCoreEditorStartup()`.
- The one fresh app artifact contains all five owner-requested font resources:
  Matrix Type regular, Matrix Type Bold, Matrix Dots, Chonky Pixels, and GNF
  (Greeting), plus the CoreEditor HTML resource. This proves bundle presence,
  not rendered visual metrics.

**Remaining verification debt and exact next action**

- No manual normal-window launch or visual smoothness claim was made. Manual
  Source first paint/H1 rendering, normal-window and graph-embedded lens
  switching, sustained typing while scrolling, selection/scroll retention,
  Prose/Edit, code, Preview, and document entry/exit remain unproven.
- Continue the read-first map at `ProseEditorRepresentable2` page-swap and
  external-body replacement geometry, then evaluate the real MarkEdit source
  lifecycle. Make another correction only if a concrete reset, load, selection,
  or scroll defect is evidenced; before any later build, repeat the one-current-
  artifact preflight and use a new disposable build location.

### Twenty-fifth checkpoint — Prose scroll-restoration ordering

**Read-first finding and correction**

- The retained Prose `handlePageSwap` path replaced the incoming text, restored
  the saved scroll origin, and only then recalculated its readable-width text
  inset. A changed width can re-layout and clamp that already-restored viewport.
  The external vault/restore body-replacement path preserved selection but did
  not preserve its current scroll origin at all.
- The correction computes incoming centering before restoring the saved page or
  disk scroll position, routes all page-swap restores through one small native
  helper that also reflects the clip view, and captures/restores scroll across
  a guarded external-body replacement after its text geometry is updated. It
  does not alter page flush, dirty-state, input/IME, selection clamp, autosave,
  debounce, or persistence behavior.

**Fresh evidence — 2026-07-13**

- Before this one test build: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, 86 dirty entries, swap 3156.50
  MB, free memory 67%, pages throttled zero, 740 GiB free disk, and no
  competing Xcode/compiler/Epistemos process. The owner resource threshold
  passed. A malformed local field extraction initially printed a blank
  throttled value; the direct `vm_stat` reading immediately confirmed zero and
  is the authoritative preflight value.
- After clearing only `/tmp/Epistemos-ProseScrollStability`, the sole current
  focused artifact is
  `/tmp/Epistemos-ProseScrollStability/DerivedData/Build/Products/Debug/Epistemos.app`.
  Its executable SHA-256 is
  `05e964115697d723017d38ded58302a0cf70c3cc2e94611daf4b736718a15209`.
  The exact result bundle is
  `/tmp/Epistemos-ProseScrollStability/DerivedData/Logs/Test/Test-Epistemos-AppStore-2026.07.13_10-17-26--0500.xcresult`.
- `appStoreProseRestoresScrollAfterIncomingLayoutAndExternalSync()` passed;
  one selected test, zero failures, zero skips. This is exact source-contract
  and compile evidence, not manual scrolling proof.

**Remaining verification debt and exact next action**

- Normal-window and graph-embedded Prose mode switching, deep-scroll restore,
  external vault synchronization while scrolled, Source first paint, Source and
  code typing while scrolling, Preview entry, Epdoc entry/exit, and all
  selection behavior remain manually unverified. Do not call the editor suite
  smooth or release-ready.
- Continue mapping the actual Preview and MarkEdit mount/update paths, then
  decide whether there is another source-backed reset or layout defect. Do not
  build again unless a narrow correction and test require it; if so, re-run the
  resource preflight and use one new disposable location only.

### Twenty-sixth steer — executive performance-first hardening and canon continuity

**Owner wording (exact excerpts)**

> “please contineu with the work ytou are doing rn but when u are done only
> whe nu are comppetely done start this: searc throug hevery corner of the ap
> before you start the mas canon to look for performance upgrades”

> “every single thgn neeeds to be auditte d the settigns included lots of stale
> things lives in the settigns and its rlly messy it needs to be simplified”

> “all teh the thigs we are hiding make sure they are not deleted from
> existence but all hidden and not compiled either”

> “there should eb no chats no ai other than kokoro.”

> “updat the acual files in mas canon folder ... i want it in the minimal prompt
> doc as well just everywhere so its part of the canon”

> “the source surface part of the app i want it to look like teh mark edit ...
> the line count strip is a diff color and i should be the same color as the
> rest of the surface instead of a grey color.”

> “this wil be the main thread and u need to dispatch tasks and be uaed as an
> executive session to start and steer other tasks”

**Interpreted intent**

- Preserve the current editor-stability sequence and close its honest evidence
  debt first. Then use this task as the executive thread for a performance-first
  audit and hardening program covering all user-visible surfaces, Settings,
  startup, memory/task/cache ownership, persistence and data paths, build and
  release topology, and backend seams before feature implementation resumes.
- Free V1 must contain no chat, June, model, provider, generative, agent,
  Browser, Research Hub, or code-execution product surface. Those paid MAS
  implementations must remain recoverable in source history/canon but be hidden,
  inert, and excluded from the Free V1 compile/link/resource graph. Kokoro and
  deterministic non-AI features remain Free V1.
- After the performance and Free-V1 boundary are genuinely hardened and
  verified, update both restored MAS canon mirrors, especially the numbered
  minimal prompt, so the accepted decisions, performance gate, clone/reference
  admission, MarkEdit-derived Source direction, task/calendar/reminder/
  accessibility feature set, typography, and future paid boundary cannot be
  lost. Only then resume the canon-approved non-AI feature sequence.

**Hard constraints**

- Current execution key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. Do not begin a new
  canonical key merely because audit subtasks are delegated.
- Follow the owner’s sequence: current editor work, app-wide performance and
  Free-V1/release hardening, exact verification, canon synchronization, then
  feature work. Keep the restored external canon as the higher authority and
  mirror accepted changes into the repository copy.
- Use semantic expansion for performance: leak, retain cycle, unbounded cache,
  observer/timer/task lifetime, main-thread I/O/parse, startup load, hang,
  freeze, jank, lag, throttle, layout shift, blank/late content, scroll jump,
  remount, allocation churn, duplicate work, persistence contention, and data
  loss. Source scans are triage, not runtime proof.
- Preserve file-first vault durability, user data, backwards-readable stored
  records, accessibility, motion preferences, owner typography, and the
  one-current-artifact build rule. Do not improve apparent speed by skipping
  writes, hiding readiness failures, or deleting retained paid implementation.
- MarkEdit remains the already-vendored Source/code foundation. Preserve the
  Epistemos palette, owner toolbar, larger readable metrics, title identity
  popover, Matrix/Chonky/GNF resources, and Matrix Bold Source H1. Make the
  line-number gutter visually continuous with the editor canvas rather than a
  contrasting grey strip.
- Delegated tasks begin read-only and return evidence to this executive thread.
  No parallel `xcodebuild`, archive, app launch, model/provider/secret, audio,
  or destructive vault operation is authorized by delegation.

**Non-goals**

- No claim of perfect performance or release readiness from static search,
  one focused build, or three repeated source checks. Manual/runtime and log
  evidence remains mandatory for visual, interaction, memory, and release
  claims.
- No payment, StoreKit, account recovery, Apple enrollment, or distribution-
  signing work in this phase.
- No deletion of June, Browser, Research Hub, or other future paid source merely
  to make Free V1 look clean; exclusion must happen at product policy, target,
  compile, link, resource, restoration, shortcut, and background-work seams.
- No blind re-cloning or wiring of IronCalc, Univer, or other reference repos.
  The existing quarantined checkouts remain non-shipping research inputs;
  integration still requires a provenance/license/package/MAS preflight and a
  separately approved project-wiring stage.

**Acceptance checks**

- Current editor changes have focused automated evidence and current manual/log
  debt is explicit for Epdoc, Prose, Source, Code, Preview, graph-embedded
  routes, scrolling, selection, repeated lens switching, and visual typography.
- A ranked app-wide performance inventory covers every major surface and
  backend; each accepted correction has a failing contract, a surgical fix,
  narrow then broad verification, memory/log evidence where applicable, and no
  regression in persistence or accessibility.
- Free V1 has no visible/restorable/shortcut/background chat or paid surface and
  its exact built artifact proves prohibited paid libraries/resources are not
  compiled or linked, while Kokoro and deterministic capabilities still work.
- Settings is simplified to truthful Free V1 controls without stale disabled
  placeholders; release scripts, schemes, entitlements, privacy manifest,
  packaging, and one-artifact evidence agree.
- The release audit reaches three uninterrupted zero-fail passes only after
  automated, manual/runtime, log, artifact, and distribution/compliance checks
  all agree. Until then the verdict remains incomplete/not ready.
- Both canon mirrors, the numbered minimal prompt, source map/manifest, and
  feature registry match byte-for-byte after the final accepted updates and
  preserve real Reckoner/Datasheet plus task/calendar/reminder/accessibility
  work in the correct post-hardening order.

**Contradictions and current truth**

- “Hidden and not compiled” cannot be satisfied by a view-level `if` alone;
  current dirty source already contains partial Free-V1 target work, but the
  exact final binary/link/resource absence remains unproven.
- “Perfect” is the target bar, not an evidence shortcut. The current editor
  fixes have focused compile/test proof only; hands-on smoothness remains open.
- MarkEdit is already vendored locally, so re-cloning it is unnecessary unless
  its pinned provenance later fails. Clean detached IronCalc and Univer
  checkouts are also present under ignored `.research-clones/work/` at
  `1bd4bb6005ffda4fcb1f287f4d4e7b564e310ddc` and
  `6ae8eb3ef05c7645ed1425b13358bab1d8155a32`, respectively. They remain
  quarantined reference inputs, not installed packages, target members,
  runtime assets, or product-capability proof.

**Current grounding and exact next action**

- Local `HEAD`, fetched `origin/feat/goose-surface`, and the commit that last
  changed the durable handoff all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`; `git pull --ff-only` was already
  up to date. The working tree remains intentionally dirty and is not reset.
- The latest resource preflight records 4,079.88 MiB swap used (below the
  4-GiB ceiling), 76% free memory, zero throttled pages, 737 GiB available disk,
  and no competing Xcode/compiler/Epistemos process.
- Finish the already test-first Preview layout-cache correction without changing
  visible output, then run only its focused serial App Store test in a fresh
  disposable build location. Continue the MarkEdit/Source lifecycle map and
  manual-evidence preparation before promoting the broader delegated audit
  findings into implementation batches.

### Twenty-seventh checkpoint — Preview layout-cache correction and focused evidence

**Read-first finding and correction**

- `AdaptiveNotePreviewView2` synchronously recomputed
  `NoteDualPreviewLayout.columnContents(in:)` in its initializer whenever
  SwiftUI reconstructed the view, including parent, title, and geometry-driven
  refreshes for unchanged content. The split itself is deterministic, but the
  repeated full-document parse and rebalance was avoidable work on the
  Preview-entry path.
- `NotePreviewContentCache` now retains the exact existing column output in a
  memory-pressure-evictable `NSCache`, bounded to 12 entries and 8 MiB total
  cost. First paint remains synchronous, the visible layout algorithm is
  unchanged, and a cache miss still calls the original parser directly.

**Focused evidence**

- The new App Store source contract was run red first in a freshly cleared
  `/tmp/Epistemos-PreviewCache` location and failed only its three missing cache
  expectations. After the surgical source correction, the same single selected
  test passed: 1 executed, 1 passed, 0 failed, 0 skipped.
- Green result bundle:
  `/tmp/Epistemos-PreviewCache/DerivedData/Logs/Test/Test-Epistemos-AppStore-2026.07.13_10-32-18--0500.xcresult`.
  The disposable build location contains exactly one `Epistemos.app` at
  `/tmp/Epistemos-PreviewCache/DerivedData/Build/Products/Debug/Epistemos.app`;
  its executable SHA-256 is
  `e40781c17ce1744e620ab346dbe172f0abb58898ec00d8dbe995620735ca227e`.
- The green preflight recorded 4,039.88 MiB swap used, 71% free memory, zero
  throttled pages, 735 GiB available disk, and no competing Xcode/compiler/
  model/Epistemos process. The prior test host was stopped if present and only
  that disposable build location was cleared before the test.
- `git diff --check` passes for the correction and contract. The build also
  surfaced existing warnings for unconditional build phases and unnecessary
  `await` expressions in `TextCapturePipeline` and `VaultSyncService`; these
  remain inputs to the broader performance/release audit rather than being
  folded into this narrow fix.

**Boundary and exact next action**

- This is focused test-host evidence, not normal-window visual or performance
  proof. Preview entry, repeated lens switching, large-note scrolling, memory
  stability, selection behavior, and all other editor manual checks remain
  unproven. The same build log also proves that the current Free V1 target still
  compiles paid/chat/agent source, so view-level hiding is insufficient and the
  compile/link/resource boundary remains open verification debt.
- Continue the read-first MarkEdit/Source theme and lifecycle map, beginning
  with gutter/canvas continuity and reload/selection/scroll ownership. Accept
  another source change only for a concrete evidenced seam, then promote the
  ranked delegated performance and release findings into test-first batches.

### Twenty-eighth checkpoint — Source identity stability and exact focused evidence

**Read-first finding and correction**

- The Source surface keyed its `CodeEditorView` to a mutable
  `sourceEditorPresentationRevision`. Saving a title or note location refreshed
  the Markdown snapshot and incremented that revision, which destroyed and
  recreated the live editor even though `CodeEditorView` already accepts
  incoming content changes in place. That recreation was a deterministic cause
  of selection, scroll, focus, WebView, and visible-flash instability.
- The Source surface is now keyed only to the stable page identity. The unused
  presentation-revision state and rename increment are removed. The existing
  editor-owned `initialContent` change hook remains responsible for accepting a
  clean external snapshot without remounting the surface.

**Focused red/green evidence**

- The single selected App Store regression test was run red first after the
  prior disposable app product was deleted. It executed 1 test and failed with
  the expected stable-identity/revision issues. That pass also revealed one
  contract-location error: the in-place content hook lives in
  `CodeEditorView.swift`, not the workspace file. The assertion was corrected
  to inspect the real owner before the source change was accepted. Red result:
  `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-07-13-104715-54647.xcresult`.
- After the surgical source correction, the same exact selected test ran in a
  newly cleared `/tmp/Epistemos-SourceIdentityStability` location and passed:
  1 executed, 1 passed, 0 failed, 0 skipped. Green result:
  `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-07-13-105003-60203.xcresult`.
- The green location contains exactly one app and no archive:
  `/tmp/Epistemos-SourceIdentityStability/Build/Products/Debug/Epistemos.app`.
  Its executable SHA-256 is
  `fc508a587dae8d332b316e6614929d05d6a9211306fe0d781751bddcb588534a`.
- The red preflight recorded 4,015.88 MiB swap, 76% free memory, zero throttled
  pages, 735 GiB available disk, and no competing Xcode/compiler/model/
  Epistemos process. The green preflight recorded the same swap and disk state,
  69% free memory, zero throttled pages, and no competing process.
- `git diff --check` passes. This remains focused test-host/source evidence;
  hands-on title changes during typing and scrolling are still part of the
  eventual serial manual editor matrix.

**New lifecycle findings and exact next action**

- The same identity audit found two adjacent current defects. A Prose title
  save posts a whole-document replacement whose default command selection is
  the end of the replacement, deterministically jumping the caret/viewport.
  An active Document/Epdoc surface can retain its old H1 after the canonical
  title changes because same-page clean external reload is intentionally
  suppressed. Neither defect should be solved by remounting an editor.
- Add narrow failing contracts for selection/scroll-preserving Prose title
  replacement and in-place active-Epdoc title convergence, then implement only
  those seams. After their focused evidence, close the default-on Contextual
  Shadows/Instant Recall Free-V1 boundary before broader performance batches.

### Twenty-ninth steer — 8-GiB resource ceiling and seamless resumption

**Owner wording (exact excerpts)**

> “ok get rid of that make the limit 8 instead please and contine”

> “as if we never stopped please”

**Interpreted intent**

- Supersede the temporary below-4-GiB swap ceiling with a durable below-8-GiB
  ceiling and resume the exact in-flight editor evidence/correction chain as one
  continuous session.
- The numerical change applies to every later Epistemos build, test build, and
  archive preflight unless a newer dated owner directive changes it.

**Hard constraints**

- Swap used must be below 8 GiB; system free-memory percentage must remain at
  least 25%; pages throttled must remain zero; and no competing Xcode build,
  compiler, model, or Epistemos runtime may be active.
- The one-current-app rule, serial Xcode execution, MAS-only/Free-V1 product
  boundaries, file-first data-safety requirements, and the current canonical
  execution key remain unchanged.
- This steer does not authorize payment/account work, paid-model execution,
  destructive vault changes, or a new canonical execution key.

**Acceptance checks**

- Root project guidance and the durable current handoff state the below-8-GiB
  ceiling and no current directive still treats 4 GiB as the active ceiling.
- Every later build/test/archive records all resource values and stops if any
  retained condition is red.
- Work resumes from the already-added identity/save red contracts; no completed
  editor evidence is discarded or rerun without a reason.

**Current truth and exact next action**

- The preflight that triggered the short stop recorded 4,123.31 MiB swap used,
  70% free memory, zero throttled pages, 741 GiB available disk, and no
  competing build/compiler/model/Epistemos process. It passes the newly
  authorized below-8-GiB ceiling.
- No Xcode command began during the stop. The stale disposable red-build app
  remains the only app product and must be deleted under the one-current-build
  rule before the next test.
- Persist this supersession in project guidance and the current handoff, remove
  the stale disposable app, rerun the resource preflight, and execute the
  focused unsigned red identity/save batch before changing production code.

### Thirtieth checkpoint — exact editor transaction evidence and remaining no-loss boundary

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`
  transaction-safety work without treating the restart, resource stop, or
  focused green test as a new feature phase.
- Close concrete editor/vault durability, ordering, and recovery defects before
  the app-wide performance/Free-V1 audit, canon synchronization, or feature
  work begins.

**Hard constraints**

- Preserve exact external bytes and newer local drafts; never convert an
  uncertain write, move, delete, sidecar, or metadata outcome into success.
- All note-body and identity writes remain file-first and exact-baseline
  guarded. MAS-only, sandbox, security-scoped vault, Free-V1, one-current-app,
  serial-Xcode, and below-8-GiB resource rules remain controlling.
- Retain the intentionally dirty owner worktree. Do not reset, overwrite,
  publish, launch the app, touch an owner vault, or begin another execution key.

**Non-goals**

- The focused test-host result is not manual editor smoothness, force-quit
  recovery, vault-switch safety, full regression, release, distribution, or
  Free-V1 compile-topology proof.
- No canon feature implementation, payment/account work, model/provider
  execution, Browser/Research Hub work, audio operation, or broad refactor is
  authorized by this checkpoint.

**Acceptance checks**

- Exact-byte CAS replacement, move, and removal reject mismatched baselines;
  directory durability failures cannot be reported as success.
- Body, front matter, filename, sidecar, SwiftData metadata, derived indexes,
  newer drafts, and concurrent identity commits have focused regression proof.
- A stale dirty save retries the newer body once and settles; it cannot retain
  its own obsolete pending body and spin indefinitely.
- Remaining public move/rename/delete/create/directory paths share lifecycle
  admission and deterministic lock ordering; stop/switch drains admitted work
  before security-scope release.
- A durable phase journal and deterministic watch-start reconciliation cover
  force-quit between forward write, move, sidecar, metadata, and rollback.

**Current exact evidence**

- Branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`; the worktree remains dirty and
  untouched outside the scoped files.
- The first current-source build stopped before tests because macOS SDK 26.5
  exposes the requested volume URL only through `URLResourceValues.allValues`,
  not a typed `.volumeURL` member. That compatibility error was corrected
  surgically. Result:
  `build/xcode-results/2026-07-13-identity-atomicity-green1-8gib.xcresult`.
- The next build compiled and began tests, then exposed a real tight retry loop.
  Its readable interrupted result executed three tests: one passed, the
  rollback fixture failed before its injected leg because it lacked a known
  synced-body baseline, and the dirty-save regression was cancelled while the
  stale pending body repeatedly produced `Saved 0 of 1`. Result:
  `build/xcode-results/2026-07-13-identity-atomicity-green2-8gib.xcresult`.
- The rollback fixtures now model known clean imported bytes. A successful or
  stale save clears only the exact pending body it owned; any different newer
  pending body remains. A returned body-hash mismatch is a failure rather than
  an unbounded immediate retry.
- The same focused batch then passed from its result bundle: 14 executed, 14
  passed, zero failed. Exact result:
  `build/xcode-results/2026-07-13-identity-atomicity-green3-8gib.xcresult`.
- The sole current app product is
  `/private/tmp/Epistemos-IdentityAtomicityGreen3-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `2ddda5f91b6f8758dc601f80dff3689c33f7d188d20c1343c8917357a1c24d28`.
  No current archive exists.

**Contradictions and questions**

- The focused body/identity core is green, but legacy public structural paths
  and vault lifecycle teardown still bypass the same transaction boundary.
  Therefore the owner no-loss bar and force-shutdown resumption bar remain open.
- Parent-directory synchronization makes individual mutations durable; it
  cannot reconstruct a process killed between multi-phase file, move, sidecar,
  and metadata operations. A durable journal is still required.
- The prior exact Release archive is no longer current source evidence and was
  removed under the one-current-app rule. A later archive/runtime leg must be
  rebuilt only after the editor/lifecycle corrections and full preflight.

**Exact next action**

- Add failing lifecycle-admission tests first, then implement the smallest
  epoch/drain barrier and route page/structural mutations through private
  unlocked helpers with one deterministic lock order. Next add the durable
  identity phase journal and watch-start reconciliation tests. Preserve this
  green result as evidence, delete its app product before the next build, and
  rerun the full owner resource preflight before exactly one fresh test build.

### Thirty-first checkpoint — vault-session admission and asynchronous drain proof

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same no-loss KEELSTONE chain through the next recorded seam:
  saves suspended across vault replacement and teardown of a vault with an
  admitted save still in flight.
- Preserve the old vault session until admitted file-first work settles, while
  refusing any old-session operation that resumes after a forced session
  replacement.

**Hard constraints and non-goals**

- Lifecycle admission is captured before the first suspension, bound to an
  exact monotonically changing epoch and standardized vault path, and checked
  again before file-backed metadata is published clean.
- Asynchronous stop must enter a draining state before awaiting, reject new
  mutations, retain the vault session for already-admitted work, and clear it
  only after those admissions finish.
- This focused correction does not prove structural create/move/rename/delete,
  imported/FSEvent callback quiescence, durable crash recovery, manual editor
  behavior, or release readiness.

**Current exact evidence**

- Pre-correction result
  `build/xcode-results/2026-07-13-lifecycle-epoch-red1-8gib.xcresult`
  executed one test and failed it. The suspended vault-A save incorrectly
  returned success under vault B, replaced the file path and synced hash/date,
  and cleared `needsVaultSync`.
- Current source adds one main-actor vault lifecycle admission state shared by
  explicit body saves, identity commits, and the dirty-save loop. An exact
  admission remains valid while its own session is operational or draining,
  but not after an epoch/path replacement.
- Current asynchronous stop blocks new admissions, quiesces current ingress,
  waits for admitted mutations, and only then tears down actors and clears the
  vault session. The synchronous replacement path refuses to replace a vault
  while tracked mutations are active.
- The first strengthened attempt is retained at
  `build/xcode-results/2026-07-13-lifecycle-epoch-green2-8gib.xcresult`. It
  stopped during compilation with zero tests executed because the synchronous
  scope-release probe inherited the test target's default `MainActor`
  isolation. Marking that lock-backed probe `nonisolated` was the only source
  correction before the fresh rerun.
- Current post-correction result
  `build/xcode-results/2026-07-13-lifecycle-epoch-green3-8gib.xcresult`
  executed three tests: three passed, zero failed, zero skipped. In addition to
  forced cross-session rejection, it proves that stop blocks new ingress,
  waits for the admitted save, and calls the exact injected security-scope
  release once and only after the drain; it also proves that queued identity
  commits cannot cross a same-path vault reattachment epoch.
- Red preflight: 6,206.38 MiB swap used, 72% free memory, zero throttled pages,
  737 GiB available disk, and no competing build/model/app runtime. Green
  preflight: 6,174.38 MiB swap used, 70% free memory, zero throttled pages,
  737 GiB available disk, and no competing runtime. The current Green3
  preflight recorded 6,166.38 MiB swap used, 68% free memory, zero throttled
  pages, 737 GiB available disk, and no competing runtime. All passed the
  owner’s below-8-GiB ceiling.
- The sole current app product is
  `/private/tmp/Epistemos-LifecycleEpochGreen3-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `d355c48015a5a0e09a50618f796fcfd12b5ff0ad71771ea6ece965ac4032403e`.
  No current archive exists.

**Contradictions and exact next action**

- The admitted body/identity/dirty paths now have a session boundary and the
  security-scope release order has a direct witness, but legacy structural
  mutations, import/FSEvent work, and detached maintenance tasks still bypass
  or outlive it.
- Add a failing deterministic old-import/background-task drain contract, bind
  background work and watcher callbacks to the exact lifecycle epoch, cancel
  and await it before security-scope release, then route the remaining
  page/structural entry points through the same admission and lock order.
  Durable phase-journal recovery remains the following required leg.

### Thirty-second checkpoint — initial-import drain and stale-publication rejection

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same KEELSTONE no-loss chain through the first confirmed
  old-vault background-work escape: a cancellation-ignoring initial import.
- Stop must retain the exact vault and its security scope until that task has
  actually finished, while rejecting progress, maintenance, toasts, telemetry,
  and vault-change publication after the session begins draining.

**Hard constraints and non-goals**

- Import identity is epoch plus standardized path, not path alone; reattaching
  the same path creates a different session.
- Cancellation is a request, not completion. Teardown must await the captured
  task handle before actor/search cleanup or security-scope release.
- The import token is operational-only for UI/index publication. Unlike an
  admitted file mutation, background import work may not publish while the
  session is draining.
- This checkpoint does not claim hybrid migration, Spotlight/search/Instant
  Recall child tasks, graph/manifest/body-cleanup tasks, or FSEvent processing
  are drained yet.

**Current exact evidence**

- Pre-correction result
  `build/xcode-results/2026-07-13-background-import-drain-red1-8gib.xcresult`
  executed one test and failed it. While the injected import remained behind a
  cancellation-ignoring barrier, stop completed, cleared `vaultURL`, released
  the exact security scope, and left the lifecycle no longer draining. The
  test recorded four expectation failures from that one ordering defect.
- Current source captures a `VaultLifecycleToken` before the import's first
  suspension, passes it through progress publication, rejects any token that
  is not the exact operational epoch/path, retains the import task handle, and
  awaits that handle after admitted file mutations but before teardown.
- The corrected task rechecks cancellation and token state before post-import
  maintenance, after its recovery-check suspension, before toast publication,
  and before final import telemetry is committed.
- Post-correction result
  `build/xcode-results/2026-07-13-background-import-drain-green1-8gib.xcresult`
  executed one test: one passed, zero failed, zero skipped. It proves stop stays
  incomplete and the scope remains held during the suspended import; after
  release, stop succeeds, releases the exact scope once, leaves no stale import
  summary, and emits zero old-session `.vaultChanged` events.
- Red preflight recorded 6,158.38 MiB swap used, 69% free memory, zero
  throttled pages, 739 GiB available disk, and no competing runtime. Green
  preflight recorded 6,291.06 MiB swap used, 69% free memory, zero throttled
  pages, 739 GiB available disk, and no competing runtime. Both passed the
  owner's below-8-GiB ceiling.
- The sole current app product is
  `/private/tmp/Epistemos-BackgroundImportGreen1-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `471f656210893375f4dd751a82134f3721e36eb958edb00a85fa6adaa9377f0c`.
  No current archive exists.

**Contradictions and exact next action**

- Initial-import ownership is green, but `performInitialImport` can still spawn
  detached Spotlight/search/Instant Recall work, hybrid migration is untracked,
  and post-import graph/manifest/cleanup work can outlive the parent task.
- The FSEvent callback carries no epoch and currently writes its event ID before
  checking whether the event path belongs to the active vault; an old callback
  can therefore seed a new vault's checkpoint.
- Add the deterministic stale-FSEvent-callback red contract next, bind watcher
  ingress to the same lifecycle token, and clear all pending watcher state on
  stop. Then add tracked child-task/hybrid and already-running FSEvent processor
  drain proofs before structural mutations or the durable journal leg.

### Thirty-third checkpoint — stale watcher ingress and same-path epoch rejection

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same KEELSTONE lifecycle chain without reopening feature/canon
  work or treating a restart as a new execution key.
- Prove that a callback captured by an old vault session cannot seed pending
  paths, a checkpoint ID, or a debounce inside any later session, including a
  reattachment of the exact same standardized path.

**Hard constraints and non-goals**

- Watcher identity is the captured lifecycle epoch plus standardized vault
  path. A path-only guard is insufficient.
- The real FSEvents callback box, DispatchSource fallback, test delivery seam,
  debounce suspension, drain admission, and checkpoint persistence must carry
  the same immutable token.
- Teardown clears `pendingLastEventID` along with paths, full-rescan state, and
  debounce state.
- This checkpoint does not claim that an already-running detached processor is
  cancelled or awaited, that its actor/search/recall work is session-safe, or
  that the real `Unmanaged` callback lifetime has runtime proof.

**Current exact evidence**

- Red result
  `build/xcode-results/2026-07-13-stale-watcher-callback-red1-8gib.xcresult`
  executed one test and failed it with two issues: the old callback wrote event
  ID `91001` and retained an active debounce in the later session.
- Source now captures `VaultLifecycleToken` in both watcher implementations,
  rejects it before touching pending state, rechecks it after the debounce
  suspension and before draining, clears the pending checkpoint ID on stop,
  and rejects stale checkpoint persistence.
- The first corrected result, `...green1-8gib.xcresult`, passed but covered
  A-to-B only. Review correctly treated it as preliminary because a path-only
  guard could also pass that shape.
- The strengthened test captures in A, activates B, reactivates A with a new
  epoch, then releases the old A callback. Final result
  `build/xcode-results/2026-07-13-stale-watcher-callback-green2-8gib.xcresult`
  executed one test: one passed, zero failed, zero skipped.
- Final preflight recorded 6,259.06 MiB swap used, 68% free memory, zero
  throttled pages, 739 GiB available disk, and no competing Xcode/compiler/
  model/Epistemos runtime. It passed the owner's below-8-GiB ceiling.
- The sole current app is
  `/private/tmp/Epistemos-StaleWatcherGreen2-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `2e141a872572b10413e34086026a317ec5ab3adae5b9c22e2b5cd0cd045767dd`.
  No archive exists.

**Contradictions and exact next action**

- Stale ingress is green, but an already-started processor remains an
  untracked detached task that can mutate/index, spawn recall work, and publish
  through global current-vault state before the token-gated checkpoint leg.
- Add the deterministic already-running processor drain regression next. Track
  its handle and lifecycle token, reject post-suspension publication, and await
  it before actor/search teardown and security-scope release. Keep the smaller
  seeded-pending-state stop test as a sibling proof, not a substitute for
  processor ownership.

### Thirty-fourth checkpoint — watcher-processor admission proof and ordered-result debt

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same KEELSTONE lifecycle chain from the recorded watcher-
  processor boundary, rerun the exact failed regressions after the laptop
  restart, and preserve every already-proven result.
- Do not treat a narrow green as completion while overlapping watcher batches,
  partial-mutation publication, child-task ownership, or deterministic waiting
  remain unproved.

**Hard constraints and non-goals**

- A processor must acquire lifecycle admission before leaving the main actor;
  teardown must retain the actor, vault URL, and security scope until that
  admission finishes.
- Checkpoint and mutation publication belong to the token-gated outer task, not
  to ambient global current-vault state. Draining or stale sessions publish
  neither.
- Multiple accepted watcher batches must preserve acceptance order, and a
  stored FSEvent checkpoint may never move backward.
- If a batch commits any mutation before a later failure, the active session
  must receive one mutation publication, while the incomplete batch must not
  advance its checkpoint.
- This checkpoint does not claim ownership of processor-spawned recall/index
  children, hybrid migration, graph/manifest/body cleanup, structural mutation
  coverage, durable identity recovery, manual runtime behavior, or release
  readiness.

**Current exact evidence**

- Pre-correction result
  `build/xcode-results/2026-07-13-watcher-processor-drain-red1-8gib.xcresult`
  executed three tests: one passed and two failed. Both processor tests observed
  zero active admissions; stop completed and released the security scope while
  the cancellation-ignoring processor remained suspended.
- Current source registers the watcher processor with the shared
  `VaultMutationAdmission` drain before detaching work. Completion removes the
  admission on the main actor, then requires the exact operational lifecycle
  token before publishing a checkpoint or `.vaultChanged` event. The static
  worker returns a data-only processing result and no longer publishes through
  `AppBootstrap.shared` unconditionally.
- The first corrected build/result bundle,
  `build/xcode-results/2026-07-13-watcher-processor-drain-green1-8gib.xcresult`,
  compiled successfully but selected zero tests because the Swift Testing
  identifiers omitted their required `()` suffix. It is invalid evidence and
  is not counted as green.
- The corrected identifiers were run with `test-without-building` against that
  exact fresh app. Accepted result
  `build/xcode-results/2026-07-13-watcher-processor-drain-green2-8gib.xcresult`
  executed three tests: three passed, zero failed, zero skipped. It proves
  seeded pending state clears on stop, stop holds the exact scope while one
  cancellation-ignoring processor remains active, and one started processor
  cannot publish or checkpoint across a same-path/new-epoch reattachment.
- Build preflight recorded 6,390.94 MiB swap used, 69% free memory, zero
  throttled pages, 738 GiB available disk, and no competing Xcode/compiler/
  model/Epistemos runtime. The exact-binary rerun preflight recorded 6,610.31
  MiB swap used, 67% free memory, zero throttled pages, and 736 GiB available
  disk. Both passed the owner's below-8-GiB ceiling.
- The sole current app is
  `/private/tmp/Epistemos-WatcherProcessorGreen1-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `251f0e1fd1e12017d12b391abd516d988339c57d52dbf90e35877adfc74e0d19`.
  No archive exists.

**Contradictions and exact next action**

- Independent detached processors can still overlap and complete out of event
  order, allowing an older batch to mutate after a newer batch and regress the
  stored checkpoint. The three-test Green2 covers only one processor at a time.
- A batch that mutates successfully and then fails later currently reports
  `(didProcess: false, didMutate: false)`; the caller suppresses the required
  mutation publication and can leave the UI stale.
- The existing tests also contain arbitrary bounded `Task.yield()` polling,
  which is not a durable completion witness.
- Add deterministic red tests for ordered multi-batch execution and the
  `(false, true)` partial-mutation result. Then serialize accepted watcher
  processors per lifecycle, make checkpoint persistence monotonic, publish
  mutations independently of full-batch success, and expose an awaitable
  processor/drain completion seam. Rerun the focused batch before moving to
  processor-spawned child and hybrid-migration ownership.

### Thirty-fifth checkpoint — ordered watcher completion and single refresh ownership

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Resume the exact interrupted watcher evidence leg without discarding the
  prior red results, changing execution keys, or treating the laptop restart
  as permission to skip failed work.
- Finish the accepted-batch ownership contract, remove adjacent proven
  watcher-path duplicate work, retain one current app product, and continue
  directly into processor-spawned child-task ownership.

**Hard constraints and non-goals**

- Accepted watcher batches run FIFO with exactly one detached processor at a
  time. Every queued batch owns a mutation admission from acceptance through
  checkpoint and synchronous event publication.
- Mutation publication is independent of full-batch success. Any incomplete
  batch blocks all later checkpoint advancement for that exact lifecycle;
  stored checkpoint values are also monotonically nondecreasing.
- The normal `.vaultChanged` EventBus subscription is the sole ambient-
  manifest refresh owner. Watcher completion may not schedule a duplicate
  direct refresh.
- This checkpoint does not claim lifecycle ownership of the processor's
  detached Instant Recall/index children, hybrid migration, structural page
  mutations, durable identity recovery, broad runtime behavior, or release
  readiness.

**Current exact evidence**

- Ordering/partial Red1,
  `build/xcode-results/2026-07-13-watcher-processor-ordering-red1-8gib.xcresult`,
  executed five tests: three passed and two failed. The partial mutation
  published zero events, and an older completion regressed checkpoint `94002`
  to `94001`. Its disposable app executable SHA-256 was
  `d56e3c9b47580ca9a73d011ce1b04f4f425a2973908fba913e2ec4f585c1d685`.
- FIFO/failure-barrier Red2,
  `build/xcode-results/2026-07-13-watcher-processor-ordering-red2-8gib.xcresult`,
  executed two tests and failed both with five issues: two processors were
  running with zero queued instead of one/one, FIFO ended at checkpoint
  `95001`, the failed batch exposed only one of two mutations, and the later
  success advanced to `96002` instead of retaining `96000`. Its disposable
  app executable SHA-256 was
  `853d6ce194c7fc70de2edb2b32dbe3c93a385e49633349cb17e4e4f2f4a1b5c1`.
- Current source owns an immutable accepted-batch FIFO on the main actor,
  starts exactly one processor, keeps each admission through result handling,
  drains already-admitted queued work during stop, and suppresses stale or
  draining completion. It publishes `didMutate` independently, establishes a
  lifecycle failure barrier on `didProcess == false`, preserves partial-
  mutation truth from the static catch, and refuses checkpoint regression.
- The queue periodically compacts its consumed prefix so sustained ingress
  cannot retain every historical batch. The watcher no longer makes a direct
  ambient-manifest refresh request after `.vaultChanged`; AppCoordinator's
  standard event subscription remains the sole refresh owner.
- `build/xcode-results/2026-07-13-watcher-processor-ordering-green1-8gib.xcresult`
  is invalid evidence: the invocation omitted `CODE_SIGNING_ALLOWED=NO`, Xcode
  stopped at provisioning before compilation, produced no app, and executed
  zero tests. The failed DerivedData was removed before retry.
- Preliminary Green2,
  `build/xcode-results/2026-07-13-watcher-processor-ordering-green2-8gib.xcresult`,
  executed seven tests: seven passed, zero failed, zero skipped. Its disposable
  app executable SHA-256 was
  `3d50b6213c2df8d1b2ea7565fa93a3f45d81d77c27fb3ed2e65f199fe9b20749`.
- Accepted final Green3,
  `build/xcode-results/2026-07-13-watcher-processor-ordering-green3-8gib.xcresult`,
  executed eight tests: eight passed, zero failed, zero skipped. It includes
  stop cleanup, cancellation-ignoring processor drain, same-path/new-epoch
  suppression, partial-mutation publication, monotonic checkpointing, FIFO,
  lifecycle failure barrier, and the single ambient-refresh owner guard.
- Red1, Red2, unsigned-retry, and final preflights respectively recorded
  6,610.31, 6,866.94, 6,858.94, and 6,834.81 MiB swap used; 70%, 70%, 71%,
  and 69% free memory; zero throttled pages; at least 737 GiB disk; and no
  competing runtime. Every executed build passed the below-8-GiB owner gate.
- Exactly one current unsigned Debug test app remains at
  `/private/tmp/Epistemos-WatcherProcessorOrderingGreen3-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `a64ca84207213bf0c085c5977a702b52f4cff91a92c158ac37a34234453fdc27`.
  No current archive exists.

**Contradictions and exact next action**

- The outer watcher processor is now ordered and drained, but it still invokes
  detached Instant Recall/index scheduling functions whose tasks are not owned
  by the accepted batch admission. They can outlive stop or a same-path epoch
  replacement and may apply old-session derived state.
- Add deterministic cancellation-ignoring child-task drain and same-path epoch
  regressions next. Move or wrap those children under explicit lifecycle/task
  ownership, await them before finishing the batch admission, and gate every
  child publication by the exact token. Then prove hybrid/post-import child
  ownership before structural mutations or durable-journal recovery.

### Thirty-sixth checkpoint — watcher Recall child ownership and prepared apply

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same KEELSTONE evidence chain from the processor-child boundary
  without reopening canon features, changing the execution key, or accepting a
  preliminary build that predates the current source.
- Make watcher-triggered Instant Recall work part of the retained FIFO batch so
  stop and same-path epoch replacement cannot release scope or accept old-vault
  derived state before that work finishes.

**Hard constraints, non-goals, and acceptance checks**

- Recall preparation stays off the main actor. The main-actor apply receives a
  prepared Sendable payload and performs no full-vault text mapping.
- The exact lifecycle token is rechecked immediately before synchronous apply;
  checkpoint persistence and `.vaultChanged` publication follow that apply and
  remain inside the same mutation admission.
- A partially committed batch applies its derived-state correction and
  publishes its mutation but does not advance the FSEvent checkpoint.
- `VaultIndexActor.removePageArtifacts` may not launch a second ambient Recall
  task. Duplicate cleanup must force a rebuild when exact deleted IDs are not
  available.
- Before every build, delete the previous app/DerivedData and retain only one
  current app. Build serially only when swap is below 8 GiB, free memory is at
  least 25%, pages throttled are zero, and no competing build/model/app process
  exists.
- This checkpoint does not claim ownership of initial-import/manual-sync
  Recall tasks, hybrid migrations, SearchIndex change publication, folder/body/
  toast/Spotlight children, structural mutations, durable-journal recovery,
  broad runtime behavior, or release readiness.

**Current exact evidence**

- Valid pre-correction Red3 is retained at
  `build/xcode-results/2026-07-13-watcher-recall-child-red3-8gib.xcresult`.
  It executed three tests: zero passed and three failed with twelve issues.
  Stop released admission/scope and accepted old Recall work; same-path epoch
  replacement also accepted old Recall work; and artifact removal still owned
  an independent ambient Recall task. Its disposable executable SHA-256 was
  `8ade1f9a74afb12e896da4441785835dbd2a3722d3a29cdf0a7e88bab83ffa9c`.
- Red1 is invalid evidence because compilation stopped before tests after the
  new value types inherited default `MainActor` isolation. Red2 is invalid
  because identifiers without `()` selected zero tests. Both disposable build
  trees were removed before retry; their result bundles remain retained.
- Current source carries `VaultPostImportRecallWorkload` through the processing
  result. The retained detached FIFO processor awaits Recall preparation and
  sends a prepared incremental or dictionary-rebuild payload to main-actor
  completion. Completion rechecks the exact operational token, applies Recall
  synchronously, then owns checkpoint/event/admission completion.
- `VaultIndexActor.removePageArtifacts` no longer launches a direct Recall
  child. Duplicate removal marks change IDs incomplete so the derived-state
  workload becomes a rebuild rather than an incomplete incremental update.
- Preliminary Green1 executed eleven tests with eleven passes and executable
  SHA-256
  `0fc6d72c1b825f434bc30ba62a286273980cdbd0433a68bcd134cfd602ef363f`,
  but it is not current-source proof: the prepared-dictionary/atomic-replace
  refinement and its tests were edited after that run. Its app was deleted.
- Accepted Green2 is
  `build/xcode-results/2026-07-13-watcher-recall-child-green2-8gib.xcresult`.
  Direct `xcresulttool` inspection reports thirteen executed, thirteen passed,
  zero failed, zero skipped. The batch covers prior watcher drain/order/barrier
  contracts, cancellation-ignoring Recall drain, same-path/new-epoch rejection,
  partial-mutation Recall application, single Recall ownership, scoped off-main
  preparation guards, and real `InstantRecallService` replacement/reset plus
  async whitespace filtering.
- Green2 preflight recorded branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, 108 dirty entries, 6,929.12 MiB
  swap used, 69% free memory, zero throttled pages, 735 GiB available disk, and
  no competing runtime. Post-run state recorded 6,957.62 MiB swap, 66% free
  memory, zero throttled pages, and 734 GiB disk. Two orphaned `ibtoold` helpers
  were verified as parentless build leftovers and reaped; the final competing-
  process scan is empty.
- Exactly one current unsigned Debug test app remains at
  `/private/tmp/Epistemos-WatcherRecallChildGreen2-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `dc83df74cadf7576efd29a2ff872e06d238aa32e83eca1e7be55bb9831c02629`.
  No archive exists.

**Contradictions and exact next action**

- Watcher Recall is now batch-owned, but initial import and manual sync still
  use unowned Recall scheduling, hybrid migrations are launched independently
  and can race initial import, SearchIndex notifications escape through an
  ambient main-actor task, and folder/body/toast/Spotlight children remain
  unowned. Full rebuild replacement may also release the old dictionary on the
  main actor, while incremental apply performs bounded text checks/mutations
  there; retain both as performance follow-up rather than overstating proof.
- Add deterministic red tests for hybrid migration ordering and cancellation-
  ignoring initial-import child drain. Fold hybrid migration and required
  post-import Recall/search/Spotlight work into the retained initial-import
  lifecycle before its admission/task completes, reject stale publication by
  exact token, then rerun a fresh focused batch under the one-app resource rule.

### Thirty-seventh checkpoint — retained hybrid migration before initial import

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue directly from watcher Recall into the first initial-import child:
  preserve both one-time hybrid migrations, but make their execution ordered,
  cancellation-visible, and scope-owned rather than deleting or bypassing them.

**Hard constraints, non-goals, and acceptance checks**

- Required order inside the retained task is `migrateToHybridSync` then
  `migrateFromExternalStorage`, then an exact operational token/cancellation
  check, then core initial import.
- Stop must remain incomplete and retain the exact vault URL/security scope
  while a migration ignores cancellation.
- The test override may not touch `UserDefaults.standard` migration keys.
- This checkpoint does not claim that FSEvent processing is buffered during
  import or that post-import Search/Spotlight/Recall and later maintenance
  children are owned.

**Current exact evidence**

- Red result
  `build/xcode-results/2026-07-13-hybrid-migration-ownership-red1-8gib.xcresult`
  executed two tests: one passed and one failed with two issues. The source
  guard located the migration call after `didImport` and inside a separate
  utility task. The runtime drain test passed pre-correction but was explicitly
  not counted as proof because the still-running import task could be the
  unrelated reason stop remained suspended. Red executable SHA-256:
  `c0840d9201f1666b047df6d2939315d69d4f6312172c58a6cd2ad01cb0efff79`.
- Current source invokes the migration helper inside the single retained
  `importTask`, before `didImport`, and rechecks cancellation plus exact
  operational epoch/path immediately afterward. The separate task is gone.
- Accepted Green1,
  `build/xcode-results/2026-07-13-hybrid-migration-ownership-green1-8gib.xcresult`,
  executed three tests: three passed, zero failed, zero skipped. In combination,
  they prove source ownership/order, scope retention during a cancellation-
  ignoring migration, and exact behavioral order `migration-started` →
  `migration-finished` → `import-started`.
- Red preflight recorded 6,917.62 MiB swap used, 68% free memory, zero
  throttled pages, 735 GiB disk, and no competitors. Green preflight recorded
  7,026.75 MiB swap, 67% free memory, zero throttled pages, 735 GiB disk, and
  no competitors. Post-run state was 7,026.75 MiB swap, 66% free memory, zero
  throttled pages, and 733 GiB disk. The completed build's parentless
  `ibtoold` helper was reaped and the final process scan is empty.
- Exactly one current unsigned Debug test app remains at
  `/private/tmp/Epistemos-HybridMigrationOwnershipGreen1-8GiB/Build/Products/Debug/Epistemos.app`;
  executable SHA-256:
  `5f046e9ace96197d63446c506d44935deca96dae41d88c1b6734ef643fd50c9e`.
  No archive exists.

**Contradictions and exact next action**

- Initial-import Search diff, outer and inner Spotlight work, and Instant
  Recall still escape retained ownership. Watcher events are captured while
  import runs but can currently drain into actor processing before the full
  retained initial pipeline is ready. Search notification tasks, Spotlight
  timestamp publication, and healthy-body cleanup add further stale-session
  risk.
- Add a deterministic cancellation-ignoring post-import-child stop regression,
  a same-path/new-epoch no-apply regression, a normal exactly-once pipeline
  regression, and watcher-buffering proof. Then await Search diff, every
  Spotlight batch, and Recall preparation serially; perform a final exact-token
  check before synchronous Recall apply; drain buffered watcher work once; only
  then publish ready/progress/event/maintenance state.

### Thirty-eighth checkpoint — truthful initial readiness after owned derived work

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Resume the same KEELSTONE release-gate evidence chain without losing the
  interrupted checkpoint, reopening feature/canon work, or treating a partial
  test result as completion.
- Finish the retained initial-import pipeline so `Vault ready`, the success
  toast, healthy-maintenance publication, and watcher admission are impossible
  after a nil import snapshot, failed required derived leg, failed buffered
  watcher reconciliation, stale lifecycle token, or detected recovery issue.

**Hard constraints, non-goals, and acceptance checks**

- Keep the canonical key
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`, MAS-only Free V1 boundary,
  owner-dirty worktree, and exact branch/HEAD. Do not launch the app, load a
  model/provider, access secrets/audio, create an archive, or begin new canon
  features in this leg.
- Core import must reject a missing snapshot. Search, legacy Spotlight, typed
  Spotlight, and Recall must report completion through the retained parent;
  exact token/cancellation checks remain between legs and before publication.
- Initial-import page ingestion may not emit one unowned Search notification
  per page. The owned Search leg must populate the index and await its required
  notification before later derived work.
- Buffered watcher work may be admitted before public readiness only through an
  explicit private drain. Its completion fence must carry success, and a failed
  batch must remain recoverable rather than losing cleared paths/checkpoint
  intent or allowing ready publication.
- Recovery validation must evaluate the just-completed import without first
  opening the public `initialImportCompleted` gate. A recovery issue is failure,
  not successful post-import maintenance.
- Spotlight success may not advance a cross-vault/global cursor, skip notes
  permanently behind a fixed cap, or swallow a required legacy/typed indexing
  failure. System acknowledgement is not a claim that Spotlight search results
  are already visible.
- Before every build, delete the preceding app/DerivedData and run serially only
  below 8 GiB swap, at or above 25% free memory, with zero throttled pages and no
  competing build/model/Epistemos runtime. Retain exactly one current app for
  the active evidence leg.
- This checkpoint does not claim release readiness, manual-sync closure,
  structural-mutation/journal recovery, broad performance completion, or any
  feature/canon implementation.

**Current exact evidence**

- The first correction build stopped at compile time because the completion
  fence inherited actor isolation; its retained result is
  `build/xcode-results/2026-07-13-initial-derived-ownership-green1-8gib.xcresult`
  and it executed zero tests. The fence declaration was corrected; this is not
  green evidence.
- The next retained result,
  `build/xcode-results/2026-07-13-initial-derived-ownership-green2-8gib.xcresult`,
  executed 22 tests: 20 passed and two source-contract assertions failed. Both
  assertions refer to safer current shapes (`InitialImportResult` and a strong
  processor-owned `self`) and must be updated semantically, not by weakening
  behavior.
- Review of that current patch found additional false-ready paths: nil import
  snapshots are accepted; recovery issues return maintenance success; watcher
  fences carry no result and failed cleared batches are not requeued; initial
  Search population still emits ambient per-page notifications; and Spotlight
  uses a global cursor, newest-first 1,000-row cap, swallowed errors, and an
  unconditional timestamp advance.
- The Green2 disposable executable was SHA-256
  `1c63f976564eefcd8b6e8f12e340f3d9060c07253f0d83da7da5e01ff2ce8e27`
  (40,344 bytes). It and its exact DerivedData tree were removed. The `.xcresult`
  and log remain retained. Post-run resources were 7,315.06 MiB swap, 69% free
  memory, zero throttled pages, and 732 GiB available disk; no competing build,
  model, or Epistemos runtime was present.

**Contradictions, questions, and exact next action**

- The retained parent now owns the broad derived sequence, but its success
  types and publication order are still too weak to make readiness truthful.
  The unresolved design question is limited to the smallest cursor/batching
  shape that preserves Spotlight completeness without turning startup into an
  unbounded hot-path allocation; no product choice is needed from the owner.
- Add focused failing regressions for import/watcher failure readiness and
  cursor/error ownership, correct the two stale guards, then implement the
  smallest fail-closed result-bearing pipeline. Inspect the diff and run one
  exact serial focused batch after a fresh resource preflight.

### Thirty-ninth checkpoint — post-Green3 truth audit under the 8-GiB ceiling

**Owner wording (exact excerpt)**

> “as if we never stopped please”

**Interpreted intent**

- Continue the same KEELSTONE evidence leg through its real correctness gaps;
  do not stop at an eight-of-nine result or make the stale source assertion
  pass while known false-ready, permanent-omission, or deletion defects remain.
- Preserve the interrupted state and strict owner resource limit so another
  build begins only after an exact fresh below-8-GiB preflight.

**Hard constraints, non-goals, and acceptance checks**

- Keep branch `feat/goose-surface`, HEAD/publication SHA
  `668b52cfb43721de95db102260d9f327ae24e13e`, the active
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` key, MAS-only Free V1
  boundary, owner-dirty worktree, and the one-current-build rule. A fresh
  remote fetch must continue to match the handoff publication, local HEAD, and
  `origin/feat/goose-surface` without reset or overwrite.
- No app-source edit or new build/test may begin while swap is at or above
  8 GiB. Documentation may record the stop. No app launch, owner-vault access,
  archive, model/provider/secret/audio operation, feature/canon implementation,
  or payment work belongs to this leg.
- Initial readiness must drain every watcher batch already known to the main
  actor, including work that arrives while an earlier buffered fence or
  recovery check is suspended. A failed batch must be recoverable, and no
  full-rescan success may advance an FSEvent checkpoint while known deletions
  remain unreconciled.
- Required Search input fetches may not collapse failure into an empty vault;
  a missing full-page projection may not be silently skipped; and Search may
  not announce page/block readiness when block reconciliation errors were
  swallowed or never performed.
- Spotlight cleanup must not leave a vault-scoped cursor that can skip content
  after the corresponding index was cleared. Legacy and typed entity deletion
  are distinct Apple APIs; neither unawaited legacy-only deletion nor an
  indexing completion may be represented as stronger proof than Apple
  documents.
- The focused done bar is fresh deterministic red evidence for each corrected
  behavior, surgical implementation, a current-source focused green batch,
  direct result inspection, disposable executable identity, post-run resource
  recording, and removal of that app before any next build. Manual-sync child
  ownership and unrelated performance/features remain subsequent debt.

**Current exact evidence**

- Green3 is retained at
  `build/xcode-results/2026-07-13-initial-readiness-green3-8gib.xcresult`:
  nine executed, eight passed, one stale source-string failure, zero skipped.
  Its disposable 40,344-byte executable SHA-256 was
  `ef8ce1a3e6124cf9c62375c19a9b7d552de585fc63cbb8ee1601ae6449a168ca`;
  its app/DerivedData tree was removed while result/log evidence was retained.
- Green3 began at 7,456.88 MiB swap, 68% free memory, zero throttled pages,
  734 GiB disk, and no competitors. Post-run swap rose to 8,363.38 MiB; after
  build deletion it remained 8,347.38 MiB and then 8,323.38 MiB, above the
  strict threshold. No later app-source correction or build began.
- A fresh remote fetch after Green3 resolved the handoff publication commit,
  local HEAD, and `origin/feat/goose-surface` to the same full SHA
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Read-only source review found these current-leg gaps:
  - readiness performs only one buffered drain, so a known event arriving
    during the fence/catch-up/recovery suspension can remain pending while
    `initialImportCompleted` and the ready event are published;
  - the watcher full-rescan branch imports with missing-file deletion disabled,
    ignores explicit deleted paths, and can nevertheless advance the durable
    FSEvent checkpoint;
  - a failed batch establishes a checkpoint barrier with no proven successful
    reconciliation/clear transition;
  - `allPageTimestamps` converts a required SwiftData fetch failure into `[]`,
    which Search diff can interpret as an authoritative empty vault, while a
    nil full-page provider is silently omitted;
  - initial page/block writers suppress or swallow some errors, but the owned
    notification currently announces both page and block dependencies;
  - local Spotlight clearing is unawaited and legacy-only while the per-vault
    cursor survives; typed `IndexedEntity` deletion uses the legacy searchable-
    item API rather than Apple's typed `deleteAppEntities` API.
- Apple’s current official Core Spotlight documentation confirms that the
  async indexing completion means the request was journaled and must be retried
  on error; it does not mean results are already searchable. Apple separately
  documents `deleteAppEntities(identifiedBy:ofType:)` for typed entities.

**Contradictions, questions, and exact next action**

- The Green3 runtime regressions are valuable but insufficient for a green
  claim. The only unresolved design choices are implementation details that
  can be decided locally: how to loop the pre-ready drain to a main-actor-empty
  instant without an uncontrolled spin, how to represent a recoverable
  checkpoint barrier, and how to propagate required Search/block/typed
  Spotlight errors without adding an unbounded startup allocation.
- Continue read-only auditing while the resource ceiling is red. When a fresh
  preflight is strictly below 8 GiB, first add deterministic red tests for the
  late buffered-event race, full-rescan deletion/checkpoint behavior, required
  Search fetch/provider failure, page/block notification truth, cursor reset,
  and typed deletion. Then make the smallest fail-closed corrections, update
  the two genuinely stale audit/source guards, and run one serial focused batch.

### Fortieth steer — raise the active resource ceiling to 10 GiB

**Owner wording (verbatim)**

> “u can run it birng it to 10gb limit at 10gb”

**Interpreted intent**

- Supersede the prior strict below-8-GiB swap ceiling with a strict
  below-10-GiB ceiling so the existing Keelstone evidence leg can resume now.
- Keep every other safety, ownership, and evidence boundary unchanged.

**Hard constraints and non-goals**

- Swap used must be strictly below 10 GiB (10,240 MiB); system free memory must
  remain at or above 25%; pages throttled must remain zero; and no competing
  Xcode build, compiler, model, or Epistemos runtime may be active.
- Before every build/test/archive, delete stale Epistemos app products and
  archives from the active build locations and retain only the one current app
  artifact for that evidence leg. Run no competing `xcodebuild` process.
- This steer changes only the resource ceiling. It does not authorize an app
  launch, owner-vault access, archive, model/provider/secret/audio operation,
  payment work, hidden Free V1 surface work, new feature/canon implementation,
  or a subsequent canonical execution key.

**Acceptance checks and exact next action**

- Refresh branch, local/remote/publication SHA equality, dirty count, swap,
  free-memory percentage, throttled pages, disk, competing processes, and stale
  app/archive inventory.
- If the complete preflight passes the new ceiling, add the deterministic
  failing regressions already recorded for the initial-derived-readiness leg,
  inspect the test diff, remove any stale app product, and run exactly one fresh
  serial focused red batch before implementation correction.

### Forty-first steer — raise the active resource ceiling to 12 GiB

**Owner wording (verbatim)**

> “let the ceilig be 12gb now”

**Interpreted intent**

- Supersede the strict below-10-GiB swap ceiling with a strict below-12-GiB
  ceiling for the same continuing Keelstone evidence leg.
- Keep every other safety, ownership, product, and evidence boundary unchanged.

**Hard constraints, non-goals, and acceptance checks**

- Swap used must be strictly below 12 GiB (12,288 MiB); system free memory must
  remain at or above 25%; pages throttled must remain zero; and no competing
  Xcode build, compiler, model, or Epistemos runtime may be active.
- Before every build/test/archive, delete stale Epistemos app products and
  archives from active build locations, run only one serial `xcodebuild`, and
  retain only the one current app artifact for the active evidence leg until
  its identity is recorded and the complete disposable build tree is removed.
- This steer changes only the resource ceiling. It does not authorize an app
  launch, archive, owner-vault access, model/provider/secret/audio operation,
  payment work, hidden Free V1 surface work, feature/canon implementation, or
  a subsequent canonical execution key.
- The pre-edit identity/resource reading taken immediately before this steer
  already passed the stricter former ceiling: branch/remote/publication SHA
  matched, swap was 8,576.56 MiB, free memory was 70%, throttled pages were
  zero, disk was 731 GiB, and app/archive inventory was empty. Recheck the full
  gate before the next build.

**Exact next action**

- Add only the deterministic Recall rebuild-failure and required Search
  timestamp-read regressions already scoped by the Green5 hardening audit.
  Inspect the diff, run one fresh serial focused batch after another complete
  12-GiB preflight, preserve exact red/green evidence, and make no production
  correction unless current behavior fails the asserted contract.

### Execution progress under the forty-first steer — Green6

**Proven state**

- The strict below-12-GiB resource gate passed immediately before Green6.
- The combined sixteen-test Green6 batch passed with zero failures, zero
  expected failures, and zero skips.
- The batch closes the focused required Search timestamp-read failure, required
  Recall rebuild-source failure, startup failed-preparation readiness fence,
  and both-owner Search source guard alongside all twelve Green5 contracts.
- The exact disposable executable identity was recorded, the complete build
  tree was deleted, the final app/archive inventory was empty, and the final
  resource reading remained inside every owner threshold.

**Remaining constraints and non-goals**

- The KEELSTONE verdict remains `INCOMPLETE`; Green6 is not Release archive,
  artifact-gate, manual-runtime, owner-vault, or finite-matrix evidence.
- Do not begin canon/feature work, payment/account work, hidden Free V1 lanes,
  model/provider/secret/audio operations, or another canonical execution key.
- Continue to require a complete 12-GiB preflight, one serial Xcode process,
  and deletion of stale/current disposable app products before every build.

**Exact next action**

- Add the smallest failing behavior regression for the public Search page
  deletion contract: seed one indexed page plus one page-owned block, invoke
  `SearchIndexService.delete(pageId:)`, and require both rows to disappear in
  one receipt-bearing operation with exact page/block dependencies. Inspect the
  red result before authorizing the minimal shared atomic-deletion correction.

### Red6 execution checkpoint — public Search deletion

**Proven state**

- The complete 12-GiB preflight passed with exact local/remote/handoff
  identity, 8,759.38 MiB swap, 70% free memory, zero throttled pages, no
  competing process, and an empty app/archive inventory.
- One serial one-test Red6 batch failed at exactly one assertion: the public
  page deletion removed the page but left its page-owned block searchable.
- The result/log and disposable executable identity were recorded. The whole
  build tree was removed and the final app/archive inventory was empty.

**Authorized correction and non-goals**

- Reuse the existing `deletePageRows(ids:in:)` helper in one GRDB transaction;
  do not duplicate its SQL and do not add a schema migration.
- Return exact page/block deletion counts with receipt-derived dependencies;
  notify once only after commit and only when a changed dependency exists.
- Replace the two production page-delete plus swallowed block-delete sequences
  with the single atomic operation while preserving notification suppression.
- Do not broaden into rebuild, Spotlight, Recall, Eidos, archive/runtime,
  feature/canon, payment, model/provider/secret/audio, or owner-vault work.

**Exact next action**

- Apply only that shared atomic-deletion correction, strengthen the Red6 test
  with exact receipt assertions plus a source guard for both production owners,
  inspect the diff, then run one fresh serial focused Green7 batch only after a
  new complete 12-GiB preflight.

### Green7 execution checkpoint — public Search deletion

**Proven state**

- The complete 12-GiB Green7 preflight passed with exact local/remote/handoff
  identity, 8,841.25 MiB swap, 69% free memory, zero throttled pages, no
  competing process, and an empty app/archive inventory.
- One serial nineteen-test App Store batch passed with zero failures, expected
  failures, or skips. It included every Green6 test plus public deletion
  receipts, forced transaction rollback, and both-owner source ownership.
- The exact disposable executable identity was recorded, the complete build
  tree was deleted, final app/archive inventory was empty, and post-cleanup
  used swap was 8,990.25 MiB—below the strict 12,288-MiB ceiling.

**Remaining constraints and verification debt**

- The general integration and production-hardening test files modified for
  contract parity are not in the active App Store scheme and remain unexecuted.
- Initial import still lacks an aggregate Search mutation/notification receipt
  when suppressed import writes make the later owned diff empty.
- Page-only full rebuild block reconciliation, global Search notification
  correlation, Spotlight receipts/ownership, authoritative-rescan truth,
  Release artifact gates, and finite Free V1 runtime evidence remain open.
- Do not begin feature/canon, payment, model/provider/secret/audio, owner-vault,
  archive, or subsequent-key work while this evidence chain remains active.

**Exact next action**

- Ground the next smallest independent Keelstone debt against current source
  and existing tests. Prefer the initial-import aggregate Search receipt gap if
  it can be expressed as one deterministic failing App Store behavior test;
  otherwise record the exact blocker and move to the next bounded typed
  Spotlight or authoritative-rescan receipt leg. Run no build until a new full
  12-GiB preflight passes.

### Forty-second steer — raise and lock the active resource ceiling to 16 GiB

**Owner wording (verbatim)**

> “make it lock at 16gb at this point man”

**Interpreted intent**

- Supersede the strict below-12-GiB swap ceiling with a strict below-16-GiB
  ceiling for the same continuing Keelstone evidence leg.
- Treat 16 GiB as the active locked ceiling until the owner explicitly changes
  it again. Keep every other safety, ownership, product, and evidence boundary
  unchanged.

**Hard constraints, non-goals, and acceptance checks**

- Swap used must be strictly below 16 GiB (16,384 MiB); system free memory must
  remain at or above 25%; pages throttled must remain zero; and no competing
  Xcode build, compiler, model, or Epistemos runtime may be active.
- Before every build/test/archive, delete stale Epistemos app products and
  archives from active build locations, run only one serial `xcodebuild`, and
  retain only the one current app artifact for the active evidence leg until
  its identity is recorded and the complete disposable build tree is removed.
- This steer changes only the resource ceiling. It does not authorize an app
  launch, archive, owner-vault access, model/provider/secret/audio operation,
  payment work, hidden Free V1 surface work, feature/canon implementation, or
  a subsequent canonical execution key.
- Green7 remains the latest executable proof. Its final post-cleanup reading
  was 8,990.25 MiB swap, 69% free memory, zero throttled pages, 728 GiB
  available disk, and an empty app/archive inventory. Recheck the complete gate
  immediately before the next build; do not reuse that historical reading.

**Exact next action**

- Finish the read-only design comparison for the initial-import aggregate
  Search receipt and page-only rebuild reconciliation debts. Select the
  smallest deterministic App Store red leg, add only its failing regression,
  inspect the diff, and run exactly one fresh serial focused red batch only
  after a complete 16-GiB preflight passes.

### Forty-third checkpoint — select the page-only Search rebuild red leg

**Owner intent and canonical execution key**

- Continue the exact in-flight Keelstone evidence chain as though the laptop
  interruption never occurred, preserving every recorded proof and debt under
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- Keep only one current app build, use the locked strict below-16-GiB ceiling,
  and do not begin later feature/canon work until this evidence chain reaches
  its recorded boundary.

**Grounded comparison and decision**

- Current source confirms that initial import mutates Search page and block
  rows while notifications are suppressed, then can receive an empty diff.
  Truthful aggregate ownership would require new mutation receipts across the
  actor's swallowed page and block write seams, so it is not the smallest
  independent next red.
- Current source also confirms a narrower deterministic defect:
  `rebuildFromSwiftData` deletes and reinserts only `indexed_pages`; its schema
  has no page-to-block cascade, so `indexed_blocks` rows survive as searchable
  orphans. The direct service behavior needs no test seam or production change
  to demonstrate.
- Select the rebuild-orphan leg now. Keep the initial-import aggregate Search
  receipt as explicit verification debt rather than weakening its truth bar.

**Hard constraints and done bar**

- Before execution, re-verify exact local/remote/handoff identity, dirty count,
  swap below 16,384 MiB, free memory at least 25%, zero throttled pages, disk,
  no competing scoped process, and empty app/archive inventory.
- Add one App Store behavior test only: seed one page and one owned block, prove
  both are searchable, call the current async rebuild with an empty source,
  prove the page is gone, and require the block to be gone.
- The red bar is an exact block-survival failure with the page-removal assertion
  passing. Do not modify production until that evidence is recorded.
- A later correction must remain one transactional rebuild contract and must
  not smuggle in initial-import receipts, Eidos redesign, Spotlight, Recall,
  archive/runtime, feature/canon, payment, model/provider/secret/audio, or
  owner-vault work.

**Exact next action**

- Read the neighboring App Store Search tests once more, add only the rebuild
  orphan regression, inspect the diff, then run exactly one fresh serial red
  test after a complete 16-GiB preflight.

### Forty-fourth checkpoint — restore the preferred initial-import Search red leg

**Grounding correction before execution**

- The delayed read-only design pass established that the initial-import
  aggregate Search ownership gap can be expressed as one deterministic App
  Store behavior test after all. That satisfies the preference recorded after
  Green7 and supersedes the forty-third checkpoint's provisional rebuild-first
  selection before any test or build executed.
- The unexecuted rebuild regression draft is removed from this red leg. The
  page-only rebuild orphan defect remains proven source debt and follows as an
  independent later leg; no evidence claim is lost.

**Deterministic red contract**

- Import one temporary Markdown note with unique page and block tokens through
  a fresh `VaultIndexActor` and `SearchIndexService` while Search notifications
  are suppressed.
- Prove both page and block projections committed and no notification fired.
- Run a direct suppressed diff and require its receipt to be entirely unchanged
  with empty dependencies; then invoke the current owned diff wrapper.
- Require exactly one awaited notification carrying both `.searchPages` and
  `.searchBlocks`. Current source is expected to return success but emit none,
  producing one exact dependency-snapshot failure.

**Correction boundary if red is proven**

- Use truthful mergeable committed Search mutation receipts; do not infer
  Search success from vault import source IDs.
- Accumulate only successful suppressed page/block/deletion mutations, mark
  swallowed Search write failure as invalid, merge with the owned diff receipt,
  publish once before enabling normal notifications, and retain pending truth
  on failed/cancelled diff.
- Do not absorb rebuild-orphan cleanup, Eidos redesign, Spotlight, Recall,
  archive/runtime, feature/canon, payment, model/provider/secret/audio, or
  owner-vault work into this leg.

**Exact next action**

- Add only the deterministic initial-import Search ownership test, inspect the
  diff, and run exactly that one test after a complete 16-GiB preflight. Make
  no production correction before recording its exact red result.

### Initial-import Search Red8 attempt A — test harness rejected before execution

**Exact evidence**

- The complete 16-GiB preflight passed: exact branch/remote/handoff identity,
  112 dirty entries, 8,926.19 MiB swap, 72% free memory, zero throttled pages,
  728 GiB available disk, no competing scoped process, and empty app/archive
  inventory.
- One serial focused build produced zero executed tests. Swift rejected the
  observer closure because it passed a task-isolated `Notification` into the
  default-main-actor `QueryDependencyKey.from` method. The result is `unknown`,
  not a product-behavior red.
- The retained log SHA-256 is
  `74e48c04807269500ecdf57b2c590247577c3a105ee8b04453fe6a1fc456f3ec`.
  The disposable executable was 40,344 bytes with SHA-256
  `51b811f0a971612b17cb39106ef6aa483e5821a427cb903cb57b15d448b5a400`;
  its bundle occupied 479,084 KiB.
- After recording identity, the entire build tree was deleted. Inventory is
  empty; final resources are 8,918.19 MiB swap, 67% free memory, zero
  throttled pages, and 728 GiB available disk.

**Authorized harness-only correction and next action**

- Decode the notification's existing raw dependency array inside the observer
  closure instead of crossing actor isolation with the `Notification` value.
  Do not change product code or the behavioral assertion.
- Inspect the one-line test correction and rerun exactly the same focused test
  only after another complete 16-GiB preflight.

### Initial-import Search Red8B — exact missing aggregate notification proven

**Proven state**

- The second complete preflight passed with exact local/remote/handoff identity,
  112 dirty entries, 8,918.19 MiB swap, 67% free memory, zero throttled pages,
  728 GiB available disk, no competing scoped process, and empty inventory.
- One serial test ran. The import committed a searchable page and searchable
  owned block with zero suppressed notifications. A direct diff and the owned
  diff each reported zero page upserts, page deletes, and block deletes.
- Exactly one assertion failed: the owned leg returned success, but the
  observed dependency snapshot was `[]` instead of the required single
  `[.searchPages, .searchBlocks]` publication. No other assertion failed.
- Direct result summary is one total, zero passed, one failed, zero expected
  failures, and zero skipped on arm64 macOS 26.3.1. The retained log SHA-256 is
  `76dcae1237dc03481481e2f6e1a4ae06bfdcdae99dfc0c5fd4155ea665c39650`.
- The disposable executable was 40,344 bytes with SHA-256
  `e4e0941945db0dd7da22bfff5de92a3b1ee1106739476effbee770cd7b72c03c`;
  its bundle occupied 490,088 KiB. After identity capture, the entire build
  tree was deleted. Final inventory is empty; resources are 9,347.81 MiB swap,
  70% free memory, zero throttled pages, and 728 GiB available disk.

**Authorized correction boundary**

- Add truthful mergeable committed Search mutation receipts at the existing
  page, block, and atomic deletion seams.
- While notifications are suppressed, accumulate successful page/block
  mutations in `VaultIndexActor`; make a swallowed Search write failure
  invalidate the pending batch rather than publishing source-derived claims.
- Merge the pending receipt with the required owned diff result, publish its
  union once and awaited, consume only after successful publication, and then
  enable normal notification ownership. Failed or cancelled preparation must
  not lose pending mutation truth.
- Keep rebuild-orphan cleanup, global notification correlation, Eidos,
  Spotlight, Recall, archive/runtime, feature/canon, payment, model/provider/
  secret/audio, and owner-vault work out of this correction.

**Exact next action**

- Map every existing Search write and import failure/cancellation owner, apply
  the smallest receipt propagation correction, strengthen Red8B with exact
  receipt/one-publication assertions and source ownership guards, re-read the
  diff, and run no build until a new complete 16-GiB preflight passes.

### Forty-fifth checkpoint — Red8 receipt ownership correction prepared

**Owner intent and interpretation**

- Continue the exact in-flight Keelstone evidence chain under
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`; the latest resource steer
  remains the locked strict below-16-GiB swap ceiling.
- Correct only the Red8B-proven initial-import Search notification gap. A
  successful suppressed import must carry truthful committed page, block, and
  atomic-deletion receipts into the owned diff leg, publish their dependency
  union exactly once, and consume the pending batch only after publication.

**Prepared implementation and acceptance checks**

- `SearchIndexService` now returns typed mutation receipts from page upsert,
  block replacement, and atomic page/block deletion. Notification domains are
  derived from committed row counts rather than vault-source inference.
- `VaultIndexActor` now owns an explicit service-bound mutation batch ID,
  accumulates only successful receipts, invalidates the batch on swallowed
  Search write/read failure, and seals the exact diff receipt before
  publication. While sealed, same-batch writes and Search-service replacement
  are rejected.
- `VaultSyncService` now merges the sealed import and diff receipts, performs
  one awaited lifecycle-checked notification, and consumes the exact
  ID/revision/service batch only after that post succeeds. A vetoed post leaves
  the sealed receipt available for an exact retry without rerunning the diff.
- The Red8B behavior test now requires positive page/block committed counts,
  exact union dependencies, veto-without-consumption, sealed-diff reuse,
  successful one-publication consumption, and no second publication from the
  consumed ID. Existing fail-closed timestamp and source-ownership guards have
  been updated to the typed contract.
- A missing Search service remains a required-derived-leg failure; it cannot be
  converted into a ready vault merely because Search is unavailable.

**Hard constraints, non-goals, and verification debt**

- No build, test, archive, launch, owner-vault access, provider/model/secret/
  audio action, feature/canon work, or subsequent execution key has begun for
  this correction.
- Page-only rebuild orphan cleanup, global notification correlation, broader
  Search/Spotlight receipts, Eidos, Recall, and Release/runtime gates remain
  separate debt.
- Current proof is source inspection plus `git diff --check` only. Swift
  compilation and behavior remain unproven until one fresh serial focused
  Green batch passes after the complete 16-GiB preflight.
- Pre-diff timestamp/diff failure retains an accumulating batch for the exact
  caller to retry and therefore intentionally fails readiness closed. A future
  same-actor restart/recovery policy remains lifecycle hardening debt; it is
  not evidence that Red8 is Green.

**Exact next action**

- Complete the remaining static compile-seam and contradiction sweep, record
  the exact selected Green tests, then re-run branch/remote/handoff identity,
  dirty count, swap below 16,384 MiB, free memory at least 25%, zero throttled
  pages, disk, competing-process, and empty app/archive inventory checks. Only
  if every gate passes, run one serial focused Green build.

### Initial-import Search Green8 preflight — passed

- After fetching origin, branch `feat/goose-surface`, local HEAD, fetched
  `origin/feat/goose-surface`, and the handoff publication commit all resolve
  exactly to `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty entry count remains 112 and `git diff --check` passes.
- Swap used is 9,267.81 MiB, below the locked strict 16,384-MiB ceiling;
  system free memory is 73%; pages throttled are zero; and available disk is
  728 GiB.
- No competing scoped Xcode/compiler/model/Epistemos runtime is active. The
  app/archive inventory across the disposable build locations, DerivedData,
  repository build tree, and Xcode Archives is empty, so there was no stale
  app product or archive to delete.
- The authorized executable leg is one serial twenty-test App Store batch: the
  complete nineteen-test Green7 selection plus the new initial-import Search
  committed-receipt/exact-publication regression. No other build may overlap.

### Initial-import Search Green8 — twenty-test pass

- The one authorized serial batch completed with result `Passed`: 20 total,
  20 passed, zero failed, zero expected failures, and zero skipped on arm64
  macOS 26.3.1.
- The new initial-import Search test passed its complete contract: committed
  page and block receipts, empty owned diff, lifecycle veto without
  consumption or notification, sealed-diff retry, one union notification,
  exact batch consumption, and no repeated publication from the consumed ID.
- The retained result is
  `build/xcode-results/2026-07-14-initial-search-receipt-green8-16gib.xcresult`.
  The retained log is the same basename with `.log`, SHA-256
  `1722b3e93c960f522201fe67eb4867e60e7d6852dca42388da5a967352ebd96f`.
- The disposable app path is
  `/private/tmp/Epistemos-InitialSearchReceiptGreen8-16GiB/Build/Products/Debug/Epistemos.app`.
  Its executable is 40,344 bytes with SHA-256
  `4d8c9241173b453421f6c94f08a209989144fb91471e5dbd9a72660da5cd1273`;
  the bundle occupies 490,368 KiB.
- Immediate post-run resources are 9,557.31 MiB swap, 69% free memory, zero
  throttled pages, and 726 GiB available disk. The corrected executable-name
  process check is empty, dirty count remains 112, and `git diff --check`
  passes.

**Remaining boundary and next action**

- Green8 closes the exact Red8B initial-import aggregate Search notification
  defect under the selected App Store evidence set. It does not prove the
  broader non-App-Store source-guard target, page-only rebuild orphan cleanup,
  global notification correlation, Release archive/artifact gates, manual
  runtime behavior, or the finite matrix.
- Record the app identity above, delete the complete disposable build tree,
  verify empty app/archive inventory and resources, then continue only with
  the next smallest grounded Keelstone debt. Do not start another build,
  archive, runtime launch, feature/canon phase, or execution key as part of
  this cleanup.

### Green8 cleanup — zero current build restored

- After identity capture, the complete disposable Green8 build tree was
  deleted. The retained `.xcresult` and log remain intact.
- App/archive inventory is empty across the disposable temp locations,
  DerivedData, repository build tree, and Xcode Archives. No scoped compiler,
  model, or Epistemos process is active.
- Final resources are 9,549.31 MiB swap, 69% free memory, zero throttled pages,
  and 728 GiB available disk. Dirty count remains 112 and `git diff --check`
  passes.
- The next action is a read-only comparison of the remaining Keelstone debts;
  no additional build is authorized until a new intent checkpoint and fresh
  complete 16-GiB preflight exist.

### Forty-sixth checkpoint — page-only Search rebuild reconciliation

**Verbatim owner steer and interpreted intent**

- Latest exact owner wording: “make it lock at 16gb at this point man”.
- Keep the continuing Keelstone evidence chain under
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`, with swap used required
  to remain strictly below 16,384 MiB before every build. This resource steer
  does not widen the active feature or runtime scope.
- Green8 is complete and its disposable app has been removed. Continue with
  the smallest recorded independent Search freshness debt: a page-only full
  rebuild must not leave blocks from removed pages searchable.

**Grounded current-source contract**

- `SearchIndexService.rebuildFromSwiftData` currently deletes and reinserts
  `indexed_pages` in one database write, but it does not reconcile
  `indexed_blocks`.
- The `indexed_blocks.page_id` column has no foreign-key cascade. The diff and
  public deletion paths already delete page-owned or historical orphan block
  rows transactionally, but the manual full-rebuild path does not.
- The local search-freshness canon explicitly rejects missing FTS rebuild
  proof. Current call sites use this path for the Settings “Rebuild Index”
  action and derived-index recovery, so a surviving block would be stale
  searchable evidence rather than harmless storage residue.

**Hard constraints and non-goals**

- Test first. Add one deterministic App Store behavior test before changing
  production: seed one page and one owned block, prove both are searchable,
  rebuild from an empty authoritative page snapshot, prove the page is gone,
  and require the block to be gone.
- The expected current red is only the surviving block; the page-removal
  assertion must pass. No production correction is authorized until that
  exact behavior is executed and retained.
- Keep the correction transactional and surgical. Do not add a foreign-key
  migration, rebuild block content from another source, redesign Eidos,
  change initial-import receipts, or absorb Spotlight, Recall, global
  notification correlation, archive/runtime, Free V1, canon/feature,
  payment, model/provider/secret/audio, or owner-vault work.
- Preserve the one-current-build rule: fresh empty app/archive inventory,
  one serial Xcode command, exact result/log/app identity capture, then delete
  the disposable build tree.

**Acceptance checks, contradiction handling, and exact next action**

- Red acceptance: one selected test executes; the seeded page disappears;
  the owned block remains and causes the sole expected assertion failure; no
  archive or app launch occurs.
- Later Green acceptance: page and orphan-block removal commit together,
  observers receive only the dependencies that actually changed, existing
  focused Search/Keelstone coverage remains green, and the disposable app is
  identified then removed.
- There is no unresolved owner contradiction. The earlier 12-GiB limit is
  superseded by the latest 16-GiB lock; all other safety gates remain strict.
- Exact next action: finish the independent read-only review, add only the
  failing rebuild regression, inspect the diff, then run exactly one focused
  red test after a fresh complete 16-GiB preflight passes.

### Page-only Search rebuild Red9 — correction authority

**Proven state**

- The complete 16-GiB preflight passed at exact local/remote/handoff SHA
  `668b52cfb43721de95db102260d9f327ae24e13e`, 112 dirty entries,
  9,533.31 MiB swap, 71% free memory, zero throttled pages, 727 GiB disk, no
  competing scoped process, and empty app/archive inventory.
- One serial test executed. Direct result inspection reports one total, zero
  passed, one failed, zero expected failures, and zero skipped. The seeded
  page was removed by the empty-source full rebuild; the sole failure was the
  exact owned block ID/page ID still being returned afterward.
- The retained log SHA-256 is
  `55184b247636a93876af180bea6dde79c007f74850ea3d09a6332ed6a53e802e`.
  The disposable executable is 40,344 bytes with SHA-256
  `b75068400509b07b84f1918917da81d1fb6a607f4b9939325d80f98d83669b16`;
  the app bundle occupies 490,388 KiB.
- This machine executed the Search fallback path because FTS5 feature probes
  were false. Source inspection proves the same orphan base row feeds block
  FTS when available, but no executed FTS5 behavior is claimed.

**Authorized correction and non-goals**

- Extract the existing set-based orphan-block deletion into one shared helper,
  call it inside the full-rebuild transaction only after authoritative pages
  are reinserted, and reuse it from diff sync. This preserves blocks owned by
  retained pages and avoids duplicate cleanup SQL.
- Capture the committed orphan deletion count and include `.searchBlocks` in
  the existing post-commit invalidation only when that count is positive.
  Keep public rebuild signatures unchanged; global notification correlation
  and awaited-publication redesign remain separate debt.
- Strengthen the Green regression so one retained page’s block survives while
  one removed page’s block disappears. Do not let a wholesale block delete
  satisfy the empty-source test.
- Do not change the manual Settings caller’s current source-fetch fallback,
  checkpoint semantics, Eidos mirroring, initial-import receipts, Spotlight,
  Recall, archive/runtime, Free V1, feature/canon, payment, model/provider/
  secret/audio, or owner-vault behavior in this leg.

**Exact next action**

- Record and remove the exact disposable Red9 app build, verify zero current
  build and safe resources, then apply only the shared orphan-cleanup helper,
  rebuild call-site, dependency derivation, and retained-block Green
  assertions. No second build may begin until a new complete 16-GiB preflight
  passes.

### Page-only Search rebuild correction — Green verification boundary

- Red9's disposable app is removed and inventory is empty. The retained result
  and log remain intact.
- The prepared source correction reuses one orphan-block helper, invokes it
  after replacement pages are inserted inside the existing rebuild
  transaction, and derives block invalidation from the committed deletion
  count. It does not truncate all blocks or change public APIs.
- The strengthened test proves the retained page and block exist before
  rebuild and must survive afterward, while the absent owner's page and block
  must disappear. It therefore rejects the two dangerous ordering shortcuts
  that the empty-source red alone could not distinguish.
- Independent post-edit reviews report no actionable source or Swift syntax
  issue. Current static proof is limited to source inspection and
  `git diff --check`; no Green compiler/runtime claim exists yet.
- Verification debt remains explicit: the notification payload is not yet a
  separately correlated observer proof; manual rebuild source-read failure,
  post-commit checkpoint failure, Eidos deletion, and full FTS5 execution are
  outside this leg.
- Exact next action: run a new complete 16-GiB preflight. Only if every gate
  passes, execute one serial twenty-one-test App Store batch containing all
  Green8 tests plus the rebuilt orphan regression. Retain exact evidence and
  delete its disposable build before selecting further debt.

### Page-only Search rebuild Green9 — proven boundary

- The second complete preflight passed at the exact local/remote/handoff SHA,
  112 dirty entries, 9,859.62 MiB swap, 70% free memory, zero throttled pages,
  727 GiB disk, no competing process, and empty current-build inventory.
- One serial batch ran. Direct result inspection reports 21 total, 21 passed,
  zero failed, zero expected failures, and zero skipped on arm64 macOS 26.3.1.
- The rebuilt orphan regression proves removed page/block exact IDs disappear
  and retained page/block exact IDs survive. All 20 Green8 tests remained
  green.
- The retained log SHA-256 is
  `9ed17d263462360e2d5a5108036afd34640d8c6412ddb80192084ad95d68a92d`.
  The disposable executable is 40,344 bytes with SHA-256
  `05121bf186de5a721deacfb901b155718276b11aac60d5861b94ea055898619c`;
  the bundle occupies 490,396 KiB.
- Green9 closes only the exact Red9 orphan-block behavior. FTS5-enabled runtime,
  notification correlation, fail-closed manual source acquisition,
  checkpoint recovery, Eidos deletion, broader suites, Spotlight/remaining
  receipts, archive/runtime, and Free V1 evidence remain open.
- Exact next action: delete the complete disposable Green9 build, verify empty
  app/archive inventory and safe resources, update the INCOMPLETE verdict, and
  read-ground the next smallest remaining Keelstone debt. Do not begin another
  build or canonical execution key as part of cleanup.

### Green9 cleanup — zero current build restored

- The complete disposable Green9 build tree was deleted after exact identity
  capture. Its retained result and log remain intact.
- Final app/archive inventory is empty. Resources are 9,859.62 MiB swap, 69%
  free memory, zero throttled pages, and 727 GiB disk; no scoped process is
  active, dirty count is 112, and `git diff --check` passes.
- The overall verdict remains `INCOMPLETE`. The next action is read-only debt
  comparison, starting with manual full-rebuild source-read ambiguity versus
  the remaining notification/Spotlight receipt gaps. No new build is
  authorized without another intent checkpoint and full 16-GiB preflight.

### Forty-seventh checkpoint — fail-closed manual Search rebuild source acquisition

**Verbatim owner steer**

> “make it lock at 16gb at this point man”

This follows the owner's standing direction to continue the interrupted
Keelstone evidence chain autonomously, rerun failed evidence legs after the
machine reset, retain exactly one current build, and finish earlier unresolved
work before beginning the MAS feature canon.

**Interpreted intent and exact selected debt**

- The build safety ceiling is now durably locked at strictly less than
  16 GiB of swap used. At 16 GiB or above, no build, test build, or archive may
  begin. The other owner gates remain at least 25% free memory, zero throttled
  pages, and no competing Xcode/compiler/model/Epistemos process.
- Continue the same execution key,
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. Do not start a new canon,
  feature, archive, runtime, payment, model, provider, secret, audio, or
  owner-vault leg.
- The next smallest evidence debt is the Settings/manual full Search rebuild.
  `VaultIndexActor.allPagesForRebuild()` currently converts a failed required
  SwiftData source read into the same empty array as a legitimate empty vault.
  `VaultSyncService.rebuildIndex()` then treats that array as authoritative,
  permitting valid Search page and block projections to be removed and an
  update notification to be published.
- Two independent read-only reviews rank this ahead of global Search
  notification correlation and Spotlight receipt ownership because it is a
  direct destructive ambiguity with a small, behavior-testable blast radius.

**Hard constraints and non-goals**

- Test first. Generalize only the existing DEBUG derived-rebuild fault seam and
  add a service forwarder so the test can execute the actual Settings/manual
  rebuild owner. The harness must preserve the current empty-on-read-failure
  behavior for Red10; it must not contain the correction in advance.
- Seed one Search page and one page-owned block without observer publication,
  force the required manual-rebuild source read to fail, invoke the same
  `rebuildIndex()` owner used by Settings, wait for its bounded task to finish,
  and require survival of both exact IDs plus zero Search update notifications.
- After exact Red evidence, the only authorized correction is a distinct
  optional required-Search-rebuild source API and a guard before
  `rebuildFromSwiftDataAsync`. A legitimate successfully-read empty vault must
  remain an authorized empty rebuild.
- Preserve the existing compatibility `allPagesForRebuild()` API for its
  current non-owner tests unless source review proves a necessary call-site
  migration. Do not widen this leg into diff sync, initial import, Recall,
  Eidos, Spotlight, global notification identity/correlation, checkpoint
  recovery, schema work, or UI changes.
- Before every build, confirm the exact branch/HEAD/origin/handoff identity,
  dirty count, diff hygiene, locked resources, competing-process absence, and
  empty app/archive inventory. Delete any stale Epistemos product before the
  build and the complete disposable product after identity capture.

**Contradiction resolution**

- The earlier Recall correction deliberately left `allPagesForRebuild()` with
  a “compatibility fallback.” That historical boundary prevented the Recall
  leg from silently expanding into manual Search behavior; it was not proof
  that destructive empty-on-failure semantics are safe. Green9 now makes the
  consequence larger because an authoritative empty rebuild correctly removes
  both page and orphan block projections. The newly isolated manual red is the
  required evidence before retiring that fallback from the Settings owner.

**Acceptance checks, done bar, and verification debt**

- Red10 must be one deterministic selected test whose direct result shows the
  current source mutates on the forced source-read failure. Its retained
  result/log, resource observations, app identity, and cleanup must be recorded
  before production correction.
- Green10 must prove the same forced failure leaves both exact Search records
  intact and publishes zero notification. The complete Green9 selection must
  remain green in the same one-build batch.
- Success closes only manual full-rebuild source acquisition. FTS5-enabled
  execution, notification correlation, post-commit checkpoint recovery, Eidos
  deletion, Spotlight receipts/dual-lane ownership, broader suites, Release
  artifact/runtime evidence, and the Free V1 matrix remain explicit debt.

**Exact next action**

- Add the behavior-preserving manual-rebuild test harness and the Red10
  regression, inspect the surgical diff, and run `git diff --check`. Then run
  a fresh complete 16-GiB preflight. Only if every gate passes may exactly one
  selected Red10 test build begin.

### Manual Search rebuild Red10 preflight — passed

- At 2026-07-13 22:36 CDT, fetched origin and reverified branch
  `feat/goose-surface`. Local HEAD, fetched `origin/feat/goose-surface`, and
  the handoff publication commit all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty entry count remains 112 and `git diff --check` passes.
- Swap used is 9,827.62 MiB, strictly below the locked 16,384-MiB ceiling;
  free memory is 72%; throttled pages are zero; and available disk is 727 GiB.
- No competing Xcode build, compiler, model, or Epistemos process is active.
  No Epistemos app or archive exists in `/private/tmp`, Xcode DerivedData, the
  repository build tree, or Xcode Archives. The new disposable build,
  result-bundle, and log paths are absent.
- Exactly one selected Debug App Store test is authorized:
  `appStoreManualSearchRebuildSourceFailureCannotEraseProjections()`, using
  `/private/tmp/Epistemos-ManualSearchRebuildRed10-16GiB` and retained
  `build/xcode-results/2026-07-13-manual-search-rebuild-source-red10-16gib.*`.
  No second build, correction, archive, launch, owner-vault, runtime,
  model/provider/secret/audio, feature/canon, payment, or subsequent-key action
  is authorized by this preflight.

### Manual Search rebuild Red10 — exact destructive ambiguity proven

- Exactly one selected test ran. Direct result-bundle inspection reports
  result `Failed`: one total, zero passed, one failed, zero expected failures,
  and zero skipped on arm64 macOS 26.3.1.
- The DEBUG fault seam installed, the exact seeded page and page-owned block
  were both searchable, and the real Settings/manual `rebuildIndex()` task
  completed. The forced failed derived source read was logged, then current
  production rebuilt from zero pages.
- The test recorded exactly three issues: the exact page no longer existed,
  the exact owned block no longer existed, and the isolated observation window
  received one Search update notification. This is the intended Red10 defect,
  not a compiler, setup, seed, timeout, or unrelated-test failure.
- The retained result is
  `build/xcode-results/2026-07-13-manual-search-rebuild-source-red10-16gib.xcresult`.
  The retained log has the same basename with `.log` and SHA-256
  `34c8b0842980fd9e336a742276239f138c87b6f8289295623e5e9a3db24ca032`.
- The disposable app is
  `/private/tmp/Epistemos-ManualSearchRebuildRed10-16GiB/Build/Products/Debug/Epistemos.app`.
  Its executable is 40,344 bytes with SHA-256
  `ba15451fbe65804f19fccd6301795d63af2b9bc3ec1bc9bacad6257c1073d61a`;
  the bundle occupies 490,468 KiB.
- Immediate post-run resources are 9,795.62 MiB swap, 68% free memory, zero
  throttled pages, and 725 GiB available disk. No scoped compiler, model, or
  Epistemos process remains; dirty count is 112 and `git diff --check` passes.
- Red10 authorizes only a distinct optional required Search-rebuild source
  read and a fail-closed guard in the actual Settings/manual owner. Legitimate
  successfully-read empty vaults must still rebuild empty. Notification
  correlation, Eidos, Spotlight, Recall, checkpoint recovery, schema work,
  archive/runtime, Free V1, feature/canon, payment, model/provider/secret/audio,
  owner-vault, and subsequent-key work remain outside this correction.
- Exact next action: delete the complete disposable Red10 build, verify empty
  app/archive inventory, then apply only the authorized fail-closed correction
  and re-read its diff. No Green build may begin before another complete
  16-GiB preflight.

### Manual Search rebuild Red10 cleanup — zero current build restored

- After exact identity capture, the complete disposable Red10 build tree was
  deleted. The retained result bundle and log remain present.
- App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
  repository build tree, and Xcode Archives. Final resources are 9,795.62 MiB
  swap, 68% free memory, zero throttled pages, and 727 GiB available disk.
  No scoped compiler, model, or Epistemos process is active; dirty count is 112
  and `git diff --check` passes.
- The authorized source correction may now begin. No build is authorized until
  the correction is re-read, independently reviewed, and followed by another
  full 16-GiB preflight.

### Manual Search rebuild correction — pre-Green10 source boundary

- `VaultIndexActor.requiredPagesForSearchRebuild()` now exposes the existing
  optional derived-page source without collapsing failure to an empty array.
  The compatibility `allPagesForRebuild()` API and existing general tests are
  unchanged.
- The actual Settings/manual `VaultSyncService.rebuildIndex()` owner now guards
  that required optional before calling `rebuildFromSwiftDataAsync`. `nil`
  logs and returns without Search mutation or notification. A successful
  `.some([])` still performs the legitimate authoritative empty rebuild.
- `isIndexing` cleanup moved into the task's existing `defer`, so source
  failure, successful rebuild, and thrown rebuild error all restore the UI
  state. No Settings UI, Search schema, notification implementation, Eidos,
  Recall, initial-import, diff-sync, or checkpoint semantics changed.
- Two independent read-only reviews report no actionable compile, actor,
  lifecycle, call-site, empty-vault, Release-boundary, or notification finding.
  They agree the complete Green9 selection remains valid and the new regression
  should be its twenty-second test. No source guard is needed because the
  behavior test invokes the real owner.
- The test now drains the main actor for a bounded 100 ms before installing its
  global observer and again after rebuild completion. This limits unrelated
  fire-and-forget leakage without claiming the still-open global notification
  correlation debt.
- `git diff --check` passes. Green behavior remains unproven until one fresh
  serial twenty-two-test App Store batch passes after a complete 16-GiB
  preflight. No archive, launch, runtime, owner-vault, feature/canon, payment,
  model/provider/secret/audio, or subsequent-key action is authorized.

### Manual Search rebuild Green10 preflight — passed

- At 2026-07-13 22:45 CDT, fetched origin and reverified branch
  `feat/goose-surface`. Local HEAD, fetched `origin/feat/goose-surface`, and
  the handoff publication commit all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty count is 112 and `git diff --check` passes. Swap used is 9,795.62 MiB,
  strictly below 16,384 MiB; free memory is 69%; throttled pages are zero; and
  available disk is 727 GiB.
- No competing Xcode/compiler/model/Epistemos process is active. App/archive
  inventory is empty across every scoped build location; the new disposable
  Green10 build, result, and log paths are absent.
- One serial twenty-two-test App Store batch is authorized: the exact twenty-
  one-test Green9 selection plus
  `appStoreManualSearchRebuildSourceFailureCannotEraseProjections()`. It will
  use `/private/tmp/Epistemos-ManualSearchRebuildGreen10-16GiB` and retain
  `build/xcode-results/2026-07-13-manual-search-rebuild-source-green10-16gib.*`.
  No second build, archive, launch, owner-vault, runtime, feature/canon,
  payment, model/provider/secret/audio, or subsequent-key action is authorized.

### Manual Search rebuild Green10 — proven boundary

- The one authorized serial batch exited zero. Direct result inspection reports
  22 total, 22 passed, zero failed, zero expected failures, and zero skipped on
  arm64 macOS 26.3.1.
- The new actual-caller regression proves a failed required manual-rebuild
  source read preserves the exact seeded Search page and owned block and emits
  zero Search update notifications in its bounded isolated observation window.
  All 21 Green9 tests remained green in the same build.
- The retained result is
  `build/xcode-results/2026-07-13-manual-search-rebuild-source-green10-16gib.xcresult`.
  Its retained log has the same basename with `.log` and SHA-256
  `65a8dfc905fd6964d65335a83d0f51a55be99931eb442043f3f9d36b14793e69`.
- The disposable app is
  `/private/tmp/Epistemos-ManualSearchRebuildGreen10-16GiB/Build/Products/Debug/Epistemos.app`.
  Its executable is 40,344 bytes with SHA-256
  `6e3c6d2ff7a20a1d5f3988c23a51af4c04472401b84ce3a5db16191a217b9e95`;
  the bundle occupies 490,472 KiB.
- Immediate post-run resources are 9,795.62 MiB swap, 70% free memory, zero
  throttled pages, and 725 GiB disk. No scoped process remains; dirty count is
  112 and `git diff --check` passes at the exact local/remote/handoff SHA.
- Green10 closes only the Red10 manual Search source-acquisition defect. FTS5
  execution, global notification correlation, post-commit checkpoint recovery,
  Eidos deletion, remaining Spotlight receipts/dual-lane proof, broader suites,
  archive/runtime, and Free V1 evidence remain open.
- Exact next action: delete only the complete disposable Green10 build, retain
  its result and log, verify empty app/archive inventory and safe resources,
  then perform a read-only next-debt comparison. No later build or canonical
  execution key is authorized as part of cleanup.

### Manual Search rebuild Green10 cleanup — zero current build restored

- The complete disposable Green10 build tree was deleted after its exact app
  identity was captured. The retained result bundle and log remain present.
- App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
  repository build tree, and Xcode Archives. Final resources are 9,763.62 MiB
  swap, 70% free memory, zero throttled pages, and 726 GiB disk.
- No scoped Xcode/compiler/model/Epistemos process is active. Dirty count
  remains 112; `git diff --check` passes; local HEAD and fetched origin remain
  the handoff publication SHA.
- The overall KEELSTONE verdict remains `INCOMPLETE`. The next action is a
  read-only comparison of the remaining bounded evidence debts. No source edit
  or build is authorized without a new intent checkpoint and fresh full
  16-GiB preflight.

### Forty-eighth checkpoint — committed Search rebuild survives checkpoint maintenance failure

**Verbatim owner steer**

> “make it lock at 16gb at this point man”

This remains joined to the owner's standing direction to continue the same
interrupted KEELSTONE chain autonomously, rerun failed evidence legs, retain
only one current app build, and finish unresolved release evidence before any
new MAS canon or feature key.

**Interpreted intent and selected debt**

- Keep the durable build safety ceiling strictly below 16 GiB of swap used,
  with at least 25% free memory, zero throttled pages, and no competing scoped
  Xcode/compiler/model/Epistemos process before every build.
- Continue execution key
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` only.
- Read-only comparison ranks post-commit full-Search-rebuild checkpoint failure
  ahead of global Search notification correlation and Spotlight receipts. The
  full rebuild commits its derivative index transaction, then calls
  `truncateCheckpoint()`. A checkpoint error currently escapes as logical
  rebuild failure and skips post-commit Eidos mirroring and Search invalidation.
  `diffSync` already treats equivalent post-commit checkpoint failure as
  non-fatal maintenance debt.
- The checkpoint success marker is currently written before the actual
  truncate checkpoint. A real checkpoint error can therefore leave telemetry
  claiming success that did not occur.

**Hard constraints and non-goals**

- Test first. Add only one DEBUG-gated deterministic truncate-checkpoint
  failure seam at the actual checkpoint boundary and one App Store behavior
  regression. Preserve the current throw/marker/notification behavior for the
  Red11 run; do not include the correction in advance.
- Seed one old Search page and owned block, force the checkpoint operation to
  fail during a full rebuild to one replacement page, and prove the database
  transaction committed before the maintenance error.
- The intended contract is: checkpoint failure does not turn a committed
  derivative rebuild into logical rebuild failure; replacement state remains
  searchable; old page and block remain removed; page-and-block invalidation
  publishes once; and `last_truncate_checkpoint_at` does not advance on a
  failed checkpoint.
- The only correction authorized after exact Red evidence is to perform the
  checkpoint before recording its success marker and to catch/log this
  post-commit maintenance error before continuing the existing post-commit
  mirror/invalidation path.
- Do not widen into global notification identity/correlation, Eidos deletion
  reconciliation, Spotlight, FTS5 configuration, schema migration, manual
  rebuild source acquisition, archive/runtime, Free V1, feature/canon,
  payment, model/provider/secret/audio, owner-vault, or a subsequent key.

**Contradictions and resolution**

- The rebuild method's throwing signature remains necessary for transaction
  and source-index failures. This leg does not make every rebuild error
  non-fatal; it distinguishes only checkpoint maintenance failure that occurs
  after the authoritative derivative transaction has already committed.
- Search notifications are still globally uncorrelated. This isolated serial
  test may use bounded main-actor drains to prove one local invalidation, but
  it does not close the broader producer/consumer identity debt.

**Acceptance checks, done bar, and verification debt**

- Red11 must directly show the forced post-commit checkpoint failure escaping,
  the committed replacement state present, the old page/block absent, the
  checkpoint success marker incorrectly advanced, and no expected
  page-and-block invalidation.
- Green11 must pass the same regression plus the complete twenty-two-test
  Green10 selection in one fresh serial App Store build. Direct result
  inspection, log digest, exact app identity, machine state, and cleanup are
  required before this leg closes.
- Success does not prove FTS5-enabled execution, global notification
  correlation, Eidos deletion, Spotlight receipts/dual-lane ownership, broad
  non-App-Store suites, Release archive/artifact/runtime behavior, or Free V1.

**Exact next action**

- Add the behavior-preserving DEBUG checkpoint fault seam and the Red11
  regression, re-read the surgical diff, and run `git diff --check`. Then run
  a complete fresh 16-GiB preflight. Only if every gate passes may exactly one
  selected Red11 test build begin.

### Post-commit Search checkpoint Red11 — behavior-preserving harness boundary

- The deterministic fault storage, setter, and throw branch are all omitted
  from Release by `#if DEBUG`. With the flag false, checkpoint behavior is
  unchanged.
- The forced throw sits after the current success-marker write and before the
  actual truncate operation. The full rebuild still commits before calling
  this maintenance path, and the existing error still escapes before mirror
  and notification. No correction is present.
- The selected test requires three committed-state facts to pass: replacement
  page present, removed page absent, and removed owned block absent. Its three
  intended-contract expectations should fail on current source: checkpoint
  error escaped, page/block notification absent, and checkpoint success marker
  changed despite failure.
- An independent read-only review reports no actionable Release gating,
  actor/Mutex, async offload, syntax, determinism, or test-meaning issue and
  predicts exactly those three expectation failures.
- `git diff --check` passes. No compiler, build, test, archive, app launch,
  owner-vault, runtime, feature/canon, payment, model/provider/secret/audio, or
  subsequent-key action has begun. The exact next action is the complete
  locked 16-GiB preflight; only a passing preflight authorizes one selected
  Red11 test build.

### Post-commit Search checkpoint Red11 preflight — passed

- At 2026-07-13 23:01 CDT, fetched origin and reverified branch
  `feat/goose-surface`. Local HEAD, fetched `origin/feat/goose-surface`, and the
  handoff publication commit all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty count is 112 and `git diff --check` passes. Swap used is 9,763.62 MiB,
  strictly below 16,384 MiB; free memory is 71%; throttled pages are zero; and
  available disk is 726 GiB.
- No competing Xcode/compiler/model/Epistemos process is active. App/archive
  inventory is empty across every scoped build location, and the new Red11
  disposable build, result, and log paths are absent.
- Exactly one selected Debug App Store test is authorized:
  `appStoreCommittedSearchRebuildSurvivesCheckpointMaintenanceFailure()`,
  using `/private/tmp/Epistemos-SearchCheckpointRed11-16GiB` and retained
  `build/xcode-results/2026-07-13-search-checkpoint-postcommit-red11-16gib.*`.
  No second build, correction, archive, launch, owner-vault, runtime,
  feature/canon, payment, model/provider/secret/audio, or subsequent-key action
  is authorized by this preflight.

### Post-commit Search checkpoint Red11 — exact defect proven

- One selected test ran. Direct summary reports one total, zero passed, one
  failed, zero expected failures, and zero skipped on arm64 macOS 26.3.1.
  Direct test-detail inspection reports exactly three issues.
- The replacement page existed and the removed exact page and owned block were
  absent after the call. Those three passing assertions prove the rebuild
  transaction committed before checkpoint maintenance failed.
- The three exact issues are: the forced checkpoint error escaped; no
  `searchBlocks,searchPages` invalidation arrived; and
  `last_truncate_checkpoint_at` advanced from `nil` to
  `805694677.960701`. No compile, setup, seed, committed-state, timeout, or
  unrelated-test failure occurred.
- The retained result is
  `build/xcode-results/2026-07-13-search-checkpoint-postcommit-red11-16gib.xcresult`.
  Its retained log has the same basename with `.log` and SHA-256
  `27dd81f4adec64bb3a6afdd8ee6d99166aa2f646b6c9507b910407bc276d001c`.
- The disposable app is
  `/private/tmp/Epistemos-SearchCheckpointRed11-16GiB/Build/Products/Debug/Epistemos.app`.
  Its executable is 40,344 bytes with SHA-256
  `486a331be7b3b9f95342c51fdddc314fb1ebcbf160ca15a64efbd157e2dd0f31`;
  the bundle occupies 490,528 KiB.
- Immediate post-run resources are 9,897.38 MiB swap, 67% free memory, zero
  throttled pages, and 724 GiB disk. No scoped process remains; dirty count is
  112 and `git diff --check` passes.
- Red11 authorizes only the bounded checkpoint marker/error correction. Exact
  next action: delete the disposable Red11 build, verify empty app/archive
  inventory, then change production. No Green build is authorized until that
  correction is re-read, independently reviewed, and followed by another
  complete 16-GiB preflight.

### Post-commit Search checkpoint Red11 cleanup — zero current build restored

- The complete disposable Red11 build tree was deleted after exact identity
  capture. Its retained result bundle and log remain present.
- App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
  repository build tree, and Xcode Archives. Final resources are 9,897.38 MiB
  swap, 67% free memory, zero throttled pages, and 726 GiB disk.
- No scoped Xcode/compiler/model/Epistemos process is active. Dirty count is
  112 and `git diff --check` passes.
- The bounded checkpoint marker/error correction may now begin. No Green build
  is authorized until source review and another complete 16-GiB preflight.

### Post-commit Search checkpoint correction — pre-Green11 source boundary

- `truncateCheckpoint()` now performs the actual `.truncate` checkpoint before
  writing `last_truncate_checkpoint_at`. Forced or real checkpoint failure can
  no longer advance the success marker.
- The full rebuild transaction remains outside the checkpoint-only catch. True
  database, schema, or rebuild-manifest failures still throw before mirror or
  notification. Only a later post-commit checkpoint maintenance error is
  logged and absorbed so the existing success log, Eidos upsert mirror, and
  Search invalidation continue.
- The DEBUG fault storage/setter/throw remain Release-omitted. `diffSync` is
  unchanged and already uses the same non-fatal post-commit maintenance rule.
- Two independent read-only reviews found no actionable semantics,
  concurrency, Release, selection, or scope issue. Green11 must be exactly all
  22 Green10 selectors plus the new checkpoint regression once: 23 serialized
  App Store tests.
- No extra test is required for this bounded leg. The global `object:nil`
  notification channel remains separate debt; the new test's bounded drains
  and serialized suite limit contamination without claiming correlation.
- `git diff --check` passes. No Green behavior is proven yet. The exact next
  action is a complete fresh 16-GiB preflight; only a passing preflight
  authorizes the one twenty-three-test Green11 build.

### Post-commit Search checkpoint Green11 preflight — passed

- At 2026-07-13 23:10 CDT, fetched origin and reverified branch
  `feat/goose-surface`. Local HEAD, fetched `origin/feat/goose-surface`, and the
  handoff publication commit all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty count is 112 and `git diff --check` passes. Swap used is 9,897.38 MiB,
  strictly below 16,384 MiB; free memory is 68%; throttled pages are zero; and
  available disk is 726 GiB.
- No competing Xcode/compiler/model/Epistemos process is active. App/archive
  inventory is empty across every scoped location, and the Green11 disposable
  build, result, and log paths are absent.
- One serial twenty-three-test App Store batch is authorized: the exact 22
  Green10 selectors plus the Red11 regression once, using
  `/private/tmp/Epistemos-SearchCheckpointGreen11-16GiB` and retained
  `build/xcode-results/2026-07-13-search-checkpoint-postcommit-green11-16gib.*`.
  No second build, archive, launch, owner-vault, runtime, feature/canon,
  payment, model/provider/secret/audio, or subsequent-key action is authorized.

### Post-commit Search checkpoint Green11 — proven boundary

- The one authorized serial batch exited zero. Direct result inspection reports
  23 total, 23 passed, zero failed, zero expected failures, and zero skipped on
  arm64 macOS 26.3.1. The corrected checkpoint test passed in 0.22 seconds.
- Under forced post-commit checkpoint failure, the rebuild returned normally,
  replacement state survived, the removed page and owned block stayed absent,
  one `searchBlocks,searchPages` invalidation arrived, and the checkpoint
  success marker did not advance. The successful full-rebuild sibling also
  passed, and all 22 Green10 tests remained green.
- The retained result is
  `build/xcode-results/2026-07-13-search-checkpoint-postcommit-green11-16gib.xcresult`.
  Its retained log has the same basename with `.log` and SHA-256
  `db207d5c1140252b5593f39025ba08cf34e3c93211f0f85a1188dec0d0af8dc0`.
- The disposable app is
  `/private/tmp/Epistemos-SearchCheckpointGreen11-16GiB/Build/Products/Debug/Epistemos.app`.
  Its executable is 40,344 bytes with SHA-256
  `fc601fbc454297916de8c924200124e46abd17d097a40b5f76cb54178582972b`;
  the bundle occupies 490,528 KiB.
- Immediate post-run resources are 10,245.19 MiB swap, 68% free memory, zero
  throttled pages, and 723 GiB disk. No scoped process remains; dirty count is
  112 and `git diff --check` passes at the exact local/remote/handoff SHA.
- Green11 closes only the Red11 checkpoint maintenance/marker defect. FTS5
  execution, global notification correlation, Eidos deletion, remaining
  Spotlight receipts/dual-lane proof, broader suites, archive/runtime, and
  Free V1 evidence remain open.
- Exact next action: delete only the complete disposable Green11 build, retain
  its result and log, verify empty app/archive inventory and safe resources,
  then perform a read-only next-debt comparison. No later build or canonical
  execution key is authorized as part of cleanup.

### Post-commit Search checkpoint Green11 cleanup — zero current build restored

- The complete disposable Green11 build tree was deleted after its exact app
  identity was captured. The retained result bundle and log remain present.
- App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
  repository build tree, and Xcode Archives. Final resources are 10,245.19 MiB
  swap, 68% free memory, zero throttled pages, and 724 GiB disk.
- No scoped Xcode/compiler/model/Epistemos process is active. Dirty count is
  112 and `git diff --check` passes.
- The overall KEELSTONE verdict remains `INCOMPLETE`. The next action is a
  read-only comparison of the remaining bounded evidence debts. No source edit
  or build is authorized without a new intent checkpoint and fresh complete
  16-GiB preflight.

### Forty-ninth checkpoint — correlate Search page/block notifications to their producing service

**Owner wording (verbatim excerpts)**

> “make it lock at 16gb at this point man”

> “the main issue ... were the performance of epdoc and sitchgn from and to
> edpco would hang take time cause lag andbugs etc.”

> “every single thgn neeeds to be auditte d ... load times throttlews hangs
> isasues ith memoery and data”

**Interpreted intent**

- Continue the same KEELSTONE release-gate execution key without reopening
  feature/canon work, and prefer the next bounded defect that removes provable
  unnecessary work from live app consumers.
- Correlate page/block `.searchIndexDidUpdate` events from a concrete
  `SearchIndexService` to that exact service. A delayed event from a retired or
  different vault index must not trigger SQL reevaluation or an HTML data-feed
  refresh against the current vault.
- Preserve dependency-domain filtering and preserve conservative acceptance of
  `object == nil` notifications, because `ReadableBlocksIndex` remains an
  intentionally unscoped producer in this leg.

**Hard constraints and non-goals**

- The locked pre-build ceiling is strictly below 16,384 MiB swap, with at least
  25% free memory, zero throttled pages, no competing scoped process, one serial
  Xcode job, and zero stale Epistemos app/archive products before every build.
- Test first. Red12 may add one behavior-preserving HTML consumer overload that
  initially delegates to the current dependency-only implementation so the
  two-service behavior can compile and fail without including the correction.
- Do not change Search database/schema/receipts/results, debounce timing, Eidos,
  Spotlight, Recall, FTS5 configuration, ReadableBlocks notification behavior,
  vault data, Release/archive/runtime, Free V1 capability policy, feature/canon,
  payment, model/provider/secret/audio, or any subsequent execution key.
- Private Columbia/VA/funding material and unavailable removable storage remain
  outside repository scope and must not be accessed or inferred.

**Acceptance checks, done bar, and verification debt**

- Red12 uses two distinct file-backed Search services. Service B performs one
  real awaited `diffSync(... notifyObservers: true)` page mutation. The captured
  event must expose B as its source; a B-bound reactive query and HTML consumer
  must accept it, while their A-bound peers must reject it.
- The unchanged source is expected to fail exactly three contract facts: the
  event source is `nil`, the A-bound reactive query accepts the foreign event,
  and the A-bound HTML consumer accepts it. B/domain behavior and the nil
  `.searchReadable` fallback must pass.
- Only after exact Red12 evidence may notification publication become
  instance-based, the aggregated VaultSync publisher call its concrete service,
  and `QueryRuntime`/`ReactiveQuery` plus the HTML feed apply the same
  service-identity filter. Nil or non-service producers remain conservative.
- Green12 must pass the same regression plus the exact twenty-three Green11
  selectors in one fresh serialized App Store batch, followed by direct result
  inspection, log digest, exact disposable-app identity, and complete cleanup.
- Even Green12 would not close readable-projection correlation, Spotlight error
  receipts/dual-lane ownership, Eidos deletion, FTS5-enabled execution, broad
  non-App-Store tests, authoritative-rescan/manual-sync breadth, structural
  recovery, Release artifact gates, manual runtime, or the finite Free V1
  matrix.

**Contradictions and resolution**

- Spotlight helper receipt availability is a smaller source edit, but its
  proposed Red is source-only and cannot prove system behavior. Search
  correlation has a deterministic awaited behavior leg and directly addresses
  unnecessary refresh work, so it is selected first without deleting or
  downgrading the Spotlight debt.
- Service correlation must not suppress `ReadableBlocksIndex` updates. This leg
  therefore rejects only a notification whose `object` is a different
  `SearchIndexService`; nil and non-service objects retain conservative legacy
  acceptance.

**Exact next action**

- Add only the behavior-preserving HTML overload and the single Red12 behavior
  regression, re-read the changed regions, inspect the diff, and run
  `git diff --check`. Then perform a complete fresh 16-GiB preflight. Only a
  passing preflight authorizes one selected Red12 App Store test build.

### Red12 Search notification correlation harness boundary

- The bounded Red harness is prepared without changing production behavior.
  `HTMLWorkspaceDataFeedStatus` now exposes a two-argument test seam that
  accepts an active `SearchIndexService` but deliberately delegates to the
  existing dependency-only helper. The live HTML binder still calls the old
  one-argument helper.
- The new serialized MainActor regression creates distinct file-backed Search
  services A and B. B performs one real awaited page `diffSync` with observer
  publication enabled. The regression requires a captured page event sourced
  by the uniquely created B service, B-bound reactive and HTML consumers to
  accept it, A-bound consumers to reject it, and an object-nil
  `.searchReadable` event to remain accepted.
- An independent read-only review found the harness compile shape plausible,
  found no correction leakage, and confirmed the current source should fail
  exactly three expectations: B source identity, A-bound `ReactiveQuery`
  rejection, and A-bound HTML rejection. Receipt/domain behavior and the two
  readable fallback checks should pass.
- The reviewer identified one non-blocking fixed-delay contamination risk. The
  100-ms heuristic was removed, and the source assertion now checks for the
  uniquely owned B identity rather than requiring a globally exact event
  array. Delayed unrelated events cannot satisfy that identity, so the proof
  remains specific without depending on timing. A follow-up read-only review
  approved the hardened harness and reconfirmed the same three expected Red
  failures; exclusivity or duplicate-unrelated-event proof is intentionally
  outside this correlation leg.
- The changed regions were re-read. Dirty entry count remains 112 and
  `git diff --check` passes. This is source review only, not executed Red
  evidence and not authorization for production correction.
- Exact next action: perform a complete fresh preflight, including origin
  fetch and three-way SHA equality, strict swap below 16,384 MiB, at least 25%
  free memory, zero throttled pages, no competing scoped process, empty stale
  app/archive inventory, and absent fresh Red12 paths. Only a passing preflight
  authorizes one selected Red12 App Store test build.

### Search notification correlation Red12 preflight — passed

- At 2026-07-13 23:40 CDT, origin was fetched successfully. Branch is
  `feat/goose-surface`; local HEAD, fetched `origin/feat/goose-surface`, and
  the handoff publication commit all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty entry count is 112 and `git diff --check` passes. Swap used is
  10,213.19 MiB, strictly below 16,384 MiB; system free memory is 72%; pages
  throttled are zero; and available disk is 724 GiB.
- No competing exact-basename Xcode build, compiler, model, Epistemos app, or
  App Store test process is active. App/archive inventory is empty across
  `/private/tmp`, Xcode DerivedData, the repository build tree, and the Xcode
  Archives root; the Archives root itself is absent. The fresh Red12
  DerivedData, result-bundle, and log paths are all absent.
- An initial read-only process probe rejected an unescaped `clang++` pattern,
  and its companion inventory aggregation returned nonzero because the
  Archives root is absent. Neither probe started Xcode or changed any product.
  Exact-basename and root-aware replacements were then run and passed with
  unambiguous empty output.
- Exactly one serial selected App Store test is authorized:
  `appStoreSearchNotificationsStayWithTheirProducingService()`, using
  `/private/tmp/Epistemos-SearchNotificationRed12-16GiB` and retained
  `build/xcode-results/2026-07-13-search-notification-source-red12-16gib.*`.
  No second build, archive, launch, owner-vault, runtime, correction-before-Red,
  feature/canon, payment, model/provider/secret/audio, or later-key action is
  authorized.

### Red12 first execution attempt — harness compile failure, zero tests

- The one authorized build exited 65 before test execution. Direct xcresult
  inspection reports result `unknown`, zero total tests, zero passed, and zero
  failed. Build-result inspection reports status `failed`, two errors, and four
  warnings. The decisive source error is Swift 6
  `Sending 'notification' risks causing data races`, paired with the warning
  that `QueryDependencyKey.from` is MainActor-isolated but was called from the
  synchronous nonisolated NotificationCenter observer closure. The second
  error is cancellation because the build failed.
- This is not the intended behavior Red and authorizes no production
  correction. The observer does not need to parse dependency metadata: the
  real B service is newly created inside this test, so exact actor identity is
  already a unique and stronger correlation filter. The only authorized
  harness correction is to remove the actor-isolated dependency parsing line;
  receipt and synthetic dependency-domain checks remain.
- The retained failed result is
  `build/xcode-results/2026-07-13-search-notification-source-red12-16gib.xcresult`.
  The retained log has the same basename with `.log` and SHA-256
  `aeb815d236334c24dbb7177a266cfe8ab6dd259376b72ecc676721ad79fedfff`.
- Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
  `5ff65155594b9d7c08700283f7617ccfd3a3fe37c9133bf742879a1f848be615`;
  its bundle occupied 479,248 KiB. Immediate resources were 10,885.31 MiB
  swap, 68% free memory, zero throttled pages, and 722 GiB disk. No scoped
  process remained.
- After identity capture, the complete disposable DerivedData tree was
  deleted. App/archive inventory is again empty across every scoped root; the
  failed result and log remain. Cleanup resources are 10,885.31 MiB swap, 70%
  free memory, zero throttled pages, and 724 GiB disk. Dirty count remains 112
  and `git diff --check` passes.
- Exact next action: remove only the actor-isolated dependency parse from the
  test observer, re-read the harness, inspect the diff, and run
  `git diff --check`. Then perform a new complete locked preflight. Only a
  passing new preflight may authorize one Red12 behavior rerun with fresh
  `/private/tmp/Epistemos-SearchNotificationRed12Rerun-16GiB` and retained
  `build/xcode-results/2026-07-13-search-notification-source-red12-rerun-16gib.*`.

### Red12 harness actor-isolation repair — pre-rerun boundary

- Only the failed observer's `QueryDependencyKey.from(notification)` guard was
  removed. The observer now performs a `SearchIndexService` cast, exact actor
  identity comparisons, and locked probe writes; no production file or
  behavior changed.
- An independent follow-up review approved the correction. Fresh service B is
  created before observer installation and no prior producer can possess that
  identity. The awaited B `diffSync` completes its MainActor post before the
  source assertion. Unrelated delayed notifications may record nil or another
  service but cannot satisfy `contains("service-b")`.
- The reviewer reconfirmed the expected behavior result remains exactly three
  failures: missing B source identity, A-bound reactive acceptance, and
  A-bound HTML acceptance. B-bound checks and object-nil readable fallback
  should pass. Search publication still uses `object: nil`, ReactiveQuery still
  filters only dependency domains, the HTML overload still ignores its active
  service, and the live binder still calls the old overload.
- The corrected region was re-read; dirty count is 112 and
  `git diff --check` passes. The fresh rerun DerivedData, result, and log paths
  are absent. This remains source-only harness review, not Red behavior proof.
- Exact next action: perform a new complete locked 16-GiB preflight. Only a
  passing preflight authorizes the one selected behavior rerun; no production
  correction is authorized before direct exact Red evidence.

### Red12 behavior rerun preflight — passed

- At 2026-07-13 23:46 CDT, origin fetched successfully. Branch is
  `feat/goose-surface`; local HEAD, fetched `origin/feat/goose-surface`, and
  handoff publication SHA all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 112 and
  `git diff --check` passes.
- Swap used is 10,845.31 MiB, strictly below 16,384 MiB; free memory is 72%;
  pages throttled are zero; and disk availability is 724 GiB. No competing
  scoped process is active.
- App/archive inventory is empty across all scoped roots. Fresh rerun
  DerivedData, result, and log paths are absent. The rejected first-attempt
  result and log remain present, and the retained log digest still equals
  `aeb815d236334c24dbb7177a266cfe8ab6dd259376b72ecc676721ad79fedfff`.
- Exactly one serial rerun of
  `appStoreSearchNotificationsStayWithTheirProducingService()` is authorized,
  using the fresh rerun paths recorded above. No other build, archive, launch,
  owner-vault, runtime, production correction before exact Red, feature/canon,
  payment, model/provider/secret/audio, or later-key action is authorized.

### Search notification correlation Red12 — exact behavior failure proven

- The one authorized rerun exited 65 because the selected behavior test failed,
  not because the build failed. Direct build-result inspection reports status
  `succeeded`, zero build errors, and three unrelated retained warnings. Direct
  test summary reports result `Failed`: one total test, zero passed, one failed,
  zero expected failures, and zero skipped on arm64 macOS 26.3.1.
- Direct targeted test-detail inspection and the retained log show exactly the
  three intended issues in 0.061 seconds: the real awaited B diff emitted
  source array `["nil"]`; A-bound `ReactiveQuery.shouldInvalidate` returned
  true for B's synthetic page event; and the A-bound HTML refresh predicate
  returned true. No other test issue was recorded, so the receipt, B-bound
  consumer checks, dependency-domain behavior, and both object-nil readable
  fallback checks passed.
- The generic xcresult `tests` listing subcommand returned an internal
  database-move collision. A repeated summary and the targeted `test-details`
  command both succeeded afterward, proving the result bundle remained valid
  and exposing all three issue trees directly.
- The retained result is
  `build/xcode-results/2026-07-13-search-notification-source-red12-rerun-16gib.xcresult`
  and occupies 136,704 KiB. Its retained `.log` SHA-256 is
  `29d684ee3c0b2822ec880d8dcc1f0ce9ddd1250607b7eb62d793a297ce3144af`.
- Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
  `5c75f848205f2b0c57c0f3caf0fd5f113bade049cd38a0f302c59e841c67cd0a`;
  the bundle occupied 490,580 KiB. Immediate resources were 11,059.94 MiB
  swap, 69% free memory, zero throttled pages, and 721 GiB disk. No scoped
  process remained.
- After identity capture, the complete disposable build was deleted. The Red
  result and log remain; app/archive inventory is empty. Cleanup resources are
  11,059.94 MiB swap, 70% free memory, zero throttled pages, and 723 GiB disk.
  Dirty count remains 112 and `git diff --check` passes.
- Exact Red12 now authorizes only the bounded correlation correction. The next
  action is source/call-site review and surgical instance publication plus
  concrete-service consumer filtering, preserving nil/non-service fallback.
  No Green build is authorized before correction review and a new full
  16-GiB preflight.

### Search notification correlation correction — pre-Green12 source boundary

- The bounded correction is prepared. Both Search notification helpers remain
  `nonisolated` but now belong to the concrete `SearchIndexService`; the
  MainActor post uses `object: self`. All nine internal publication call sites
  use their instance, and the aggregate VaultSync path calls its exact
  `searchService` instance after the existing continuation fence.
- `QueryExecutor` now exposes concrete Search-source matching. Its only current
  conformer, `QueryRuntime`, stores the constructor's Search service and uses
  actor identity. `ReactiveQuery` rejects only a `.searchIndexDidUpdate` whose
  object is a concrete different Search service, before retaining the existing
  dependency and unscoped fallback logic.
- The HTML predicate rejects only when producer and active Search services are
  both concrete and different, then delegates to its existing dependency
  predicate. Its live binder supplies the current
  `AppBootstrap.shared?.vaultSync.searchService`. Nil producer, non-service
  producer, nil active service, and identical-service events remain
  conservative fallbacks.
- `ReadableBlocksIndex` remains untouched and still publishes object-nil
  `.searchReadable` events. Search schema, receipts, results, debounce,
  Spotlight, Eidos, Recall, FTS5 configuration, owner vault, runtime, archive,
  Free V1 capability policy, feature/canon, payment, model/provider/secret/
  audio, and later keys remain outside this correction.
- The three source guards now require instance publication spelling and retain
  the preparation-publication-consumption order proof. Semantic scans find no
  stale static Search helper call and exactly the two intended producers:
  instance-sourced page/block Search and object-nil ReadableBlocks.
- An independent read-only applied-diff audit found no missed call site, Swift
  6 isolation risk, fallback error, source-guard inconsistency, or scope creep.
  Changed regions were re-read; dirty count is 114 because QueryRuntime and
  ReactiveQuery joined the already dirty feature set, and `git diff --check`
  passes.
- Green12 is exactly the twenty-three Green11 selectors plus the Red12
  regression once, for twenty-four serialized App Store tests. Exact next
  action: run a fresh complete locked preflight. Only a passing preflight may
  authorize one Green12 build using
  `/private/tmp/Epistemos-SearchNotificationGreen12-16GiB` and retained
  `build/xcode-results/2026-07-13-search-notification-correlation-green12-16gib.*`.

### Search notification correlation Green12 preflight — passed

- At 2026-07-14 00:00 CDT, origin fetched successfully. Branch is
  `feat/goose-surface`; local HEAD, fetched `origin/feat/goose-surface`, and
  handoff publication SHA all equal
  `668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 114 and
  `git diff --check` passes.
- Swap used is 10,635.94 MiB, strictly below 16,384 MiB; free memory is 70%;
  pages throttled are zero; and disk availability is 723 GiB. No competing
  scoped process is active, and app/archive inventory is empty across all
  scoped roots.
- The selector audit derives the exact twenty-three unique Green11 selectors
  from its retained log and adds the Red12 regression once: twenty-four unique
  serialized App Store selectors, with no duplicate.
- Midnight crossed after the source checkpoint. The proposed July 13 retained
  basename is superseded only for evidence dating by the verified-absent
  `build/xcode-results/2026-07-14-search-notification-correlation-green12-16gib.*`.
  The fresh DerivedData path remains
  `/private/tmp/Epistemos-SearchNotificationGreen12-16GiB`; all three actual
  paths are absent.
- Both rejected/behavior Red12 result-log pairs remain retained with their
  verified digests. Exactly one serial twenty-four-test Green12 build is now
  authorized. No second build, archive, launch, owner-vault, runtime,
  feature/canon, payment, model/provider/secret/audio, or later-key action is
  authorized.

### Search notification Green12 first attempt — compile failure

- The one authorized Green12 build exited 65 before any test executed. Direct
  xcresult inspection reports build status `failed`, two errors, four warnings,
  and an empty/unknown test summary: zero total, passed, failed, expected, or
  skipped tests.
- The bounded failure is exact: `HTMLWorkspaceDataFeed.shouldRefresh(for:
  activeSearchService:)` called the existing one-argument predicate without
  returning its `Bool`. The compiler reports `Missing return in static method
  expected to return 'Bool'` at line 594. No runtime behavior was exercised.
- The retained failed result is
  `build/xcode-results/2026-07-14-search-notification-correlation-green12-16gib.xcresult`
  and occupies 500 KiB. The retained log occupies 2,052 KiB and has SHA-256
  `1324ec22b8051d335fa6f0b66c00f8579587e2752b6e97de78601bb71ab2815e`.
- The partial disposable app occupied 197,176 KiB. It had no main Epistemos
  executable; its only executable under `Contents/MacOS` was the 16,760-byte
  `__preview.dylib`, SHA-256
  `d84f77e6467c2bf34498a4dbb0871fc906a374ca80dcbe70d574c74ffcab58bf`.
- Immediate resources remain inside the owner lock: 11,217.75 MiB swap used,
  66% free memory, zero throttled pages, and 721 GiB available disk. No scoped
  Xcode/compiler/model/Epistemos process remains. Branch and the local/origin/
  handoff SHA triple remain exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 114 and
  `git diff --check` passes.
- Exact next action is to retain this failed result/log, delete the partial
  disposable build, verify zero-build inventory, add only the missing `return`,
  re-read and diff-check the changed region, and run a new full 16-GiB
  preflight. No rerun is authorized until those gates pass.
- The exact partial DerivedData path was deleted after identity capture. The
  retained failed result/log remain, app/archive inventory is empty across the
  scoped build roots, and cleanup resources are 11,193.75 MiB swap used, 66%
  free memory, zero throttled pages, and 723 GiB available disk. No scoped
  process remains. The one-line return correction is now authorized.
- The authorized correction is applied: the existing dependency predicate is
  now explicitly returned after the concrete mismatched-service guard. The
  changed region was re-read, its intended fallback semantics were confirmed
  independently, the exact structural source check passes, dirty count remains
  114, and `git diff --check` passes. A fresh full preflight is the only next
  action; Green12 remains unproven.

### Search notification Green12 rerun preflight — passed

- At 2026-07-14 00:06 CDT, origin fetched successfully. Branch
  `feat/goose-surface`, local HEAD, fetched origin, and the handoff publication
  commit all equal `668b52cfb43721de95db102260d9f327ae24e13e`. Dirty
  count is 114 and `git diff --check` passes.
- Swap used is 11,177.75 MiB, strictly below the 16,384-MiB lock; free memory
  is 67%; pages throttled are zero; disk availability is 723 GiB; and no
  competing scoped process is active.
- App/archive inventory is empty. Fresh rerun DerivedData, result, and log paths
  are absent. The failed first-attempt result/log remain retained and their log
  digest re-verifies as
  `1324ec22b8051d335fa6f0b66c00f8579587e2752b6e97de78601bb71ab2815e`.
- Selector extraction from the failed command returns exactly twenty-four
  total and twenty-four unique selectors, including the Red12 regression once.
  The source correction structural guard passes. Exactly one serial rerun is
  authorized at
  `/private/tmp/Epistemos-SearchNotificationGreen12Rerun-16GiB` with retained
  `build/xcode-results/2026-07-14-search-notification-correlation-green12-rerun-16gib.*`.
  No second build or broader action is authorized.

### Search notification Green12 rerun — invalid zero-test selection

- The authorized rerun compiled and linked successfully and exited zero, but it
  is not Green evidence: direct xcresult inspection reports build status
  `succeeded` with zero errors and three unrelated warnings, while the test
  result is `unknown` with zero total/passed/failed/skipped/expected tests. The
  log independently says `Test run with 0 tests`.
- Exact cause is selector spelling. The attempted twenty-four selector names
  omitted the required trailing `()` used by this Swift Testing bundle. The
  retained proven Green11 command contains `()` on every one of its twenty-three
  selectors, and its result nodes use the same identifiers. This is command
  correction only; no source edit is authorized or needed.
- The invalid result is retained at
  `build/xcode-results/2026-07-14-search-notification-correlation-green12-rerun-16gib.xcresult`
  and occupies 560 KiB. Its 2,052-KiB log has SHA-256
  `19d588de28e62a9017b7592ad46392dc0fead227a10a46296eaa152b8c1a80ae`.
- Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
  `98396e509a692d0bcaff586cc83153b7fa6e0974834a587041f2c28477269ee9`;
  the bundle occupied 490,604 KiB. Resources were 11,519.69 MiB swap used,
  67% free memory, zero throttled pages, and 721 GiB disk. No scoped process
  remains. Identity remains exact, dirty count is 114, and diff-check passes.
- Exact next action is retain the invalid result/log, delete the disposable
  build, verify zero-build inventory, then run a new complete preflight for a
  corrected twenty-four-selector command whose every identifier ends in `()`.
  Green12 remains unproven.

### Search notification Green12 corrected-selector preflight — passed

- The invalid zero-test DerivedData was deleted after identity capture. Its
  result/log remain retained and the log digest re-verifies. App/archive
  inventory is empty.
- At 2026-07-14 00:11 CDT, origin fetched successfully and the branch/local/
  origin/handoff identity remains exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 114 and
  diff-check passes.
- Swap used is 11,519.69 MiB below the 16,384-MiB ceiling; free memory is 68%;
  pages throttled are zero; disk is 723 GiB; and no scoped process is active.
- The corrected selection is twenty-four total and twenty-four unique
  identifiers. Every identifier ends in `()`, the twenty-three proven Green11
  names are preserved, and the Red12 regression is added once. Fresh
  DerivedData/result/log paths are absent. Exactly one corrected serial batch
  is authorized; Green12 is still unproven until direct result inspection.

### Search notification Green12 corrected batch — passed

- The one corrected serial batch exited zero. Direct xcresult summary reports
  result `Passed`: twenty-four total, twenty-four passed, zero failed, skipped,
  or expected failures on arm64 macOS 26.3.1. Direct build inspection reports
  status `succeeded`, zero errors, and three unrelated retained warnings.
- Direct test-node and targeted test-detail inspection prove
  `appStoreSearchNotificationsStayWithTheirProducingService()` passed in
  0.014 seconds. The retained log independently records that named pass, the
  twenty-four-test suite pass, and terminal `TEST SUCCEEDED`.
- The exact Green result is
  `build/xcode-results/2026-07-14-search-notification-correlation-green12-selected-rerun-16gib.xcresult`
  at 136,940 KiB. Its 2,052-KiB log has SHA-256
  `8808bed8c621a3d94b5f43f1d7477cc44c1e82c702c509cf5bb34cea100b41d6`.
- Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
  `55dea8d717e03ba550c99bc4c3e74f8d2b0bacccd97db34081ce82a811ba883f`;
  the bundle occupied 490,612 KiB. Resources were 11,519.69 MiB swap used,
  67% free memory, zero throttled pages, and 721 GiB disk. No scoped process
  remains; the SHA triple remains exact, dirty count is 114, and diff-check
  passes.
- Green12 closes the bounded Search producer-correlation evidence leg. The
  overall KEELSTONE verdict remains `INCOMPLETE`; exact next action is delete
  the disposable build after identity capture, verify empty inventory, retain
  all result/log evidence, and compare the next bounded verification debt
  read-only before authorizing any new edit or build.
- The exact Green12 DerivedData was deleted after identity capture. It is
  absent and app/archive inventory is empty across the scoped roots. Direct
  result inspection expanded the retained result to 137,192 KiB; the retained
  log remains 2,052 KiB with the same verified digest. Cleanup resources are
  11,503.69 MiB swap used, 68% free memory, zero throttled pages, and 722 GiB
  disk. No scoped process remains; identity/diff state is unchanged. The next
  action is read-only debt comparison, not another build.

### Fiftieth checkpoint — restore FTS5 in the App Store executable without a second SQLite

**Owner wording (verbatim excerpts)**

> “make it lock at 16gb at this point man”

> “the main issue ... were the performance of epdoc and sitchgn from and to
> edpco would hang take time cause lag andbugs etc.”

> “every single thgn neeeds to be auditte d ... load times throttlews hangs
> isasues ith memoery and data”

**Interpreted intent**

- Continue the same canonical execution key,
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`, and keep performance and
  release hardening ahead of MAS-canon feature construction.
- Restore the intended FTS5 page, block, and readable-block projections in the
  actual App Store test host. Current exact logs initialize every fresh Search
  service with all three FTS5 flags false, forcing plain-table fallback even
  though FTS5 is part of the canonical Search/RRF architecture.
- Remove only the unused Cozo persistent-SQLite/request/graph-algorithm feature
  closure from `graph-engine`. Preserve its three current in-memory pure-Datalog
  users and do not replace, weaken, or delete Search fallback behavior.

**Current-source and research grounding**

- `graph-engine/Cargo.toml` currently enables Cozo 0.7.6 defaults. The resolved
  default `compact` feature includes `minimal`, and `minimal` includes
  `storage-sqlite` plus bundled `storage-sqlite-src`. The built
  `libgraph_engine.a` exports 269 `_sqlite3_*` symbols and is linked into the
  App Store executable before the GRDB product.
- Graph-engine source constructs Cozo only as `DbInstance::new("mem", "", "")`
  in `knowledge_core/store.rs` and the two query-kernel helpers. A semantic
  source sweep finds no Cozo persistent storage, backup/restore, request,
  custom fixed-rule, or optional graph-algorithm use.
- The system SQLite on this machine reports `ENABLE_FTS5` and completes a real
  temporary FTS5 `MATCH` round trip. Current Green12 executable logs repeatedly
  report `fts5_pages=false fts5_blocks=false fts5_readable_blocks=false`.
- Local canon requires one shared GRDB Search database, external-content FTS5,
  and derived/disposable Search truth. Official SQLite documentation requires
  `SQLITE_ENABLE_FTS5` for a compiled-in FTS5 module. Cozo 0.7.6 documentation
  confirms its memory database is available independently, its defaults enable
  SQLite, requests, and graph algorithms, and pure Datalog can operate without
  `graph-algo`. GRDB's current primary documentation warns against multiple
  SQLite implementations in one process because of linker/runtime conflicts.
- This is a strong linked-symbol causal diagnosis, not yet a completed runtime
  proof. Only the exact Red/Green sequence below may promote it to proven.

**Hard constraints and non-goals**

- Before every test or build, swap used must be strictly below 16,384 MiB,
  free memory at least 25%, throttled pages zero, disk sufficient, and no
  competing Xcode/compiler/model/Epistemos process active.
- Keep one current Epistemos app artifact only. Before each Xcode test build,
  remove stale disposable app/archive products; after identity capture, remove
  that build before any later app build. Run no competing Xcode job.
- Test first. Red13 may change only the serialized App Store test file and must
  exercise the actual linked SQLite plus the real Search schema. No production
  correction is authorized before exact Red13 evidence.
- Do not change Search schema/fallback/query semantics, vault data, Spotlight,
  Eidos, Recall, editor UI, Free V1 capability policy, paid June/Browser/
  ResearchHub, feature/canon work, payment, model/provider/secret/audio,
  archive/runtime launch, or another execution key.
- Do not access or infer private Columbia/VA/funding material, an unavailable
  Treasure drive, another laptop, or any owner-vault/removable-storage data.

**Acceptance checks, done bar, and verification debt**

- Red13 creates one isolated `SearchIndexService` in the actual App Store host,
  seeds page and block rows plus one readable-block row, and requires
  `page_search`, `block_search`, and `readable_blocks_fts` to exist and return
  their exact unique tokens through real `MATCH` queries. Current source is
  expected to fail at the missing-table requirement before any production edit.
- After exact Red, the bounded correction is only
  `cozo = { version = "0.7.6", default-features = false }` plus the mechanical
  Cargo lock reconciliation. Any required additional Cozo feature must be
  justified by a current call site; no speculative feature is enabled.
- Green requires graph-engine compilation and relevant Cozo-memory/Datalog
  regressions, a rebuilt linked archive with zero exported `_sqlite3_*` symbols,
  the exact Red13 behavior test, and the prior twenty-four Green12 selectors in
  one serialized twenty-five-test App Store batch.
- Direct result inspection, retained log digest, exact disposable app identity,
  resource capture, source/diff audit, and complete build cleanup remain
  mandatory. An archive, manual app launch, full runtime matrix, broad suites,
  Spotlight/Eidos closure, and final release readiness remain verification debt.

**Contradictions and resolution**

- The typed Spotlight deletion helper receipt is textually smaller, but its
  proposed current test is source-only and cannot prove Core Spotlight behavior
  or caller ownership. FTS5 has current executable failure evidence, a bounded
  causal hypothesis, and direct relevance to Search latency and scale; it is
  selected first without deleting or downgrading the Spotlight debt.
- Eidos deletion is a real stale-retrieval defect in the retained paid runtime,
  but Free V1 intentionally does not link `agent_core`; meaningful Eidos Red
  evidence therefore requires a later paid target and cross-language FFI work.
  It is not mixed into this Free V1 release leg.
- FTS5 is derived, not vault truth. Restoring it improves the projection while
  preserving the canonical vault/artifact source of truth and the existing
  no-FTS fallback for genuinely unsupported environments.

**Exact next action**

- Add only the one App Store-host FTS5 Red13 regression. Re-read its complete
  region, inspect the diff, and run `git diff --check`. Then perform a new full
  16-GiB preflight. Only a passing preflight may authorize one serial selected
  Red13 Xcode test build; the Cozo dependency correction remains unauthorized
  until that exact result is inspected and proves the intended failure.

### FTS5 Red13 harness boundary

- The sole Red13 source edit is now present in the serialized App Store test
  file. It creates one isolated Search database, seeds one page row, one
  page-owned block row, and one readable-block row, then queries `sqlite_master`
  for exactly `page_search`, `block_search`, and `readable_blocks_fts`.
- The table-set expectation precedes a guard. Current source should therefore
  fail once on the empty required-table set and return without emitting
  secondary `no such table` errors. If all three tables exist, the test runs
  raw page, block, and readable-block `MATCH` counts and requires `1/1/1` for
  unique per-run tokens. No Search or readable fallback API can satisfy it.
- An independent read-only harness review found two test-only risks, both
  corrected before execution: the GRDB table-name bindings now use explicit
  `StatementArguments`, and the readable row is inserted directly inside the
  test database transaction so no asynchronous unscoped Search notification
  can leak into the next serialized test. The test no longer needs `async` or
  a heuristic `Task.yield()` drain.
- The full changed region was re-read. `graph-engine/Cargo.toml` remains
  unchanged at `cozo = "0.7.6"`; no production correction is present.
  `git diff --check` passes. Red13 remains unexecuted.
- Exact next action is a complete fresh locked preflight, including origin and
  handoff identity, dirty state, swap/free/throttled/disk/process state,
  zero-current-build inventory, and absent fresh result paths. Only a passing
  preflight may authorize the single selected Red13 Xcode test build.

### FTS5 Red13 executable proof

- The complete Red13 preflight passed after a fresh origin fetch. Branch
  `feat/goose-surface`, local HEAD, fetched origin, and the handoff publication
  commit were identical at `668b52cfb43721de95db102260d9f327ae24e13e`;
  dirty count was 114 and `git diff --check` passed. Swap used was 11,375.62
  MiB, free memory was 75%, pages throttled were zero, disk availability was
  722 GiB, no competing build/compiler/model/Epistemos runtime was active, the
  scoped app/archive inventory was empty, and all fresh evidence paths were
  absent.
- One isolated App Store test build then ran. Direct result-bundle inspection
  reports build status `succeeded`, zero build errors, one total test, zero
  passes, and exactly one failure at the table-set expectation. The actual
  linked host initialized the fresh Search service with
  `fts5_pages=false fts5_blocks=false fts5_readable_blocks=false`; the
  installed table set was empty instead of exactly `page_search`,
  `block_search`, and `readable_blocks_fts`. The guard prevented secondary
  `no such table` failures. This is the required executable Red, not a compile
  failure and not a fallback-path result.
- The retained result is
  `build/xcode-results/2026-07-14-search-fts5-linked-sqlite-red13-16gib.xcresult`.
  The retained 1,387,824-byte log has SHA-256
  `357380c51f43d1deaabef0bd34716286c0373dc81cf42c13a9870fac356a6e4d`.
  Before cleanup, the disposable app occupied 490,604 KiB and its 40,344-byte
  executable had SHA-256
  `437c9448ce794f4bbad7626f3aa0d5bdf0b11d570d8263af44166e6e2ab9ac90`.
  Immediate resources were 11,577.19 MiB swap used, 68% free memory, zero
  throttled pages, and 720 GiB available disk.
- The exact disposable DerivedData was deleted after identity capture. It is
  absent, the retained result/log remain present, and scoped app/archive
  inventory is empty. Red13 proves the current App Store executable lacks all
  three Search FTS5 projections. It does not by itself prove the Cozo feature
  diagnosis, the correction, Search performance, archive/runtime behavior, or
  release readiness.
- The production correction is now narrowly authorized: re-read the current
  Cozo declaration and lock closure, change only `graph-engine/Cargo.toml` to
  Cozo 0.7.6 with `default-features = false`, reconcile `Cargo.lock` only if
  Cargo mechanically changes it, then inspect the exact manifest/lock diff.
  No Swift production code, Search schema/fallback, route, feature, vault,
  archive, or runtime-launch change is authorized. Do not start the Green13
  Xcode batch until graph-engine regressions and a rebuilt archive prove the
  in-memory/Datalog path still passes and exports zero `_sqlite3_*` symbols.

### Cozo zero-feature compile constraint — Red13b

- The first locked graph-engine suite attempt after the bounded manifest and
  mechanical lock reconciliation did not run tests. Cozo 0.7.6 compilation
  failed because its non-WASM evaluator imports `rayon::prelude`, calls
  `par_iter()` in two core query paths, and calls `rayon::spawn()` in its
  transaction path even when no feature is selected. Four compiler errors
  proved that literally zero Cozo features is not a valid macOS build closure.
- Cozo's own manifest declares Rayon as an optional dependency and exposes its
  implicit `rayon` feature; `graph-algo` is a broader feature that adds both
  Rayon and the separate `graph` package. The current Epistemos call sites use
  only in-memory pure Datalog, so the exact justified closure is Cozo 0.7.6
  with `default-features = false, features = ["rayon"]`. Do not enable
  `graph-algo`, `minimal`, SQLite storage/source, requests, or another backend.
- The retained 3,902-byte Red13b compile log is
  `build/xcode-results/2026-07-14-graph-engine-cozo-zero-feature-red13b-compile-16gib.log`
  with SHA-256
  `7bb0fc0c6d53a3b12949c7dcf59c7b3d66d9a0bf8037ce091bc0536a8ef80184`.
  It is a dependency-closure Red, not a test result. No app archive or staged
  graph archive exists. Immediate resources remain 11,577.19 MiB swap used,
  70% free memory, zero throttled pages, and 722 GiB available disk.
- Exact next action is to add only `features = ["rayon"]` to the existing Cozo
  declaration, mechanically reconcile the lock again, and inspect that Rayon
  returns without any SQLite/request/graph-algorithm package. A new complete
  16-GiB preflight is required before retrying the full exact-feature Rust
  suite. The Green13 App Store build remains unauthorized.

### Direct outline-memory verification debt

- The Rayon-only locked graph-engine suite now passes 2,871 tests with zero
  failures, and the rebuilt arm64/x86_64 archive exports zero `_sqlite3_*`
  symbols. A read-only coverage audit nevertheless found that existing tests
  directly exercise the persistent knowledge-core `DatalogStore` and the BTK
  property Cozo database, but not the separate `outline_db` constructor used
  by `BtkQueryKernel.subscribe_outline` after a page is materialized.
- Before authorizing the App Store Green, add exactly one test in the existing
  query-kernel test module. It must sync the existing two-block fixture before
  subscribing, consume the initial outline payload, and prove both root/child
  rows round-trip through page, parent, depth, and content fields. This order
  is mandatory: subscribing before sync would take the missing-page shortcut
  and later exercise only the incremental non-Cozo path.
- This is test-only coverage for the third and final current Cozo memory
  constructor. It must add no seam, fixture, dependency, feature, production
  behavior, schema, or FFI change. Re-read the changed region and diff-check,
  then run a fresh 16-GiB preflight followed by the one exact test and the full
  exact-feature Rust suite. Only after both pass may the staged archive be
  treated as stale and deleted before the one fresh Green13 app build.

### Direct outline-memory proof passed

- The new test syncs the existing root/child fixture before subscribing and
  therefore executes `outline_db` creation, import, Datalog query, and row
  decoding. Its exact offline selector passed once in 0.02 seconds with zero
  failures. The retained 736-byte narrow log has SHA-256
  `bf3d82f2d2fee76eaf7e7c92dbf3c07e01f6c1308ea403ebb4987d1e10fef112`.
- The complete exact-feature suite then passed again: 2,872 total passed, zero
  failed, and eight intentional ignores across library, integration, stress,
  visual-equivalence, and doc tests. The retained 249,034-byte final log is
  `build/xcode-results/2026-07-14-graph-engine-cozo-minimal-green13-rust-tests-rerun-16gib.log`
  with SHA-256
  `17f3f0d2e62f3ebca05c0db97b9aebe9c5bb8449c572cd4bea0aa1fe439c4e01`.
  Targeted Rust formatting and repository diff checks pass.
- Post-test resources were 11,577.19 MiB swap used, 70% free memory, zero
  throttled pages, and 717 GiB available disk. The pre-test staged graph
  archive was deleted so the next app build cannot reuse it. App/archive
  inventory is empty; local/origin/handoff identity remains exact; dirty count
  is 117.
- Exact next action is to construct the Green13 selection from the proven
  twenty-four Green12 selectors plus
  `appStoreLinkedSQLiteProvidesAllSearchFTS5RoundTrips()` exactly once. Audit
  twenty-five total/unique selectors and every `()` suffix, confirm the fresh
  DerivedData/result/log paths are absent, then run a full new 16-GiB preflight.
  Only that passing gate authorizes one serial App Store test build. The build
  must create the sole current app and graph archive; after the batch, directly
  inspect the result, require FTS5 `true/true/true` plus 25/25 passes, inspect
  the just-built graph archive for zero SQLite exports, capture app identity,
  and delete the disposable build before any later action.

### Owner resource-lock steer — 16 GiB is the durable ceiling

**Verbatim owner wording**

> "make it lock at 16gb at this point man"

**Interpreted intent**

- The conservative KEELSTONE resource gate is now permanently locked at
  strictly below 16 GiB of swap used before any test or build. This supersedes
  the earlier temporary 8/10/12-GiB thresholds; it does not weaken any other
  resource or one-build control.

**Hard constraints and non-goals**

- A preflight passes only when swap used is below 16,384 MiB, system free
  memory is at least 25%, pages throttled are zero, disk is sufficient, and no
  competing Xcode/compiler/model/Epistemos runtime is active.
- Run only one serial Xcode job. Delete stale disposable Epistemos app/archive
  products before every app build, retain only the active evidence artifact,
  capture its exact identity, then delete its DerivedData/app product before a
  later build.
- This steer changes only the resource ceiling. It does not authorize archive,
  launch, model/provider, owner-vault, removable-storage, private work,
  feature/canon, payment, or a later execution key.

**Acceptance checks and next action**

- Record the exact preflight measurements for every later test/build and stop
  without executing if any threshold fails.
- Continue the already-authorized single Green13 batch, inspect its exact
  result without inference, retain result/log evidence, capture disposable
  artifact identity, and clean the build before any later test/build.

### Green13 rejected — writer maintenance leaked into read connections

- The one serialized twenty-five-test App Store batch compiled and linked, but
  direct result inspection reports `Failed`: 25 total, 14 passed, 11 failed,
  zero skipped, and zero expected failures. The eleven failed tests all share
  `SQLite error 8: attempt to write a readonly database - while executing
  PRAGMA optimize`; one test records two issues, so the console's twelve-issue
  count is not twelve failed tests.
- Every fresh Search initialization in the retained log now reports
  `fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`. The linked-
  SQLite correction therefore restored the three FTS5 capabilities, but the
  batch is not Green because opening a GRDB reader executes the current
  connection-preparation `PRAGMA optimize`, which can write planner statistics.
- Direct build-result inspection reports build status `succeeded`, zero errors,
  and three unrelated retained warnings. This is a runtime test failure, not a
  compile or selector failure.
- The retained result is
  `build/xcode-results/2026-07-14-search-fts5-linked-sqlite-green13-selected-16gib.xcresult`.
  The retained 1,488,467-byte log has SHA-256
  `d661d4b5d829003626cc95ed55f975f835cf4723b69bfe4270bb97a409aa7cb1`.
  Before cleanup, the disposable app occupied 475,772 KiB; its 40,344-byte
  executable had SHA-256
  `f46884543c2d9188cd2966fe4b566226f6f4814aca52494e43d639948836f8d1`.
- The exact build-created universal graph archive is arm64/x86_64,
  928,375,752 bytes, and has SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
  Exported `_sqlite3_*` counts remain zero in the universal, arm64, and x86_64
  symbol views; an independent archive string scan also finds zero SQLite
  symbol names.
- Immediate resources are 11,618.19 MiB swap used, 68% free memory, zero
  throttled pages, and 710 GiB available disk. Local HEAD, fetched origin, and
  the handoff publication commit remain exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
  `git diff --check` passes.
- Overall KEELSTONE remains `INCOMPLETE`. No production edit or rerun is
  authorized until the exact red artifacts are retained, disposable app/build
  products are deleted, and the current `PRAGMA optimize` ownership plus
  nearby tests/contracts are audited read-only. The correction must remain
  surgical and test-first; no unrelated source-hardening lane reopens here.

### Green13 cleanup and writer-only optimizer correction boundary

- The disposable Green13 DerivedData/app and exact build-created
  `build-rust/libgraph_engine.a` were deleted after identity capture. Both are
  absent. Scoped app/archive inventory is empty. The retained result remains
  136,708 KiB and the retained log digest re-verifies as
  `d661d4b5d829003626cc95ed55f975f835cf4723b69bfe4270bb97a409aa7cb1`.
- Current GRDB 7.10 source and documentation prove that
  `Configuration.prepareDatabase` runs for the DatabasePool writer and every
  lazy reader, and that reader configurations set `readonly = true`. Current
  SQLite documentation and implementation prove that `PRAGMA optimize` may
  invoke `ANALYZE` and write planner-statistics tables; it is conditionally,
  not inherently, read-only.
- Local KEELSTONE canon requires `PRAGMA optimize` at maintenance points rather
  than hot-path `ANALYZE`. The existing memory-pressure path already calls it
  through `dbPool.write`. The current shared connection-preparation placement
  is therefore the ownership defect, not a reason to delete optimizer
  maintenance or move it into Search/query work.
- The exact surgical production correction is authorized: remove only
  `PRAGMA optimize` from the shared multi-pragma SQL block, then execute that
  same pragma immediately afterward only when
  `!db.configuration.readonly`. Every other pragma, integrity check, schema,
  Search/FTS behavior, and the writer-owned memory-pressure maintenance path
  remains unchanged.
- Green13 itself is the failing behavior test: the FTS5 regression and ten
  existing selected tests all open a pool reader and fail before their query
  bodies. No additional seam or test is required before this two-part source
  move. After the edit, re-read the complete configuration region, inspect the
  exact diff, run source/diff checks, and resolve the separately logged
  database-lifetime warning audit before authorizing a fresh 16-GiB preflight.
- The retained log also exposes three `libsqlite3` vnode-unlink API-violation
  messages from one temporary Search test, plus one notification-rate warning
  and one priority-inversion runtime warning. These are not silently treated as
  Green. Their ownership remains explicit verification debt; only the bounded
  SQLite-lifetime signal is being audited before the next selected batch.

### Green13 temporary-database lifetime warning resolved to test teardown

- All three vnode-unlink warnings belong to
  `appStoreInitialImportPublishesCommittedSearchDependenciesOnce()`. That test's
  `VaultIndexActor` retains its Search service both as the active service and,
  until consumption, in the suppressed mutation batch. The failed first reader
  unwinds into a defer that removes the temporary Search root while the actor
  still holds the pool; system SQLite then reports the database, WAL, and SHM
  descriptors being invalidated.
- This warning sequence is test teardown fallout, not the initiating production
  failure. The production failure remains the unguarded optimizer on a lazy
  read-only pool connection.
- The smallest deterministic test-only correction is authorized: register the
  cleanup defer after the Search service is created and call the already-
  exposed `searchService.databaseWriter().close()` before removing the two
  temporary roots. No new production lifecycle API or test seam is allowed.
- The retained Green13 log is the Red for both changes: it proves the common
  reader exception and the three still-open-file warnings. The later single
  selected batch must contain neither signal. Notification-rate and priority-
  inversion warnings remain separately recorded verification debt.

### Writer-only optimizer and deterministic teardown prepared

- The exact two scoped corrections are now present. In production,
  `PRAGMA optimize` no longer appears in the shared multi-pragma batch and runs
  immediately afterward only under `!db.configuration.readonly`; the separate
  memory-pressure call remains in `dbPool.write`. In the one actor-retained
  test, cleanup now closes `searchService.databaseWriter()` before deleting the
  vault and Search temporary roots.
- The complete production configuration and complete changed test opening were
  re-read. The exact diff was inspected, `git diff --check` passes, and dirty
  count remains 117. Current source SHA-256 values are
  `bbd455a749460fa52c31155b3176ae686fd5e2f298cd6c43262ff03bf0c32c54`
  for `SearchIndexService.swift` and
  `7b39223065e06da332283cd7860023b93c65e97472c65e5a94b4e45ee0f973b6`
  for the App Store KEELSTONE test file.
- No test/build has run after these edits. Exact next action is to recover and
  re-audit the same twenty-five selected identifiers, choose new absent
  DerivedData/result/log paths, and run a complete fresh 16-GiB preflight.
  Only that passing gate may authorize one serial rerun.
- The rerun done bar is strict: build success; 25/25 tests; all three FTS5
  flags true; raw page/block/readable `MATCH` counts each one; zero read-only
  optimizer errors; zero SQLite vnode-unlink/client-bug/invalidated-descriptor
  messages; a fresh universal graph archive with zero `_sqlite3_*` exports;
  exact app/archive/log/result identity; and complete disposable build cleanup.

### Writer-only optimizer Green13 rerun preflight passed

- Origin fetched successfully. Branch `feat/goose-surface`, local HEAD,
  fetched origin, and the handoff publication commit are identical at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
  `git diff --check` passes.
- The recovered selection is exactly 25 total and 25 unique identifiers; every
  selector ends in `()` and resolves to exactly one current test function.
- Swap used is 11,610.19 MiB, below the locked 16,384-MiB ceiling; system free
  memory is 68%; pages throttled are zero; available disk is 690 GiB; and no
  Xcode/compiler/model/Epistemos runtime is active.
- A broad inventory across Xcode DerivedData, Xcode Archives, `/private/tmp`,
  and the repository build root finds zero Epistemos app/archive products.
  The fresh DerivedData path, staged graph archive, result bundle, and log are
  all absent.
- Exactly one serial twenty-five-test App Store rerun is authorized at
  `/private/tmp/Epistemos-SearchFTS5Green13WriterOnlyRerun-16GiB`, retaining
  `build/xcode-results/2026-07-14-search-fts5-writer-only-green13-rerun-16gib.*`.
  No overlapping build or broader action is authorized.

### Writer-only optimizer Green13 rerun passed

- The single authorized command exited zero. Direct result-summary inspection
  reports `Passed`: 25 total, 25 passed, zero failed, zero skipped, and zero
  expected failures. Direct test-node inspection independently lists all 25
  requested tests as passed. Direct targeted detail reports the linked-SQLite
  FTS5 test passed in 0.0082 seconds and the actor-retained initial-import test
  passed in 0.05 seconds.
- Direct build-result inspection reports status `succeeded`, zero errors, and
  three unrelated retained warnings: future incompatibility in Rust `block`
  0.1.6, one unnecessary Swift `await`, and one unused `try?` result.
- The log contains 15 Search initializations with
  `fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`, zero false FTS
  flags, and one explicit pass for the FTS5 behavior test. Because that test
  requires the three virtual tables plus raw unique-token page, block, and
  readable-block `MATCH` counts of one each, its pass is the required real
  round-trip proof.
- The console log contains zero read-only optimizer errors, zero SQLite client-
  bug/vnode-unlink/invalidated-descriptor messages, zero notification-rate
  warning text, zero priority-inversion warning text, and zero test-failure markers. It records
  one 25-test suite pass and one `TEST SUCCEEDED` marker.
- The retained 1,515,756-byte log has SHA-256
  `89e90e1b248626d6898226795b2ccb42513cced56d9fb04552761df601e0470b`.
  The retained result occupies 136,468 KiB after direct test-detail inspection.
  Before cleanup, the disposable app occupies 475,784 KiB; its 40,344-byte
  arm64 executable has SHA-256
  `3baffa337c7aa8364b976f7de5ad8ca49724c8b8fd7be446661dd7dd6e127c3c`,
  identifier `com.epistemos.appstore`, build 1, and version 1.0.0.
- The exact build-created graph archive is universal arm64/x86_64,
  928,375,752 bytes, and has SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
  Universal, arm64, and x86_64 exported `_sqlite3_*` counts are all zero; the
  independent archive string scan also finds zero SQLite symbol names.
- Post-run resources are 12,089.31 MiB swap used, 68% free memory, zero
  throttled pages, and 686 GiB available disk. No competing process remains.
  Local/origin/handoff identity remains exact; dirty count is 117 and
  `git diff --check` passes.
- This closes the bounded linked-SQLite/reader-ownership Green13 leg, not the
  whole release. Overall KEELSTONE remains `INCOMPLETE`. Exact next action is
  to delete only this disposable DerivedData/app and staged graph archive,
  verify empty broad app/archive inventory while retaining result/log evidence,
  then compare the next bounded verification debt read-only. No archive,
  launch, owner-vault, runtime matrix, canon/feature, payment, model/provider,
  secret, audio, or later execution key is authorized by this pass.

### Green13 rerun cleanup complete

- The exact disposable DerivedData/app and build-created graph archive are now
  absent. Broad inventory across Xcode DerivedData, Xcode Archives,
  `/private/tmp`, and the repository build root is zero. The retained result
  remains 136,468 KiB and the retained log SHA-256 re-verifies as
  `89e90e1b248626d6898226795b2ccb42513cced56d9fb04552761df601e0470b`.
- Cleanup resources are 12,065.31 MiB swap used, 68% free memory, zero
  throttled pages, and 689 GiB available disk. No competing process remains;
  dirty count is 117 and `git diff --check` passes.
- The safe boundary is a read-only comparison of the remaining KEELSTONE debts.
  No new edit, test, build, archive, launch, or later execution key is pre-
  authorized.

### Green13 full-result correction and Red14 drain-priority checkpoint

**Owner wording (exact excerpts)**

> “my ap eeds to be severels auditted for memory leakeage and any sematnically
> related term used to exemplfiy performance or other wise bugs lags throttles
> etc.”

> “make it lock at 16gb at this point man”

**Interpreted intent**

- Do not treat a passing count or console-log grep as performance completion.
  Inspect the retained result's warning nodes, preserve the 16-GiB safety lock,
  and close a concrete priority-inversion warning before constructing another
  app/archive.
- Preserve the intended Utility-QoS watcher processor during ordinary
  background work. Correct the dependency/wait ownership rather than masking
  the result with a test-only QoS override or moving indexing onto the UI lane.

**Current exact evidence**

- Direct `xcresulttool get test-results tests` inspection of
  `build/xcode-results/2026-07-14-search-fts5-writer-only-green13-rerun-16gib.xcresult`
  contains one `Runtime Warning` for
  `appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()`:
  a User-interactive thread waited on a Utility-QoS thread. Targeted
  `test-details` reports the same warning and a passing 0.069-second test.
- The prior statement was only true of the retained console log; that log does
  not serialize this result-bundle issue. Green13 remains 25/25 and closes its
  FTS5/SQLite/teardown behaviors, but it is not warning-free.
- The warning recurs in multiple earlier retained selected results for the same
  test. The production watcher task is intentionally detached at Utility QoS.
  The main-actor drain instead waits through a checked continuation, which
  hides the exact task dependency from Swift priority escalation.
- Current primary Apple guidance identifies high-QoS waits on lower-QoS work as
  a hang risk and recommends removing opaque synchronous-style waits. Current
  Swift Task documentation states that directly awaiting the target task is
  normally the correct way to obtain implicit priority escalation.

**Hard constraints, non-goals, and acceptance checks**

- This retained warning is Red14; no additional failing test or priority
  override is needed. Before editing, independently audit the serial queue,
  all admission owners, stop/disconnect caller, and race boundaries.
- The proposed correction may change only the drain's ownership of the already-
  stored watcher processor task: while watcher admissions remain, directly
  await each current task's `value`; retain the existing continuation fallback
  for non-watcher admissions. Ordinary processor QoS remains `.utility`.
- Do not change watcher results, Recall semantics, checkpoint/requeue truth,
  Search/Spotlight/Eidos, Free V1 policy, vault data, archive/runtime, feature/
  canon, payment, model/provider/secret/audio, or a later execution key.
- Before a rerun, require branch/local/origin/handoff equality, swap strictly
  below 16,384 MiB, free memory at least 25%, zero throttled pages, sufficient
  disk, no competing process, and empty app/archive inventory.
- Green14 requires the same exact twenty-five selected tests to pass, direct
  result inspection to contain zero failed/skipped tests and zero `Runtime
  Warning` nodes, the existing FTS5/SQLite/teardown bars to remain green, exact
  artifact/log identities, and complete disposable-build cleanup. Console-log
  absence alone cannot satisfy the warning bar.

**Exact next action**

- Finish the independent read-only causal/race review. If it confirms the
  bounded task-handle drain, apply only that production correction, re-read the
  complete changed region, inspect the diff, and run source/diff checks. Then
  perform a fresh full 16-GiB preflight; only a fully passing gate authorizes
  the one serial Green14 rerun. The Release archive remains blocked.

### Red14 source correction prepared

- Two independent reviews approved the exact task-handle drain and found no
  MainActor deadlock, FIFO regression, stop/disconnect admission race, or loss
  of non-watcher admission coverage.
- `waitForVaultMutationDrain()` now loops over the authoritative admission set,
  snapshots and directly awaits each current
  `vaultFileSystemProcessorTask.value`, and uses the existing checked
  continuation only when admissions remain without a watcher processor.
- The watcher remains detached at `.utility`; no priority suppression, polling,
  cancellation, Recall/checkpoint mutation, test-only seam, feature, route, or
  broader refactor was added.
- The complete changed and processor regions were re-read, the exact diff was
  inspected, `git diff --check` passes, and dirty count remains 117. No test or
  build has run after the correction.
- Exact next action: recover and validate the same twenty-five selectors and
  fresh absent evidence paths, then run the complete locked preflight. The one
  serial Green14 rerun is authorized only if swap is strictly below 16,384 MiB,
  free memory is at least 25%, pages throttled are zero, no competing process
  exists, disk is sufficient, and app/archive inventory is empty.

### Green14 preflight passed

- After a fresh origin fetch, branch/local/origin/handoff identity is exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and the diff
  check passes.
- The identical Green13 selection validates as 25 total, 25 unique, all with
  the `()` suffix, and every selector resolves to exactly one current test.
- Swap used is 12,001.31 MiB under the strict 16,384-MiB ceiling; free memory is
  71%; pages throttled are zero; disk availability is 683 GiB; the corrected
  process scan is empty; broad app/archive inventory is zero.
- Fresh Green14 DerivedData, result, log, and staged graph-archive paths are all
  absent. One serial twenty-five-test App Store rerun is now authorized. No
  archive, launch, runtime matrix, canon/feature work, or later execution key is
  authorized by this preflight.

### Green14 setup abort checkpoint

- The first invocation was stopped because macOS Bash lacks `mapfile`; without
  an immediate-exit guard, the selector list stayed empty and Xcode began an
  unfiltered setup.
- The partial result proves zero tests executed. The generated app path is an
  empty zero-KiB directory with no executable, the log contains no compilation
  or test marker, no graph archive exists, and no build process remains.
- This is not Green14 evidence. Delete its exact partial state before any new
  build, validate the replacement selector constructor without Xcode, and run
  a complete fresh preflight using new `-rerun` paths.
- The exact partial state was deleted and broad app/archive inventory is zero.
  The Bash-3-compatible replacement ran under immediate-exit mode without
  Xcode and produced exactly twenty-five selectors. A new build still requires
  a full fresh preflight.

### Green14 rerun preflight passed

- Exact branch/local/origin/handoff identity remains at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and the diff
  check passes.
- The corrected array has 25 selectors. Swap is 11,985.31 MiB, free memory is
  72%, throttled pages are zero, competing-process and app/archive counts are
  zero, and all new rerun paths are absent.
- One immediate-exit, serial, twenty-five-test rerun is authorized. No later
  execution step is authorized by this gate.

### Green14 result: RED

- The validated serial command completed and direct evidence proves 25/25
  tests passed with zero failed or skipped tests. Existing FTS5, SQLite,
  teardown, watcher, Recall, and checkpoint behavioral assertions remain
  green.
- Direct result inspection still contains exactly one Runtime Warning for
  `appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()`: the
  User-interactive/Utility priority inversion. The console log contains no
  warning text, again proving console grep is insufficient.
- Directly awaiting the tracked detached task did not close the warning. Treat
  that causal theory as falsified; do not raise processor QoS, suppress the
  warning, weaken the test, or make another speculative edit.
- The retained result/log identities and disposable app/graph identities are
  recorded in the exact-runtime evidence. Post-run swap is 12,093.06 MiB,
  free memory 66%, throttled pages zero, and no competing process remains.
- Exact next action: delete the disposable app/build and graph archive, retain
  the red result/log, then complete an independent read-only trace of the
  actual wait owner before authorizing any next correction or build. The
  Release archive remains blocked.
- The exact Green14 disposable app/build and graph archive are now deleted;
  broad product inventory is zero. The failed result/log remain retained, with
  the recorded log digest reverified. Only read-only causal analysis is now
  authorized.

### Green14 symbolicated RCA and bounded test-lifetime correction

**Owner wording (exact excerpt)**

> “make it lock at 16gb at this point man”

**Interpreted intent**

- Keep the strict 16-GiB resource ceiling while continuing the unresolved
  KEELSTONE evidence chain. Do not stop at a passing count, hide a runtime
  warning, or make another speculative production change.
- Correct the actual ownership boundary proven by current evidence, then use
  the smallest possible rerun before reopening the twenty-five-test batch.

**Corrected exact evidence**

- Green14's validated rerun passed all twenty-five selected tests, but direct
  result inspection preserved the same one Runtime Warning. The new direct
  `processorTask.value` wait did not affect the warning and is not its cause.
- Unified-log inspection identifies the runtime checker trigger as
  `dispatch_semaphore_wait`. Symbolication resolves SwiftData
  `ModelContainer` destruction through Core Data persistent-store removal,
  connection-manager disconnection, connection checkout, and a dispatch
  synchronous wait.
- The affected test is the only selected watcher case that performs the real
  missing-page `VaultIndexActor.fullPageData` fetch. The batch and Recall
  completion finish, then service stop logs, and only afterward the
  `@MainActor` test epilogue releases its local in-memory container. That final
  high-QoS teardown waits on Core Data's Utility connection and creates the
  warning.
- This stack excludes watcher drain, `AsyncCompletionProbe`, `NSLock`, the
  completion fence, and FSEvents as the warning owner.

**Hard constraints, non-goals, and acceptance checks**

- Revert only the ineffective production task-handle drain hunk; do not alter
  the surrounding user changes or watcher Utility QoS.
- Add only a private test-lifetime owner and restructure only the affected test
  into a nested scope. The service must stop and lose all references before an
  awaited dedicated Utility queue performs the final container release.
- No leak, static retention, unstructured task, semaphore, polling, warning
  suppression, priority override, production seam, route, schema, Recall,
  checkpoint, Search, Spotlight, Free V1, archive/runtime, owner-vault,
  feature/canon, payment, model/provider, secret, audio, or later execution-key
  change is allowed.
- Before any build: exact branch/local/origin/handoff identity; swap strictly
  below 16,384 MiB; at least 25% free memory; zero throttled pages; no competing
  process; sufficient disk; zero stale Epistemos app/archive products; and
  fresh absent DerivedData/result/log paths.
- The first proof may select only
  `appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()`. It must
  pass and direct result-node inspection must report zero Runtime Warning
  nodes. Console-log absence is insufficient. Delete the exact disposable app
  and graph archive after identity capture.
- Only a green single-test discriminator may authorize a fresh twenty-five-test
  regression batch. The Release archive remains blocked until the complete
  bounded evidence chain is green.

**Exact next action**

- Apply the surgical production-hunk revert and one-test lifetime owner; re-
  read the full changed regions and exact diff; run source/diff checks; delete
  the temporary read-only diagnostic export; then run the complete locked
  preflight. Do not start Xcode unless every gate passes.

### Red14 bounded source checkpoint

- The ineffective Green14 production Task-await hunk is surgically reverted;
  production drain and Utility watcher behavior are back at the proven
  pre-Green14 source boundary.
- A private lock-backed container owner and awaited serial Utility release
  queue exist only in the App Store test file. The affected test alone runs its
  service/body in the owner's nested scope, so service stop and temp cleanup
  precede the final off-main container release even when the body throws.
- The helper introduces no leak, static retention, unstructured task,
  semaphore, sleep, polling, warning suppression, priority override, or
  production seam. No other container test was generalized without evidence.
- The complete regions and exact diff were inspected; `git diff --check`
  passes; dirty count remains 117. Current source digests are
  `7246b51071b6403a2810d22e569eabb6db4337e568b532cc3adccb1b381c28ec`
  for `VaultSyncService.swift` and
  `8f03f473815429989288d80b903601dfd1feb00a80a8f73541e18c24d0532832`
  for the App Store test file.
- No test/build has run after the correction. Delete the temporary diagnostic
  export, then require a full 16-GiB preflight before the single focused proof.
- The temporary diagnostic export is deleted and its path is absent. The
  retained Red result/log remain intact and the log digest re-verifies. The
  next action is now the focused-selector audit and full locked preflight.

### Red14 focused preflight passed

- Two scanner-only preflight attempts failed closed before Xcode because of an
  `awk` regex error and zsh's special `path` variable. No build/test/product or
  source change occurred. The corrected scanner then completed successfully.
- Branch/local/origin/handoff identity is exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117; the diff
  check passes; and the one focused selector resolves exactly once.
- Swap is 12,020.94 MiB under the strict 16,384-MiB ceiling, free memory is
  67%, throttled pages are zero, available disk is 668 GiB, and competing-
  process and stale app/archive inventories are zero.
- All focused DerivedData/result/log/graph staging paths are absent. One serial
  focused test is authorized; no broader execution step is.

### Red14 focused proof passed

- The one serial focused command exited zero. Direct summary, test-tree, and
  targeted test-details inspection all report the exact selected test passed;
  failed, skipped, and expected-failure counts are zero.
- The direct test tree and targeted details each contain zero Runtime Warning
  nodes, and targeted details contain zero priority-inversion/QoS/semaphore
  text. The console independently records the named case and one-test suite
  pass with zero warning text and `TEST SUCCEEDED`.
- Exact retained identities: result 576 KiB; log 1,469,740 bytes with SHA-256
  `e5680932c6df37cab325ef997191204d5457ed16590169098f73aded42b337de`;
  disposable arm64 executable 40,344 bytes with SHA-256
  `c9d3d9f54b8e6ce9b3660a2c5ccff7a5b301927b5c6194618a5d7461f9e16aa0`;
  universal graph archive 928,375,752 bytes with SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`
  and zero SQLite exports/string names.
- The build result retains three unrelated compiler/toolchain warnings, and
  the console retains duplicate-column migration and metadata messages. This
  focused result closes only Red14's exact warning, not general log debt or
  release readiness.
- Post-run swap is 13,003.25 MiB under the 16-GiB ceiling, free memory is 70%,
  throttled pages are zero, disk is 665 GiB, and no competing process remains.
- Exact next action is focused build/graph/temp-JSON cleanup, followed by a
  fresh full gate for the exact twenty-five-test regression batch. No archive
  or broader runtime step is authorized yet.
- Focused cleanup is complete: disposable app/build, graph archive, and parsed
  JSON are absent; broad product inventory is zero; retained result/log
  identities reverify. Resources remain inside the 16-GiB gate. The exact next
  action is the twenty-five-selector audit and fresh regression preflight.

### Red14 regression preflight passed

- The retained Green14 command reconstructs exactly 25 total/unique selectors;
  all retain `()` and resolve once in current source.
- Branch/local/origin/handoff identity remains exact; dirty count is 117 and
  the diff check passes. Swap is 13,003.25 MiB under the 16-GiB ceiling, free
  memory is 70%, throttled pages are zero, disk is 668 GiB, and competing-
  process and stale-product inventories are zero.
- Fresh regression DerivedData/result/log/graph paths are absent. One serial
  25-test batch is authorized; archive/runtime/canon work remains blocked.

### Red14 regression passed

- Direct summary is 25/25 with zero failed/skipped/expected failures. A
  recursive direct tree audit independently finds 25 passing cases, zero non-
  passing cases, and zero issue nodes.
- The full tree and targeted formerly Red test contain zero Runtime Warning
  nodes and zero priority/QoS/semaphore text. The console also has zero matching
  warning text, 25 named passes, one 25-test suite pass, and no failure marker.
- All 15 Search capability lines are true/true/true. Read-only optimizer,
  SQLite client/vnode/descriptor, FTS false, and real notification posting-rate
  counts are zero. The broad notification regex's sole match was a compiler
  action naming `UserNotifications`, not a runtime warning.
- Exact retained identities: result 800 KiB; log 1,511,031 bytes with SHA-256
  `2f3690e5d835f5ade2321ef0547066b7e3cc894b41698cf1cb4f6c1cc0c657d7`;
  disposable executable SHA-256
  `9d07036d94c49c024581222f08e84cbfe80d7b107e2ab3ea46b3d5d0375ff6ae`;
  universal graph SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`
  with all SQLite export/string checks zero.
- The same three build warnings, two short duration outliers, twelve duplicate-
  column bootstrap messages, and one metadata message remain explicit later
  debt. This is Red14 closure, not release readiness.
- Post-run swap is 12,963.25 MiB under 16 GiB, free memory is 69%, throttled
  pages are zero, disk is 665 GiB, and no competing process remains.
- Exact next action is disposable regression cleanup, then read-only debt
  comparison before deciding whether a Release archive is authorized.
- Regression cleanup is complete: the exact disposable DerivedData/app, staged
  graph archive, and parsed JSON are absent; broad app/archive inventory is
  zero; the retained 800-KiB result and retained log SHA-256
  `2f3690e5d835f5ade2321ef0547066b7e3cc894b41698cf1cb4f6c1cc0c657d7`
  reverify. Cleanup resources are 12,963.25 MiB swap, 69% free memory, zero
  throttled pages, 668 GiB disk, and zero competing process. Dirty count is 117
  and the diff check passes. Read-only debt comparison is now the only allowed
  next action before a new full 16-GiB archive preflight.

### Current-source archive authorization comparison

- Independent and primary read-only comparison agree that the focused 1/1 and
  selected 25/25 Red14 evidence close the remaining narrow compile/regression
  prerequisite. No earlier retained Red leg is still designated as an archive
  prerequisite.
- The owner-locked order is now one new full 16-GiB archive preflight, exactly
  one serial fresh `Epistemos-AppStore` Release archive, all artifact gates
  against that exact archive, and launch/runtime only if every gate is green.
- Broad suites, Eidos/Spotlight/rescan/manual-sync/structural-recovery debt,
  three retained build warnings, bootstrap messages, performance/storage soak,
  manual runtime, distribution, and repeated-zero-fail evidence remain open
  and prohibit a release-ready verdict; they do not precede archive creation in
  the current explicit evidence chain.
- The handoff's older statement that its July 13 archive still exists is stale:
  actual broad inventory is zero after later source changes. That artifact must
  not be reused, and the handoff must be reconciled after the new exact archive
  result is known.
- Current wrapper, gate, scanner, project phases, scheme, Release settings,
  entitlements, and privacy manifest were read before authorization. The only
  next action is the fresh complete preflight for
  `/private/tmp/Epistemos-KeelstoneCurrentReleaseArchive-16GiB`,
  `build/archives/Epistemos-FreeV1-current-2026-07-14.xcarchive`, and the fresh
  dated result/log siblings. No launch is authorized by this comparison.

### Current-source Release archive preflight passed

- A first read-only inventory script failed closed because the optional Xcode
  Archives directory is absent under `pipefail`; it ran no Xcode command and
  created no product or source change. The corrected scanner skips absent
  optional roots.
- Fresh origin fetch confirms branch/local/origin/handoff identity at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and the
  diff check passes.
- Resource and isolation gates pass: 12,915.25 MiB swap under the strict
  16,384-MiB ceiling, 73% free memory, zero throttled pages, 667.68 GiB disk,
  zero competing process, zero current app/archive products, and zero conflict
  at every new DerivedData/archive/result/log/graph/scan path.
- Exactly one serial unsigned local-evidence Release archive is authorized.
  No launch or later evidence leg is authorized until its exact identity and
  every artifact gate are inspected.

### Current-source Release archive and artifact-gate checkpoint

- The one authorized serial wrapper/archive invocation exited zero and produced
  exactly one current Release archive at
  `build/archives/Epistemos-FreeV1-current-2026-07-14.xcarchive` plus its fresh
  retained result/log. Direct build-result inspection is `succeeded`, zero
  errors, thirteen explicit warnings; warning-free and release-ready claims
  remain prohibited.
- The exact Release graph archive was universal, SHA-256
  `b3daf69e1d1f220278a2e99921e488465178ca9bdcdedbed2ce5814a3160c58e`,
  with zero universal/arm64/x86_64 SQLite exports and zero SQLite symbol-name
  strings. Disposable DerivedData and the staged graph archive were removed
  after identity capture; the sole remaining app is inside the sole archive.
- The archive app is bundle `com.epistemos.appstore`, version 1.0.0 build 1,
  universal `x86_64 arm64`, locally ad-hoc signed with the App Store
  entitlements, and strict-deep-valid. Current executable SHA-256 is
  `16773d596813727bcf8894b6719c2ec329fb5ac29d7a1f124d670fffb28575c8`;
  app-tree SHA-256 is
  `f5335879f45df66bc5a290d48f41296a46ba33eb3924bf8fd41559ee0fc1d9cb`;
  CDHash is `1e5bf8ec807e1cea25414214c663a554ac5b009b`.
- The integrated release gate and separately retained scanner pass. App
  Sandbox is effective; the main privacy manifest matches source byte-for-byte;
  the second expected manifest is GRDB's nested manifest; App Store/MAS/free-V1
  compile conditions are present for both architectures; paid assets/linkage,
  test frameworks, quarantine, and every scanner forbidden finding are absent.
- A combined audit stopped because its shell assertion counted expected
  nonempty scanner inventories as findings and assumed only one privacy
  manifest. Separate exact checks prove this was an audit-script defect, not a
  red artifact. No source or archive byte changed during diagnosis.
- An independent read-only audit reproduced the artifact checks and found no
  real red. It confirmed the expected GRDB manifest, scanner inventory/finding
  distinction, and scanner's intentional terminal `[scan] complete` marker.
- Retained log SHA-256 values: archive
  `3f0fb10cd849641c2c4384690bad149bc6e19c7af2e8e97d5a7758e746841641`;
  sign/verify
  `1ea1149771257f2a754fafe78a2726fbe7e25f8eb09a94b8583d6a21dc8b7972`;
  gate
  `3bd36a2b2fef3fe75d73209de48720fad36b2e3ca87453008fb65cff08e5d757`;
  scanner
  `4e6138b971da4794814c5ea6ac05e7219e62d1480dacb18eeb50fa0a5d324f28`.
- Branch/local/origin/handoff remains exact at `668b52cf...`; dirty count is
  117 and the diff check passes. Resources are 13,402.38 MiB swap under the
  strict 16,384-MiB ceiling, 74% free memory, zero throttled pages, 665 GiB
  disk, and zero competing process.
- Exact next action: a new complete 16-GiB runtime preflight against the
  immutable archive, then only the finite owner-visible Free V1 runtime matrix
  with correlated logs and a disposable vault. Owner/private/removable data,
  account/payment, model/provider/secret, paid surfaces, canon/feature work,
  and another execution key remain out of bounds. KEELSTONE is `INCOMPLETE`.

### Finite runtime preflight passed

- Fresh origin and identity checks pass at `668b52cf...`; dirty count is 117;
  staged/unstaged diff checks pass. Swap is 13,378.38 MiB under the strict
  16,384-MiB ceiling, free memory is 75%, throttled pages and competing
  processes are zero, and disk is 665.37 GiB.
- Sole archive/nested-app inventory, strict signature, app-tree/executable
  hashes, universal architecture, and CDHash exactly match the artifact-gate
  checkpoint. All isolated runtime/evidence paths are fresh.
- The finite runtime matrix is authorized only with
  `EPISTEMOS_APPLICATION_SUPPORT_ROOT` pointed at disposable storage and
  `EPISTEMOS_SKIP_VAULT_RESTORE=1`. Owner data and every paid/account/model/
  provider/secret/later-key lane remain prohibited.

### Owner checkpoint — 16-GiB lock and runtime-isolation blocker

**Verbatim owner wording**

> "make it lock at 16gb at this point man"

**Interpreted intent**

- Keep the resource gate fixed at swap used strictly below 16,384 MiB; do not
  ask again or silently revert to 4/8/10/12 GiB.
- Continue the existing KEELSTONE evidence chain without owner-vault,
  production-preference, saved-state, app-group, private/removable, paid,
  model/provider, secret, or account/payment access.
- Fix only a concrete failed evidence leg before continuing.

**New exact evidence and contradiction**

- The complete runtime preflight passed, but the planned two-variable launch
  is not sufficient for the full matrix. Skip-restore creates a random defaults
  suite per process, so disposable bookmark restore cannot survive relaunch.
  It also authorizes production-bundle saved-state deletion, and the existing
  Application Support override does not own the fixed App Group root.
- Both production saved-state candidate paths are currently absent and the app
  was not launched. No user data was touched.

**Constraints / non-goals**

- Test first; surgical shared isolation policy only. Do not reopen general
  source hardening or feature scope.
- Require a stable audit-only defaults suite, disposable App Group and
  Application Support roots, and restorable-state suppression without
  production deletion. Keep normal product behavior unchanged when the full
  audit environment is absent.
- The current archive becomes stale after the source correction and must be
  deleted before exactly one replacement build. Retained logs/results stay.

**Acceptance checks / next action**

- Red tests must demonstrate same-suite cross-instance persistence, invalid-
  environment rejection, isolated App Group routing, and suppress-without-
  purge semantics.
- Implement the smallest passing seam, re-read/diff-audit, run only the narrow
  regression under a fresh 16-GiB preflight, clean the disposable build, then
  delete the stale archive before one replacement Release archive/gate chain.

### Runtime-audit isolation expected-red checkpoint

- The sole July 14 archive was reverified and deleted before the focused test,
  as required by the one-current-build rule. No Release archive or app remains.
- The focused two-test expected-red build stopped at compile time with exactly
  the intentionally absent audit-isolation API: validated audit defaults and
  App Group environment keys, full-isolation validation, suppress-without-
  purge policy, stable defaults construction, and App Group environment
  injection. It reported no unrelated source error and executed zero tests.
- Retained evidence is
  `build/xcode-results/2026-07-14-runtime-audit-isolation-red-16gib.xcresult`
  plus its log, SHA-256
  `13ca980883717b962a50f3efcd2b75ba6cd2a0c1665671461d2694a568fcb785`.
- The disposable failed-build app was arm64 with executable SHA-256
  `48a77aba5a89da185c7da5d8f9eb16f6ce84a7a0fc3b00dbab426d284d66b539`;
  the staged universal graph archive SHA-256 was
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
  Both disposable products are cleanup-only and are not runtime evidence.
- Post-run resources remain inside the owner lock: 13,346.38 MiB swap used,
  69% free memory, zero throttled pages, and 663 GiB available disk.
- Exact next action: delete only the identified disposable build products,
  implement the bounded shared isolation seam, then re-read and diff-audit the
  change before a new full 16-GiB preflight authorizes the same two tests.

### Runtime-isolation source review expansion — owner preferences remain protected

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**New source evidence**

- The first seam review found that an empty audit bookmark domain still fell
  through to the historical `Brainiac.epistemos` and `com.lucid.app` suites,
  including removal of a migrated bookmark. Audit mode must never open or
  mutate those production domains.
- App bootstrap also constructs UI, inference, workspace, power, graph, and
  settings state that directly uses `UserDefaults.standard`; SwiftUI
  `@AppStorage` defaults to that same production domain. Isolating only the
  vault service would therefore be an incomplete owner-preference boundary.

**Revised bounded intent and acceptance**

- Keep the same three-variable full-audit contract and normal behavior when it
  is absent, but centralize all product preference access through one runtime
  defaults resolver. In a valid audit environment it returns only the stable
  audit suite; otherwise it returns the existing standard defaults.
- Route direct product `UserDefaults.standard` access and every product
  `@AppStorage` declaration through that resolver. This is a mechanical
  isolation correction, not a preference redesign.
- Full audit mode must skip legacy bookmark-suite migration, must suppress
  restorable state, and must remain purge-false even if a stale skip-restore
  variable is also present.
- Before a green build, source search must show no direct product
  `UserDefaults.standard` access outside the single resolver and no unscoped
  product `@AppStorage`. The focused tests must prove production-domain
  separation, stable cross-instance persistence, legacy-suite denial, isolated
  App Group routing, provider non-invocation, and suppress-without-purge.

### Runtime-isolation adversarial review checkpoint

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**New contradiction and interpreted intent**

- A read-only adversarial review found that spelling protected Library paths
  with different case, reaching them through a symlink, or nesting one audit
  root inside the other could evade the first validation pass. It also found a
  theoretical validate-then-retry fallback to production Application Support,
  a setup-assistant action that could create `~/Documents/Epistemos`, and a
  recovery-snapshot helper that still named the production preference plist.
- The owner intent remains an actually disposable runtime proof, not merely an
  environment-variable label. Every invalid full-audit request must fail
  closed before app bootstrap, and normal launches must remain unchanged.

**Acceptance checks / exact next action**

- Add focused expected-red assertions for symlink and case-variant protected
  paths, nested roots, every incomplete combination involving the two new
  audit keys, legacy App Group non-copy, and the disposable default-vault path.
- Canonicalize audit roots, reject overlap, return the already-validated audit
  Application Support root without a production fallback, suppress production
  preference-plist snapshotting in audit mode, and route the setup assistant's
  default vault into disposable audit storage.
- Re-read and diff-audit before any command. No build/test/archive is permitted
  until a fresh preflight proves swap strictly below 16,384 MiB, free memory at
  least 25%, zero throttled pages, no competing process, and no stale product.

### Automatic-launch external-path checkpoint

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**New source evidence and bounded intent**

- The final automatic-launch trace found two additional concrete writes/reads
  outside the three audit roots: synchronous probing of Claude.app reference
  fonts and a Release-only Metal warmup lock in the global temporary directory.
- App Store and full-audit launches must never probe third-party application
  fonts. All bundled owner fonts—including Matrix, Matrix Bold, Matrix Dots,
  Chonky, and the rest of the bundled display library—must remain registered.
- A full-audit launch must suppress the optional Release Metal prewarm rather
  than create its global lock. Normal non-audit Release behavior remains
  unchanged; graph/Metal behavior is still runtime verification debt.

**Acceptance checks / next action**

- The same focused isolation test must prove external reference fonts are off
  in the App Store target, bundled font registrations remain present, audit
  Release warmup is off, and normal Release warmup remains on.
- Re-run the complete semantic path sweep and diff check, then perform the
  locked 16-GiB preflight before the exact two-test green proof. No launch or
  archive is authorized by source inspection alone.

### Runtime-defaults compiler-red checkpoint

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**Observed evidence and interpreted intent**

- The first attempted green isolation build passed the locked resource gate
  but stopped before test execution because Swift 6 rejected the stable shared
  `FoundationSafety.runtimeUserDefaults` property: `UserDefaults` is mutable
  and does not conform to `Sendable`. The compiler explicitly offered
  `nonisolated(unsafe)` when access is protected by an external synchronization
  contract.
- This is a compiler-boundary failure in the new isolation seam, not evidence
  about runtime behavior. The retained result reports zero executed tests and
  result `unknown`; it must not be described as green.
- The owner intent remains one stable defaults handle for the process so every
  product preference and `@AppStorage` access uses the same audit suite during
  a disposable launch. Converting the property into a computed factory would
  weaken that identity contract; moving all callers to the main actor would
  expand the correction far beyond the failed evidence leg.

**Hard constraints / acceptance / next action**

- Retain the compiler-red result and log. Log SHA-256 is
  `096df8720308b1e9e341c15ceace75bdb7e47083cb4014c1210fc5ee9e23d96c`;
  the result contains zero tests, zero passed, zero failed, and result
  `unknown`.
- Delete only the failed build's disposable DerivedData and staged graph
  archive after their identities have been recorded. Do not delete either
  retained result bundle or log and do not touch owner data.
- Apply only the compiler-requested `nonisolated(unsafe)` annotation to the
  stable `static let`; do not add a wrapper, change the defaults domain, or
  broaden the implementation.
- Re-read the changed region, inspect the diff, and repeat the complete locked
  preflight. The same two focused tests may rerun only with swap strictly below
  16,384 MiB, free memory at least 25%, zero throttled pages, no competing
  Xcode/compiler/model/Epistemos process, and no stale app/archive/graph
  product. Archive, launch, canon, paid, and later-key work remain closed.

### Runtime-defaults minimal correction and retry authorization

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**Implemented boundary and independent review**

- `FoundationSafety.runtimeUserDefaults` now has only the compiler-requested
  `nonisolated(unsafe)` annotation and remains one stable process-wide
  `static let`. The suite resolver, domains, callers, and product behavior are
  unchanged.
- Independent read-only review confirmed this is narrower than a global
  unchecked conformance, wrapper, computed factory, or main-actor migration.
  Existing nonisolated consumers and the full target compile remain the
  relevant enforcement surface; no behavior-test rewrite is warranted.
- Source re-read, semantic defaults/Application Support sweeps, staged and
  unstaged diff checks, and stale-product cleanup are clean for this correction.

**Fresh authorizing preflight**

- Branch `feat/goose-surface`, local HEAD, fetched remote, handoff publication,
  and supplied publication SHA are exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; the pull is already up to date
  and dirty count is 179.
- Swap used is 13,234.38 MiB, strictly below 16,384 MiB; free memory is 71%;
  pages throttled are zero; available disk is 696,667,760 KiB; no competing
  process exists; and app, archive, and staged graph counts are all zero.
- One earlier collection reached the same green observations but its final
  shell assertion failed after a reserved shell variable temporarily replaced
  the command path. It authorized no command. The complete corrected rerun
  above exited successfully and is the sole authorization for the retry.
- Exact next action: run the same two focused selectors once, serially, using
  fresh DerivedData, result, and log paths. Stop and retain evidence on any
  failure; do not open the archive or runtime legs unless the result is
  inspected green and the disposable products are identified and cleaned.

### Runtime-isolation Green2 red checkpoint — path markers and test-host contact

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**Exact result**

- The serial Green2 retry compiled the full target, clearing the prior
  `UserDefaults` concurrency error. It executed exactly two selected tests:
  one passed and one failed with two expectations.
- Both failures compare the same canonical filesystem path with different
  `URL.hasDirectoryPath` representation: the actual App Group and default
  audit-vault URLs retain a trailing directory marker while the expected URLs
  lose it after symlink resolution. This is a test-oracle mismatch, not proof
  that either URL escaped its disposable root.
- The retained result is red and the archive gate remains closed. The log
  SHA-256 is
  `0d097d773956d4eb1007f54d9fa671f9f86c4482697332e4c28728c016e5fa28`.

**New safety contradiction**

- Before the selectors ran, the XCTest host initialized `AppBootstrap` without
  the full audit tuple. Application Support correctly used the existing
  per-process temporary test root, but `AppGroupContainer.shared` resolved the
  production `group.com.epistemos.shared` container and called `ensureLayout`
  plus migration checks there.
- The production App Group's top-level modification time predates the test and
  no owner file contents were read, but that cannot prove no nested metadata or
  file access occurred. A recursive metadata-only probe stalled and was
  stopped; every probe process is terminated. Do not inspect that owner
  container again for this diagnosis.

**Hard constraints / acceptance / next action**

- Retain the Green2 result and log; record the disposable app and staged graph
  identities; delete only those products before any retry.
- Correct only the two test expectations to compare canonical filesystem
  paths, preserving the production URL-return behavior and directory marker.
- The next test host must be isolated before `AppBootstrap` begins: its global
  process environment must contain a fresh valid Application Support root,
  App Group root, and audit defaults suite, or an equally narrow source-level
  XCTest fallback must prove the production provider is never invoked. Normal
  launches and the explicit audit tuple must remain unchanged.
- Add/retain an assertion that the safe boundary cannot silently regress, then
  re-read and diff-audit. Run no command until cleanup and a new complete
  strict-below-16,384-MiB preflight pass. The next log must name only the
  disposable App Group root before the selectors. Archive, runtime, canon,
  paid, private/removable, and later-key work remain closed.

### Runtime-isolation Green3 retry authorization

- Green2 disposable DerivedData/app, staged graph archive, per-process test
  runtime, and temporary saved state are deleted; its red result and log remain.
- The two red URL assertions now compare canonical `.path` values only. Source
  behavior, directory markers, validators, and runtime destinations are
  unchanged; re-read and both diff checks pass.
- The next XCTest host will start with the fresh global audit tuple rooted at
  `/private/tmp/Epistemos-RuntimeAuditIsolationGreen3-16GiB-Runtime` and suite
  `com.epistemos.audit.runtime.keelstone.green3.20260714`. The audit suite and
  root were cleared before preflight. Its log must show the disposable App
  Group root before any selector; a production App Group line is an immediate
  stop regardless of test result.
- Fresh branch/local/origin/handoff/supplied SHA identity is exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; pull is already up to date;
  dirty count is 179. Swap is 13,226.38 MiB used, free memory 67%, throttled
  pages zero, disk 696,326,296 KiB, competing processes zero, and stale
  app/archive/staged-graph counts zero.
- Exactly the same two selectors are authorized once under fresh Green3
  DerivedData/result/log paths. No other test, build, archive, app launch,
  owner-data access, or later execution key is authorized.

**Authorization invalidated before execution by source-level safety review**

- No Green3 command used the preflight above. Independent review showed that a
  process-only tuple would protect this one command but leave any future XCTest
  caller of `AppGroupContainer.shared` able to resolve the production provider.
- Test-first coverage now injects an XCTest environment and a counting provider
  and requires the provider never to run, the production path never to exist,
  and layout to remain under an injected disposable fallback.
- `AppGroupContainer.containerURL` now gives an explicit valid audit root first,
  returns `nil` for XCTest so `rootURL` uses its already disposable test fallback,
  and calls the production provider only for normal non-test launches. No normal
  or explicit-audit behavior changed.
- Because those test/source edits occurred after the recorded preflight, that
  preflight is non-authorizing. Re-read, diff audit, semantic path sweep, and a
  complete new 16-GiB preflight are required before Green3 may run.

**Replacement Green3 preflight passed**

- Re-read and semantic sweeps confirm explicit audit precedence, XCTest
  provider denial, and normal-only provider invocation; both diff checks pass.
- Identity remains exact at `668b52cfb43721de95db102260d9f327ae24e13e`,
  dirty count 179, and pull already up to date. Swap is 13,226.38 MiB used,
  free memory 68%, throttled pages zero, disk 696,325,116 KiB, competing
  processes zero, and stale app/archive/staged-graph counts zero. All Green3
  output, runtime-root, and audit-suite state is fresh.
- This replacement preflight authorizes exactly one Green3 run of the same two
  selectors under the three-part process audit tuple. The injected XCTest
  container inside the selected test separately proves generic provider denial.

### Green3 passed, but XCTest defaults isolation remains open

- Green3 compiled and passed both selected tests, including canonical audit
  paths, explicit audit provider denial, and injected generic XCTest provider
  denial. Its startup log contains zero production App Group paths and one
  PID-scoped disposable fallback path.
- Xcode did not propagate the shell-supplied three-part audit tuple into the
  hosted app: the requested audit root has zero log hits and explicit audit
  precedence would otherwise have selected it. Therefore the host's central
  defaults resolver still selected `UserDefaults.standard` in `.notRequested`
  test mode. A green result cannot silently stand in for owner-preference
  isolation.
- Retain Green3 as exact App Group/path evidence, but keep the archive gate
  closed. Add a PID-scoped XCTest defaults suite, clean it on creation and app
  termination, prove it is not standard and persists across same-suite handles,
  then rerun the same two selectors after product cleanup and a fresh preflight.
- Normal non-test defaults and explicit valid audit-suite behavior must remain
  unchanged. No owner standard-domain probe or content inspection is permitted.

### PID-scoped XCTest defaults correction; Green4 proof pending

- Green3 disposable app/DerivedData, staged graph archive, PID runtime, temporary
  saved state, requested audit root, and audit suite are cleaned; its result and
  log remain.
- In `.notRequested` mode only, `resolvedRuntimeUserDefaults` now detects XCTest
  and returns `com.epistemos.test.runtime.<pid>` instead of standard defaults.
  The stable global handle clears that PID domain once at creation; explicit
  valid audit mode still takes precedence, invalid audit mode still fails
  closed, and normal non-test mode still returns `UserDefaults.standard`.
- XCTest teardown removes the PID domain before returning from the existing
  test-only termination branch. The selected regression uses an injected PID
  to prove nonstandard identity, startup reset, same-suite cross-handle
  persistence, and explicit cleanup without reading any owner domain.
- Re-read and semantic sweeps show one intentional standard-defaults fallback,
  no unscoped `@AppStorage`, no stale product, and clean staged/unstaged diffs.
  A fresh complete 16-GiB preflight must pass before the same two selectors may
  run as Green4. The post-run audit must verify the actual PID suite is absent.

**Green4 preflight passed**

- Identity is exact at `668b52cfb43721de95db102260d9f327ae24e13e`, pull
  already up to date, dirty count 179, and both diff checks clean. Swap is
  13,537.38 MiB used, free memory 68%, throttled pages zero, disk
  695,985,676 KiB, competing processes zero, and stale app/archive/staged-graph
  and test-defaults plist counts zero.
- Only the same two selectors under fresh Green4 paths are authorized. The
  process-level audit tuple is intentionally absent so actual test-host startup
  must prove both generic XCTest fallbacks, followed by actual-PID suite cleanup.

### Green4 test-green result with red actual-host cleanup

- The retained Green4 result is authoritative 2/2 passed, zero failures or
  skips. Its log has zero production App Group hits and routes actual host PID
  `66878` beneath disposable `Epistemos-TestRuntime/66878` storage.
- Green4 is not log-clean: three formal build warnings, twelve duplicate-column
  runtime diagnostics, and one metadata diagnostic remain explicit debt.
- The actual PID defaults domain is still readable after the runner exits. Its
  898-byte, 18-key plist has SHA-256
  `82ba1b186f1e9a316bf1a4d1e1c95855effa0a03a067f2b162258743fce3b9fd`;
  the PID runtime directory also remains. This falsifies the assumption that
  `applicationWillTerminate` is a reliable XCTest cleanup hook. No production
  defaults or owner container was read.
- Retain Green4 result/log and record product identities, then delete only its
  disposable DerivedData/app, staged graph archive, PID runtime, and PID
  defaults suite. Move cleanup ownership to a narrow Swift Testing suite scope
  so it executes after selected tests even when the app delegate is bypassed.
- Re-read and diff-audit the surgical change. Before Green5, require branch/
  remote/handoff identity, swap strictly below 16,384 MiB, at least 25% free
  memory, zero throttled pages, zero competing process, and zero stale product
  or test-domain state. Green5 may rerun only the same two selectors. The
  archive/runtime/canon/feature/paid/private/model/secret/later-key lanes remain
  closed until actual-host cleanup is proven.

**Cleanup correction landed; Green5 not yet authorized**

- Green4 disposable app/DerivedData, graph archive, PID runtime, and test-only
  defaults state are removed; its retained result/log and recorded identities
  remain. The exact domain is unreadable and its empty plist is absent.
- A private recursive Swift Testing scope trait now clears the PID defaults
  suite after each test controlled by the existing serialized KEELSTONE suite.
  This changes only test-harness lifecycle ownership; production defaults,
  audit precedence, normal launch behavior, and the app-delegate fallback are
  unchanged.
- The changed region was re-read and its diff inspected; `git diff --check`
  passes. No test/build/archive has run after the correction.
- Exact next action is a complete fresh Green5 16-GiB preflight. If and only if
  it passes, rerun the same two selectors once and inspect both the xcresult and
  actual-host PID cleanup before reopening the Release archive gate.

**Green5 preliminary inventory found and removed stale XCTest residue**

- The first inventory found zero app/archive products but 73 disposable
  `Epistemos-TestRuntime/<pid>` directories and one empty, logically unreadable
  synthetic test plist. No build/test was authorized by that inventory.
- An exact-name process scan was empty, so only the test runtime namespace and
  test-prefix plist were removed. Both counts now equal zero.
- Because `removePersistentDomain` can leave a 42-byte empty plist, the
  test-only cleanup helper now synchronizes the cleared domain and removes only
  its exact validated PID-scoped test plist. The selected test forces its
  injected suite to disk, then requires value and plist removal; the recursive
  suite scope performs the real-host cleanup.
- Re-read and diff checks are required again. The complete Green5 identity,
  stale-product, selector, resource, and process preflight must restart from the
  beginning; the preliminary inventory authorizes nothing.

**Complete Green5 preflight passed**

- Fresh fetch/pull and identity checks are exact at `668b52cf...`; dirty count
  is 179 and staged/unstaged diff checks pass.
- Swap is 13,885.25 MiB under the strict 16,384-MiB ceiling, free memory is
  73%, pages throttled are zero, disk is 695,677,960 KiB, and competing process
  count is zero.
- App/archive/graph products, test plists, PID runtime directories, saved state,
  and every Green5 output path are absent; each selector resolves exactly once.
- Exactly one serial Green5 run of the same two selectors is now authorized.
  No other test/build, archive, launch, runtime, canon, feature, private/paid,
  model/secret, or later-key action is authorized by this preflight.

### Green5 runner crash — missing recursive `TestTrait` conformance

- Green5 compiled but ran zero selected test bodies. Its result is red with one
  system failure: the hosted app crashed while Swift Testing prepared the plan.
- The 42,399-byte crash report (SHA-256
  `399924480c0ddb2ecf232991e69230645c380eb132971f013e02abfbb1caadab`)
  records `EXC_BREAKPOINT`/`SIGTRAP` in
  `Runner.Plan._recursivelyApplyTraits`; the faulting registers name
  `RuntimeDefaultsCleanupTrait` and the `TestTrait` protocol descriptor.
- The custom recursive scope omitted `TestTrait`, while the current local
  Testing framework's recursive scoped traits conform to both `TestTrait` and
  `SuiteTrait`. The tests never entered cleanup or either body, so defaults-
  plist deletion is not implicated by this crash.
- PID `72121` test defaults/runtime and the disposable build remain exactly
  identified. Retain result/log/crash identity, then clean only those disposable
  products and the temporary diagnostic export. Add only the missing
  `TestTrait` conformance, re-read/diff-audit, and rerun no command until a fresh
  Green6 16-GiB preflight passes.

**Green5 cleanup and one-conformance correction complete**

- Green5 result/log/crash evidence remains; its disposable build, graph, PID
  runtime/defaults, saved state, and diagnostic export are absent.
- The private recursive cleanup trait now adds only the missing `TestTrait`
  conformance, matching Xcode's built-in recursive scoped traits. Product code,
  defaults routing, cleanup body, and selected test bodies are unchanged.
- Re-read and diff checks pass. No build/test/archive ran after the correction.
  A complete fresh Green6 preflight is the only next action.

**Green6 preflight passed**

- Identity is exact at `668b52cf...`, dirty count 179, and diff checks pass.
- Swap is 14,249.19 MiB under the 16,384-MiB lock; free memory is 72%; pages
  throttled and competing processes are zero; disk is 693,823,400 KiB.
- App/archive/graph, test-plist/PID-runtime, saved-state, and fresh Green6 path
  inventories are zero; both selectors resolve once.
- One serial Green6 rerun of only the two isolation selectors is authorized.

## Checkpoint 2026-07-14 Green6 Result And 16-GiB Lock

### Verbatim owner steer excerpt

> make it lock at 16gb at this point man

### Interpreted intent

Continue the exact KEELSTONE evidence chain without restarting it, using a
strict 16-GiB swap ceiling. A superficially green Xcode result is not enough:
the real hosted process must also leave its PID-scoped defaults and temporary
runtime state disposable before the Release archive gate reopens.

### Hard constraints

- Swap used must be strictly below 16,384 MiB before every Epistemos test,
  build, archive, or runtime leg; free memory must be at least 25%; pages
  throttled must be zero; and no competing Xcode/compiler/model/Epistemos
  process may be active.
- Keep exactly one current Epistemos app/archive product for an active evidence
  leg, record its identity, and delete its disposable product before another
  build.
- Preserve the branch, owner dirty work, MAS-only boundary, Free V1 paid/AI
  hiding, and Kokoro-only eventual voice matrix.
- Do not touch owner/private/removable/account/payment/funding/provider/model or
  secret data, and do not start canon/features or a later execution key.

### Non-goals

- Do not treat the focused isolation test as release readiness.
- Do not start the Release archive, app launch, runtime matrix, feature work,
  or MAS canon while post-process cleanup is unresolved.
- Do not inspect or mutate any production defaults domain or owner App Group.

### Green6 proven state

- The authoritative result is `Passed`: two selected tests passed, with zero
  failures, skips, or expected failures.
- The 1,274,428-byte log has SHA-256
  `35b57730eedaeddd8f401a0ba28032d8c99ef4cafde1f3e69d30182582b4beeb`.
- Startup stayed beneath `Epistemos-TestRuntime/76429`; literal searches of
  the log and result bundle found zero production App Group identifiers.
- The log records June disabled, local GGUF disabled, cloud models off, and
  vault-bookmark restore skipped.
- Three formal warnings and the existing twelve duplicate-column plus one
  metadata `dev_t` diagnostics remain verification debt.

### Contradiction and acceptance failure

The selected test bodies are green, and the actual PID defaults domain is no
longer readable or populated. However, four seconds after the selected suite
completed, Foundation left a valid 42-byte, zero-key plist at
`~/Library/Preferences/com.epistemos.test.runtime.76429.plist`. Its SHA-256 is
`9261ecceda608ef174256e5fdc774c1e6e3dcf533409c1bc393d490d01c713f1`.
This is test-only residue, not owner data, but it fails the exact physical-
disposal bar. Green6 therefore closes the routing assertions but does not yet
close actual-host cleanup or authorize an archive.

### Next smallest safe action

Retain and document the Green6 result/log and disposable product identities;
then delete only its derived app, staged graph archive, PID runtime, and exact
test-only plist. Replace the early test-scope-only physical cleanup assumption
with the smallest process-exit cleanup seam, add a focused source/behavior
assertion, re-read and diff-audit, and run no Epistemos command until a wholly
fresh Green7 16-GiB preflight passes. Green7 may rerun only the same two
selectors, and the archive gate remains closed until an independent post-exit
check finds both the logical domain and physical plist absent.

**Green6 cleanup and process-exit correction complete; Green7 not authorized**

- Green6's retained result and log remain. Its disposable DerivedData/app,
  staged graph archive, actual PID runtime, exact test-only plist/domain, and
  temporary saved state are absent.
- The generic XCTest branch now registers one normal-process-exit callback
  before creating its first PID-scoped persistent suite. That final callback
  reuses the existing exact-PID cleanup helper after application and test-scope
  teardown have finished. Explicit runtime-audit suites do not register it, so
  the later two-process restore matrix can retain its deliberate suite state.
- The selected source guard requires both the `Darwin.atexit` callback and its
  registration at the XCTest resolver seam. Production defaults, normal app
  launches, valid/invalid explicit-audit precedence, and owner domains are
  unchanged.
- Apple documents `UserDefaults` suites as persistent stores and `atexit` as a
  normal-exit callback. This correction addresses normal hosted-test exit; it
  does not claim cleanup after SIGKILL or crash.
- The changed regions were re-read and `git diff --check` is clean. No
  Epistemos build, test, archive, or launch has run after the correction.
  Independent review and a wholly fresh Green7 16-GiB preflight remain the
  only next actions.

**First Green7 preflight stopped on synthetic PID residue**

- Identity, diff, selector, process, app/archive/graph, saved-state, disk,
  free-memory, and throttling checks passed. Swap was 15,360.00 MiB, still
  strictly below the 16,384-MiB lock; free memory was 75% and throttled pages
  were zero.
- The stale-state inventory found one 42-byte, zero-key test-only plist:
  `com.epistemos.test.runtime.20260714.plist`, timestamped with Green6 and
  carrying the same empty-plist SHA-256 already recorded. No test/build began.
- This is the fixed synthetic PID used inside the selected regression, not the
  actual Green6 host PID. Cleaning only the actual host therefore could not
  remove it at final process exit.
- Exact next action is to record and remove this known test-only residue, make
  the regression exercise the actual current PID suite instead of manufacturing
  a second persistent suite, and extend the source guard for actual-host-only
  exit registration. Then re-read/diff-audit and restart the entire Green7
  preflight; nothing from this failed preflight authorizes a command.

**Replacement Green7 preflight passed; compile-only evidence is red**

- After exact synthetic-suite cleanup and the actual-PID test correction, the
  complete replacement preflight passed: identities exact, dirty count 179,
  swap 15,360.00 MiB, free memory 75%, throttled pages zero, no competing
  process, and every stale/fresh product and test-state inventory zero.
- The one authorized Green7 command stopped in Swift module emission. Xcode's
  project-wide `MainActor` default inferred the top-level exit callback as
  `@MainActor`, so Darwin rejected conversion to `@convention(c) () -> Void`.
  Result status is failed with three build errors and zero tests; no test host,
  app runtime, vault, preference value, provider, model, or secret path began.
- The callback is a direct top-level function, and this codebase already uses
  `private nonisolated func` to escape the default actor on equivalent global
  helpers. The smallest correction is therefore the explicit `nonisolated`
  modifier only; no cleanup routing or lifecycle contract needs reopening.
- Exact next action: retain Green7 result/log and partial product identities,
  delete its disposable DerivedData/partial app and staged graph, add only the
  missing callback isolation modifier, re-read/diff-audit, then require a new
  complete Green8 16-GiB preflight before rerunning the same two selectors.
  Archive/runtime/canon/feature/private/paid/model/secret/later-key work remains
  closed.

**Green7 cleanup and callback isolation correction complete**

- Green7 result/log remain retained; its partial DerivedData/app, staged graph,
  test state, and saved state are absent.
- The only implementation change after the compiler evidence is
  `private nonisolated func` on the no-capture exit callback. The registration,
  actual-XCTest guards, retained defaults handle, exact PID cleanup, explicit-
  audit persistence, and production route are unchanged.
- The selected source guard now requires the nonisolated declaration. Changed
  regions were re-read, local nonisolated global-function precedent was
  confirmed, and `git diff --check` passes. No build/test/archive/launch has
  run after this correction. A complete fresh Green8 preflight is the sole
  next action.

**Green8 compiled; one artificial filesystem assertion is red**

- Green8's complete 16-GiB preflight passed, the callback compiled, and the
  hosted app launched only under PID-scoped test roots. The isolation-rejection
  test passed; the same-suite test failed only because it demanded that
  `UserDefaults.synchronize()` immediately materialize the PID plist before
  cleanup.
- The value contract itself worked: the first real-PID handle set the sentinel
  and the second handle observed it. Foundation is allowed to keep this state
  in its preferences service without creating the physical file at that exact
  instant, so pre-materialization is not a valid product requirement.
- After host exit and a 40-second settle window, the logical domain was
  unreadable, the PID runtime was absent, and ByHost count was zero. The system
  later wrote one 42-byte, zero-key main plist. This contains no owner data but
  confirms that in-process or `atexit` code cannot promise physical file absence
  after the external preferences daemon's final flush.
- The safety bar is therefore split honestly: product/test code must leave the
  PID domain empty/unreadable and never touch production identifiers; the
  controlling evidence leg must then delete and verify absence of the exact
  empty test-only shell before any later build. No wildcard or owner-domain
  cleanup is authorized.
- Exact next action: retain Green8 evidence, delete its disposable app/graph,
  PID runtime, and exact empty PID shell; remove only the invalid requirement
  that the plist must exist before cleanup; preserve same-suite value proof,
  cleanup, final in-process absence, source guards, and all isolation routes;
  then require a fresh Green9 16-GiB preflight before the same two selectors.

**Green8 cleanup and assertion correction complete**

- Green8 result/log remain retained. Its disposable app/DerivedData, staged
  graph, PID runtime, exact main/ByHost test plists, logical test domain, and
  saved state are absent.
- Only the invalid positive `fileExists` assertion was removed. The real-PID
  suite name, startup reset, nonstandard identity, same-suite value replay,
  explicit cleanup, value absence, final in-process plist absence, source
  guards, and external settle/cleanup bar remain.
- The changed region was re-read and `git diff --check` passes. No command has
  run after the correction. A complete fresh Green9 preflight is required.

**Green9 closes the focused runtime-isolation test leg**

- The complete Green9 preflight passed at the exact publication identity with
  dirty count 179, swap 15,360.00 MiB, free memory 71%, zero throttling, zero
  competing processes, and zero stale/fresh product or test state.
- The authoritative result is `Passed`: two selected tests passed, with zero
  failures, skips, expected failures, or build errors. The log and entire
  result bundle contain zero production App Group identifiers.
- Hosted PID `89953` used only its temporary Application Support root; June,
  local GGUF, and cloud models stayed disabled/off and vault restore was
  skipped. After the settle window, its defaults domain was unreadable,
  contained zero keys, left no ByHost state, and its PID runtime was absent.
- The preferences daemon again materialized the known 42-byte, zero-key main
  shell four seconds after test completion. This is now an external artifact-
  hygiene item, not a product-domain failure. It must be removed exactly along
  with Green9's disposable app/graph before an archive preflight.
- Three formal warnings plus twelve duplicate-column and one `dev_t` runtime
  diagnostics remain explicit verification debt; they are not hidden by the
  focused pass.
- Exact next action: retain Green9 result/log and identities; remove only the
  disposable Green9 app/DerivedData, graph archive, exact PID shell/domain,
  PID runtime, and saved state; verify all absent; then inspect the recorded
  Release archive command and artifact gates and run a wholly fresh 16-GiB
  archive preflight. No archive is authorized until that new preflight passes.

### Replacement archive checkpoint — artifact gates green

**Controlling owner wording**

> "make it lock at 16gb at this point man"

**Interpreted intent and constraints**

- Keep swap used strictly below 16,384 MiB before every test, build, archive,
  or runtime leg; retain the free-memory, throttling, process, and one-current-
  build gates.
- Replace the source-stale archive once, preserve all retained evidence, keep
  June/models/providers/generative actions/Browser/ResearchHub hidden and
  inert, and authorize no launch until every artifact gate is green.
- Runtime evidence must use the new three-part audit isolation tuple and a
  disposable vault. Owner/private/removable data, production preferences/App
  Group/saved state, payment/account, paid model/provider/secret work, canon,
  features, and another execution key remain non-goals.

**Exact proven state**

- The first archive preflight found and removed only three stale isolated
  XCTest runtime directories (PIDs 76429, 87086, 89953; thirty files; 1,716
  KiB). No matching process or owner-domain contact existed. The repeated full
  preflight passed at exact local/remote/handoff SHA `668b52cf...`, dirty count
  179, 14,566.88 MiB swap, 73% free memory, zero throttling, zero competitors,
  and zero stale/fresh product conflict.
- Exactly one serial Release archive succeeded at
  `build/archives/Epistemos-FreeV1-runtime-isolation-current-2026-07-14.xcarchive`.
  Result status is succeeded with zero errors and thirteen honestly retained
  warnings. Disposable DerivedData and staged graph products were removed
  after identity capture; exactly one archive and its nested app remain.
- The local ad-hoc signature is strict-deep-valid and carries the exact six App
  Store entitlements. Bundle/version/build are `com.epistemos.appstore`, 1.0.0,
  and 1; architectures are `x86_64 arm64`; CDHash is
  `493877f23700cc0a8d5803cacf8cdda85dc3c160`. This is not distribution
  signing or submission proof.
- The integrated gate, standalone scanner, and independent direct audit pass.
  Paid assets/linkage, test artifacts, quarantine, and all scanner findings are
  absent; the exact executable inventory is the app plus the two expected
  Epistemos dylibs. Current executable SHA-256 is
  `468c76dc6fa2e0982af8bed768ce2ea17eecee50d25314003b16fbfca231bda7`;
  deterministic app-tree SHA-256 is
  `adaded48d7b114d0ea50cd734b4287b222536b0a75ac8968e141d8e942d16608`.

**Verification debt and exact next action**

- Thirteen build warnings, Apple distribution identity/validation, broad
  suites, performance/storage soak, manual Free V1 behavior, audible Kokoro,
  and repeated-zero-fail closeout remain unproven.
- Run a new complete 16-GiB runtime preflight that rechecks the immutable
  archive hashes, signature, sole-product inventory, resources/processes, and
  fresh disposable runtime/log/defaults paths. If every check passes, run only
  the recorded eight-item finite Free V1 matrix serially with the full audit
  tuple, stable defaults suite, correlated logs, and disposable vault. Stop on
  any red leg, record the final KEELSTONE verdict, and do not begin canon or a
  later execution key.

## Checkpoint 2026-07-14 Runtime Verdict And Near-Verbatim MarkEdit Lock

### Verbatim owner excerpts

> “make it lock at 16gb at this point man”

> “the v1 free versjon will have no ai at all.”

> “browser, research hub both are needing to be on paid version as well an
> hidden from v1 releawe”

> “i still was not satisfied with the source again the formattign and everythig
> about markedit is what i wanted all except for the toolbar, the color palette
> etc. even the eye i wanted the eye ui to be markedit can i do that and is
> there a reason why its not almost verbatim markedit”

### Interpreted owner intent

- The 16-GiB ceiling is durable: swap used must remain strictly below 16,384
  MiB, with at least 25% free memory, zero throttling, and no competing build,
  compiler, model, or Epistemos process before every evidence leg.
- Free V1 must contain no AI or model execution. June, providers, generative
  actions, Browser, ResearchHub, Companions, agent/chat/provenance surfaces,
  and contextual embedding execution must be hidden, inert, and not compiled
  into the Free product. Kokoro is the separately retained owner-approved
  voice capability, but it still requires honest installation/runtime proof.
- Source Markdown is not a loose MarkEdit inspiration. It must preserve
  MarkEdit's donor formatting, text size and line height, gutter, insets,
  scrolling/selection behavior, active-line treatment, editor geometry, and
  preview/“eye” experience almost verbatim. Epistemos keeps its palette and
  owner toolbar. The existing Epistemos document identity/title popover remains
  the ontology; no second title model is required.

### Current source explanation for the MarkEdit gap

- `docs/prompts/PROMPT_PLAN_2_EDITOR.md` already locks “MD = MarkEdit chrome
  VERBATIM,” donor font/line-height fidelity, and retention of donor controls
  and settings.
- The full MarkEdit source is already vendored at `LocalPackages/MarkEdit`;
  re-cloning is not the missing step.
- Current production routing hard-codes `allowsMarkEditWindowToolbar: false`.
  That selects a custom nonpersistent CoreEditor-only `WKWebView` wrapper with
  Epistemos CSS and empty MarkEdit user settings instead of MarkEdit's full
  `EditorViewController` and Previewer path.
- The false default was added for a legitimate security reason: the full
  controller currently exposes MarkEdit file, service, and clipboard bridge
  APIs. Therefore simply flipping the Boolean is not an acceptable repair.
  The correct seam is a restricted MarkEdit host that retains donor
  editor/preview presentation while denying those unrestricted native bridge
  capabilities and replacing only the toolbar and palette.

### Hard constraints and non-goals

- Finish and record the current KEELSTONE verdict before editor/canon feature
  work. Do not begin a new execution key from this checkpoint.
- Keep MAS-only architecture, App Sandbox, security-scoped vault access,
  native in-process code, and one-current-build discipline.
- Preserve the user's existing dirty work and the immutable runtime archive.
- Do not access owner/private/removable/account/payment/provider/secret data.
- Do not copy a separate product shell or enable MarkEdit's unrestricted
  native bridge. Do not change the title ontology merely to imitate a screenshot.
- Do not claim MarkEdit fidelity, Free V1 no-AI behavior, performance health,
  vault safety, calendar support, or Kokoro runtime without exact current
  artifact and runtime evidence.

### Acceptance checks

- Free build has zero visible or compiled paid/agent surfaces and zero
  NaturalLanguage/June/provider/model execution; no eager audio setup or
  microphone-permission polling occurs before an explicit owner action.
- `/tmp` and `/private/tmp` aliases cannot create nested absolute-derived vault
  paths; save/relaunch/save and graph/search routing pass with no containment,
  indexing, or file-first-save error.
- A side-by-side Source comparison matches MarkEdit donor typography,
  geometry, gutter, scrolling, selection, active line, and preview/eye
  behavior while retaining Epistemos palette and toolbar.
- Raw Markdown stays byte-semantically faithful across Epdoc, Source, Preview,
  save, close, relaunch, and second save; no host/source divergence appears.
- Narrow tests, exact archive gates, correlated logs, manual screenshots, and
  repeated zero-fail validation support every completed claim.

### Contradictions and final verdict

- Artifact scanning proved June/GGUF/cloud resources absent, but runtime
  evidence proved Apple NaturalLanguage embedding-model activity. A literal
  Free V1 no-AI claim is therefore false on this archive.
- MarkEdit donor code and a full-controller branch exist, but the live route
  uses the restricted custom CoreEditor wrapper. Current visual behavior
  therefore does not satisfy the already-canonical near-verbatim requirement.
- KEELSTONE is `INCOMPLETE`; the runtime matrix is red and the product is not
  release-ready.

### Exact next action

Stop at this recorded KEELSTONE verdict. Do not start canon or another key. If
the owner explicitly resumes this same key, first write failing Free-build
tests for visible/compiled agent surfaces, NaturalLanguage model activity,
eager audio initialization, and microphone polling; make only the bounded
repair. Then repair centralized canonical vault containment. Only after those
runtime blockers pass should the restricted-host MarkEdit Source/Preview
fidelity implementation begin.

## Checkpoint 2026-07-14 Continuous Canon Execution Authorization

### Verbatim owner excerpts

> “do not notify me just start it all please and finihs it all. after whatever
> keelstoen needs do makredit and then what ever isafter keelsteon like
> lumenless and then beyond until all of the canon prompts are done idk if sync
> was part of mas canon but that is the plan lease cotninue do not stop
> please.”

> “why was makr edit restricted do i need to kep it as suhc”

### Interpreted intent

- Supersede the previous stop-after-verdict boundary. Continue the existing
  KEELSTONE execution key through its proved runtime blockers, then implement
  the near-verbatim MarkEdit Source/Preview contract, then continue
  dependency-ordered LUMENLENS, RECKONER, Sync, and the rest of the free MAS
  canon without pausing for routine notification.
- “All canon prompts” means complete every active free-V1 obligation and
  preserve/debt-classify deferred paid work honestly. It does not reactivate
  Prompt 3, June, Browser, ResearchHub, payment, StoreKit, or general AI in
  Free V1 because the later no-AI owner lock still controls that boundary.
- MarkEdit's security restriction applies only to broad native page-world
  file/service/clipboard authority. It must remain denied. The donor editor
  and Previewer appearance, text geometry, gutter, scrolling, selection,
  active-line behavior, formatting, and preview/eye experience should not be
  visually reduced by that security boundary.

### Hard constraints

- Preserve MAS-only architecture, Free V1 no-AI/no-model behavior except the
  explicit Kokoro voice exception, vault/artifact durable truth, App Sandbox,
  security-scoped access, and the single current build/archive discipline.
- Before every build/test/archive/runtime leg, require swap used strictly
  below 16,384 MiB, at least 25% free memory, zero throttled pages, and no
  competing build/compiler/model/Epistemos process.
- Keep the current dirty worktree intact; read and edit surgically; never
  reset, overwrite, or absorb unrelated user/agent changes.
- Keep MarkEdit's unrestricted native file read/write/delete, macOS Services,
  and clipboard bridge unavailable to embedded page content. Expose only
  narrow Epistemos-owned document operations required by the active surface.
- Do not access private/removable/account/payment/provider/secret or
  Columbia/VA/funding material.

### Non-goals

- No blanket activation of preserved paid source, no second product/agent/
  storage/sync/task/calendar/transcript/calc authority, and no parked Pro,
  Experimental, Goose, Kindred, Node, server, subprocess, terminal, or stdio
  lane.
- No trade-dress clone, new MarkEdit title ontology, replacement Epistemos
  toolbar, or unsafe Boolean flip that enables the full donor bridge.
- No release, performance, visual-fidelity, storage-safety, or canon-complete
  claim from source inspection or a single narrow green check.

### Acceptance checks

- KEELSTONE's retained red legs become current test/build/runtime green:
  compiled and visible Free V1 policy, zero NaturalLanguage/June/provider
  model execution, explicit-only audio initialization and microphone access,
  canonical vault-relative paths, safe save/relaunch/save, no app-owned
  index/save/containment divergence, and bounded diagnostics.
- MarkEdit Source/Preview matches the donor behavior side by side while
  retaining Epistemos palette, toolbar, title popover, sandbox boundaries, and
  byte-faithful Markdown across lens changes, save, close, and relaunch.
- LUMENLENS, RECKONER, Meeting, Sync, Quick Capture, calendar/tasks,
  PDF/import, Kokoro, graph/search, workspace, and export satisfy their
  canonical done bars in dependency order.
- Final completion requires exact one-current-archive evidence, correlated
  logs/manual UI proof, source and artifact guards, broad regressions, and
  three uninterrupted zero-fail recursive app/release passes with no code
  changes between them.

### Contradictions and resolution

- The earlier checkpoint required stopping after the red KEELSTONE verdict.
  This later owner authorization explicitly resumes that same key and the
  subsequent active canon, so the stop boundary is superseded.
- The older MarkEdit implementation coupled visual fidelity to a bridge with
  excessive authority. Resolve this by separating presentation from
  capability: restricted native host, donor UI/behavior, Epistemos-owned
  operations only.

### Exact next action

Remain on `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. Ground the four
runtime-red ownership paths and existing tests, then write the smallest
failing Free-build tests for compiled/visible agent residue,
NaturalLanguage embedding execution, eager audio/microphone polling, and
canonical vault containment. Make and verify the first surgical correction
before advancing to the restricted-host MarkEdit implementation.

### Latest owner steer — App Store-safe native MarkEdit preview

> “continue and yes do that then the method that preserves the cognisant
> restruction where t should be cuz i still want the look of narkedit
> incldung the press on eye to show the native popover ... it needs to still
> work on app store”

The restriction boundary must be capability-specific. Preserve MarkEdit's
native eye control and Previewer popover behavior in the App Store target
through a narrow preview message/host seam. Continue denying general embedded
page authority for arbitrary file read/write/delete, macOS Services, and
clipboard access. Acceptance requires a real signed/ad-hoc App Store artifact
showing that the eye opens the donor-style native popover for supported content
without expanding entitlements, enabling forbidden bridge methods, or leaving
the MAS sandbox.

## Checkpoint 2026-07-14 — Native Rich Epdoc And Cross-Lens Object Inspector

### Verbatim owner excerpt

> “as part of upgrading the ep.doc ... I want to add in all native stuff ...
> they have lists or they have calendar integration. They have dictation
> integration where you can add in a voice note inside of a note, or you can
> draw inside of a note. I want to do all that.”

> “ep.doc is going to be the main default surface ... on the source and the
> prose, there should be an info section ... like a popover that will explain
> all of the things that are embedded into that Markdown file. And then ep.doc
> is going to be the one that has it all visual and that you can see, interact
> with it, edit, etc.”

> “the checklists ... look really low quality. They don't look like Apple
> macOS 26 ... I still want to keep my pixel art font and stuff, but everything
> else, I really want to upgrade it to look more like macOS 26 for the ep.doc
> specifically.”

### Interpreted owner intent

- Epdoc is the default, fully visual, directly editable rich-document lens. It
  must become a structural native workspace rather than a lightly styled text
  editor.
- The Free V1 Epdoc program includes first-class task lists, checklists,
  projects/headings, dates, reminders, calendar context, tags and priority,
  voice-note recording/playback, dictation, drawings/sketches, images and other
  approved attachments, timeline/note/calendar views, and appropriate native
  Apple integrations such as widgets and accessibility.
- Source and Prose must share an accessible document-object inspector/popover
  that inventories every rich object referenced by the current Markdown file,
  shows its type and source location, and provides a route back to the object.
  Source may show a safe inline representation when its Markdown grammar and
  performance allow it; otherwise the inspector is the mandatory truthful
  representation. Epdoc remains the lens that renders and edits the full
  object.
- Existing Epdoc lists and checklists require a real macOS-26-quality component
  redesign—interaction, states, spacing, hierarchy, keyboard behavior,
  accessibility, motion, and performance—not a token-only polish. Preserve the
  Epistemos palette, pixel-art identity, and owner-approved font resources.
- The owner-supplied Things and Diarly screenshots are capability and quality
  references, not authorization to copy their trade dress, assets, wording,
  proprietary formats, or storage systems.

### Hard constraints

- This steer is additive future LUMENLENS/capability-ring scope. It does not
  replace or interrupt the active KEELSTONE correction order: complete the
  current Free V1 June/QuickChat/Goose compile boundary, then the remaining
  exact KEELSTONE blockers, then restricted-host MarkEdit, then advance through
  the canon in dependency order.
- Markdown plus referenced user-owned artifacts remains readable durable truth.
  Rich-object records use stable, round-trippable references and KEELSTONE
  coordinated writes; do not create a parallel note/task/calendar/media
  authority or hide opaque row/blob payloads in Markdown.
- Calendar and reminder integrations use EventKit with least privilege,
  explicit permission, denial-safe behavior, and user-initiated writes.
  Recording/dictation requires explicit action, visible state, privacy copy,
  bounded retention, crash-safe finalization, and no microphone request for
  Kokoro read-aloud.
- Free V1 still contains no June, chat, agent, general model, generative action,
  Browser, or ResearchHub execution. Native deterministic features and Kokoro
  do not reopen those paid lanes.
- Use public MAS-safe native APIs, App Sandbox/security-scoped access, local
  bundled assets, existing provenance/event seams, and the one-current-build
  rule. Preserve raw Markdown, unknown syntax, attachment references, undo,
  selection, scroll position, and dirty-file safety across lens switches.

### Non-goals

- Do not implement this broad program inside the current June-boundary patch
  or claim it exists merely because current models, stubs, or screenshots do.
- Do not clone Things, Diarly, NotePlan, Apple Notes, or any proprietary UI,
  iconography, file format, sync service, or calendar/task database.
- Do not add a second editor toolbar, document identity ontology, task store,
  media library, sync engine, transcript database, or background reconciler.
- Do not make every rich object fully editable in raw Source if doing so would
  compromise Markdown fidelity, source-editor performance, accessibility, or
  sandbox safety; the shared inspector provides the truthful fallback.

### Acceptance checks

- Canon, minimal prompt, build order, live surface registry, and executive
  continuity record all point to one Epdoc rich-object contract and one
  dependency-ordered implementation program, with repository/external-canon
  byte parity.
- A typed rich-object manifest can be rebuilt deterministically from Markdown
  and referenced artifacts and reports lists/tasks, calendar/reminder links,
  voice/audio, drawings, images/attachments, datasets, PDFs, meetings, and
  unsupported objects without silently dropping unknown syntax.
- Epdoc displays and edits each supported object inline; Prose and Source expose
  the same object inventory through a keyboard- and VoiceOver-accessible native
  inspector, and Source uses only proven safe inline renderers.
- Native list/checklist components pass empty, nested, Unicode, rapid toggle,
  reorder, undo/redo, keyboard, VoiceOver, reduced-motion, concurrent edit,
  save/relaunch, and minimal-diff tests; visual evidence covers light/dark
  Epistemos themes and macOS 26-quality interaction without trade-dress copying.
- Audio/dictation/drawing/media/calendar features prove permission denial,
  cancellation, crash recovery, missing/moved artifact handling, sandboxed
  reopen, export portability, and no hidden model/provider/agent startup.
- Lens switching, typing, scrolling, selection, object loading, and attachment
  playback are measured with representative small and large documents before
  any performance or completion claim.

### Contradictions and questions

- “All native stuff” is a product direction, not proof that every reference-app
  feature is feasible or appropriate for one release. Each object class needs
  an API, privacy, data-model, accessibility, performance, and App Review spike
  before admission; unsupported classes remain visible in the inspector rather
  than being silently lost.
- Markdown cannot natively encode every interactive object. The resolution is
  one stable, human-readable reference grammar plus portable artifact files,
  not an opaque embedded database and not a second document authority.
- macOS 26 visual quality does not supersede the Epistemos palette, pixel-art
  identity, saved font preferences, or the near-verbatim MarkEdit Source
  contract. Epdoc owns the native rich-object grammar; Source retains its
  donor-derived editor grammar and gains the shared inspector.

### Exact next action

Record this checkpoint in the repository and external MAS canon mirrors, then
resume the already-scoped June/QuickChat/Goose Free V1 compile-boundary patch.
After KEELSTONE and restricted-host MarkEdit evidence are green, start the
Epdoc rich-object program with a read-only current-source/object inventory and
a failing typed-manifest round-trip test before any new visual component or
permission-bearing integration.

## Checkpoint 2026-07-14 — Fifth PDF Lens, Images, And Dynamic Epdoc Structure

### Verbatim owner excerpts

> “I want it to be a PDF view added as like a fifth surface for the editors in
> a PDF ... the PDF should be the same thing as the app. Also the colors as well.
> I mean the font as whales in the in the colors as well ... an option to edit
> on it and then you'll be able to like save it as PDF and then start looking at
> it.”

> “i wnat to be able to add images to epdoc and thigns like that so liteeralyl
> make it as robust as it ca be ... rn its less trucutred but i want options
> tomake its trutured mayhbe on notes sidebar or whatever. should be dynamic
> like that”

### Interpreted owner intent

- PDF becomes the fifth canonical editor lens in the shared editor switcher and
  identity chrome. It is a full-size native workspace, not the current kind of
  small/low-quality preview.
- An Epdoc note can be viewed and exported as a PDF that carries the approved
  Epistemos palette, registered fonts, hierarchy, images, and supported rich
  objects. The owner can keep viewing it, annotate/edit what PDFKit can safely
  edit, and explicitly save/export it.
- Epdoc images and approved attachments are first-class portable objects with
  inline presentation and a dynamic object/attachment sidebar.
- Epdoc may remain free-flowing or reveal structured outline/project,
  timeline/agenda/calendar, and object/attachment views on demand. These are
  dynamic projections, not conversion into a second note format or database.

### Hard constraints

- The active work order remains KEELSTONE Free V1 boundary and blockers,
  restricted-host MarkEdit, then the typed rich-object manifest/native Epdoc
  program, then the fifth PDF lens and remaining dependency-ordered canon.
- Markdown plus referenced portable artifacts remains durable truth. A live
  Epdoc PDF is derived, cancellable, and off the typing/scroll hot path; it does
  not become a second document authority.
- Imported PDFs remain visually and byte-faithful user artifacts. Epistemos
  palette/font styling applies to app chrome, Epdoc-generated rendition, and
  new annotation defaults, not by silently recoloring or reflowing original
  imported pages.
- In-lens editing is honest: public PDFKit annotations, supported forms, and
  proven page operations. Structural body-text edits return to Epdoc/Source and
  regenerate the PDF because arbitrary PDF text reflow is not a lossless rich-
  text contract.
- All import/save/export paths use App Sandbox, security-scoped access, and
  KEELSTONE writes. Save a Copy is default for imported-PDF mutation until
  atomic in-place conflict/recovery evidence passes.
- Free V1 still has no June, chat, agent, provider, general model, Browser, or
  ResearchHub execution. Kokoro is the sole bundled/app-owned model exception;
  explicit macOS system dictation is an owner-invoked OS text-input service,
  never another bundled or background speech model.

### Non-goals

- Do not implement the PDF or broad Epdoc feature program inside the current
  June compile-boundary correction.
- Do not claim arbitrary imported PDF body text can be edited losslessly, fork
  Markdown truth into PDF, add a PDF database, or mutate original PDFs without
  an explicit safe write choice.
- Do not copy Things/Diarly/NotePlan/Preview trade dress or replace Epistemos
  palette, fonts, toolbar, title ontology, MarkEdit Source grammar, or owner-
  approved identity.

### Acceptance checks

- Canon, minimal prompt, build order, surface registry, executive continuity,
  and this intent ledger all name the fifth PDF lens, dynamic Epdoc structure,
  first-class images, shared authority, and exact dependency order; both canon
  mirrors remain byte-identical with a regenerated manifest digest.
- The full-size PDF lens supports fit/zoom, page navigation, thumbnails/outline,
  search, selection, keyboard/VoiceOver access, shared object/source inspector,
  stable restoration, annotations/forms, Save a Copy, and explicit export.
- Epdoc-generated fixtures prove page count, extracted text, registered fonts,
  palette, images, links, supported rich objects, deterministic pagination, and
  visual rendering without clipping, overlap, broken glyphs, or missing media.
- Imported-PDF fixtures prove original protection, annotation/form save-reopen,
  sandbox denial, external conflict, interruption/recovery, missing-file state,
  and honest unsupported editing behavior.
- Dynamic document/outline/project/timeline/calendar/sidebar views rebuild from
  one manifest and preserve source reachability, dirty state, selection, scroll,
  undo/redo, rapid switching, large-document performance, and image reference
  portability.

### Contradictions and resolution

- “Edit on the PDF” can mean annotation/form editing or arbitrary source-text
  reflow. Apple PDFKit directly supports the former; the latter cannot be
  promised as lossless Markdown editing. Epistemos therefore annotates/forms in
  PDF and routes structural content changes to Epdoc/Source before regeneration.
- “Same colors and fonts as the app” applies fully to Epdoc-generated PDF output
  and PDF chrome/annotation defaults. Recoloring an imported PDF would violate
  its fidelity, so imported page appearance remains unchanged unless the owner
  deliberately creates a new transformed copy in a later proven feature.

### Exact next action

Finish the independent June-boundary diff review and the current one-build
focused green evidence leg under the 16-GiB preflight. After KEELSTONE and the
restricted-host MarkEdit seam are green, inventory current PDFKit/export/image/
surface-switcher code and land the typed object-manifest round-trip test. The
first PDF implementation slice is read-only full-size viewing plus one
deterministic Epdoc-generated PDF fixture; no annotation/write/live-preview
claim precedes that foundation's render and authority evidence.

## Checkpoint 2026-07-14 — Native MAS Integration Supremacy, Intent Correctness, And Performance

### Verbatim owner excerpt

> “so intents and all othe thigns that make the app deeply integrated idk what
> other apps have on the app store but i want hte secret i want you to contneu
> and also research what they do that my app can do if i have the proper thigns
> like ntents and such but ofc i lost the singing thngs i will still get it back
> i just dont know if i ll be abel to test my app out without them so please make
> sure i have as muhc as i can get like no cormpmise also otpimsie for
> performacne and such. but yea one app def cotonieu im jut reiteratign that i
> want the full capabiltiies i can get on MAS to superceed those kind of apps”

### Interpreted owner intent

- Build one deeply integrated Mac App Store Epistemos that legitimately uses
  the strongest relevant public macOS capabilities available to a sandboxed
  productivity, notes, planning, document, and research workspace.
- Preserve and expand real modern App Intents/Shortcuts integrations. Removing
  an obsolete or false legacy SiriKit declaration is correctness work and must
  not remove the compiled App Intents, shortcuts, entities, queries, or future
  public integration program.
- Research current successful Mac App Store productivity/note applications and
  official Apple APIs after the current KEELSTONE gate, then turn supported
  capability gaps into a dependency-ordered, evidence-gated canon program.
- Treat responsiveness, memory, launch/load time, editor stability, background
  work, and permission behavior as acceptance criteria for every integration;
  feature count cannot outrank performance or data safety.
- Continue local source work, unsigned builds, and tests without waiting for a
  paid signing account. Signing, notarized/distribution identity, App Store
  submission, and device/distribution-only evidence resume only when the owner
  restores the required account and credentials.

### Hard constraints

- One Mac App Store app, one current build artifact, one vault/document truth,
  one coordinated write path, and no parallel product, private server, sidecar,
  subprocess runtime, hidden background authority, or duplicate data store.
- Keep the current execution key
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` until its final verdict is
  recorded. Do not start MarkEdit, Epdoc, PDF, LumenLens, RECKONER, Sync, or a
  new canonical key inside the current intent-metadata evidence leg.
- Free V1 keeps June/chat/agent/provider/general-model/Browser/ResearchHub code
  hidden and uncompiled while retaining it in source for future paid work.
  Kokoro remains the sole bundled/app-owned model exception; explicit system
  dictation remains an owner-invoked OS service.
- Integrations must use public App Store-safe Apple APIs, least-privilege
  entitlements and permissions, App Sandbox/security-scoped access, accessible
  native behavior, deterministic failure states, and honest availability.
- Research may learn capability patterns and public interaction conventions;
  it must not copy proprietary implementation, private formats, branded trade
  dress, icons, screenshots, or inaccessible services from competing apps.
- Do not request, inspect, restore, replace, or infer signing credentials,
  Apple-account state, payment state, private Columbia/VA/funding material,
  removable-drive material, provider secrets, or other private data.

### Non-goals

- Do not preserve `INIntentsSupported` merely to appear integrated when no
  directly handled legacy `INIntent` subclasses exist. Do not invent SiriKit
  handlers, import the legacy Intents framework, or add entitlements solely to
  satisfy stale metadata.
- Do not claim every Apple capability is appropriate or already implemented.
  Each candidate needs API, sandbox, privacy, accessibility, performance,
  persistence, App Review, and runtime evidence before admission.
- Do not let missing paid signing block compile-time tests, unsigned local app
  builds, source audits, deterministic unit tests, or other evidence that does
  not require distribution identity.

### Acceptance checks

- The fail-first legacy-metadata test proves the source and built app currently
  advertise unsupported `INIntentsSupported`; the surgical correction makes
  both checks green while the current generated App Intents metadata still
  proves the expected action/entity/query/shortcut inventory.
- The exact current source plist, built plist, generated App Intents metadata,
  result bundle, log, app identity, artifact count, and hashes are recorded.
- A later native-capability research matrix covers at least App Intents and
  Shortcuts/Siri exposure, Spotlight, services/share/open-in and drag/drop,
  widgets, notifications, Calendar/Reminders, system dictation and owned audio,
  accessibility, document/PDF/Quick Look behavior, restoration/Handoff where
  appropriate, sandboxed files, and measurable performance.
- Every admitted capability has explicit permission-denial, restricted or
  unavailable-state, cancellation, relaunch/restoration, accessibility, data-
  loss, memory, latency, and background-work evidence sized to its risk.
- Local development remains unblocked without signing; the evidence ledger
  clearly labels distribution/signing proofs as deferred rather than faking or
  silently omitting them.

### Contradictions and resolution

- The owner wants “proper intents” while the current plist advertises legacy
  SiriKit handlers the app does not implement. Apple distinguishes directly
  handled legacy `INIntent` subclasses from modern App Intents metadata. Remove
  only the false legacy key and prove the modern generated inventory remains.
- “No compromise” cannot mean enabling every API regardless of privacy,
  performance, product coherence, or App Review. It means no knowingly shallow
  integration: only capabilities that pass the full admission and evidence bar
  become active, while rejected or deferred candidates remain truthfully
  documented.
- Missing signing credentials block distribution-grade signing/submission and
  some entitlement/device proofs, but they do not block unsigned local builds,
  ordinary unit tests, source guards, or most performance and UI work.

### Exact next action

Complete the current legacy SiriKit metadata red-to-green evidence leg: record
the red artifact, remove only the unsupported `INIntentsSupported` plist block,
pass the 16-GiB resource preflight, delete the stale red test app, run exactly
one serial focused green build, and verify the modern generated App Intents
inventory against that exact app. Then update the existing KEELSTONE evidence
and continue its next recorded debt; do not begin the broader capability build
or another canonical execution key yet.

## Checkpoint 2026-07-14 — Privacy Truth, Working Native Voice, And Quick Capture Ownership

### Verbatim owner excerpts

> “i want the full capabiltiies i can get on MAS to superceed those kind of
> apps”

> “They have dictation integration where you can add in a voice note inside of
> a note ... I want to do all that.”

> “make sure i have as muhc as i can get like no cormpmise also otpimsie for
> performacne and such.”

### Interpreted owner intent

- Preserve real, owner-invoked native voice capability and ultimately make
  Quick Capture voice a working, durable input—not a decorative button or
  permission string.
- Keep Meeting transcription working through the current public
  `SpeechAnalyzer`/`SpeechTranscriber` organ while removing privacy copy that
  falsely names chats or the currently nonfunctional Quick Capture path.
- Share one speech/capture authority safely. Quick Capture must not preempt,
  stop, clear, or corrupt an active Meeting or a second capture.
- Continue source/tests/unsigned evidence while paid signing is unavailable;
  label signed distribution/TCC evidence deferred.
- Keep performance, cancellation, teardown, data durability, permission
  behavior, and truthful UI as acceptance criteria—not later polish.

### Hard constraints

- Stay inside `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` and the strict
  swap-used-below-16,384-MiB, free-memory-at-least-25%, zero-throttled-pages,
  no-competing-process, and one-current-build rules.
- Free V1 contains no June, chat, agent, provider, general model, Browser, or
  ResearchHub runtime. Kokoro remains the sole bundled/app-owned model
  exception.
- Use the existing public native speech organ; do not restore
  `SFSpeechRecognizer`, hidden subprocess capture, a local server, sidecar,
  second recorder authority, or stale speech metadata merely to make the
  feature look present.
- Do not access signing credentials, Apple accounts, payment, secrets,
  removable media, or private Columbia/VA/funding material.

### Non-goals

- Do not claim Quick Capture Dictate works because the button exists, the
  microphone entitlement is present, or Meeting transcription works.
- Do not broaden this seam into the later MarkEdit, Epdoc rich-object, PDF,
  planner, widget, Calendar/Reminders, Sync, LumenLens, or Reckoner programs.
- Do not perform a normal interactive app launch, microphone request, or real
  audio capture before the relevant permission, ownership, and teardown
  contract is implemented and the resource gate passes.

### Acceptance checks

- The exact Free V1 source and built plist name only explicit Meeting
  microphone use and omit the server-oriented speech-recognition key while
  preserving the audio-input entitlement and modern App Intents inventory.
- A fail-first Quick Capture contract proves the current visible Dictate action
  and Settings voice claim reach unavailable stubs.
- Any real restoration uses an owner-scoped, non-preemptive capture lease with
  deterministic busy/unavailable/permission-denied/cancelled states, explicit
  draft persistence, and owner-only stop/teardown.
- Tests prove Meeting and concurrent Quick Capture sessions cannot steal,
  clear, or stop one another, and no raw audio or partial transcript is lost or
  silently committed on failure.
- If the safe path is not ready for Free V1, the dead control is hidden or
  truthfully disabled and Settings stops overclaiming it.

### Contradictions and resolution

- The app has a real native Meeting transcription path, but Quick Capture's
  visible Dictate button currently uses intentionally fail-closed
  `AudioRecorder`/`AudioTranscriber` stubs. The Meeting-only privacy correction
  is therefore truthful; it must not be misread as deleting the owner's future
  Quick Capture voice requirement.
- Reusing `LiveVoiceInputService` naively would let one surface stop or clear
  another surface's capture. Add ownership/lease semantics before wiring the
  UI; feature presence cannot outrank data integrity.
- Missing signing blocks distribution-grade entitlement/TCC proof, not the
  source contract, fail-first tests, unsigned builds, or deterministic
  concurrency/state-machine evidence.

### Proven state

- The privacy fail-first result recorded four expected source/built-plist
  issues before product correction.
- The surgical correction changed only `Epistemos-AppStore-Info.plist`: exact
  Meeting-only microphone copy and no
  `NSSpeechRecognitionUsageDescription`.
- The focused replacement passed one test with zero failures and retained one
  exact unsigned app. Speech/AVFoundation links, audio-input entitlement,
  current App Intents inventory, and the absence of executable
  `SFSpeechRecognizer` symbols were reverified.
- Overall KEELSTONE remains incomplete and not release ready.

### Exact next action

Add the smallest fail-first Quick Capture voice-honesty/capture-ownership test
after completing the read-only call-site map. Then implement only the minimum
shared capture-lease contract needed to prevent preemption and cross-session
teardown, or truthfully hide/disable the dead control if that contract cannot
be proven within the gate. Re-run the strict 16-GiB preflight and delete the
current app before any next serial build. Do not start a new execution key.

## Checkpoint 2026-07-14 — Maximum MAS Integration Without Signing Fiction

### Verbatim owner excerpt

> “i want hte secret i want you to contneu and also research what they do that
> my app can do if i have the proper thigns like ntents and such ... please make
> sure i have as muhc as i can get like no cormpmise also otpimsie for
> performacne and such ... i want the full capabiltiies i can get on MAS to
> superceed those kind of apps”

### Interpreted owner intent

- Build one coherent, deeply integrated Mac app rather than a collection of
  disconnected feature stubs. Use legitimate modern Apple frameworks and App
  Store-safe integrations wherever they materially improve the product.
- Research the current native capability envelope—including App Intents,
  Shortcuts, Spotlight, widgets, calendar/reminders, accessibility, document
  and rich-media workflows—and preserve those decisions in the existing MAS
  canon after the active release-gate repair is proven.
- Treat performance, responsiveness, memory, cancellation, and data durability
  as admission requirements for every integration.
- Continue all source, deterministic test, unsigned-build, and local artifact
  work that does not require the lost paid signing identity. Keep signing,
  entitlement-distribution, and App Store submission proof explicitly deferred
  until the owner restores an Apple developer account.

### Hard constraints

- Finish the current Quick Capture ownership/session repair and its evidence
  before broadening into the later MAS feature canon.
- Stay on the current execution key and Free V1 boundary: no June, chat,
  agents, providers, general model runtime, Browser, or ResearchHub; Kokoro is
  the sole bundled/app-owned model exception.
- Use public, sandbox-compatible Apple APIs and truthful permission/UI copy.
  Do not reach for private APIs, hidden helpers, subprocesses, local servers,
  credential access, or distribution claims without exact evidence.
- Preserve the one-current-build rule and the strict resource preflight before
  every later test, build, or archive.

### Non-goals

- Do not enable every framework merely to inflate a feature list. Native
  integration must have a coherent user route, privacy boundary, fallback,
  performance budget, accessibility behavior, and evidence plan.
- Do not buy, recover, inspect, or modify Apple accounts, signing identities,
  payment, secrets, or external drives from this task.
- Do not claim signed/TCC/App Store behavior from an unsigned local artifact.

### Acceptance checks

- The active Quick Capture test moves from the retained 13-issue red artifact
  to owner-scoped lease/session behavior with behavioral concurrency tests.
- Official Apple sources produce a capability matrix that distinguishes local
  unsigned work from signing-, entitlement-, device-, and distribution-bound
  proof, and the matrix is folded into the existing canon rather than a
  competing plan.
- Every later admitted integration has explicit denial/unavailable,
  cancellation, restoration/data-loss, accessibility, latency, memory, and
  background-work checks.
- Overall KEELSTONE remains honestly incomplete until its recorded runtime and
  release evidence chain passes.

### Contradictions and resolution

- “No compromise” does not override MAS privacy, sandbox, entitlement, or
  review constraints. It means using the strongest public architecture that
  can be truthfully supported and tested, with blocked distribution legs
  named rather than hidden.
- The owner wants broad native research now, but the active red release seam
  must remain serial. Research may run read-only in parallel; implementation
  and canon promotion wait until the Quick Capture repair is proven.

### Proven state

- The fail-first Quick Capture ownership test is retained at
  `build/xcode-results/2026-07-14-free-v1-quick-capture-lease-red-16gib.xcresult`.
  It ran one test, passed zero, failed one, and recorded 13 expected contract
  issues. No interactive launch, microphone request, or audio capture ran.
- Its build log is 698,805 bytes with SHA-256
  `31f20c29a1d92fa03a83b38a7e983d370b1007b69c3d05cc49ad086c4c15c559`.

### Exact next action

Implement the smallest exact-owner voice lease and analyzer session-token
contract, migrate Meeting/Quick Capture/cached-window teardown and their
deterministic tests, then re-run the strict resource preflight. Delete the red
app immediately before producing the single replacement green test app. Do
not begin another execution key or broader feature implementation.

## Checkpoint 2026-07-14 — Quick Capture Implementation Paused At The 16-GiB Gate

### Verbatim owner constraints carried forward

> “make it lock at 16gb at this point man”

> “one build whever testung u must delte the stale builds before building an ew
> app”

### Interpreted owner intent

- Preserve the exact in-flight Quick Capture repair through the resource stop;
  do not discard it, fake a green result, raise the ceiling, or restart a
  competing implementation.
- Resume automatically at the same verification boundary after resources are
  reset, keeping one current artifact and the same canonical execution key.

### Proven state

- The fail-first result is retained with one failed test and 13 intended
  contract issues.
- The exact-owner/session implementation is present in working source but has
  not been parsed, compiled, tested, built, launched, or exercised with audio.
- The post-edit preflight found 17163.44 MiB swap used, 63–64% free memory, zero
  throttled pages, sufficient disk, and no competing Xcode/compiler/model/app
  process. Swap is 779.44 MiB over the strict ceiling.
- The previously built red app remains the sole app artifact and is explicitly
  stale relative to current source.

### Verification debt

- Preserve the last promoted Meeting partial in the crash-recovery draft during
  close teardown.
- Add typed denial/cancellation and cross-owner behavior tests, then Quick
  Capture draft recovery.
- Update and prove the privacy test/build against the new truthful Meeting plus
  Quick Capture microphone purpose.
- Run no compiler or replacement build until the full preflight passes, and
  delete the red app only immediately before that single replacement build.

### Exact next action

After the resource reset, re-run branch/HEAD/dirty/swap/memory/throttling/disk/
process preflight. If and only if every threshold passes, finish the two known
durability/test debts, run static checks, delete the retained red app, and run
one serial focused replacement batch. Remain on
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

## Checkpoint 2026-07-14 — Owner Removes Swap Ceiling As A Stop Condition

### Verbatim owner excerpt

> “please jsut contieu do nto worry about the limit stop worry about the limit
> do not stop”

### Interpreted owner intent

- Continue the exact in-flight Quick Capture/Meeting repair without pausing
  again solely because swap usage is above the previously selected 16-GiB
  ceiling.
- Preserve the already-produced red evidence and complete the scoped source,
  deterministic tests, single replacement build, and artifact audit under the
  same execution key.

### Hard constraints retained

- The swap-used-below-16,384-MiB threshold is no longer an owner stop gate for
  this continuation. Record swap as diagnostic evidence, but do not halt solely
  because it exceeds that number.
- Keep the one-current-build rule, run no competing Xcode/compiler/model/app
  process, require sufficient disk and zero throttled pages, and execute builds
  serially.
- Delete the retained red app only immediately before the one replacement
  build. Do not claim current source works before exact parse/test/build
  evidence exists.
- Preserve Free V1/MAS-only boundaries, Kokoro as the sole bundled/app-owned
  model exception, and the ban on accounts, signing credentials, secrets,
  removable media, and private Columbia/VA/funding material.

### Acceptance checks

- Close the known Meeting final-partial durability gap and the deterministic
  ownership/race tests before the replacement build.
- Prove the focused Quick Capture, privacy, lease-registry, Meeting, and voice
  regression batch against exactly one newly produced app artifact.
- Record resource observations and any warnings honestly, without using swap
  alone as a reason to stop or as passing product evidence.

### Exact next action

Re-read the in-flight implementation and tests, correct the known Meeting
close-durability ordering, add the missing deterministic ownership/race and
Quick Capture draft-recovery coverage, run static checks, then perform the
single serial replacement build and artifact audit. Remain on
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

## Checkpoint 2026-07-14/15 — Replace Epdoc Engine, Preserve Epistemos Product Shell

### Verbatim owner excerpts

> “please start that migratio i wnat to make sure i keep ym chrome ad keep my
> pixel art font and epistemos plaette but the ui of the surfaec can be
> revamped ... i rlly want a proven foundation tho”

> “please do not lose sight or forget about all the oother steers but i do want
> to pivot then we can just stop trying to polsih epdoc and compeltely redo it
> maybe cloning ... tolaria or another githu repo that has rich codemirror md
> editting ... lets pivot adn start tryign to redo the epdoc surface”

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

### Interpreted owner intent

- Stop treating the current Tiptap/ProseMirror Epdoc canvas as the foundation
  to polish indefinitely. Replace the Epdoc editing engine with a proven
  CodeMirror 6 rich-Markdown/live-preview substrate, choosing the donor or
  reference only after current-source, maintenance, performance, license, and
  App Store integration review.
- The replacement boundary is the Epdoc canvas and its internal editor/runtime
  ownership. The Epistemos window and navigation chrome, owner toolbar,
  document title and identity popovers, surface switcher, Epistemos palettes,
  Matrix/Matrix Bold/Matrix-type, Chonky, Greetings, and other registered font
  contracts remain Epistemos-owned and must survive unchanged unless a later
  explicit owner steer changes them.
- Reuse the already-vendored MarkEdit/CoreEditor CodeMirror 6 implementation
  where it is the strongest proven substrate. A donor such as Tolaria or
  another open-source editor may contribute narrowly reviewed patterns or
  extensions, but it must not add a second product shell, unsafe bridge,
  parallel document authority, incompatible license, or proprietary trade
  dress.
- Markdown remains the durable source of truth and the same file must switch
  among Epdoc, Source, Prose, Preview, and the planned PDF lens without JSON
  mirror authority, stale snapshot restoration, disappearing text, backspace
  resurrection, save refusal, selection loss, or recalibration jumps.
- The new Epdoc must eventually support the already-recorded rich-object
  program: native-quality tasks/checklists, headings/projects, tags, dates,
  reminders/calendar context, images and attachments, voice notes/dictation,
  drawing, datasets, meetings, PDFs, object inspection, accessibility, and
  safe inline widgets/decorations. These are dependency-ordered capabilities,
  not permission to fake them in the first migration slice.
- Large Markdown documents are a first-class acceptance case. The retained
  roughly 58,000/67,000-word KEELSTONE-class fixture must remain editable,
  deletable, saveable, scroll-stable, and lens-switchable without whole-
  document JSON serialization or ProseMirror full-tree work on each keystroke.

### Hard constraints

- Remain inside
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`: this replacement is a
  focused response to current runtime-red Epdoc fidelity, divergence, latency,
  and large-document failures, not a new canonical execution key.
- Preserve the Free V1 boundary: June, chat, agents, general models/providers,
  Browser, and ResearchHub remain hidden, inert, and uncompiled; Kokoro remains
  the separately approved voice exception. Do not add a Node backend, local
  server, subprocess, terminal, stdio-MCP, or network-loaded editor asset.
- Preserve App Sandbox, bundled WKWebView assets, non-persistent web data,
  narrow native message handlers, security-scoped vault writes, undo, raw
  Markdown/unknown syntax, owner file safety, and the one-current-build and
  resource-preflight rules in root `AGENTS.md`.
- Keep the existing dirty worktree intact. Do not reset, overwrite, broadly
  delete, or absorb unrelated changes. Use a staged migration seam with an
  explicit rollback path until behavior and runtime evidence are green.
- Do not simply flip `allowsMarkEditWindowToolbar`, expose MarkEdit's general
  file/service/clipboard bridge, clone Obsidian or proprietary apps, or claim
  performance/visual/runtime success from package presence or source guards.

### Non-goals for the first migration slice

- No rewrite of the whole app shell, note store, sync engine, title ontology,
  toolbar, theme system, font registry, or every lens at once.
- No immediate implementation claim for calendar, reminders, voice, drawing,
  PDF editing, widgets, or every rich object before the core Markdown edit,
  save, undo, selection, scroll, and surface-switch contract is proven.
- No deletion of the legacy Tiptap engine until the replacement passes narrow,
  broad, large-document, manual, and rollback evidence.

### Acceptance checks

- Architecture evidence names the selected CodeMirror substrate, exact reused
  code, donor/license boundary, bridge boundary, document authority, rollback
  seam, and why it is preferable to the current Tiptap hot path.
- The first real replacement slice renders inside existing Epistemos chrome
  and palette/font contracts, edits raw Markdown directly, emits bounded
  transactions, saves through the existing coordinated Markdown route, and
  preserves Source/Prose/Preview switching.
- Backspace/delete cannot be overwritten by a host reload; typing and scrolling
  do not cause invisible/reappearing content, position jumps, or whole-document
  mirror churn.
- Representative small, Unicode/nested, and KEELSTONE-scale Markdown fixtures
  prove edit, undo/redo, save, close/reopen, rapid lens switch, selection,
  scroll stability, memory/latency bounds, and unknown-syntax preservation.
- Visual/manual evidence proves the Epistemos shell remains intact while the
  Epdoc canvas is visibly and structurally replaced. Completion later invokes
  the deep-hardening, recursive app, release, and maintainability audit loops.

### Contradictions and resolution

- Older checkpoints ordered restricted-host MarkEdit Source/Preview before
  broad Epdoc feature work. The current explicit pivot supersedes incremental
  Epdoc polishing, but it does not discard the MarkEdit fidelity contract; it
  promotes the same restricted MarkEdit/CoreEditor substrate as the leading
  candidate for the replacement engine.
- The handoff's older stop boundary prohibited later feature work until current
  KEELSTONE defects were focused. Epdoc divergence, 40-second delay, save/lens
  failures, and large-document hangs are now current focused KEELSTONE defects,
  so the replacement proceeds under the same key while other canon features
  remain queued.

### Exact next action

Complete the current-source ownership map for `MarkdownDocumentSurface`,
`EpdocEditorChromeView`, the Tiptap bridge/bundle, MarkEdit/CoreEditor, surface
switch flushing, coordinated save, and existing regressions. Verify candidate
donor repositories and licenses. Then select the smallest real engine seam and
land one fail-first migration test plus the first CodeMirror-backed Epdoc
canvas path behind the existing Epistemos chrome, without deleting the legacy
fallback or starting a new build before the mandatory preflight.

## Checkpoint 2026-07-15 — CodeMirror Canvas Broad Green, Data-Loss Hardening Still Open

### Verbatim owner excerpt carried forward

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

### Interpreted owner intent

- Keep the Epistemos-owned window chrome, toolbar, title/identity popovers,
  palette, and registered Matrix/Chonky/Greetings font contracts while the
  Epdoc editing canvas uses the restricted MarkEdit/CoreEditor CodeMirror 6
  foundation.
- Continue hardening the replacement canvas until save, note switching,
  deletion, scrolling, and large-document behavior are proven; do not mistake
  a green broad test batch for visual completion or release readiness.

### Hard constraints and non-goals

- Markdown remains the only durable document authority. A dirty edge may not
  be cleared or a page identity replaced until the exact CodeMirror checkpoint
  is obtained and durably written.
- Preserve the existing Epistemos chrome and palette boundary. Do not reopen
  shell, toolbar, font, paid-surface, June, Browser, ResearchHub, or broad rich-
  object feature work while these synchronization blockers remain.
- Keep the legacy Tiptap canvas as rollback only. Do not delete it or perform
  the planned coordinator decomposition in the same patch as the blocker
  corrections.

### Proven state

- R69 passed the 10-test focused CodeMirror/large-document batch with zero
  failures. The hosted KEELSTONE-scale test proved exact insertion, deletion,
  scroll, explicit checkpoint save, and final fixture restoration.
- R70 passed all 192 tests in the App Store KEELSTONE target with zero failures
  or skips. This proves the current Debug regression slice only; it does not
  prove manual visual fidelity, Release/archive behavior, distribution, or
  final KEELSTONE readiness.
- Read-only hardening found two untested P0 races: Save can synchronously clear
  the only dirty indication before its asynchronous checkpoint starts, and a
  page-ID switch can enqueue the old `latestMarkdown` before the dirty-only
  CodeMirror delta has been checkpointed.
- The same review identified two P1 synchronization debts: programmatic reset
  and user-edit transactions still lack explicit origins, and a clean active
  same-page external update can be accepted by host state without reaching the
  visible editor.
- `MarkEditCoreEditorCoordinator.swift` is now 1,556 lines and owns too many
  synchronization responsibilities. Decomposition into a typed synchronization
  session is real maintainability debt, but mixing it into the immediate P0
  repair would increase regression risk.

### Acceptance checks

- A fail-first Save test proves a dirty-only CodeMirror edit is checkpointed
  and written before `isDirty` becomes false.
- A fail-first page-switch test proves the old page's exact CodeMirror text is
  checkpointed and written before the coordinator changes document ownership.
- Focused and broad replacement batches pass under the one-current-build and
  mandatory resource-preflight rules, with exact artifacts and hashes recorded
  in the existing KEELSTONE evidence document.
- P1 reset-origin and external-update risks are either corrected with focused
  evidence or remain explicitly red; no visual, Release, or ship claim is made
  while they are unproven.

### Contradictions and resolution

- R70 broad green does not contradict the hardening findings: its tests cover
  explicit checkpoint saves and flushed surface switching, not dirty-only Save
  timing or page replacement before a checkpoint.
- The owner asked to continue feature work autonomously, but the same owner
  requires editor text never to disappear or restore after deletion. These
  P0 data-loss seams therefore remain the exact next work before another
  feature phase or Release archive.

### Exact next action

Add deterministic fail-first tests for dirty-only Save and dirty-only page-ID
switching. Then make the smallest ownership-ordering correction so only a
verified successful checkpoint/write clears dirty state or permits the old
page coordinator to be replaced. Audit the two P1 seams next, re-run the exact
resource preflight, delete the sole stale app immediately before the one
replacement build, and run focused then broad serial verification under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

## Checkpoint 2026-07-15 — Visible Transaction During Reset-Settle Must Survive

### Verbatim owner excerpt

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

### Interpreted owner intent and constraints

- Continue replacing only the Epdoc canvas. The Epistemos chrome, toolbar,
  title/info affordances, palette, and Matrix/Chonky/Greetings font ownership
  remain unchanged.
- A visible CodeMirror edit is user data even when the asynchronous Swift reset
  operation is still waiting for its paint-settle callback. Reset metadata may
  remain non-user, but the bridge must not discard that real transaction.
- Keep this correction inside the existing Markdown authority, delta mirror,
  coordinated save, App Sandbox, Free V1, and legacy-rollback boundaries.

### Current evidence and contradiction resolution

- R72 previously passed the hosted KEELSTONE-scale insert/delete/save test.
- R73 and fresh R74 both failed the same large-document save sequence after
  reset-origin hardening. R74 still loaded the exact fixture and completed the
  synthetic insertion under the retained 100 ms limit, but the toolbar never
  became dirty and no Markdown save occurred.
- Source inspection explains the regression: the new editor is visible before
  `resetEditor` finishes two-frame paint settling, while `postTransactions`
  returned early for every transaction during that entire interval. MarkEdit
  creates reset content as the initial `EditorState`; it does not need a
  document-change transaction for the reset itself. Therefore accepting actual
  update-listener document transactions does not turn reset creation into a
  user edit.

### Acceptance checks and exact next action

- Preserve the applying flag for reset/snapshot metadata.
- Do not suppress an actual CodeMirror `docChanged` transaction solely because
  the reset paint-settle flag is active.
- Prove the exact R74 large-document insertion, dirty edge, save, scrolling,
  deletion, second save, and final snapshot in a fresh focused run.
- If focused green, run the complete App Store KEELSTONE target serially before
  updating the existing evidence document or considering Release work.

## Checkpoint 2026-07-15 — Epdoc Canvas Debug Regression Gate Green

### Verbatim owner excerpt

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

### Interpreted owner intent and fixed boundary

- The Epdoc canvas is the replacement surface. Epistemos continues to own the
  window chrome, toolbar, title/info interactions, palette, and registered
  Matrix/Chonky/Greetings fonts.
- The CodeMirror migration must make large Markdown editing, deletion, save,
  and lens switching reliable without reopening the queued rich-object or
  paid/AI feature scope.
- A Debug green is necessary but not sufficient: visual fidelity, Release
  archive artifacts, distribution, and the finite manual/runtime matrix still
  require current exact evidence.

### Proven state

- R76 passed all 14 focused synchronization and hosted large-document tests.
- R77 passed the whole current App Store KEELSTONE target: 196 tests in 4
  suites, zero failures or skips.
- The hosted KEELSTONE-scale test proves exact insertion, dirty state, save,
  scrolling, deletion, a transport-safe retry, second save, and final fixture
  restoration. It does not prove subjective visual parity or an App Store
  Release artifact.
- The exact R69-R77 chain, preflights, artifact paths, and hashes are recorded
  in `KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`.

### Remaining acceptance checks

- One fresh `Epistemos-AppStore` Release archive must pass all artifact gates
  before launch.
- Manual evidence must prove the retained Epistemos chrome/palette/fonts and
  the new canvas across typing, backspace, scrolling, selection, title/info
  popovers, lens switches, save/reopen, and representative large documents.
- The final KEELSTONE verdict must record every unproven leg and stop this
  execution key without beginning later canon feature work.

### Exact next action

Read and apply the Epistemos Release Audit procedure, re-run the resource
preflight, enforce the one-current-build rule, and produce exactly one fresh
Release archive. Run all artifact gates against that exact archive and do not
launch if any gate is red. Only a green artifact gate may open the finite
serial manual/runtime matrix.

## Checkpoint 2026-07-15 — R78 Release Identity Regression Blocks Launch

### Verbatim owner excerpt

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

### Interpreted owner intent and fixed boundary

- Preserve the existing Epistemos window chrome, toolbar, palette, title/info
  interactions, and Matrix/Chonky/Greetings font ownership.
- Replace only the Epdoc editing canvas with the restricted
  MarkEdit/CoreEditor CodeMirror foundation.
- Free V1 must keep paid AI/chat/June/Browser/Research Hub implementation
  hidden and out of the compiled product. Kokoro remains allowed.
- A compiled paid/provider identity regression is a Release blocker even when
  the corresponding UI is hidden at runtime.

### Current exact evidence and contradiction

- The R78 `Epistemos-AppStore` Release archive compiled successfully and the
  primary KEELSTONE and bundle scanners passed.
- The stricter R43-compatible executable identity scan is red: the universal
  Release executable contains exact paid/runtime identifiers including
  `_claudeManagedSessionsEnabled`, `epistemos.kimiModel`, `gguf`, `june`,
  `openai`, `anthropic`, and `claude`.
- Some broad substring hits are benign library/localization data, including
  Turkish text containing `kimi` and the timezone `America/Juneau`. Those do
  not excuse the exact whole-string product identifiers.
- R43 previously recorded zero strict executable hits on the same HEAD, so R78
  is an active worktree regression that must be traced and corrected before
  launch.

### Hard constraints and non-goals

- Do not launch R78, claim visual/runtime behavior, or use it as Release
  evidence while the strict identity gate is red.
- Do not remove the new Epdoc canvas, Epistemos chrome/palette/fonts, meeting,
  PDF/import, graph, local note, or Kokoro capability to make the scan green.
- Preserve paid future source behind compile boundaries; do not delete the
  parked paid lane from the repository.
- Do not broaden this pass into queued rich-object feature work or another
  canonical execution key.

### Acceptance checks and exact next action

- Add an exact whole-string Release executable identity gate that catches
  genuine paid identifiers without treating benign embedded substrings as
  product identity.
- Trace each genuine R78 hit to its compiled source owner and add the narrowest
  Free-V1 compile boundary or neutral replacement.
- Re-run the existing Debug regression target after source correction.
- Re-preflight, delete the invalid R78 app/archive, produce exactly one fresh
  Release archive, and require every artifact gate to pass before launch.

## Checkpoint 2026-07-15 — R85 Owner-Visible Epdoc Test Session

### Verbatim owner excerpts

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

> “whats the status did u replace epdoc yet”

> “let me test it out please continue building on it byt i want to test it so
> build s i can use”

> “io oet u know when im done.”

### Interpreted owner intent

- The implemented replacement is the Epdoc editing canvas only. Epistemos
  continues to own the surrounding window chrome, toolbar, palette,
  title/info interactions, and bundled display fonts.
- The owner wants to use the exact current build personally before visual,
  interaction, performance, or completion acceptance is claimed.
- The test session must preserve the current R85 build and use isolated audit
  storage rather than the owner's normal Epistemos vault or preferences.
- Once the owner-visible app is open, the agent must not close, relaunch,
  inspect, or interact with it until the owner says the test is finished.

### Current exact state

- The CodeMirror 6 Epdoc canvas replacement is compiled into the exact R85
  Release app. R84 passed 198 App Store KEELSTONE tests, including the hosted
  KEELSTONE-scale edit/delete/scroll/save fixture.
- R85 passed the integrated KEELSTONE gate, standalone bundle scan, strict
  paid-identity scan, signature/entitlement/architecture checks, main privacy
  manifest equality, CoreEditor asset/handshake checks, and bundled
  Matrix/Matrix Bold/Matrix Dots/Chonky presence checks.
- The exact R85 app is being launched through macOS Launch Services with a
  fresh three-part runtime-audit isolation tuple and stable audit defaults
  suite. This is owner-visible runtime evidence, not distribution signing or
  App Store submission evidence.
- Two earlier direct-executable attempts were cleaned up when their command
  sessions ended. App diagnostics recorded both becoming active with three
  visible windows and no crash record; this was a launch-mode defect in the
  evidence procedure, not evidence that the app crashed.

### Acceptance checks and next action

- Await the owner's explicit “done” signal without touching the visible app.
- After the owner finishes, collect the bounded correlated runtime evidence
  and the owner's observed failures/successes, then continue only the failed
  KEELSTONE evidence legs.
- Do not begin another canonical execution key or queued MAS-canon feature
  implementation before the final KEELSTONE verdict is recorded.

## Checkpoint 2026-07-15 — R85 Rich-Epdoc and Lens-Switch Runtime Failure

### Verbatim owner excerpts

> “ok no the issue s that it looks the same as source i want it to look like my
> old rich doc like tolaria whihc is why i asked to clome tolaria is that not a
> better deal becasue rn it just looks ;ike plain md”

> “also they are not swiching surfaces anymore not just a epdoc issue it was
> working bfeore now it wont switch to other surfaces”

### Interpreted owner intent

- Reject the current raw-Markdown Epdoc canvas. Epdoc must again be a visibly
  rich, inline-editable document surface with the polished block behavior the
  owner associates with Tolaria; Source remains the raw MarkEdit/CodeMirror
  lens.
- Treat the inability to switch among editor surfaces as a separate
  release-blocking regression, not as part of subjective Epdoc styling.
- Preserve Epistemos window chrome, toolbar, title/info controls, palette, and
  Matrix/Chonky/Greetings font ownership while replacing the Epdoc canvas.
- Preserve Markdown on disk as the sole durable authority and keep every lens
  synchronized without a lossy JSON mirror becoming canonical.

### Current contradiction and external-source check

- R84 deterministic tests passed, but owner-visible R85 runtime evidence
  falsifies the current acceptance claim: the Epdoc canvas is raw Markdown and
  the visible lens controls no longer switch reliably. Test coverage is
  therefore insufficient for the real product behavior.
- Tolaria's current public repository identifies its editor as BlockNote for
  rich notes and CodeMirror for raw editing. That validates the owner's
  requested rich/raw split and shows that using raw CodeMirror for both
  Epdoc and Source selected the wrong Tolaria lane.
- Tolaria is AGPL-3.0-or-later and cannot be copied into the current Epistemos
  distribution without accepting that license's source obligations. Its code
  remains behavioral research only.
- BlockNote's non-XL core is MPL-2.0 and is intended for commercial and
  closed-source embedding; GPL-licensed `@blocknote/xl-*` packages remain
  excluded. A clean Epistemos-owned BlockNote integration is a viable
  candidate, not permission to copy Tolaria's AGPL components or branding.

### Hard constraints and non-goals

- Do not rename the raw Source canvas to Epdoc or disguise Source through CSS.
- Do not restore the old Tiptap renderer merely by flipping the rollback enum
  unless current source and performance evidence proves that it satisfies the
  rich, large-document, save, and switching done bar.
- Do not copy Tolaria AGPL source, system prompts, trademarks, app shell, or
  runtime subprocess architecture.
- Do not add paid/AI/June/Browser/Research Hub behavior to Free V1.
- Do not stop or interact with the owner's visible R85 app until the owner
  finishes testing or a mandatory new-build boundary is reached and clearly
  communicated.

### Acceptance checks and exact next action

- Map the visible lens state owner, dirty-flush path, and mount/unmount
  contracts; add a fail-first test for visible switching away from a dirty
  Epdoc and for repeated Epdoc/Source/Prose/Preview switching.
- Compare the current legacy Tiptap bridge with BlockNote's official rich
  editor and Tolaria's documented BlockNote/raw split. Select the smallest
  architecture that delivers a real rich Epdoc without restoring the old
  performance/data-loss topology.
- Build the rich canvas behind the existing Epistemos chrome and Markdown
  durability contracts, then prove small and KEELSTONE-scale typing,
  backspace, scroll, save, switch, reopen, and exact Markdown round trip.
- Do not accept the replacement until owner-visible runtime evidence shows a
  visually distinct rich Epdoc and working surface controls.

## Checkpoint 2026-07-15 — Preserve Prose, One Markdown Authority, Literal MarkEdit Source

### Verbatim owner excerpts

> “no do not conslidate prose and do nto make the soruce a diff md source”

> “but what should i use that is muhc more roust thatn my old epdoc tiptap.
> please deliberate.”

> “i wnat the literal mark edit on my source ... i wnat the literal makredit to
> be soruce but with my palette maeaning my colo that is all”

> “i must want to keep my toolbar becasue it is native and works wit all my
> surfaces ... all but color and toolbar”

> “what about a json native editor could that be better ... im justasking”

> “i msyng decoupl epdoc from the rest so epdoc becaomes jsut json”

### Interpreted owner intent

- Preserve Prose as an independent first-class editor surface. No Prose
  consolidation, removal, or silent replacement is authorized.
- Source, Prose, and Preview must continue to address one canonical Markdown
  document. Source must not use a forked copy, second Markdown file, JSON
  authority, or alternate persistence format.
- The owner's newest steer explicitly removes Epdoc from that Markdown lens
  family. Epdoc becomes a separate JSON-native rich document type with one JSON
  authority; it does not continuously mirror or round-trip the Markdown file.
- Source is not a MarkEdit-inspired reskin. It must embed the actual vendored
  MarkEdit/CoreEditor implementation and preserve MarkEdit's nuanced editing,
  layout, selection, scrolling, and native behavior. The Source canvas may
  differ from upstream MarkEdit only through the Epistemos palette/theme bridge
  and the owner's existing native shared Epistemos toolbar. Do not import
  MarkEdit's app toolbar and do not replace, restyle, or fork the owner's native
  toolbar. In this checkpoint, “chrome” means only that retained native shared
  toolbar/window control layer; it is not permission for another custom editor
  wrapper or approximation.
- Select the Epdoc replacement by architecture evidence, not by resemblance.
  It must be materially more robust than the retired Tiptap bridge for large
  documents and exact Markdown fidelity while remaining visibly rich.

### Current evidence and constraints

- The vendored `LocalPackages/MarkEdit` donor carries an MIT license. MarkEdit
  is not the App Store licensing blocker; Tolaria's AGPL license is the
  clean-room restriction that was previously discussed.
- BlockNote produces the closest prebuilt Tolaria-like block UI, but its
  official Markdown import/export is explicitly lossy and its durable format
  is BlockNote JSON. That contradicts the owner's one-Markdown-authority lock.
- Lexical is a strong MIT rich-editor framework, but its native editor state is
  structured/JSON-first and Markdown behavior is plugin-provided. It would
  recreate a second-authority/round-trip problem.
- Milkdown is MIT and Markdown-oriented, but it remains ProseMirror-based and
  therefore does not by itself remove the old whole-document DOM/tree and
  serialization risk that failed under KEELSTONE-scale content.
- CodeMirror 6 keeps Markdown text as the editor state, incrementally reparses
  it, maps decorations through edits, and renders only the visible viewport.
  The existing MarkEdit donor already proves this substrate on large files.
- The earlier rejection of JSON-native Epdoc is superseded by the owner's
  explicit decoupling steer. JSON is now permitted as the sole durable
  authority for an Epdoc document. Markdown import/export and PDF export are
  explicit user operations, never silent continuous synchronization and never
  a second canonical copy.

### Superseding architecture decision pending fail-first proof

- Keep the literal MarkEdit/CoreEditor as Markdown Source.
- Replace Epdoc with an Epistemos-owned Lexical JSON editor rather than
  BlockNote or another Tiptap/ProseMirror layer. Lexical is the preferred
  candidate because it is MIT, JSON-native, independent of the failed Tiptap
  bridge, and provides extensible rich nodes without requiring Markdown
  round-trip authority.
- Epdoc must provide native-feeling checklists, tables, images, audio, drawings,
  PDF/object embeds, rich typography, and structured blocks through explicit
  Lexical nodes and an Epistemos-owned schema/version migrator.
- Prose remains its existing independent TextKit editor and participates in the
  current one-writer/flush contract against the same Markdown file as Source
  and Preview. It is not consolidated into Epdoc.
- The legacy Tiptap canvas remains rollback evidence only until the new Epdoc
  passes exact small/large typing, backspace, scroll, JSON save, reopen, schema
  migration, import/export, and object-node tests.

### Done bar and next action

- Prove the visible switching regression red before repair, then dispatch
  flushing by the actually active surface so a dirty Document does not
  incorrectly require Source's live-text registry.
- Compare the vendored MarkEdit snapshot with its exact upstream revision and
  remove Epistemos Source deviations that are not the palette/theme bridge or
  explicitly retained host chrome.
- Land the first visibly rich Lexical Epdoc slice with a versioned JSON schema;
  do not present another raw Markdown canvas as Epdoc and do not create an
  automatic Markdown sidecar.
- Verify Source is recognizably and behaviorally MarkEdit, Prose remains
  available, Source/Prose/Preview address one Markdown file, and Epdoc owns one
  independent JSON document. Verify KEELSTONE-scale Markdown remains editable
  in MarkEdit/Prose without disappearing text, backspace restoration, hangs, or
  lens-switch failure; verify large JSON Epdoc independently.

## Checkpoint 2026-07-15 — JSON-Decoupled Epdoc Steer Withdrawn

### Verbatim owner excerpt

> “but nvm on that please continue”

### Supersession

- Withdraw the immediately preceding proposal to make Epdoc a separate
  JSON-native document type. Do not introduce Lexical, a `.epdoc` JSON
  authority, an automatic JSON sidecar, or a document-type split from this
  withdrawn steer.
- Restore the prior active architecture: Epdoc remains a genuinely rich editor
  profile over the same canonical Markdown document used by Source, Prose, and
  Preview. JSON may be disposable derived cache only.
- Source remains the actual vendored MarkEdit/CoreEditor behavior beneath the
  owner's native shared Epistemos toolbar, with only the Epistemos palette and
  explicitly required Free-V1 capability removals differing from upstream.
- Prose remains an independent surface and must not be consolidated.

### Exact next action

- Continue the fail-first lens-switch repair, the upstream MarkEdit Source
  fidelity audit, and the Markdown-native CodeMirror rich-Epdoc implementation.

## Checkpoint 2026-07-15 — Final Owner Lock: JSON-Native Epdoc Reopened

### Verbatim owner excerpt

> “ok well yea we can do that then lets do json for epdoc”

### Final supersession for this implementation pass

- This newest explicit authorization supersedes the immediately preceding
  withdrawal. Epdoc is again authorized and required to become a separate
  JSON-native rich document surface.
- Use an Epistemos-owned Lexical integration under the existing native shared
  Epistemos toolbar. Do not use Tolaria AGPL source, BlockNote GPL `xl-*`, or
  restore the legacy Tiptap bridge as production Epdoc.
- Source and Prose remain separate editors over one canonical Markdown file.
  Source uses actual vendored MarkEdit/CoreEditor behavior with the Epistemos
  palette. Preview remains a Markdown rendering surface.
- Epdoc owns one versioned JSON document. It does not continuously synchronize
  with the Markdown file and must not create a silent `.md` or JSON sidecar.
  Markdown import/export and PDF export are explicit user actions with clear
  destination/overwrite behavior.
- Existing Markdown notes remain Markdown notes. They must not silently change
  document type when this migration lands.

### Required architecture proof before broad feature work

- Map `SDPage`, vault/export, note routing, file-type detection, recovery draft,
  indexing, and window restoration so JSON Epdoc has one durable authority and
  cannot be mistaken for Markdown bytes.
- Define a versioned Epdoc envelope, schema migration contract, atomic save,
  crash recovery, attachment references, plain-text/index projection, and
  explicit Markdown import/export boundary.
- Add fail-first tests for document-type routing and current Markdown lens
  switching before production edits.
- Land a minimal Lexical JSON vertical slice first: paragraph, headings, inline
  emphasis, lists/checklists, code, links, undo/redo, atomic save/reopen, and
  large-document typing/backspace/scroll. Images, audio, drawings, tables,
  PDFs, calendar/tasks, and other rich nodes follow only after that core is
  proven.

## Checkpoint 2026-07-15 — Epdoc Autosave, Markdown Publish, and PDF Snapshot Boundary

### Verbatim owner excerpt

> “on epdoc i can hae a save button where it saves to md as well hut nver
> should be syncronous. so im thinking when u start from epdoc u cant just save
> over existing md files. i will hve a save feature where it never auto saves u
> just press a button to save as md ... the auto is always json. but it never
> auto saves md it should be exlicit but alwasy manual.”

> “with pdf viewer that maybesnapshots the epdoc and views it in pdf.”

### Interpreted owner intent

- Epdoc autosave persists only the canonical versioned JSON inside its
  `.epdoc` package. No autosave, editor transaction, lens switch, or background
  task may write Markdown or PDF from Epdoc.
- Markdown generation is an explicit user command. Label it **Publish Markdown
  Copy…** or **Export Markdown…**, not ordinary Save, because ordinary Save is
  the canonical JSON document save and macOS autosave remains enabled.
- Publishing creates an independent Markdown note/file. It must never silently
  overwrite an existing `.md`, must use a collision-safe filename, and must
  never establish continuous or bidirectional synchronization with the Epdoc.
- A Markdown copy published into the active vault is a normal Markdown note
  visible in the Notes sidebar. It may use Prose, Preview, and literal MarkEdit
  Source because those surfaces share that published `.md` as their one
  authority. Later edits to the copy do not change the originating Epdoc, and
  later Epdoc edits do not change the copy.
- Preserve provenance in additive Markdown front matter (origin Epdoc ID,
  export timestamp, and schema/export version). Provenance is informational;
  it does not grant write-through authority.
- PDF is an explicit rendered snapshot/preview and export of canonical Epdoc
  JSON. It is never canonical document state and never participates in editor
  autosave or Markdown lens switching.

### Product defaults and constraints

- Default vault destination: a visible `Epdoc Exports/Markdown` folder so the
  resulting note is easy to find and not confused with the `.epdoc` package.
  A later destination picker may override this explicitly.
- Default collision behavior: generate a unique filename. Replacing an
  existing Markdown file requires a separate explicit confirmation path and is
  not part of the initial vertical slice.
- Markdown is a potentially lossy projection of rich JSON. The publish action
  must report unsupported/degraded block types rather than implying exact rich
  round-trip fidelity. Embedded assets use stable exported references or an
  adjacent asset directory; they are never silently discarded.
- Do not add a protected or coupled Markdown subtype. Once published, the
  result is ordinary Markdown by design. The source Epdoc remains protected by
  separation and the absence of any reverse-sync path.

### Acceptance checks and exact next action

- Keep this publish/export behavior behind the JSON schema/storage vertical
  slice; do not let it expand the first implementation batch.
- Add tests proving Epdoc autosave writes JSON only, Markdown publishing is
  manual and collision-safe, the published note is independently routable to
  Prose/Preview/Source, and later edits do not cross either direction.
- Add PDF snapshot tests only after the JSON editor and deterministic renderer
  are stable. Until then, preserve the command contract without presenting a
  completed PDF surface.
- Continue first with the fail-first active-surface flush repair and exact
  `.epdoc` package/schema mapping.

## Checkpoint 2026-07-15 — Large-Epdoc Engine Selection Must Prove the 67K Fixture

### Verbatim owner excerpt

> “i like that plan ok continue fid. teh best editor for epdoc that will not
> run into the same 67k word issue”

### Interpreted owner intent

- The JSON-Epdoc and explicit Markdown/PDF publication boundary is approved.
- Do not select an editor engine from visual resemblance or framework claims.
  The production engine must prove that the owner's KEELSTONE-scale roughly
  67,000-word document can open, type, backspace, select, scroll, undo/redo,
  autosave JSON, close, and reopen without the hangs, restored deletions,
  invisible text, viewport jumps, or surface-lock failures seen in the former
  Markdown-mirrored Epdoc.
- Richness remains required: the performance solution cannot collapse Epdoc
  back into raw Markdown or a plain textarea.

### Engine decision gate

- Keep Lexical as the leading lightweight JSON-state candidate, but do not
  promote it solely from its general “fast” claim. Compare it against the
  strongest permissive JSON-rich alternative with explicit large-document
  evidence (currently Plate/Slate with chunked rendering) using the same
  local fixture and plugin set.
- Required measurements: cold mount, first editable frame, p50/p95 keydown to
  rendered text, backspace correctness, continuous scroll frame stalls,
  selection/cursor stability, undo/redo, JSON serialization time and bytes,
  Swift↔WKWebView bridge traffic, autosave latency, memory peak/steady state,
  close/teardown, and exact reopen digest.
- The production architecture must not serialize or send the entire document
  across the bridge per keystroke. Ordinary edits publish bounded transaction
  metadata immediately and a coalesced canonical JSON checkpoint only at the
  durable-save boundary. Derived Markdown, PDF, plain text, graph, and search
  projections run outside the typing hot path.
- If neither candidate meets the acceptance budget with the full fixture, stop
  promotion and implement block-windowing/chunked rendering behind the same
  versioned Epdoc schema before adding rich-media features.

### Exact next action

- Continue the independent active-surface flush repair while the engine
  evidence bakeoff is researched. Do not wire a new production JS engine until
  the bakeoff contract and package migration path are explicit.

## Checkpoint 2026-07-15 — Epdoc Requires Viewport/Chunked Rich Rendering

### Verbatim owner excerpt

> “can i not get the same viewport thing like prose editor and codemirro”

### Interpreted owner intent and hard constraint

- Yes: the production Epdoc editor must keep the complete canonical JSON model
  while mounting/laying out only the visible block window plus bounded
  overscan. The active selection, composition/IME block, drag target, find
  match, and enough neighboring context for stable cursor movement must remain
  mounted.
- This is a real rendering architecture requirement, not a debounce or CSS
  optimization. A hidden full-document DOM does not satisfy it.
- Preserve stable block IDs and viewport anchors across chunk mount/unmount so
  scroll position, selection, undo/redo, backlinks, object-node identity, and
  accessibility do not jump or disappear.
- The engine bakeoff must prefer a candidate with maintained, reproducible
  chunked/viewport rendering over an otherwise attractive editor that requires
  a speculative virtualization layer. Naively unmounting contenteditable nodes
  is forbidden because it can invalidate browser selection and IME state.

### Acceptance checks

- The KEELSTONE fixture must demonstrate bounded mounted block/DOM counts while
  scrolling from beginning to middle to end.
- Type, backspace, multi-block selection, shift-selection across a chunk
  boundary, find-next, undo/redo, drag/reorder, and VoiceOver traversal must not
  lose content or jump the viewport.
- Memory and key-to-paint latency must be measured with chunking enabled and
  compared with an unchunked falsifier baseline.

## Checkpoint 2026-07-15 — Native TextKit 2 Viewport Selected for Epdoc

### Owner steer being resolved

> “can i not get the same viewport thing like prose editor and codemirro”

### Current-source and primary-source finding

- Yes. The current Prose implementation already constructs a real TextKit 2
  stack through `NSTextContentStorage`, `NSTextLayoutManager`, and an
  `NSTextView` created against that stack.
- Apple's `NSTextViewportLayoutController` contract defines the viewport as
  the visible area plus overscroll and lays out text fragments in that active
  area. Apple's TextKit 2 guidance states that its layout is always
  noncontiguous and is designed to scroll documents hundreds of megabytes in
  size at interactive rates when callers avoid forcing off-viewport layout.
- Slate/Plate remains a useful benchmark falsifier, but its documented
  chunking is experimental and primarily separately memoizes React chunks;
  `content-visibility` suppresses offscreen painting without guaranteeing a
  CodeMirror/TextKit-style unmounted or non-laid-out document viewport. It
  therefore does not satisfy the owner's strict viewport requirement as
  directly as TextKit 2.

Primary references:

- `https://developer.apple.com/documentation/appkit/nstextviewportlayoutcontroller`
- `https://developer.apple.com/videos/play/wwdc2021/10061/`
- `https://docs.slatejs.org/walkthroughs/09-performance`
- `https://platejs.org/docs/performance`

### Architecture decision

- Use a **distinct native TextKit 2 Epdoc editor** as the leading production
  engine. This shares a lower-level viewport/layout substrate with Prose but
  does not consolidate the surfaces, storage, commands, or appearance.
- Prose remains a Markdown editor over the canonical `.md`. Source remains
  vendored MarkEdit/CodeMirror over that same `.md`. Preview remains the
  Markdown renderer. Epdoc remains a separate `.epdoc` NSDocument whose sole
  canonical authority is versioned Epistemos rich JSON.
- Epdoc must not reuse Prose's Markdown parser or Markdown autosave pipeline.
  It will map canonical rich blocks and inline marks to TextKit 2 text
  elements, attributes, attachments, and custom layout fragments. Ordinary
  edits update only the affected block transaction; full canonical JSON is
  encoded at coalesced NSDocument autosave/explicit save boundaries.
- Reuse proven non-product substrate only where ownership is clean: TextKit 2
  stack creation, viewport discipline, Epistemos palette/font resolution,
  input/selection/accessibility handling, and bounded image loading. Keep an
  Epdoc-specific view/coordinator, JSON adapter, undo model, attachment node
  registry, toolbar command surface, and performance harness.
- Rich object blocks such as checklists, images, audio, drawings, tables,
  calendar/task links, and PDF embeds must remain stable JSON nodes with
  package asset references. TextKit attachments or custom layout fragments are
  views of those nodes, never canonical serialized UI objects.

### Hard performance constraints

- Never request full-document layout to answer ordinary scroll, selection,
  toolbar, status, or typing events.
- Never rebuild an attributed document or encode/transmit the complete JSON
  tree per keystroke. Maintain stable block IDs and update the affected block
  plus bounded neighbors.
- Preserve insertion point, IME marked text, multi-block selection, undo/redo,
  find, accessibility, and scroll anchors across viewport relocation.
- The exact Keelstone fixture and a 2x generated rich-JSON fixture must prove
  load, edit, backspace, scroll, select, undo/redo, autosave, teardown, and
  byte/digest-stable reopen before this engine is promoted.

### Exact next action

- Land the versioned engine-neutral Epdoc rich-block envelope and legacy
  `content.pm.json` migration receipt contract first. Then add a minimal native
  TextKit 2 JSON editor vertical slice for paragraphs, headings, inline marks,
  lists/checklists, code, links, undo/redo, atomic save/reopen, and viewport
  instrumentation. Keep Plate/Slate as the same-fixture falsifier rather than
  the production default.

## Checkpoint 2026-07-15 — Continue Canon in Recorded Order Without Narrowing Keelstone

### Verbatim owner excerpt

> “do not notify me just start it all please and finihs it all. after whatever
> keelstoen needs do makredit and then what ever isafter keelsteon like
> lumenless and then beyond until all of the canon prompts are done idk if sync
> was part of mas canon but that is the plan lease cotninue do not stop please.”

### Interpreted intent

- Continue autonomously from the exact Keelstone evidence boundary. Do not
  redefine completion around the native viewport foundation or stop after one
  green test batch.
- Finish Keelstone's remaining editor semantics and exact runtime/release
  evidence first. Then complete the literal vendored MarkEdit Source surface,
  resume LumenLens, and follow the MAS canon's recorded execution-key order.
- Sync is included only if current MAS canon promotes it; do not infer its
  position from memory or reopen parked June/Pro runtime lanes.

### Hard constraints and non-goals

- Preserve the Markdown family boundary: one `.md` shared by Prose, Preview,
  and Source. Standalone Epdoc remains versioned JSON and never background
  syncs with Markdown.
- Preserve the Free V1 boundary, native toolbar, Epistemos palette/fonts,
  one-current-build rule, resource preflight, and evidence-sized claims.
- Do not skip Keelstone debt to create the appearance of progress elsewhere.
  Do not start a later execution key while the current key remains red or
  incomplete.
- Do not use the old CodeMirror-Epdoc bridge as the native Epdoc architecture;
  CodeMirror remains relevant to the Markdown Source surface only.

### Acceptance checks

- Native Epdoc selection across blocks/viewports, IME and Unicode editing,
  undo/redo, structural split/merge identity, rich-node projection, package
  save/close/reopen, and owner-visible large-document behavior have exact
  evidence.
- Keelstone Release/archive gates pass against exactly one fresh artifact
  before a final verdict or later execution key begins.
- The handoff/canon ledger names the exact next execution key after Keelstone;
  MarkEdit, LumenLens, sync, and later prompt work follow that authority rather
  than conversational recollection.

### Contradictions and current evidence

- R92 proves one generated 67.5k-word TextKit 2 viewport/edit/backspace/
  checkpoint/reopen path and 206 green tests. It does not prove the broader
  selection, IME, undo, rich-object, document lifecycle, visual, or Release
  claims above.
- The current Debug app is open for owner inspection. Do not rebuild or delete
  it while that inspection is active.

### Exact next action

- Add the next fail-first native AppKit semantics batch for multi-block
  selection, Unicode/marked-text safety, undo/redo, and split/merge stable IDs
  while preserving the bounded TextKit 2 viewport. Keep verification debt
  recorded until the current inspection app can be retired and the next
  resource-preflight/one-build leg can run.

## Checkpoint 2026-07-15 — Owner Finished R92 Inspection

### Verbatim owner excerpt

> “im done testimg it so u can do what u need to do”

### Interpreted intent

- The owner-visible R92 inspection window is complete. The retained R92 Debug
  app no longer needs to remain open or preserved as the current runnable
  product.
- Resume the recorded Keelstone verification boundary: retire the R92 process
  and stale product, then run exactly one clean serial R93 App Store test leg
  if and only if the current resource preflight is green.

### Hard constraints and acceptance checks

- Preserve R92 logs and `.xcresult` evidence while removing only its stale app
  product/DerivedData build location.
- Before Xcode, record branch, HEAD, dirty-entry count, swap, free-memory
  percentage, throttled pages, disk, and competing Epistemos/Xcode/compiler/
  model processes.
- Require swap below 16 GiB, at least 25% free memory, zero pages throttled,
  and no competing process. Stop without building if any retained condition is
  red.
- R93 remains unproven until its fresh log and result bundle complete with no
  failures; do not attribute current source behavior to R92.

### Exact next action

- Record the preflight, stop retained R92 PID `4450` if still present, remove
  only stale Epistemos build products, repeat the decisive process/resource
  check, and begin one clean serial R93 test build only on a green verdict.

## Checkpoint 2026-07-15 — R92 Was Not an Epdoc Inspection

### Verbatim owner excerpt

> “i also have not tested the epdoc becasue i didnt see it but i guess i was
> using a stale build”

### Interpreted intent

- Do not count the earlier owner interaction with the retained R92 Debug app as
  owner-visible Epdoc evidence. The owner did not unmistakably reach or
  identify the standalone `.epdoc` rich-document surface.
- Finish the fresh native Epdoc test/evidence chain before presenting another
  app for inspection. The next retained runnable product must have one exact
  path and an explicit `.epdoc` creation/open route so Source/Markdown cannot
  be mistaken for Epdoc.

### Hard constraints and acceptance checks

- Preserve the standalone boundary: `.epdoc` is canonical versioned JSON;
  Markdown Source, Prose, and Preview remain the separate shared `.md` family.
- Do not claim owner-visible Epdoc behavior from R92. Do not label a failed or
  stale test product as the current inspection app.
- A future inspection handoff must name the exact fresh app artifact, exact
  document kind, and an unmistakable visible check for the rich Epdoc surface.

### Contradictions and current evidence

- R92's automated 72,000-word TextKit 2 viewport evidence remains valid for
  its exact automated fixture, but its retained app session supplies no owner
  Epdoc evidence.
- R94 compiled the corrected native list/table code but its test run is red:
  220 tests executed with 11 issues across cross-block replacement, Unicode/
  IME reconciliation, and inline-attachment preservation. Its partial app is
  not an inspection artifact and has been removed.

### Exact next action

- Retain and hash R94's failed log/result bundle, record the exact assertions,
  repair only the three native reconciliation seams, then perform a new
  resource preflight and one clean serial App Store test retry. Present a
  runnable Epdoc app only after that leg is green.

## Checkpoint 2026-07-15 — Preserve and Repair the Full Epdoc Toolbar

### Verbatim owner excerpts

> “also the tooolbar is outdated i wnat the toolbar to still work incldung
> thigns lkee the margin slider and such.”

> “also the toolbar is not workign correctly select on thign for header makes
> the whole doc a header so please ipdate it all harden and audit it please.”

### Interpreted intent

- The native TextKit 2 Epdoc replacement must retain the useful full Epdoc
  toolbar, including the document margin/content-width slider and existing
  applicable formatting controls. A minimal overflow-only or stale toolbar is
  not an acceptable replacement.
- Formatting commands must act on the exact selected block or selected block
  set. Choosing a heading style for one selection must never convert the whole
  document or unrelated blocks.
- Audit and harden the toolbar end to end: visible composition, command
  dispatch, native selection-to-canonical-block mapping, undo/redo, persisted
  JSON, and reopen behavior.

### Hard constraints and non-goals

- Keep the native shared toolbar concept and Epistemos palette/fonts. Do not
  restore the retired Tiptap/ProseMirror runtime or couple Epdoc back to
  Markdown surfaces.
- Preserve the bounded TextKit 2 viewport and standalone `.epdoc` JSON
  authority while repairing toolbar behavior.
- Keep useful controls such as margin/content width; remove or hide only
  controls whose underlying capability is canonically parked or unavailable
  in Free V1.

### Acceptance checks

- The live Epdoc window visibly exposes the current intended formatting and
  margin controls without relying on a stale toolbar implementation.
- A collapsed caret, partial selection, one-block selection, and multi-block
  selection each resolve deterministically to the intended canonical block
  IDs; unrelated blocks remain byte-equivalent.
- Heading/paragraph changes, inline marks, undo/redo, save, close, and reopen
  preserve the exact intended block set and JSON structure.
- Margin changes affect only presentation/layout, remain responsive on large
  documents, and never mutate canonical content JSON.

### Current evidence and exact next action

- R96 automated tests are green (220 tests, 5 suites), but the fresh runtime
  window shows only an overflow toolbar in its current width and supplies no
  proof for the complete toolbar or margin control. The owner reports a
  heading command can style the whole document. This supersedes any implied
  toolbar-completion claim.
- Keep the exact R96 app/package as current runtime evidence while reading the
  toolbar controller/view, selection helpers, call sites, tests, and local
  canon. Add fail-first selection-scope and margin-presentation tests before
  the surgical implementation. Do not begin Release/archive or MarkEdit work
  until this Keelstone toolbar leg is green and visibly checked.

## Checkpoint 2026-07-15 — Surface-Specific Toolbar Density and Stable Margins

### Verbatim owner excerpt

> “the toolbar ca just work on epdoc and maybe the soruyce and orose can have a
> simplfied toolbar please that has esssential thigns on it plus the slider i
> want prose to have the sldier as well and have it be normal by default rn it
> often gltiches and snaps to a margin randomly the prose does. and the epdoc is
> all o the right side so issues around these. things. and again the prose and
> soruce shoudl have a more simplfoied toolbar not as large and sdense as epdoc”

### Interpreted intent

- Do not force one dense toolbar across every editor. Epdoc owns the complete
  rich-document toolbar. Prose and Source each use a smaller essential toolbar
  appropriate to Markdown editing.
- The margin/content-width slider is a cross-editor essential: retain it for
  Epdoc, Prose, and Source even when the Markdown toolbars are simplified.
- Prose must open at a normal centered default width and stop snapping or
  glitching to arbitrary margins. Epdoc must also be centered and must not
  render its document body against the right edge.

### Hard constraints and non-goals

- Keep the existing surface boundaries and native shared toolbar integration;
  use surface-specific item sets and state rather than duplicating unrelated
  editor runtimes.
- Margin/width is presentation state only. It must not enter Markdown or Epdoc
  canonical content, change selection scope, or trigger full-document content
  rewrites.
- Source/Prose simplification must not remove essential Save, find/navigation,
  surface identity, or margin controls. Epdoc density must not spill into
  Source/Prose.

### Acceptance checks

- Epdoc shows its full intended controls and a working width slider; Prose and
  Source show visibly smaller essential control sets with their own working
  width slider.
- New Prose and Epdoc windows use a deterministic normal centered width.
  Window resize, surface switching, tab switching, selection changes, and
  editing do not jump, snap, right-align, or silently change the width.
- Width state is scoped intentionally (document/window/surface as current canon
  requires), has one owner, persists only where intended, and never causes
  feedback loops between SwiftUI toolbar state and AppKit text-container
  geometry.

### Exact next action

- Extend the active toolbar audit to cover all three surfaces, the width-state
  owner and defaults, toolbar item composition, text-container insets, frame/
  alignment calculations, resize observers, tab/surface switching, and tests.
  Add fail-first centered-default, no-snap, stable-resize/switch, and
  surface-specific-density coverage before implementation.

## Checkpoint 2026-07-15 — Source Wrap Toggle, Discoverable Epdoc, and Graph Navigation

### Verbatim owner excerpts

> “i dont see epdoc short cut or anything”

> “also the margi slier does ot work for source so please get rid of it on
> source. also i wanted the sourc liners to be like markedit when there is a
> always presetn margen that makes t4he line becomes two lines wehe the wi dows
> is a certainszie please actually look at the code of markedit and see how
> they do it i wnat it to be like that”

> “also the epdoc does not have a graph surface i wnat to be able to nav to a
> epdoc n the graph both embedded graph and hte hoogram grah”

> “so bsasiclly therte is not sldier at the bottom on markedi t because
> everythign u need is alway there”

> “i thik a better thg is actualyl a toggle that turns that on and off so a
> atoggle that allows oe line to be multi line which is the markedit ontolgoy
> and then a toggle that forces everytign to be one line. i like that”

### Interpreted intent

- Source must stop presenting the nonfunctional content-width/margin slider.
  Replace that Source-only control with one clear wrapping toggle.
- Wrapping is enabled by default and uses the actual vendored MarkEdit/
  CodeMirror line-wrapping behavior: one logical line may occupy multiple
  visual rows as the window narrows, with the gutter and active-line geometry
  remaining stable.
- With wrapping disabled, each logical line remains one visual row and the
  editor scrolls horizontally. This is a presentation preference only; it
  must never rewrite Markdown, change line numbers, or disturb selection.
- Epdoc creation must be discoverable from the home surface and have an
  intentional keyboard shortcut in addition to File > New Epdoc Document.
- A saved `.epdoc` must be a first-class node in both the embedded graph and
  the hologram graph. Activating it must open the actual Epdoc package through
  the native Epdoc document route, not a Markdown substitute, stale projection,
  or dead preview.

### Hard constraints and non-goals

- This checkpoint supersedes the earlier request for a Source width slider
  only. Prose and Epdoc retain their separately owned width controls and
  centering requirements.
- Use the existing MIT-vendored MarkEdit bridge and its `lineWrapping`
  compartment. Do not approximate the behavior with arbitrary pixel-width
  presets, document rewrites, or a second editor runtime.
- Preserve the shared native toolbar, Epistemos palette, Source typography,
  line numbers, title popover, and Markdown Source/Prose/Preview family.
- Preserve standalone `.epdoc` JSON authority. Graph navigation may project
  metadata for indexing, but it must open the real package and must not couple
  Epdoc back to Markdown auto-save or surface switching.
- Stay within Free V1/MAS-only boundaries; do not expose, compile, or revive
  June, chat, provider, browser, research-hub, code-execution, or parked lanes.

### Acceptance checks

- Source visibly has a wrapping toggle and no margin/content-width slider.
  Toggle on wraps a long logical line responsively; toggle off keeps it on one
  visual row with horizontal scrolling. Repeated resize, edit, undo/redo,
  surface switching, save, and reopen do not jump, hide, duplicate, or mutate
  text.
- The wrapping preference has one owner, a deterministic default, and a
  tested bridge call into MarkEdit's existing line-wrapping compartment.
- Home visibly offers New Epdoc Document; its keyboard shortcut is unique,
  shown in the menu, and invokes the same creation path as the File command.
- A saved Epdoc is represented in both graph surfaces with stable identity;
  click/double-click navigation opens the native `.epdoc` document. Missing or
  moved packages fail honestly rather than opening unrelated content.
- Current-source tests and a fresh, isolated one-artifact runtime pass supply
  exact evidence before any claim that these behaviors work.

### Contradictions, current evidence, and next action

- The retained R109 app proves that File > New Epdoc Document exists, but its
  home surface has no Epdoc shortcut and the File menu shows no keyboard
  equivalent. Source still exposes `Source width`, contrary to this steer.
- Current source contains Epdoc graph persistence, projection, preview, and
  open helpers, but the R109 runtime pass did not exercise either embedded or
  hologram Epdoc navigation. Presence is not runtime proof.
- Read the exact home-command, Source-toolbar/MarkEdit bridge, Epdoc graph
  projection/opening, and nearby test contracts. Add fail-first behavioral
  coverage, make only the surgical correction, inspect the diff, then perform
  the required serial resource-preflight/test/build/runtime chain.

## Checkpoint 2026-07-15 — Restore Native Landing Commands and Format-Explicit Names

### Verbatim owner excerpt

> “one more thing i wnat to add as a 4th owner directive rn. A rlly long time
> ago my shrotcuts on landig page was reglar font, had the acutaly command hints
> and were like native buttons so wehen u hover they have that liquid glass look
> i want to readd that verbatim like th shortcuts underwent lots of changes but
> ther was one time for a rlly long time the shrotcuts were native thigns that
> weh nu hover it gave th4 liqudi glsass look it had hits. i wnat to have that
> look again. and i want to name the note to markdown and the doc can be named
> JSON document. something like that. or it can be .md and the doc can be .JSON
> somethign like that so that is the 4th thing please let me know that u
> understand the old look.”

### Interpreted intent

- Restore the earlier Landing command implementation itself, as identified in
  repository history: native macOS buttons, regular system typography, real
  keyboard-command hints, and the native liquid-glass hover response. A pixel
  tile with merely similar colors, hover opacity, or a glass-looking wrapper is
  not sufficient.
- Preserve the current Free V1 command set and current actions while restoring
  that native presentation and interaction grammar.
- Rename the Markdown creation command so its file authority is explicit
  (`Markdown`/`.md`) and rename the standalone Epdoc creation command so its
  JSON authority is explicit (`JSON document`/`.JSON`). Final visible wording
  should be short, legible, and consistent across Landing, accessibility,
  read-aloud copy, and the File menu without conflating the two formats.

### Hard constraints and non-goals

- Recover the exact prior implementation from Git history before editing; do
  not invent an approximation from memory.
- Keep the Epistemos palette, current command destinations, MAS-only Free V1
  feature boundaries, keyboard accessibility, reduced-motion behavior, and
  visible shortcut chords.
- A label change must not change the underlying file formats: Markdown remains
  `.md`; Epdoc remains the standalone canonical `.epdoc` JSON package and must
  not become a generic loose `.json` file.

### Acceptance checks

- Landing commands use regular native/system typography and native button
  semantics, expose the correct command-key hints, and show the prior
  liquid-glass hover/focus treatment on supported macOS versions with an
  accessible fallback.
- The Markdown and Epdoc/JSON commands are unambiguous by sight, VoiceOver,
  read-aloud output, and tooltip/help text; each invokes only its canonical
  creation route.
- Keyboard shortcuts remain unique, visible, and dispatch exactly once.
- Hovering, resizing, keyboard focus, reduced motion, light/dark mode, and
  repeated navigation do not jump, shift, leak animation work, or lose labels.

### Exact next action

- Trace `LandingView` and the Landing command component through Git history to
  identify the owner-recognized native implementation and exact hover/button
  APIs. Fold those exact findings into the existing fail-first Home/Epdoc test
  batch before any production edit.

## Checkpoint 2026-07-15 — Format-Explicit Notes Sidebar and Batched Verification

### Verbatim owner excerpt

> “also the notes sidebar needs to have tha verbiage as well .md and .json so
> it dos not cofnuse users. and can u make the changes faster please and build
> after its all done yuo have been buildign alot wastign time do i in batches”

### Interpreted intent

- Carry the same format distinction into the Notes sidebar: ordinary notes are
  identified as Markdown (`.md`), while standalone rich documents are
  identified as JSON-backed Epdoc packages (`.epdoc`).
- Keep implementation moving as one coherent correction batch. Do not launch
  repeated intermediate app builds; perform the next build only after the
  Source, Landing, sidebar, Epdoc, and graph changes are integrated.

### Hard constraints and non-goals

- Do not lie about the on-disk extension. Epdoc's canonical content is JSON,
  but the user-facing document is a `.epdoc` package rather than a loose
  `.json` file. The sidebar wording must communicate both facts.
- Do not rename existing user files, migrate package bytes, or merge Markdown
  and Epdoc authority merely to change labels.
- Preserve the one-current-build rule and mandatory resource preflight. Batching
  reduces redundant builds; it does not permit an unverified completion claim.

### Acceptance checks and exact next action

- The Notes sidebar visibly distinguishes `Markdown (.md)` from
  `JSON Documents (.epdoc)` without changing either open route.
- Accessibility labels and help text expose the same distinction.
- Stop the still-running pre-change fail-first compile, implement the complete
  correction batch, then perform one fresh isolated verification build/test
  leg after the required resource preflight.

## Checkpoint 2026-07-15 — Notes Home/Multitask Routing and Two Explicit Graph Destinations

### Verbatim owner excerpt

> “on the sidebar i wnat ther to be two modes home and multi task. home is like
> this: i seelct a note on notessidebar either json md code etc. any of the
> files and that immediately blur revelas the note on the home windwo and the
> other mutli task is the default mode that just operates how it alwasy has. i
> want to do that. the toggle should be at the top vissible sothe user can
> easily see it. also the default graph should eb the embedded home one not the
> hologram one. get rid of the facelesss graph sesciont compeltly so in
> thesettignsa there is an xperimental version that has a third graph view iwht
> no border please delete that and make the default for the user when they frist
> set up the app to be the home embedded gaph they can always go and set it to
> the hologram one. make sure there are hitns for the comamnd for ntoes sidebar
> because since it is ot always presetn i wna there to be a hint in many places
> for the user. als othe nortes sidebar should also have a graph button that
> opens the home embedded graph. or it can be a multi tasked graph and the multi
> tasked graph will be the hollogram graph but existsi the note workspace
> mutlit task tabs thing so pelase read this back to me so u understand what i
> wat. so nvm the defalt graph thong i want the graph to have two seelctons the
> user can access on home and on notes sidebar when hove over grph on landing
> page it should expad to both the mutlit task graph hologram and the embedded
> home one and the notes sidebar should have that as well.”

### Interpreted intent

- Put a visible two-mode routing control at the top of the Notes sidebar.
  `Multitask` is the default and preserves current page/document opening.
  `Home` routes any supported sidebar file selection to an immediate Home-window
  reveal using the existing blur transition grammar.
- Replace implicit single graph-location dispatch with two explicit choices on
  both Landing and the Notes sidebar: `Home Graph` for the embedded Home graph,
  and `Multitask Graph` for the hologram graph hosted in the Notes multitask/tab
  workspace.
- Remove the experimental third borderless/faceless graph presentation from
  Settings and supported selection state.
- Make the Notes sidebar keyboard command discoverable in multiple appropriate
  native surfaces because the sidebar is not continuously visible.

### Supersession and constraints

- The closing “never mind the default graph thing” supersedes the earlier
  request in the same steer to force the embedded graph as the new-user default.
  The final contract is explicit destination choice, not a silent default flip.
- `Multitask` remains the default Notes routing mode. Home routing must not
  mutate file authority, duplicate documents, or silently save Epdoc JSON into
  Markdown.
- Preserve the existing canonical open routes for Markdown, Epdoc, code, and
  HTML workspace documents; only their presentation destination changes.
- Exactly two graph choices may remain visible. No experimental borderless
  third choice, hidden duplicate settings row, or stale persisted value may
  leave the UI in an unsupported state.

### Acceptance checks and next action

- The Notes sidebar top control visibly shows Home and Multitask, defaults to
  Multitask, persists intentionally, and routes every supported row through one
  centralized destination policy.
- Home mode reveals the selected content in Home with a stable blur transition;
  Multitask mode behaves as before.
- Landing Graph hover and the Notes sidebar Graph control both expose Home Graph
  and Multitask Graph, and each reaches its named host exactly once.
- Settings exposes exactly those two graph destinations; legacy third-mode
  preferences migrate to a supported value.
- Trace the current sidebar action router, Home content routes, graph location
  enum/settings, hologram host, tab host, command/menu hints, and existing blur
  transition before adding fail-first contracts or editing production.

### Verification-debt update

- The first R112 command exited before compilation because `EpistemosTests` is
  not a member of the `Epistemos-AppStore` scheme. It produced no app artifact.
  The next verification leg must use only scheme-member tests in the single
  fresh App Store build; non-member source tests remain deferred to their own
  valid scheme rather than being smuggled into repeated builds.

## Checkpoint 2026-07-15 — Epdoc Save Truth, Performance Parity, and Editor Title Reveal

### Verbatim owner excerpts

> “also epdoc has a save button is that still used or does it auto save as a
> live doc i wnated the md and epdoc to be live so is that save button on epdoc
> stale or whats going on there.”

> “also the new epdoc i wat to make sure it is deeply optimized sicne it isaa
> new thing and things like jumping and lagging and the bugs we were wo0rkign on
> for all the other surfaces are addressed on epdoc as well.”

> “the title on the surfaces on code soruce prose and epdoc etc. i want it to
> not hace the weird bubble. ... the chat before that the one that had the
> ascii blur animation on the title. i want that to be applied to the titles o
> the editor surfaces. ... do not hange ay o the capabilities of the title”

> “when u navigate to a note from the tabs as well thetitle should ascii blur
> reveal hjsut like it did with the old local chat style”

> “on the surfaces there is a title on the left side as well that is an old
> deprecarted title ... i want to get rid of that.”

### Interpreted intent

- Establish and expose one honest save model for both live Markdown and live
  Epdoc editing. Inspect current NSDocument/autosave and explicit-checkpoint
  wiring before changing the Epdoc Save button; retain it only if it performs a
  distinct, useful, data-safe action, otherwise remove stale duplication.
- Give the new native Epdoc editor the same performance and stability bar as
  every other editor: no text restoration after deletion, disappearing text,
  scroll/edit recalibration, cursor jumps, layout shifts, surface hangs, save
  failures, or graph-navigation regressions, including representative 67k–72k
  word documents.
- Recover the exact older local-chat ASCII scramble plus blur-reveal title
  behavior from Git history and reuse that implementation for Markdown Prose,
  Preview, Source, code, and Epdoc titles.
- Preserve every title capability, especially the native Name/Tags/Where
  popover and rename/location semantics, while removing the unwanted liquid-
  glass title bubble itself.
- Trigger the reveal whenever editor identity changes: creation, opening,
  switching surface where appropriate, wikilink/tab navigation, and replacing
  the active note in an existing tab. Remove the duplicate deprecated
  left-side window title without destabilizing native toolbar layout.

### Hard constraints and non-goals

- Finish and verify the already-confirmed Source/Landing/sidebar/Home/
  Multitask/graph batch first; this steer is next in order and must not erase
  its evidence boundary.
- Read the exact historical title implementation and current title/save call
  sites before editing. Do not imitate the old animation from memory or replace
  the title control with a noninteractive label.
- Epdoc remains a standalone canonical `.epdoc` JSON package with native
  document ownership. Markdown remains live `.md`; no synchronous cross-format
  coupling or hidden Markdown overwrite is introduced.
- Autosave and explicit save/checkpoint behavior must be deterministic,
  crash-safe, and truthful. A visual simplification cannot weaken dirty-state,
  undo, versioning, or save/reopen guarantees.
- Preserve Epistemos palette, requested fonts, native toolbar actions, reduced
  motion, accessibility, Free V1/MAS boundaries, and the one-build rule.

### Acceptance checks and exact next action

- Source inspection and focused behavior evidence identify whether Epdoc is
  live-autosaved, what the Save button does, and whether it remains; UI copy and
  behavior agree.
- The shipped Epdoc route proves bounded large-document load, typing,
  backspace, selection, scrolling, toolbar edits, undo/redo, save/reopen,
  resize, graph navigation, and repeated navigation without jumps, hangs,
  disappearing/restored text, or uncontrolled memory growth.
- All editor titles use the recovered regular title plus ASCII/blur reveal,
  retain Name/Tags/Where and rename actions, avoid the bubble, retrigger on real
  identity/navigation changes, and honor Reduce Motion/VoiceOver.
- The duplicate left-side title is absent on all relevant editor hosts, while
  toolbar spacing, drag regions, traffic lights, window restoration, and tab
  titles remain correct.
- Continue the current R113 scheme-member verification without editing its
  inputs. After its exact result is recorded, audit Epdoc save/performance and
  title history/call sites, add fail-first coverage, implement surgically, and
  batch the next build until the complete title/Epdoc correction is integrated.

## Checkpoint 2026-07-15 — Cancel LumenLens/AI and Park Reckoner

### Verbatim owner excerpt

> “I am canceling LumenLens and all of the AI parts of it. I'm also, um,
> canceling the Reckoner because I don't want to have the sheets, the database
> stuff on there, at least not now. So, canceling that. What else should I
> cancel? I think there was more parts of it beyond just having an Excel clone
> and a Teleria clone for Epidoc. What else did I have? And what do you have
> left based off of all the prompts and steers I gave you, plus the future work
> that involved Killstone and the entire Mac App Store Canon plan, so the MAS
> Canon.”

### Interpreted intent

- Remove LumenLens and every AI-dependent LumenLens feature from the active MAS
  roadmap. Do not continue implementation, verification, or promotion of that
  lane.
- Remove Reckoner, spreadsheet cloning, and database-surface work from the
  active roadmap for now. Treat “at least not now” as parked/reversible rather
  than permission to destroy useful source or research.
- Inventory the complete MAS canon and prior owner steers so the owner can see
  what existed beyond the Excel-clone and Tolaria-inspired Epdoc work, what is
  still active, and what else could reasonably be canceled to simplify V1.
- Preserve and continue non-AI editor quality work that remains useful after
  this pivot: Epdoc JSON document editing, Markdown Prose/Preview/Source, code,
  title/save correctness, performance, navigation, graph access, native macOS
  integration, and release evidence.

### Hard constraints and non-goals

- “Canceled” changes roadmap authority immediately. It does not authorize
  destructive source deletion, history rewriting, or removal of canon needed
  to explain the decision. Park dormant implementation behind honest build and
  product boundaries unless a later explicit owner directive requests deletion.
- Kokoro voice/read-aloud is not silently canceled by the phrase “all AI
  parts”; the owner repeatedly preserved Kokoro as a non-chat local voice
  capability. Report it separately and request an explicit cancel only if the
  owner wants voice removed too.
- Do not infer or restore private Columbia/VA/funding work.
- Do not claim Free V1 has no AI merely because UI is hidden. Audit compile
  membership, product-capability gates, runtime reachability, and visible
  surfaces before making that statement.
- Pause new feature expansion while producing the inventory. Keep the current
  unbuilt Epdoc/title/performance batch intact and do not launch a stale app.

### Acceptance checks and exact next action

- Produce an evidence-anchored inventory with four buckets: canceled now,
  parked already, active non-AI MAS V1, and optional cancellation candidates.
- Identify every LumenLens/AI and Reckoner/sheets/database source or canon
  surface that is compiled, visible, gated, or merely retained.
- State the remaining Keelstone verification debt and the exact non-AI work
  already implemented but not yet rebuilt/tested.
- Update the master MAS canon/minimal execution prompt only after reconciling
  this steer with their current authority and avoiding contradictory active
  directives.
- Resume the current editor batch only within the surviving non-AI scope, then
  perform the next single clean resource-gated build when the batch is ready.

## Checkpoint 2026-07-15 — Owner-Requested Scope-Reconciliation Pause

### Verbatim owner excerpt

> “disregard what i said about contnueign the work we can pause rn but i do
> want to find a checkpoint so i can look over all the thigs. tell me what u
> did and ndid not finish and what u did not audit hardened etc basedo nthe
> nerw implementias i gave becasue lots of them im not sure got tests”

### Interpreted intent

- Pause production implementation, builds, tests, and launches at the current
  safe source checkpoint.
- Produce a durable, reviewable inventory of canceled, parked, retained,
  implemented, verified, unverified, and not-started work across all recent
  owner steers and the MAS canon.
- Retain all non-AI work except Reckoner, including Sync and the current editor
  corrections. Do not lose or overwrite the unbuilt editor batch.
- Reconcile the authoritative external canon, repository mirror, minimal
  prompt, and handoff before treating any older LumenLens/Reckoner direction as
  executable.

### Hard constraints, acceptance, and next action

- No source implementation or Xcode action occurs during this pause checkpoint.
- Evidence labels must distinguish source present, parse-only, compiled/tested,
  exact artifact, manual runtime, and still-unproven behavior.
- Record current Free V1 AI/chat leakage and dormant compile membership as open
  defects; hidden UI is not proof of cancellation.
- Publish `14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md` into
  both canon copies and point all active prompt/read-order docs at it without
  deleting historical provenance.
- After the owner reviews the checkpoint, resume under the existing KEELSTONE
  key with the Free V1 AI/Reckoner boundary correction, then finish and verify
  the retained non-AI editor batch in one resource-gated build.

## Checkpoint 2026-07-15 — No-Stranded-Directive Coverage Audit

### Verbatim owner excerpt

> “double check it mainly wnat to make sure that the direcives i gae u dont go
> missing or stranded or forgotten abou. save it all as a checkpoint that
> tewlls me what i need to do add remove and harden test etc. if not alreayd
> inl udng subtleties like P0 remove work contextual shadwo work etc.”

### Interpreted intent

- Keep the pause active and audit the full ledger/canon for owner directives
  that canon 14 summarized too broadly or did not status individually.
- Publish one durable add/remove/harden/test router covering subtle Free V1
  leaks, in-flight non-AI work, editor architecture and UX details, capability
  families, performance, storage, release, and evidence requirements.
- Preserve chronological owner wording and older receipts while preventing
  canceled AI or parked Reckoner prompts from becoming executable again.

### Hard constraints and acceptance checks

- No production source implementation, build, test, archive, or app launch
  occurs during the audit.
- Contextual Shadows chat presentation, query-runtime hidden-node disclosure,
  notebook Chat/Sheet UI, AI editor compile membership, inert AI services,
  Reckoner capability truth, restoration/copy, and stale release gates receive
  explicit P0 removal/fail-closed actions and tests.
- Retained editor, Sync, Capture/Meeting, planner, rich object, PDF, Kokoro,
  graph/search, native integration, Settings/performance, storage, and release
  work receives current implementation/proof status and an exact done bar.
- Publish
  `15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md` in both
  canon copies and route the active read order, prompt pack, handoff, evidence,
  and manifest through it.

### Exact next action

- Complete this documentation-only publication, validate parity/digest/diff,
  and remain paused. A later implementation resume starts at canon 15 Step 3
  under the existing KEELSTONE key.

## Checkpoint 2026-07-15 — Concurrent Settings Cleanup Ownership

### Verbatim owner excerpt

> “i am cleanig up settings in another session so if u see dirty edits done to
> settigs dotn worry about it”

### Interpreted intent and constraint

- Settings-file changes are owner-authorized concurrent work from another
  session. This checkpoint task must preserve them untouched and must not
  overwrite, revert, absorb, or mistake them for unexplained corruption.
- Settings cleanup remains in the product hardening/test queue, but its current
  implementation ownership belongs to the other session. Reconcile its final
  diff and run Settings/runtime/accessibility evidence only at the later shared
  one-current-build boundary.

## Checkpoint 2026-07-15 — Two-Lane Removal and Retained Rebuild Authorization

### Verbatim owner excerpts

> “i want to continue in anotehrsession but i have a whole new directive i want
> to start the mass removal of things that need to be removed ... start a
> promot for thing that should be added.”

> “epdoc is now a bare new thing i want it to have all the rich stuff teh
> previoustiptap edpoc had and more.”

> “the multitask graphdoes not work it is blank.”

> “the header behavior everythign about it feels new and lacks teh robustness
> of what it use to be including the font palettes etc.”

### Interpreted intent

- Supersede the owner-review pause for two bounded implementation sessions.
- Lane R mass-removes only what canon 15 classifies as canceled/parked/stale or
  fail-closed, with data/compatibility preservation and compile/query/runtime
  proof rather than hidden UI.
- Lane B restores and exceeds the deterministic rich behavior of the previous
  Tiptap Epdoc on the selected native TextKit 2 + JSON architecture and repairs
  the blank Multitask Graph before continuing retained additions.
- Preserve palettes, all owner fonts, rich headers/blocks, toolbar, title/
  Name-Tags-Where behavior, save/undo/migrations/export, large-document safety,
  and both allowed graph destinations. Do not restore Tiptap, AI suggestions,
  a raw-Markdown Epdoc, or a synchronous Markdown mirror.

### Hard constraints and next action

- Use canon 16 and the two new executable prompt files. Both sessions use
  disjoint file ownership, separate scoped intent/evidence ledgers, and do not
  edit Settings or coordinator canon/handoff/central-ledger files.
- Neither lane runs Xcode or launches Epistemos while the other is editing.
  After both source checkpoints are stable, one integration owner performs the
  mandatory resource preflight, one-current-build cleanup, serial App Store
  build/test, and owner-visible removal/Epdoc/graph matrix.
- Start the two new sessions by pasting their respective prompt-file command.

## Checkpoint 2026-07-15 — Removal First and Epdoc-Native Notebook Preserved

### Verbatim owner excerpt

> “u can just do one at a time so nvm lets start with remove one caveat on
> removal is that epdoc will have notebook again but in s diff way”

### Interpreted intent

- Execute the two bounded lanes sequentially, with Lane R removal first and
  Lane B Epdoc/graph construction deferred until the removal source checkpoint
  is stable.
- “Notebook removal” means the legacy Chat/Sheet/Body-strip workspace, its
  launchers, stale tabs, restoration, disclosure, and presentation—not the
  general notebook product concept.
- Preserve canonical JSON `.epdoc` document/block seams for a later
  deterministic Epdoc-native notebook/structured-document experience. That
  future feature must not revive Chat, Sheet/Reckoner, Tiptap, AI, or the
  retired workspace ontology.

### Constraints, acceptance, and next action

- Settings remains externally owned. Lane R does not edit Lane B Epdoc/graph
  files or coordinator canon/handoff/central-ledger files.
- Lane R source and tests must prove the retired workspace is unreachable while
  Epdoc JSON document/block routing remains intact and no user bytes are lost.
- Start only
  `docs/prompts/FREE_V1_REMOVAL_AND_FAIL_CLOSED_PROMPT_2026_07_15.md`.
  Do not start the retained build prompt yet.
