# KEELSTONE Intent Ledger

Date: 2026-07-07
Lane: Keelstone audit and verification evidence only.

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
