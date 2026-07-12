# Prompt 1 / Prompt 2 KEELSTONE Checkpoint - 2026-07-08

Instruction lock: `OWNER-INTENT-HARDENING-LOCK-2026-07-07`

## 2026-07-09 Visible MAS Proof Addendum - Retired Lane Bundle Prune

Owner lock captured:

> OWNER STEER: MAS base-app completion lock.

> The running MAS archive shows "The Workspace bundle is missing from this build."

> Package JuneWeb into the MAS archive at Contents/Resources/JuneWeb.

> STOP normal feature work. Treat this as a MAS data-loss/release blocker.

> voice still doesnt work so add that to known issues

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpreted intent:

- Current proof lane is MAS-only: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`.
- Prompt 2 remains open until MAS/June is the normal/base product reality and old 1Code/OpenChamber/Experimental lanes are deleted or quarantined after inventory.
- The MAS archive must load June from the bundled `Contents/Resources/JuneWeb`, with no Release/MAS fallback to dev fork or environment paths.
- Vault restore/data-loss, Kokoro/read-aloud, prompt-upgrade/Hermes drift, editor/Epdoc/graph latency, and code editor editability remain release blockers until exact archive proof says otherwise.

Prompt 1 status:

- Prompt 1 repo/target reality reporting is complete for the current MAS lane in this durable checkpoint file.
- The current repo/target reality is: normal/base `Epistemos` scheme is expected to map to the MAS AppStore target, while the proof/archive scheme remains `Epistemos-AppStore`.
- The old 1Code V2 / Experimental-lane goal is stale for this MAS run and is not controlling scope.

Latest focused MAS test before archive:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-retired-lane-prune-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneParksCodexAccountBackendAndLocalSessionImport()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 selected MAS KEELSTONE Swift Testing test passed.
- Result bundle: `build/xcode-results/2026-07-09-125722-48389.xcresult`

Latest fresh MAS archive:

```bash
STAMP=2026-07-09-retired-lane-bundle-prune-$(date +%Y%m%d-%H%M%S)
echo "$STAMP" > build/current-retired-lane-archive-stamp.txt
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "build/appstore-release-archive-derived-$STAMP" \
  -archivePath "build/appstore-release-archive-$STAMP.xcarchive"
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Stamp: `2026-07-09-retired-lane-bundle-prune-20260709-130115`
- Exact archive app: `build/appstore-release-archive-2026-07-09-retired-lane-bundle-prune-20260709-130115.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier: `com.epistemos.appstore`
- Required JuneWeb files present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`

Build settings proof:

- Proof file: `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/show-build-settings-release.json`
- Scheme: `Epistemos-AppStore`
- Target: `Epistemos-AppStore`
- Configuration: `Release`
- Product name: `Epistemos`
- Bundle id: `com.epistemos.appstore`
- Active Swift conditions: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- `EPISTEMOS_EXPERIMENTAL`: absent from AppStore Release build settings proof.
- `KINDRED_ENABLED`: absent from AppStore Release build settings proof.

Release gates and archive scans:

```bash
APP="build/appstore-release-archive-$(cat build/current-retired-lane-archive-stamp.txt).xcarchive/Products/Applications/Epistemos.app"
./scripts/keelstone-release-gate.sh --appstore-app "$APP"
```

Result:

- `KEELSTONE release gate passed`
- Gate proof includes: normal `Epistemos` scheme launches/builds MAS AppStore target, AppStore target has MAS flags, built App Store entitlements are sandboxed, built artifact omits parked runtime markers, retired payload paths, retired-lane bundle strings, and includes the required JuneWeb files.

```bash
STAMP="$(cat build/current-retired-lane-archive-stamp.txt)"
APP="build/appstore-release-archive-$STAMP.xcarchive/Products/Applications/Epistemos.app"
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR="build/visible-mas-proof-$STAMP" ./scripts/scan_appstore_bundle.sh "$APP"
```

Result:

- Scan passed.
- Report directory: `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115`
- Executables in the app bundle are limited to:
  - `Contents/MacOS/Epistemos`
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`
- Empty forbidden reports:
  - `forbidden-strings.txt`
  - `forbidden-account-runtime-strings.txt`
  - `forbidden-retired-lane-strings.txt`
  - `forbidden-1code-strings.txt`
  - `forbidden-symbols.txt`
  - `forbidden-resources.txt`
  - `quarantine-xattrs.txt`

Exact retired-lane absence scan:

```bash
APP="build/appstore-release-archive-$(cat build/current-retired-lane-archive-stamp.txt).xcarchive/Products/Applications/Epistemos.app"
find "$APP" \( -name ExperimentalWeb -o -name OpenChamber -o -name 1Code -o -name goosed -o -name opencode -o -name codex -o -name node -o -name bun -o -name rg -o -name experimental-runtime -o -name experimental-web.tar.gz \) -print
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | rg -i 'ExperimentalWeb|OpenChamber|goosed|opencode|codex|experimental-runtime|experimental-web' || true
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | rg '(^|[^[:alnum:]])1(Code|CODE)([^[:alnum:]]|$)' || true
```

Result:

- No path hits.
- No retired runtime string hits.
- No boundary `1Code` string hits.
- Saved proof: `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/exact-retired-lane-absence-scan-131938.txt`

Exact archive launch and visible MAS proof:

```bash
open -n /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-retired-lane-bundle-prune-20260709-130115.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Launched PID: `61372`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-retired-lane-bundle-prune-20260709-130115.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Launched bundle identifier: `com.epistemos.appstore`
- Launch proof: `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/exact-archive-launch-proof-131938.txt`
- Runtime log: `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/runtime-logs/exact-archive-runtime-131938.log`
- Screenshots:
  - `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/screenshots/exact-archive-mas-june-loaded-resume-overlay-131938.png`
  - `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/screenshots/exact-archive-settings-power-131938.png`
  - `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/screenshots/exact-archive-vault-sidebar-131938.png`
- Visible result: exact archive app loads MAS/June (`Greetings, Researcher` behind the resume overlay) and does not show the missing Workspace bundle panel.

Stale process boundary:

- No `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, or old Epistemos runtime path is counted as MAS evidence.
- Ambient `node`/`codex` processes observed in `pgrep` belonged to Codex/Claude/headless tooling outside the archive app path. They are not active MAS dependencies and are not evidence for this app.
- Current validation evidence is only the exact archive app path above, bundle id `com.epistemos.appstore`, and MAS release-gate/archive scans.

Current dirty files grouped:

- MAS-safe/product lane:
  - AppStore target/config/scheme files: `Epistemos-AppStore-Info.plist`, `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos.xcodeproj/project.pbxproj`, `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme`, `project.yml`.
  - MAS June/vault/voice/editor/product files: `Epistemos/App/AppBootstrap.swift`, `Epistemos/App/EpistemosApp.swift`, `Epistemos/JuneAgent/*`, `Epistemos/Sync/VaultSyncService.swift`, `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`, `Epistemos/Engine/EpistemosVisibleReadAloud.swift`, `Epistemos/VoicePro/*`, `Epistemos/Views/Notes/*`, `Epistemos/Views/Epdoc/*`, `Epistemos/Views/Capture/QuickCaptureView.swift`, `Epistemos/Views/Shared/*`, AppStore KEELSTONE tests.
  - Release gates/scanners: `scripts/keelstone-release-gate.sh`, `scripts/scan_appstore_bundle.sh`.
- Shared substrate:
  - Shared engine/vault/editor/graph files under `Epistemos/Engine`, `Epistemos/Vault`, `Epistemos/Graph`, `Epistemos/Views/Graph`, `js-editor`, `agent_core`, `epistemos-core`, `LocalPackages/KokoroPipeline`, and Rust build scripts.
  - MAS-safe Goose agent-core bridge files such as `Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift`, `Epistemos/Goose/GooseMASAgentCoreRunner.swift`, and `Epistemos/Goose/GooseMASRuntimeSupervisor.swift`.
- Parked-lane/legacy:
  - `Epistemos/ExperimentalAgent/*`, legacy Goose ACP/local-server/subprocess files, `Epistemos/Work/*` local runtime files, `Epistemos/VaultMCP/*`, Harness/EvalSandbox files, and old experimental/goose/openchamber docs/prompts.
  - These changed because Prompt 2 requires inventory/quarantine/delete mapping before removal, not indefinite preservation.
- Generated/build artifacts:
  - `build/...` archives, proof dirs, xcresults, DerivedData, `build/current-retired-lane-archive-stamp.txt`, `.june-web-stage`, compressed editor resources, `syntax-core/target`, generated Rust/Swift outputs, and scan/log/screenshot proof files.
  - Raw dirty-state proof: `build/visible-mas-proof-2026-07-09-retired-lane-bundle-prune-20260709-130115/git-status-short-1323.txt`

Why ExperimentalAgent and Goose files changed:

- `ExperimentalAgent` files changed to make legacy/parked surfaces explicit under MAS source guards and target membership quarantine, so the old 1Code/OpenChamber/Experimental surface cannot silently define product reality.
- Goose files changed because MAS June still preserves a useful MAS-safe in-process `agent_core` seam, while legacy `goosed`, ACP WebSocket/local server, subprocess, provider-key bridge, and runtime health paths are parked or excluded from the AppStore target.

Current verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Vault restore/save | Owner saw valid vault unselect after relaunch and `Cannot save page body: no vault URL` | Exact archive select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, no missing/unreadable toast, `vaultSync.vaultURL != nil`, no `no vault URL` save log | HIGH OPEN |
| Kokoro/read-aloud | Owner reports voice still does not work | Exact archive gate-ready proof, Settings preview proof, audible/log proof, and June/Prose/Epdoc/Quick Capture/current surface matrix | HIGH OPEN |
| Editor/Epdoc/graph latency | Owner reports hangs typing on all surfaces and slow graph startup | Exact archive manual/profiling proof across Prose, Source/Code, Epdoc, Quick Capture, embedded graph, hologram graph, and graph-to-editor transitions | HIGH OPEN |
| Code editor editability | Owner reports code editor is view-only | Exact archive code/source edit test plus vault write proof | HIGH OPEN |
| Epdoc rich fidelity | Owner reports rich tables/formatting collapse when switching views | Exact archive Epdoc table/formatted doc switch/edit proof and no normalized-table destructive save | HIGH OPEN |
| Prompt-upgrade/Hermes drift | Owner reports June still upgrades prompt and calls Hermes on send | Exact archive send proof with log scan for Prompt Forge/Hermes prompt-upgrade calls; remove any remaining runtime path if found | OPEN |
| Base app owner-open path | Scheme/build proof is resolved, but stale installed `/Applications/Epistemos.app` or LaunchServices alias can still mislead owner | Promote/archive install path or document/replace owner-opened app path after current archive is accepted | OPEN RESIDUAL |

Next KEELSTONE pruning/storage/release-gate target:

1. Continue Prompt 2 without Prompt 3: prioritize vault restore/save and editor/Epdoc/graph latency because they are data-loss/performance blockers.
2. Keep pruning legacy lanes through inventory: `rg` references, `project.yml`/target membership, build scripts/phases/resources, schemes/configs, tests/source guards, generated bundles, stale DerivedData/processes.
3. Preserve shared code only through MAS-safe seams; delete or quarantine old `1Code`, OpenChamber, Goose subprocess/local-server, ExperimentalWeb, node/bun/rg/opencode runtime paths after ownership is mapped.
4. Rebuild/archive/rescan `Epistemos-AppStore` after the next meaningful source batch.

## 2026-07-09 Voice English/Clean MAS Patch Addendum

Owner lock captured:

> voice still doesnt work

> the vocie is in another lanugage big issue

> am i able to do english or how does that shit work

Finding:

- Yes, the installed MAS Kokoro package can speak English. The MAS container package at `~/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro/kokoro-82m-coreml` contains English voice packs: `af_bella`, `af_heart`, `af_nicole`, `am_fenrir`, `am_michael`, `am_puck`, and `bf_emma`.
- The AppStore defaults had `EPISTEMOS_KOKORO_VOICE_PRO_V0 = 1`, global voice `af_bella`, and persisted `com.epistemos.voice.readAloudEffect = pixelArt`. That effect can distort otherwise-English output enough to sound broken or non-English.

Patch:

- MAS/AppStore builds now force read-aloud effects to `.clean` through `VoicePreferences.shippedReadAloudEffect`.
- MAS/AppStore builds hide the read-aloud effect controls behind `VoicePreferences.allowsReadAloudEffects == false`.
- `EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier` now accepts only installed English Kokoro voice packs for explicit/global selection before falling back to the English starter voice.
- Live AppStore defaults were reset with:

```bash
defaults write com.epistemos.appstore com.epistemos.voice.readAloudEffect clean
```

Focused MAS proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-voice-english-clean-appstore-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()'
```

Result:

- `** TEST SUCCEEDED **`
- Swift Testing reported 2 selected MAS KEELSTONE tests passed.
- Result bundle: `build/xcode-results/2026-07-09-153128-3171.xcresult`

Blocked broad companion proof:

- `EpistemosTests` is not included in the current `Epistemos-AppStore` or normal `Epistemos` schemes.
- Direct target `test` requires a scheme.
- Direct target `build -target EpistemosTests` currently fails before compiling tests because `EpistemosTests` depends on quarantined `Epistemos-LegacyDev`, whose `com.epistemos.legacydev` signing profile is intentionally unavailable in the MAS-focused environment.

Remaining voice proof debt:

- Rebuild/archive/rescan exact `Epistemos-AppStore` Release app after this patch.
- Launch the exact archive app.
- Trigger Settings Voice preview and capture logs showing readiness plus `Kokoro TTS queued`, `render started`, `render finished`, `playback started`, and no failure log.
- Manual/audible proof still required; source and focused MAS tests alone are not the final voice fix claim.

## 2026-07-09 MAS Visible + Voice Proof Addendum

Current lock:

- MAS-only proof scheme: `Epistemos-AppStore`
- Target: `Epistemos-AppStore`
- Configuration: `Release` for archive proof, `Debug` for focused test proof
- Active compile conditions: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- Explicitly absent from AppStore build settings: `EPISTEMOS_EXPERIMENTAL`, `KINDRED_ENABLED`

Focused MAS test before archive:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-voice-landing-read-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()'
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 1 selected MAS KEELSTONE test passed. Result bundle: `build/xcode-results/2026-07-09-105820-4666.xcresult`.

Fresh exact archive proof:

- Proof directory: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112`
- Archive: `build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive`
- Exact app: `build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive/Products/Applications/Epistemos.app`
- Archive command: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/archive-command.txt`
- Archive log: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/archive.log`
- Result: `** ARCHIVE SUCCEEDED **`
- Bundle identifier: `com.epistemos.appstore`
- Build settings proof: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/visible-mas-proof.txt`
- Release gate proof: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/keelstone-release-gate.log` ends `KEELSTONE release gate passed`.
- Bundle scan proof: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/appstore-bundle-scan.log` passed.
- Exact artifact name scan: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/exact-artifact-name-scan.txt` reports `scan_result=PASS`.
- Required JuneWeb files present in the archive app:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`
- Prohibited archive path/resource names absent by exact path-segment scan: `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, `experimental-runtime`.

Exact launch and visible proof:

- Launch command: `open -n /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive/Products/Applications/Epistemos.app`
- Launch proof: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/exact-archive-launch-proof.txt`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Launched bundle identifier: `com.epistemos.appstore`
- Screenshot: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/screenshots/exact-archive-mas-june-loaded-111203.png`
- Screenshot result: exact archive app visibly loads MAS June landing (`GREETINGS, RESEARCHER`) and does not show the missing Workspace bundle panel.
- Stale process evidence boundary: `prelaunch-process-scan.txt` and `postquit-process-scan.txt` show no exact Epistemos process and no `goosed`/`OpenChamber`/`ExperimentalWeb`/`opencode`/runtime-path processes before this launch. Stale `goosed`, `OpenChamber`, `ExperimentalWeb`, node/dev-server, or old debug apps remain non-evidence if observed later.

Kokoro/read-visible proof from the exact archive:

- Runtime log: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/runtime-logs/exact-archive-runtime.log`
- Voice proof summary: `build/visible-mas-proof-2026-07-09-voice-landing-read-20260709-110112/runtime-logs/voice-landing-proof.txt`
- `Read visible surface requested preferred=active`: present
- `Read visible surface queued surface=landingHome`: present
- Kokoro readiness for `landingHome`: `gateResolved=true`, `manifestValid=true`, `KokoroPipelineLinked=true`, `isTextToSpeechAvailable=true`
- Model root: `/Users/jojo/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro`
- Kokoro render/playback: queued, render finished, audio engine started, playback started, playback completed
- Kokoro failure log: absent for this trigger
- Agent did not claim personal audible perception; captured playback proof is the exact archive runtime log showing AVAudioEngine output plus Kokoro playback start/completion.

Current dirty files grouped:

- MAS-safe release/product lane: AppStore plist/entitlements/scheme/project, MAS June source, `JuneWebAssets`, prompt-forge disablement, landing/read-aloud providers, Kokoro voice path, vault restore path, AppStore KEELSTONE tests, release gate and bundle scan scripts.
- Shared substrate: shared Swift engine/vault/editor/graph services, `LocalPackages/KokoroPipeline`, `agent_core`, `epistemos-core`, editor runtime, Rust build scripts, MAS-safe Goose agent-core adapters.
- Parked-lane/legacy: `ExperimentalAgent`, legacy Goose ACP/local-server/subprocess files, OpenCode/Work runtime files, Harness/EvalSandbox, old docs/prompts. These are inventory/quarantine/delete targets, not product evidence.
- Generated/build artifacts: `build/...` archives/proof dirs/xcresults/DerivedData, `.june-web-stage`, generated editor compressed resources, `syntax-core/target`, generated Rust/Swift binding outputs. Do not stage or commit broad generated state.

Verification debt after this proof:

- HIGH OPEN: full voice matrix still needs exact archive proof for Settings preview, June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, HTML Workspace/current MAS screen. Landing/home is proven.
- HIGH OPEN: exact archive quit/reopen vault restore proof on `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, with no missing/unreadable toast and no `Cannot save page body: no vault URL`.
- HIGH OPEN: direct proof that `vaultSync.vaultURL` is non-nil after exact archive relaunch.
- HIGH OPEN: normal/base app visible launch proof must show MAS/June from the normal owner-opened path. Source/release gate says normal `Epistemos` scheme maps to MAS AppStore target, but exact normal launch proof remains required.
- HIGH OPEN: prompt-upgrade/Hermes send behavior needs exact archive runtime send proof, even though staged JuneWeb marker scan and JS tests passed.
- HIGH OPEN: Epdoc rich table/format preservation, code editor editability, graph startup, graph-embedded editor launch, and typing latency need real archive/manual proof after source hardening.
- MEDIUM OPEN: stop the current runtime log stream and quit the exact archive app before any final handoff.

Next Prompt 2 target:

1. Prove or fix normal/base launch path as MAS/June product reality.
2. Re-run exact archive vault restore relaunch proof and patch if the bookmark warning or `no vault URL` appears.
3. Continue surface-by-surface Kokoro wiring proof.
4. Audit prompt send/Hermes drift from the exact archive.
5. Continue editor/Epdoc/graph hot-path hardening and archive/manual proof.

## 2026-07-09 Normal/Base Scheme MAS Proof Addendum

Normal/base scheme archive proof:

- Scheme: `Epistemos`
- Built target observed in archive log: `Epistemos-AppStore`
- Configuration: `Release`
- Proof directory: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518`
- Archive: `build/base-scheme-release-archive-2026-07-09-base-scheme-mas-20260709-111518.xcarchive`
- Exact app: `build/base-scheme-release-archive-2026-07-09-base-scheme-mas-20260709-111518.xcarchive/Products/Applications/Epistemos.app`
- Archive log: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/archive.log`
- Result: `** ARCHIVE SUCCEEDED **`
- Base proof file: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/base-scheme-mas-proof.txt`
- Bundle identifier: `com.epistemos.appstore`
- Compile flags: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED`: absent from normal-scheme Release build settings
- Required JuneWeb files: present in `Contents/Resources/JuneWeb`
- Release gate: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/keelstone-release-gate.log` ends `KEELSTONE release gate passed`.
- Bundle scan: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/appstore-bundle-scan.log` passed.
- Exact artifact name scan: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/exact-artifact-name-scan.txt` reports `scan_result=PASS`.

Normal/base scheme exact launch proof:

- Launch command: `open -n /Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-09-base-scheme-mas-20260709-111518.xcarchive/Products/Applications/Epistemos.app`
- Launch proof: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/exact-base-scheme-launch-proof.txt`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-09-base-scheme-mas-20260709-111518.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Launched bundle identifier: `com.epistemos.appstore`
- Runtime log: `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/runtime-logs/exact-base-scheme-runtime.log`
- Visible proof screenshots:
  - `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/screenshots/base-scheme-mas-june-loaded-frontmost-112512.png`
  - `build/visible-mas-proof-2026-07-09-base-scheme-mas-20260709-111518/screenshots/base-scheme-mas-june-after-continue-112557.png`
- Visual result: the normal `Epistemos` scheme launches the MAS AppStore app and shows the MAS Welcome Back/June landing surface. It does not open the old 1Code/OpenChamber/Experimental surface.
- Prelaunch/postquit scans: `prelaunch-process-scan.txt` and `postquit-process-scan.txt` show no exact Epistemos process and no old runtime process names/paths before launch.

Base-app ambiguity status:

- RESOLVED for Xcode scheme/build/run/archive reality: normal `Epistemos` scheme now builds/archives/launches `Epistemos-AppStore` with MAS flags and bundle id `com.epistemos.appstore`.
- OPEN residual owner-facing risk: if the owner opens an already-installed older `/Applications/Epistemos.app` or an old LaunchServices shortcut outside this repo/archive, that external installed app can still be stale. It must not be used as evidence. Next hardening target is to document or replace the owner-facing install/open path after the archive is promoted.

Updated next Prompt 2 target:

1. Exact archive vault restore relaunch proof on `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`.
2. Patch `VaultSyncService`/startup restore if the missing/unreadable bookmark warning or `no vault URL` appears.
3. Continue full read-aloud matrix beyond the now-proven landing/home surface.
4. Audit prompt send/Hermes runtime behavior.
5. Continue editor/Epdoc/graph latency and code-editor editability hardening.

## 2026-07-09 Fresh MAS Archive Proof Addendum

Latest owner steers captured:

> OWNER STEER: MAS base-app completion lock.

> The running MAS archive shows "The Workspace bundle is missing from this build."

> STOP normal feature work. Treat this as a MAS data-loss/release blocker.

> voice still doesnt work so add that to known issues

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng

> all editors bascially ... hang when i start typign ... takes a long time to startup on graph speciifcally

Interpreted intent:

- Current lock is MAS-only: `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`.
- Prompt 2 remains open until the normal/base app cannot be mistaken for old 1Code/OpenChamber/Experimental, or that ambiguity is logged as a HIGH blocker with exact actions.
- The MAS archive must package JuneWeb and load the MAS June surface visibly from `Contents/Resources/JuneWeb`, with no Release/MAS fallback to dev paths.
- Vault restore data-loss risk, Kokoro/read-aloud, prompt-upgrade/Hermes drift, editor/Epdoc/graph latency, and base-app MAS reality are release blockers.
- Stale `goosed`, `OpenChamber`, `ExperimentalWeb`, node/dev-server, or old debug app processes are not MAS evidence.

Fresh verified archive evidence:

- Proof directory: `build/visible-mas-proof-2026-07-09-agentcore-scope-20260709-094155`
- Archive: `build/appstore-release-archive-2026-07-09-agentcore-scope-20260709-094155.xcarchive`
- Exact app: `build/appstore-release-archive-2026-07-09-agentcore-scope-20260709-094155.xcarchive/Products/Applications/Epistemos.app`
- Archive log: `build/visible-mas-proof-2026-07-09-agentcore-scope-20260709-094155/archive.log`
- Result: archive log contains `** ARCHIVE SUCCEEDED **`; wrapper exit was contaminated by a shell variable bug after archive completion.
- Bundle id: `com.epistemos.appstore` from `build/visible-mas-proof-2026-07-09-agentcore-scope-20260709-094155/bundle-id.txt`
- Build settings proof: `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT` in `show-build-settings-key-lines.txt`
- App Store Info.plist: `INFOPLIST_FILE = Epistemos-AppStore-Info.plist`
- Product bundle identifier: `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
- Prohibited compile flags: `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` absent from the AppStore Release build settings/archive proof.
- Required packaged web files present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`
- Release gate proof: `build/visible-mas-proof-2026-07-09-agentcore-scope-20260709-094155/keelstone-release-gate.log` ends `KEELSTONE release gate passed`.
- Bundle scan proof: `build/visible-mas-proof-2026-07-09-agentcore-scope-20260709-094155/appstore-bundle-scan.log` passed; only executables are the MAS binary and bundled dylibs.
- Exact runtime artifact/name scan: `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, `experimental-runtime`, `node_modules`, package locks, `EPISTEMOS_EXPERIMENTAL`, and `KINDRED_ENABLED` are absent from the built MAS bundle per `exact-runtime-artifact-scan.txt` and `strict-prohibited-token-scan.txt`.
- Exact launch command: `open -n build/appstore-release-archive-2026-07-09-agentcore-scope-20260709-094155.xcarchive/Products/Applications/Epistemos.app`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-agentcore-scope-20260709-094155.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Launched bundle id: `com.epistemos.appstore`
- Visible MAS proof screenshot: `build/visible-mas-proof-2026-07-09-agentcore-scope-20260709-094155/exact-archive-epistemos-window-51490.png` shows MAS June loaded from the exact archive, not the missing Workspace bundle panel. It also shows vault import progress, so vault restore is active but not yet accepted as relaunch-proof.
- Runtime log proof: `runtime-logs/exact-archive-runtime.log` shows the exact archive resolving an app-scoped vault bookmark with security scope; relaunch/no-toast proof remains pending.

Current dirty files grouped:

- MAS-safe release/product lane: `Epistemos-AppStore-Info.plist`, `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos.xcodeproj`, `project.yml`, `scripts/keelstone-release-gate.sh`, `scripts/scan_appstore_bundle.sh`, AppStore source guards/tests, MAS June source, MAS release-gate scripts, JuneWeb asset packaging, vault restore, voice/read-aloud, editor/Epdoc/graph hot paths.
- Shared substrate: `agent_core`, `epistemos-core`, `LocalPackages/KokoroPipeline`, `js-editor`, shared Swift engine/vault/model/editor/graph services, shared Rust build scripts, AppBootstrap and provider/keychain seams.
- Parked-lane/legacy: `Epistemos/ExperimentalAgent`, legacy Goose runtime/surface files, OpenCode/Work runtime files, Harness/EvalSandbox files, old experimental/goose/openchamber docs and prompts. These are inventory/quarantine/delete targets, not active product scope.
- Generated/build artifacts: `build/...` archives/proof directories/xcresults/DerivedData, `syntax-core/target`, generated compressed editor resources, generated presets and local package/build outputs. Do not stage broad generated state.

Why ExperimentalAgent and Goose files changed:

- ExperimentalAgent files changed because the MAS base-app lock requires inventory/quarantine and compile/source guards around legacy/parked surfaces so they cannot silently define product reality.
- Goose files changed because MAS June still reuses a MAS-safe in-process agent-core seam; legacy Goose subprocess/ACP/local-server behavior is parked or gated, while `GooseMASAgentCoreRunner` and related MAS-safe adapters preserve useful agent-core substrate without depending on `goosed`, OpenChamber, node, or local servers.

Current verification-debt ledger:

- HIGH OPEN: exact archive quit/reopen vault restore proof on `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, with no startup missing/unreadable toast and no `Cannot save page body: no vault URL`.
- HIGH OPEN: direct proof that `vaultSync.vaultURL` is non-nil after exact archive relaunch, not merely source-guard proof.
- HIGH OPEN: Kokoro voice/read-aloud exact archive proof; current status remains known broken until gate-ready, preview, audible/manual, and surface matrix are proven.
- HIGH OPEN: prompt-upgrade/Hermes drift on send; staged JuneWeb marker scan and JS tests passed, but exact archive runtime send behavior still needs proof.
- HIGH OPEN: Epdoc rich-table/format preservation and editor typing latency across Prose, Source, Epdoc, code editor, graph-embedded launch, and Hologram graph startup need real archive/manual proof after source fixes.
- HIGH OPEN: base/default app must become MAS/June product reality or old base must be quarantined/renamed legacy/dev-only.
- MEDIUM OPEN: stop runtime proof log stream after exact archive checks so no long-lived proof process remains.

Next KEELSTONE pruning/storage/release-gate target:

1. Complete exact archive vault relaunch proof and capture logs/screenshots.
2. If the relaunch path still warns or loses the vault URL, patch `VaultSyncService`/startup validation before any normal feature work.
3. Audit/fix prompt-upgrade/Hermes send drift and voice/read-aloud product wiring.
4. Continue editor/Epdoc/graph hot-path hardening and run focused MAS tests.
5. Resolve base/default MAS app reality, then rebuild/archive/rescan after meaningful source changes.

## Latest Owner Steer - 2026-07-09 Editing and Graph Startup

Verbatim owner wording:

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpreted intent:

- Treat all editor-surface typing latency and graph startup latency as Prompt 2 MAS release blockers.
- Continue MAS-only work on `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`; do not switch back to stale 1Code/Experimental scope.
- Harden shared storage/editor hot paths used by Prose, Source, Epdoc/Document, preview transitions, graph-embedded editors, and code-file surfaces.
- Keep the base-app completion lock: the normal/base scheme must remain MAS/June equivalent, and legacy 1Code/OpenChamber/Experimental lanes remain inventory/delete/quarantine targets.

Constraints:

- Do not stage or commit the broad dirty worktree.
- Do not use stale DerivedData/debug apps, goosed/OpenChamber/ExperimentalWeb processes, or local dev paths as MAS evidence.
- Preserve useful shared code only through MAS-safe seams.
- Source-level guards are not enough for a final claim; archive/test/manual evidence remains required before closing the blocker.

Acceptance checks added to the ledger:

- MAS App Store lane test proves graph sidebar tree/search cache rebuilds are off graph startup and utility-priority async.
- MAS App Store lane test proves all body editor surfaces route interactive Markdown body persistence through `VaultSyncService.savePageBodyFileFirst` without duplicate pre-file-first model/block-mirror/file writes.
- Exact `Epistemos-AppStore` archive rebuild, release gate, and bundle scan pass after meaningful source changes.
- Manual exact-archive proof remains required for perceived graph startup and typing responsiveness.

Current verification debt:

- HIGH OPEN: real archived-app graph startup timing and typing responsiveness on Prose, Source, Epdoc/Document, code editor, graph-embedded editor launches.
- HIGH OPEN: vault bookmark restore/save regression proof on `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`.
- HIGH OPEN: Kokoro read-aloud proof and product wiring.
- HIGH OPEN: prompt-upgrade/Hermes aggressiveness audit and fix.
- HIGH OPEN: Epdoc rich table/format fidelity and surface-switch preservation proof.

Latest focused MAS editor evidence:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-snapshot-clean-reload-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneClearsStaleCleanLensSnapshotsAfterPersistedReload()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()'
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 3 selected `EpistemosAppStoreKeelstoneTests` passed under `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`. Result bundle: `build/xcode-results/2026-07-09-045529-2389.xcresult`.

Patch evidence boundary: this validates the clean lens-snapshot invalidation guard and existing editor input/typing source guards in a Debug MAS build. A fresh `Epistemos-AppStore` Release archive, release gate, bundle scan, and exact-archive manual responsiveness proof are still required before closing the editor/graph blocker.

Follow-up MAS editor/graph hot-path evidence:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-graph-hotpath-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneClearsStaleCleanLensSnapshotsAfterPersistedReload()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()'
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 4 selected `EpistemosAppStoreKeelstoneTests` passed under the MAS scheme. Result bundle: `build/xcode-results/2026-07-09-050352-4878.xcresult`.

Source changes covered by this pass:

- `HologramSearchSidebar` now yields before capturing graph nodes/edges for sidebar cache building and only recomputes search results when the query is non-empty.
- `CodeEditorView` now debounces parent `onTextSnapshot` publication while preserving immediate flush on disappear and the existing debounced content-save path.
- The June fork was rebuilt by the AppStore build step after `src/lib/tauri.ts` was changed so Prompt Forge helper calls return disabled/unchanged responses instead of invoking native `system_prompt_forge_*` commands.

Evidence boundary: this is still Debug MAS build/test proof. Because source and staged JuneWeb changed after the last archive, a fresh Release archive, release gate, bundle scan, prompt marker scan, and exact-archive manual checks remain open.

Prompt-upgrade/Hermes source and staged-web proof:

```bash
rg -n "system_prompt_forge|prompt\.forge_preview|Prompt Forge|Sharpening prompt|agent-composer-forge|Custom system prompt|Accepted System Prompt Forge|No accepted System Prompt Forge|Hermes" .june-web-stage
```

Result: no matches (`rg` exit 1). The staged JuneWeb output does not contain Prompt Forge, forge-preview, sharpening, or Hermes markers.

```bash
bun run test -- src/test/agent-workspace.test.tsx src/test/app-settings.test.tsx
```

Result: passed. Vitest reported 2 files passed, 185 tests passed, 2 skipped. This covers normal `prompt.submit` send behavior and the disabled prompt-rewriting settings panel in the June fork.

## Owner Intent Checkpoint

Verbatim owner wording:

> Epistemos is now MAS-only. The active product is Epistemos-AppStore / EPISTEMOS_APP_STORE / MAS_SANDBOX. MAS June is the only active agent surface.

Interpreted intent:

- Treat `Epistemos-AppStore` as the only active release product.
- Treat MAS June as the only active agent surface.
- Pro, Developer-ID, Experimental, Goose runtime/surface, Kindred, browser-use, Chromium, terminal/code execution, stdio MCP, local servers, subprocess sidecars, second chat/runtime/transcript/tool/data-room lanes are parked unless explicitly revived.
- Do not delete first. Inventory, prove release risk, gate, then prune or decouple surgically.

Non-goals:

- No App Store Connect upload/submission.
- No distribution-signing or provisioning changes beyond local inspection evidence.
- No broad deletion of direct/pro/experimental source without inventory and rollback path.
- No use of stale cached direct-lane apps or old local processes as MAS evidence.
- No obedience to stale 1Code V2 / Experimental-lane scope rules during this MAS-only run.
- No staging or committing of the broad dirty worktree until the MAS-safe scope is separated.

Latest owner steer:

> the old 1Code V2 Experimental-lane goal/objective is stale for this MAS run. Current lock is MAS-only. Do not obey 1Code/Experimental scope rules for this MAS agent.

Interpretation: parked Experimental/1Code files may be scanned, gated, documented, or pruned for MAS release safety, but they do not define active product scope or acceptance criteria.

## Prompt 1 Reality Report

- Repo: `/Users/jojo/Downloads/Epistemos`
- Branch: `feat/goose-surface`
- Worktree: broadly dirty. `git status --short | wc -l` returned `341` after the latest App Store archive, local signing, and scan re-run.
- Active release target: `Epistemos-AppStore`
- Active MAS compile conditions: `EPISTEMOS_APP_STORE MAS_SANDBOX`
- Bundle ID: `com.epistemos.appstore`
- Source entitlements: `Epistemos/Epistemos-AppStore.entitlements`
- App Store Info.plist: `Epistemos-AppStore-Info.plist`
- Privacy manifest: `Epistemos/Resources/PrivacyInfo.xcprivacy`
- Parked but present: direct `Epistemos`, `Epistemos-Experimental`, Experimental/Goose/OpenChamber/Work runtime source.

Stale-lane risk:

- Direct/debug `Epistemos` and `Epistemos-Experimental` still exist.
- Goose/OpenChamber/Experimental runtime source remains in the tree.
- Old local processes were observed under `.cache/epistemos-dd-codex-preview-inset-clamp-pro`; these are not MAS dependencies and must not be used as evidence.

## Prompt 2 / KEELSTONE Status

Prompt 2 is active. Current phase: KEELSTONE storage/release-gate hardening and parked-lane decoupling for MAS App Store archive evidence.

Current App Store archive evidence:

- Archive: `build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive`
- Archived app: `build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app`
- Local inspection signature only: ad-hoc signed with `Epistemos/Epistemos-AppStore.entitlements`

## Verification Evidence

Focused hardening test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests \
  -only-testing:EpistemosTests/ProductionHardeningTests
```

Result: `** TEST SUCCEEDED **`; 54 Swift Testing tests passed.

Post HTML runtime parking source-guard test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests
```

Result: `** TEST SUCCEEDED **`; 56 Swift Testing tests passed, including `HTML Workspace Goose regeneration is compile-parked in App Store source` and `HTML Workspace Python runtime is parked in App Store source`. Result bundle:
`build/xcode-results/2026-07-08-071418-61211.xcresult`.

Dedicated App Store lane test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 Swift Testing tests passed. Result bundle:
`build/xcode-results/2026-07-08-064815-39901.xcresult`.

Post HTML runtime parking App Store lane test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 Swift Testing tests passed. Result bundle:
`build/xcode-results/2026-07-08-070949-58369.xcresult`.

Fresh App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-0638-no-network-server \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Post HTML runtime parking fresh App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0723-html-runtime-pruned.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-0723-html-runtime-pruned \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. Archived app was ad-hoc signed for local inspection with `Epistemos/Epistemos-AppStore.entitlements`.

Archive checks:

- `codesign -d --entitlements :-` showed sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only.
- `com.apple.security.network.server` absent from source and built entitlements.
- `com.apple.security.cs.allow-jit`, `com.apple.security.cs.allow-unsigned-executable-memory`, and `com.apple.security.cs.disable-library-validation` absent from MAS entitlements.
- `LSApplicationCategoryType` = `public.app-category.productivity`.
- `PrivacyInfo.xcprivacy` present with file timestamp, system boot time, disk space, and user defaults required-reason API declarations.
- `com.apple.quarantine` xattr scan returned no paths for the archived app.

Release gates:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive/Products/Applications/Epistemos.app
```

Result: passed.

Post HTML runtime parking release gate against the existing archive:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Scope covered target/macro drift, project resource exclusions, MAS source parking witnesses, source entitlements, built entitlements, and archive residue checks.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-0638-no-network-server \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive/Products/Applications/Epistemos.app
```

Result: passed.

Post HTML runtime parking archive scan against the existing archive:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-0638-no-network-server-post-html-runtime-parking \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-0638-no-network-server-post-html-runtime-parking`.

Explicit archived-app forbidden-path scan:

```bash
find build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | \
  rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'
```

Result: no forbidden archive path residues.

Fresh 07:23 archive release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0723-html-runtime-pruned.xcarchive/Products/Applications/Epistemos.app
```

Result: passed.

Fresh 07:23 archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-0723-html-runtime-pruned \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0723-html-runtime-pruned.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-0723-html-runtime-pruned`.

Fresh 07:23 entitlements inspection:

```bash
codesign -d --entitlements :- build/appstore-release-archive-2026-07-08-0723-html-runtime-pruned.xcarchive/Products/Applications/Epistemos.app 2>/dev/null | plutil -p -
```

Result: sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only; no network server entitlement.

Fresh 07:23 forbidden-path scan:

```bash
find build/appstore-release-archive-2026-07-08-0723-html-runtime-pruned.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | \
  rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'
```

Result: no forbidden archive path residues.

## Files Changed In This KEELSTONE Pass

MAS-safe:

- `Epistemos-AppStore-Info.plist`
- `Epistemos/Epistemos-AppStore.entitlements`
- `EpistemosTests/AppStoreHardeningTests.swift`
- `EpistemosTests/AppStoreJuneHardeningTests.swift`
- `EpistemosTests/AppStoreJuneSourceGuard.swift`
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`
- `EpistemosTests/ProductionHardeningTests.swift`
- `scripts/keelstone-release-gate.sh`
- `scripts/scan_appstore_bundle.sh`
- `docs/MAS_APP_REVIEW_NOTES_2026_07_03.md`
- `docs/mas-c/**`
- `docs/plans/keelstone/**`
- `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
- `docs/prompts/MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md`
- `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`

Shared substrate:

- `AGENTS.md`, `CLAUDE.md`, `.gitignore`, `README.md`
- `project.yml`, `Epistemos.xcodeproj/project.pbxproj`
- Shared Swift app surfaces under `Epistemos/App`, `Epistemos/Engine`, `Epistemos/JuneAgent`, `Epistemos/QuickChat`, `Epistemos/Vault`, `Epistemos/VaultMCP`, `Epistemos/Views`, `Epistemos/VoicePro`, and `Epistemos/Omega`
- HTML workspace MAS parking seams: `Epistemos/Engine/HTMLWorkspacePythonRuntime.swift`, `Epistemos/Models/HTMLWorkspacePackage.swift`, `Epistemos/Models/HTMLWorkspacePreviewDocument.swift`, `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorPackageActions.swift`, `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift`, and `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceGooseRegenerator.swift`
- Shared Rust substrate under `agent_core/**` and `epistemos-core/**`
- Shared editor substrate under `js-editor/**`
- Shared build scripts including `build-agent-core.sh`, `build-epistemos-core.sh`, `build-rust.sh`, and `bundle-app-runtime-assets.sh`

These shared files remain dirty in the working tree and are not staged. For Prompt 2 they are only acceptable if the MAS target reaches them through `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`-safe seams.

Parked-lane / legacy:

- `Epistemos/ExperimentalAgent/**`
- `Epistemos/Goose/**`
- `Epistemos/Harness/CompletionChecker.swift`
- `Epistemos/Harness/EvalSandbox.swift`
- `Epistemos/Harness/HarnessIntegration.swift`
- `Epistemos/Harness/HarnessLab.swift`
- `Epistemos/Harness/HarnessRegistry.swift`
- `Epistemos/Work/WorkOpenCodeRuntime.swift`
- `Epistemos/Work/WorkOpenCodeShell.swift`
- `Epistemos/Work/WorkServerDiagnostics.swift`
- `Epistemos/Work/WorkSkillsProvisioner.swift`
- Goose, Experimental, Kindred, OpenChamber, and 1Code handoff/prompt/research docs under `docs/handoffs/**`, `docs/prompts/**`, and `docs/research/**`
- `docs/release/MAS_APP_REVIEW_NOTES.md` now warns that it is legacy and must not be attached to App Store Connect.

Generated/build artifacts:

- `Epistemos/Resources/Editor/editor.css.br`
- `Epistemos/Resources/Editor/editor.js.br`
- `Epistemos/Resources/best_of_preset.json`
- `build/appstore-release-archive-2026-07-08-0638-no-network-server.xcarchive`
- `build/appstore-release-archive-derived-0638-no-network-server`
- `build/appstore-release-archive-2026-07-08-0723-html-runtime-pruned.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-0723-html-runtime-pruned`
- `build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-0750-html-runtime-warning-clean`
- `build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-0812-oauth-loopback-parked`
- `build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-0846-goose-acp-client-parked`
- `build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-0915-vault-subprocess-guard`
- `build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-0936-harness-subprocess-parked`
- `build/appstore-archive-scan-0638-no-network-server`
- `build/appstore-archive-scan-0638-no-network-server-post-html-runtime-parking`
- `build/appstore-archive-scan-2026-07-08-0723-html-runtime-pruned`
- `build/appstore-archive-scan-2026-07-08-0750-html-runtime-warning-clean`
- `build/appstore-archive-scan-2026-07-08-0812-oauth-loopback-parked`
- `build/appstore-archive-scan-2026-07-08-0846-goose-acp-client-parked`
- `build/appstore-archive-scan-2026-07-08-0915-vault-subprocess-guard`
- `build/appstore-archive-scan-2026-07-08-0936-harness-subprocess-parked`
- `build/xcode-results/2026-07-08-064815-39901.xcresult`
- `build/xcode-results/2026-07-08-070949-58369.xcresult`
- `build/xcode-results/2026-07-08-071418-61211.xcresult`
- `build/xcode-results/2026-07-08-073520-78411.xcresult`
- `build/xcode-results/2026-07-08-073951-82238.xcresult`
- `build/xcode-results/2026-07-08-080318-96619.xcresult`
- `build/xcode-results/2026-07-08-080825-457.xcresult`
- `build/xcode-results/2026-07-08-082629-13829.xcresult`
- `build/xcode-results/2026-07-08-083831-22848.xcresult`
- `build/xcode-results/2026-07-08-084225-25509.xcresult`
- `build/xcode-results/2026-07-08-085824-37298.xcresult`
- `build/xcode-results/2026-07-08-090748-46977.xcresult`
- `build/xcode-results/2026-07-08-092414-60585.xcresult`
- `build/xcode-results/2026-07-08-093214-66414.xcresult`
- `syntax-core/target/**`

## ExperimentalAgent / Goose Explanation

Experimental and Goose files are still inspected because they are the highest-risk parked surfaces. Prompt 2 must prove those paths are compile-parked, scrubbed, or absent from the MAS archive. Their presence in tests/gates is intentional evidence, not active MAS product scope.

Old `goosed`, OpenChamber, and ExperimentalWeb processes observed under `.cache/epistemos-dd-codex-preview-inset-clamp-pro` are leftover direct-lane preview processes. They are not active dependencies for `Epistemos-AppStore` and must not be used as MAS evidence.

## 2026-07-08 07:49 Update

Post-warning-cleanup source guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 56 tests in the `Phase S -- App Store hardening` suite passed. Result bundle:
`build/xcode-results/2026-07-08-073951-82238.xcresult`.

Important evidence boundary: this was a non-AppStore source-guard run, and its normal `Epistemos` Debug build copied direct-lane runtime resources (`opencode-runtime`, ExperimentalWeb staging) into the non-MAS debug app. That output is not MAS validation and must not be used as App Store evidence. MAS evidence still comes only from `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX` tests, gates, archives, entitlements inspection, and archive scans.

Fresh post-warning-cleanup App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-0750-html-runtime-warning-clean \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. The prior `HTMLWorkspacePackage.swift` / `HTMLWorkspacePreviewDocument.swift` constant-condition warnings did not recur. Remaining visible Release warnings were existing `no async operations occur within await` warnings in `TextCapturePipeline.swift` and `VaultSyncService.swift`.

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive/Products/Applications/Epistemos.app
```

Result: replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive/Products/Applications/Epistemos.app
```

Result: passed.

Archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-0750-html-runtime-warning-clean \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-0750-html-runtime-warning-clean`.

Entitlements inspection:

```bash
codesign -d --entitlements :- build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive/Products/Applications/Epistemos.app 2>/dev/null | plutil -p -
```

Result: sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only; no network server, JIT, unsigned executable memory, or library-validation override entitlement.

Explicit forbidden-path scan:

```bash
find build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | \
  rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'
```

Result: no forbidden archive path residues.

Quarantine xattr scan:

```bash
xattr -lr build/appstore-release-archive-2026-07-08-0750-html-runtime-warning-clean.xcarchive/Products/Applications/Epistemos.app | rg -n 'com\.apple\.quarantine'
```

Result: no quarantine extended attributes.

## Verification Debt Ledger

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Durable Prompt 1/2 ledger | Source of truth can drift into chat-only memory | This file exists and is updated after steers | Open until committed or refreshed after next steer |
| MAS target membership leak scan | Parked resources can re-enter App Store target | Source/project/archive scan for forbidden residues | Passed for fresh 09:36 App Store archive; reopen after meaningful MAS source/project changes |
| Google OAuth loopback server | MAS lacks network-server entitlement; local OAuth callback listener would drift into App Store binary | Compile-park listener/import/sign-in branch, source guard, release gate, MAS build/archive string scan | Passed: source guard, MAS App Store lane, 08:12 archive release gate, and binary marker scan |
| Goose ACP WebSocket/provider client | Parked Goose ACP client/provider bridge symbols drifted into the 08:12 MAS archive | Compile-park client/provider bridge, source guard, release gate, MAS build/archive string scan | Passed: source guard, MAS App Store lane, 08:46 archive release gate, and binary marker scan |
| Vault git/tmutil subprocess MAS_SANDBOX guard | AppStore-only guards could leave subprocess paths reachable if MAS_SANDBOX is used without EPISTEMOS_APP_STORE | Combined source guards, release gate witnesses, MAS App Store lane, fresh archive string/path scan | Passed: source guard, source release gate, MAS App Store lane, 09:15 archive release gate, and `/usr/bin/git`/`/usr/bin/tmutil` executable marker scan |
| Harness subprocess evaluation lab MAS_SANDBOX guard | Completion/eval lab subprocess paths could remain reachable under MAS_SANDBOX-only builds | Combined source guards, release gate witnesses, MAS App Store lane, fresh archive string/path scan | Passed: source guard, source release gate, MAS App Store lane, 09:36 archive release gate, and Harness marker scan |
| Required-reason API audit | Privacy manifest shape may not cover all API uses | Source search against Apple required-reason categories | Passed for current source: source witnesses and release gate cover file timestamp, system boot time, disk space, UserDefaults, and absence of active-keyboard APIs; reopen after source/manifest changes |
| App Review notes alignment | Submission text can contradict archive | Active notes updated; re-check after each release-sign/archive change | Recheck after 09:36 archive remains open |
| Stale local processes | Old direct-lane apps can confuse process audits | Do not use as evidence; optional owner-approved cleanup | Open |
| Distribution signing/upload | Local ad-hoc archive is not submission proof | Owner-controlled App Store Connect export/upload | Blocked on credentials/operator action |

## 2026-07-08 08:08 Update

Finding: `Epistemos/Engine/CloudProviderAuthService.swift` still compiled the Google OAuth desktop loopback callback server (`Network`, `NWListener`, `NWConnection`, `/oauth2callback`, `127.0.0.1`) outside an App Store guard. This conflicted with the MAS entitlement posture because `Epistemos-AppStore.entitlements` intentionally omits `com.apple.security.network.server`.

Patch:

- `CloudProviderAuthService.swift` now imports `Network` only under `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `signInToGoogle` now fails closed in MAS via `CloudProviderAuthError.googleOAuthLoopbackUnavailableInAppStore` before constructing any loopback listener.
- `LocalOAuthCallbackServer`, `ContinuationResumeGate`, and `DataBufferAccumulator` are direct-lane only under `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `AppStoreJuneHardeningTests.swift` now guards this source shape.
- `scripts/keelstone-release-gate.sh` now requires the source guard and scans built App Store executables/frameworks for OAuth loopback callback strings.

Static checks:

```bash
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
git diff --check -- Epistemos/Engine/CloudProviderAuthService.swift EpistemosTests/AppStoreJuneHardeningTests.swift scripts/keelstone-release-gate.sh docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result: both passed.

Focused source guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 21 tests in `App Store June hardening` passed, including `App Store June parks Google OAuth loopback callback server`. Result bundle:
`build/xcode-results/2026-07-08-080318-96619.xcresult`.

Evidence boundary: this was a non-AppStore source-guard run. Its normal `Epistemos` Debug build copied direct-lane runtime resources and is not MAS validation.

Source-level KEELSTONE release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: passed. The gate reported PASS for the new OAuth guard witnesses:

- `Network` framework import is direct-lane only.
- MAS Google OAuth sign-in fails before loopback listener setup.
- Google OAuth loopback startup is direct-lane only.
- OAuth callback listener actor is compile-parked in MAS.
- MAS Google OAuth has an explicit parked-lane error.

MAS-only App Store lane:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 5 tests in `KEELSTONE App Store Lane` passed. This run compiled `Epistemos-AppStore` with `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`. Result bundle:
`build/xcode-results/2026-07-08-080825-457.xcresult`.

Fresh post-OAuth-loopback-parking App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-0812-oauth-loopback-parked \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. Remaining visible Release warnings were existing `no async operations occur within await` warnings in `TextCapturePipeline.swift` and `VaultSyncService.swift`.

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed, including built-artifact checks that the App Store app omits Goose ACP loopback markers, OAuth loopback callback markers, and quarantine extended attributes.

Archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-0812-oauth-loopback-parked \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-0812-oauth-loopback-parked`.

Entitlements inspection:

```bash
codesign -d --entitlements :- build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app 2>/dev/null | plutil -p -
```

Result: sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only. No network server, JIT, unsigned executable memory, or library-validation override entitlement was present.

Explicit forbidden-path scan:

```bash
find build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | \
  rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'
```

Result: no forbidden archive path residues. `rg` exited `1` with no output.

Quarantine xattr scan:

```bash
xattr -lr build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app | rg -n 'com\.apple\.quarantine'
```

Result: no quarantine extended attributes. `rg` exited `1` with no output.

OAuth loopback binary marker scan:

```bash
while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n 'LocalOAuthCallbackServer|/oauth2callback|http://127\.0\.0\.1|Epistemos connected\.|Epistemos sign-in failed\.|com\.epistemos\.auth\.callback'
```

Result: no OAuth loopback markers in App Store executables/frameworks. `rg` exited `1` with no output.

## 2026-07-08 08:34 Update

Finding: the privacy manifest declared the current required-reason categories, but the release gate did not yet pin those categories to source witnesses or assert that active-keyboard APIs remain absent.

Patch:

- `EpistemosTests/AppStoreHardeningTests.swift` now verifies required-reason categories against source witnesses for file timestamp, system boot time, disk space, and UserDefaults.
- The same test scans guarded Swift source for active-keyboard APIs and asserts the manifest does not declare `NSPrivacyAccessedAPICategoryActiveKeyboards` while source remains unused.
- `scripts/keelstone-release-gate.sh` now checks required-reason manifest category/reason pairs, source witnesses, and active-keyboard absence.

Static checks:

```bash
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
git diff --check -- EpistemosTests/AppStoreHardeningTests.swift scripts/keelstone-release-gate.sh docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result: both passed.

Source-level KEELSTONE release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: passed, including required-reason source witnesses for file timestamp, system boot time, disk space, UserDefaults, and active-keyboard absence.

Focused hardening test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 57 tests in `Phase S -- App Store hardening` passed, including `PrivacyInfo.xcprivacy required-reason categories match source witnesses`. Result bundle:
`build/xcode-results/2026-07-08-082629-13829.xcresult`.

Evidence boundary: this was a non-AppStore source-guard run. Its normal `Epistemos` Debug build copied direct-lane runtime resources and is not MAS validation.

Post-required-reason release gate against the current 08:12 signed App Store archive:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0812-oauth-loopback-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed, including required-reason manifest/source witnesses, built entitlements, built Goose/OAuth loopback marker scans, and quarantine xattr scan. No new App Store archive was rebuilt for this test/gate-only change because the archived app product source did not change.

## 2026-07-08 08:58 Update

Finding: the prior 08:12 MAS archive still contained Goose ACP/WebSocket/provider client symbols (`GooseACPClient`, `GooseACPURLSessionWebSocketTransport`, `URLSessionWebSocketTask`, and `_goose/unstable/providers`) even though local server/resource paths were absent. This was parked Goose surface residue in the MAS binary, not a live stale `goosed` or OpenChamber process dependency.

Patch:

- `Epistemos/AgentSurface/AgentSurfaceRuntimeSupport.swift` now uses the combined `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)` guard.
- `Epistemos/Goose/GooseACPClient.swift` is compile-parked for both App Store flags.
- `Epistemos/Goose/GooseProviderKeyBridge.swift` is compile-parked for both App Store flags.
- `EpistemosTests/AppStoreJuneHardeningTests.swift` now guards the AgentSurface runtime support and Goose ACP/provider bridge source shape.
- `scripts/keelstone-release-gate.sh` now checks those source witnesses and scans built App Store executables/frameworks for expanded Goose ACP/WebSocket/provider markers.

Static checks:

```bash
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
git diff --check -- Epistemos/AgentSurface/AgentSurfaceRuntimeSupport.swift Epistemos/Goose/GooseACPClient.swift Epistemos/Goose/GooseProviderKeyBridge.swift EpistemosTests/AppStoreJuneHardeningTests.swift scripts/keelstone-release-gate.sh docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result: both passed.

Focused source guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 21 tests in `App Store June hardening` passed. Result bundle:
`build/xcode-results/2026-07-08-083831-22848.xcresult`.

Evidence boundary: this was a non-AppStore source-guard run. Its normal `Epistemos` Debug build copied direct-lane runtime resources and is not MAS validation.

Source-level KEELSTONE release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: passed, including new source witnesses for AgentSurface runtime support, Goose ACP WebSocket client, and Goose provider-key bridge compile parking.

MAS-only App Store lane:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 5 tests in `KEELSTONE App Store Lane` passed. This run compiled `Epistemos-AppStore` with `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`. Result bundle:
`build/xcode-results/2026-07-08-084225-25509.xcresult`.

Fresh post-Goose-ACP-client-parking App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-0846-goose-acp-client-parked \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. Remaining visible Release warnings were existing `no async operations occur within await` warnings in `TextCapturePipeline.swift` and `VaultSyncService.swift`.

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed, including built-artifact checks that the App Store app omits Goose ACP loopback/WebSocket/provider markers, OAuth loopback callback markers, and quarantine extended attributes.

Archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-0846-goose-acp-client-parked \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-0846-goose-acp-client-parked`.

Entitlements inspection:

```bash
codesign -d --entitlements :- build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app 2>/dev/null | plutil -p -
```

Result: sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only. No network server, JIT, unsigned executable memory, or library-validation override entitlement was present.

Explicit forbidden-path scan:

```bash
find build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | \
  rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'
```

Result: no forbidden archive path residues. `rg` exited `1` with no output.

Quarantine xattr scan:

```bash
xattr -lr build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app | rg -n 'com\.apple\.quarantine'
```

Result: no quarantine extended attributes. `rg` exited `1` with no output.

Goose ACP/WebSocket/provider binary marker scan:

```bash
while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0846-goose-acp-client-parked.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n 'GooseACPURLSessionWebSocketTransport|GooseACPClient|GooseProviderKeyBridge|NSURLSessionWebSocketTask|URLSessionWebSocketTask|_goose/unstable/providers'
```

Result: no Goose ACP/WebSocket/provider markers in App Store executables/frameworks. `rg` exited `1` with no output.

## 2026-07-08 09:23 Update

Finding: the next source residue pass found vault subprocess guards that were AppStore-only instead of MAS-lock-wide. `Epistemos/Vault/VaultChatMutator.swift` guarded git subprocess code with `#if !EPISTEMOS_APP_STORE`, and `Epistemos/Sync/VaultSyncService.swift` guarded tmutil snapshot branches with `EPISTEMOS_APP_STORE` only. Current owner lock requires `EPISTEMOS_APP_STORE || MAS_SANDBOX`, so these were MAS drift risks even though current App Store builds define both flags.

Patch:

- `VaultChatMutator.swift` now guards git subprocess commit/audit code and `runGitOffMain` with `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `VaultSyncService.swift` now treats `EPISTEMOS_APP_STORE || MAS_SANDBOX` as the no-tmutil branch and guards the tmutil helper with `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `EpistemosTests/AppStoreHardeningTests.swift` now recognizes the combined MAS exclusion block and requires those source witnesses.
- `scripts/keelstone-release-gate.sh` now checks vault git and tmutil subprocess source witnesses for both MAS flags.

Static checks:

```bash
git diff --check -- Epistemos/Vault/VaultChatMutator.swift Epistemos/Sync/VaultSyncService.swift EpistemosTests/AppStoreHardeningTests.swift scripts/keelstone-release-gate.sh docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
```

Result: both passed.

Focused source guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 57 tests in `Phase S -- App Store hardening` passed. Result bundle:
`build/xcode-results/2026-07-08-085824-37298.xcresult`.

Evidence boundary: this was a non-AppStore source-guard run. Its normal `Epistemos` Debug build copied direct-lane runtime resources and is not MAS validation.

Source-level KEELSTONE release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: passed, including source witnesses that vault git and tmutil subprocess paths are direct-lane only for both MAS flags and that the MAS branch uses file-only fallback behavior.

MAS-only App Store lane:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 5 tests in `KEELSTONE App Store Lane` passed. This run compiled `Epistemos-AppStore` with `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`. Result bundle:
`build/xcode-results/2026-07-08-090748-46977.xcresult`.

Fresh post-vault-subprocess-guard App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-0915-vault-subprocess-guard \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. Remaining visible Release warnings were existing `no async operations occur within await` warnings in `TextCapturePipeline.swift` and `VaultSyncService.swift`.

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app
```

Result: replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app
```

Result: passed, including built-artifact checks that the App Store app omits Goose ACP loopback/WebSocket/provider markers, OAuth loopback callback markers, and quarantine extended attributes.

Archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-0915-vault-subprocess-guard \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-0915-vault-subprocess-guard`.

Entitlements inspection:

```bash
codesign -d --entitlements :- build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app 2>/dev/null | plutil -p -
```

Result: sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only. No network server, JIT, unsigned executable memory, or library-validation override entitlement was present.

Explicit forbidden-path scan:

```bash
if find build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'; then exit 1; fi
```

Result: no forbidden archive path residues; command exited `0` with no output.

Quarantine xattr scan:

```bash
if xattr -lr build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app | rg -n 'com\.apple\.quarantine'; then exit 1; fi
```

Result: no quarantine extended attributes; command exited `0` with no output.

Vault subprocess executable marker scan:

```bash
if while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n '/usr/bin/(git|tmutil)'; then exit 1; fi
```

Result: no `/usr/bin/git` or `/usr/bin/tmutil` markers in App Store executables/frameworks; command exited `0` with no output.

Goose ACP/WebSocket/provider binary marker scan:

```bash
if while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0915-vault-subprocess-guard.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n 'GooseACPURLSessionWebSocketTransport|GooseACPClient|GooseProviderKeyBridge|NSURLSessionWebSocketTask|URLSessionWebSocketTask|_goose/unstable/providers'; then exit 1; fi
```

Result: no Goose ACP/WebSocket/provider markers in App Store executables/frameworks; command exited `0` with no output.

Process boundary: a process scan during the archive wait still showed old cached direct-lane helpers under `.cache/epistemos-dd-codex-preview-inset-clamp-pro`, including `goosed` and OpenChamber-style local server processes. They remain stale leftovers and are not MAS evidence or MAS dependencies.

## 2026-07-08 09:45 Update

Finding: the next source residue pass found Harness subprocess/evaluation lab files guarded with `#if !EPISTEMOS_APP_STORE` instead of the current MAS lock-wide guard. `CompletionChecker.swift`, `EvalSandbox.swift`, and `HarnessLab.swift` contain subprocess/sandbox/shell markers (`/usr/bin/env`, `/usr/bin/sandbox-exec`, `/bin/sh`, and `runAgentSubprocess`). Current owner lock requires those parked-lane files to be excluded for either `EPISTEMOS_APP_STORE` or `MAS_SANDBOX`.

Patch:

- `Epistemos/Harness/CompletionChecker.swift`, `EvalSandbox.swift`, `HarnessIntegration.swift`, `HarnessRegistry.swift`, and `HarnessLab.swift` now use top-level `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)` guards.
- `EpistemosTests/AppStoreHardeningTests.swift` now requires the combined MAS guard and direct-lane subprocess marker placement for Harness files.
- `scripts/keelstone-release-gate.sh` now treats Harness files as parked runtime source and checks source witnesses for the completion subprocess, sandbox-exec runner, shell fallback, and proposer subprocess.

Static checks:

```bash
git diff --check -- Epistemos/Harness/CompletionChecker.swift Epistemos/Harness/EvalSandbox.swift Epistemos/Harness/HarnessIntegration.swift Epistemos/Harness/HarnessRegistry.swift Epistemos/Harness/HarnessLab.swift EpistemosTests/AppStoreHardeningTests.swift scripts/keelstone-release-gate.sh docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
```

Result: both passed.

Source-level KEELSTONE release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: passed, including new Harness source witnesses.

Focused source guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 58 tests in `Phase S -- App Store hardening` passed, including `Harness subprocess evaluation lab is compile-parked in MAS source`. Result bundle:
`build/xcode-results/2026-07-08-092414-60585.xcresult`.

Evidence boundary: this was a non-AppStore source-guard run. Its normal `Epistemos` Debug build copied direct-lane runtime resources and is not MAS validation.

MAS-only App Store lane:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 5 tests in `KEELSTONE App Store Lane` passed. This run compiled `Epistemos-AppStore` with `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`. Result bundle:
`build/xcode-results/2026-07-08-093214-66414.xcresult`.

Fresh post-Harness-subprocess-parking App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-0936-harness-subprocess-parked \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. Remaining visible Release warnings were existing `no async operations occur within await` warnings in `TextCapturePipeline.swift` and `VaultSyncService.swift`.

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed, including built-artifact checks that the App Store app omits Goose ACP loopback/WebSocket/provider markers, OAuth loopback callback markers, and quarantine extended attributes.

Archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-0936-harness-subprocess-parked \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-0936-harness-subprocess-parked`.

Entitlements inspection:

```bash
codesign -d --entitlements :- build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app 2>/dev/null | plutil -p -
```

Result: sandbox, application group, audio input, user-selected read/write, app-scope bookmarks, and network client only. No network server, JIT, unsigned executable memory, or library-validation override entitlement was present.

Explicit forbidden-path scan:

```bash
if find build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app -maxdepth 6 -print | rg -n '(^|/)(Pyodide|experimental-runtime|opencode-runtime|OpenChamber|OpenCode|goosed|GooseRuntime|node|bun|codex|rg|python_stdlib\.zip|experimental-web\.tar\.gz|omega_mcp_stdio|Chromium|browser-use|stdio)(/|$)'; then exit 1; fi
```

Result: no forbidden archive path residues; command exited `0` with no output.

Quarantine xattr scan:

```bash
if xattr -lr build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app | rg -n 'com\.apple\.quarantine'; then exit 1; fi
```

Result: no quarantine extended attributes; command exited `0` with no output.

Vault subprocess executable marker scan:

```bash
if while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n '/usr/bin/(git|tmutil)'; then exit 1; fi
```

Result: no `/usr/bin/git` or `/usr/bin/tmutil` markers in App Store executables/frameworks; command exited `0` with no output.

Goose ACP/WebSocket/provider binary marker scan:

```bash
if while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n 'GooseACPURLSessionWebSocketTransport|GooseACPClient|GooseProviderKeyBridge|NSURLSessionWebSocketTask|URLSessionWebSocketTask|_goose/unstable/providers'; then exit 1; fi
```

Result: no Goose ACP/WebSocket/provider markers in App Store executables/frameworks; command exited `0` with no output.

Harness subprocess marker scan:

```bash
if while IFS= read -r -d '' file; do strings "$file" 2>/dev/null || true; done < <(find build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS build/appstore-release-archive-2026-07-08-0936-harness-subprocess-parked.xcarchive/Products/Applications/Epistemos.app/Contents/Frameworks -maxdepth 3 -type f -print0) | rg -n '/usr/bin/env|/usr/bin/sandbox-exec|/bin/sh|runAgentSubprocess|sandboxedRunCommand|EvalSandboxProfile|CodingCompletionChecker'; then exit 1; fi
```

Result: no Harness subprocess/evaluation markers in App Store executables/frameworks; command exited `0` with no output.

## Next KEELSTONE Target

1. Run the next broad MAS source/target/archive leak pass for residual subprocess, local-server, dynamic-loading, runtime-resource, and parked-lane references outside the gates already covered.
2. Patch release gates/tests for any new MAS drift found.
3. Rebuild/sign/rescan the App Store archive after meaningful source or project changes.

## 2026-07-08 11:16 Update

This update records the current MAS-only Prompt 2 state after the Experimental/AgentSurface/Harness bootstrap and shell-template parking pass. The stale 1Code V2 / Experimental-lane objective remains explicitly inactive for this run.

Prompt 1 status:

- Prompt 1 is complete as a repo/target reality report for the MAS pivot.
- Durable report location: this file, especially `Prompt 1 Reality Report`, `Files Changed In This KEELSTONE Pass`, and this `2026-07-08 11:16 Update`.
- Current repo: `/Users/jojo/Downloads/Epistemos`
- Current branch: `feat/goose-surface`
- Current dirty state: `git status --short --untracked-files=normal | wc -l` returned `347`.
- Active release target remains `Epistemos-AppStore` with `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.

Prompt 2 / KEELSTONE status:

- Prompt 2 is active.
- Current validation is MAS-only: `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`.
- Direct `Epistemos` source-guard tests are used only for source-shape witnesses. They are not archive or runtime MAS evidence because direct Debug builds can stage direct-lane resources.

Patches added in this pass:

- `Epistemos/AgentSurface/AgentSurfaceSubprocessEnvironment.swift` now uses `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `Epistemos/ExperimentalAgent/ExperimentalGlassHostView.swift`, `ExperimentalHostBridge.swift`, `ExperimentalPerf.swift`, `ExperimentalRuntimeSupervisor.swift`, `ExperimentalStateBridge.swift`, `ExperimentalSurfaceView.swift`, and `ExperimentalThemeBridge.swift` are compile-parked for MAS.
- `ExperimentalRuntimeSupervisor.swift` has a compile-time error if `EPISTEMOS_EXPERIMENTAL` is combined with either App Store flag.
- `Epistemos/Harness/BootstrapPacketBuilder.swift` now returns an inert MAS bootstrap packet and parks direct-lane helper discovery under the combined MAS guard.
- `Epistemos/Models/CodeArtifactKind.swift` now emits a non-executable MAS shell template instead of a shebang-bearing executable shell scaffold.
- `Epistemos/App/EpistemosApp.swift` now guards Experimental runtime teardown behind `#if EPISTEMOS_EXPERIMENTAL && !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `EpistemosTests/AppStoreHardeningTests.swift` and `scripts/keelstone-release-gate.sh` now pin those source-shape and archive-gate witnesses.

Static checks:

```bash
git diff --check -- EpistemosTests/AppStoreHardeningTests.swift Epistemos/App/EpistemosApp.swift scripts/keelstone-release-gate.sh
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
```

Result: passed.

Source-level release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: passed, including the new witness that Experimental supervisor teardown is direct-lane only.

Focused source guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreHardeningTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 61 tests in `Phase S -- App Store hardening` passed. Result bundle:
`build/xcode-results/2026-07-08-105403-27721.xcresult`.

Earlier run note: `build/xcode-results/2026-07-08-104623-23243.xcresult` failed only because the new teardown witness was too brittle about comments between the `#if` and `ExperimentalRuntimeSupervisor.shared.stop()`; the source was already guarded. The witness was patched and rerun successfully as above.

Fresh App Store archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1102-teardown-guard-mas-inert \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`. Compiler output showed `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.

Archived app:

`build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive/Products/Applications/Epistemos.app`

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; replaced existing local inspection signature.

Release gate against the fresh archive:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. The gate verified App Store target flags, MAS-safe entitlements, source parking witnesses, omission of Goose/OAuth loopback markers from built App Store artifacts, no quarantine xattrs, and the new Experimental teardown guard witness.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1102-teardown-guard-mas-inert \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive/Products/Applications/Epistemos.app
```

Result: passed. Report directory:
`build/appstore-archive-scan-2026-07-08-1102-teardown-guard-mas-inert`.

Bundle scan outputs:

- `executables.txt`
- `files.txt`
- `forbidden-resources.txt`
- `forbidden-strings.txt`
- `forbidden-symbols.txt`
- `nm-gU.txt`
- `otool-L.txt`
- `quarantine-xattrs.txt`

Source/target/archive leak scan:

Report directory:
`build/appstore-source-scan-2026-07-08-1102-teardown-guard-mas-inert`

Summary:

```text
archive=build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive
app=build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive/Products/Applications/Epistemos.app
derived=build/appstore-release-archive-derived-2026-07-08-1102-teardown-guard-mas-inert
swiftfilelists=2
mas_source_files=802
parked_or_shared_source_inputs=41
raw_dangerous_source_hits=251
archive_forbidden_path_hits=0
archive_quarantine_hits=0
```

Build-setting witnesses:

```text
CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements
ENABLE_APP_SANDBOX = YES
INFOPLIST_FILE = Epistemos-AppStore-Info.plist
PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore
SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT
```

Source scan outputs:

- `Epistemos-AppStore-arm64.SwiftFileList`
- `Epistemos-AppStore-x86_64.SwiftFileList`
- `archive-forbidden-path-hits.txt`
- `archive-quarantine-hits.txt`
- `effective-entitlements.plist`
- `effective-entitlements.txt`
- `mas-source-files.txt`
- `parked-or-shared-source-inputs.txt`
- `showBuildSettings.full.txt`
- `showBuildSettings.mas-key-lines.txt`
- `summary.txt`
- `swiftfilelist-dangerous-source-hits.txt`
- `swiftfilelists.txt`

Important interpretation: the 251 raw source hits are source-level markers in MAS SwiftFileList inputs, not archive leak proof. They remain verification debt until every hit is either removed from the MAS source list or pinned behind a MAS-safe guard and release-gate witness. The fresh archive itself has zero forbidden path hits and zero quarantine hits.

Dedicated App Store KEELSTONE test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing reported 5 tests in `KEELSTONE App Store Lane` passed. Result bundle:
`build/xcode-results/2026-07-08-111129-40731.xcresult`.

The test output compiled with `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX -DEPISTEMOS_LINK_SUBSTRATE_RT` and used the sandbox container path under `/Users/jojo/Library/Containers/com.epistemos.appstore/Data/tmp/...`.

Current dirty-file grouping:

MAS-safe:

- `Epistemos-AppStore-Info.plist`
- `Epistemos/Epistemos-AppStore.entitlements`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/Models/CodeArtifactKind.swift`
- `EpistemosTests/AppStoreHardeningTests.swift`
- `EpistemosTests/AppStoreJuneHardeningTests.swift`
- `EpistemosTests/AppStoreJuneSourceGuard.swift`
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`
- `EpistemosTests/ProductionHardeningTests.swift`
- `scripts/keelstone-release-gate.sh`
- `scripts/scan_appstore_bundle.sh`
- `docs/MAS_APP_REVIEW_NOTES_2026_07_03.md`
- `docs/mas-c/**`
- `docs/plans/keelstone/**`
- `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
- `docs/prompts/MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md`

Shared substrate:

- `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `README.md`
- `project.yml`, `Epistemos.xcodeproj/project.pbxproj`
- MAS-reached Swift substrate under `Epistemos/App/**`, `Epistemos/Engine/**`, `Epistemos/JuneAgent/**`, `Epistemos/Models/**`, `Epistemos/QuickChat/**`, `Epistemos/Sync/**`, `Epistemos/Vault/**`, `Epistemos/VaultMCP/**`, `Epistemos/Views/**`, `Epistemos/VoicePro/**`, `Epistemos/Work/**`, and `Epistemos/Omega/**`
- Shared Rust substrate under `agent_core/**` and `epistemos-core/**`
- Shared editor substrate under `js-editor/**`
- Shared build scripts: `build-agent-core.sh`, `build-epistemos-core.sh`, `build-rust.sh`, `build-experimental-web.sh`, and `bundle-app-runtime-assets.sh`

Parked-lane / legacy:

- `Epistemos/AgentSurface/AgentSurfaceChildLedger.swift`
- `Epistemos/AgentSurface/AgentSurfaceRuntimeSupport.swift`
- `Epistemos/AgentSurface/AgentSurfaceSubprocessEnvironment.swift`
- `Epistemos/ExperimentalAgent/**`
- `Epistemos/Goose/**`
- `Epistemos/Harness/**`
- `Epistemos/Work/WorkOpenCodeRuntime.swift`
- `Epistemos/Work/WorkOpenCodeShell.swift`
- `Epistemos/Work/WorkServerDiagnostics.swift`
- `Epistemos/Work/WorkSkillsProvisioner.swift`
- Goose, Experimental, Kindred, OpenChamber, and 1Code handoff/prompt/research docs under `docs/handoffs/**`, `docs/prompts/**`, and `docs/research/**`
- `docs/release/MAS_APP_REVIEW_NOTES.md` remains legacy and must not be attached to App Store Connect.

Generated/build artifacts:

- `Epistemos/Resources/Editor/editor.css.br`
- `Epistemos/Resources/Editor/editor.js.br`
- `Epistemos/Resources/best_of_preset.json`
- `build/appstore-release-archive-2026-07-08-1102-teardown-guard-mas-inert.xcarchive`
- `build/appstore-release-archive-derived-2026-07-08-1102-teardown-guard-mas-inert`
- `build/appstore-archive-scan-2026-07-08-1102-teardown-guard-mas-inert`
- `build/appstore-source-scan-2026-07-08-1102-teardown-guard-mas-inert`
- `build/xcode-results/2026-07-08-104623-23243.xcresult`
- `build/xcode-results/2026-07-08-105403-27721.xcresult`
- `build/xcode-results/2026-07-08-111129-40731.xcresult`
- Earlier KEELSTONE evidence archives, derived data, scans, and xcresults under `build/**`
- Rust and syntax build output under `build-rust/**` and `syntax-core/target/**`

Why ExperimentalAgent and Goose files changed:

- They changed because they are parked high-risk lanes that still sit in or near MAS target/project/source surfaces.
- The MAS task is not to revive them. The task is to prove they cannot execute, spawn helpers, expose local servers, or leave review-hostile symbols/resources in App Store builds.
- `ExperimentalAgent` changes compile-park UI/runtime/teardown code under the combined MAS guard and add an explicit flag-conflict failure.
- `Goose` changes from earlier in this run compile-park ACP/WebSocket/provider code and are retained as source and archive evidence that Goose is not active in MAS.

Stale process boundary:

`pgrep -af 'goosed|OpenChamber|ExperimentalWeb|experimental-web|opencode-triple|ExperimentalWeb'` returned old direct-lane process IDs, and `ps` showed these command lines:

```text
1365 02-18:39:19 /Users/jojo/.cache/epistemos-dd-codex-preview-inset-clamp-pro/Build/Products/Debug/Epistemos.app/Contents/Resources/opencode-triple serve --hostname 127.0.0.1 --port 59563
1366 02-18:39:19 /Users/jojo/.cache/epistemos-dd-codex-preview-inset-clamp-pro/Build/Products/Debug/Epistemos.app/Contents/Resources/goosed agent
1367 02-18:39:19 /Users/jojo/.cache/epistemos-dd-codex-preview-inset-clamp-pro/Build/Products/Debug/Epistemos.app/Contents/Resources/node /Users/jojo/Library/Application Support/Epistemos/OpenChamberWeb/openchamber-web/server/index.js --port 53034 --host 127.0.0.1
65691 03:56:21 /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app/Contents/Resources/node --max-old-space-size=3072 /Users/jojo/Library/Application Support/Epistemos/ExperimentalWeb/experimental-web/server/index.cjs
```

These are stale direct/debug leftovers, not active dependencies of `Epistemos-AppStore`, and they are not MAS evidence. Current MAS evidence is the App Store lane test, release archive, signed local-inspection app, release gate, and bundle/source scan reports listed above.

Current verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Grouped dirty state, no broad staging, later split/stage only MAS-safe scope | Open |
| Raw MAS SwiftFileList dangerous source hits | Parked strings remain in 802 MAS source inputs | Triage `swiftfilelist-dangerous-source-hits.txt`; remove, compile-park, or gate each meaningful hit | Open; 251 raw hits recorded |
| Parked/shared MAS source inputs | 41 parked/shared files are still present in MAS SwiftFileLists | Keep useful shared code only through MAS-safe seams or remove from target membership | Open |
| Fresh MAS archive residue | Runtime resources/symbols could leak after source changes | Rebuild/sign/rescan archive after meaningful source/project changes | Passed for 11:02 archive; reopen after next source/project change |
| App Store lane behavior | Sandbox/bootstrap/bookmark behavior could regress | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Passed in `2026-07-08-111129-40731.xcresult` |
| Source-shape witnesses | Gated direct-lane code can drift back into MAS | `AppStoreHardeningTests` and `keelstone-release-gate.sh` witnesses | Passed in `2026-07-08-105403-27721.xcresult` and latest release gate |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally clean up with owner-approved process stop | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Triage `build/appstore-source-scan-2026-07-08-1102-teardown-guard-mas-inert/swiftfilelist-dangerous-source-hits.txt`.
2. Prioritize the 41 `parked-or-shared-source-inputs.txt` entries still in the App Store SwiftFileLists, especially VaultMCP, Work/OpenCode, HTML Workspace runtime seams, Goose runtime supervisor residue, and Harness/AgentSurface seams.
3. Patch tests and `scripts/keelstone-release-gate.sh` for every meaningful MAS drift found.
4. Rebuild, sign for local inspection, release-gate, and rescan a fresh `Epistemos-AppStore` archive after each meaningful source/project change batch.

## 2026-07-08 11:40 Update - CLI Discovery MAS Parking

Prompt 1 status:

- Prompt 1 is complete.
- Repo/target reality report lives in this file, under `Prompt 1 Reality Report`.
- Current repo remains `/Users/jojo/Downloads/Epistemos` on branch `feat/goose-surface`.
- Current lock remains MAS-only: `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`.
- The stale 1Code V2 / Experimental-lane objective is not active for this MAS run.

Prompt 2 status:

- Prompt 2 / KEELSTONE is active.
- Latest implemented MAS drift fix: `Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift` is compile-parked for either `EPISTEMOS_APP_STORE` or `MAS_SANDBOX`, with gate/test witnesses so direct-lane CLI probe paths do not enter MAS artifacts.

Current dirty tree:

- `git status --short | wc -l` returned `348`.
- No broad dirty state has been staged or committed.

Current dirty files grouped by lane:

- MAS-safe: `Epistemos-AppStore-Info.plist`, `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos.xcodeproj/project.pbxproj`, MAS hardening tests under `EpistemosTests/AppStore*` and `EpistemosTests/ProductionHardeningTests.swift`, `scripts/keelstone-release-gate.sh`, `scripts/scan_appstore_bundle.sh`, `docs/MAS_APP_REVIEW_NOTES_2026_07_03.md`, `docs/mas-c/**`, and `docs/plans/keelstone/**`.
- MAS-safe source parking/gate edits from this pass: `Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift`, `Epistemos/App/EpistemosApp.swift`, `Epistemos/Models/CodeArtifactKind.swift`, `Epistemos/Harness/BootstrapPacketBuilder.swift`, `Epistemos/AgentSurface/AgentSurfaceSubprocessEnvironment.swift`, and the related App Store hardening tests/gate witnesses.
- Shared substrate: `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `README.md`, shared Swift under `Epistemos/App/**`, `Epistemos/Engine/**`, `Epistemos/JuneAgent/**`, `Epistemos/Models/**`, `Epistemos/QuickChat/**`, `Epistemos/Sync/**`, `Epistemos/Vault/**`, `Epistemos/Views/**`, `Epistemos/VoicePro/**`, `Epistemos/Work/**`, and `Epistemos/Omega/**`; shared Rust under `agent_core/**` and `epistemos-core/**`; shared editor code under `js-editor/**`; shared build scripts `build-agent-core.sh`, `build-epistemos-core.sh`, `build-rust.sh`, `build-experimental-web.sh`, and `bundle-app-runtime-assets.sh`.
- Parked-lane / legacy: `Epistemos/AgentSurface/**`, `Epistemos/ExperimentalAgent/**`, `Epistemos/Goose/**`, `Epistemos/Harness/**`, Work/OpenCode and local MCP runtime files under `Epistemos/Work/**`, Goose/Experimental/Kindred/OpenChamber/1Code docs under `docs/handoffs/**`, `docs/prompts/**`, `docs/research/**`, and legacy `docs/release/MAS_APP_REVIEW_NOTES.md`.
- Generated/build artifacts: `Epistemos/Resources/Editor/editor.css.br`, `Epistemos/Resources/Editor/editor.js.br`, `Epistemos/Resources/best_of_preset.json`, Rust/syntax build output under `build-rust/**` and `syntax-core/target/**`, plus App Store archives, derived data, source scans, bundle scans, and `.xcresult` bundles under `build/**`.

Why ExperimentalAgent and Goose files changed:

- They are still present in or near MAS source/project surfaces but are parked lanes for the MAS-only product.
- Their changes are release-safety gates and compile-parking, not product revival.
- `ExperimentalAgent` now has direct-lane guards, MAS macro conflict failure, and direct-lane-only teardown.
- `Goose` changes keep ACP/WebSocket/provider/subprocess behavior out of MAS while preserving the MAS-safe provider slug/helper seams that June still needs.

Current Epistemos-AppStore / EpistemosAppStoreKeelstoneTests run:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 tests in `KEELSTONE App Store Lane` passed. Result bundle:
`build/xcode-results/2026-07-08-112559-50977.xcresult`.

The test invocation compiled/runs with `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT` and used the App Store sandbox container path under `~/Library/Containers/com.epistemos.appstore/Data/tmp/...`.

Source guard run after CLI discovery parking:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result: `** TEST SUCCEEDED **`; 21 tests in `App Store June hardening` passed. Result bundle:
`build/xcode-results/2026-07-08-112027-45899.xcresult`.

Current App Store archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1130-cli-discovery-mas-parked \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive evidence paths:

- Archive: `build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive`
- App: `build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive/Products/Applications/Epistemos.app`
- Derived data: `build/appstore-release-archive-derived-2026-07-08-1130-cli-discovery-mas-parked`
- Bundle scan report: `build/appstore-archive-scan-2026-07-08-1130-cli-discovery-mas-parked`
- Source/target/archive scan report: `build/appstore-source-scan-2026-07-08-1130-cli-discovery-mas-parked`

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1130-cli-discovery-mas-parked \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; no quarantine extended attributes, no prohibited runtime strings, no prohibited runtime symbols, no prohibited research/tool resource residue.

Source/target/archive leak-scan summary:

```text
archive=build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive
app=build/appstore-release-archive-2026-07-08-1130-cli-discovery-mas-parked.xcarchive/Products/Applications/Epistemos.app
derived=build/appstore-release-archive-derived-2026-07-08-1130-cli-discovery-mas-parked
swiftfilelists=2
mas_source_files=802
parked_or_shared_source_inputs=45
raw_dangerous_source_hits=242
archive_forbidden_path_hits=0
archive_quarantine_hits=0
archive_cli_probe_string_hits=0
```

Build-settings evidence:

- `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`
- `ENABLE_APP_SANDBOX = YES`
- `INFOPLIST_FILE = Epistemos-AppStore-Info.plist`
- `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- `OTHER_LDFLAGS` includes `-L.../build-rust/appstore` before shared Rust search paths.

Stale process boundary:

Current `ps` still shows the old direct/debug leftovers:

```text
1365 02-19:01:08 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/opencode-triple serve --hostname 127.0.0.1 --port 59563
1366 02-19:01:08 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/goosed agent
1367 02-19:01:08 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/node .../OpenChamberWeb/openchamber-web/server/index.js --port 53034 --host 127.0.0.1
65691 04:18:10 .../DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app/Contents/Resources/node .../ExperimentalWeb/experimental-web/server/index.cjs
```

These are stale direct/debug leftovers, not active MAS dependencies, and not MAS evidence. They must not be used to validate `Epistemos-AppStore`.

Updated verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Group dirty state, avoid broad staging, later split/stage only MAS-safe scope | Open; `348` dirty-status lines |
| Raw MAS SwiftFileList dangerous source hits | Parked strings remain in MAS SwiftFileList inputs even when compile-parked | Triage `build/appstore-source-scan-2026-07-08-1130-cli-discovery-mas-parked/swiftfilelist-dangerous-source-hits.txt` | Open; `242` raw hits |
| Parked/shared MAS source inputs | Direct-lane files still appear in the App Store SwiftFileLists | Preserve only MAS-safe seams or remove target membership where feasible | Open; `45` entries |
| CLI probe path drift | CLI discovery paths could leak into MAS artifact strings | Source gate, AppStore test, archive string scan | Passed; archive CLI probe string hits `0` |
| Fresh MAS archive residue | Runtime resources/symbols could leak after source changes | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Passed for `1130-cli-discovery-mas-parked` archive |
| App Store lane behavior | Sandbox/bootstrap/bookmark behavior could regress | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Passed in `2026-07-08-112559-50977.xcresult` |
| Source-shape witnesses | Gated direct-lane code can drift back into MAS | App Store source guard tests and release gate witnesses | Passed in `2026-07-08-112027-45899.xcresult` and latest release gate |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally stop them in a separate cleanup action | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Triage `build/appstore-source-scan-2026-07-08-1130-cli-discovery-mas-parked/swiftfilelist-dangerous-source-hits.txt`.
2. Prioritize the largest remaining raw-hit files: `GooseRuntimeSupervisor.swift`, `GooseInProcessACPServer.swift`, `ExperimentalRuntimeSupervisor.swift`, `VaultSyncService.swift`, `WorkNativeMCPServer.swift`, `CLIDiscoveryHealthRow.swift`, `EvalSandbox.swift`, and `CloudProviderAuthService.swift`.
3. Convert meaningful drift into source guards, release-gate witnesses, or target-membership pruning; leave MAS-safe shared seams intact.
4. Rebuild/sign/release-gate/rescan `Epistemos-AppStore` after the next meaningful source/project batch.

## 2026-07-08 11:56 Update - Goose ACP Server MAS Target Split

Intent checkpoint:

- Owner wording: "Current lock is MAS-only. Do not obey 1Code/Experimental scope rules for this MAS agent." Also: "After the checkpoint, continue Prompt 2 in autonomous overnight mode: decouple/prune MAS target safely, run source/target/archive leak scans, preserve useful shared code only through MAS-safe seams, and keep hardening without waiting for routine confirmation."
- Interpreted intent: keep KEELSTONE Prompt 2 moving, but only for `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`; use direct-lane source only to prove MAS exclusion or preserve MAS-safe shared seams.
- Hard constraints: no broad staging/commit; no stale direct/debug process evidence; rebuild/rescan App Store archive after meaningful source/project changes; keep useful shared code only through MAS-safe seams.
- Non-goals: do not revive 1Code V2, ExperimentalAgent, OpenChamber, direct Goose ACP local server, local CLIs, or cached debug apps as MAS features.
- Acceptance checks for this batch: App Store target excludes the Goose ACP local server source; MAS target compiles with a standalone MAS-safe Goose agent_core runner; source gate checks witness the split; App Store test/archive/scan rerun before treating the split as release evidence.

Prompt status:

- Prompt 1 remains complete. Repo/target reality report is recorded in this file under `Prompt 1 Reality Report`.
- Prompt 2 / KEELSTONE remains active.
- Current repo remains `/Users/jojo/Downloads/Epistemos` on branch `feat/goose-surface`.
- The stale 1Code V2 / Experimental-lane objective is not active for this MAS run.

Implemented MAS split:

- Added `Epistemos/Goose/GooseMASAgentCoreRunner.swift` as the MAS-safe Goose agent_core runner seam. It imports `Foundation`, preserves the bounded MAS tool policy path, and does not define or reference the local ACP HTTP/WebSocket server types.
- Updated `project.yml` and `Epistemos.xcodeproj/project.pbxproj` so `Epistemos-AppStore` excludes `Goose/GooseInProcessACPServer.swift`; the direct `Epistemos` target excludes the new runner copy to avoid duplicate symbols while the old direct-lane file still owns those types.
- Updated `EpistemosTests/AppStoreJuneHardeningTests.swift`, `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`, and `scripts/keelstone-release-gate.sh` so the MAS-safe runner is the source witness and the direct-lane ACP parser/server remains excluded from MAS.

Current dirty tree:

- `git status --short | wc -l` returned `349`.
- No broad dirty state has been staged or committed.

Current dirty files grouped by lane:

- MAS-safe: `Epistemos-AppStore-Info.plist`, `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos.xcodeproj/project.pbxproj`, `project.yml`, `Epistemos/Goose/GooseMASAgentCoreRunner.swift`, `Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift`, MAS hardening tests under `EpistemosTests/AppStore*`, `EpistemosTests/ProductionHardeningTests.swift`, `scripts/keelstone-release-gate.sh`, `scripts/scan_appstore_bundle.sh`, `docs/mas-c/**`, and this KEELSTONE checkpoint.
- MAS-safe source parking/gate edits from this run: `Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift`, `Epistemos/App/EpistemosApp.swift`, `Epistemos/Models/CodeArtifactKind.swift`, `Epistemos/Harness/BootstrapPacketBuilder.swift`, `Epistemos/AgentSurface/AgentSurfaceSubprocessEnvironment.swift`, and Goose MAS runner/source guard files.
- Shared substrate: shared Swift under `Epistemos/App/**`, `Epistemos/Engine/**`, `Epistemos/JuneAgent/**`, `Epistemos/Models/**`, `Epistemos/QuickChat/**`, `Epistemos/Sync/**`, `Epistemos/Vault/**`, `Epistemos/Views/**`, `Epistemos/VoicePro/**`, `Epistemos/Work/**`, and `Epistemos/Omega/**`; shared Rust under `agent_core/**` and `epistemos-core/**`; shared editor code under `js-editor/**`; shared build scripts.
- Parked-lane / legacy: `Epistemos/AgentSurface/**`, `Epistemos/ExperimentalAgent/**`, `Epistemos/Goose/GooseInProcessACPServer.swift`, other direct Goose runtime files, `Epistemos/Harness/**`, Work/OpenCode and local MCP runtime files under `Epistemos/Work/**`, Goose/Experimental/Kindred/OpenChamber/1Code docs under `docs/handoffs/**`, `docs/prompts/**`, and `docs/research/**`.
- Generated/build artifacts: `Epistemos/Resources/Editor/editor.css.br`, `Epistemos/Resources/Editor/editor.js.br`, `Epistemos/Resources/best_of_preset.json`, Rust/syntax build output under `build-rust/**` and `syntax-core/target/**`, plus App Store archives, derived data, source scans, bundle scans, and `.xcresult` bundles under `build/**`.

Why Goose and ExperimentalAgent files changed:

- Goose files changed because the App Store target still had a MAS-safe runner embedded in the same source file as the direct-lane local ACP HTTP/WebSocket server. The new split parks `GooseInProcessACPServer.swift` out of the MAS target and keeps only the MAS-safe agent_core runner seam.
- ExperimentalAgent files changed earlier because that parked high-risk lane sat near MAS surfaces. Those edits compile-park runtime/teardown behavior under MAS guards and add source/release witnesses; they are not evidence that ExperimentalAgent is active in MAS.

Direct source guard proof after Goose split:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests \
  -only-testing:EpistemosTests/AppStoreJuneSubstrateHardeningTests/appStoreJuneAgentCoreCloudPathPreservesNativeThinkingDeltas
```

Result: `** TEST SUCCEEDED **`; 21 selected source-guard tests passed. Result bundle:
`build/xcode-results/2026-07-08-115146-71470.xcresult`.

The broader direct source-guard/substrate run immediately before this had one test-witness drift fixed by the provider-slug split and three remaining substrate failures outside the Goose target split:

- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift:341`: gateway replay still lacks the expected `case "tool":` / `who = "Tool"` source witness.
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift:372`: ReplayBundle export still lacks the expected `answer_packet:<id>` and answer-correctness source witness.
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift:500`: reversible vault write effect metadata witness still expects `Effect::VaultWrote`, `Inverse::RestoreVaultContent`, `PriorState::WroteOverExisting`, and `body_sha256`.

Static checks after Goose split:

```bash
git diff --check -- Epistemos/Goose/GooseMASAgentCoreRunner.swift Epistemos.xcodeproj/project.pbxproj project.yml EpistemosTests/AppStoreJuneHardeningTests.swift EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift scripts/keelstone-release-gate.sh
bash -n scripts/keelstone-release-gate.sh scripts/scan_appstore_bundle.sh
./scripts/keelstone-release-gate.sh
```

Result: all passed. The release gate now witnesses that `Epistemos-AppStore` excludes `Goose/GooseInProcessACPServer.swift` and that `GooseMASAgentCoreRunner.swift` has no local listener or ACP HTTP parser dependency.

Stale process boundary:

Current process scan still shows the same direct/debug leftovers:

```text
1365 02-19:19:36 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/opencode-triple serve --hostname 127.0.0.1 --port 59563
1366 02-19:19:36 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/goosed agent
1367 02-19:19:36 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/node .../OpenChamberWeb/openchamber-web/server/index.js --port 53034 --host 127.0.0.1
65691    04:36:38 .../DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app/Contents/Resources/node .../ExperimentalWeb/experimental-web/server/index.cjs
```

These are stale direct/debug leftovers, not active MAS dependencies, and not MAS evidence. Current MAS validation must come from `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, and `MAS_SANDBOX` checks only.

Updated verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| App Store target test after Goose split | App Store target may fail to compile or run after moving the runner out of the old ACP server file | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Open; run next |
| Fresh MAS archive after Goose split | Archive could retain old ACP server source/symbols or stale target membership | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Open; run after App Store target test |
| Raw MAS SwiftFileList dangerous source hits | Parked strings remain in MAS SwiftFileList inputs even when compile-parked | Triage latest `swiftfilelist-dangerous-source-hits.txt`; expect `GooseInProcessACPServer.swift` to disappear after fresh archive | Open |
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Group dirty state, avoid broad staging, later split/stage only MAS-safe scope | Open; `349` dirty-status lines |
| Remaining substrate witnesses | MAS substrate source guards still expose non-Goose gaps | Patch replay/tool attribution and reversible vault metadata witnesses or record as separate substrate work | Open; 3 failures listed above |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally stop them in a separate cleanup action | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Run `Epistemos-AppStore` / `EpistemosAppStoreKeelstoneTests` after the Goose target split.
2. Rebuild, local-sign, release-gate, bundle-scan, and source/target/archive-scan a fresh App Store archive.
3. Confirm `GooseInProcessACPServer.swift` is absent from the App Store SwiftFileLists and archive strings while `GooseMASAgentCoreRunner.swift` remains present.
4. Continue pruning the next largest MAS SwiftFileList drift source, likely `GooseRuntimeSupervisor.swift` or the remaining Work/VaultMCP local-server seams.

## 2026-07-08 12:10 Update - Fresh MAS Archive After Goose ACP Split

Prompt status:

- Prompt 1 remains complete; the repo/target reality report remains in this file.
- Prompt 2 / KEELSTONE remains active under the MAS-only lock.
- The stale 1Code V2 / Experimental-lane objective remains inactive for this MAS run.
- Current dirty count remains `349` status lines, with no broad staging or commit.

App Store target test after Goose split:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 tests in `KEELSTONE App Store Lane` passed. Result bundle:
`build/xcode-results/2026-07-08-115759-74774.xcresult`.

Notable target-membership proof from this build: `xcodebuild` removed stale App Store intermediates for `GooseInProcessACPServer.o`, `GooseInProcessACPServer.stringsdata`, and `GooseInProcessACPServer.swiftconstvalues`.

Fresh App Store archive after Goose split:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1205-goose-acp-server-excluded \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive evidence paths:

- Archive: `build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive`
- App: `build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive/Products/Applications/Epistemos.app`
- Derived data: `build/appstore-release-archive-derived-2026-07-08-1205-goose-acp-server-excluded`
- Bundle scan report: `build/appstore-archive-scan-2026-07-08-1205-goose-acp-server-excluded`
- Source/target/archive scan report: `build/appstore-source-scan-2026-07-08-1205-goose-acp-server-excluded`

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1205-goose-acp-server-excluded \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; no quarantine extended attributes, no prohibited runtime strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.

Source/target/archive leak-scan summary:

```text
archive=build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive
app=build/appstore-release-archive-2026-07-08-1205-goose-acp-server-excluded.xcarchive/Products/Applications/Epistemos.app
derived=build/appstore-release-archive-derived-2026-07-08-1205-goose-acp-server-excluded
swiftfilelists=2
mas_source_files=802
parked_or_shared_source_inputs=45
raw_dangerous_source_hits=220
archive_forbidden_path_hits=0
archive_quarantine_hits=0
archive_goose_acp_string_hits=0
```

Goose ACP target-membership proof:

```text
238:/Users/jojo/Downloads/Epistemos/Epistemos/Goose/GooseMASAgentCoreRunner.swift
```

`GooseInProcessACPServer.swift` is absent from `mas-source-files.txt`; `GooseMASAgentCoreRunner.swift` is present. Archive string scan found `0` Goose ACP server/parser/framing markers.

Stale process boundary:

Current direct/debug leftovers are still present:

```text
1365 02-19:33:20 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/opencode-triple serve --hostname 127.0.0.1 --port 59563
1366 02-19:33:20 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/goosed agent
1367 02-19:33:20 .../.cache/epistemos-dd-codex-preview-inset-clamp-pro/.../Epistemos.app/Contents/Resources/node .../OpenChamberWeb/openchamber-web/server/index.js --port 53034 --host 127.0.0.1
65691    04:50:22 .../DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app/Contents/Resources/node .../ExperimentalWeb/experimental-web/server/index.cjs
```

They remain stale direct/debug leftovers, not active MAS dependencies and not MAS evidence.

Updated verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| App Store target test after Goose split | App Store target could fail after moving the MAS runner out of the old ACP server file | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Passed in `2026-07-08-115759-74774.xcresult` |
| Fresh MAS archive after Goose split | Archive could retain old ACP server source/symbols or stale target membership | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Passed for `1205-goose-acp-server-excluded` archive |
| Raw MAS SwiftFileList dangerous source hits | Parked strings remain in MAS SwiftFileList inputs even when compile-parked | Triage latest `swiftfilelist-dangerous-source-hits.txt` | Open; down from `242` to `220` after parking `GooseInProcessACPServer.swift` out of MAS |
| Parked/shared MAS source inputs | Direct-lane files still appear in App Store SwiftFileLists | Preserve only MAS-safe seams or remove target membership where feasible | Open; `45` entries |
| Remaining substrate witnesses | MAS substrate source guards still expose non-Goose gaps | Patch replay/tool attribution and reversible vault metadata witnesses or record as separate substrate work | Open; 3 direct substrate failures listed above |
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Group dirty state, avoid broad staging, later split/stage only MAS-safe scope | Open; `349` dirty-status lines |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally stop them in a separate cleanup action | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Triage and prune `Epistemos/Goose/GooseRuntimeSupervisor.swift` from the App Store source surface if the MAS stub can be moved to a smaller MAS-safe seam.
2. If that split is safe, add target/project/gate/test witnesses and rerun the App Store test plus fresh archive/gate/scans.
3. If Goose supervisor cannot be safely split, move to the next raw-hit group: `ExperimentalRuntimeSupervisor.swift`, `WorkNativeMCPServer.swift`, `VaultMCPServer.swift`, and `CloudProviderAuthService.swift`.

## 2026-07-08 12:35 Update - Goose Runtime Supervisor MAS Target Split Verified

Prompt state:

- Prompt 1 remains complete. The durable repo/target reality report is this file; do not treat old 1Code V2 / Experimental-lane objective text as current scope for this MAS run.
- Prompt 2 / KEELSTONE remains active and MAS-only.
- Current evidence remains `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, and `MAS_SANDBOX` only.

Change summary:

- Added `Epistemos/Goose/GooseMASRuntimeSupervisor.swift` as the App Store-only Goose runtime supervisor seam.
- Updated `project.yml` and `Epistemos.xcodeproj/project.pbxproj` so `Epistemos-AppStore` excludes `Goose/GooseRuntimeSupervisor.swift`, while the direct `Epistemos` target excludes `Goose/GooseMASRuntimeSupervisor.swift`.
- Updated `EpistemosTests/AppStoreJuneHardeningTests.swift` and `scripts/keelstone-release-gate.sh` so target/project/source gates require the MAS-safe supervisor file and keep the direct supervisor implementation out of the MAS target.

Direct source-guard test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result: `** TEST SUCCEEDED **`; 21 tests in `App Store June hardening` passed. Result bundle:
`build/xcode-results/2026-07-08-121439-89344.xcresult`.

App Store KEELSTONE test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 tests in `KEELSTONE App Store Lane` passed. Result bundle:
`build/xcode-results/2026-07-08-122001-93602.xcresult`.

Notable target-membership proof from this build: `xcodebuild` removed stale App Store intermediates for `GooseRuntimeSupervisor.o`, `GooseRuntimeSupervisor.stringsdata`, and `GooseRuntimeSupervisor.swiftconstvalues`.

Fresh App Store archive after Goose supervisor split:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1220-goose-supervisor-excluded \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive evidence paths:

- Archive: `build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive`
- App: `build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive/Products/Applications/Epistemos.app`
- Derived data: `build/appstore-release-archive-derived-2026-07-08-1220-goose-supervisor-excluded`
- Bundle scan report: `build/appstore-archive-scan-2026-07-08-1220-goose-supervisor-excluded`
- Source/target/archive scan report: `build/appstore-source-scan-2026-07-08-1220-goose-supervisor-excluded`

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1220-goose-supervisor-excluded \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; no quarantine extended attributes, no prohibited runtime strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.

Source/target/archive leak-scan summary:

```text
archive=build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive
app=build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive/Products/Applications/Epistemos.app
derived=build/appstore-release-archive-derived-2026-07-08-1220-goose-supervisor-excluded
swiftfilelists=2
mas_source_files=802
parked_or_shared_source_inputs=52
raw_dangerous_source_hits=137
archive_forbidden_path_hits=0
archive_quarantine_hits=0
archive_goose_acp_string_hits=0
```

Extended raw-hit comparison file for broader triage is also present at
`build/appstore-source-scan-2026-07-08-1220-goose-supervisor-excluded/swiftfilelist-dangerous-source-hits.comparable.txt`.

Goose target-membership proof:

```text
238:/Users/jojo/Downloads/Epistemos/Epistemos/Goose/GooseMASAgentCoreRunner.swift
239:/Users/jojo/Downloads/Epistemos/Epistemos/Goose/GooseMASRuntimeSupervisor.swift
```

`GooseInProcessACPServer.swift` and `GooseRuntimeSupervisor.swift` are absent from the App Store SwiftFileLists. Archive string scan found `0` Goose ACP server/parser/framing markers.

Dirty-file grouping at this checkpoint:

- MAS-safe current lane: `Epistemos/Goose/GooseMASRuntimeSupervisor.swift`, `Epistemos/Goose/GooseMASAgentCoreRunner.swift`, `Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift`, `EpistemosTests/AppStoreJuneHardeningTests.swift`, `scripts/keelstone-release-gate.sh`, `project.yml`, `Epistemos.xcodeproj/project.pbxproj`, this checkpoint ledger.
- Shared substrate touched by MAS hardening: `scripts/scan_appstore_bundle.sh`, `build-rust.sh`, `build-agent-core.sh`, `build-epistemos-core.sh`, `bundle-app-runtime-assets.sh`, `agent_core/*`, `epistemos-core/*`, `Epistemos/AgentSurface/*`, `Epistemos/JuneAgent/*`, `Epistemos/Vault*`, `Epistemos/Work/*`, `Epistemos/Harness/*`, and App Store source-guard tests.
- Parked-lane / legacy: `Epistemos/ExperimentalAgent/*`, direct Goose implementation files (`GooseRuntimeSupervisor.swift`, `GooseInProcessACPServer.swift`, `GooseACPClient.swift`, `GooseProviderKeyBridge.swift`), `Resources/experimental-runtime`, `Resources/opencode-runtime`, Pyodide/Python resources, and broad Experimental/OpenChamber/Goose docs.
- Generated/build artifacts: `build/appstore-*`, `build/xcode-results/*`, `build-rust/swift-bindings/*`, `Epistemos/Resources/Editor/*.br`, `.spm-cache`, `syntax-core/target/*`, archived apps/derived data, and scan report directories.

Why ExperimentalAgent and Goose files changed:

- Goose changed because MAS must preserve the useful agent_core Goose seam while removing direct local ACP server/runtime supervisor code from the App Store target. The new MAS files are the safe seam; the old Goose files remain direct-lane implementation/legacy and are excluded from `Epistemos-AppStore`.
- ExperimentalAgent changed earlier in Prompt 2 to compile-park direct Experimental/OpenChamber runtime surfaces for MAS while keeping legacy/direct-lane behavior available outside `EPISTEMOS_APP_STORE || MAS_SANDBOX`.

Stale process boundary:

The old `opencode-triple`, `goosed`, OpenChamber web, and ExperimentalWeb processes remain stale direct/debug leftovers. They are not active MAS dependencies and are not MAS evidence. Current validation above is the fresh `Epistemos-AppStore` archive/test/gate/scan evidence only.

Updated verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| App Store target test after Goose supervisor split | App Store target could fail after excluding direct Goose runtime supervisor | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Passed in `2026-07-08-122001-93602.xcresult` |
| Fresh MAS archive after Goose supervisor split | Archive could retain old supervisor source/symbols or stale target membership | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Passed for `1220-goose-supervisor-excluded` archive |
| Raw MAS SwiftFileList dangerous source hits | Parked/direct-lane strings remain in MAS SwiftFileList inputs even when compile-parked | Triage latest `swiftfilelist-dangerous-source-hits.txt` | Open; current focused scan `137` raw hits |
| Parked/shared MAS source inputs | Direct-lane files still appear in App Store SwiftFileLists | Preserve only MAS-safe seams or remove target membership where feasible | Open; `52` entries under current broader grouping |
| Remaining substrate witnesses | MAS substrate source guards still expose non-Goose gaps | Patch replay/tool attribution and reversible vault metadata witnesses or record as separate substrate work | Open; 3 direct substrate failures remain from earlier broader run |
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Group dirty state, avoid broad staging, later split/stage only MAS-safe scope | Open; broad dirty state still present, not staged |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally stop them in a separate cleanup action | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Triage the next raw-hit group now that direct `GooseRuntimeSupervisor.swift` is out of MAS. Start with `ExperimentalRuntimeSupervisor.swift` only if it can be safely target-split or reduced without breaking MAS-visible types.
2. If Experimental is too coupled, move to `WorkNativeMCPServer.swift` / `VaultMCPServer.swift` for smaller local-server pruning seams.
3. Keep source/target/archive scans and fresh App Store archive rebuilds at each meaningful target/source change.

## 2026-07-08 12:45 Owner Steer - MAS-Only Prompt 2 Continues

Owner wording:

```text
Good checkpoint. Continue Prompt 2 / KEELSTONE, but first write the durable Prompt 1/2 checkpoint ledger as a file.

Important: the old 1Code V2 Experimental-lane goal/objective is stale for this MAS run. Current lock is MAS-only. Do not obey 1Code/Experimental scope rules for this MAS agent.
```

Interpreted intent:

- Keep this run locked to `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, and `MAS_SANDBOX`.
- Treat direct 1Code / Experimental-lane product goals as parked legacy scope for this MAS agent.
- Do not stage or commit the broad dirty state.
- Continue Prompt 2 autonomously by pruning MAS target/source/archive exposure, patching drift gates, and rebuilding/rescanning after meaningful source changes.

Acceptance checks for the next edit:

- App Store target/project/source scans show the target does not include direct ExperimentalAgent runtime Swift files.
- Fresh `Epistemos-AppStore` test, archive, release-gate, and bundle/source/archive scans use only MAS evidence.
- Stale `goosed`, OpenChamber, and ExperimentalWeb debug processes remain explicitly excluded from evidence.

Next action:

- Exclude direct `Epistemos/ExperimentalAgent/*.swift` files from `Epistemos-AppStore` target membership while preserving source guards for the direct lane, then run MAS-only verification.

## 2026-07-08 13:05 Update - ExperimentalAgent MAS Target Exclusion Verified

Prompt state:

- Prompt 1 remains complete. The durable repo/target reality report is this file; it records that the repo is `/Users/jojo/Downloads/Epistemos`, the live MAS target is `Epistemos-AppStore`, and current proof must be `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`.
- Prompt 2 / KEELSTONE is active now.
- The old 1Code V2 / Experimental-lane objective is stale for this MAS run. Experimental/OpenChamber direct-lane behavior is parked legacy scope unless needed only to prove MAS exclusion.
- No broad dirty state was staged or committed.

Change summary:

- Added explicit App Store source exclusions for the seven direct ExperimentalAgent Swift files:
  - `ExperimentalAgent/ExperimentalGlassHostView.swift`
  - `ExperimentalAgent/ExperimentalHostBridge.swift`
  - `ExperimentalAgent/ExperimentalPerf.swift`
  - `ExperimentalAgent/ExperimentalRuntimeSupervisor.swift`
  - `ExperimentalAgent/ExperimentalStateBridge.swift`
  - `ExperimentalAgent/ExperimentalSurfaceView.swift`
  - `ExperimentalAgent/ExperimentalThemeBridge.swift`
- Updated `project.yml` and `Epistemos.xcodeproj/project.pbxproj` so `Epistemos-AppStore` excludes those files from target membership.
- Updated `EpistemosTests/AppStoreJuneHardeningTests.swift` and `scripts/keelstone-release-gate.sh` so App Store target/project gates require those exclusions.

Pre-archive source checks:

```bash
git diff --check -- project.yml Epistemos.xcodeproj/project.pbxproj EpistemosTests/AppStoreJuneHardeningTests.swift scripts/keelstone-release-gate.sh docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result: exit `0`; no output.

```bash
bash -n scripts/keelstone-release-gate.sh
```

Result: exit `0`; no output.

Pre-build gate check against the previous signed archive:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1220-goose-supervisor-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`. This was a source/project gate check only; the archive evidence below is the fresh MAS archive.

Direct source-guard test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result: `** TEST SUCCEEDED **`; 21 tests in `App Store June hardening` passed. Result bundle:
`build/xcode-results/2026-07-08-123940-7565.xcresult`.

App Store KEELSTONE test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 tests in `KEELSTONE App Store Lane` passed. Result bundle:
`build/xcode-results/2026-07-08-124453-11702.xcresult`.

Notable target-membership proof from this build: `xcodebuild` removed stale App Store intermediates for all seven ExperimentalAgent files: `ExperimentalGlassHostView`, `ExperimentalHostBridge`, `ExperimentalPerf`, `ExperimentalRuntimeSupervisor`, `ExperimentalStateBridge`, `ExperimentalSurfaceView`, and `ExperimentalThemeBridge`.

Fresh App Store archive after ExperimentalAgent target exclusion:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1248-experimental-agent-excluded \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive evidence paths:

- Archive: `build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive`
- App: `build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive/Products/Applications/Epistemos.app`
- Derived data: `build/appstore-release-archive-derived-2026-07-08-1248-experimental-agent-excluded`
- Bundle scan report: `build/appstore-archive-scan-2026-07-08-1248-experimental-agent-excluded`
- Source/target/archive scan report: `build/appstore-source-scan-2026-07-08-1248-experimental-agent-excluded`

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1248-experimental-agent-excluded \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; no quarantine extended attributes, no prohibited runtime strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.

Source/target/archive leak-scan summary:

```text
archive=build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive
app=build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive/Products/Applications/Epistemos.app
derived=build/appstore-release-archive-derived-2026-07-08-1248-experimental-agent-excluded
swiftfilelists=2
mas_source_files=795
parked_or_shared_source_inputs=45
goose_target_membership=9
experimental_target_membership=0
raw_dangerous_source_hits=169
comparable_dangerous_source_hits=1042
archive_forbidden_path_hits=0
archive_quarantine_hits=0
archive_goose_experimental_string_hits=0
```

The scan is generated from the archive-derived `Epistemos-AppStore` Swift file lists. Corrected false-positive patterns exclude ordinary `.bundle` paths and Rust dependency source paths such as `url/src/host.rs`; those are not MAS parked-runtime evidence.

Dirty-file grouping at this checkpoint:

- MAS-safe current lane: `project.yml`, `Epistemos.xcodeproj/project.pbxproj`, `EpistemosTests/AppStoreJuneHardeningTests.swift`, `scripts/keelstone-release-gate.sh`, `Epistemos/Goose/GooseMASAgentCoreRunner.swift`, `Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift`, `Epistemos/Goose/GooseMASRuntimeSupervisor.swift`, and this checkpoint ledger.
- Shared substrate touched by MAS hardening: App Store entitlements/plist, build and bundle scripts, `scripts/scan_appstore_bundle.sh`, MAS-safe Goose runner/provider seams, `Epistemos/AgentSurface/*`, `Epistemos/JuneAgent/*`, `Epistemos/Vault*`, `Epistemos/Work/*`, `Epistemos/Harness/*`, `agent_core/*`, `epistemos-core/*`, and App Store hardening/source-guard tests.
- Parked-lane / legacy: direct `Epistemos/ExperimentalAgent/*`, direct Goose ACP/server/supervisor files, OpenChamber/Experimental docs, `Resources/experimental-runtime`, `Resources/opencode-runtime`, Pyodide/Python resources, and old direct-lane prompt/research docs.
- Generated/build artifacts: `build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive`, `build/appstore-release-archive-derived-2026-07-08-1248-experimental-agent-excluded`, `build/appstore-archive-scan-2026-07-08-1248-experimental-agent-excluded`, `build/appstore-source-scan-2026-07-08-1248-experimental-agent-excluded`, `build/xcode-results/*`, `syntax-core/target/*`, compressed editor resources, `.spm-cache`, and other archive/derived-data outputs.

Why ExperimentalAgent and Goose files changed:

- ExperimentalAgent changed because Prompt 2 found direct Experimental/OpenChamber runtime Swift files still present in the App Store target membership. They are now target-excluded for MAS while direct-lane source guards remain as legacy safety witnesses.
- Goose changed because MAS keeps the useful `agent_core` Goose path only through MAS-safe runner/provider/supervisor seams, while direct ACP server/parser/framing/runtime supervisor files are excluded from `Epistemos-AppStore`.

Stale process boundary:

Old `goosed`, OpenChamber, ExperimentalWeb, and `opencode-triple` processes remain stale direct/debug leftovers. They are not active MAS dependencies and are not MAS evidence. The current proof above is only the fresh `Epistemos-AppStore` test/archive/gate/scan chain.

Updated verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| App Store target test after ExperimentalAgent exclusion | App Store target could fail after removing direct ExperimentalAgent source files | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Passed in `2026-07-08-124453-11702.xcresult` |
| Fresh MAS archive after ExperimentalAgent exclusion | Archive could retain direct Experimental symbols/resources or stale target membership | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Passed for `1248-experimental-agent-excluded` archive |
| Raw MAS SwiftFileList dangerous source hits | Parked/direct-lane strings remain in MAS SwiftFileList inputs even when compile-parked | Triage latest `swiftfilelist-dangerous-source-hits.txt` | Open; current focused scan `169` raw hits, comparable broad scan `1042` |
| Parked/shared MAS source inputs | Direct-lane files still appear in App Store SwiftFileLists | Preserve only MAS-safe seams or remove target membership where feasible | Open; focused membership now `45`, down from `52` |
| Remaining substrate witnesses | MAS substrate source guards still expose non-Goose gaps | Patch replay/tool attribution and reversible vault metadata witnesses or record as separate substrate work | Open; 3 direct substrate failures remain from earlier broader run |
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Group dirty state, avoid broad staging, later split/stage only MAS-safe scope | Open; broad dirty state still present, not staged |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally stop them in a separate cleanup action | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Inspect the `45` focused parked/shared MAS source inputs and `169` focused dangerous hits.
2. Prefer target-splitting or MAS-safe seam extraction for local-server files where public MAS behavior can stay inert: `WorkNativeMCPServer.swift`, `VaultMCPServer.swift`, `CloudProviderAuthService.swift`, and remaining Goose ACP client/provider files.
3. After any meaningful source/target change, rerun source gates, `Epistemos-AppStore` KEELSTONE tests, fresh App Store archive, release gate, bundle scan, and source/target/archive scan.

## 2026-07-08 13:24 Update - Goose ACP Support MAS Target Exclusion Verified

Current lock: MAS-only. The old 1Code V2 / Experimental-lane goal is stale for this run and is not being used to steer scope.

Change verified:

- App Store target now excludes direct Goose ACP/provider/diagnostics support files: `Goose/GooseACPClient.swift`, `Goose/GooseACPProtocol.swift`, `Goose/GooseACPSourceProtocol.swift`, `Goose/GooseProcessDiagnostics.swift`, and `Goose/GooseProviderKeyBridge.swift`.
- App Store target already excluded `Goose/GooseInProcessACPServer.swift` and `Goose/GooseRuntimeSupervisor.swift`.
- App Store keeps only MAS-safe Goose seams in target membership: `GooseMASAgentCoreCatalog.swift`, `GooseMASAgentCoreProviderSlug.swift`, `GooseMASAgentCoreRunner.swift`, and `GooseMASRuntimeSupervisor.swift`.

Pre-archive source checks:

```bash
git diff --check -- project.yml Epistemos.xcodeproj/project.pbxproj EpistemosTests/AppStoreJuneHardeningTests.swift scripts/keelstone-release-gate.sh
```

Result: exit `0`.

```bash
bash -n scripts/keelstone-release-gate.sh
```

Result: exit `0`.

```bash
./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-08-1248-experimental-agent-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed` as a source/project gate against the previous archive. This was not counted as fresh archive evidence.

Direct source-guard test after Goose ACP exclusion:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result: `** TEST SUCCEEDED **`; 21 tests passed. Result bundle:
`build/xcode-results/2026-07-08-130240-26201.xcresult`.

App Store KEELSTONE test after Goose ACP exclusion:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result: `** TEST SUCCEEDED **`; 5 tests passed. Result bundle:
`build/xcode-results/2026-07-08-130748-30458.xcresult`.

Notable target-membership proof from this build: `xcodebuild` removed stale App Store intermediates for `GooseACPClient`, `GooseACPProtocol`, `GooseACPSourceProtocol`, `GooseProcessDiagnostics`, and `GooseProviderKeyBridge`.

Fresh App Store archive after Goose ACP support target exclusion:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-131235-goose-acp-support-excluded \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive evidence paths:

- Archive: `build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive`
- App: `build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive/Products/Applications/Epistemos.app`
- Derived data: `build/appstore-release-archive-derived-2026-07-08-131235-goose-acp-support-excluded`
- Bundle scan report: `build/appstore-archive-scan-2026-07-08-131235-goose-acp-support-excluded`
- Source/target/archive scan report: `build/appstore-source-scan-2026-07-08-131235-goose-acp-support-excluded`

Local inspection signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; replaced existing signature for local inspection.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-131235-goose-acp-support-excluded \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive/Products/Applications/Epistemos.app
```

Result: exit `0`; no quarantine extended attributes, no prohibited runtime strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.

Source/target/archive leak-scan summary:

```text
archive=build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive
app=build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive/Products/Applications/Epistemos.app
derived=build/appstore-release-archive-derived-2026-07-08-131235-goose-acp-support-excluded
swiftfilelists=2
mas_source_files=790
parked_or_shared_source_inputs=40
goose_target_membership=4
experimental_target_membership=0
raw_dangerous_source_hits=167
comparable_dangerous_source_hits=1039
archive_forbidden_path_hits=0
archive_quarantine_hits=0
archive_goose_experimental_string_hits=0
```

Delta from the prior ExperimentalAgent-only archive: MAS Swift inputs `795 -> 790`, focused parked/shared inputs `45 -> 40`, Goose target membership `9 -> 4`, Experimental target membership remains `0`, and archive leak hits remain `0`.

Dirty-file grouping at this checkpoint:

- MAS-safe current lane: `project.yml`, `Epistemos.xcodeproj/project.pbxproj`, `EpistemosTests/AppStoreJuneHardeningTests.swift`, `scripts/keelstone-release-gate.sh`, `Epistemos/Goose/GooseMASAgentCoreRunner.swift`, `Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift`, `Epistemos/Goose/GooseMASRuntimeSupervisor.swift`, and this checkpoint ledger.
- Shared substrate touched by MAS hardening: App Store entitlements/plist, build and bundle scripts, `scripts/scan_appstore_bundle.sh`, MAS-safe Goose runner/provider/supervisor seams, `Epistemos/AgentSurface/*`, `Epistemos/JuneAgent/*`, `Epistemos/Vault*`, `Epistemos/Work/*`, `Epistemos/Harness/*`, `agent_core/*`, `epistemos-core/*`, and App Store hardening/source-guard tests.
- Parked-lane / legacy: direct `Epistemos/ExperimentalAgent/*`, direct Goose ACP/server/supervisor files, OpenChamber/Experimental docs, `Resources/experimental-runtime`, `Resources/opencode-runtime`, Pyodide/Python resources, and old direct-lane prompt/research docs.
- Generated/build artifacts: `build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive`, `build/appstore-release-archive-derived-2026-07-08-131235-goose-acp-support-excluded`, `build/appstore-archive-scan-2026-07-08-131235-goose-acp-support-excluded`, `build/appstore-source-scan-2026-07-08-131235-goose-acp-support-excluded`, prior archive/scan result directories, `build/xcode-results/*`, `syntax-core/target/*`, compressed editor resources, `.spm-cache`, and other archive/derived-data outputs.

Why ExperimentalAgent and Goose files changed:

- ExperimentalAgent changed because Prompt 2 found direct Experimental/OpenChamber runtime Swift files still present in the App Store target membership. They are target-excluded for MAS while direct-lane source guards remain legacy safety witnesses.
- Goose changed because MAS now keeps the useful `agent_core` Goose path only through MAS-safe runner/provider/supervisor/catalog seams, while direct ACP client/protocol/server/diagnostics/provider bridge files are excluded from `Epistemos-AppStore`.

Stale process boundary:

Old `goosed`, OpenChamber, ExperimentalWeb, and `opencode-triple` processes remain stale direct/debug leftovers. Direct scheme tests also ran direct-lane build scripts earlier. None of those processes or cached apps are active MAS dependencies or MAS evidence. The current proof above is only the fresh `Epistemos-AppStore` test/archive/gate/scan chain.

Updated verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| App Store target test after Goose ACP exclusion | App Store target could fail after removing direct Goose source files | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Passed in `2026-07-08-130748-30458.xcresult` |
| Fresh MAS archive after Goose ACP exclusion | Archive could retain direct Goose ACP symbols/resources or stale target membership | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Passed for `131235-goose-acp-support-excluded` archive |
| Raw MAS SwiftFileList dangerous source hits | Parked/direct-lane strings remain in MAS SwiftFileList inputs even when compile-parked | Triage latest `raw-dangerous-source-hits.txt` | Open; current raw scan `167`, comparable broad scan `1039` |
| Parked/shared MAS source inputs | Direct-lane files still appear in App Store SwiftFileLists | Preserve only MAS-safe seams or remove target membership where feasible | Open; focused membership now `40`, down from `45` |
| Remaining substrate witnesses | MAS substrate source guards still expose non-Goose gaps | Patch replay/tool attribution and reversible vault metadata witnesses or record as separate substrate work | Open; 3 direct substrate failures remain from earlier broader run |
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Group dirty state, avoid broad staging, later split/stage only MAS-safe scope | Open; broad dirty state still present, not staged |
| Stale direct-lane processes | Process audits can be confused by old debug helpers | Do not count them as MAS evidence; optionally stop them in a separate cleanup action | Open; not MAS evidence |
| Distribution signing/upload | Ad-hoc local archive is not App Store submission proof | Operator-controlled distribution signing/export/upload | Blocked on credentials/operator action |

Next KEELSTONE pruning/storage/release-gate target:

1. Inspect the `40` focused parked/shared MAS source inputs and `167` focused raw dangerous hits from `build/appstore-source-scan-2026-07-08-131235-goose-acp-support-excluded`.
2. Prefer target splitting or MAS-safe seam extraction for remaining local-server/storage files where public MAS behavior can stay inert: likely `WorkNativeMCPServer.swift`, `VaultMCPServer.swift`, `CloudProviderAuthService.swift`, and related Work/VaultMCP substrate.
3. After any meaningful source/target change, rerun source gates, `Epistemos-AppStore` KEELSTONE tests, fresh App Store archive, release gate, bundle scan, and source/target/archive scan.

## 2026-07-08 13:32 Update - Work/VaultMCP Direct Source Guard Passed

Current MAS-only lock:

- The old 1Code V2 / Experimental-lane goal is stale for this run.
- Current scope is Prompt 2 / KEELSTONE for `Epistemos-AppStore` only.
- Direct-lane processes, cached apps, `goosed`, OpenChamber, and ExperimentalWeb are not MAS evidence.

Current pruning slice:

- Target-exclude direct Work/OpenCode, VaultMCP server, and CLI/VaultMCP settings residue from `Epistemos-AppStore`.
- Preserve only MAS-safe seams needed by always-compiled inert code paths, including `WorkOpenCodeShell.swift` and `WorkNativeMCPRegistration.swift`.
- Do not stage or commit broad dirty state.

Direct source guard command:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EpistemosTests/AppStoreJuneHardeningTests
```

Result bundle: `build/xcode-results/2026-07-08-132642-46974.xcresult`.

Extracted result:

```json
{
  "result": "Passed",
  "passedTests": 21,
  "failedTests": 0,
  "skippedTests": 0,
  "totalTestCount": 21,
  "title": "Test - Epistemos"
}
```

Status:

- Direct source guard for the current Work/VaultMCP pruning slice passed.
- Fresh `Epistemos-AppStore` KEELSTONE test, archive, release gate, bundle scan, and source/target/archive leak scan are still pending for this slice.
- The prior fresh MAS evidence remains the Goose ACP support checkpoint at `build/appstore-release-archive-2026-07-08-131235-goose-acp-support-excluded.xcarchive`.

Dirty-file grouping delta for this slice:

- MAS-safe current lane: `project.yml`, `Epistemos.xcodeproj/project.pbxproj`, `EpistemosTests/AppStoreJuneHardeningTests.swift`, `scripts/keelstone-release-gate.sh`, and this checkpoint ledger.
- Shared substrate intentionally preserved: `WorkOpenCodeShell.swift`, `WorkNativeMCPRegistration.swift`, and MAS-safe Goose runner/provider/supervisor seams.
- Parked-lane / legacy newly target-excluded from App Store: `VaultMCP/VaultMCPCore.swift`, `VaultMCP/VaultMCPHost.swift`, `VaultMCP/VaultMCPServer.swift`, `VaultMCP/VaultMCPTokenStore.swift`, `Views/Settings/CLIDiscoveryHealthRow.swift`, `Views/Settings/VaultMCPServerSettingsRow.swift`, `Work/WorkAppContextSnapshot.swift`, `Work/WorkNativeMCPServer.swift`, `Work/WorkNativeToolExecutor.swift`, `Work/WorkOpenCodeRuntime.swift`, `Work/WorkPromptForgeContext.swift`, `Work/WorkServerDiagnostics.swift`, `Work/WorkSkillsProvisioner.swift`, and `Work/WorkToolMCPCore.swift`.
- Generated/build artifacts: `build/xcode-results/2026-07-08-132642-46974.xcresult` and direct-lane generated runtime resources from the direct scheme build; these are not MAS archive evidence.

Verification-debt update:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Direct source guard after Work/VaultMCP exclusion | Source guards or release-gate assertions could reject the current target split | `EpistemosTests/AppStoreJuneHardeningTests` under direct `Epistemos` | Passed in `2026-07-08-132642-46974.xcresult` |
| App Store target test after Work/VaultMCP exclusion | `Epistemos-AppStore` could have stale target membership or missing MAS-safe seams | `EpistemosAppStoreKeelstoneTests` under `Epistemos-AppStore` | Pending |
| Fresh MAS archive after Work/VaultMCP exclusion | Archive could retain direct local-server symbols/resources or stale target membership | Rebuild, local-sign, release-gate, bundle scan, source/target/archive scan | Pending |
| Raw MAS SwiftFileList dangerous source hits | Parked/direct-lane strings may still appear in MAS SwiftFileList inputs | Triage latest raw hit report after fresh archive | Pending |
| Broad dirty worktree separation | MAS-safe changes can be buried among stale direct/legacy/generated edits | Continue grouping; avoid broad staging | Open |

Next action:

Run the `Epistemos-AppStore` KEELSTONE test for this exact Work/VaultMCP pruning slice, then rebuild and rescan a fresh App Store archive if it passes.

## 2026-07-08 14:18 Update - Visible MAS Proof And Base-App Completion Lock

Owner wording:

> Prompt 2 is not complete if the normal/base app still opens the old 1Code/OpenChamber/Experimental surface.

> One active product reality: MAS/June.

> The normal/base app the owner opens must match the MAS App Store product.

> The old Epistemos base target/scheme must either become MAS-equivalent or be renamed/quarantined as legacy/dev-only so it cannot be mistaken for the product.

> Do not advance past Prompt 2 until base-app ambiguity is resolved or logged as a HIGH MAS blocker with exact next actions.

Interpreted intent:

- Continue to use `Epistemos-AppStore` with `EPISTEMOS_APP_STORE` and `MAS_SANDBOX` as the proof scheme.
- Treat base/default `Epistemos` opening 1Code/OpenChamber/Experimental as HIGH MAS drift.
- Resolve the owner-visible default app ambiguity before any Prompt 3 work.
- Inventory 1Code/OpenChamber/Goose runtime/ExperimentalWeb/Node/local-server/subprocess ownership before deletion; "do not delete first" means inventory before deletion, not indefinite preservation.
- Treat the screenshot showing `The Workspace bundle is missing from this build.` in the launched MAS app as a visible MAS product blocker, separate from the old-surface ambiguity.

Visible MAS proof captured:

- Fresh archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1405-python-runtime-residue-clean.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1405-python-runtime-residue-clean \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

- Result: `** ARCHIVE SUCCEEDED **`.
- Proof directory: `build/visible-mas-proof-2026-07-08-1412-python-runtime-residue-clean`.
- Scheme: `Epistemos-AppStore`.
- Target: `Epistemos-AppStore`.
- Configuration: `Release`.
- Built app path: `build/appstore-release-archive-2026-07-08-1405-python-runtime-residue-clean.xcarchive/Products/Applications/Epistemos.app`.
- Bundle identifier from built app: `com.epistemos.appstore`.
- Compile flags from `showBuildSettings`: `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- `EPISTEMOS_EXPERIMENTAL`: absent from App Store target build settings.
- `KINDRED_ENABLED`: absent from App Store target build settings.
- Ad-hoc local launch signing:

```bash
codesign --deep --force --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1405-python-runtime-residue-clean.xcarchive/Products/Applications/Epistemos.app
```

- Launch command:

```bash
open build/appstore-release-archive-2026-07-08-1405-python-runtime-residue-clean.xcarchive/Products/Applications/Epistemos.app
```

- Launched process: PID `90219`.
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1405-python-runtime-residue-clean.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Running bundle id from System Events: `com.epistemos.appstore`.
- Stale direct/debug processes were terminated before launch: cached `opencode-triple`, cached `goosed`, cached OpenChamber `node`, and DerivedData ExperimentalWeb `node`.
- Stale direct process count after MAS launch: `0`.
- KEELSTONE release gate against that exact app path: `KEELSTONE release gate passed`.
- App Store bundle scan report: `build/appstore-archive-scan-2026-07-08-1412-python-runtime-residue-clean`.
- App Store bundle scan result: no quarantine xattrs; no prohibited runtime strings according to `scripts/scan_appstore_bundle.sh`; no prohibited runtime symbols; no prohibited research/tool resource residue.

Strict string scan caveat:

- `build/visible-mas-proof-2026-07-08-1412-python-runtime-residue-clean/bundle-forbidden-filenames.txt`: zero forbidden file/resource name hits for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, and `experimental-runtime`.
- `build/visible-mas-proof-2026-07-08-1412-python-runtime-residue-clean/forbidden-executable-filenames.txt`: zero forbidden executable filename hits.
- A broader all-string scan still finds `codex` in main binary strings and `node`/`rg` as incidental editor/Rust/graph strings. This is classified as HIGH MAS drift for further pruning, even though it is not evidence of bundled runtime executables.

Owner-visible blocker:

- The launched MAS app screenshot shows `The Workspace bundle is missing from this build.`.
- This means the visible MAS proof establishes the correct launched app identity, but the current archived MAS app is not yet a complete owner-usable product surface.
- Next action before more pruning: map and fix MAS Workspace resource bundling, then resolve base/default `Epistemos` scheme/target ambiguity.

Current verification-debt additions:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| MAS Workspace bundle packaging | Owner-visible MAS app opens but cannot render workspace | Resource membership/script mapping, patched bundle phase/resources, fresh MAS launch showing no missing Workspace bundle | HIGH open |
| Base/default app ambiguity | Normal owner launch can still resolve to direct 1Code/OpenChamber/Experimental | Scheme/target/config/resource/process map; patch base target/scheme or quarantine legacy; launch proof for normal path | HIGH open |
| Legacy runtime deletion/quarantine | Old lanes may remain because source guards preserve them | rg references, target membership, build phases/scripts/resources, schemes/configs, tests/source guards, generated/stale process inventory | Open |

## 2026-07-08 14:22 Update - JuneWeb MAS Packaging Blocker

Owner wording:

> The running MAS archive shows "The Workspace bundle is missing from this build."

> Treat this as a Prompt 2 MAS release blocker. The app being launched is com.epistemos.appstore, so this is not acceptable as evidence of MAS working.

> Package JuneWeb into the MAS archive at Contents/Resources/JuneWeb.

> Required files: JuneWeb/dist/index.html and JuneWeb/tauri-internals-shim.js.

> Do not fall back to dev fork/env paths for Release/MAS.

> Add a release/archive gate that fails if those files are missing.

Interpreted intent:

- Fix MAS archive resource packaging so the launched `com.epistemos.appstore` app renders June instead of the missing-bundle panel.
- The proof bar is not only build/archive identity; it must include manual/screenshot proof that the exact archived MAS app loads June from bundled resources.
- Release/MAS must use bundled `Contents/Resources/JuneWeb` only, not dev fork or environment fallback paths.
- Keep the base-app completion lock active after this fix: normal/base app reality must become MAS/June or legacy/dev-only must be quarantined.

Next action:

- Map `JuneWeb` source/resource/build-script ownership, patch bundle and release gates, rebuild/archive `Epistemos-AppStore`, relaunch the exact archive app, and capture manual/screenshot proof.

## 2026-07-08 15:08 Update - MAS Vault Restore And Body Persistence Blocker

Owner wording:

> STOP normal feature work. Treat this as a MAS data-loss/release blocker.

> after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault.

> Primary suspected root cause: VaultSyncService.startupBookmarkValidation() starts security-scoped access, stops it, then checks fileExists/isReadable afterward. In MAS sandbox this can false-fail a valid bookmark as unreadable. The readability check must happen while scope is active, and automatic restore must not be blocked by a false preflight.

> Do not claim fixed from source guards only. Prove it in the real archived app with logs.

> Local voice/read-aloud is also a Prompt 2 MAS release blocker.

Interpreted intent:

- Freeze normal Prompt 2 feature/pruning work until the MAS vault restore and body-save path is proven safe in the exact App Store archive.
- Keep the current proof scheme locked to `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`.
- Prove vault restore against `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)` after quit/reopen of the exact archive app, with no startup missing/unreadable warning and no `Cannot save page body: no vault URL` log.
- Treat note-body loss after save/view switching as unresolved until a real archived-app proof shows visible words survive and persist to the vault.
- After vault/body persistence is fixed and proven, investigate Kokoro/read-aloud in the exact archive; do not dismiss it as missing model without archive-level gate evidence.
- Keep the base-app completion lock active: normal/base app must become MAS/June or be quarantined/renamed legacy/dev-only, but that work follows this data-loss blocker.

Current evidence carried forward:

- `Epistemos-AppStore` archive `build/appstore-release-archive-2026-07-08-1440-vault-restore-scope.xcarchive` succeeded and was ad-hoc signed for local launch.
- Exact archive app path: `build/appstore-release-archive-2026-07-08-1440-vault-restore-scope.xcarchive/Products/Applications/Epistemos.app`.
- Bundle id: `com.epistemos.appstore`.
- App Store release gate passed against the exact app after signing.
- App Store bundle scan report: `build/appstore-archive-scan-2026-07-08-1440-vault-restore-scope`.
- Visible proof directory: `build/visible-mas-proof-2026-07-08-1440-vault-restore-scope`.
- Live log proof showed `Vault bookmark found`, `Resolved bookmark`, `FSEvents watcher started`, and `VaultSyncService started for: Kimi_Agent_Deterministic AI Deep Dive (2)` after relaunch.
- Negative log scan found no `Saved vault bookmark points to a missing or unreadable directory`, no `Automatic vault restore was paused`, and no `Cannot save page body: no vault URL`.
- Manual note-save probe created `Untitled.md` in the vault but only frontmatter persisted; the typed body was not found in the vault. Classify this as HIGH MAS body persistence/data-loss debt until isolated and fixed.
- Focused App Store Keelstone tests passed: `build/xcode-results/2026-07-08-145800-35895.xcresult`.

Next action:

- Read the note save/export path around `NoteDetailWorkspaceView`, `ProseEditorView`, `ProseEditorRepresentable2`, `VaultSyncService.savePage`, and the existing note-save tests.
- Patch the narrowest MAS-safe body-save issue found, with tests that prevent stale/generic exports from overwriting file-first edited note bodies.
- Rebuild/archive `Epistemos-AppStore`, relaunch the exact archive app, and prove vault restore plus body save with logs and vault file contents before moving to Kokoro/read-aloud or base-app defaulting.

## 2026-07-08 Resume Checkpoint - MAS-Only Canon And Current Release Blockers

Source canon:

- Objective file read: `/Users/jojo/.codex/attachments/c83385d9-0c81-447e-94eb-1127b27bc730/pasted-text-1.txt`.
- Canon ZIP read: `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08.zip`.
- Canon files read in required order: `00_READ_FIRST.md`, `01_OWNER_LOCK_AND_CANONICAL_THESIS.md`, `02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`, `03_MINIMAL_PROMPT_PACK.md`, `08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md`, `10_LOCAL_AGENT_REDIRECT_AND_STATUS_TEMPLATES.md`.
- Prompt 2 domain doc read for the active blocker: `04_KEELSTONE_STORAGE_AND_RELEASE_GATE.md`.

Current repo reality:

- Repo path: `/Users/jojo/Downloads/Epistemos`.
- Branch: `feat/goose-surface`.
- Worktree: broad dirty state remains; do not stage or commit broadly.
- Xcode targets: `Epistemos`, `Epistemos-AppStore`, `EpistemosAppStoreKeelstoneTests`, `EpistemosTests`, `EpistemosWidgets`.
- Xcode schemes include active proof scheme `Epistemos-AppStore`, base scheme `Epistemos`, stale/dev scheme `Epistemos-Experimental`, local package schemes, and bench/test schemes.
- Current proof target: `Epistemos-AppStore`.
- Current proof flags from Release build settings: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- Base/default Release drift: target `Epistemos` still uses `EPISTEMOS_EXPERIMENTAL KINDRED_ENABLED EPISTEMOS_LINK_SUBSTRATE_RT` with bundle id `com.epistemos.app`.
- AppStore bundle id: `com.epistemos.appstore`.

Owner intent checkpoint:

- Verbatim steer: "STOP normal feature work. Treat this as a MAS data-loss/release blocker." Also: "Prompt 2 is not complete if the normal/base app still opens the old 1Code/OpenChamber/Experimental surface." Also: "Local voice/read-aloud is also a Prompt 2 MAS release blocker."
- Interpreted intent: Continue Prompt 2 / KEELSTONE only. Fix MAS vault restore and body persistence first, with exact archived-app proof. Then prove Kokoro/read-aloud in the exact archive. Keep the base/default app ambiguity as a HIGH Prompt 2 blocker until `Epistemos` becomes MAS-equivalent or is quarantined/renamed legacy/dev-only.
- Hard constraints: use `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX` as current proof scheme; do not use stale DerivedData, goosed, OpenChamber, ExperimentalWeb, or debug apps as MAS evidence; no dev/env path fallback in Release/MAS; vault files/artifacts are durable truth.
- Non-goals: no Prompt 3 work; no 1Code/Experimental/Goose/OpenChamber resurrection; no broad staging/commit; no source-guard-only success claim for storage.
- Acceptance checks now active: real archive restores `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)` after quit/reopen; no missing/unreadable bookmark toast; no `Cannot save page body: no vault URL`; `vaultSync.vaultURL` non-nil after launch; visible note words survive switching/relaunch and persist to vault markdown; AppStore tests/gates/archive scans pass; exact archive screenshots/logs prove the result.
- Contradictions/questions: base/default `Epistemos` is currently not MAS-equivalent; it must be fixed after storage proof or remain logged as HIGH blocker. Current archive proof showed vault restore logs, but manual body-save proof failed to prove typed body persisted.
- Next action: inspect current storage/save source and tests, patch the narrowest data-loss path, then rebuild/archive and collect runtime proof.

Current process evidence:

- No running `Epistemos` process was observed in the current process scan.
- Active `node`/Codex/computer-use processes are tool/runtime leftovers from the development environment and are not MAS evidence.
- Stale `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, and `bun` were not observed as active dependencies in the current process scan.

Dirty-file grouping at this checkpoint:

- MAS-safe / active Prompt 2: `Epistemos/Sync/VaultSyncService.swift`, `Epistemos/App/AppBootstrap.swift`, `Epistemos/JuneAgent/JuneWebAssets.swift`, `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`, `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `EpistemosTests/VaultSyncServiceAuditTests.swift`, `EpistemosTests/WorkspaceSnapshotTests.swift`, `EpistemosTests/NoteEditorLayoutTests.swift`, `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`, `project.yml`, `Epistemos.xcodeproj/project.pbxproj`, `scripts/keelstone-release-gate.sh`, `bundle-app-runtime-assets.sh`, `build-june-web.sh`.
- Shared substrate under MAS audit: `agent_core`, `epistemos-core`, `js-editor`, selected `JuneAgent`, `Vault`, `QuickChat`, and `Epdoc` files.
- Parked-lane / legacy dirty state: `ExperimentalAgent`, `Goose`, `Work`, `VaultMCP`, `HTMLWorkspace`, legacy prompt/docs, Kindred/Reckoner/Lumenlens planning docs. These remain inventory/quarantine/deletion targets, not active product lanes.
- Generated/build artifacts: `build/*`, `.june-web-stage`, `syntax-core/target/*`, generated editor bundles/resources, `build/xcode-results/*`, `build/appstore-audit/*`, `build/visible-mas-proof-*`.

Verification-debt ledger:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| MAS vault restore proof | False bookmark preflight can sever source access after relaunch | Exact archive launch, quit, reopen, logs showing bookmark resolved and `vaultSync` started without missing/unreadable toast | Partially proven earlier; must reprove after final storage patch |
| MAS note body persistence | Body edits can create frontmatter-only markdown or fail to save body | Exact archive manual proof: typed token visible, saved, found in vault `.md`, no `no vault URL` log | HIGH open |
| Startup integrity warning | Warnings can scare owner and may indicate source-loss path | Logs/UI show no missing/unreadable bookmark warning and no destructive local-state clear during restore | Open |
| Base/default app reality | Owner opens normal `Epistemos` and sees old 1Code/Experimental surface | Patch or quarantine base scheme/target; normal launch proof opens MAS/June | HIGH open |
| Kokoro/read-aloud | Voice button may exist without a working MAS-safe TTS path | Archive gate status, settings preview audible/log proof, surface-by-surface read matrix | HIGH open after storage |
| Archive legality/leak scans | Parked/runtime symbols may remain in archive | Fresh AppStore archive, release gate, bundle scan, strings/nm scans | Pending after meaningful source changes |

Safe overnight queue:

1. Finish MAS storage/data-loss blocker with tests and exact archive proof.
2. Re-run source, target, archive, and runtime leak scans after storage changes.
3. Resolve or formally block base/default `Epistemos` MAS-equivalence.
4. Prove Kokoro/read-aloud from the exact archive and patch missing product wiring.
5. Continue parked-lane inventory and safe quarantine/deletion only after target membership, scripts, schemes, tests, resources, generated bundles, and stale processes are mapped.

## 2026-07-08 16:53 Update - Visible MAS Proof Plus Active Body Persistence Failure

Latest App Store lane test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-appstore-doc-flush-keelstone-2026-07-08 \
  -only-testing:EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests
```

Result: `** TEST SUCCEEDED **`; 7 tests. Result bundle:
`build/xcode-results/2026-07-08-163100-25432.xcresult`.

The AppStore compile command included `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX -DEPISTEMOS_LINK_SUBSTRATE_RT`. The proof target did not include `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED`.

Latest Release archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1635-doc-flush.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1635-doc-flush \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archived app path:
`build/appstore-release-archive-2026-07-08-1635-doc-flush.xcarchive/Products/Applications/Epistemos.app`.

Local inspection signing:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1635-doc-flush.xcarchive/Products/Applications/Epistemos.app
```

Result: replaced existing signature for local inspection.

Release gates and scans:

```bash
./scripts/keelstone-release-gate.sh
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1635-doc-flush.xcarchive/Products/Applications/Epistemos.app
./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1635-doc-flush.xcarchive/Products/Applications/Epistemos.app
```

Result: all passed. Bundle id: `com.epistemos.appstore`. Entitlements: sandbox, app group, audio input, app-scope bookmarks, user-selected read/write, and network client only.

JuneWeb archive proof:

- `Contents/Resources/JuneWeb/dist/index.html` exists in the archived app.
- `Contents/Resources/JuneWeb/tauri-internals-shim.js` exists in the archived app.
- Release/MAS must continue to fail gates if either file is absent.

Runtime proof directory:
`build/visible-mas-proof-2026-07-08-1635-doc-flush`.

Runtime proof files:

- `build/visible-mas-proof-2026-07-08-1635-doc-flush/launch-welcome.png`
- `build/visible-mas-proof-2026-07-08-1635-doc-flush/document-typed-marker.png`
- `build/visible-mas-proof-2026-07-08-1635-doc-flush/source-missing-marker-regression.png`
- `build/visible-mas-proof-2026-07-08-1635-doc-flush/runtime.log`

Exact archive launch command:

```bash
open -na /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1635-doc-flush.xcarchive/Products/Applications/Epistemos.app
```

Visible proof result:

- Launched process path was the exact archive app path above.
- Launched bundle id was `com.epistemos.appstore`.
- UI loaded MAS June, not the missing `Workspace bundle is missing from this build` panel.
- The runtime log showed `VaultSyncService started for: Kimi_Agent_Deterministic AI Deep Dive (2)`.
- No stale DerivedData/debug app, `goosed`, OpenChamber, ExperimentalWeb, opencode, node, bun, rg, or experimental-runtime process was used as MAS evidence.

Active release blocker reproduced in exact archive:

- Manual proof typed marker `MAS doc flush proof 2026-07-08 16:45 archive.` in Document view.
- Switching to Source showed only frontmatter, not the typed marker.
- Vault search for the marker under `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)` returned no matches.
- Classification: HIGH MAS data-loss/release blocker remains open. The app can restore the vault and load June, but Document-view body edits were not proven durable in the archived AppStore app.

Patch direction now in progress:

- Add a MAS-safe direct WebView markdown snapshot path using `window.epistemos.getMarkdown()` before host save/lens switch.
- Keep the existing bridge-triggered `flushDocumentSnapshot()` path as fallback.
- Add regression tests proving Document surface host saves use the fresh editor snapshot before switching or disappearing.

Current dirty-file grouping additions:

- MAS-safe / active storage fix: `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`, `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `Epistemos/Engine/EpdocEditorBridge.swift`, `js-editor/src/bridge/inbound.ts`, `js-editor/src/types/webkit.d.ts`, `EpistemosTests/EditorProvenanceStoreTests.swift`, `EpistemosTests/EpdocEditorBridgeTests.swift`, `EpistemosTests/NoteEditorLayoutTests.swift`.
- Shared substrate under audit: `project.yml`, `Epistemos.xcodeproj/project.pbxproj`, `bundle-app-runtime-assets.sh`, `scripts/keelstone-release-gate.sh`, `Epistemos/JuneAgent/JuneWebAssets.swift`.
- Parked-lane / legacy still dirty and not staged: `Epistemos/ExperimentalAgent/**`, `Epistemos/Goose/**`, `Epistemos/Work/**`, `Epistemos/Views/HTMLWorkspace/**`, legacy Goose/OpenChamber/Experimental docs.
- Generated/build artifacts: generated editor bundles, `.june-web-stage/**`, `build/**`, `syntax-core/target/**`, `build-rust/swift-bindings/**`.

Verification-debt delta:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Document-to-Source body persistence | Visible words can disappear from the shared markdown source and vault file | Focused tests, AppStore lane test, fresh Release archive, exact archive manual proof with marker found in Source and vault | HIGH open |
| JuneWeb archive packaging | Release app can regress to missing-bundle panel | Archive gate plus exact app screenshot | Passed for 16:35 archive; reopen after rebuild |
| Base/default app reality | Owner can still open normal `Epistemos` and see 1Code/Experimental | Make base target MAS-equivalent or quarantine/rename it, then prove normal launch path | HIGH open after storage blocker |
| Kokoro/read-aloud | Voice controls can exist without working MAS TTS | Exact archive gate/status/log/audible proof and surface read matrix | HIGH open after storage blocker |

## 2026-07-08 17:30 Update - Storage Still Leads, Prompt Upgrade Added To MAS Drift

Latest owner steer additions:

- Verbatim steer: "june keeps messing up with the prompt thing where it tries to upgrade the prompt on sending and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade system but rn its still calling hermes for it etc."
- Interpreted intent: keep storage/data-loss first, then audit the June prompt-upgrade path as Prompt 2 MAS drift. The MAS app should not silently route sends through Hermes or an aggressive prompt-upgrade system. If the prompt upgrade cannot be made reliable and MAS-safe, disable/remove it for the MAS product path.
- Constraint update: do not move to prompt-upgrade, Kokoro, or base-app migration until the active vault/body persistence blocker has real archived-app proof or an exact blocker is logged.

Latest archive proof:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1711-direct-doc-snapshot \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive app path:
`build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive/Products/Applications/Epistemos.app`.

Bundle id: `com.epistemos.appstore`.

Compile flags observed in Release build: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`. No `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED` proof flags were observed for this AppStore target.

Archive signing/gate/scan evidence:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive/Products/Applications/Epistemos.app

./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive/Products/Applications/Epistemos.app

EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1711-direct-doc-snapshot \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive/Products/Applications/Epistemos.app
```

Result: signing succeeded; release gate passed; archive scan passed. Scan report directory:
`build/appstore-archive-scan-2026-07-08-1711-direct-doc-snapshot`.

JuneWeb proof in archive:

- `Contents/Resources/JuneWeb/dist/index.html`
- `Contents/Resources/JuneWeb/tauri-internals-shim.js`

Runtime visible proof directory:
`build/visible-mas-proof-2026-07-08-1711-direct-doc-snapshot`.

Runtime launch command:

```bash
open -na /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive/Products/Applications/Epistemos.app
```

Runtime result:

- Launched exact archived app, PID `72128`.
- Computer-use app state reported path `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1711-direct-doc-snapshot.xcarchive/Products/Applications/Epistemos.app/`.
- Bundle id was `com.epistemos.appstore`.
- June loaded from `june://bundle/index.html`.
- Vault `Kimi_Agent_Deterministic AI Deep Dive (2)` was visible.
- No missing/unreadable vault toast appeared in this launch proof.
- No stale `goosed`, OpenChamber, ExperimentalWeb, opencode, node, bun, rg, or experimental-runtime process was used as MAS evidence.

Active failure from that exact archive:

- Manual marker typed in Document view: `MAS direct snapshot proof 2026-07-08 17:22 archive. Words must survive source switch, vault search, and relaunch.`
- Switching to Source still showed frontmatter only.
- Screenshot: `build/visible-mas-proof-2026-07-08-1711-direct-doc-snapshot/source-missing-marker-regression.png`.
- Classification: HIGH MAS data-loss/release blocker remains open.

Patch now under verification:

- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` now falls back from `window.epistemos.getMarkdown()` to `editor.state.doc.textBetween(...)` when a live ProseMirror document has visible text but the Markdown serializer returns an empty string.
- This is not accepted as fixed until an exact archived AppStore app proves Source/vault persistence with a real typed marker.

Verification note:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-doc-flush-visible-text-fallback-tests-2026-07-08 \
  -only-testing:EpistemosTests/EpdocEditorBridgeTests/documentEditorExposesImmediateSnapshotFlushForNativeSaves \
  -only-testing:EpistemosTests/EditorProvenanceStoreTests/markdownDocumentSurfaceUsesDirectJSMarkdownSnapshotBeforeHostSave
```

Result: `** TEST SUCCEEDED **`, but Swift Testing selected `0 tests`; result bundle:
`build/xcode-results/2026-07-08-172358-73324.xcresult`. This is not counted as proof and must be rerun with valid selection or broader suite coverage.

Verification-debt delta:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Visible-text fallback | Source can still show frontmatter-only after Document typing | Valid focused/broader test selection, AppStore lane, archive proof with marker in Source and vault file | HIGH open |
| Prompt upgrade/Hermes | June send path can over-aggressively rewrite prompts or call Hermes in MAS | Source inventory, MAS-safe disable/fix, regression guard, archive behavior proof | HIGH open after storage |

## 2026-07-08 17:48 Update - Source Cache Patch Ready For Archive Proof

Owner steer remains unchanged: storage/data-loss proof leads; prompt-upgrade/Hermes, Kokoro, and base-app migration stay queued until the archived MAS app proves durable vault/body persistence or an exact blocker is logged.

Additional source patch under verification:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` now refreshes the Source-mode markdown snapshot immediately after accepting a Document-surface markdown save or flushing the current editor. This prevents an old frontmatter-only `codeFileBodySnapshot` from winning over the just-accepted body when the owner switches from Document to Source.
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` keeps the live WebView snapshot fallback from `window.epistemos.getMarkdown()` to visible ProseMirror text.
- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift` keeps the direct snapshot save path before host save/lens-switch.

Valid focused source/test proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-doc-flush-visible-text-fallback-tests2-2026-07-08 \
  -only-testing:'EpistemosTests/EpdocEditorBridgeTests/documentEditorExposesImmediateSnapshotFlushForNativeSaves()' \
  -only-testing:'EpistemosTests/EditorProvenanceStoreTests/markdownDocumentSurfaceUsesDirectJSMarkdownSnapshotBeforeHostSave()'
```

Result: `** TEST SUCCEEDED **`; Swift Testing executed 2 tests and both passed. Result bundle:
`build/xcode-results/2026-07-08-173113-81963.xcresult`.

Focused rerun after the Source-cache refresh helper:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-doc-flush-visible-text-fallback-tests2-2026-07-08 \
  -only-testing:'EpistemosTests/EpdocEditorBridgeTests/documentEditorExposesImmediateSnapshotFlushForNativeSaves()' \
  -only-testing:'EpistemosTests/EditorProvenanceStoreTests/markdownDocumentSurfaceUsesDirectJSMarkdownSnapshotBeforeHostSave()' \
  -only-testing:'EpistemosTests/CodeEditorPolishTests/markdownSourceMountsFromNoteFallbackAndEnrichesFromRawSourceSafely()'
```

Result: `** TEST SUCCEEDED **`; Swift Testing executed 3 tests and all passed. Result bundle:
`build/xcode-results/2026-07-08-173819-91603.xcresult`.

Important caveat: these focused runs used the base `Epistemos` Debug scheme and are source/regression proof only. They also confirmed the HIGH base-app blocker because the base Debug target still compiles `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` and stages Experimental/OpenCode runtime assets.

Current App Store lane proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-appstore-visible-text-fallback-keelstone-2026-07-08 \
  -only-testing:EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests
```

Result: `** TEST SUCCEEDED **`; Swift Testing executed 7 tests in `KEELSTONE App Store Lane` and all passed. Result bundle:
`build/xcode-results/2026-07-08-174229-96039.xcresult`.

Verification-debt delta:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Document-to-Source body persistence | Source and vault can still lose visible words despite source guards | Fresh Release `Epistemos-AppStore` archive, release gate, bundle scan, exact archive launch, typed marker visible in Source, marker found under selected vault, quit/reopen proof with no missing-vault toast | HIGH open |
| Base/default app reality | Owner can still open normal `Epistemos` and see non-MAS/Experimental product reality | Make base target MAS-equivalent or quarantine/rename it, then prove normal launch path | HIGH open after storage |
| Prompt upgrade/Hermes | June send path can over-aggressively rewrite prompts or call Hermes in MAS | Source inventory, MAS-safe disable/fix, regression guard, archive behavior proof | HIGH open after storage |
| Kokoro/read-aloud | Voice controls can exist without working MAS TTS | Exact archive gate/status/log/audible proof and surface read matrix | HIGH open after storage |

## 2026-07-08 18:18 Update - Canon Re-Read And Archived App Still Fails Body Truth

Pasted objective file read:
`/Users/jojo/.codex/attachments/c83385d9-0c81-447e-94eb-1127b27bc730/pasted-text-1.txt`.

Canon source read:
`/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08.zip`.

Files read from canon:

- `00_READ_FIRST.md`
- `01_OWNER_LOCK_AND_CANONICAL_THESIS.md`
- `02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`
- `03_MINIMAL_PROMPT_PACK.md`
- `04_KEELSTONE_STORAGE_AND_RELEASE_GATE.md`
- `08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md`
- `10_LOCAL_AGENT_REDIRECT_AND_STATUS_TEMPLATES.md`

Interpretation update:

- Prompt 2 / KEELSTONE remains the active prompt.
- Storage truth/body truth remains the release blocker.
- Kokoro/read-aloud, prompt-upgrade/Hermes, and base/default app migration are queued behind storage proof.

Fresh source/release evidence before manual proof:

```bash
./scripts/keelstone-release-gate.sh
```

Result: `KEELSTONE release gate passed`.

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1748-visible-text-source-cache \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archived app path:
`build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive/Products/Applications/Epistemos.app`.

Signing/gate/scan:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive/Products/Applications/Epistemos.app

./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive/Products/Applications/Epistemos.app

EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1748-visible-text-source-cache \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive/Products/Applications/Epistemos.app
```

Result: signing succeeded; release gate passed; archive scan passed. Scan report directory:
`build/appstore-archive-scan-2026-07-08-1748-visible-text-source-cache`.

Archive facts:

- Bundle id: `com.epistemos.appstore`
- Bundle name: `Epistemos`
- Entitlements: app sandbox, app group, audio input, app-scope bookmarks, user-selected read/write, network client.
- `Contents/Resources/JuneWeb/dist/index.html` present.
- `Contents/Resources/JuneWeb/tauri-internals-shim.js` present.
- Explicit forbidden-path scan for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, `experimental-runtime`, Pyodide/Python, Chromium/browser-use, and stdio residues returned no hits.

Exact archive launch proof:

```bash
open -na /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive/Products/Applications/Epistemos.app
```

Computer-use app state:

- Path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1748-visible-text-source-cache.xcarchive/Products/Applications/Epistemos.app/`
- Bundle id: `com.epistemos.appstore`
- PID during proof: `12700`
- UI loaded MAS June/Welcome Back and then the June home surface.
- No stale DerivedData/debug app, `goosed`, OpenChamber, ExperimentalWeb, opencode, node, bun, rg, or experimental-runtime process was used as MAS evidence.

Screenshots:

- `build/visible-mas-proof-2026-07-08-1748-visible-text-source-cache/launch-welcome.png`
- `build/visible-mas-proof-2026-07-08-1748-visible-text-source-cache/document-paste-marker.png`
- `build/visible-mas-proof-2026-07-08-1748-visible-text-source-cache/source-missing-marker-regression.png`

Archived-app failure:

- Created/opened a new Document note in the exact archived MAS app.
- Real paste input into the focused editor changed the live Document editor model: visible status read `15 words 103 chars`.
- Marker text: `MAS paste proof 2026-07-08 18:02 archive. Words must survive source switch, vault search, and relaunch.`
- Switching to Source still showed frontmatter only.
- Vault search returned no marker:

```bash
rg -n 'MAS paste proof 2026-07-08 18:02 archive|MAS source cache proof 2026-07-08 18:01 archive' \
  '/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)'
```

Result: no matches.

Classification: HIGH MAS data-loss/release blocker remains open. The current direct snapshot/source-cache patch is insufficient because live Document editor edits still do not become Source/vault truth before lens switch.

## 2026-07-08 18:25 Update - Owner Steer: Prompt Upgrade/Hermes Drift Queued Behind Storage

Verbatim owner steer:

> also june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpretation:

- This is Prompt 2 MAS drift, not Prompt 3 feature work.
- The June send path must not aggressively rewrite/upgrade owner prompts.
- Hermes prompt-upgrade calls are suspect in MAS and need source inventory plus a MAS-safe fix or removal.
- This remains queued behind the current KEELSTONE storage/body-truth blocker, because the archived MAS app still lost visible Document text on Source switch/vault persistence.

Constraints:

- Keep using `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX` as the proof scheme.
- Do not claim fixed from source guards only; archive and exact-app behavior are required for release blockers.
- Do not stage or commit broad dirty state.
- Do not use stale debug apps, goosed/OpenChamber/ExperimentalWeb/opencode/node/bun/rg processes, or stale DerivedData as MAS evidence.

Verification-debt ledger update:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Document-to-Source body persistence | Exact archived MAS app can lose visible words and fail vault body truth | Rebuild AppStore archive after frontmatter-visible fallback, launch exact archive, real paste marker, Source shows marker, vault `rg` finds marker, quit/reopen restores same vault with no warning | HIGH in progress |
| Prompt upgrade/Hermes | June send can rewrite prompts or call Hermes in MAS | Inventory send/upgrade/Hermes references; patch to disable, reduce, or remove MAS prompt-upgrade path; regression guard; archive behavior proof | HIGH queued after storage |
| Base/default app reality | Owner can still open normal `Epistemos` and see non-MAS/Experimental product reality | Make base target MAS-equivalent or quarantine/rename it, then prove normal launch path | HIGH queued after storage |
| Kokoro/read-aloud | Voice controls can exist without working MAS TTS | Exact archive gate/status/log/audible proof and surface read matrix | HIGH queued after storage |

## 2026-07-08 18:28 Update - Focused Frontmatter-Visible Fallback Tests

Command:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-doc-flush-frontmatter-visible-fallback-tests-2026-07-08 \
  -only-testing:'EpistemosTests/EpdocEditorBridgeTests/documentEditorExposesImmediateSnapshotFlushForNativeSaves()' \
  -only-testing:'EpistemosTests/EditorProvenanceStoreTests/markdownDocumentSurfaceUsesDirectJSMarkdownSnapshotBeforeHostSave()' \
  -only-testing:'EpistemosTests/CodeEditorPolishTests/markdownSourceMountsFromNoteFallbackAndEnrichesFromRawSourceSafely()'
```

Result:

- `** TEST SUCCEEDED **`
- Swift Testing executed 3 selected tests, all passed.
- XCTest selected suite executed 0 legacy XCTest tests.
- xcresult: `build/xcode-results/2026-07-08-182043-16382.xcresult`

Important classification:

- This was a focused source-guard/base Debug run, not MAS proof.
- The build confirmed the normal/base `Epistemos` scheme still compiles/stages Experimental/Goose/opencode-era assets, so the base-app ambiguity remains a HIGH Prompt 2 blocker after storage proof.

## 2026-07-08 18:32 Update - AppStore KEELSTONE Lane After Frontmatter-Visible Fallback

Command:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-appstore-frontmatter-visible-fallback-keelstone-2026-07-08 \
  -only-testing:EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests
```

Result:

- `** TEST SUCCEEDED **`
- Swift Testing executed 7 tests in `KEELSTONE App Store Lane`, all passed.
- XCTest selected suite executed 0 legacy XCTest tests.
- xcresult: `build/xcode-results/2026-07-08-182755-26690.xcresult`

AppStore lane notes:

- Exact scheme: `Epistemos-AppStore`
- Exact target under test: `Epistemos-AppStore` with `EpistemosAppStoreKeelstoneTests`
- Configuration: `Debug`
- This is MAS lane evidence, but not Release/archive evidence.
- The AppStore lane still compiles shared in-process bridge files with legacy names such as `GooseMASAgentCore*` and `HTMLWorkspace*`; those require classification as MAS-safe in-process bridge, docs/provenance only, or deletion during Prompt 2 pruning.
- No external stale goosed/OpenChamber/ExperimentalWeb/opencode/node process is MAS evidence.

Source release gate:

```bash
./scripts/keelstone-release-gate.sh
```

Result: `KEELSTONE release gate passed`.

Relevant witnesses passed:

- `Epistemos-AppStore` target includes `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.
- `Epistemos-AppStore` target stages bundled `JuneWeb`.
- Bundle witness validates staged `JuneWeb` completeness and fails incomplete stages.
- MAS JuneWeb resolver has no env fallback, no dev fork fallback, and ignores process environment.
- AppStore source/project excludes parked Experimental, OpenCode, Pyodide/Python, Vault MCP local server, Work local-server/runtime files.
- MAS bookmark readability is checked while security-scoped access is active.
- AppStore lane first-run/upgrade/bootstrap and vault unavailability tests are executable.

## 2026-07-08 18:42 Update - Fresh Release Archive, Gate, And Bundle Scan

Archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-1832-frontmatter-visible-fallback \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archive app path:
`build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive/Products/Applications/Epistemos.app`.

Ad-hoc signing command:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive/Products/Applications/Epistemos.app
```

Result: succeeded; existing signature replaced.

Archive gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Archive scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-1832-frontmatter-visible-fallback \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports written to `build/appstore-archive-scan-2026-07-08-1832-frontmatter-visible-fallback`.

Built archive gate facts:

- Built App Store entitlements include sandbox, user-selected read/write, and app-scope bookmarks.
- Built App Store entitlements omit allow-jit, disable-library-validation, and network.server.
- Built artifact omits Goose ACP loopback and OAuth loopback markers.
- Built artifact omits quarantine extended attributes.
- Built artifact includes `JuneWeb/dist/index.html`.
- Built artifact includes `JuneWeb/tauri-internals-shim.js`.

Remaining proof before storage blocker can close:

- Launch exact archive app path.
- Confirm launched bundle id is `com.epistemos.appstore`.
- Real paste into Document editor must appear in Source.
- Marker must exist under selected vault `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`.
- Quit/reopen exact archive must restore same vault with no missing/unreadable startup warning and no `Cannot save page body: no vault URL` on normal save.

## 2026-07-08 18:55 Update - Archived MAS Storage/Vault Proof

Owner steer excerpt:

> also june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpreted intent:

- Keep Prompt 2 MAS-only.
- Finish the real archived MAS app storage proof first.
- Then treat June prompt-upgrade/Hermes-on-send as MAS drift: inventory it, make it less aggressive only if it actually works, otherwise disable/remove it from the MAS send path.
- Do not let prompt-upgrade/Hermes cleanup displace the base-app completion lock or Kokoro/read-aloud blocker.

Exact archived app under proof:

- Scheme built: `Epistemos-AppStore`
- Target built: `Epistemos-AppStore`
- Configuration: `Release`
- Archive: `build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive`
- App path: `build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive/Products/Applications/Epistemos.app`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Bundle id observed through Computer Use: `com.epistemos.appstore`
- First launch PID during proof: `42409`
- Relaunch PID during proof: `42781`

Manual storage/vault proof:

- Exact archive launch showed MAS June resume surface, not the missing-JuneWeb panel.
- Screenshot: `build/visible-mas-proof-2026-07-08-1832-frontmatter-visible-fallback/launch-resume-checkpoint.png`
- Document editor accepted marker text:
  `MAS frontmatter visible fallback proof 2026-07-08 18:45 archive. Words must survive Source, vault search, and relaunch.`
- Screenshot: `build/visible-mas-proof-2026-07-08-1832-frontmatter-visible-fallback/document-marker-live.png`
- Switching to Source showed the marker below frontmatter.
- Screenshot: `build/visible-mas-proof-2026-07-08-1832-frontmatter-visible-fallback/source-marker-visible.png`
- Vault disk search found the marker:

```bash
rg -n 'MAS frontmatter visible fallback proof 2026-07-08 18:45 archive' \
  '/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)'
```

Result:

```text
/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)/New Note-2.md:6:MAS frontmatter visible fallback proof 2026-07-08 18:45 archive. Words must survive Source, vault search, and relaunch.
```

- Exact archive app was quit, then relaunched by exact path.
- Relaunch showed `Vault loaded: Kimi_Agent_Deterministic AI Deep Dive (2)` and no missing/unreadable startup warning.
- Screenshot: `build/visible-mas-proof-2026-07-08-1832-frontmatter-visible-fallback/relaunch-vault-loaded.png`
- After relaunch, Notes showed the same vault and in-app search for `18:45 archive` found the marker as a `Body Match`.
- Screenshot: `build/visible-mas-proof-2026-07-08-1832-frontmatter-visible-fallback/notes-search-marker-after-relaunch.png`

Runtime log proof:

- Bounded runtime log: `build/visible-mas-proof-2026-07-08-1832-frontmatter-visible-fallback/runtime.log`
- Runtime log line count: 5,698.
- The bounded log had no matches for:
  - `Saved vault bookmark points to a missing or unreadable directory`
  - `Cannot save page body: no vault URL`
  - `Workspace bundle is missing`
  - `missing or unreadable`
  - `no vault URL`

Process classification after proof:

- Active Epistemos app process was the exact archive app path above, PID `42781`.
- No active `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, `bun`, `local-server`, or `experimental-runtime` process was found.
- `node headless/dist/index.cjs` and Codex/CUA `node_repl` processes were observed, but these are Codex/computer-use infrastructure, not MAS app dependencies and not MAS evidence.

Storage blocker status:

- Archived MAS Document -> Source -> vault file -> quit/relaunch -> restored vault -> in-app Notes search proof passed.
- The previous missing-JuneWeb panel did not recur in this archived app.
- The previous vault-disconnect/no-vault-save signatures did not occur in the bounded archive runtime log.

Verification-debt ledger update:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Document-to-Source body persistence | Exact archived MAS app can lose visible words and fail vault body truth | Rebuild AppStore archive after frontmatter-visible fallback, launch exact archive, real marker, Source shows marker, vault `rg` finds marker, quit/reopen restores same vault with no warning | PASSED on archive `build/appstore-release-archive-2026-07-08-1832-frontmatter-visible-fallback.xcarchive` |
| Prompt upgrade/Hermes | June send can rewrite prompts or call Hermes in MAS | Inventory send/upgrade/Hermes references; patch to disable, reduce, or remove MAS prompt-upgrade path; regression guard; archive behavior proof | HIGH next |
| Base/default app reality | Owner can still open normal `Epistemos` and see non-MAS/Experimental product reality | Make base target MAS-equivalent or quarantine/rename it, then prove normal launch path | HIGH queued |
| Kokoro/read-aloud | Voice controls can exist without working MAS TTS | Exact archive gate/status/log/audible proof and surface read matrix | HIGH queued |

## 2026-07-08 18:54 Update - Prompt Upgrade / Hermes Send-Path Drift

Owner steer excerpt:

> also june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpreted intent:

- Normal June send must submit the owner's prompt text directly.
- Prompt Forge must not auto-intercept, rewrite, or pause sends in the MAS product.
- If the prompt-upgrade system is not reliable enough for the product path, remove or disable it from the send path instead of making it less visible.
- Hermes-named code must be classified honestly: compatibility naming is acceptable only if it is an in-process MAS-safe bridge and not a second runtime/process authority.

Current source finding before edit:

- The June web fork at `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx` currently calls `prompt.forge_preview` inside `submit(...)` before `prompt.submit`.
- The fork test at `/Users/jojo/dev/june-epistemos/src/test/agent-workspace.test.tsx` currently asserts the wrong behavior: send opens a Prompt Forge review and withholds `prompt.submit` until `Accept`.
- Native `Epistemos/JuneAgent/JuneAgentGateway.swift` has separate `prompt.forge_preview` and `prompt.submit` cases; the `prompt.submit` branch passes `text` into `startTurn(sessionID:prompt:)` without invoking `JunePromptForge`.

Next action:

- Disable Prompt Forge auto-review from the June web send path.
- Replace the fork regression test with one proving normal send bypasses `prompt.forge_preview` and submits original text.
- Add MAS release/source guards so staged or archived JuneWeb cannot ship the auto Prompt Forge send interception again.

## 2026-07-08 19:28 Update - Prompt Forge Send-Path Disabled and Archived MAS Proof

Owner steer excerpt:

> also june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpreted intent:

- Normal June/Workspace send in MAS must submit the user's prompt directly.
- Prompt Forge/system-prompt tooling must not auto-intercept normal sends, rewrite prompts, or pause on a review panel.
- Hermes-named compatibility code may remain only where it is the June/Tauri in-process bridge or explicit settings/manual admin surface; it must not be the send-path prompt-upgrade authority.

Implementation completed:

- `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`
  - Removed composer Prompt Forge state/UI.
  - Removed the `prompt.forge_preview` call from normal `submit(...)`.
  - Normal send now submits the trimmed draft text directly through `prompt.submit`.
- `/Users/jojo/dev/june-epistemos/src/test/agent-workspace.test.tsx`
  - Replaced the old accept/review Prompt Forge test with `sends a normal prompt directly without Prompt Forge auto-review`.
  - The regression throws if `prompt.forge_preview` is called and asserts `prompt.submit` receives the original text.
- `/Users/jojo/dev/june-epistemos/src/styles/app.css`
  - Removed dead `agent-composer-forge-*` styles.
- `EpistemosTests/AppStoreJuneHardeningTests.swift`
  - Added source guard that the native `prompt.submit` branch calls `startTurn(sessionID:prompt:requestedModelID:)` with the incoming `text` and does not call Prompt Forge.
- `scripts/keelstone-release-gate.sh`
  - Added staged and built `JuneWeb` scans for `prompt.forge_preview`, `Sharpening prompt locally`, and `agent-composer-forge`.

Web/fork proof:

```bash
cd /Users/jojo/dev/june-epistemos && \
bunx vitest run src/test/agent-workspace.test.tsx \
  -t "sends a normal prompt directly without Prompt Forge auto-review"
```

Result: passed.

```bash
cd /Users/jojo/dev/june-epistemos && bunx tsc --noEmit
```

Result: passed.

```bash
./build-june-web.sh
```

Result: succeeded; `.june-web-stage` contains `dist/index.html` and `tauri-internals-shim.js`.

```bash
rg -a -n 'prompt\.forge_preview|Sharpening prompt locally|agent-composer-forge' \
  .june-web-stage/dist .june-web-stage/tauri-internals-shim.js
```

Result: no matches.

Source/test proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-source-prompt-forge-send-bypass-2026-07-08 \
  -only-testing:'EpistemosTests/AppStoreJuneHardeningTests/appStoreJunePromptForgeIsLocalVisibleAndVaultHonest()'
```

Result: `** TEST SUCCEEDED **`; Swift Testing executed and passed 1 test in suite `App Store June hardening`.

Result bundle:

- `build/xcode-results/2026-07-08-190738-56100.xcresult`

Notes:

- The same command first reports XCTest selected 0 tests because this case is a Swift Testing case; the valid evidence is the later Swift Testing line: `Test run with 1 test in 1 suite passed`.
- An earlier `Epistemos-AppStore` attempt failed because `EpistemosTests` is not in the App Store scheme. That failed attempt is not MAS evidence.

Fresh MAS archive proof:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-08-191205-prompt-forge-send-bypass \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Archived app:

- `build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Bundle version: `1.0.0 (1)`

Ad-hoc signing:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app
```

Result: succeeded.

KEELSTONE gate proof:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app
```

Result: `KEELSTONE release gate passed`.

Relevant gate lines:

- `PASS: Staged JuneWeb omits auto Prompt Forge send-review UI`
- `PASS: Built App Store artifact includes JuneWeb/dist/index.html`
- `PASS: Built App Store artifact includes JuneWeb/tauri-internals-shim.js`
- `PASS: Built App Store JuneWeb omits auto Prompt Forge send-review UI`

Bundle scan proof:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-archive-scan-2026-07-08-191205-prompt-forge-send-bypass \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app
```

Result: passed.

Report directory:

- `build/appstore-archive-scan-2026-07-08-191205-prompt-forge-send-bypass`

Direct built-resource proof:

```bash
rg -a -n 'prompt\.forge_preview|Sharpening prompt locally|agent-composer-forge' \
  build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app/Contents/Resources/JuneWeb/dist \
  build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app/Contents/Resources/JuneWeb/tauri-internals-shim.js
```

Result: no matches.

Native send-path proof:

- `Epistemos/JuneAgent/JuneAgentGateway.swift` `case "prompt.submit":` calls:
  - `startTurn(sessionID: sessionID, prompt: text, requestedModelID: requestedModel)`
- The `prompt.submit` branch does not contain `promptForge` or `forge_preview`.

Visible archive launch proof:

- No stale Epistemos/goosed/OpenChamber/ExperimentalWeb/opencode process was running before launch.
- Exact launched process:
  - PID `67940`
  - `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Computer Use observed:
  - app path: exact archive path above
  - bundle id: `com.epistemos.appstore`
  - URL for June surface: `june://bundle/index.html`
- Screenshots:
  - June home loaded, no missing-bundle panel: `build/visible-mas-proof-2026-07-08-191205-prompt-forge-send-bypass/epistemos-appstore-june-home.png`
  - Agent composer loaded, no Prompt Forge/sharpening review UI: `build/visible-mas-proof-2026-07-08-191205-prompt-forge-send-bypass/epistemos-appstore-agent-composer-w48516.png`
  - Initial restored note proof from the same archive: `build/visible-mas-proof-2026-07-08-191205-prompt-forge-send-bypass/epistemos-appstore-window.png`

Live-process proof while exact archive app was running:

```bash
pgrep -P 67940 -laf . || true
```

Result: no child processes.

Observed `node`/`codex` processes were Codex/CUA infrastructure, not Epistemos children and not MAS app evidence.

Classification of remaining Prompt Forge/Hermes names:

- `system_prompt_forge_*` remains in the Settings/System Prompt Forge manual settings path.
- Hermes-named types/functions remain in the June fork because the Tauri/Jeeves bridge still uses Hermes compatibility naming for sessions/events/settings.
- Current proof only closes the normal-send regression: the MAS composer no longer auto-runs Prompt Forge or `prompt.forge_preview` before `prompt.submit`.
- If owner wants all manual System Prompt Forge settings removed too, that is a separate pruning target, not needed for the send-path blocker unless it re-enters normal send.

Dirty-state grouping update for files changed by this checkpoint:

MAS-safe:

- `EpistemosTests/AppStoreJuneHardeningTests.swift`
- `scripts/keelstone-release-gate.sh`
- `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`

Shared substrate:

- `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`
- `/Users/jojo/dev/june-epistemos/src/test/agent-workspace.test.tsx`
- `/Users/jojo/dev/june-epistemos/src/styles/app.css`

Generated/build artifacts:

- `.june-web-stage/**`
- `build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive/**`
- `build/appstore-release-archive-derived-2026-07-08-191205-prompt-forge-send-bypass/**`
- `build/appstore-archive-scan-2026-07-08-191205-prompt-forge-send-bypass/**`
- `build/visible-mas-proof-2026-07-08-191205-prompt-forge-send-bypass/**`
- Regenerated Rust UniFFI bindings appeared during archive scripts; classify as generated/build-script output unless separately reviewed.

Parked-lane/legacy:

- No new intentional parked-lane source edits for this prompt-send checkpoint.
- Existing broad dirty Experimental/Goose/Work files remain from earlier KEELSTONE pruning and must not be staged wholesale without ownership review.

Verification-debt ledger update:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Prompt upgrade/Hermes send-path drift | June normal send silently rewrites/pause-prompts or calls a second prompt authority before submit | Fork regression, typecheck, staged JuneWeb scan, native source guard, App Store archive, KEELSTONE gate, built bundle scan, exact archive visual composer proof | PASSED for normal send auto-upgrade removal on archive `build/appstore-release-archive-2026-07-08-191205-prompt-forge-send-bypass.xcarchive` |
| Manual System Prompt Forge settings | Owner may also want the settings/manual system removed, not just auto-send disabled | Decide whether System Prompt Forge manual settings survive as MAS-safe explicit settings or are deleted/quarantined | OPEN, lower than base-app/Kokoro unless it re-enters send path |
| Base/default app reality | Owner can still open normal `Epistemos` and see non-MAS/Experimental product reality | Make base target MAS-equivalent or quarantine/rename it, then prove normal launch path | HIGH queued; Prompt 2 not complete |
| Kokoro/read-aloud | Voice controls can exist without working MAS TTS | Exact archive gate/status/log/audible proof and surface read matrix | HIGH queued |

## Checkpoint 2026-07-08 19:55 CT - Base `Epistemos` Scheme Is MAS/June

Owner steer:

- "Prompt 2 is not complete if the normal/base app still opens the old 1Code/OpenChamber/Experimental surface."
- "One active product reality: MAS/June."
- "The normal/base app the owner opens must match the MAS App Store product."
- "Keep the base-app completion lock."

Interpreted intent:

- Keep `Epistemos-AppStore` as the proof target and MAS archive lane.
- Make the normal Xcode `Epistemos` scheme resolve to the MAS App Store product so opening/running the normal scheme is not ambiguous.
- Quarantine the old direct target behind an explicit legacy/dev scheme instead of leaving it as the default product path.
- Continue treating 1Code/OpenChamber/ExperimentalWeb/goosed/opencode/node/local-server/subprocess lanes as deletion/quarantine targets after inventory.

Scheme/project change:

- `project.yml` normal `Epistemos` scheme now builds/runs/profiles/archives `Epistemos-AppStore`.
- `project.yml` normal `Epistemos` scheme now tests `EpistemosAppStoreKeelstoneTests`.
- Added explicit `Epistemos-LegacyDev` scheme for the old direct `Epistemos` target and `EpistemosTests`.
- Ran `xcodegen generate`, producing:
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme`
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-LegacyDev.xcscheme`

Target/test proof before archive:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-base-scheme-mas-2026-07-08 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/normalEpistemosSchemeLaunchesMASTarget()'
```

Result: `** TEST SUCCEEDED **`

Result bundle:

- `build/xcode-results/2026-07-08-193354-70661.xcresult`

Debug build proof from that test:

- Target graph: `EpistemosAppStoreKeelstoneTests` depends on `Epistemos-AppStore`.
- Bundle id used by the test host: `com.epistemos.appstore`.
- App path: `build/derived-base-scheme-mas-2026-07-08/Build/Products/Debug/Epistemos.app`
- Debug app launched by exact path showed MAS/June, not the missing-bundle panel and not 1Code/OpenChamber.
- Screenshot: `build/visible-mas-proof-2026-07-08-base-scheme/normal-epistemos-scheme-mas-launch.png`

Normal scheme Release archive command:

```bash
osascript -e 'tell application id "com.epistemos.appstore" to quit' >/dev/null 2>&1 || true
sleep 2
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/base-scheme-release-archive-2026-07-08-1941.xcarchive \
  -derivedDataPath build/base-scheme-release-archive-derived-2026-07-08-1941 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** ARCHIVE SUCCEEDED **`

Archive path:

- `build/base-scheme-release-archive-2026-07-08-1941.xcarchive`

Exact built app path:

- `build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app`

Archive target reality:

- Archive command scheme: `Epistemos`
- Effective app target: `Epistemos-AppStore`
- Configuration: `Release`
- Built bundle identifier: `com.epistemos.appstore`
- `xcodebuild -showBuildSettings -project Epistemos.xcodeproj -scheme Epistemos -configuration Release` reported:
  - `TARGET_NAME = Epistemos-AppStore`
  - `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
  - `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`
  - `ENABLE_APP_SANDBOX = YES`
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS =  EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- The same build-settings query filtered for `EPISTEMOS_EXPERIMENTAL|KINDRED_ENABLED` returned no matches.

Archive signing command for validation:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app
```

Result: succeeded, replacing the existing signature.

Required JuneWeb package proof:

- `build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app/Contents/Resources/JuneWeb/dist/index.html`
- `build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app/Contents/Resources/JuneWeb/tauri-internals-shim.js`

Release gate hardening added in this checkpoint:

- `scripts/keelstone-release-gate.sh` now fails if normal `Epistemos.xcscheme` stops pointing to `Epistemos-AppStore`.
- It also requires `EpistemosAppStoreKeelstoneTests` on the normal scheme and verifies the old direct app appears only in `Epistemos-LegacyDev`.
- It normalizes quoted/unquoted PBX membership exception lines so the gate checks path intent rather than Xcode's quoting choice.

Release gate command:

```bash
set -o pipefail
./scripts/keelstone-release-gate.sh \
  --appstore-app build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app \
  | tee build/visible-mas-proof-2026-07-08-base-scheme/keelstone-release-gate-base-scheme-archive.log
```

Result: `KEELSTONE release gate passed`

Relevant gate lines:

- `PASS: Normal Epistemos scheme launches the MAS App Store target`
- `PASS: Normal Epistemos scheme build product is MAS App Store app`
- `PASS: Normal Epistemos scheme tests the MAS KEELSTONE bundle`
- `PASS: Normal Epistemos scheme does not launch the legacy direct target`
- `PASS: Normal Epistemos scheme does not build the legacy direct app`
- `PASS: Legacy direct target is explicit in Epistemos-LegacyDev scheme`
- `PASS: Epistemos-AppStore target Swift conditions: EPISTEMOS_APP_STORE count 2`
- `PASS: Epistemos-AppStore target Swift conditions: MAS_SANDBOX count 2`
- `PASS: Epistemos-AppStore target`
- `PASS: Built App Store artifact includes JuneWeb/dist/index.html`
- `PASS: Built App Store artifact includes JuneWeb/tauri-internals-shim.js`
- `PASS: Built App Store JuneWeb omits auto Prompt Forge send-review UI`

Standalone App Store bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/base-scheme-release-archive-scan-2026-07-08-1941 \
  ./scripts/scan_appstore_bundle.sh \
  build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app
```

Result: passed.

Important scanner output:

- `no quarantine extended attributes detected`
- `no prohibited runtime strings detected`
- executable files are only:
  - `Contents/MacOS/Epistemos`
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`
- `no prohibited runtime symbols detected`
- `no prohibited research/tool resource residue detected`

Report directory:

- `build/base-scheme-release-archive-scan-2026-07-08-1941`

Exact resource/path leak proof:

```bash
find build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app/Contents -print \
  | perl -ne 'print if m{/(ExperimentalWeb|1Code|OpenChamber|goosed|opencode|codex|node|bun|rg|experimental-runtime|opencode-runtime)(/|$)}i'
```

Result: no matches.

Runtime/process proof before launch:

```bash
ps -axo pid=,ppid=,command= \
  | rg -i 'Epistemos|goosed|OpenChamber|ExperimentalWeb|opencode|experimental-runtime|/node |/bun |/rg '
```

Result: no stale Epistemos/goosed/OpenChamber/ExperimentalWeb/opencode/node/bun/rg dependency process; only the scan command itself matched.

Exact archive launch command:

```bash
open -n /Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app
```

Launched process:

- PID `86933`
- `/Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Bundle id: `com.epistemos.appstore`

Child-process proof:

```bash
pgrep -P 86933 -laf .
```

Result: no child processes.

Launch log drift scan:

```bash
/usr/bin/log show --last 3m --style compact --predicate 'process == "Epistemos"' \
  | rg -n 'Workspace bundle is missing|Saved vault bookmark points|Cannot save page body: no vault URL|ExperimentalWeb|OpenChamber|goosed|opencode|experimental-runtime|prompt\.forge_preview|Sharpening prompt locally'
```

Result: no matches.

Visible proof:

- Screenshot: `build/visible-mas-proof-2026-07-08-base-scheme/normal-scheme-release-archive-mas-launch.png`
- Observed state: exact archive app shows June UI (`GREETINGS, RESEARCHER`, companions, MAS app menu), not the missing-bundle panel and not the old 1Code/OpenChamber surface.

What to open going forward:

- Normal Xcode scheme: `Epistemos`
- Effective app target: `Epistemos-AppStore`
- Archive proof app path: `build/base-scheme-release-archive-2026-07-08-1941.xcarchive/Products/Applications/Epistemos.app`
- Expected bundle id: `com.epistemos.appstore`
- Do not open stale DerivedData/debug apps or the explicit `Epistemos-LegacyDev`/`Epistemos-Experimental` schemes as product evidence.

Dirty-state grouping update for files changed by this checkpoint:

MAS-safe:

- `project.yml`
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme`
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-LegacyDev.xcscheme`
- `Epistemos.xcodeproj/project.pbxproj`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `scripts/keelstone-release-gate.sh`
- `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`

Shared substrate:

- No new shared-substrate code change for the base-scheme checkpoint.

Parked-lane/legacy:

- `Epistemos-LegacyDev` scheme is the explicit quarantine label for the old direct app lane.
- Existing broad Experimental/Goose/Work dirty files remain from earlier KEELSTONE pruning/inventory and are not staged wholesale.

Generated/build artifacts:

- `build/derived-base-scheme-mas-2026-07-08/**`
- `build/base-scheme-release-archive-2026-07-08-1941.xcarchive/**`
- `build/base-scheme-release-archive-derived-2026-07-08-1941/**`
- `build/base-scheme-release-archive-scan-2026-07-08-1941/**`
- `build/visible-mas-proof-2026-07-08-base-scheme/**`
- Xcodegen-regenerated project files listed above are intentional source-control artifacts, not throwaway build output.

Verification-debt ledger update:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Base/default app reality | Owner opens normal app and sees stale 1Code/OpenChamber/Experimental product | Normal scheme maps to MAS target, MAS tests run under normal scheme, normal scheme Release archive succeeds, exact archive launches June | PASSED for normal `Epistemos` scheme. Old direct target remains explicit legacy/dev lane via `Epistemos-LegacyDev`; deeper target deletion/quarantine remains Prompt 2 pruning work. |
| App Store archive bundle completeness | MAS app launches missing-workspace panel | JuneWeb `dist/index.html` and `tauri-internals-shim.js` in archive, release gate, exact archive screenshot | PASSED for archive `build/base-scheme-release-archive-2026-07-08-1941.xcarchive`. |
| Source/archive leak scan | 1Code/OpenChamber/ExperimentalWeb/goosed/opencode/node/bun/rg resources or runtime strings ship in MAS app | Release gate, standalone bundle scanner, exact path scan, process proof | PASSED for current archive. Continue after meaningful source changes. |
| Kokoro/read-aloud | Owner reports voice still does not work in the exact MAS product; visible controls can exist without audible Kokoro playback | Exact archive gate/status/log/audible proof and surface read matrix; patch the real readiness/playback/surface-provider failure | HIGH ACTIVE BLOCKER. Do not dismiss as missing model without archive evidence. |

## 2026-07-08 Owner Steer: Voice Still Broken

Verbatim owner update:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

Interpretation:

- Kokoro/read-aloud remains an active Prompt 2 MAS release blocker.
- Source guards, button presence, and settings rows are insufficient proof.
- The exact archived `com.epistemos.appstore` app must show Kokoro gate readiness, queue a known phrase, avoid failure logs, and produce audible/manual proof.
- Surface read-aloud must be verified or honestly classified per surface: June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, meeting/current MAS-owned text surface.
- Continue base-app MAS work and prompt-upgrade/vault regression watch in parallel, but do not advance Prompt 2 past this blocker without runtime proof or exact next actions.

Current verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Kokoro exact archive readiness | The installed Kokoro package may be present but the archived MAS process may still resolve the gate false, lack the linked runtime, or fail audio startup | Exact archived app launch; log/proof of resolved flag, model root, manifest validity, `KokoroPipeline` linked, and `isTextToSpeechAvailable() == true` | OPEN |
| Settings voice preview | The preview button may no-op or fail without visible reason | Trigger Settings -> Voice preview in exact archive; capture `Kokoro TTS queued`; no `Kokoro TTS failed`; audible/manual proof | OPEN |
| Read visible surface | Toolbar read button can exist without an app-owned text provider | Runtime matrix for June, Prose, Epdoc, Quick Capture, meeting/current MAS surface | OPEN |
| Prompt upgrade/Hermes send path | Owner still observes June prompt-upgrade/Hermes interference | Normal send path must stay bypassed; scan/log if runtime still calls prompt forge on send | WATCH |
| Vault restore | Prior fix passed but owner sees this as the highest data-loss risk | Recheck exact archive logs after relaunch for no bookmark warning and no `no vault URL` | WATCH |

## 2026-07-08 21:08 Update: Voice Known Issue and MAS Source Guard

Owner steer remains active:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

Known issue status:

- Kokoro/read-aloud is still a HIGH ACTIVE MAS release blocker.
- The latest source changes add Kokoro readiness logging, a first-class `View -> Open Voice Settings` command, visible failure toasts, and remove Apple Personal Voice/AVSpeech-facing picker paths from the MAS voice settings surface.
- This is not yet a runtime fix claim. The exact archived app still needs Voice Settings launch, preview queue, no failure logs, and audible/manual proof.

Latest MAS source/regression proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-voice-settings-kokoro-only-mas-2026-07-08 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()'
```

Result:

- `** TEST SUCCEEDED **`
- `Test "App Store lane owns a visible read-aloud surface path" passed`
- xcresult: `build/xcode-results/2026-07-08-210328-23690.xcresult`
- The app target compiled through the normal `Epistemos` scheme with MAS conditions from the current source tree.

Current proof boundary:

- Last signed archive proof remains `build/base-scheme-release-archive-2026-07-08-voice-symbol-readiness.xcarchive/Products/Applications/Epistemos.app`, launched as bundle id `com.epistemos.appstore` and screenshot at `build/visible-mas-proof-2026-07-08-voice-symbol-readiness/archive-mas-june-post-voice-patch.png`.
- That archive proved MAS/June loaded and no missing `JuneWeb` bundle panel, but it predates the latest `VoiceSettingsDetailView`, app command, and Kokoro-only picker edits.
- Required next proof is a fresh Release archive of the normal `Epistemos` scheme, signed, release-gated, bundle-scanned, launched by exact path, then Voice Settings/preview tested in that exact archive.

Dirty-state grouping for this update:

- MAS-safe: `Epistemos/App/EpistemosApp.swift`, `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`, `Epistemos/Engine/EpistemosAgentReadAloud.swift`, `Epistemos/Views/Settings/VoicePreferencesSection.swift`, `Epistemos/Views/Settings/VoiceSettingsDetailView.swift`, `Epistemos/Views/Shared/ModelVoicePickerSection.swift`, `Epistemos/VoicePro/KokoroVoiceProSettingsSection.swift`, `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`, `EpistemosTests/VoiceCodepackPlan3Tests.swift`, `EpistemosTests/SSQCGlobalVoiceTests.swift`, this ledger.
- Shared substrate: `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` and `Epistemos/Engine/EpistemosAgentReadAloud.swift` remain shared code paths, but the MAS-visible wiring now keeps Kokoro-only behavior and visible failure reporting.
- Parked-lane/legacy: existing broad `ExperimentalAgent`, `Goose`, `Work`, and old direct-app dirty files remain quarantine/pruning inventory, not App Store runtime proof.
- Generated/build artifact: `build/derived-voice-settings-kokoro-only-mas-2026-07-08/**`, `build/xcode-results/2026-07-08-210328-23690.xcresult`, existing archives/scans under `build/**`.

Stale process rule for the next runtime pass:

- Any pre-existing `goosed`, OpenChamber, ExperimentalWeb, opencode, node, bun, rg, Codex helper, or stale DerivedData/debug `Epistemos` process is not MAS evidence.
- The next launch proof must use the exact newly signed archive path and bundle id `com.epistemos.appstore`, with no child-process dependency.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Fresh archive after voice edits | Latest source changes are not in the last signed archive | Normal `Epistemos` Release archive, ad-hoc sign, `keelstone-release-gate`, standalone App Store bundle scan | OPEN NEXT |
| Voice Settings visibility | Settings can blank or fail before the Voice pane appears | Launch exact archive and open `View -> Open Voice Settings`; screenshot/log proof, no invalid SF Symbol/layout failure | OPEN |
| Kokoro readiness | Installed Kokoro package can still fail inside archived MAS process | Log line showing gate resolved true, model root, manifest valid, `KokoroPipelineLinked=true`, `isTextToSpeechAvailable=true` from exact archive | OPEN |
| Voice preview playback | Button presence can still no-op | Trigger known preview phrase; capture `Kokoro TTS queued`, no Kokoro failure, audible/manual proof | OPEN |
| Surface read matrix | App-owned read visible surface can be wired only partially | Runtime matrix for June, Prose note body, Epdoc selected/visible text, Quick Capture, meeting/current MAS-owned text surface | OPEN |
| Prompt upgrade/Hermes send path | Owner still observes June prompt-upgrade/Hermes interference | Normal send path scan/log in exact archive; no Hermes prompt-upgrade call on send | WATCH |
| Vault restore/data loss | Owner reports recurrent vault disconnect/source loss | Exact archive relaunch logs: no bookmark warning and no `Cannot save page body: no vault URL`; manual body-save/vault proof as needed | WATCH |

## 2026-07-08 21:27 Update: Archive Voice Runtime Proof Still Open

Owner steer:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

Known issue:

- Voice/read-aloud is still unresolved and remains a HIGH MAS release blocker.
- The previous exact archive proved the normal `Epistemos` scheme launched the MAS/June app bundle, and Voice Settings visually showed a ready Kokoro package, but that is not playback proof.
- Runtime proof is still missing because the Settings preview action was not safely invoked. A coordinate click landed on the Kokoro package replace/download control, created `Voice.KokoroDownload` retry/skip logs, and the exact archive app was terminated before any download could continue. That event is not counted as voice preview evidence.

Immediate corrective target:

- Persist Kokoro readiness and queue logs at notice level so exact archive `log show` scans can capture them.
- Make the Settings preview controls standard, accessibility-identified buttons so the archive can trigger preview without coordinate-clicking near install/replace controls.
- Rebuild/sign/gate/scan a fresh normal-scheme MAS archive, launch by exact path, then prove `Kokoro TTS queued`, no failure log, and audible/manual playback for a short known phrase.

## 2026-07-08 22:05 Update: Voice Runtime Fix In Progress

Owner steer remains active:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

Known issue status:

- Voice/read-aloud is still a HIGH MAS release blocker until the exact archived `com.epistemos.appstore` app proves Kokoro render and playback.
- The owner-visible failure is not being treated as a missing-model assumption. The latest exact archive already proved Kokoro gate readiness from the MAS app, but it did not prove audible playback.
- The previous archive preview attempt logged `Kokoro TTS queued` and then spent sustained CPU in Core ML/MIL activity without playback telemetry. That evidence suggests a first-render/load stall or very slow render path, not a ready voice feature.
- The exact archive process used for that proof was quit before source edits so it cannot be confused with the next runtime pass.

Source changes made for the next proof:

- `LocalPackages/KokoroPipeline/Sources/KokoroPipeline/KokoroPipeline.swift`: Core ML packages are now loaded lazily on first use instead of compiling/loading every duration, f0, decoder, and generator package during pipeline initialization.
- `Epistemos/VoicePro/KokoroCoreMLRuntimeLoader.swift`: the MAS Kokoro runtime now caches a `KokoroPipeline` per resolved model directory/manifest/bucket/token configuration instead of rebuilding the pipeline on every preview/read action.
- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`: Kokoro render and playback telemetry is now notice-level: queued, render started, render finished, playback preparing, audio engine started, playback started, and playback completed.
- `Epistemos/Views/Settings/VoicePreferencesSection.swift` and `Epistemos/Views/Shared/ModelVoicePickerSection.swift`: preview phrases are shortened so the first MAS runtime proof exercises the smallest practical Core ML path before expanding the surface matrix.

Latest source/regression proof:

```bash
git diff --check -- \
  Epistemos/Engine/EpistemosSpeechSynthesizer.swift \
  Epistemos/VoicePro/KokoroCoreMLRuntimeLoader.swift \
  Epistemos/Views/Settings/VoicePreferencesSection.swift \
  Epistemos/Views/Shared/ModelVoicePickerSection.swift \
  LocalPackages/KokoroPipeline/Sources/KokoroPipeline/KokoroPipeline.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  EpistemosTests/VoiceCodepackPlan3Tests.swift \
  EpistemosTests/SSQCGlobalVoiceTests.swift
```

Result:

- Passed with no whitespace errors.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-voice-lazy-kokoro-proof-mas-appstore-2026-07-08 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()'
```

Result:

- `** TEST SUCCEEDED **`
- `Test "App Store lane owns a visible read-aloud surface path" passed`
- Final xcresult: `build/xcode-results/2026-07-08-220152-59488.xcresult`
- Intermediate failed compile xcresults during the fix were `build/xcode-results/2026-07-08-215751-53757.xcresult` and `build/xcode-results/2026-07-08-220000-57224.xcresult`; they are implementation iterations, not final proof.

Current proof boundary:

- This is still source/test proof only.
- The next required proof is a fresh Release archive of the normal `Epistemos` scheme, signed with App Store entitlements, passed through `keelstone-release-gate`, scanned by `scan_appstore_bundle.sh`, launched by exact archive path, and tested through Settings -> Voice preview.
- Required exact-archive voice logs: Kokoro readiness true, `Kokoro TTS queued`, render started, render finished, playback preparing, audio engine started, playback started, playback completed, and no `Kokoro TTS failed` or `TTS unavailable`.
- Manual audible proof remains pending unless the owner confirms sound or a reliable capture path is added.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Fresh Release archive after lazy Kokoro edits | Source fix may not survive Release/archive/signing/gates | Normal `Epistemos` Release archive, ad-hoc sign, release gate, standalone App Store bundle scan | OPEN NEXT |
| Exact archive voice preview | Source guards can still pass while real playback stalls | Launch exact archive, open Voice Settings, click first preview, capture render/playback telemetry and no failure logs | OPEN NEXT |
| Audible proof | Logs can show player scheduling without user-audible output | Owner-confirmed audible preview or reliable audio capture proof from exact archive | OPEN |
| Surface read matrix | Settings preview can pass while product surfaces remain unwired | Runtime matrix for June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, and current MAS-owned text surface | OPEN |
| Vault restore/data loss | Owner reported vault disconnect and `no vault URL` save failures | Exact archive relaunch/log proof: no missing bookmark toast, `vaultSync.vaultURL` non-nil after launch, no `Cannot save page body: no vault URL` | WATCH |
| Prompt upgrade/Hermes send path | Owner reports June send path still tries prompt upgrade/Hermes | Runtime/source proof that normal June send bypasses prompt upgrade unless explicitly requested, or remove the upgrade system | WATCH |

## 2026-07-08 23:37 Update: Normal/Base MAS Archive Rebuilt After OpenCode Shell Parking

Source fix before archive:

- `Epistemos/Work/WorkOpenCodeShell.swift` is now compile-parked for MAS with `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `Epistemos/Views/Settings/SubstrateHealthPanel.swift` uses MAS-specific Foundation copy that omits `Experimental` and `OpenCode-style` wording.
- `scripts/keelstone-release-gate.sh` now requires the OpenCode shell seam to be compile-parked, not merely inert at runtime.

Fresh normal/base archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/base-scheme-release-archive-2026-07-08-opencode-shell-parked-v2.xcarchive \
  -derivedDataPath build/base-scheme-release-archive-derived-2026-07-08-opencode-shell-parked-v2 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Normal/base scheme: `Epistemos`.
- Built target: `Epistemos-AppStore`.
- Configuration: `Release`.
- Exact app path: `build/base-scheme-release-archive-2026-07-08-opencode-shell-parked-v2.xcarchive/Products/Applications/Epistemos.app`.
- Bundle identifier: `com.epistemos.appstore`.
- Active compile flags observed in the archive compile: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.
- Target graph observed `Target 'Epistemos-AppStore' in project 'Epistemos'`.

Signing:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/base-scheme-release-archive-2026-07-08-opencode-shell-parked-v2.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Signed successfully, replacing existing signature.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/base-scheme-release-archive-2026-07-08-opencode-shell-parked-v2.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`.
- Gate proved the normal `Epistemos` scheme launches/builds `Epistemos-AppStore`, not the legacy direct target.
- Gate proved `Epistemos-AppStore` effective source/project excludes parked Experimental, Goose ACP/local-server, Vault MCP local-server, Work OpenCode/runtime/local-server, Pyodide/Python, `experimental-runtime`, and `opencode-runtime` resources.
- Gate proved built entitlements include sandbox, user-selected read-write, and app-scope bookmarks, and omit JIT, disabled library validation, and network server.
- Gate proved built artifact includes `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js`.
- Gate proved built JuneWeb omits auto Prompt Forge send-review UI.

Standalone bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-08-opencode-shell-parked-v2/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/base-scheme-release-archive-2026-07-08-opencode-shell-parked-v2.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- Executable candidates only:
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`
  - `Contents/MacOS/Epistemos`
- No parked account/backend runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports written to `build/visible-mas-proof-2026-07-08-opencode-shell-parked-v2/appstore-bundle-scan`.

Strict legacy/runtime absence scan:

- Report path: `build/visible-mas-proof-2026-07-08-opencode-shell-parked-v2/strict-legacy-runtime-absence-scan.txt`.
- PASS path/resource component absence: `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun` runtime, `rg` runtime, `experimental-runtime`.
- PASS executable-name absence: `node`, `bun`, `rg`, `codex`, `opencode`, `goosed`.
- PASS content-marker absence: `ExperimentalWeb`, `OpenChamber`, `goosed`, `experimental-runtime`, `opencode-runtime`, `WorkOpenCodeShell`, `OpenCode-style`, `.codex/auth.json`, `.codex/models_cache.json`, `backend-api/codex`, `auth.openai.com/codex/device`, branded `1Code`.

Important caveat:

- This is archive/gate/static proof. Runtime-visible relaunch proof for voice/vault/prompt is still owed from this exact or newer archive path.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Base app MAS reality | Owner could still open wrong default app/scheme | Normal `Epistemos` archive/gate proof that it builds `Epistemos-AppStore`; exact app launch proof from archive | ARCHIVE/GATE PASSED; LAUNCH PROOF OWED |
| OpenCode shell string drift | App binary previously retained `WorkOpenCodeShell` and `OpenCode-style` strings | Compile-park shell seam, rebuild archive, strict content scan | PASSED |
| Voice owner-visible product surfaces | Owner reports voice still does not work | Surface matrix with exact archive logs and owner/manual audible proof | HIGH OPEN |
| Vault restore/data loss | Owner reported vault disconnect and `no vault URL` saves | Exact archive relaunch/log proof: bookmark restored, no warning toast, `vaultSync.vaultURL` non-nil, no `Cannot save page body: no vault URL` | HIGH WATCH |
| Prompt upgrade/Hermes send path | Owner reports June still calls Hermes/prompt-upgrade on send | Exact archive send proof and log scan, or remove/disable remaining upgrade path | OPEN |
| Focused `EpistemosTests` guards | Some relevant tests are outside normal `Epistemos` scheme/test plan | Either run through a scheme that owns `EpistemosTests` or migrate guards into `EpistemosAppStoreKeelstoneTests` | OPEN |

## 2026-07-08 Late Update: Owner Voice Steer + MAS Account Runtime Drift

Owner wording captured:

- "voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please"
- "june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc."

Interpreted intent:

- Voice remains a HIGH MAS release blocker despite prior exact-archive Settings preview telemetry. App-side render/playback logs are not enough if the owner cannot hear voice in product use.
- Prompt Forge/per-message prompt upgrade must not run on normal June send. Current source disables `prompt.forge_preview`; runtime send proof is still owed after the next archive.
- MAS must not rely on local Codex account/session import or ChatGPT Codex backend/device-auth paths. The strict archive scan found `.codex/auth.json`, `.codex/models_cache.json`, and `backend-api/codex` markers in the prior archive, so that archive is not acceptable final proof.

Current implementation pass:

- Compile-park OpenAI Codex account import/device flow outside `EPISTEMOS_APP_STORE || MAS_SANDBOX`.
- Make MAS OpenAI setup API-key based in Settings and hide the "Import Codex CLI" button from MAS builds.
- Stop MAS default skill discovery from walking `~/.codex/skills`.
- Compile-park agent_core Codex account backend auth/provider slugs outside the `mas-build` feature.
- Add artifact/release-gate checks for `.codex/(auth|models_cache).json`, `backend-api/codex`, and Codex device-auth URLs.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Voice owner-visible product surfaces | Owner still reports no voice | Exact archive audible/manual proof and surface read-aloud matrix for June, Prose, Epdoc, Quick Capture, and current MAS-owned text surface | HIGH OPEN |
| Codex account/backend drift | Prior exact archive contained local account/backend markers | MAS build/test, Release archive, release gate, standalone bundle scan proving parked account/backend strings are absent | IN PROGRESS |
| Prompt upgrade runtime proof | Owner reports send still tries prompt upgrade/Hermes | Exact archive June send/log proof; no Prompt Forge/Hermes prompt upgrade on normal submit | OPEN |
| Vault restore/data loss | Owner reported vault disconnect and `no vault URL` save failures | Exact archive relaunch/log proof: no missing bookmark toast, `vaultSync.vaultURL` non-nil, no `Cannot save page body: no vault URL` | HIGH WATCH |

## 2026-07-08 22:31 Update: Owner Voice Steer and Prompt Upgrade Lock

Owner wording:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

> also june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpreted intent:

- Keep Prompt 2 moving, but voice/read-aloud remains a known MAS release issue until owner-visible product surfaces work, not just Settings preview logs.
- Treat per-message prompt upgrade on send as product drift. Normal June send must submit the owner's prompt literally. If a prompt-upgrade path exists, it must not run automatically during send.
- Preserve MAS-only lock: evidence must come from the normal `Epistemos` scheme mapped to `Epistemos-AppStore` / `com.epistemos.appstore` with `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.

Constraints and non-goals:

- Do not use stale archive app PID `70072` as new evidence after source edits.
- Do not count old goosed/OpenChamber/ExperimentalWeb/node/local-server processes as MAS evidence.
- Do not stage or commit broad dirty state.
- Do not re-enable Apple AVSpeech as a hidden fallback.
- Do not keep the old per-message Prompt Forge path if it can surprise a send.

Prompt upgrade investigation:

- The staged June web send path uses `prompt.submit`; no staged JuneWeb marker for `Prompt Forge`, `prompt.forge_preview`, or send-review UI was found in the built web assets.
- `Epistemos/JuneAgent/JuneAgentGateway.swift` still had a native `prompt.forge_preview` message case wired to `JunePromptForge`, while normal `prompt.submit` already directly called `startTurn(sessionID:prompt:requestedModelID:)`.

Prompt upgrade source changes:

- `Epistemos/JuneAgent/JuneAgentGateway.swift`: removed the gateway-level `JunePromptForge` instance and changed `prompt.forge_preview` to return a disabled MAS error instead of rewriting text.
- `prompt.submit` remains a literal send path and does not call prompt forge.
- Settings/system prompt tooling is not being claimed fixed or removed here; this change is specifically the per-message send-upgrade path.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: added a MAS scheme-owned guard requiring `prompt.forge_preview` to be disabled and `prompt.submit` to remain literal.
- `EpistemosTests/AppStoreJuneHardeningTests.swift`: updated the non-scheme source guard with the same intent.

Prompt upgrade verification:

```bash
git diff --check -- \
  Epistemos/JuneAgent/JuneAgentGateway.swift \
  EpistemosTests/AppStoreJuneHardeningTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift
```

Result:

- Passed with no whitespace errors.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-prompt-forge-disabled-mas-2026-07-08 \
  -only-testing:'EpistemosTests/AppStoreJuneHardeningTests/appStoreJunePerMessagePromptForgeIsDisabledAndSubmitStaysLiteral()'
```

Result:

- Failed with exit code 70 because `EpistemosTests` is not included in the normal `Epistemos` scheme/test plan.
- This is a scheme membership failure, not an assertion failure.
- xcresult: `build/xcode-results/2026-07-08-222514-71684.xcresult`

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-prompt-forge-disabled-mas-keelstone-2026-07-08 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()'
```

Result:

- `** TEST SUCCEEDED **`
- `Test "App Store lane disables per-message Prompt Forge and submits literal prompts" passed`
- xcresult: `build/xcode-results/2026-07-08-222633-72537.xcresult`

Current process evidence boundary:

- Prior exact archive app is still running as PID `70072` from `build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- That PID is now stale for new proof because `JuneAgentGateway.swift` changed after the archive was built.
- Several `node headless/dist/index.cjs` processes are present, but they are Codex/headless helper context unless proven otherwise and are not MAS product evidence.
- No new Prompt 2 runtime claim should use PID `70072`; the next proof must quit it if safe, rebuild/archive, sign, gate, scan, and launch the new exact archive path.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Voice owner-visible product surfaces | Settings preview app-side logs passed, but owner still reports no voice | Surface matrix with logs and owner/manual audible confirmation for June, Prose, Epdoc, Quick Capture, and current MAS text surface | HIGH OPEN |
| Fresh Release archive after prompt-gateway change | MAS test passed in Debug, but archive proof predates `JuneAgentGateway.swift` change | Normal `Epistemos` Release archive, ad-hoc sign, release gate, standalone App Store bundle scan | OPEN NEXT |
| Prompt upgrade runtime proof | Source guard can miss a web/native edge invoking `prompt.forge_preview` | Exact new archive send test/log scan showing normal send does not run Prompt Forge/Hermes prompt upgrade; stale `prompt.forge_preview` returns disabled error if invoked | OPEN |
| Vault restore/data loss | Owner reported vault disconnect, missing bookmark warning, and `no vault URL` saves | Exact archive relaunch/log proof with selected vault retained, no warning toast, `vaultSync.vaultURL` non-nil, and no `Cannot save page body: no vault URL` | HIGH WATCH |
| Startup keychain prompt | Prior exact archive requested keychain `app.epistemos` access on launch | Decide whether to defer/suppress startup credential probing or classify as expected user-approved account access | WATCH |

## 2026-07-08 23:28 Update: Owner Voice Regression Reopened as HIGH

Owner wording:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

Interpreted intent:

- The prior exact-archive Settings preview logs are not enough to close voice.
- Voice remains a Prompt 2 MAS release issue until the owner-visible product path works, not merely until Kokoro readiness/render/playback logs appear.
- Continue Prompt 2 autonomously; do not stop MAS archive/gate/base-app work for a report-only pause.

Current constraints:

- Keep using exact archived `Epistemos.app` artifacts for runtime evidence.
- Keep Apple AVSpeech disabled unless the owner changes the Kokoro-only policy.
- Do not claim voice fixed from source guards or Settings preview logs alone.

Acceptance checks still owed:

- Surface read-aloud matrix from exact archive: June latest assistant reply, Prose note body, Epdoc selected/visible document text, Quick Capture text/read-back, and current active MAS-owned screen text.
- Visible failure reason/toast when Kokoro is unavailable or a surface has no readable text.
- Runtime logs proving Kokoro queues and does not fail for each surface.
- Owner/manual audible confirmation or an equivalent captured audio proof.

Current verification-debt change:

- Voice owner-visible product surfaces: HIGH OPEN.
- Settings preview app-side playback: PASSED earlier, but insufficient to close this issue.
- Next voice target after the current MAS archive/gate/scan checkpoint: inspect surface wiring and add/repair MAS-safe app-owned visible-text providers.

## 2026-07-08 22:20 Update: Exact Archive Voice Preview App-Side Playback Passed

Fresh normal-scheme MAS archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive \
  -derivedDataPath build/base-scheme-release-archive-derived-2026-07-08-voice-lazy-kokoro \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Target graph and active compiler process proved `Epistemos-AppStore` with `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.
- Exact app path: `build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier from built app Info.plist: `com.epistemos.appstore`
- Launch process: PID `70072`, path `/Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Child process scan for PID `70072`: no child processes.

Archive gates:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Signed successfully, replacing the unsigned archive signature.

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Built App Store entitlements include sandbox/bookmark/user-selected read-write entitlements and omit JIT, disabled library validation, and network server entitlement.
- Built artifact includes `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js`.
- Built JuneWeb omits auto Prompt Forge send-review UI.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/base-scheme-release-archive-2026-07-08-voice-lazy-kokoro.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports written to `build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/appstore-bundle-scan`.

Visible MAS proof:

- Stale process preflight found no matching stale `Epistemos`, `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, or `experimental-runtime` process.
- Exact archive launched by path, not LaunchServices name lookup.
- A startup keychain prompt for `app.epistemos` appeared and was denied; it is not counted as voice evidence.
- Clean MAS/June screenshot after dismissing prompt: `build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/archive-mas-june-after-point-continue.png`
- Voice Settings screenshot: `build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/archive-voice-settings-open.png`
- Post-preview screenshot: `build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/archive-after-voice-preview-click.png`

Voice preview proof:

- Trigger path: Settings -> Voice -> first `Preview` button in the exact archive.
- Timestamp file: `build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/voice-preview-start.txt`
- Filtered log evidence: `build/visible-mas-proof-2026-07-08-voice-lazy-kokoro/voice-preview-filtered.log`
- System output at proof time: `output volume:31`, `output muted:false`.

Key log lines:

```text
Kokoro readiness context=settings-voice-preview gateResolved=true modelRoot=/Users/jojo/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro manifestValid=true KokoroPipelineLinked=true isTextToSpeechAvailable=true
Kokoro readiness evidence context=settings-voice-preview modelPackages=22 voices=7 runtimeAssets=2 manifestFiles=75 declaredBytes=987229282
Kokoro TTS render started chars=16 voice=default speed=1.000000
Kokoro TTS queued chars=16 effect=pixelArt
Kokoro TTS render finished chars=16 samples=45600 sampleRate=24000 chunks=1 elapsedMs=17239
Kokoro TTS playback preparing samples=45600 sampleRate=24000 durationMs=1900 effect=pixelArt engineRunning=false
Kokoro TTS audio engine started
Kokoro TTS playback started samples=45600 playerPlaying=true
Kokoro TTS playback completed
```

Voice status after this proof:

- Settings preview app-side playback: PASSED in exact archived `com.epistemos.appstore` app.
- No `Kokoro TTS failed`, `TTS unavailable`, missing `JuneWeb`, vault bookmark warning, `Cannot save page body`, Hermes, Prompt Forge, ExperimentalWeb, OpenChamber, goosed, opencode, or experimental-runtime line appeared in the filtered proof log.
- Human-audible confirmation remains OPEN because app logs and system volume can prove the AVAudioEngine path started/completed, but they cannot prove what the owner physically heard.
- Surface read-aloud matrix remains OPEN for June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, and current MAS-owned text surface.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Fresh Release archive after lazy Kokoro edits | Source fix may not survive Release/archive/signing/gates | Normal `Epistemos` Release archive, ad-hoc sign, release gate, standalone App Store bundle scan | PASSED |
| Exact archive voice preview | Source guards can still pass while real playback stalls | Launch exact archive, open Voice Settings, click first preview, capture render/playback telemetry and no failure logs | PASSED app-side |
| Audible proof | Logs can show player scheduling without user-audible output | Owner-confirmed audible preview or reliable audio capture proof from exact archive | OPEN |
| Surface read matrix | Settings preview can pass while product surfaces remain unwired | Runtime matrix for June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, and current MAS-owned text surface | OPEN NEXT |
| Startup keychain prompt | Exact archive requested `app.epistemos` keychain access during launch and re-prompted after denial | Decide whether this is expected cloud-credential UX or a MAS startup prompt to suppress/defer | WATCH |
| Vault restore/data loss | Owner reported vault disconnect and `no vault URL` save failures | Exact archive relaunch/log proof: no missing bookmark toast, `vaultSync.vaultURL` non-nil after launch, no `Cannot save page body: no vault URL` | WATCH |
| Prompt upgrade/Hermes send path | Owner reports June send path still tries prompt upgrade/Hermes | Runtime/source proof that normal June send bypasses prompt upgrade unless explicitly requested, or remove the upgrade system | WATCH |

## 2026-07-08 23:45 Update: Vault Startup Restore State-Preservation Guard Passed

Owner-visible blocker:

- The owner reported that after selecting a vault, quitting and reopening can show `Saved vault bookmark points to a missing or unreadable directory. Automatic vault restore was paused.`, followed by notes losing source access and saves logging `Cannot save page body: no vault URL`.
- This remains a HIGH MAS release blocker until exact-archive relaunch proof shows the selected vault restores without the warning and without `no vault URL` save failures.

Source change:

- `Epistemos/Sync/VaultSyncService.swift`: startup restore failures that occur before a concrete `VaultRecoveryIssue` is detected now preserve local vault state instead of calling `clearVaultData()`.
- This does not claim bookmark restore is fixed by itself; it prevents the destructive local-state clear during the suspect false-failure path while the exact archive relaunch proof is still owed.

Regression guard:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-vault-restore-preserve-2026-07-08 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneStartupRestoreFailurePreservesLocalVaultState()'
```

Result:

- `** TEST SUCCEEDED **`
- Normal/base scheme: `Epistemos`.
- Built target under test: `Epistemos-AppStore`.
- Test passed: `App Store lane startup restore failure preserves local vault state`.
- xcresult: `build/xcode-results/2026-07-08-234234-42224.xcresult`.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Vault restore/data loss | Source guard passed, but owner bug was exact-archive relaunch behavior | Rebuild/archive exact normal `Epistemos` MAS app, launch by path, select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove no missing/unreadable bookmark toast, non-nil vault URL after launch, and no `Cannot save page body: no vault URL` during save | HIGH OPEN NEXT |
| Voice owner-visible product surfaces | Owner still reports voice does not work | Keep as known issue; inspect/fix surface read-aloud wiring and prove exact-archive audible/manual behavior | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send/log proof or remove/disable remaining prompt-upgrade path | OPEN |
| Base app MAS reality | Archive/gate passed before this vault source edit | Rebuild normal `Epistemos` Release archive after vault edit, sign, gate, scan, and launch exact archive path | OPEN NEXT |

## 2026-07-08 23:56 Update: Fresh Normal/Base MAS Archive Passed After Vault Restore Patch

Fresh normal/base archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive \
  -derivedDataPath build/base-scheme-release-archive-derived-2026-07-08-vault-restore-preserve \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Normal/base scheme: `Epistemos`.
- Built target: `Epistemos-AppStore`.
- Configuration: `Release`.
- Exact app path: `build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app`.
- Bundle identifier observed during archive metadata extraction: `com.epistemos.appstore`.
- Active compile flags observed in the archive compile: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.

Signing:

```bash
/usr/bin/codesign --force --deep --sign - \
  --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Signed successfully, replacing the unsigned archive signature.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`.
- Gate proved the normal `Epistemos` scheme launches/builds `Epistemos-AppStore`, not the legacy direct target.
- Gate proved App Store effective project/target excludes parked Experimental, Goose ACP/local-server, Vault MCP local-server, Work OpenCode/runtime/local-server, Pyodide/Python, `experimental-runtime`, and `opencode-runtime` resources.
- Gate proved built entitlements include sandbox, user-selected read-write, and app-scope bookmarks, and omit JIT, disabled library validation, and network server.
- Gate proved built artifact includes `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js`.
- Gate proved built JuneWeb omits auto Prompt Forge send-review UI.
- Gate proved the new vault startup restore failure path avoids destructive `clearVaultData()`.

Standalone bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-08-vault-restore-preserve/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- Executable candidates only:
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`
  - `Contents/MacOS/Epistemos`
- No parked account/backend runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports written to `build/visible-mas-proof-2026-07-08-vault-restore-preserve/appstore-bundle-scan`.

Strict legacy/runtime absence scan:

- Report path: `build/visible-mas-proof-2026-07-08-vault-restore-preserve/strict-legacy-runtime-absence-scan.txt`.
- Result: `PASS strict legacy/runtime absence scan: no path/resource/content marker hits`.
- Covered path/resource components and content markers for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, `experimental-runtime`, `opencode-runtime`, `WorkOpenCodeShell`, `OpenCode-style`, `.codex/auth.json`, `.codex/models_cache.json`, `backend-api/codex`, and `auth.openai.com/codex/device`.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive relaunch vault restore | Archive/gate/static scans passed, but owner bug is relaunch behavior | Launch exact archive path, select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove no missing/unreadable bookmark toast, non-nil vault URL after launch, and no `Cannot save page body: no vault URL` during save | HIGH OPEN NEXT |
| Voice owner-visible product surfaces | Owner still reports voice does not work | Surface read-aloud matrix and manual/audible proof from this or newer exact archive | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send/log proof, or remove/disable remaining prompt-upgrade system | OPEN |
| Base app MAS reality | Normal scheme archive/gate proves base scheme maps to MAS; runtime launch proof still owed after vault patch | Launch exact archive by path and identify running process path/bundle id | OPEN NEXT |

## 2026-07-09 00:10 Update: Exact Archive Relaunch Shows MAS/June and Restored Vault Bookmark

Initial launch after rebuild:

- Command: `open -n build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app`
- Running PID: `57485`.
- Process path: `/Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Bundle identifier from built app Info.plist: `com.epistemos.appstore`.
- Computer Use proof by full app path resolved the running archive app despite many stale `com.epistemos.appstore` DerivedData/archive copies.
- Targeted window screenshot: `build/visible-mas-proof-2026-07-08-vault-restore-preserve/archive-mas-june-home.png`.
- Screenshot shows MAS/June home (`GREETINGS, RESEARCHER`), not the missing `JuneWeb` bundle panel and not 1Code/OpenChamber.

Relaunch:

- Quit command: `osascript -e 'tell application id "com.epistemos.appstore" to quit'`.
- PID `57485` exited.
- Relaunch command: `open -n build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app`.
- New running PID: `61589`.
- Process path: `/Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-08-vault-restore-preserve.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Bundle identifier: `com.epistemos.appstore`.
- Relaunch screenshot: `build/visible-mas-proof-2026-07-08-vault-restore-preserve/archive-mas-june-home-after-relaunch.png`.
- Relaunch screenshot shows MAS/June home with no startup integrity warning panel/toast visible.

Vault evidence after relaunch:

```bash
defaults read com.epistemos.appstore epistemos.lastVaultPath
```

Result:

- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`

```bash
defaults read com.epistemos.appstore epistemos.vaultBookmark | head -c 120
```

Result:

- Bookmark exists: `{length = 812, bytes = 0x626f6f6b ... }`

Filtered relaunch logs:

```bash
/usr/bin/log show --style compact --last 2m \
  --predicate "processID == 61589 AND (eventMessage CONTAINS[c] 'VaultSync' OR eventMessage CONTAINS[c] 'vault' OR eventMessage CONTAINS[c] 'bookmark' OR eventMessage CONTAINS[c] 'Cannot save page body' OR eventMessage CONTAINS[c] 'missing or unreadable')"
```

Result:

- Scoped bookmark resolution activity observed via `CFURLResolveBookmarkData` and `com.apple.scopedbookmarksagent.xpc`.
- No `Saved vault bookmark points to a missing or unreadable directory`.
- No `Automatic vault restore was paused`.
- No `Cannot save page body: no vault URL`.

Source/runtime boundary:

- Source and KEELSTONE gate prove bookmark readability validation occurs while security-scoped access is active.
- Exact archive relaunch proves the owner vault bookmark and path survived relaunch, and the MAS/June app did not show the missing/unreadable vault warning.
- Direct runtime introspection of `vaultSync.vaultURL` and a deliberate real-note body save remain open. Do not overstate defaults/log/UI evidence as a direct object read.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Direct `vaultSync.vaultURL` object proof | Defaults/bookmark/log evidence is strong but not the exact in-memory property | Add/use a MAS-safe diagnostics surface or exact archive UI path showing active vault status/path | OPEN |
| Real save path | No `no vault URL` log appeared, but no deliberate body save was exercised in this relaunch window | Save a controlled note/body from the exact archive and verify no `Cannot save page body: no vault URL`; avoid leaving unwanted vault artifacts | OPEN |
| Voice owner-visible product surfaces | Owner still reports voice does not work | Surface read-aloud matrix and audible/manual proof from exact archive | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive June send/log proof or remove remaining automatic prompt-upgrade system | OPEN |

## 2026-07-09 00:15 Update: Owner-Visible Editing And Voice Regressions Are Prompt 2 Blockers

Latest owner steer:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work just note that and fix as wel as theo hter thigns ur working on please

> one bad thing i noticed is that th epdoc takes a long tme to load ... transition from one surface to epdoc makes the epdoc lose uts rich tables and formattig ... edittign in epdoc hangs badly ... all surfaces code edutor prose sruce epdoc ... hang when i start typign ... trying to go to a coee editor, epdoc and other surfaces from graph embedded gaph nad th4 hologram graph cuases hangs

Interpretation:

- Voice remains a live MAS release blocker. Previous readiness/log evidence is insufficient because the owner still cannot hear or rely on read-aloud in the product.
- Epdoc load latency, rich table/formatting loss across surface switches, graph-to-editor hangs, and keystroke stalls across Code/Prose/Source/Epdoc are Prompt 2 MAS product blockers, not deferred polish.
- The likely risk surface is document load/save/surface-switch storage behavior: avoid copy/markdown downgrade when switching into Epdoc, avoid synchronous body/package/index work on the main typing path, and preserve rich Epdoc package state across view transitions.
- Do not use stale debug apps as proof. Fixes need source tests first, then a new exact MAS archive and manual/runtime proof at the next meaningful checkpoint.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Epdoc load latency | MAS feels un-hardened and blocks normal use | Instrument or source-audit Epdoc load path; remove avoidable cold-load/recreation work; archive/manual proof that Epdoc opens promptly from MAS app | HIGH OPEN |
| Epdoc rich formatting loss | Surface switch appears to copy/downgrade Epdoc instead of rerendering package | Prove switching from Prose/Source/Graph to Epdoc does not rewrite rich package/tables through lossy markdown; add regression guard | HIGH OPEN |
| Cross-editor typing hangs | Code, Prose, Source, Epdoc all stall on keystrokes | Identify shared save/index/render path; debounce/off-main expensive work; focused tests/source guards plus manual archive typing proof | HIGH OPEN |
| Graph-to-editor hangs | Embedded graph/hologram graph to editor transitions are slow | Inspect graph route/open-editor path for synchronous body/package loads or repeated editor construction; patch and prove | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Treat as product failure until exact archive audible/manual proof exists across owned surfaces | HIGH OPEN |
| Prompt upgrade/Hermes send path | June still feels like it upgrades prompts on send | Disable/remove remaining automatic prompt-upgrade behavior or prove send is literal in exact archive | OPEN |

## 2026-07-09 00:35 Update: MAS Epdoc Clean-Switch Formatting Guard Added

Owner-visible regression addressed in this slice:

- Clean switches out of Markdown-backed Epdoc Document mode could previously force a WebKit Markdown snapshot and save it even when the surface was not dirty.
- That path could normalize Markdown tables and make a surface transition look like a lossy copy instead of a rerender.
- Document autosave now uses a `2s` quiet window instead of the prior few-hundred-millisecond write path.
- Dirty switches still flush a fresh direct editor snapshot before host save.

Touched source/test files in this slice:

- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

MAS verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-clean-switch-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()'
```

Result:

- `** TEST SUCCEEDED **`
- xcresult: `build/xcode-results/2026-07-09-002140-67175.xcresult`

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-clean-switch-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreMarkdownDocumentDirtySwitchSavesDirectEditorSnapshot()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreMarkdownDocumentCleanSwitchDoesNotSaveNormalizedTableSnapshot()'
```

Result:

- `** TEST SUCCEEDED **`
- xcresult: `build/xcode-results/2026-07-09-002744-77694.xcresult`
- Build log showed App Store compile flags: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Epdoc load latency | Clean-switch save regression is bounded, but cold/open load may still be slow | Inspect load/recreate path and add timing/source guard; exact MAS archive manual proof | HIGH OPEN |
| Cross-editor typing hangs | Autosave quiet window helps Document mode only; Code/Prose/Source shared stalls remain likely | Audit per-keystroke metrics/save/index/graph paths; patch off-main/debounce behavior; MAS tests and manual archive typing proof | HIGH OPEN |
| Graph-to-editor hangs | Surface transition may still do synchronous body/package/editor setup | Inspect graph open routes and editor activation path; patch avoidable repeated load/snapshot work | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Disable/remove remaining automatic prompt-upgrade behavior or prove send is literal in exact archive | OPEN |

## 2026-07-09 Update: Editor Fastness Regression Owner Steer

Latest owner wording:

> one bad thing i noticed is that th epdoc takes a long tme to load ... transition from one surface to epdoc makes the epdoc lose uts rich tables and formattig ... edittign in epdoc hangs badly ... all surfaces code edutor prose sruce epdoc ... hang when i start typign ... graph embedded gaph nad th4 hologram graph cuases hangs ... idk if its hte new storage or what but irealyl wnat that tobe hardnened

Interpretation:

- Treat editor latency as a Prompt 2 MAS hardening blocker because it affects normal product use and can look like storage/data-loss.
- Keep the existing clean-switch Epdoc table guard, then continue into shared typing/open paths.
- Prioritize removing expensive work from every keystroke and every surface activation: outline/KnowledgeCore scans, block mirror/save duplication, indexing, and graph/editor state churn must be debounced, off-main, or gated.
- Do not claim this fixed from a source guard alone. Current slice should produce MAS AppStore tests and record remaining archive/manual proof debt.

Next action:

- Patch `NoteDetailWorkspaceView`, `CodeEditorView`, and the save/metrics path only where source inspection shows synchronous or over-eager work during typing/surface switches. Preserve MAS vault persistence and Epdoc package fidelity.

## 2026-07-09 Update: MAS Editor Typing Hot-Path Guard Added

Owner-visible regression addressed in this slice:

- Prose typing was refreshing editor metrics after a 300 ms debounce and then could run deterministic outline refresh plus `KnowledgeCoreBlockOutline.items(...)`.
- The note outline overlay could also mount in Document/Preview/Source and parse Markdown inside the overlay when the parent did not provide precomputed outline items.
- This slice gates those expensive outline paths away from the live typing and non-edit surface-switch paths. Clean Epdoc switching/table preservation from the previous slice remains in place.

Touched source/test files in this slice:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `EpistemosTests/NoteEditorLayoutTests.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`

Behavioral changes:

- Added `NoteWorkspacePerformancePolicy.liveTypingMetricsQuietWindow = 900 ms`.
- Added `includeHeavyOutlines` to `scheduleMetricsRefresh`.
- Live typing now updates word count and normal parsed headings but does not run deterministic outline refresh or KnowledgeCore block-outline refresh.
- Edit mode passes an explicit `tocItems` array into `NoteOutlineOverlay`, including empty arrays, so the overlay does not self-parse Markdown during live edit churn.
- Document/Preview/Source do not mount the outline overlay by default (`nonEditOutlineOverlayEnabled = false`), avoiding parse work during Epdoc/Source transitions.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  EpistemosTests/NoteEditorLayoutTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- xcresult: `build/xcode-results/2026-07-09-003805-83313.xcresult`

Non-MAS test note:

- Attempted to run `EpistemosTests/NoteEditorLayoutTests/outlineContentAndNavigationBelongToActiveSurface()` through `Epistemos-AppStore`, but that target is not a member of the MAS scheme/test plan. It was not used as MAS evidence.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Cross-editor typing hangs | Metrics/outline churn is reduced, but Code/Source snapshot churn and save/index work may still stall | Continue source audit on CodeEditor snapshot path, Prose overlay refreshes, and file-first save/index work; then exact archive manual typing proof | HIGH OPEN |
| Epdoc cold/open latency | This does not directly measure Epdoc initial package load | Instrument or source-audit Epdoc load/recreation path; exact archive manual proof | HIGH OPEN |
| Graph-to-editor hangs | This does not yet patch graph route/open-editor state churn | Inspect embedded graph/hologram editor activation paths and avoid repeated editor/source loads | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-09 Update: Base App MAS Archive Proof After Legacy Quarantine

Owner steer:

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

Interpretation:

- Broad dirty-state caution is no longer a blocker to Prompt 2 work.
- Current lock remains MAS-only: normal/base app reality must be `Epistemos` product name backed by the `Epistemos-AppStore` target, `EPISTEMOS_APP_STORE`, and `MAS_SANDBOX`.
- Continue touching project/source/build state as needed, but keep evidence tied to the exact MAS archive app and do not use stale debug/legacy apps as proof.

Exact archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-base-quarantine-1507 \
  CODE_SIGNING_ALLOWED=YES
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Built target: `Epistemos-AppStore`
- Built configuration: `Release`
- Built app path: `build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier from built `Info.plist`: `com.epistemos.appstore`
- Product name/executable: `Epistemos`
- Compile flags observed in Release build settings and archive compile invocation: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- App sandbox entitlement present; app-scope bookmark and user-selected read-write entitlements present; JIT/library-validation/network-server entitlements absent.

Base-app reality proof:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -showBuildSettings | rg 'TARGET_NAME|PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_ACTIVE_COMPILATION_CONDITIONS|CODE_SIGN_ENTITLEMENTS|ENABLE_APP_SANDBOX|CONFIGURATION'
```

Result:

- `TARGET_NAME = Epistemos-AppStore`
- `PRODUCT_NAME = Epistemos`
- `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
- `CONFIGURATION = Release`
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`
- `ENABLE_APP_SANDBOX = YES`

JuneWeb packaging proof:

- `Contents/Resources/JuneWeb/dist/index.html` exists in the archive app.
- `Contents/Resources/JuneWeb/tauri-internals-shim.js` exists in the archive app.
- File sizes: `index.html` 2,142 bytes; `tauri-internals-shim.js` 18,034 bytes.

Release gates and scans:

```bash
./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate specifically passed normal `Epistemos` scheme mapping to the MAS App Store target/product.
- Gate passed archive checks for JuneWeb files.
- Gate passed absence checks for built App Store artifact loopback/runtime markers, retired runtime payload paths, retired-lane bundle strings, quarantine xattrs, prompt-upgrade UI, Hermes-branded send/session failure copy, and parked-lane visible CLI copy.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit/base-quarantine-1507 \
  ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- No parked account/backend runtime strings detected.
- No retired-lane strings detected.
- No `1Code` strings detected.
- No prohibited research/tool resource residue detected.
- No prohibited runtime symbols detected.
- Reports written to `build/appstore-audit/base-quarantine-1507`.

Explicit retired-runtime filename check:

```bash
find build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app -print |
  rg -i '(^|/)(ExperimentalWeb|1Code|OpenChamber|goosed|opencode|codex|node|bun|rg|experimental-runtime)(/|$|[._-])'
```

Result:

- No matches.

Launch proof:

- Stale process found before launch: PID `81474`, an older archive app at `build/appstore-release-archive-2026-07-09-prompt-send-copy-1400.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Stale process was terminated and was not counted as MAS evidence.
- Exact launch command used the archive path:

```bash
open -n /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app
```

Runtime proof:

- Launched PID: `99767`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Bundle identifier from launched app path: `com.epistemos.appstore`
- Process check after launch found no active stale `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, `experimental-runtime`, `/node`, `/bun`, or `/rg` dependency process matching the MAS drift query.

Visible proof:

- Screenshot paths:
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_15-15-14-w52932.png`
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_15-15-14-w52936.png`
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_15-15-14-w52934.png`
- Visual result: archived MAS app shows the June/Epistemos shell/home UI and vault/sidebar/settings windows. It does not show the previous `The Workspace bundle is missing from this build` panel.
- This is archive launch and bundle-packaging proof only; it is not proof that vault restore, June send, voice, Epdoc fidelity, code/source editability, or graph/editor latency are fully fixed.

Dirty-file grouping for this checkpoint:

- MAS-safe/current product: AppStore target/scheme/project changes, AppStore release gate and scans, `JuneWeb` bundle staging/scrubbing, vault restore guards, Kokoro English/read-visible code, Epdoc/editor/graph hot-path changes, June send/prompt-upgrade hardening.
- Shared substrate: vault storage/indexing, coordinated writes, graph projections, editor bridges, document/Epdoc surfaces, June gateway bridge types, speech synthesizer seams used by MAS.
- Parked-lane/legacy: `Epistemos-LegacyDev`, `Epistemos-Experimental`, `ExperimentalAgent`, direct Goose ACP/server/runtime files, Work/OpenCode/local-server paths, HTML/Python runtime paths. Current policy: inventory, guard, quarantine, or delete; not long-term product preservation.
- Generated/build artifact: `Epistemos.xcodeproj`, `.june-web-stage`, June fork `dist`, Rust Swift bindings, `build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive`, `build/appstore-release-archive-derived-2026-07-09-base-quarantine-1507`, `build/appstore-audit/base-quarantine-1507`, and recent `build/xcode-results/*.xcresult`.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Vault restore data-loss blocker | Owner-visible vault disconnect can make notes lose source access and saves fail with `no vault URL` | Exact archive select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen, prove same vault restored, `vaultSync.vaultURL` non-nil, no missing/unreadable toast, no `no vault URL` save log | HIGH NEXT |
| June send output | Owner reports MAS June still is not producing outputs | Exact archive send a known prompt, capture logs/events, prove visible assistant output or durable visible error without prompt-upgrade/Hermes drift | HIGH OPEN |
| Voice English/read-aloud | Owner reports voice still does not work and was non-English | Exact archive Kokoro readiness + English voice selection + audible/manual preview; surface matrix for June, Prose, Epdoc, Quick Capture, current visible surface | HIGH OPEN |
| Epdoc load/fidelity | Owner reports slow Epdoc load and rich table/formatting loss switching surfaces | Exact archive Epdoc open/switch/edit proof with logs/screenshot; source guards already added but runtime proof still missing | HIGH OPEN |
| Graph/editor latency | Owner reports embedded/hologram graph startup and node-to-editor transitions hang | Exact archive graph startup and node edit/open proof; continue pruning synchronous preview/save/index fanout | HIGH OPEN |
| Code/source editability | Owner reports code editor view-only | Exact archive Code/Source edit and save proof | HIGH OPEN |
| Legacy deletion/quarantine | Prompt 2 end state is one active product reality: MAS/June | Continue inventory across rg/project.yml/build phases/schemes/tests/generated bundles/processes; delete or quarantine direct-lane runtime after ownership mapping | OPEN |

## 2026-07-09 Update: Exact Archive Vault Restore Relaunch Proof

Owner context:

> after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault ... Logs include "Cannot save page body: no vault URL."

Interpretation:

- Treat vault restore as a data-loss/release blocker until the exact `Epistemos-AppStore` archive proves the selected vault survives quit/reopen and `vaultSync.vaultURL` is non-nil after launch.
- Do not count source guards alone as proof.

Exact archive under test:

- App path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Initial archive launch PID before relaunch: `99767`
- Relaunch PID after clean quit/reopen: `433`

Quit/reopen command:

```bash
osascript -e 'tell application id "com.epistemos.appstore" to quit'
open -n /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app
```

Process proof after relaunch:

- Active process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-base-quarantine-1507.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Post-launch process scan showed no active `Epistemos-LegacyDev`, `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, `experimental-runtime`, `/node`, `/bun`, or `/rg` dependency process matching the MAS drift query.

Saved bookmark/defaults proof:

```bash
plutil -p "$HOME/Library/Containers/com.epistemos.appstore/Data/Library/Preferences/com.epistemos.appstore.plist" |
  rg 'epistemos\.vaultBookmark|epistemos\.lastVaultPath|hasEverConnected'
```

Result:

- `epistemos.hasEverConnectedAVault` is true.
- `epistemos.lastVaultPath` is `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`.
- `epistemos.vaultBookmark` exists.

Machine-readable `vaultSync.vaultURL` witness:

```bash
cat "/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)/.epcache/diagnostics/crash-recorder-ready.json"
```

Result:

```json
{
  "installedAt" : "2026-07-09T20:18:54Z",
  "processID" : 433,
  "signalLog" : "fatal-signals.log",
  "vaultPath" : "/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)"
}
```

Interpretation: after exact archive relaunch, `VaultCrashRecorder.updateVaultURL(vaultURL)` wrote the ready marker inside the selected vault with the relaunched PID and exact vault path, which is direct runtime evidence that `vaultSync.vaultURL` was non-nil after launch.

Visible proof:

- Relaunch screenshot paths:
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_15-19-14-w52952.png`
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_15-19-14-w52956.png`
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_15-19-14-w52954.png`
- The Notes/sidebar window visibly shows `KIMI_AGENT_DETERMINISTIC AI DEEP DIVE...` with folders and file rows after relaunch.
- No screenshot showed the owner-reported `Saved vault bookmark points to a missing or unreadable directory` startup toast.

Focused MAS test proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-vault-restore-proof-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRetriesTransientMASBookmarkPreflightInsteadOfWarning()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneStartupRestoreFailurePreservesLocalVaultState()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLanePreservesBookmarkOnTransientRestoreFailures()'
```

Result:

- `** TEST SUCCEEDED **`
- 4 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-152011-585.xcresult`

Remaining vault verification debt:

- I did not intentionally create or edit a user note in the live Kimi vault for this proof pass. The exact archive relaunch proved selected-vault restoration and non-nil `vaultSync.vaultURL`; save-path proof remains covered by source/unit guards unless a later manual edit proof is run.
- App custom `Log.vault` messages were not visible through the persisted unified-log query for the exact release archive; runtime diagnostics and crash-recorder marker provided the durable state witness instead.

Updated Prompt 2 priority after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Voice English/read-aloud | Owner reports voice still does not work and was non-English | Exact archive Kokoro readiness + English voice selection + audible/manual preview; surface matrix for June, Prose, Epdoc, Quick Capture, current visible surface | HIGH NEXT |
| June send output | Owner reports MAS June still is not producing outputs | Exact archive send a known prompt, capture logs/events, prove visible assistant output or durable visible error without prompt-upgrade/Hermes drift | HIGH OPEN |
| Epdoc load/fidelity | Owner reports slow Epdoc load and rich table/formatting loss switching surfaces | Exact archive Epdoc open/switch/edit proof with logs/screenshot; source guards already added but runtime proof still missing | HIGH OPEN |
| Graph/editor latency | Owner reports embedded/hologram graph startup and node-to-editor transitions hang | Exact archive graph startup and node edit/open proof; continue pruning synchronous preview/save/index fanout | HIGH OPEN |
| Code/source editability | Owner reports code editor view-only | Exact archive Code/Source edit and save proof | HIGH OPEN |
| Legacy deletion/quarantine | Prompt 2 end state is one active product reality: MAS/June | Continue inventory across rg/project.yml/build phases/schemes/tests/generated bundles/processes; delete or quarantine direct-lane runtime after ownership mapping | OPEN |

## 2026-07-09 Update: Base App MAS Reality / Legacy Target Quarantine

Owner context:

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

Interpretation:

- The old direct `Epistemos` product target name was still too easy to confuse with the MAS product.
- Prompt 2 is not complete while a normal owner-opened `Epistemos` path can mean the old 1Code/OpenChamber/Experimental surface.
- The normal `Epistemos` scheme must build/run the MAS App Store product; legacy must be explicit and quarantined.

Change:

- `project.yml` application target `Epistemos` is renamed to `Epistemos-LegacyDev`.
- Legacy product and executable are now `Epistemos-LegacyDev.app` / `Epistemos-LegacyDev`.
- Legacy bundle id is `com.epistemos.legacydev`.
- `EpistemosTests` test host now points at `Epistemos-LegacyDev.app`.
- The normal shared `Epistemos.xcscheme` builds/runs/archives `Epistemos-AppStore`.
- `Epistemos-LegacyDev.xcscheme` and `Epistemos-Experimental.xcscheme` are the only schemes that point at the quarantined legacy target.
- `scripts/keelstone-release-gate.sh` now fails unless the only application targets are `Epistemos-LegacyDev` and `Epistemos-AppStore`.
- MAS tests and legacy guard tests were updated to reject stale `BlueprintName = "Epistemos"` / `BuildableName = "Epistemos.app"` legacy expectations.

Files changed in this slice:

- MAS-safe:
  - `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
  - `scripts/keelstone-release-gate.sh`
  - `project.yml`
  - `Epistemos.xcodeproj/project.pbxproj`
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme`
- Shared substrate / legacy guard:
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `EpistemosTests/AppStoreHardeningTests.swift`
  - `EpistemosTests/ThemePairTests.swift`
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-LegacyDev.xcscheme`
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-Experimental.xcscheme`
- Parked-lane / legacy:
  - The old direct application target is now only `Epistemos-LegacyDev`.
- Generated/build artifact:
  - `Epistemos.xcodeproj/**` regenerated by `xcodegen generate --spec project.yml`.
  - `build/derived-mas-base-quarantine-2026-07-09/**`
  - `build/xcode-results/2026-07-09-150226-93064.xcresult`

Verification:

```bash
xcodegen generate --spec project.yml
```

Result:

- Succeeded; regenerated `Epistemos.xcodeproj`.

```bash
xcodebuild -project Epistemos.xcodeproj -list
```

Result:

- Application targets include `Epistemos-AppStore` and `Epistemos-LegacyDev`; no application target named plain `Epistemos`.
- Shared schemes include `Epistemos`, `Epistemos-AppStore`, `Epistemos-LegacyDev`, and `Epistemos-Experimental`.

```bash
rg -n -- "Epistemos Legacy Dev|BlueprintName = \"Epistemos\"|BuildableName = \"Epistemos.app\"|target_section \"Epistemos\"|com\.epistemos\.app;|PRODUCT_NAME = \"Epistemos Legacy Dev\"|TEST_HOST = \"\$\(BUILT_PRODUCTS_DIR\)/Epistemos Legacy Dev" \
  project.yml Epistemos.xcodeproj EpistemosAppStoreKeelstoneTests EpistemosTests scripts/keelstone-release-gate.sh
```

Result:

- No matches.

```bash
git diff --check -- \
  project.yml \
  scripts/keelstone-release-gate.sh \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  EpistemosTests/RuntimeValidationTests.swift \
  EpistemosTests/AppStoreHardeningTests.swift \
  EpistemosTests/ThemePairTests.swift \
  Epistemos.xcodeproj/project.pbxproj \
  Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme \
  Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-LegacyDev.xcscheme \
  Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-Experimental.xcscheme
```

Result:

- Passed.

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Release -showBuildSettings
```

Result:

- Target resolved by the normal scheme: `Epistemos-AppStore`.
- Product path: `Epistemos.app`.
- Bundle id: `com.epistemos.appstore`.
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`.
- `ENABLE_APP_SANDBOX = YES`.

```bash
./scripts/keelstone-release-gate.sh
```

Result:

- Passed.
- Gate proves exactly two application targets: `Epistemos-LegacyDev`, `Epistemos-AppStore`.
- Gate proves normal `Epistemos` scheme launches `Epistemos-AppStore`.
- Gate proves legacy direct target/product is explicit in `Epistemos-LegacyDev`.
- Gate proves App Store target has `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`, lacks `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED`, has sandbox settings, packages JuneWeb, and excludes parked runtime resources.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-base-quarantine-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/normalEpistemosSchemeLaunchesMASTarget()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-150226-93064.xcresult`
- Test build compiled with `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`.
- Built Debug MAS app path during test: `build/derived-mas-base-quarantine-2026-07-09/Build/Products/Debug/Epistemos.app`
- Test runtime bundle id/log path: `com.epistemos.appstore`.

Current verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Fresh exact Release archive after base quarantine | Previous archives predate the target rename and source fixes | Archive normal `Epistemos` / `Epistemos-AppStore` Release app, run source/target/archive leak scans, run gate with `--appstore-app`, and launch exact archive app | OPEN NEXT |
| Visible owner app path | Scheme/build proof is resolved, but installed `/Applications/Epistemos.app` or LaunchServices aliases can still be stale external state | Replace/promote the accepted archive app to the owner-opened path or explicitly document the exact archive/open path after current archive proof | OPEN |
| Vault restore real archive | Source/tests prove scope-time readability checks, but owner saw vault disconnect in real app | Select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove restored vault and no no-vault save logs | HIGH OPEN |
| Kokoro English voice real archive | Source/tests prove English voice/phoneme selection, but owner heard non-English/no voice | Exact archive Settings preview and read-visible-surface manual audible proof with logs | HIGH OPEN |
| June send real archive | Source/tests prove prompt forge disabled and error persistence, but owner reports no June outputs | Exact archive send test with logs, no Prompt Forge/Hermes prompt-upgrade drift, durable assistant reply or visible error | HIGH OPEN |
| Epdoc/graph/editor performance real archive | Source/tests guard obvious hot paths, but owner saw slow load, formatting loss, and hangs | Exact archive manual performance/fidelity pass across Epdoc, Prose, Source/Code, embedded graph, hologram graph | HIGH OPEN |

## 2026-07-09 Update: Graph/Epdoc Editor Hang Feedback Loop

Owner context:

> graph embedded and hologram graph when i go to ndes it takes a long time to lead them up and when i edit anythign in the graph hologram or embedded graoh they hang so editting anyhtig through the graph surfaces makes tehm hang badly and lots of performance issues

Interpretation:

- Treat graph-to-editor startup latency and graph-surface editing hangs as Prompt 2 MAS blockers.
- Preserve immediate note/vault writes, but decouple noncritical derived graph/manifest work from the autosave path.
- Do not use stale preview/debug UI as proof; this slice is source/build guard proof only until the next exact archive proof.

Change:

- `NoteDetailWorkspaceView` now disables heavy deterministic/block outline work for graph-embedded note loads and body reloads.
- Graph-embedded notes no longer mount the outline overlay, so opening a node from embedded/hologram graph does not pay the full notes-window outline cost.
- `AppCoordinator` now coalesces ambient manifest refreshes from `.vaultPageChanged` with a two-second delayed page-mutation task instead of rebuilding the manifest immediately on every page save.
- `VaultSyncService.publishVaultMutation(_:)` now keeps immediate graph refresh for `.vaultChanged`, but coalesces `.vaultPageChanged` graph refresh into a delayed task.
- Existing editor fixes remain covered: Source route stale-read guard, MarkEdit dirty flag box, and read-only Hologram inspector preview.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  Epistemos/App/AppCoordinator.swift \
  Epistemos/Sync/VaultSyncService.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-graph-epdoc-perf-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsHologramInspectorPreviewReadOnly()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneClearsStaleCleanLensSnapshotsAfterPersistedReload()'
```

Result:

- `** TEST SUCCEEDED **`
- 3 Swift Testing tests passed.
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-145314-89617.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive Epdoc proof | Debug MAS source/unit guards can miss Release/archive WKWebView latency and formatting regressions | Rebuild/archive exact MAS app; open Epdoc, switch Prose/Source/Document, verify tables stay rich and editing is responsive | HIGH OPEN |
| Exact archive graph-to-editor proof | Debug MAS guards do not prove real graph embedded/hologram navigation latency | Rebuild/archive exact MAS app; open nodes from embedded graph and hologram graph; verify editors open without hangs and typing remains responsive | HIGH OPEN |
| Code editor real edit proof | Source guard shows local editor sessions editable, but owner saw view-only behavior | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| Voice owner-visible product surfaces | Owner reports voice still not working and sounded non-English | Exact archive Kokoro-ready proof, English voice selection proof, audible/manual proof, and surface matrix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes and does not produce outputs | Exact archive send proof with logs; ensure failed sends persist a visible assistant error instead of disappearing | HIGH OPEN |
| Vault restore archive proof | Source/test fixes are insufficient for the owner-visible bookmark regression | Exact archive vault select/quit/reopen proof with `vaultSync.vaultURL != nil`, no unreadable bookmark toast, and no `no vault URL` save logs | HIGH OPEN |
| Base app MAS default | Owner cannot trust the product while normal/base Epistemos can open old 1Code/OpenChamber surface | Make base app MAS-equivalent or quarantine/rename legacy dev target; prove normal launch opens MAS/June | HIGH OPEN |

## 2026-07-09 Update: Editor/Graph Hang and Epdoc Switch Guards

Owner steer:

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

Interpretation:

- Broad dirty state is not a blocker for this MAS run.
- Continue touching any source, project config, generated gate, or parked-lane ownership file needed to make MAS/June the single product reality.
- Still keep verification evidence and this durable ledger current.

Changes:

- Fixed Source/Code editor bridge input dirty tracking so typing no longer assigns into an immutable JavaScript binding on every input event.
- Fixed Source-to-Epdoc stale async read guard so a delayed Source read only applies when the currently visible route is still Source for the same file.
- Moved Hologram graph inspector note preview loading off the synchronous `currentBody(for:)` path and removed the preview-only save pipeline from that inspector. It now loads a preview snapshot asynchronously and remains read-only.

MAS verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-graph-fixes-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRetriesRestoredSourceReadsAfterVaultRestore()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsHologramInspectorPreviewReadOnly()'
```

Result:

- `** TEST SUCCEEDED **`
- 3 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-143531-85228.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive Epdoc proof | Debug MAS guards can miss Release/archive WKWebView latency and formatting loss | Rebuild/archive exact MAS app; open Epdoc, switch Prose/Source/Document, verify rich tables/formatting survive and editing is responsive | HIGH OPEN |
| Exact archive graph-to-editor proof | Source guards can miss Release runtime graph navigation stalls | Launch exact MAS archive; open embedded graph and hologram graph; open nodes into Prose/Source/Code/Epdoc; type and capture no hang/no formatting loss | HIGH OPEN |
| Code editor real edit proof | Source guard fixes one likely input bridge bug, but owner saw view-only behavior | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| Kokoro English audible proof | Debug guard proves English voice/token path, but owner heard non-English audio | Rebuild exact archive; Voice preview and read-visible-surface logs must show English voice and successful playback; owner/manual audible proof still required | HIGH OPEN |
| June send/output | Owner reports MAS June still does not produce outputs | Audit native gateway and June fork submit path, patch drift, then exact archive send proof with logs | HIGH OPEN |
| Base/default app MAS reality | Owner still sees ambiguity between base app and MAS scheme | Make normal/base launch path MAS/June-equivalent or quarantine/rename legacy; prove normal launch opens MAS/June | HIGH OPEN |

## 2026-07-09 Update: June Send Failure Visibility

Owner context:

> june mas still is not rlly working it is not producing outputs and i cant tell if it even works

Interpretation:

- A send that fails due missing cloud/provider setup must not look like a silent no-op.
- MAS June should persist a visible assistant/error turn so reloads and session refreshes do not erase the failure.
- The web status reducer must not classify a `message.complete` payload with `status: "error"` as a successful completion.

Changes:

- `JuneAgentGateway.startTurn` now turns failures into a durable assistant message with `Error: ...` text and emits the same payload with `status: "error"`.
- The June fork `AgentWorkspace` now maps `message.complete` with payload status `error` to `failed`, and `cancelled` to `cancelled`, before the generic terminal-complete path.
- Rebuilt/staged JuneWeb through `./build-june-web.sh`; staged output is `.june-web-stage` and includes `dist/index.html` plus `tauri-internals-shim.js`.

MAS verification:

```bash
./build-june-web.sh
```

Result:

- Passed.
- Fork: `/Users/jojo/dev/june-epistemos @ 7105c43c`.
- Staged 27 files to `.june-web-stage`; main chunk 523 KB gz.
- Warning noted: fork working tree is dirty, so staging includes current uncommitted fork state.

```bash
rg -n "System Prompt Forge is disabled|prompt\\.forge_preview|Hermes did not|Could not connect to Hermes|message\\.complete|June session transport|June did not create|status.*error|cancelled" \
  .june-web-stage Epistemos/JuneAgent EpistemosAppStoreKeelstoneTests scripts/keelstone-release-gate.sh
```

Result:

- No old Hermes visible failure copy found in `.june-web-stage`.
- Remaining Hermes matches are release-gate patterns or native compatibility/type names.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-june-send-error-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReleaseGateRejectsArchivedJuneWebPromptForgeCommandDrift()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed.
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-144326-87304.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive June send proof | Debug source/staged proof can miss Release archive runtime provider/session behavior | Rebuild/archive exact MAS app; send known prompt; capture visible assistant output or durable error message plus logs | HIGH OPEN |
| Exact archive Epdoc proof | Debug MAS guards can miss Release/archive WKWebView latency and formatting loss | Rebuild/archive exact MAS app; open Epdoc, switch Prose/Source/Document, verify rich tables/formatting survive and editing is responsive | HIGH OPEN |
| Exact archive graph-to-editor proof | Source guards can miss Release runtime graph navigation stalls | Launch exact MAS archive; open embedded graph and hologram graph; open nodes into Prose/Source/Code/Epdoc; type and capture no hang/no formatting loss | HIGH OPEN |
| Kokoro English audible proof | Debug guard proves English voice/token path, but owner heard non-English audio | Rebuild exact archive; Voice preview and read-visible-surface logs must show English voice and successful playback; owner/manual audible proof still required | HIGH OPEN |
| Base/default app MAS reality | Owner still sees ambiguity between base app and MAS scheme | Make normal/base launch path MAS/June-equivalent or quarantine/rename legacy; prove normal launch opens MAS/June | HIGH OPEN |

## 2026-07-09 Update: Owner Full-Freedom MAS Completion Steer

Owner context:

> u have full freedom to tou ch anythign stop saying u are not tocuhgi broad state do whatever u need to do u are not blocked on anythig

Interpretation:

- The MAS-only completion lock remains active.
- Broad source changes are allowed when they are necessary to resolve the MAS product blockers.
- Do not stop or defer because the worktree is broad/dirty; continue using source-grounded edits, tests, and archive proof.
- Do not treat legacy 1Code/Experimental scope rules as binding for this MAS run.

Immediate evidence added:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-voice-english-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-142522-82993.xcresult`
- The test proves MAS default Kokoro selection stays on an installed English checked voice (`af_heart`) when the global voice default is not a Kokoro voice, and that the preview phrase is converted to English phoneme symbols instead of raw character tokens.

Updated verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Kokoro exact archive audible English proof | Source/unit proof does not prove owner-heard English output in the archived app | Rebuild Release archive, launch exact archive app, run Voice preview with live Kokoro logs and manual audible check | HIGH OPEN |
| Epdoc switch fidelity and load latency | Source fast-path helped one switch path, but owner still sees slow loads and rich table loss | Audit and patch Epdoc/MarkEdit bridge lifecycle, prevent destructive markdown reparse on view switches, exact archive manual proof | HIGH OPEN |
| Graph embedded/hologram graph editor latency | Graph node selection/editing may still trigger synchronous graph/sidebar/index/editor rebuilds | Audit graph route/inspector/node editor path, patch expensive main-actor work and edit gating, exact archive proof | HIGH OPEN |
| June MAS output | Owner reports June still does not produce outputs | Audit June bridge/gateway/send/log path under MAS, patch prompt-upgrade leftovers/output failure path, exact archive send proof | HIGH OPEN |
| Base app MAS product reality | Prompt 2 is not done if normal/base app can still be confused with legacy 1Code/OpenChamber | Keep normal scheme mapped to MAS/June or quarantine legacy naming; rerun scheme/project/gate scans | HIGH OPEN |

## 2026-07-09 Update: Owner Reprioritized Visible Prompt 2 Blockers

Owner steer excerpt:

> the main issues were the loading of epdoc, and also switchign fromotehr surfaces to epdoc and from epdoc meses up epdoc's formatting that should not happen ans the other issues are the voice is not in english ... graph embedded and hologram graph when i go to ndes it takes a long time ... when i edit anythign in the graph hologram or embedded graoh they hang ... june mas still is not rlly working it is not producing outputs

Interpretation:

- Keep the MAS/base-app Prompt 2 lock active, but prioritize owner-visible product failures before broad pruning polish.
- Treat non-English Kokoro output as a real release blocker, not a model-install dismissal: exact archive proved CoreML playback starts, but the native path must feed English voice/phoneme inputs.
- Treat Epdoc load latency and cross-surface formatting loss as release blockers. Switching to/from Epdoc must preserve rich tables and must not serialize a degraded copy.
- Treat graph embedded/hologram graph node-to-editor transitions and graph-origin editing hangs as release blockers.
- Treat June MAS no-output/no-obvious-working-send as release blocker. Prompt-upgrade removal is not sufficient without a live MAS reply proof.

Verification debt added:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Kokoro English output | CoreML can play audio while sounding non-English if text is not phonemized or an English voice is not selected | Force English Kokoro voice/default; route English text through MAS-safe phoneme input; exact archive preview/read-surface audible proof | HIGH OPEN |
| Epdoc switch fidelity | Surface switches can save normalized/degraded snapshots and lose rich tables | Exact archive switch matrix Prose/Source/Epdoc with table-rich document and no formatting loss | HIGH OPEN |
| Graph-to-editor performance | Graph/hologram origin may force heavy graph/editor warmups and synchronous save/index work | Measure and patch node open/edit path; exact archive graph-to-Prose/Code/Epdoc typing proof | HIGH OPEN |
| June MAS output | June bundle may load but send path may not produce assistant output | Exact archive send known short prompt; prove reply or actionable failure log without prompt-upgrade/Hermes drift | HIGH OPEN |

## 2026-07-09 Update: Prompt Send Copy Hardened and Exact Release Archive Re-Proved

Owner context:

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpretation:

- Prompt 2 MAS must not expose Prompt Forge/send-review behavior on normal June send.
- The archived MAS app must not carry user-visible Hermes-branded send/session failure copy.
- Source guards are insufficient; the exact Release AppStore archive must be rebuilt, scanned, launched, and visibly checked.

Change:

- June web fork send/session failure copy now says `June session...` instead of Hermes-branded transport text.
- The retry classifiers now recognize the new June transport/session connection strings, preserving retry UI behavior.
- `scripts/keelstone-release-gate.sh` now fails staged and built JuneWeb bundles containing old Hermes-branded send/session failure strings.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` now expects the new staged/built release-gate witnesses.

Web verification:

```bash
./node_modules/.bin/vitest run \
  src/test/hermes-gateway.test.ts \
  src/test/hermes-trace-buffer.test.ts \
  src/test/hermes-session-steer.test.ts \
  src/test/agent-workspace.test.tsx \
  -t 'rejects requests pending|records an error|dropped connection|connection-shaped error|error surface'
```

Result:

- 4 Vitest files passed.
- 5 selected tests passed, 173 skipped.

MAS source/stage verification:

```bash
./build-june-web.sh
./scripts/keelstone-release-gate.sh
```

Result:

- `build-june-web.sh` staged 27 JuneWeb files from `/Users/jojo/dev/june-epistemos`.
- KEELSTONE release gate passed.
- Staged JuneWeb omitted prompt-upgrade UI/send-review hooks.
- Staged JuneWeb omitted Hermes-branded send/session failure copy.
- Normal `Epistemos` scheme still maps to the MAS AppStore target and product.

Focused MAS test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-prompt-hermes-copy-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReleaseGateRejectsArchivedJuneWebPromptForgeCommandDrift()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-135516-73290.xcresult`

Exact Release archive command:

```bash
STAMP="2026-07-09-prompt-send-copy-$(date +%H%M)"
printf '%s\n' "$STAMP" > build/current-mas-archive-stamp.txt
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "build/appstore-release-archive-$STAMP.xcarchive" \
  -derivedDataPath "build/appstore-release-archive-derived-$STAMP" \
  -clonedSourcePackagesDirPath .spm-cache
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Actual stamp: `2026-07-09-prompt-send-copy-1400`
- Exact app: `build/appstore-release-archive-2026-07-09-prompt-send-copy-1400.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Target: `Epistemos-AppStore`
- Product: `Epistemos.app`
- Release build flags: `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- `ENABLE_APP_SANDBOX = YES`
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` are absent from the AppStore Release build settings.

Exact built-bundle gates:

```bash
APP="build/appstore-release-archive-2026-07-09-prompt-send-copy-1400.xcarchive/Products/Applications/Epistemos.app"
./scripts/keelstone-release-gate.sh --appstore-app "$APP"
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR="build/visible-mas-proof-2026-07-09-prompt-send-copy-1400/appstore-bundle-scan" \
  ./scripts/scan_appstore_bundle.sh "$APP"
```

Result:

- KEELSTONE release gate passed for the exact built archive app.
- Built app includes `Contents/Resources/JuneWeb/dist/index.html`.
- Built app includes `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- Built JuneWeb omits prompt-upgrade UI and send-review hooks.
- Built JuneWeb omits Hermes-branded send/session failure copy.
- Bundle scan found no prohibited runtime strings, no retired-lane strings, no `1Code` strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.
- Scan report: `build/visible-mas-proof-2026-07-09-prompt-send-copy-1400/appstore-bundle-scan/`

Exact archive launch proof:

```bash
/usr/bin/open -n "build/appstore-release-archive-2026-07-09-prompt-send-copy-1400.xcarchive/Products/Applications/Epistemos.app"
```

Result:

- Running PID: `81474`
- Running process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-prompt-send-copy-1400.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Runtime/codesign identifier: `com.epistemos.appstore`
- Runtime log scan for the last 2 minutes found zero hits for:
  - `Workspace bundle is missing`
  - `Saved vault bookmark points to a missing`
  - `unreadable directory`
  - `Cannot save page body: no vault URL`
- Screenshots:
  - `build/visible-mas-proof-2026-07-09-prompt-send-copy-1400/june-welcome-back-window.png`
  - `build/visible-mas-proof-2026-07-09-prompt-send-copy-1400/restored-vault-sidebar-window.png`
  - `build/visible-mas-proof-2026-07-09-prompt-send-copy-1400/settings-window.png`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive prompt send behavior | Source/bundle scans prove no Prompt Forge UI/hooks/copy, but not a live submitted turn | Send a short prompt in exact archive and log-scan for `prompt.submit` direct payload, no `prompt.forge_preview`, no Prompt Forge rewrite, no Hermes-branded failure | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive Kokoro readiness proof, Settings preview audible/log proof, and surface read-aloud matrix/fix | HIGH OPEN |
| Exact archive Epdoc proof | Source/unit guards can miss Release/archive WKWebView latency and formatting regressions | Open Epdoc in exact archive, switch Prose/Source/Document, verify tables stay rich and editing is responsive | HIGH OPEN |
| Exact archive editor typing proof | Release runtime can still hitch despite file-first/debounce changes | Type in Prose, Source/Code, and Epdoc in exact archive; capture logs/no hangs and vault write proof | HIGH OPEN |
| Code editor real edit proof | Owner saw code editor view-only behavior | Exact archive Code/Source edit and save proof | HIGH OPEN |
| Graph startup/editor transition proof | Owner reports graph startup and graph-to-editor hangs | Exact archive startup on graph, graph-to-editor transition timing/log proof | HIGH OPEN |

## 2026-07-09 Update: Exact Release Archive Visible MAS Proof After File-First/Voice/Editor Slice

Owner context:

> Pause after the current build/archive checkpoint. I need a visible MAS proof checkpoint before more Prompt 2 work.

> Package JuneWeb into the MAS archive at Contents/Resources/JuneWeb. Required files: JuneWeb/dist/index.html and JuneWeb/tauri-internals-shim.js.

> The running MAS archive shows "The Workspace bundle is missing from this build."

Interpretation:

- This checkpoint is proof of the current `Epistemos-AppStore` archive, not a Prompt 2 completion claim.
- Prompt 2 remains locked until the normal/base product reality is MAS/June and owner-visible regressions are resolved or logged as HIGH blockers.
- Stale DerivedData/debug apps and stale goosed/OpenChamber/ExperimentalWeb/node-style processes are not MAS evidence.

Exact archive command:

```bash
STAMP="2026-07-09-voice-filefirst-editor-$(date +%H%M)"
printf '%s\n' "$STAMP" > build/current-mas-archive-stamp.txt
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "build/appstore-release-archive-$STAMP.xcarchive" \
  -derivedDataPath "build/appstore-release-archive-derived-$STAMP" \
  -clonedSourcePackagesDirPath .spm-cache
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Stamp: `2026-07-09-voice-filefirst-editor-1336`
- Archive app: `build/appstore-release-archive-2026-07-09-voice-filefirst-editor-1336.xcarchive/Products/Applications/Epistemos.app`
- Proof directory: `build/visible-mas-proof-2026-07-09-voice-filefirst-editor-1336`

Exact built target identity:

- Scheme: `Epistemos-AppStore`
- Target: `Epistemos-AppStore`
- Configuration: `Release`
- Product name: `Epistemos`
- Bundle id from archive `Info.plist`: `com.epistemos.appstore`
- Build settings proof: `SWIFT_ACTIVE_COMPILATION_CONDITIONS =  EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- Negative build-settings proof: no `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED` hits in `build/visible-mas-proof-2026-07-09-voice-filefirst-editor-1336/build-settings-release.txt`
- Effective entitlements proof: sandbox/app-scope bookmark/user-selected read-write present; network server/JIT/library-validation exceptions absent.

Packaged JuneWeb proof:

- `Contents/Resources/JuneWeb/dist/index.html` exists in the archive app.
- `Contents/Resources/JuneWeb/tauri-internals-shim.js` exists in the archive app.
- Release gate enforces both files.

Release gates and scans:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-voice-filefirst-editor-1336.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate also proved the normal `Epistemos` scheme launches/builds/tests the MAS App Store target, and the direct legacy target is explicit in `Epistemos-LegacyDev`.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-voice-filefirst-editor-1336/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-voice-filefirst-editor-1336.xcarchive/Products/Applications/Epistemos.app
```

Result:

- App Store bundle scan passed.
- No quarantine xattrs.
- No prohibited runtime strings.
- No prohibited runtime symbols.
- No retired-lane strings.
- No `1Code` strings.
- No prohibited research/tool resource residue.
- Forbidden path scan had zero hits for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, or `experimental-runtime`.

Visible launch proof:

- Launched by exact path:
  `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-filefirst-editor-1336.xcarchive/Products/Applications/Epistemos.app`
- Running process proof:
  `pid=72692`
  `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-filefirst-editor-1336.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Running bundle id proof: `com.epistemos.appstore`
- Final process inventory had exactly one `Epistemos.app/Contents/MacOS/Epistemos` process, and it was the exact archive process above.
- Final screenshots:
  - `build/visible-mas-proof-2026-07-09-voice-filefirst-editor-1336/visible-mas-archive-window-final-w52574.png`
  - `build/visible-mas-proof-2026-07-09-voice-filefirst-editor-1336/visible-mas-archive-window-final-w52576.png`
- Manual visual read: exact archive loaded MAS/June and the Kimi vault sidebar; it did not show the missing Workspace bundle panel.

Vault continuity observations in this launch:

- `defaults read com.epistemos.appstore epistemos.lastVaultPath` returned `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`.
- Unified log scan for this launch had no hits for:
  - `Workspace bundle is missing`
  - `Saved vault bookmark points to a missing`
  - `unreadable directory`
  - `Cannot save page body: no vault URL`
- The screenshot showed the selected `KIMI_AGENT_DETERMINISTIC AI DEEP DIVE...` vault sidebar.

Stale process classification:

- One older archived Epistemos instance was present earlier in the proof run and was not counted as evidence. After cleanup, only the current exact archive `Epistemos` process remained.
- Remaining `node headless/dist/index.cjs`, Codex `node_repl`, Claude helper, system helper, and containermanager processes are external tooling/system processes and not MAS app dependencies or MAS evidence.
- No active goosed/OpenChamber/ExperimentalWeb/opencode/bun/experimental-runtime process is required by, or counted as evidence for, the MAS archive.

Prompt/Hermes residue finding:

- Archive `JuneWeb` prompt/Hermes scan produced 14 lines.
- The visible Prompt Forge/send-review UI strings remain absent per release gate, but the built JuneWeb bundle still contains Hermes bridge naming/comments and minified Hermes send-path names.
- This stays open as a Prompt 2 blocker because the owner reports June still attempts prompt upgrade/Hermes on send.

Files changed in current dirty tree, grouped:

| Group | Paths / Areas |
|---|---|
| MAS-safe product lane | AppStore config/project/schemes, `Epistemos-AppStore-Info.plist`, AppStore entitlements, `Epistemos/App`, June bridge/gateway/web asset packaging, voice/read-aloud, settings, vault sync, note/editor/graph surfaces, AppStore KEELSTONE tests, release gates |
| Shared substrate | `agent_core`, `epistemos-core`, `js-editor`, KokoroPipeline, shared graph/editor/vault/engine code, shared build scripts |
| Parked-lane / legacy | `ExperimentalAgent`, `Goose`, `AgentSurface`, HTMLWorkspace parked runtimes, Work/OpenCode, VaultMCP, Harness/EvalSandbox, legacy docs/prompts. These changed for inventory, compile parking, MAS guards, and seams; they remain deletion/quarantine targets after ownership mapping |
| Generated / build artifact | `.june-web-stage`, `Epistemos/Resources/Editor/*.br`, Rust/Xcode build output, `syntax-core/target`, archives, xcresults, proof directories |

Verification debt after this checkpoint:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Prompt upgrade/Hermes runtime send path | Owner sees June trying prompt upgrade/Hermes on send; archive still has Hermes bridge names | Inspect June send path/native bridge, remove or inert prompt-upgrade/Hermes send behavior for MAS, rebuild/archive/scan, then send a prompt from exact archive while log-scanning | HIGH OPEN NEXT |
| Voice owner-visible product surfaces | Owner still reports voice does not work | Exact archive Settings preview and surface matrix with Kokoro queued/render/playback logs or visible reason toast | HIGH OPEN |
| Epdoc archive runtime fidelity/perf | Source guards can miss WKWebView latency/table degradation | Exact archive Epdoc load, Prose/Source/Document switching, table preservation, typing latency proof | HIGH OPEN |
| Editor typing and code editability | Owner reports all editors hang and code editor is view-only | Exact archive Prose, Source/Code, Epdoc typing/edit/save proof with no no-vault logs | HIGH OPEN |
| Graph-to-editor transitions | Owner reports graph/hologram graph opens editors slowly | Exact archive graph startup and graph-to-editor transition proof; patch if still slow | HIGH OPEN |
| Normal/base app ambiguity | Gate proves normal scheme maps to MAS target, but owner-visible base open must stay MAS/June | Keep validating normal/base launch path after changes; legacy direct lane remains explicit `Epistemos-LegacyDev` until deleted/quarantined | HIGH OPEN |

Next target:

- Start with the Prompt upgrade/Hermes runtime send path because the archive scan still exposes Hermes naming and the owner explicitly reported this behavior.
- Then continue the voice and editor/Epdoc runtime proofs/fixes against exact `Epistemos-AppStore` archive evidence.

## 2026-07-09 Update: Prompt Upgrade / Hermes Drift Gate

Owner context:

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpretation:

- Prompt rewriting/upgrading is not acceptable on send in the MAS product.
- A MAS archive must fail if the JuneWeb bundle reintroduces Prompt Forge commands, prompt-upgrade UI copy, or send-review hooks.
- Remaining Hermes names must be classified honestly: legacy in-process June gateway bridge names are not proof of an external Hermes runtime, but they remain MAS naming debt until renamed/quarantined.

Change:

- Strengthened `scripts/keelstone-release-gate.sh` so staged and archived `JuneWeb/dist` fail on `system_prompt_forge` in addition to the existing Prompt Forge / `prompt.forge_preview` / upgrade-copy markers.
- Added AppStore KEELSTONE witness test `appStoreLaneReleaseGateRejectsArchivedJuneWebPromptForgeCommandDrift()`.

Archive proof:

- Proof dir: `build/visible-mas-proof-2026-07-09-prompt-hermes-20260709-114541`
- Exact archive app: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Corrected scan file: `build/visible-mas-proof-2026-07-09-prompt-hermes-20260709-114541/archive-prompt-hermes-scan-v2.txt`
- Result: no hits for `system_prompt_forge`, `prompt.forge_preview`, `Sharpening prompt locally`, `agent-composer-forge`, `Prompt Forge`, `System Prompt Forge`, custom prompt, accepted prompt forge, or no-accepted prompt forge markers in archived `JuneWeb/dist`.
- Positive marker: archived bundle contains `Prompt rewriting disabled`.
- Corrected forbidden runtime path scan: no `ExperimentalWeb`, `OpenChamber`, `1Code`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, or `experimental-runtime` path hits.
- Remaining legacy bridge name counts in archived `JuneWeb`: `hermes_bridge=31`, `start_hermes_bridge=2`, `ensure_hermes_bridge_session=1`, `prompt.submit=6`, `session.create=4`, `session.resume=4`. Classification: MAS-safe in-process June gateway compatibility naming for this slice, not external runtime proof; still naming debt for Prompt 2 pruning.

Verification:

```bash
git diff --check -- \
  scripts/keelstone-release-gate.sh \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift
```

Result:

- Passed.

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate confirmed `Built App Store JuneWeb omits prompt-upgrade UI and send-review hooks`.
- Gate confirmed archived `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js` are present.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-prompt-gate-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesSystemPromptForgeRuntimeComposition()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReleaseGateRejectsArchivedJuneWebPromptForgeCommandDrift()'
```

Result:

- `** TEST SUCCEEDED **`
- `xcresult`: `build/xcode-results/2026-07-09-114549-21653.xcresult`
- `xcresulttool` summary: result `Passed`, total `3`, failed `0`.
- Compile invocation included `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Runtime send log proof | Source/archive gates prove prompt upgrade code is absent, but not a live send trace from the exact archive | Launch exact archive, send a known prompt, log-scan for Prompt Forge / `system_prompt_forge` / prompt rewrite / external runtime calls | OPEN |
| Hermes naming quarantine | Archive still contains `hermes_bridge` compatibility names for the in-process June gateway | Rename or compatibility-wrap web/native commands so MAS product copy and logs say June gateway, while old names remain only as non-user-visible compatibility shims | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive Settings preview and surface read-aloud matrix with logs/audible or visible failure reason | HIGH OPEN |
| Exact archive Epdoc/editor performance proof | Owner reports slow Epdoc/editor typing and formatting loss | Rebuild/archive after source changes; run manual graph-to-editor, Epdoc, Prose, Source/Code edit proof with logs | HIGH OPEN |

## 2026-07-09 Update: Owner Continuation Steer / Active Release Blockers

Owner excerpts:

> STOP normal feature work. Treat this as a MAS data-loss/release blocker.

> after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault.

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng ... if i cant get it to work then get rid of it

> epdoc takes a long tme to load ... transition from one surface to epdoc makes the epdoc lose uts rich tables and formattig ... all edititng surfaces hang

> continue the plan ... dont wait for me ... whe prompt 2 is done proeed indefinately beyind prompt 2

Interpreted intent:

- Continue autonomously under the MAS-only lock; the stale 1Code/Experimental objective is not active for this run.
- Treat vault restore as the highest release blocker because it can disconnect the selected vault and cause write failures such as `Cannot save page body: no vault URL`.
- Keep MAS/June as the only active product reality: the normal/base scheme must resolve to the AppStore MAS product, and legacy 1Code/OpenChamber/Experimental lanes remain quarantine/deletion targets after ownership inventory.
- Keep voice, Prompt Forge/Hermes prompt-upgrade behavior, Epdoc fidelity/load time, graph-to-editor transition latency, and editor typing hangs on the active Prompt 2 verification ledger.

Hard constraints:

- Current validation evidence must come from `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX` or the normal/base `Epistemos` scheme only when proven to archive the same `com.epistemos.appstore` MAS target.
- Do not count stale DerivedData/debug apps, cached installed apps, `goosed`, OpenChamber, ExperimentalWeb, node/local-server, or other parked/dev processes as MAS evidence.
- Do not stage or commit the broad dirty worktree.
- Before deletion/quarantine of legacy lanes, keep requiring reference scans, project target membership, build phases/scripts/resources, schemes/configs, tests/source guards, and stale generated/process mapping.

Acceptance checks currently required:

- Exact AppStore archive selects `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quits, reopens, restores the same vault without user reselect, shows no missing/unreadable bookmark toast, leaves `vaultSync.vaultURL` non-nil, and does not log `no vault URL`.
- MAS security-scoped bookmark validation checks readability while scope is active and does not destructively clear local state on a retryable restore preflight.
- Exact AppStore archive voice proof covers Settings preview, June latest reply, Prose, Epdoc, Quick Capture, HTML Workspace/current surface, and exposes visible failure reasons if Kokoro is unavailable.
- Prompt Forge/Hermes upgrade behavior is absent from normal June sends in the exact archive, not just source/unit guards.
- Epdoc and editor performance/fidelity are validated in exact archive flows, especially graph-to-editor transitions, table-rich Epdoc switches, Code/Source editability, and typing responsiveness.

Current source observation:

- `VaultSyncService.startupBookmarkValidation()` now checks `fileExists`/`isReadableFile` inside active security-scoped access for scoped bookmarks.
- The runtime acceptance proof is still open; source shape alone is not enough because the owner saw the exact archive surface disconnect from the vault.

Next action:

- Run the exact `Epistemos-AppStore` archive vault select/quit/reopen proof with logs and screenshots. Patch only if runtime or logs show restore drift; otherwise record the runtime proof and continue through voice, prompt-send, editor/Epdoc performance, and MAS pruning.

## 2026-07-09 Update: MAS Vault Restore Release Blocker Proof

Source/test change:

- Added `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift::appStoreLaneRetriesTransientMASBookmarkPreflightInsteadOfWarning`.
- The MAS-lane regression proves a transient `Saved vault bookmark points to a missing or unreadable directory.` preflight does not block automatic restore, does not produce a startup toast, and does not convert cached vault-backed notes into unrecoverable warnings.

Exact archive runtime proof:

- Scheme: `Epistemos-AppStore`
- Configuration: `Release`
- Archive app:
  - `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-landing-read-20260709-110112.xcarchive/Products/Applications/Epistemos.app`
- Relaunch proof:
  - `build/visible-mas-proof-2026-07-09-vault-restore-20260709-113115/exact-vault-relaunch-proof.txt`
- Summary proof:
  - `build/visible-mas-proof-2026-07-09-vault-restore-20260709-113115/exact-archive-vault-restore-proof.txt`
- Screenshots:
  - `build/visible-mas-proof-2026-07-09-vault-restore-20260709-113115/screenshots/exact-archive-vault-restored-before-relaunch.png`
  - `build/visible-mas-proof-2026-07-09-vault-restore-20260709-113115/screenshots/exact-archive-vault-restored-after-relaunch.png`
- Unified logs:
  - `build/visible-mas-proof-2026-07-09-vault-restore-20260709-113115/runtime-logs/unified-log-after-saveall-epistemos.txt`
  - `build/visible-mas-proof-2026-07-09-vault-restore-20260709-113115/runtime-logs/unified-log-after-saveall-scan-summary.txt`

Runtime result:

- Exact archive launched by path as bundle id `com.epistemos.appstore`.
- Selected/restored vault path:
  - `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`
- After quit and relaunch by exact archive path, Notes showed the restored root `KIMI_AGENT_DETERMINISTIC AI DEEP DIVE (2)` with folders/files and the vault connection button showed `externaldrive / Vault Connection`, not `externaldrive.badge.plus`.
- Container preferences after relaunch retained:
  - `epistemos.lastVaultPath=/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`
  - `epistemos.vaultBookmark` present, 812 bytes
  - `epistemos.disconnectInProgress` absent
- After pressing `Save All` in the restored Notes surface, unified-log scan showed:
  - `missing_unreadable_warning_count=0`
  - `automatic_restore_paused_count=0`
  - `no_vault_url_count=0`
- The `log stream` capture attempt failed because the first shell invoked zsh's `log` builtin; proof therefore uses `/usr/bin/log show` unified-log snapshots plus visible archive state and container preferences.

MAS test verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-vault-restore-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRetriesTransientMASBookmarkPreflightInsteadOfWarning()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneStartupRestoreFailurePreservesLocalVaultState()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLanePreservesBookmarkOnTransientRestoreFailures()'
```

Result:

- `** TEST SUCCEEDED **`
- 4 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-113845-18629.xcresult`
- `xcresulttool` summary: result `Passed`, total `4`, failed `0`.
- Build compile line included `-DEPISTEMOS_APP_STORE -DMAS_SANDBOX`.

Residual vault restore risk:

- The exact archive proof used an already-present valid security-scoped bookmark for the owner-requested vault rather than reselecting the folder through a fresh `NSOpenPanel` cycle during this slice. The relaunch failure mode was still exercised against the exact archive and persisted bookmark.
- The owner-visible Welcome Back overlay still showed stale `0 notes` counts before entering Notes. This is not a vault disconnect, but it can confuse launch trust and remains a Prompt 2 UX/state freshness issue.

## 2026-07-09 Update: MAS JuneWeb Archive Proof + JSON-RPC Numeric ID Fix

Owner context:

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpretation:

- The exact AppStore archive must load bundled MAS June, not the missing-bundle panel.
- Send must preserve the literal prompt and must not route through Prompt Forge / Hermes prompt-upgrade UI.
- The previous visible archive symptom `Hermes request timed out: session.create` is a Prompt 2 blocker even if the bundle scan passes.

Root cause found:

- `JuneGatewayReplyID.init(rawValue:)` rejected numeric WebKit JSON-RPC ids because `JSONSerialization` returns `__NSCFNumber` and Swift reports `NSNumber(value: 1) is Bool == true`.
- The validator now checks `NSNumber` first and rejects only exact CoreFoundation booleans with `CFGetTypeID(number) != CFBooleanGetTypeID()`.

Change:

- `Epistemos/JuneAgent/JuneGatewayTypes.swift`
  - accepts bounded numeric `NSNumber` JSON-RPC ids;
  - still rejects JSON boolean ids.
- `Epistemos/JuneAgent/JuneAgentGateway.swift`
  - added method/code-only gateway diagnostics; no prompt/body logging.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
  - added executable AppStore regression for numeric `id: 1` session creation and rejected `id: true`.
- `EpistemosTests/AppStoreJuneHardeningTests.swift`
  - updated the source guard to require CFBoolean rejection rather than `rawValue is Bool`.

Focused MAS verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-gateway-id-fix-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneAcceptsWebKitNumericJSONRPCIDsForJuneSessions()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed.
- The focused test log showed `gateway rpc received: session.create`, `gateway rpc reply sent`, then `gateway frame rejected invalid json-rpc id` for the boolean id case.
- xcresult: `build/xcode-results/2026-07-09-080850-68443.xcresult`

Fresh Release archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-gateway-id-fix-081245 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- App path: `build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Executable: `Contents/MacOS/Epistemos`
- Required bundled MAS June files present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`
- The live Release compiler invocation for `Epistemos-AppStore` included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.

Local signing / verification:

```bash
APP='build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive/Products/Applications/Epistemos.app'
for dylib in "$APP"/Contents/Frameworks/*.dylib; do
  if [ -e "$dylib" ]; then
    codesign --force --sign - --timestamp=none "$dylib"
  fi
done
codesign --force --sign - --timestamp=none --entitlements Epistemos/Epistemos-AppStore.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
```

Result:

- Codesign verification passed.
- Bundle id remained `com.epistemos.appstore`.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate confirmed:
  - normal `Epistemos` scheme launches/builds the MAS AppStore target;
  - `Epistemos-AppStore` target has `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`;
  - AppStore entitlements include sandbox/user-selected/bookmark access and omit JIT/library-validation/server/document-scope;
  - built artifact includes `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js`;
  - built JuneWeb omits prompt-upgrade UI and send-review hooks;
  - built AppStore artifact omits Goose ACP loopback, OAuth loopback, parked account/backend markers, and quarantine xattrs.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-gateway-id-fix-081245/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No prohibited runtime strings detected.
- No parked account/backend runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports: `build/visible-mas-proof-2026-07-09-gateway-id-fix-081245/appstore-bundle-scan`
- Executable files remained limited to:
  - `Contents/MacOS/Epistemos`
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`

Exact archive launch proof:

- No Epistemos process was running before launch.
- Launched exact path:
  - `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive/Products/Applications/Epistemos.app`
- Running process path:
  - `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-gateway-id-fix-081245.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Runtime bundle id:
  - `com.epistemos.appstore`
- Screenshots:
  - Launch loaded MAS June home, not the missing-bundle panel:
    `build/visible-mas-proof-2026-07-09-gateway-id-fix-081245/exact-archive-launch.png`
  - Workspace/Agent surface loaded:
    `build/visible-mas-proof-2026-07-09-gateway-id-fix-081245/exact-archive-agent-open.png`
  - Literal prompt was preserved and submitted:
    `build/visible-mas-proof-2026-07-09-gateway-id-fix-081245/exact-archive-agent-literal-prompt-send-proof.png`
- Runtime log:
  - `build/visible-mas-proof-2026-07-09-gateway-id-fix-081245/runtime-logs/exact-archive-agent-send-runtime.log`

Runtime result:

- The previous user-visible blocker `Hermes request timed out: session.create` did not recur.
- The literal prompt `Say exactly: MAS gateway fixed.` created a visible session and appeared unchanged in the conversation.
- Prompt Forge / Hermes prompt-upgrade markers were not present in the runtime log scan.
- New active blocker exposed in the same exact archive:
  - UI: `Error: agent_core MAS run failed (domain=Epistemos.AgentErrorFfi code=0)`
  - Log hit: `June turn failed: agent_core MAS run failed (domain=Epistemos.AgentErrorFfi code=0)`
- The exact archive app was quit after proof so it is not a stale evidence process.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| `agent_core MAS run failed` on archived Workspace send | Session/create timeout is fixed, but real MAS agent turns still fail after handoff to agent_core | Inspect `GooseMASAgentCoreRunner`, `agent_core` FFI error propagation, cloud credential path, and MAS env; patch and prove exact archive sends a successful short turn | HIGH OPEN NEXT |
| Voice/Kokoro | Owner says voice still does not work | Exact archive Kokoro gate readiness, preview audible/log proof, and surface matrix for June/Prose/Epdoc/Quick Capture | HIGH OPEN |
| Vault restore/save | Owner reports vault unselects after relaunch; this remains a data-loss/release blocker | Select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove no startup warning, `vaultSync.vaultURL != nil`, and no `no vault URL` save log | HIGH OPEN |
| Epdoc load/fidelity/edit latency | Owner reports slow load, table/formatting loss on surface switch, and hangs while editing | Manual exact archive Epdoc table switch/edit proof plus bridge profiling if still slow | HIGH OPEN |
| Code/source editor editability | Owner reports code editor view-only and editor typing hangs | Exact archive manual Code/Source edit test with vault write proof and typing responsiveness logs | HIGH OPEN |
| Graph startup/editor transition hangs | Owner reports graph startup and transitions to editors are slow/hanging | Exact archive graph open/transition timing and fixes if still blocking | HIGH OPEN |

## 2026-07-09 Update: Exact Archive Editor Bridge Runtime Proof

Owner context:

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpretation:

- Treat editor typing latency, source/code editability, Epdoc switching, and graph-to-editor transitions as active Prompt 2 MAS blockers.
- Current proof must come from `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`, not stale debug apps or old goosed/OpenChamber/ExperimentalWeb processes.
- Source guards are useful, but Release archive runtime proof is required before a fix is considered product-valid.

Change recorded for this slice:

- `MarkEditCoreEditorCoordinator` now throttles full-text bridge snapshots while typing and sends lightweight metadata snapshots for cursor/selection updates.
- Native apply-state no longer reloads the WKWebView over a pending editor text snapshot when the model text has not changed.
- The MAS lane has source guards for the bridge throttle and for avoiding the old 250 ms full-text poll.

Focused MAS test:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-bridge-throttle-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-072016-51013.xcresult`

Base scheme verification debt exposed:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-base-code-editor-polish-2026-07-09 \
  -only-testing:'EpistemosTests/CodeEditorPolishTests/codeEditorLargeFileAffordancesStayOnCoreEditor()'
```

Result:

- Failed before test execution with xcodebuild code 70.
- Reason: `Tests in the target EpistemosTests can't be run because EpistemosTests isn't a member of the specified test plan or scheme.`
- xcresult: `build/xcode-results/2026-07-09-072016-51014.xcresult`

Exact archive rebuild:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-editor-bridge-throttle-072502 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- App path: `build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Compile flags observed in the archive build included `-D EPISTEMOS_APP_STORE` and `-D MAS_SANDBOX`.

Local signing proof:

```bash
APP='build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive/Products/Applications/Epistemos.app'
for dylib in "$APP"/Contents/Frameworks/*.dylib; do
  if [ -e "$dylib" ]; then codesign --force --sign - --timestamp=none "$dylib"; fi
done
codesign --force --sign - --timestamp=none --entitlements Epistemos/Epistemos-AppStore.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
```

Result:

- Valid on disk.
- Satisfies designated requirement.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate proved normal `Epistemos` scheme launches the MAS App Store target.
- Gate proved `Epistemos-AppStore` uses MAS flags/sandbox.
- Gate proved built app includes `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- Gate proved built App Store JuneWeb omits prompt-upgrade UI and send-review hooks.
- Gate proved built App Store artifact omits Goose ACP loopback/OAuth loopback/parked runtime markers.
- Gate proved built App Store entitlements include sandbox and omit JIT/library-validation/server entitlements.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-editor-bridge-throttle-072502/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Scan completed.
- No quarantine xattrs.
- No prohibited runtime strings/symbols.
- No research/tool residue.
- Reports directory: `build/visible-mas-proof-2026-07-09-editor-bridge-throttle-072502/appstore-bundle-scan`

Exact archive launch/runtime proof:

```bash
open -n build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Running process PID: `58292`
- Process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-editor-bridge-throttle-072502.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Bundle id: `com.epistemos.appstore`
- Visible app: MAS/June Home, not missing-bundle, 1Code, OpenChamber, or ExperimentalWeb.
- Vault root visible in Notes: `KIMI_AGENT_DETERMINISTIC AI DEEP DIVE (2)`.
- Manual Epdoc typing proof succeeded in exact archive; text inserted into the editor and the word/character status updated without a short-proof hang.
- Screenshot: `build/visible-mas-proof-2026-07-09-editor-bridge-throttle-072502/exact-archive-epdoc-editor-typed-proof.png`

Runtime log proof:

- Log file: `build/visible-mas-proof-2026-07-09-editor-bridge-throttle-072502/runtime-logs/exact-archive-editor-bridge-runtime.log`
- Negative scan found no owner-blocker lines for `Cannot save page body`, `no vault URL`, saved vault bookmark missing/unreadable, `Workspace bundle is missing`, June web bundle missing, `Prompt Forge`, `prompt.forge_preview`, `Sharpening prompt`, `Hermes`, `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, `bun`, `codex`, or `experimental-runtime`.
- The broad `node` pattern only matched Apple/system log noise such as LaunchServices "cached node not found"; this is not counted as MAS runtime evidence.
- Save proof lines included scoped bookmark activity and file-coordination write claims during `Cmd+S`.
- Separate debt found: one `ShadowIndexingService shadow op failed (domain=Epistemos.ShadowFFIError code=3)` line. This is not a vault restore/no-vault-url failure but remains a hardening target.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Source/Code editor real editability | Owner saw code editor view-only; stale session lease or owner lock may still block editing after relaunch | Patch/retest MAS stale owner handling; exact archive manual Code/Source edit and save proof | HIGH OPEN NEXT |
| Exact archive prompt send proof | Source/gate says Prompt Forge omitted, but owner still saw prompt upgrade/Hermes behavior | Launch exact archive, send prompt on Agent surface, log-scan for `prompt.forge_preview`, Prompt Forge, Hermes/prompt-upgrade calls | HIGH OPEN |
| Voice owner-visible surfaces | Owner still reports voice does not work | Exact archive Kokoro surface matrix with audible/manual proof or visible failure reason | HIGH OPEN |
| Graph startup/editor transitions | Owner reports graph startup and graph-to-editor routes hang | Read graph commit/load paths; patch main-thread commit/route cost; exact archive graph startup/transition proof | HIGH OPEN |
| Shadow indexing failure | Runtime log has a shadow FFI failure during exact archive proof | Classify source/cause; add non-blocking/error throttling or storage fix if it affects launch/editing | OPEN |

## 2026-07-09 Update: MarkEdit Source/Code Editor Bridge Throttle

Owner context:

> all surfaces code edutor prose sruce epdoc ... all edititng surfaces hang when i start typign on them ... it also wont let me edit on code editor at all

Interpretation:

- Treat editor typing stalls and view-only editor behavior as Prompt 2 MAS release blockers.
- Preserve MAS-only proof: source guards are not enough; exact archive proof remains required after source changes.

Change:

- `MarkEditCoreEditorCoordinator` no longer posts a full editor text snapshot on every keyup, selection change, mouseup, and fixed 250 ms interval.
- The bridge now posts lightweight cursor/line metadata for selection-only events and debounces full text snapshots after real input.
- The Swift coordinator tracks a pending editor text snapshot and defers same-text config reloads that would otherwise replace unsynced user edits while the debounced snapshot is still in flight.
- This is intended to reduce WKWebView-to-Swift serialization pressure on large source/code buffers and avoid reload churn during typing.

MAS verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-bridge-throttle-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-072016-51013.xcresult`

Additional verification:

```bash
git diff --check
```

Result:

- Passed.

Verification debt:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; type in Prose, Source/Code, and Epdoc from the exact archive; capture logs/no hangs | OPEN NEXT |
| Code editor real edit proof | Owner saw the code editor as view-only | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| Base Epistemos test-plan coverage | The normal `Epistemos` scheme did not include `EpistemosTests` for the attempted source guard run | Either run the right base test plan or keep primary proof on `Epistemos-AppStore`; failed attempt xcresult `build/xcode-results/2026-07-09-072016-51014.xcresult` | OPEN |
| Exact archive Epdoc proof | The separate Epdoc fast path still needs runtime proof in Release/archive | Open Epdoc from exact MAS archive, switch surfaces, verify rich tables persist and typing remains responsive | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Repeat exact archive surface read-aloud matrix after archive rebuild | HIGH OPEN |

## 2026-07-09 Update: Exact MAS Archive, JuneWeb, Vault Restore, and Kokoro Playback Proof

Owner context:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work

> stop trying to us theapp please ... im done ur good contiue

Interpretation:

- Keep Prompt 2 MAS-only: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`.
- Use the exact App Store archive path for validation, not stale debug/DerivedData apps.
- Treat Kokoro first-render hang as a MAS release blocker until the exact archive logs prove render and playback complete.
- Continue after proof into editor/graph/storage hardening; do not stage or commit broad dirty state.

Source change in this slice:

- `Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift` now caps visible/read-aloud Kokoro vocabulary chunks at the responsive duration-model bucket (`responsiveDurationTokenCeiling = 32`) instead of using the largest installed duration bucket. The prior exact-archive sample showed a CoreML lazy-load hang inside large duration-model loading; this change keeps read-visible chunks on the responsive `t32` path.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` adds App Store source guards for the responsive duration-model cap and prevents regression to `resources.durationTokenSizes.max()`.
- `EpistemosTests/VoiceCodepackPlan3Tests.swift` mirrors the source guard for the broader voice codepack plan.

MAS source/test proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-kokoro-responsive-duration-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-065246-43030.xcresult`

Exact MAS archive proof:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-kokoro-responsive-duration-0730.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-kokoro-responsive-duration-0730 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Exact app path: `build/appstore-release-archive-2026-07-09-kokoro-responsive-duration-0730.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Local ad-hoc signing with `Epistemos/Epistemos-AppStore.entitlements` passed `codesign --verify --deep --strict --verbose=2`.
- Archive output is an archive/build result, not a test xcresult; current test xcresult evidence is listed above.

Build-settings and target reality proof:

- Saved build settings: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/build-settings/Epistemos-AppStore-Release-showBuildSettings.txt`
- `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
- `PRODUCT_NAME = Epistemos`
- `INFOPLIST_FILE = Epistemos-AppStore-Info.plist`
- `ENABLE_APP_SANDBOX = YES`
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- Forbidden flag proof: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/build-settings/forbidden-release-flags.txt`
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` are absent from the Release MAS build settings.

Release gates and bundle scans:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-kokoro-responsive-duration-0730.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate confirmed normal `Epistemos` scheme launches the MAS App Store target, `Epistemos-LegacyDev` is the legacy direct target, built MAS entitlements are sandboxed, `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js` are present, JuneWeb prompt-upgrade UI/send-review hooks are omitted, and parked runtime markers are absent.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-kokoro-responsive-duration-0730.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Scan completed successfully.
- Reports: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/appstore-bundle-scan/`
- Forbidden app-bundle path proof: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/app-bundle-forbidden-paths.txt`
- `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, and `experimental-runtime` are absent from the built MAS app bundle.

Exact archive runtime proof:

- Launched exact app path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-kokoro-responsive-duration-0730.xcarchive/Products/Applications/Epistemos.app`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-kokoro-responsive-duration-0730.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Launched bundle id: `com.epistemos.appstore`
- Runtime log: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/runtime-logs/exact-archive-runtime-kokoro-completed.log`
- Welcome Back screenshot: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/exact-archive-welcome-back-kokoro-responsive-duration.png`
- Restored note screenshot: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/exact-archive-restored-note-before-kokoro-responsive-duration.png`
- Visible UI was MAS/June Home/Notes, not missing `Workspace bundle`, 1Code, OpenChamber, or ExperimentalWeb.
- Restored vault shown: `KIMI_AGENT_DETERMINISTIC AI DEEP DIVE (2)`.
- Restored note body shown: `MAS vault repeat proof 2026-07-09 0559. This body was typed after relaunch from the App Store archive.`

Kokoro exact archive proof:

- `Read visible surface queued surface=proseNoteBody sourceChars=184 spokenChars=181 truncated=false`
- `Kokoro readiness context=proseNoteBody gateResolved=true`
- `modelRoot=/Users/jojo/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro`
- `manifestValid=true`
- `KokoroPipelineLinked=true`
- `isTextToSpeechAvailable=true`
- `Kokoro TTS render started chars=181`
- `Kokoro TTS render finished chars=181 samples=515040 sampleRate=24000 chunks=9 elapsedMs=13915`
- `Kokoro TTS playback started samples=515040 playerPlaying=true`
- `Kokoro TTS playback completed`
- Negative log scan found no `no vault URL`, no startup bookmark warning, no missing Workspace bundle warning, and no Kokoro failure line during this proof.

Stale process treatment:

- Before launch, no stale `Epistemos`, `goosed`, `OpenChamber`, or `ExperimentalWeb` process was active.
- Generic `node headless` helpers and other non-Epistemos desktop/browser processes are not MAS evidence.
- The exact proof PID was terminated after proof so future validation cannot accidentally rely on it as a stale running app.

Dirty-state grouping:

- Full current dirty status: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/git-status-short.txt`
- Grouped current dirty files: `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/dirty-files-grouped.txt`
- Groups recorded there:
  - MAS-safe/current Prompt 2 proof and product hardening: App Store plist/project/schemes, June, vault restore, voice, Epdoc/editor surfaces, MAS gate/tests.
  - Shared substrate: app engine, state/graph/vault substrate, Rust crates, editor JS, Kokoro package code.
  - Parked-lane/legacy/direct-lane quarantine candidates: ExperimentalAgent, Goose, VaultMCP, Work/OpenCode, Harness, direct-lane docs/plans.
  - Generated/build artifacts: editor brotli bundles, `syntax-core/target`, package-lock/build generated churn.
  - Docs/provenance: MAS pivot/plan ledgers and historical research docs.
- No broad dirty state was staged or committed.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Full voice surface matrix | Only prose/read-visible was runtime-proved in the exact archive after the Kokoro fix | Exact archive tests for Settings preview, June latest assistant reply, Epdoc selected/visible text, Quick Capture read-back, and other MAS-owned visible surfaces | OPEN |
| Epdoc load/fidelity | Owner reports slow load, table/format loss after surface transitions, and edit hangs | Exact archive manual Epdoc switch/edit proof plus profiler/log sampling if latency persists | HIGH OPEN |
| All editor typing hangs | Owner reports Prose/Source/Epdoc/code/editor surfaces hang when typing | Isolate main-thread/file-save/outline/graph work on typing; add guards and exact archive manual typing proof | HIGH OPEN |
| Code editor editability | Owner reports code editor is view-only | Exact archive code/source edit test with vault write proof; patch if the write lease or editor mode blocks input | HIGH OPEN |
| Graph startup/editor transitions | Owner reports graph startup and graph-to-editor transitions are slow/hanging | Profile graph load and transition path; move expensive work off startup/transition; exact archive proof | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof with log scan; further remove or neutralize prompt upgrade/Hermes calls if any remain | OPEN |
| Base app completion lock | Prompt 2 requires normal/base product reality to be MAS/June | Current gate proves normal `Epistemos` scheme maps to MAS target; continue deleting/quarantining direct-lane surface names until remaining legacy names are classified or removed | OPEN UNTIL CLEAN |

## 2026-07-09 Update: Active MAS Overnight Lock and Read-Visible Voice Blocker

Owner context:

> whenever u are good with all the steers and fixing all the outstanding issues u can cntiue the plan also ont wait for me jussst fontinue whe prompt 2 is done proeed indefinately beyind prompt 2. im going to sleep

Interpretation:

- Continue autonomously on Prompt 2 MAS release hardening.
- Do not treat Prompt 2 as complete while base-app ambiguity, vault restore/data loss, Kokoro voice/read-aloud, Prompt Forge/Hermes, Epdoc fidelity/latency, code/source editability, editor typing hangs, graph startup/editor transitions, or legacy-lane quarantine remain unproven.
- After Prompt 2 is genuinely proven or blocked with exact next actions, continue beyond Prompt 2 instead of waiting for routine confirmation.

Current exact MAS evidence before this slice:

- Archive: `build/appstore-release-archive-2026-07-09-voice-visible-live-body-0610.xcarchive`
- App: `build/appstore-release-archive-2026-07-09-voice-visible-live-body-0610.xcarchive/Products/Applications/Epistemos.app`
- Bundle ID: `com.epistemos.appstore`
- Release gate: passed for the exact archive app.
- Bundle scan: passed in `build/visible-mas-proof-2026-07-09-voice-visible-live-body-0610/appstore-bundle-scan`.
- Launch proof: exact archive launched, restored the vault, and showed MAS/June "Welcome Back" instead of the missing Workspace panel.
- Screenshot: `build/visible-mas-proof-2026-07-09-voice-visible-live-body-0610/exact-archive-welcome-back.png`
- Kokoro Settings proof: exact archive reported `gateResolved=true`, valid model root, valid manifest, linked `KokoroPipeline`, and `isTextToSpeechAvailable=true`.
- Kokoro preview proof: exact archive log showed queued, rendered, playback started, and playback completed for the Settings preview.
- Settings screenshots:
  - `build/visible-mas-proof-2026-07-09-voice-visible-live-body-0610/exact-archive-kokoro-ready.png`
  - `build/visible-mas-proof-2026-07-09-voice-visible-live-body-0610/exact-archive-kokoro-preview-active.png`

Failure found:

- Global `Shift+Cmd+R` on a visible restored note did not read the visible note body.
- Runtime log instead selected `surface=codeEditor` and queued a 560-character render from a stale/background code editor provider.
- That render did not reach playback proof within the wait window.

Change in progress:

- `EpistemosVisibleReadAloudRegistry.register` now has `activate: Bool = true`, so background providers can register without taking the active surface.
- `CodeEditorView` registers the code editor read-aloud provider with `activate: false`.
- Visible note/document branches explicitly mark the prose note body active on appear.
- `EpistemosAgentReadAloud.readVisibleSurface` now prepares a bounded responsive excerpt for long visible text, logs the surface/source/spoken lengths, and shows an excerpt toast when it truncates.
- Tests were updated to guard the app-owned read-visible command path, responsive excerpt cap, non-activating code editor provider registration, and diagnostics.

Dirty file grouping for this slice:

MAS-safe:

- `Epistemos/Engine/EpistemosVisibleReadAloud.swift`
- `Epistemos/Engine/EpistemosAgentReadAloud.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `EpistemosTests/VoiceCodepackPlan3Tests.swift`

Shared substrate:

- None newly introduced in this slice beyond the MAS in-process read-aloud substrate above.

Parked-lane/legacy:

- No new intentional legacy edits in this slice.

Generated/build artifacts:

- Prior exact archive and proof directories remain under `build/`.
- No broad dirty state has been staged or committed.

Verification debt opened by this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Focused MAS read-visible compile/tests | Recent source patch can fail Swift compile or source guards | Run focused `Epistemos-AppStore` tests for read-visible ownership and VoiceCodepack read-visible guard | OPEN NEXT |
| Exact archive read-visible runtime proof | Source guards can miss stale provider focus or Kokoro render stalls | Rebuild a new exact `Epistemos-AppStore` Release archive; launch exact path; prove `Read visible surface queued surface=proseNoteBody`, bounded spoken chars, render finished, playback started/completed | HIGH OPEN |
| Surface matrix | Owner asked for June, Prose, Epdoc, Quick Capture, and current MAS surfaces | Manual/log proof surface-by-surface in exact archive, or exact product-wiring blocker if a provider is missing | HIGH OPEN |
| Remaining Prompt 2 blockers | Owner reports vault, voice, prompt upgrade, Epdoc/editor hangs, graph startup, and base app ambiguity | Continue MAS archive proof and source/runtime hardening; do not advance past Prompt 2 until resolved or logged as HIGH blocker with exact next actions | HIGH OPEN |

## 2026-07-09 Update: Prompt-Upgrade UI Removed From Staged JuneWeb

Owner context:

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem

Interpretation:

- Normal June send must submit the literal typed prompt.
- MAS must not expose a confusing Prompt Forge / prompt-upgrade settings surface.
- A release/archive gate must fail if prompt-upgrade UI text or send-review hooks return to the staged or built JuneWeb bundle.

Change:

- In `/Users/jojo/dev/june-epistemos`, removed the visible `Prompt Forge` wording from the disabled Agent settings behavior panel.
- Kept the disabled prompt-rewriting panel as plain product copy: June sends the message as written.
- Updated focused June tests to assert no prompt-upgrade auto-review and no old prompt-forge controls.
- Tightened `scripts/keelstone-release-gate.sh` so staged and built JuneWeb fail on prompt-upgrade UI text as well as `prompt.forge_preview`/send-review hook markers.

Verification:

```bash
bun run test -- src/test/agent-workspace.test.tsx src/test/app-settings.test.tsx
```

Result:

- Passed in `/Users/jojo/dev/june-epistemos`.
- 2 test files passed.
- 185 tests passed, 2 skipped.

```bash
./build-june-web.sh
```

Result:

- Rebuilt `/Users/jojo/Downloads/Epistemos/.june-web-stage` from `/Users/jojo/dev/june-epistemos`.
- Staged `27` files.
- Main chunk: `523 KB` gzip.
- Required stage files present: `.june-web-stage/dist/index.html` and `.june-web-stage/tauri-internals-shim.js`.

```bash
rg -n "prompt\\.forge_preview|Sharpening prompt locally|agent-composer-forge|Prompt Forge|System Prompt Forge|Custom system prompt|Accepted System Prompt Forge|No accepted System Prompt Forge" .june-web-stage/dist
```

Result:

- No matches.

```bash
./scripts/keelstone-release-gate.sh
```

Result:

- Passed source/staged-tree gate.
- New gate witness: `PASS: Staged JuneWeb omits prompt-upgrade UI and send-review hooks`.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact Release archive prompt proof | Staged JuneWeb proof can miss archive copy or runtime send behavior | Rebuild/archive exact MAS app; run tightened release gate against built app; scan archive JuneWeb; launch exact archive and send a prompt while log-scanning for prompt-upgrade calls | OPEN NEXT |
| Exact archive Epdoc proof | Debug/source guards can miss Release/archive WKWebView latency and formatting regressions | Open Epdoc in exact archive, switch Prose/Source/Document, verify tables stay rich and editing is responsive | HIGH OPEN |
| Exact archive editor typing proof | Source guards can miss Release/archive runtime hitches | Type in Prose, Source/Code, and Epdoc in exact archive; capture logs/no hangs | HIGH OPEN |
| Code editor real edit proof | Owner saw Code editor view-only behavior | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix for surface read-aloud matrix | HIGH OPEN |

## 2026-07-09 Update: Kokoro Preview and App-Owned Read Visible Surface

Owner context:

> voice still doesnt work so add that to known issues but i do want you to coitneu ith work

Interpretation:

- Keep Kokoro-only voice as a Prompt 2 MAS release blocker until the exact archive proves model readiness, queued playback, and surface wiring.
- Do not treat a visible button as voice proof.
- Add MAS-owned visible-surface read aloud instead of system-wide OCR, screen capture, Apple AVSpeech fallback, or local-server/subprocess behavior.

Exact archive Kokoro readiness and preview proof:

- App path: `build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive/Products/Applications/Epistemos.app`
- Bundle id: `com.epistemos.appstore`
- Launched process during proof: `PID 94020`
- Screenshot: `/tmp/epistemos-proof/mas-kokoro-settings-preview-2026-07-09.png`
- Log: `build/visible-mas-proof-2026-07-09-vault-source-retry-0422/kokoro-settings-preview.log`

Required readiness lines observed in the exact archive log:

- `Kokoro readiness context=voice-settings-detail gateResolved=true modelRoot=/Users/jojo/Library/Containers/com.epistemos.appstore/Data/Library/Application Support/Epistemos/VoicePro manifestValid=true KokoroPipelineLinked=true isTextToSpeechAvailable=true`
- `Kokoro readiness context=settings-voice-model-preview gateResolved=true ... KokoroPipelineLinked=true isTextToSpeechAvailable=true`
- `Kokoro TTS render started chars=16 voice=default speed=1.000000`
- `Kokoro TTS queued chars=16 effect=pixelArt`
- `Kokoro TTS render finished chars=16 samples=45600 sampleRate=24000 chunks=1 elapsedMs=12149`
- `Kokoro TTS audio engine started`
- `Kokoro TTS playback started samples=45600 playerPlaying=true`
- `Kokoro TTS playback completed`

No Kokoro failure log was present in the captured preview proof.

Source hardening added after the preview proof:

- `Epistemos/App/EpistemosApp.swift`: app command `Read Visible Surface` calls `EpistemosAgentReadAloud.readVisibleSurface()`.
- `Epistemos/Engine/EpistemosVisibleReadAloud.swift`: visible surface registry now includes `.codeEditor`.
- `Epistemos/Views/Notes/CodeEditorView.swift`: code editor registers/unregisters a read-aloud provider, marks itself active on text changes, and carries the existing `isEditable` policy through editor internals.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: source guard now requires the app command, code-editor provider, Kokoro readiness diagnostics, and absence of OCR/screen-capture voice paths.

Focused MAS verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-voice-visible-surface-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneOwnsVisibleReadAloudSurfacePath()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-043755-94880.xcresult`
- `xcresulttool` summary: title `Test - Epistemos-AppStore`, result `Passed`, total `1`, failed `0`.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact Release archive after voice source changes | Preview proof predates the app command/code-editor provider source edits | Rebuild/archive `Epistemos-AppStore`, sign, run release gate and bundle scan, relaunch exact archive | OPEN NEXT |
| Manual voice surface matrix | Settings preview proves Kokoro can speak, not every MAS surface can provide visible text | Exact archive read-aloud proof for June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, Code editor, Meeting/current MAS text surface | HIGH OPEN |
| Owner audible confirmation | Logs prove playback lifecycle; owner reports voice still does not work | Capture manual audible proof or visible playback state from exact archive after rebuilt source | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still calls Hermes/upgrades prompts | Exact archive send proof with log scan; remove or further gate any remaining prompt-upgrade path | OPEN |
| Epdoc/editor/graph performance | Owner reports slow Epdoc load, formatting loss, typing hangs, graph-to-editor hangs | Runtime profiling and focused source fixes/tests for heavy outline/snapshot/writeback paths | HIGH OPEN |

## 2026-07-09 Update: Voice Visible-Surface Archive Proof

Meaningful source changes since the prior archive:

- Added app command `Read Visible Surface`.
- Added code-editor visible read-aloud registration.
- Carried code-editor `isEditable` through the MarkEdit/CoreEditor paths.
- Strengthened the AppStore KEELSTONE voice/read-aloud source guard.

Archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-voice-visible-surface-044357 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Archive app: `build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive/Products/Applications/Epistemos.app`
- Build output showed Release compile flags `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

Post-archive signing and identity proof:

```bash
APP="build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive/Products/Applications/Epistemos.app"
find "$APP/Contents/Frameworks" -maxdepth 2 \( -name '*.dylib' -o -name '*.framework' -o -name '*.bundle' \) -print0 | xargs -0 -I{} codesign --force --sign - {}
codesign --force --sign - --entitlements Epistemos/Epistemos-AppStore.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
```

Result:

- `codesign --verify --deep --strict --verbose=2` passed.
- Bundle id: `com.epistemos.appstore`.

Release gate and bundle scan:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Includes built-app passes for JuneWeb completeness, MAS entitlements, no parked runtime strings, no quarantine xattrs, no auto Prompt Forge send-review UI, and no parked-lane visible CLI copy.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-voice-visible-surface-044357/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes.
- No prohibited runtime strings.
- No prohibited runtime symbols.
- No prohibited research/tool resource residue.
- Reports written to `build/visible-mas-proof-2026-07-09-voice-visible-surface-044357/appstore-bundle-scan`.

JuneWeb prompt-upgrade marker check:

- Required files present: `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- Built JuneWeb contains `Prompt rewriting disabled`, `No Prompt Forge preview`, and `prompt.submit`.
- Built JuneWeb does not contain `prompt.forge_preview`, `Sharpening prompt locally`, `agent-composer-forge`, `Custom system prompt`, `Accepted System Prompt Forge layer`, or `No accepted System Prompt Forge layer`.
- Native binary still contains `prompt.forge_preview` only as the MAS rejection branch marker: `prompt.forge_preview rejected; per-message Prompt Forge disabled in MAS`.

Exact archive launch proof:

- Terminated stale older archive app `PID 94020` from `build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive`.
- Launch command:

```bash
/usr/bin/open -n /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Launched process: `PID 2176`.
- Process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Computer-use app state resolved bundle id `com.epistemos.appstore`.
- Visible UI loaded the MAS/June resume checkpoint; it did not show the missing Workspace bundle panel.
- Screenshot: `/tmp/epistemos-proof/mas-voice-visible-archive-launch-2026-07-09.png`.
- Launch log: `build/visible-mas-proof-2026-07-09-voice-visible-surface-044357/epistemos-launch-last5m.log` (1,529 lines).
- Launch log scan had no matches for:
  - `Saved vault bookmark points to a missing or unreadable directory`
  - `Automatic vault restore was paused`
  - `Cannot save page body: no vault URL`
  - `Workspace bundle is missing`
  - `refusing async code file read with no active vault`
  - `Kokoro TTS`
  - `prompt.forge_preview`
  - `Sharpening prompt locally`
  - `Hermes`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Manual voice surface matrix | New archive proves the app launches and contains the command, but not every surface spoke text | Exact archive read-aloud proof for June latest assistant reply, Prose note body, Epdoc selected/visible text, Quick Capture, Code editor, Meeting/current MAS text surface | HIGH OPEN |
| Owner audible confirmation | Settings preview spoke in the prior archive; this archive needs a fresh manual audible surface proof after source changes | Trigger preview/read-visible in exact `voice-visible-surface-044357` archive and capture Kokoro queued/playback logs | HIGH OPEN |
| Runtime prompt send proof | Bundle/source proof shows no auto Prompt Forge call, but owner saw aggressive runtime behavior | Send a known prompt in exact archive and log-scan for `prompt.forge_preview`, `Sharpening prompt locally`, and Hermes/admin prompt-upgrade calls | OPEN |
| Epdoc/editor/graph performance | Owner reports slow Epdoc load, formatting loss, typing hangs, graph-to-editor hangs | Patch clean snapshot invalidation and run focused MAS source guard/tests, then rebuild/rescan archive after meaningful changes | HIGH OPEN NEXT |

## 2026-07-09 Update: MAS Vault Retry Archive, JuneWeb Scrub, and Release Gate Tightening

Owner context:

> The running MAS archive shows "The Workspace bundle is missing from this build."

> The app being launched is com.epistemos.appstore, so this is not acceptable as evidence of MAS working.

> User-visible bug: after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault.

> Do not use stale cached goosed/OpenChamber/ExperimentalWeb apps as evidence. Current validation must be Epistemos-AppStore / MAS_SANDBOX only.

Interpretation:

- Prompt 1 reality mapping remains complete and durable here: the normal `Epistemos` scheme now points at the MAS AppStore target, and the legacy direct target is explicit as `Epistemos-LegacyDev`.
- Prompt 2 / KEELSTONE is still active; do not advance until MAS/June is the normal product reality and the owner-visible blockers are either fixed or logged as HIGH blockers with next actions.
- Stale `goosed`, `OpenChamber`, `ExperimentalWeb`, debug, or DerivedData apps are not MAS evidence.
- Exact proof must come from `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, and `MAS_SANDBOX`.

MAS source change:

- `VaultSyncService.startupBookmarkValidation()` now treats transient MAS readability/security-scope preflight failures as retryable instead of a hard automatic-restore blocker.
- `restoreVaultFromBookmark()` no longer clears local vault state or removes the saved bookmark for transient restore failures.
- `AppBootstrap` only pauses automatic vault restore for non-retryable bookmark validation failures; retryable failures defer vault-source warnings while restore is still possible.
- AppStore KEELSTONE tests now guard:
  - readability checks while the security scope is active;
  - deferring vault-source warnings before a ready bookmark restore;
  - preserving bookmarks/local state on transient restore failures.

JuneWeb packaging and visible-copy change:

- The MAS archive packages JuneWeb at `Contents/Resources/JuneWeb`.
- Required files are present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`
- The external June fork was scrubbed of AppStore-visible parked CLI copy in:
  - `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`
  - `/Users/jojo/dev/june-epistemos/src/components/settings/AgentSettingsSection.tsx`
  - `/Users/jojo/dev/june-epistemos/src/lib/tauri.ts`
  - `/Users/jojo/dev/june-epistemos/src/test/agent-workspace.test.tsx`
- `scripts/keelstone-release-gate.sh` now fails an AppStore archive if bundled JuneWeb contains parked-lane visible CLI copy matching:
  - `experimentalweb`
  - `openchamber`
  - `1code`
  - `goosed`
  - `opencode`
  - `codex`
  - `claude code`
  - `experimental-runtime`

Exact AppStore KEELSTONE test proof:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-vault-retry-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersVaultSourceWarningsBeforeReadyBookmarkRestore()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLanePreservesBookmarkOnTransientRestoreFailures()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneStartupRestoreFailurePreservesLocalVaultState()'
```

Result:

- `** TEST SUCCEEDED **`
- 4 tests passed.
- Compile flags include `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-034234-73708.xcresult`

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-vault-retry-2026-07-09 \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result:

- `** TEST SUCCEEDED **`
- 26 tests passed.
- Compile flags include `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-034450-74510.xcresult`

Invalid or intermediate evidence not used as final proof:

- `build/xcode-results/2026-07-09-033914-72054.xcresult`: invalid mixed test invocation; `EpistemosTests` are not in the AppStore scheme.
- `build/xcode-results/2026-07-09-033953-72501.xcresult`: first focused AppStore attempt failed before the `nonisolated` fix.
- `build/appstore-release-archive-2026-07-09-vault-retry-0350.xcarchive`: archive succeeded, but stricter scan found bundled JuneWeb visible `opencode`/`Codex` copy, so it is not final proof.

Exact MAS archive proof:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-vault-retry-cli-scrub-0405 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Exact app path: `build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive/Products/Applications/Epistemos.app`
- Scheme: `Epistemos-AppStore`
- Target: `Epistemos-AppStore`
- Configuration: `Release`
- Bundle identifier from built app Info.plist: `com.epistemos.appstore`
- Required JuneWeb files present in built app.
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` are absent from the AppStore target compile settings; `EPISTEMOS_APP_STORE` and `MAS_SANDBOX` are active by project/gate and xcodebuild invocation evidence.

Ad-hoc archive signing proof:

```bash
APP='build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive/Products/Applications/Epistemos.app'
if [ -d "$APP/Contents/Frameworks" ]; then
  find "$APP/Contents/Frameworks" -maxdepth 2 \( -name '*.dylib' -o -name '*.framework' -o -name '*.bundle' \) -print0 | xargs -0 -I{} codesign --force --sign - {}
fi
codesign --force --sign - --entitlements Epistemos/Epistemos-AppStore.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP"
```

Result:

- App valid on disk.
- Effective entitlements include App Sandbox, app-scoped bookmarks, user-selected read-write, app group, audio input, and network client.
- Effective entitlements omit JIT, disabled library validation, and network server.

Archive gates and scans:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Normal `Epistemos` scheme launches/builds/tests the MAS AppStore target.
- Built AppStore artifact includes `JuneWeb/dist/index.html`.
- Built AppStore artifact includes `JuneWeb/tauri-internals-shim.js`.
- Built AppStore JuneWeb omits auto Prompt Forge send-review UI.
- Built AppStore JuneWeb omits parked-lane visible CLI copy.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-vault-retry-cli-scrub-0405/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Passed.
- Scan report directory: `build/visible-mas-proof-2026-07-09-vault-retry-cli-scrub-0405/appstore-bundle-scan`
- No quarantine xattrs.
- No prohibited runtime strings/symbols or prohibited research/tool resource residue.
- Executables in the bundle remained limited to:
  - `Contents/MacOS/Epistemos`
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`
- Exact forbidden path components absent from the built bundle:
  - `ExperimentalWeb`
  - `1Code`
  - `OpenChamber`
  - `goosed`
  - `opencode`
  - `codex`
  - `node`
  - `bun`
  - `rg`
  - `experimental-runtime`
- Case-insensitive visible legacy copy absent from bundled JuneWeb for:
  - `opencode`
  - `codex`
  - `Claude Code`
  - `ExperimentalWeb`
  - `OpenChamber`
  - `goosed`
  - `1Code`

Exact archive launch proof:

```bash
APP_ABS='/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive/Products/Applications/Epistemos.app'
/usr/bin/open -n "$APP_ABS"
```

Result:

- Stale previous archive PID `71212` was identified and quit before launch; it was not counted as evidence.
- Launched PID: `84799`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Built Info.plist bundle id: `com.epistemos.appstore`
- Screenshot proof:
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_04-07-12-w50516.png`
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_04-07-12-w50519.png`
- Visible result: MAS/June loaded from the archive; the missing `Workspace bundle is missing from this build` panel did not appear.
- `log show --last 5m --predicate 'process == "Epistemos"'` found no matching startup warning/no-vault logs in the sampled window.

Current dirty files grouped, do not stage broadly:

- MAS-safe active product edits:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/Sync/VaultSyncService.swift`
  - `Epistemos/JuneAgent/*`
  - `Epistemos/Views/Notes/*`
  - `Epistemos/Views/Graph/*`
  - `Epistemos/Views/Settings/*`
  - `Epistemos/VoicePro/*`
  - `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
  - focused `EpistemosTests/*` source guards and regression tests
  - `project.yml`
  - `Epistemos.xcodeproj/project.pbxproj`
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme`
  - `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-LegacyDev.xcscheme`
  - `Epistemos/Epistemos-AppStore.entitlements`
  - `Epistemos-AppStore-Info.plist`
  - `scripts/keelstone-release-gate.sh`
  - `scripts/scan_appstore_bundle.sh`
  - `bundle-app-runtime-assets.sh`
  - `build-agent-core.sh`
  - `build-epistemos-core.sh`
  - `build-rust.sh`
- Shared substrate edits:
  - `agent_core/src/*`
  - `epistemos-core/*`
  - `LocalPackages/KokoroPipeline/*`
  - `js-editor/*`
  - shared note/editor/provenance support under `Epistemos/Models`, `Epistemos/Vault`, and `Epistemos/Engine`
- Parked-lane or legacy quarantine edits:
  - `Epistemos/ExperimentalAgent/*`
  - `Epistemos/Goose/*`
  - `Epistemos/Work/*`
  - `Epistemos/VaultMCP/*`
  - `Epistemos/Harness/*`
  - `Epistemos/AgentSurface/*`
  - `Epistemos/Views/HTMLWorkspace/*`
  - `Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift`
  - docs and handoffs mentioning retired lanes
- Generated/build artifacts:
  - `.june-web-stage`
  - `build/**`
  - `.spm-cache`
  - `syntax-core/target/**`
  - compressed editor bundles `Epistemos/Resources/Editor/editor.css.br` and `Epistemos/Resources/Editor/editor.js.br`
- External June fork dirty files:
  - `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`
  - `/Users/jojo/dev/june-epistemos/src/components/settings/AgentSettingsSection.tsx`
  - `/Users/jojo/dev/june-epistemos/src/lib/agent-chat-runtime.ts`
  - `/Users/jojo/dev/june-epistemos/src/lib/model-privacy.ts`
  - `/Users/jojo/dev/june-epistemos/src/lib/tauri.ts`
  - `/Users/jojo/dev/june-epistemos/src/styles/app.css`
  - `/Users/jojo/dev/june-epistemos/src/test/*.test.*`

Why ExperimentalAgent and Goose files changed:

- `ExperimentalAgent` changes are quarantine/guard changes so direct-lane Experimental code is inventory-mapped, macro-isolated, and excluded from MAS target membership.
- `Goose` changes split MAS-safe in-process provider/agent-core support from parked ACP/local server/subprocess code.
- These files are not product evidence for MAS; they are pruning and ownership-map work so the MAS target cannot accidentally depend on legacy local-server/runtime lanes.

Process classification:

- Any `goosed`, `OpenChamber`, `ExperimentalWeb`, debug, DerivedData, or previous-archive `Epistemos` process is stale unless launched from the exact archive path above.
- Such processes are not active MAS dependencies and must not be used as evidence.
- Final proof for this slice is only the exact `Epistemos-AppStore` archive and launched `com.epistemos.appstore` process path above.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Manual vault restore sequence | Source and AppStore tests prove retry safety, but owner required real archive relaunch proof with the target vault | Select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove no unreadable-bookmark toast, `vaultSync.vaultURL` non-nil, and no `Cannot save page body: no vault URL` during a real save | HIGH OPEN NEXT |
| Kokoro voice/read-aloud | Owner still reports voice does not work | Exact archive `KokoroVoiceGateStatus` ready proof, preview queued/no failure log, audible/manual proof, and surface-by-surface read-aloud matrix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Prompt Forge is disabled by source/bundle tests, but owner reports June still calls Hermes on send | Exact archive prompt-send log proof and further removal if any prompt-upgrade request still fires | HIGH OPEN |
| Epdoc load/fidelity/edit hangs | Source fast-path guards exist, but owner reports slow load, formatting loss, and edit stalls | Exact archive Epdoc table switch/edit proof and profiling/logs if still slow | HIGH OPEN |
| Code editor editability | Owner reports code editor opens view-only | Exact archive Code/Source edit proof with vault write proof | HIGH OPEN |
| Graph startup/editor transition hangs | Source graph sidebar/commit hot paths were reduced, but owner reports graph startup and editor transitions still hang | Exact archive startup/graph/open-editor timing proof and further off-main pruning | HIGH OPEN |
| Full post-vault archive rebuild | Current archive proves vault retry source and JuneWeb scrub, but more source changes will require a new archive | Rebuild/rescan/relaunch AppStore archive after next meaningful source patch | OPEN |

## 2026-07-09 Update: Shared Edit Save Hot Path and Archive Proof

Owner context:

> it still hangs alot when editting on all surfaces

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpretation:

- Treat all-surface edit latency and graph startup stalls as Prompt 2 MAS release blockers.
- Continue MAS-only proof through `Epistemos-AppStore` / `EPISTEMOS_APP_STORE` / `MAS_SANDBOX`.
- Do not use stale DerivedData apps, stale debug apps, or stale goosed/OpenChamber/ExperimentalWeb processes as evidence.

Change:

- Moved duplicate caller-owned editor metadata work out of the common file-first save path.
- `VaultSyncService.savePageBodyFileFirst(pageId:body:)` now remains the owner of staged body state, derived interactive state, `updatedAt`, title sync, model save, block mirror scheduling, export, and graph invalidation.
- `ProseEditorView.debouncedSave(_:)` no longer pre-applies derived state or independently schedules block mirror sync before calling the service.
- `NoteDetailWorkspaceView.flushCurrentEditor(...)` and `saveMarkdownDocumentSurfaceContent(page:markdown:)` now await the service write result first and then update view-local snapshots only.
- This reduces per-keystroke/editor-flush duplicate work across Prose, Source/Code, and Epdoc/Document paths while preserving vault-md-first semantics.

Focused MAS source checks:

```bash
git diff --check -- \
  Epistemos/Sync/VaultSyncService.swift \
  Epistemos/Views/Notes/ProseEditorView.swift \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  EpistemosTests/NoteEditorLayoutTests.swift
```

Result:

- Passed with no output.

```bash
rg -n "Self\.syncNoteTitleIfNeeded\(|page\.applyInteractiveDerivedState\(from: newValue\)|scheduleBlockMirrorSync\(pageId: pageId, body: newValue\)|saveModelContext\(reason: \"debounced save|stageBodyWrite\(pageId: pageId, fullText: fullText\)|stageBodyWrite\(pageId: pageId, fullText: markdown\)|page\.applyInteractiveDerivedState\(from: fullText\)|page\.applyInteractiveDerivedState\(from: markdown\)|Document surface: failed to save markdown note state|failed to persist flushed editor body" \
  Epistemos/Views/Notes/ProseEditorView.swift \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift
```

Result:

- No removed duplicate hot-path markers remain in the edited service-backed save sections.
- Remaining `Self.syncNoteTitleIfNeeded` matches are in non-service flush paths.

MAS test command:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-edit-hotpath-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed:
  - `App Store lane does not double-schedule block mirrors before file-first saves`
  - `App Store lane keeps dirty graph rebuilds out of graph startup`
- xcresult: `build/xcode-results/2026-07-09-023519-17077.xcresult`

Non-evidence / verification debt:

- Attempting to run `EpistemosTests` through `Epistemos-AppStore` failed before build because `EpistemosTests` is not a member of the MAS scheme/test plan.
- Attempting to run `EpistemosTests` through the normal `Epistemos` scheme failed for the same reason; the normal scheme now maps to the MAS App Store target and KEELSTONE tests, not the broad legacy shared test bundle.
- `Epistemos-LegacyDev` includes `EpistemosTests`, but that scheme builds the legacy direct target and is not MAS proof.
- Debt: either migrate selected shared source guards into `EpistemosAppStoreKeelstoneTests` or create a MAS-compatible shared test scheme.

Archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-edit-hotpath.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-edit-hotpath \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Scheme: `Epistemos-AppStore`
- Target: `Epistemos-AppStore`
- Configuration: `Release`
- Archive app path: `build/appstore-release-archive-2026-07-09-edit-hotpath.xcarchive/Products/Applications/Epistemos.app`

Post-archive signing and bundle identity:

```bash
APP='build/appstore-release-archive-2026-07-09-edit-hotpath.xcarchive/Products/Applications/Epistemos.app'
codesign --force --deep --sign - --entitlements Epistemos/Epistemos-AppStore.entitlements "$APP"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist"
test -f "$APP/Contents/Resources/JuneWeb/dist/index.html"
test -f "$APP/Contents/Resources/JuneWeb/tauri-internals-shim.js"
```

Result:

- Signature replaced successfully.
- Bundle identifier: `com.epistemos.appstore`
- Executable: `Epistemos`
- `Contents/Resources/JuneWeb/dist/index.html` exists.
- `Contents/Resources/JuneWeb/tauri-internals-shim.js` exists.

Release gate:

```bash
./scripts/keelstone-release-gate.sh --appstore-app \
  build/appstore-release-archive-2026-07-09-edit-hotpath.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate includes:
  - Normal `Epistemos` scheme launches/builds the MAS App Store target.
  - MAS effective build settings include sandbox posture.
  - MAS target uses `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.
  - `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` are direct/legacy lane only.
  - `JuneWeb/dist/index.html` and `JuneWeb/tauri-internals-shim.js` are present in the built App Store artifact.
  - Staged/built JuneWeb omits auto Prompt Forge send-review UI.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-edit-hotpath/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-edit-hotpath.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- No parked account/backend runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports: `build/visible-mas-proof-2026-07-09-edit-hotpath/appstore-bundle-scan`

Targeted residue proof:

```bash
APP='build/appstore-release-archive-2026-07-09-edit-hotpath.xcarchive/Products/Applications/Epistemos.app'
find "$APP" -print | rg '/(ExperimentalWeb|1Code|OpenChamber|goosed|opencode|codex|node|bun|rg|experimental-runtime)(/|$)' || true
strings "$APP/Contents/MacOS/Epistemos" | rg 'EPISTEMOS_APP_STORE|MAS_SANDBOX|EPISTEMOS_EXPERIMENTAL|KINDRED_ENABLED' || true
strings "$APP/Contents/MacOS/Epistemos" | rg -i 'ExperimentalWeb|OpenChamber|goosed|opencode|experimental-runtime' || true
```

Result:

- No file residue matches.
- No flag-string matches in stripped binary output.
- No forbidden runtime string sample matches.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive editor typing proof | Owner still sees all-surface hangs; source guards do not measure runtime latency | Launch exact archive, type in Prose, Source/Code, Epdoc, Quick Capture, and current text surfaces with logs/profiling | HIGH OPEN |
| Exact archive graph startup proof | Owner reports graph startup specifically slow | Launch exact archive to graph route; capture startup timings/logs and verify dirty graph rebuild work is not on first paint path | HIGH OPEN |
| Vault restore/save proof | Owner reports vault disconnects and `no vault URL`; source guards cannot prove real bookmark behavior | Select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove `vaultSync.vaultURL != nil`, no warning toast, no `no vault URL` | HIGH OPEN |
| Voice/Kokoro proof | Owner reports voice still does not work | Exact archive Kokoro gate/status plus audible/manual preview and surface read-aloud matrix | HIGH OPEN |
| Epdoc rich-table fidelity proof | Source fast path needs runtime validation | Exact archive lens switch Prose/Source/Epdoc with rich table formatting preserved and no long hang | HIGH OPEN |
| Prompt upgrade/Hermes send proof | Owner reports prompt upgrade still calls Hermes | Exact archive send prompt with log scan showing no Prompt Forge/Hermes prompt-upgrade path | OPEN |
| MAS shared-test coverage | `EpistemosTests` source guards are not in the MAS/base scheme | Port critical source guards into `EpistemosAppStoreKeelstoneTests` or add MAS-compatible shared test scheme | OPEN |

Next target:

- Investigate the graph startup route and remaining editor-latency hot paths in source before any more UI/June/voice feature work.
- Keep vault restore/save and Kokoro voice as HIGH Prompt 2 release blockers, but do not launch the app until the next exact-archive manual proof pass is intentionally started.

## 2026-07-09 Update: Visible MAS Proof, Code Editability, and Global Edit Hangs

Owner context:

> it also wont let me edit on code editor at all for some reason it just has me view it

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpretation:

- Treat code/source view-only behavior as a Prompt 2 MAS release blocker because MAS/June must be usable as the normal product app.
- Treat cross-surface edit hangs as a shared substrate blocker, not a per-surface polish issue. Prose, Source/Code, Epdoc, and graph-opened editors share note update, save, outline/graph projection, lease, and vault reconciliation paths.
- Treat graph startup latency as HIGH MAS drift because graph is now a normal product surface and cannot block opening editors.

Current exact archive proof:

- Command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/base-scheme-release-archive-2026-07-09-code-editor-lease.xcarchive \
  -derivedDataPath build/base-scheme-release-archive-derived-2026-07-09-code-editor-lease \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

- Result: `** ARCHIVE SUCCEEDED **`.
- Exact app path: `build/base-scheme-release-archive-2026-07-09-code-editor-lease.xcarchive/Products/Applications/Epistemos.app`.
- Bundle id: `com.epistemos.appstore`.
- Base scheme `Epistemos` Release build settings resolve to target `Epistemos-AppStore`, product `Epistemos.app`, and compile flags `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`.
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` were absent from the base scheme Release active compilation conditions.
- Required archive assets present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`
- The unsigned archive initially failed the built-entitlements gate because `CODE_SIGNING_ALLOWED=NO` produced no embedded entitlements. The archived app was then ad-hoc signed in place with `Epistemos/Epistemos-AppStore.entitlements` for local MAS evidence.
- `./scripts/keelstone-release-gate.sh --appstore-app build/base-scheme-release-archive-2026-07-09-code-editor-lease.xcarchive/Products/Applications/Epistemos.app` passed after ad-hoc signing.
- Bundle scan report: `build/visible-mas-proof-2026-07-09-code-editor-lease/appstore-bundle-scan-after-adhoc-sign`.
- Visible launch command: `open -n build/base-scheme-release-archive-2026-07-09-code-editor-lease.xcarchive/Products/Applications/Epistemos.app`.
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/base-scheme-release-archive-2026-07-09-code-editor-lease.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`.
- Launched bundle id: `com.epistemos.appstore`.
- Screenshot proof path: `build/visible-mas-proof-2026-07-09-code-editor-lease/archive-launch.png`.
- Screenshot showed June loaded from the exact archive app, not the missing-bundle panel.
- Caveat: the ad-hoc signed archive triggered a macOS keychain prompt for `app.epistemos`; no keychain password was entered. This is local signing evidence noise, not MAS product proof.

Code/source editability change:

- `NoteSessionStateMachine` now creates process-qualified session IDs, tracks active in-process sessions, and reclaims inactive persisted lease owners before acquiring.
- A stale persisted owner from a prior launch/crash can no longer leave Source/Code view-only forever.
- MAS executable regression test added: `appStoreLaneReclaimsOrphanedSourceLeaseAfterRelaunch`.

Code/source editability verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-code-editor-lease-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReclaimsOrphanedSourceLeaseAfterRelaunch()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-014102-98271.xcresult`
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Global edit hangs | All editor surfaces still hang; likely shared main-thread note/save/index/graph path | Trace common typing path; patch main-thread heavy work; run focused MAS tests; manually type in exact archive | HIGH OPEN |
| Graph startup latency | Graph launch/opening editors from graph is slow | Trace graph projection/bootstrap and defer or cache heavy startup work | HIGH OPEN |
| Vault active restore/save proof | Launch log still showed `refusing async code file read with no active vault` | Exact archive select/reopen vault proof and save proof; no `Cannot save page body: no vault URL` | HIGH OPEN |
| Voice product proof | Owner still reports no working voice | Exact archive Kokoro readiness and surface read-aloud proof or fix | HIGH OPEN |
| Prompt send runtime proof | Archive scan proves prompt-upgrade UI markers absent, but manual send proof still open | Send prompt in exact archive while log-scanning for Prompt Forge/Hermes prompt upgrade calls | OPEN |

## 2026-07-09 Update: Code Editor View-Only Blocker

Owner context:

> it also wont let me edit on code editor at all for some reason it just has me view it

Interpretation:

- Treat Source/Code view-only behavior as a Prompt 2 MAS release blocker.
- The editor widget already receives `isEditable: editorSurfacesAcceptInput`; the likely failure is the note-session lease above it.
- A persisted `note_session.owner_session_id` row can survive app restart/crash, making the new MAS app instance look like a follower and mounting Source/Code read-only.

Constraints:

- Do not bypass write-lease safety for genuinely active same-process note windows.
- Reclaim only stale/orphaned persisted owners so the normal owner can keep editing after relaunch.
- Keep saves gated through `beginNoteSessionWrite`; do not turn all views into unconditional writers.

Acceptance evidence needed:

- Focused state-machine regression proving a restart with an orphaned persisted lease lets the new session reclaim edit ownership.
- MAS AppStore Keelstone/source guard proving Source/Code remains wired to `editorSurfacesAcceptInput` and saves remain lease-gated.
- Exact archive manual proof remains open: Code/Source text accepts typing and persists to the restored vault.

Change:

- `NoteSessionStateMachine` sessions now default to process-qualified IDs: `epistemos:<pid>:<uuid>`.
- `NoteSessionLeaseRegistry` tracks active session IDs in memory.
- Stored `note_session` owners are reclaimed only when the owner is not an active in-process session and is not a live process-qualified owner.
- Source/Code editability remains routed through `editorSurfacesAcceptInput`; saves still require `beginNoteSessionWrite`.
- Added executable MAS regression in `EpistemosAppStoreKeelstoneTests` and a shared regression in `EpistemosTests`.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/NoteSessionStateMachine.swift \
  EpistemosTests/NoteSessionStateMachineTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-code-editor-lease-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneReclaimsOrphanedSourceLeaseAfterRelaunch()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed.
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-014102-98271.xcresult`
- `xcresulttool` summary: title `Test - Epistemos-AppStore`, result `Passed`, total `2`, failed `0`.
- Debug MAS app bundle: `build/derived-mas-code-editor-lease-2026-07-09/Build/Products/Debug/Epistemos.app`
- Debug MAS bundle id: `com.epistemos.appstore`
- Debug MAS bundle included `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive Code/Source editing proof | Debug MAS state-machine proof can miss Release/archive UI behavior | Rebuild/archive normal `Epistemos` MAS app; open exact archive; type into Source/Code; verify persisted vault write | HIGH OPEN |
| Exact Release archive prompt proof | Debug MAS source/bundle proof can miss Release/archive runtime send behavior | Rebuild/archive exact normal `Epistemos` MAS app; scan archive JuneWeb/native bundle; launch exact archive and send a prompt while log-scanning for Prompt Forge/Hermes prompt upgrade calls | OPEN |
| Exact archive Epdoc/editor performance proof | Source/unit guards can miss Release/archive WKWebView latency and formatting regressions | Rebuild/archive exact MAS app; manually test Prose, Source/Code, Epdoc, graph/hologram transitions | HIGH OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Surface read-aloud matrix and exact archive audible/manual proof or fix | HIGH OPEN |

## 2026-07-09 Update: Code Editor View-Only Regression

Latest owner wording:

> it also wont let me edit on code editor at all for some reason it just has me view it

Interpretation:

- This is a higher-priority MAS editor blocker than the remaining latency work.
- The likely source is current editability wiring around `noteSession.canWrite` and `CodeEditorView(isEditable:)`.
- Source/Code surfaces must be editable for the local owner session by default. Lease/state-machine hardening must not silently degrade ordinary editor surfaces into read-only views.

Next action:

- Inspect note-session ownership and CodeEditor mounting. Patch the Code/Source path so normal local sessions acquire/own write capability before presenting the editor or fall back to an explicit editable local-owner state, with MAS guards.

Resolution:

- Root cause: Code, Prose, and Epdoc surfaces were mounted with `isEditable: noteSession.canWrite`, but `noteSession.open()` runs from view appearance after the first render. A local owner session could therefore initialize editor views read-only and stay visually view-only even though save paths would later own the lease.
- Fix: `NoteDetailWorkspaceView` now uses `editorSurfacesAcceptInput`, which allows input when `noteSession.canWrite` is true or when no external owner is present yet. Save/write paths still go through `beginNoteSessionWrite(...)`, so lease enforcement remains at mutation time.
- Guard: MAS source tests now forbid direct `isEditable: noteSession.canWrite` mounting and require the local-owner input gate plus write-time lease checks.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  EpistemosTests/EpdocVisibilitySourceGuardTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-004502-88586.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Real archive code editor editability | Source guards can miss AppKit/WebView focus or editor initialization details | Rebuild/archive exact MAS app and manually type in Code/Source surface | OPEN |
| Cross-editor typing hangs | Local editability is fixed, but overlay/snapshot/save/index work can still stall typing | Continue editor hot-path audit and exact archive typing proof | HIGH OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-09 Update: Prose Transclusion Typing Hot Path

Owner context:

> all surfaces code editro prose sruce epdoc as well ad bascialyl all edititng surfaces hang when i start typign on them takes long time to load etc.

Interpretation:

- Treat editor typing latency as a Prompt 2 MAS hardening blocker, alongside the base-app/MAS and voice blockers.
- Avoid broad UI work while reducing specific synchronous typing paths that can run on every keystroke.

Change:

- `TransclusionOverlayManager2.refreshAfterTextChange()` now debounces full transclusion overlay rescans through `textChangeRefreshTask`.
- Added `NoteEditorPerformancePolicy.transclusionOverlayRefreshDelay = 160 ms`.
- `removeAll()` now cancels pending transclusion text-change refresh work.
- This matches the existing rendered-table overlay debounce pattern and prevents full visible-window transclusion recalculation from running synchronously on each prose text change.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/TransclusionOverlayManager2.swift \
  Epistemos/Views/Notes/ProseTextView2.swift \
  EpistemosTests/NoteEditorLayoutTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDebouncesTransclusionOverlayRefreshesDuringProseTyping()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-005032-89579.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | OPEN |
| Code editor snapshot churn | `CodeEditorView` may still publish snapshots on every key and trigger parent state/render work | Source audit and patch if `onTextSnapshot` is a live keystroke path; MAS guard | NEXT |
| Save/index work during typing | Body save, block mirror, and indexing may still run too eagerly while typing | Source audit `savePageBodyFileFirst`, block mirror scheduling, snapshot/index flows | HIGH OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-09 Update: Source Snapshot Parent-State Churn

Owner context:

> it also wont let me edit on code editor at all for some reason it just has me view it

and:

> all surfaces code editro prose sruce epdoc as well ad bascialyl all edititng surfaces hang when i start typign on them

Interpretation:

- After the local editor input gate fix, continue reducing Code/Source typing churn without weakening Source snapshot safety.
- Source snapshots still need to update before debounced persistence for lens switching and save correctness, but identical snapshots should not rewrite parent SwiftUI state.

Change:

- `NoteDetailWorkspaceView.recordSourceEditorSnapshot(...)` now compares the incoming Source body against `codeFileBodySnapshot` before assigning.
- Markdown Source mode still updates `modeBodySnapshot` immediately when the body changes, but now skips that assignment when the parsed body is unchanged.
- This keeps immediate snapshot semantics while avoiding redundant parent state writes from frame-coalesced CoreEditor snapshot events.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  Epistemos/Views/Notes/TransclusionOverlayManager2.swift \
  Epistemos/Views/Notes/ProseTextView2.swift \
  EpistemosTests/NoteEditorLayoutTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneSkipsUnchangedSourceSnapshotsBeforeRewritingParentState()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDebouncesTransclusionOverlayRefreshesDuringProseTyping()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-005455-90586.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | OPEN |
| Save/index work during typing | Body save, block mirror, and indexing may still run too eagerly while typing | Source audit `savePageBodyFileFirst`, block mirror scheduling, snapshot/index flows | NEXT |
| Graph-to-editor hangs | Embedded graph/hologram routes may still force expensive editor open/load work | Source audit graph route activation and editor mount paths; patch repeated loads or heavy side effects | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-09 Update: Duplicate Block-Mirror Work Before File-First Saves

Owner context:

> all editors bascially idk if its hte new storage or what but irealyl wnat that tobe hardnened

Interpretation:

- Treat storage-triggered typing and surface-switch stalls as part of the editor hardening blocker.
- Avoid weakening the file-first save path or durable vault truth; only remove duplicated work.

Change:

- `saveMarkdownDocumentSurfaceContent(...)` no longer schedules `BlockMirrorSyncCoordinator` immediately before calling `vaultSync.savePageBodyFileFirst(...)`.
- `flushCurrentEditor(...)` no longer schedules `BlockMirrorSyncCoordinator` immediately before calling `vaultSync.savePageBodyFileFirst(...)`.
- Non-file-first paths, including note-backed/direct Markdown Source saves, still keep their explicit `BlockMirrorSyncCoordinator` scheduling.
- `VaultSyncService.savePageBodyFileFirst(...)` remains the canonical file-first save/mirror/export path.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  Epistemos/Views/Notes/TransclusionOverlayManager2.swift \
  Epistemos/Views/Notes/ProseTextView2.swift \
  EpistemosTests/NoteEditorLayoutTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneSkipsUnchangedSourceSnapshotsBeforeRewritingParentState()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDebouncesTransclusionOverlayRefreshesDuringProseTyping()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-005852-91472.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | OPEN |
| File-first service mirror cost | `savePageBodyFileFirst` still performs canonical `BlockMirror.sync` inside the service | Decide whether to move service mirror refresh off the main save path; update wider tests if changed | OPEN |
| Graph-to-editor hangs | Embedded graph/hologram routes may still force expensive editor open/load work | Source audit graph route activation and editor mount paths; patch repeated loads or heavy side effects | NEXT |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-09 Update: Hologram Graph Preview Hidden Writes Removed

Owner context:

> lastlytrying to go to a coee editor, epdoc and other surfaces from graph embedded gaph nad th4 hologram graph cuases hangs and it takes a long time to oen and load editros code editro soruce epdocs prose preview etc. all editors bascially

and:

> it also wont let me edit on code editor at all for some reason it just has me view it

Interpretation:

- Continue treating editor/surface hangs as Prompt 2 MAS release blockers.
- A graph/hologram preview must not behave like a hidden editor. Rendering selected note text is fine; staging bodies, file-first saves, and block-mirror work during preview route changes are not.

Change:

- `HologramNodeInspector.noteEditorBody(...)` now only loads current body text for preview rendering on appear/page change.
- Removed the graph inspector preview save pipeline: no `lastPersistedBody`, no `editorSaveTask`, no `flushEditorIfNeeded`, no `debouncedEditorSave`, no private `markPageDirty` writer.
- Updated source guards so the graph inspector Preview tab remains read-only and cannot reintroduce `NoteFileStorage.stageBodyForImmediateRead(...)`, `vaultSync.savePageBodyFileFirst(...)`, or `BlockMirrorSyncCoordinator` work.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Graph/HologramNodeInspector.swift \
  EpistemosTests/GraphInspectorSourceGuardTests.swift \
  EpistemosTests/NoteEditorLayoutTests.swift \
  EpistemosTests/RuntimeValidationTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsHologramInspectorPreviewReadOnly()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneSkipsUnchangedSourceSnapshotsBeforeRewritingParentState()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDebouncesTransclusionOverlayRefreshesDuringProseTyping()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()'
```

Result:

- `** TEST SUCCEEDED **`
- 6 Swift Testing tests passed.
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-010555-92651.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | OPEN |
| Epdoc load/fidelity | Owner reports Epdoc slow load and loss of rich tables/formatting on surface switches | Source audit Epdoc bridge/session handoff; patch loss-of-fidelity path; exact archive manual proof | HIGH OPEN |
| Code editor real edit proof | Source guard shows local editor sessions editable, but owner saw view-only behavior | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| File-first service mirror cost | `savePageBodyFileFirst` still performs canonical `BlockMirror.sync` inside the service | Decide whether to move service mirror refresh off the main save path; update wider tests if changed | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-09 Update: June Agent Startup Keychain Hang and Exact MAS Archive Proof

Owner context:

> june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

> all edititng surfaces hang when i start typign on them takes long time to load etc. lastlytrying to go to a coee editor, epdoc and other surfaces from graph embedded gaph nad th4 hologram graph cuases hangs

> whenever u are good with all the steers and fixing all the outstanding issues u can cntiue the plan also ont wait for me jussst fontinue whe prompt 2 is done proeed indefinately beyind prompt 2.

Interpretation:

- Continue MAS-only Prompt 2 autonomously.
- Treat exact archive app responsiveness as the proof target, not stale debug apps or stale processes.
- Treat the Agent/JUNE open hang as part of the owner-reported all-surface responsiveness regression.
- Do not treat prompt-upgrade source removal as complete until exact archive scans and runtime logs show no Prompt Forge/Hermes prompt-upgrade path during MAS/JUNE launch and Agent open.

Runtime finding:

- Exact archive app from the previous prompt UI removal proof, PID `17587`, hung after clicking the Agent tile.
- Sample evidence: `build/visible-mas-proof-2026-07-09-prompt-ui-removed-0526/runtime-logs/agent-open-hang-sample.txt`.
- Main-thread stack showed `JuneAgentBridge.userContentController(_:didReceive:)` -> `JuneAgentGateway.preferredConfiguredCloudModel()` -> `InferenceState.hasConfiguredCloudAccess(for:)` -> `InferenceState.apiKey(for:)` -> `Keychain.load(for:)` -> `SecItemCopyMatching`.
- Concurrent background credential bootstrap was also inside keychain migration/loading, so the WebKit invoke path could block behind keychain work during Agent startup.

Change:

- `Epistemos/State/InferenceState.swift`: added `hasCachedCloudAccess(for:)`, a UI/catalog fast path that answers only from already-landed in-memory credential snapshots and does not fall through to Keychain.
- `Epistemos/JuneAgent/JuneAgentGateway.swift`: Agent startup/default-model and model payload paths now use cached configured-cloud helpers.
- `Epistemos/JuneAgent/JuneAgentModelCatalog.swift`: model rows are marked configured from a cached provider set instead of synchronously calling `hasConfiguredCloudAccess`.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`: added MAS scheme guard proving Agent startup/model-catalog paths use the cached predicate and document the no-`SecItemCopyMatching` invariant.
- Prompt-upgrade gate also remains tightened in `scripts/keelstone-release-gate.sh` for staged and built JuneWeb artifacts.

Focused MAS verification:

```bash
git diff --check -- \
  Epistemos/State/InferenceState.swift \
  Epistemos/JuneAgent/JuneAgentModelCatalog.swift \
  Epistemos/JuneAgent/JuneAgentGateway.swift \
  EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-june-startup-keychain-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsJuneStartupOffSynchronousKeychainReads()'
```

Result:

- `** TEST SUCCEEDED **`
- 1 Swift Testing test passed.
- xcresult: `build/xcode-results/2026-07-09-053902-19071.xcresult`
- Build output included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-june-startup-keychain-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsJuneStartupOffSynchronousKeychainReads()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneClearsStaleCleanLensSnapshotsAfterPersistedReload()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()'
```

Result:

- `** TEST SUCCEEDED **`
- 6 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-054201-20435.xcresult`
- Build output included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

Fresh Release archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-june-startup-keychain-0545 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- App path: `build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier: `com.epistemos.appstore`
- Required JuneWeb files present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`

Release build settings proof:

```bash
./scripts/xcodebuild_epistemos.sh \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -showBuildSettings | \
  rg 'TARGET_NAME|PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_ACTIVE_COMPILATION_CONDITIONS|ENABLE_APP_SANDBOX'
```

Result:

```text
ENABLE_APP_SANDBOX = YES
FULL_PRODUCT_NAME = Epistemos.app
PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore
PRODUCT_NAME = Epistemos
SWIFT_ACTIVE_COMPILATION_CONDITIONS =  EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT
TARGET_NAME = Epistemos-AppStore
```

Therefore `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` are absent from the active Release MAS target conditions.

Signing, gate, and archive scans:

```bash
codesign --force --sign - Contents/Frameworks/*.dylib
codesign --force --sign - --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app
codesign --verify --deep --strict --verbose=2 \
  build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app
```

Result:

- All four MAS dylibs were signed.
- App signature replaced.
- `codesign --verify --deep --strict --verbose=2` passed.

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate confirms:
  - Normal `Epistemos` scheme launches/builds/tests the MAS App Store target.
  - Legacy direct lane is explicit in `Epistemos-LegacyDev`.
  - App Store target has `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.
  - Built App Store entitlements include App Sandbox and app-scope bookmarks.
  - Built App Store artifact includes JuneWeb and omits prompt-upgrade UI/send-review hooks.
  - Built App Store artifact omits Goose ACP loopback, OAuth loopback, parked account/backend runtime markers, and quarantine xattrs.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-june-startup-keychain-0545/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- No parked account/backend runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Report directory: `build/visible-mas-proof-2026-07-09-june-startup-keychain-0545/appstore-bundle-scan`

Targeted archive scans:

```bash
rg -n "prompt\\.forge_preview|Sharpening prompt locally|agent-composer-forge|Prompt Forge|System Prompt Forge|Custom system prompt|Accepted System Prompt Forge|No accepted System Prompt Forge" \
  build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app/Contents/Resources/JuneWeb
```

Result:

- No matches.

```bash
cd build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app && \
  find . -print | rg '(^|/)(ExperimentalWeb|1Code|OpenChamber|goosed|opencode|codex|node|bun|rg|experimental-runtime)(/|$)'
```

Result:

- No matches.

Stale process handling:

```bash
pgrep -af 'Epistemos.app/Contents/MacOS/Epistemos|goosed|OpenChamber|ExperimentalWeb|opencode|experimental-runtime'
```

Result before launch:

- No matches.

Exact archive launch proof:

```bash
/usr/bin/open -n \
  /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Launched PID: `25918`
- Running process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-june-startup-keychain-0545.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Bundle identifier from launched app state: `com.epistemos.appstore`
- Computer Use state showed `june://bundle/index.html` after opening Agent.
- The Agent surface opened to `What can Workspace do for you?` without the previous keychain hang.
- Saved screenshot: `build/visible-mas-proof-2026-07-09-june-startup-keychain-0545/exact-archive-agent-open-responsive.png`

PID-scoped runtime log:

```bash
/usr/bin/log stream --style compact --info --debug --predicate 'processIdentifier == 25918' \
  > build/visible-mas-proof-2026-07-09-june-startup-keychain-0545/runtime-logs/agent-open-runtime.log
```

Runtime scan:

```bash
rg -n "prompt\\.forge_preview|Prompt Forge|System Prompt Forge|Sharpening prompt|Hermes|hermes|agent-composer-forge|goosed|OpenChamber|ExperimentalWeb|experimental-runtime|no vault URL|Workspace bundle|SecItemCopyMatching" \
  build/visible-mas-proof-2026-07-09-june-startup-keychain-0545/runtime-logs/agent-open-runtime.log
```

Result:

- No matches.
- Log line count: `4251`.
- Tail includes WebKit page-load performance (`4.1% CPU after the page load`) and background indexing preference reads, not the prior keychain block.

Current dirty file grouping:

| Group | Files/Areas |
|---|---|
| MAS-safe product and proof lane | `project.yml`, `Epistemos.xcodeproj/*Epistemos*.xcscheme`, `Epistemos-AppStore-Info.plist`, `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos/App/*`, `Epistemos/JuneAgent/*`, `Epistemos/State/InferenceState.swift`, `Epistemos/Sync/VaultSyncService.swift`, MAS KEELSTONE tests, release/scan scripts, this ledger |
| Shared substrate under MAS-safe seams | Graph/editor/note surfaces, `MarkEdit*`, `Epistemos/Engine/*`, `agent_core/*`, `epistemos-core/*`, Kokoro pipeline/runtime files, `js-editor/*`, shared model/vault services |
| Parked-lane/legacy inventory or quarantine candidates | `Epistemos/ExperimentalAgent/*`, `Epistemos/Goose/*`, `Epistemos/Work/*`, `Epistemos/VaultMCP/*`, HTML/Python/OpenCode/CLI-related rows and tests |
| Generated/build artifacts | `build/*`, `syntax-core/target/*`, compressed editor assets, DerivedData/archive products, xcode results, screenshot/log proof files |

No broad dirty state has been staged or committed.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Prompt send runtime | Archive launch/open proof shows no prompt-upgrade markers, but I did not submit a real prompt to the configured cloud model while the owner was asleep | Either local-only prompt-send proof or owner-approved cloud prompt-send log proof showing no Prompt Forge/Hermes upgrade path | OPEN |
| Vault repeat proof on latest archive | Earlier exact archive restore/save proof passed, but this new archive needs a quick repeat after additional source changes | Relaunch latest archive, confirm restored vault, save body, scan logs for no `no vault URL` and no startup unreadable-bookmark toast | HIGH OPEN |
| Voice/Kokoro | Owner still says voice does not work; prior Settings preview proof is insufficient for all surfaces | Exact latest archive audible/manual proof for June reply, Prose, Epdoc, Quick Capture, visible surface read action; fix any missing wiring | HIGH OPEN |
| Epdoc load/fidelity | Source guards and snapshot fast path are not enough for the reported UI regression | Exact archive manual Epdoc load/switch/edit proof; preserve rich tables across surface transitions | HIGH OPEN |
| All-editor typing hangs | Source guards/debouncing exist, but runtime typing across Prose/Code/Source/Epdoc still needs proof | Exact archive manual typing matrix with logs/samples if any surface hitches | HIGH OPEN |
| Code editor editability | Source guard shows local sessions editable before `onAppear`, but owner saw view-only Code editor | Exact archive Code/Source edit-and-save proof | HIGH OPEN |
| Graph startup/editor transition hangs | Dirty graph rebuild is now deferred, but exact archive graph startup/transition proof is still needed | Launch latest archive, open graph, transition to editor/Epdoc/Source, capture responsiveness/log proof | HIGH OPEN |
| Base app completion lock | Gate says normal `Epistemos` scheme is MAS target, but owner-visible normal launch behavior still needs ongoing quarantine/deletion proof | Continue inventory/deletion/quarantine of 1Code/OpenChamber/Experimental/Goose runtime ownership; normal app must remain MAS/JUNE | HIGH OPEN |

## 2026-07-09 Update: Exact MAS Archive Proof After Prompt UI Removal

Owner context:

> whenever u are good with all the steers and fixing all the outstanding issues u can cntiue the plan also ont wait for me jussst fontinue whe prompt 2 is done proeed indefinately beyind prompt 2. im going to sleep

Interpretation:

- Continue MAS-only Prompt 2 hardening autonomously.
- Do not advance the completion claim while base-app ambiguity, vault durability, prompt rewrite removal, voice, Epdoc/editor latency, and graph startup remain unproven.
- Use only exact `Epistemos-AppStore` / `MAS_SANDBOX` archive evidence for release claims.

Archive command:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-prompt-ui-removed-0526 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Compiler invocation included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.
- Exact app path: `build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier: `com.epistemos.appstore`

Local signing command:

```bash
codesign --force --sign - --entitlements Epistemos/Epistemos-AppStore.entitlements \
  build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `codesign --verify --deep --strict --verbose=2` passed.

Release gate:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Built archive included `Contents/Resources/JuneWeb/dist/index.html`.
- Built archive included `Contents/Resources/JuneWeb/tauri-internals-shim.js`.
- Built archive omitted prompt-upgrade UI and send-review markers.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-prompt-ui-removed-0526/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Passed.
- Scan report directory: `build/visible-mas-proof-2026-07-09-prompt-ui-removed-0526/appstore-bundle-scan`
- No quarantine xattrs, prohibited runtime strings, prohibited symbols, or prohibited research/tool resource residue.
- Executables remained limited to:
  - `Contents/MacOS/Epistemos`
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`

Targeted scans:

```bash
rg -n "prompt\\.forge_preview|Sharpening prompt locally|agent-composer-forge|Prompt Forge|System Prompt Forge|Custom system prompt|Accepted System Prompt Forge|No accepted System Prompt Forge" \
  build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app/Contents/Resources/JuneWeb

cd build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app && \
  find . -print | rg '(^|/)(ExperimentalWeb|1Code|OpenChamber|goosed|opencode|codex|node|bun|rg|experimental-runtime)(/|$)'
```

Result:

- No prompt-upgrade marker matches.
- No forbidden MAS app resource path matches for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, or `experimental-runtime`.

Stale-process handling:

- A previous exact archive app process from `build/appstore-release-archive-2026-07-09-voice-visible-surface-044357.xcarchive` was found as PID `2176` and terminated before this proof launch.
- No stale `Epistemos.app/Contents/MacOS/Epistemos`, `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, or `experimental-runtime` process was used as MAS evidence.
- Active Codex/node tooling processes are session infrastructure, not MAS app evidence.

Exact archive launch:

```bash
/usr/bin/open -n \
  /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Launched PID: `17587`
- Launched process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-prompt-ui-removed-0526.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Runtime bundle identifier: `com.epistemos.appstore`
- Visible app state showed MAS/June content with `Welcome Back`, `resume checkpoint`, and `GREETINGS, researcher`.
- The missing Workspace bundle panel was not present.

Screenshot evidence:

- Main MAS/June loaded proof: `build/visible-mas-proof-2026-07-09-prompt-ui-removed-0526/exact-archive-mas-june-loaded-w50695.png`
- Vault-restored note window: `build/visible-mas-proof-2026-07-09-prompt-ui-removed-0526/exact-archive-mas-june-loaded-w50698.png`
- Settings window: `build/visible-mas-proof-2026-07-09-prompt-ui-removed-0526/exact-archive-mas-june-loaded-w50699.png`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Prompt send runtime | Archive bundle no longer contains prompt-upgrade UI markers, but runtime send still needs log proof that Hermes/prompt forge is not invoked | Exact archive send with log scan for `prompt.forge_preview`, `Prompt Forge`, and Hermes prompt-upgrade calls | OPEN NEXT |
| Exact archive Epdoc proof | Owner reports table/formatting loss and slow Epdoc load/editing | Open Epdoc in exact archive, switch lenses, verify tables stay rich and typing is responsive | HIGH OPEN |
| Exact archive editor typing proof | Source/test guards can miss WKWebView/AppKit runtime hitches | Type in Prose, Source/Code, Epdoc, and Quick Capture in exact archive with logs/screenshots | HIGH OPEN |
| Graph startup and editor transitions | Owner reports graph startup and graph-to-editor transitions hang | Exact archive graph open timing and transition proof after source-level hot-path fixes | HIGH OPEN |
| Voice/Kokoro | Owner still says voice does not work | Exact archive Kokoro readiness, Settings preview audible/log proof, and surface read-aloud matrix | HIGH OPEN |
| Vault durability long-run | Earlier exact archive vault proof passed, but owner-visible issue is data-loss class | Repeat restore/save proof after later source/archive changes and ensure no `no vault URL` logs | HIGH OPEN |
| Base-app completion lock | `Epistemos` scheme was redirected to MAS target earlier, but owner wants no ambiguity | Keep scheme/target/project scans green and continue quarantining/deleting legacy lanes after inventory | HIGH OPEN |

## 2026-07-09 Update: MAS Vault Source-Retry Archive Proof

Owner context:

> User-visible bug: after selecting a vault, quitting/reopening causes Epistemos to unselect or fail to restore the vault ... Logs include "Cannot save page body: no vault URL."

> it also wont let me edit on code editor at all for some reason it just has me view it

Interpretation:

- Treat false vault disconnect, transient no-vault source reads, and restored source/code view-only behavior as Prompt 2 MAS release blockers.
- The real proof must be from the exact `Epistemos-AppStore` archive app, not stale DerivedData/debug apps.
- Do not count stale `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, local `node`, or old archive processes as MAS evidence.

Source change:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` now observes `vaultSync.vaultURL?.standardizedFileURL.path`.
- When the MAS bookmark restores after note tabs are already visible, restored persisted-body and source/code body refreshes are rescheduled.
- `scheduleCodeFileBodyRefresh` no longer logs a transient "refusing async code file read with no active vault" error before bookmark restore; it seeds a fallback snapshot and retries when the vault URL appears.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` adds `appStoreLaneRetriesRestoredSourceReadsAfterVaultRestore()`.

Focused MAS tests:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-vault-source-retry-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRetriesRestoredSourceReadsAfterVaultRestore()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersVaultSourceWarningsBeforeReadyBookmarkRestore()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLanePreservesBookmarkOnTransientRestoreFailures()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneStartupRestoreFailurePreservesLocalVaultState()'
```

Result:

- `** TEST SUCCEEDED **`
- 5 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-041851-87774.xcresult`

Exact archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-vault-source-retry-0422 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Exact app: `build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier: `com.epistemos.appstore`
- Compile flags observed in the archive frontend command: `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`
- `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` were absent from the observed App Store archive frontend command.
- `codesign --verify --deep --strict --verbose=2` passed after ad-hoc signing the app and embedded dylibs.

Release gates:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Built artifact includes `JuneWeb/dist/index.html`.
- Built artifact includes `JuneWeb/tauri-internals-shim.js`.
- Built artifact omits parked-lane visible CLI copy.

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-vault-source-retry-0422/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh \
  build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive/Products/Applications/Epistemos.app
```

Result:

- No quarantine extended attributes detected.
- No prohibited runtime strings detected.
- No parked account/backend runtime strings detected.
- No prohibited runtime symbols detected.
- No prohibited research/tool resource residue detected.
- Reports: `build/visible-mas-proof-2026-07-09-vault-source-retry-0422/appstore-bundle-scan`

Exact launch and visible MAS proof:

- Stale old archive process `PID 87298` from `appstore-release-archive-2026-07-09-vault-retry-cli-scrub-0405.xcarchive` was terminated and not counted as evidence.
- New exact archive launched with:

```bash
/usr/bin/open -n /Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive/Products/Applications/Epistemos.app
```

- Launched process:
  - `PID 94020`
  - `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-vault-source-retry-0422.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
  - bundle id `com.epistemos.appstore`
- UI proof:
  - MAS/June loaded; no missing-bundle panel.
  - Vault Settings path: `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`
  - Vault status: `Connected`
  - Import status: 266 vault-backed items restored.
  - Screenshot: `/tmp/epistemos-proof/mas-vault-source-retry-connected-2026-07-09.png`

Live save proof:

- Exact archive opened restored `New Note`.
- Appended through the restored editor:
  - `MAS source-retry archive live save verification 2026-07-09 04:31.`
- Saved with `Command-S`.
- Vault file proof:

```bash
rg -n 'MAS source-retry archive live save verification 2026-07-09 04:31' \
  '/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)' \
  --glob '*.md' \
  --glob '!**/.epcache/**'
```

Result:

- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)/New Note-3.md:10:MAS source-retry archive live save verification 2026-07-09 04:31.`
- Screenshot: `/tmp/epistemos-proof/mas-vault-source-retry-live-save-2026-07-09.png`

Log proof:

- `build/visible-mas-proof-2026-07-09-vault-source-retry-0422/epistemos-last8m.log`
- `build/visible-mas-proof-2026-07-09-vault-source-retry-0422/epistemos-after-live-save.log`
- Both logs omit:
  - `Saved vault bookmark points to a missing or unreadable directory`
  - `Automatic vault restore was paused`
  - `Cannot save page body: no vault URL`
  - `refusing async code file read with no active vault`

Stale process classification:

- No active `goosed`, `OpenChamber`, `ExperimentalWeb`, `opencode`, or `experimental-runtime` process was used as MAS evidence.
- The only `node` process matched during proof was `/Applications/Codex.app/Contents/Resources/cua_node/bin/node_repl`, which is Codex tooling and not an Epistemos MAS dependency.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive Kokoro gate/status, audible preview proof, and surface-by-surface read-visible-surface proof or fix | HIGH OPEN NEXT |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof that Prompt Forge/Hermes prompt upgrade is disabled or a source fix that removes the automatic path | HIGH OPEN |
| Exact archive Epdoc proof | Debug MAS source/unit guards can miss Release/archive WKWebView latency and formatting regressions | Open Epdoc, switch Prose/Source/Document, verify tables stay rich and editing is responsive | HIGH OPEN |
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | HIGH OPEN |
| Code editor real edit proof | Source retry fixed no-vault refresh race, but owner saw view-only behavior | Exact archive Code/Source edit test with vault write proof | HIGH OPEN |
| File-first service mirror cost | `savePageBodyFileFirst` still performs canonical `BlockMirror.sync` inside the service | Decide whether to move service mirror refresh off the main save path; update wider tests if changed | OPEN |

## 2026-07-09 Update: Exact Archive Graph/Source Hot Path Proof

Owner context:

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpretation:

- Treat graph startup render churn, source editor save fanout, and all editor typing stalls as Prompt 2 MAS release blockers.
- Continue using only the exact `Epistemos-AppStore` MAS proof scheme and archive app as evidence.
- Keep stale `goosed`, `OpenChamber`, `ExperimentalWeb`, `node`, and other dev-tool processes out of the MAS evidence set.

Changes:

- `MetalGraphView` now builds full graph commit payloads off the main actor from snapshots and idles the display link while a pending full commit is already building.
- `HologramSearchSidebar` keeps sidebar cache/tree construction off the main actor and cancels stale cache tasks on teardown.
- Markdown Source saves now use the file-first vault body write path and no longer duplicate BlockMirror/model save/code-file/vault fallback work directly from the source editor hot path.
- MAS source guards were updated to check the graph pending-commit path, source editor file-first save path, local editor input enablement, and unchanged source snapshot skips.

Focused MAS verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-graph-source-hotpath-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneSkipsUnchangedSourceSnapshotsBeforeRewritingParentState()'
```

Result:

- `** TEST SUCCEEDED **`
- 4 Swift Testing tests passed.
- xcresult after final pending-render patch: `build/xcode-results/2026-07-09-031759-62344.xcresult`

Full AppStore lane verification:

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-graph-source-hotpath-2026-07-09 \
  -only-testing:EpistemosAppStoreKeelstoneTests
```

Result:

- `** TEST SUCCEEDED **`
- 25 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-032018-63159.xcresult`
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.

Release archive:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-graph-source-hotpath-0323.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-graph-source-hotpath-0323 \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Exact app path: `build/appstore-release-archive-2026-07-09-graph-source-hotpath-0323.xcarchive/Products/Applications/Epistemos.app`
- Bundle identifier: `com.epistemos.appstore`
- The archive includes `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.

Release gate and bundle scans:

- Initial `scripts/keelstone-release-gate.sh` run failed only because `CODE_SIGNING_ALLOWED=NO` produced an unsigned archive app with no embedded entitlements.
- After ad-hoc signing the archive app with `Epistemos/Epistemos-AppStore.entitlements`, the gate passed:

```bash
./scripts/keelstone-release-gate.sh \
  --appstore-app build/appstore-release-archive-2026-07-09-graph-source-hotpath-0323.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Normal `Epistemos` scheme is mapped to the MAS AppStore target.
- MAS macros are present and `EPISTEMOS_EXPERIMENTAL` / `KINDRED_ENABLED` are absent for the AppStore target.
- Required JuneWeb files are present.
- App Store artifact omits Goose ACP loopback markers, OAuth loopback markers, parked backend/runtime markers, quarantine xattrs, and prohibited runtime strings/symbols.

Scan report directories:

- Unsigned bundle scan: `build/visible-mas-proof-2026-07-09-graph-source-hotpath-0323/appstore-bundle-scan`
- Signed bundle scan: `build/visible-mas-proof-2026-07-09-graph-source-hotpath-0323/appstore-bundle-scan-signed`

Exact archive launch proof:

```bash
/usr/bin/open -n build/appstore-release-archive-2026-07-09-graph-source-hotpath-0323.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Running process path: `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-09-graph-source-hotpath-0323.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/Epistemos`
- Running bundle id: `com.epistemos.appstore`
- PID observed: `71212`
- Screenshot evidence:
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_03-31-52-w50383.png`
  - `/var/folders/3w/cpj519g555jbvmmbp42z7mvw0000gn/T/codex-shot-2026-07-09_03-31-52-w50388.png`
- Visible state: exact archive app is no longer showing the missing Workspace bundle panel. The screenshots show live MAS app UI from the archive process, including a code editor surface in the second capture. This is archive-launch proof, not a stale DerivedData/debug app.

Stale process classification:

- No running `goosed`, `OpenChamber`, or `ExperimentalWeb` app process was observed in the MAS proof process scan.
- Many old `node headless/dist/index.cjs` processes and the active Codex/node_repl process were observed. They are external developer-tool leftovers and are not MAS runtime evidence or dependencies.
- The only running Epistemos app counted as evidence is the exact archive process above.

Current dirty file grouping:

- MAS-safe product/source: AppStore scheme/project mapping, MAS entitlements, `AppBootstrap`, `EpistemosApp`, June agent/gateway/prompt forge, vault sync, editor surfaces, graph surfaces, settings/voice/read-aloud, tests, and AppStore Keelstone guards.
- Shared substrate: `agent_core`, `epistemos-core`, `js-editor`, Kokoro local package, work/native MCP pieces, shared Rust build scripts, scan/gate scripts.
- Parked-lane/legacy: `ExperimentalAgent`, `Goose`, `AgentSurface`, HTML workspace, Work/OpenCode, and legacy docs. These changed because Prompt 2 maps or quarantines old runtime lanes, adds MAS guards, or preserves MAS-safe in-process bridge seams while preventing subprocess/local-server product dependency. They remain deletion/quarantine targets after inventory, not long-term product lanes.
- Generated/build artifacts: `.june-web-stage`, bundled `Epistemos/Resources/JuneWeb`, bundled editor assets, Rust/Xcode build outputs, `build/xcode-results`, archive/DerivedData outputs, and syntax-core target objects.

Verification debt ledger after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Vault restore exact archive proof | Owner saw data-loss warning and `no vault URL`; source guards can miss sandbox bookmark behavior | Select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit exact archive, relaunch exact archive, prove no warning and non-nil vault URL with logs | HIGH OPEN |
| Editor/graph latency manual proof | Source guards can miss runtime hangs in Release archive | Type in Prose, Source/Code, Epdoc; open from graph/hologram; capture logs/screenshots and no hangs | HIGH OPEN |
| Code editor real edit proof | Owner saw view-only behavior | Exact archive Code/Source edit with vault write proof | HIGH OPEN |
| Epdoc fidelity proof | Source guards can miss rich table/format loss during surface switches | Exact archive Prose/Source/Epdoc switch with rich table preservation proof | HIGH OPEN |
| Voice/Kokoro audible proof | Owner reports voice still does not work | Exact archive Kokoro gate status, preview log, audible/manual proof, surface read-aloud matrix | HIGH OPEN |
| Prompt upgrade/Hermes runtime send proof | Source/bundle guard can miss runtime prompt upgrade call | Exact archive send test with logs proving literal prompt submit and no Hermes prompt upgrade | OPEN |
| Signed archive gate reproducibility | Current archive was ad-hoc signed after `CODE_SIGNING_ALLOWED=NO` | Rebuild with normal signing settings if available; otherwise record ad-hoc-sign step as local proof only | OPEN |

## 2026-07-09 Update: Shared Edit Save Path and Dirty Graph Startup Hardening

Owner context:

> it still hangs alot when editting on all surfaces

> it still hangs alot when editting on all surfaces an takes a long time to startup on graph speciifcally

Interpretation:

- Treat shared editor typing latency and graph-first startup latency as Prompt 2 MAS release blockers, not polish.
- The affected surfaces share the save/snapshot substrate, so the first fix should remove synchronous post-save work from the hot path rather than tuning one editor lens.
- Graph startup should show persisted data first and schedule rebuild work after the graph is visible, unless no persisted graph exists.

Change:

- `VaultSyncService.savePageBodyFileFirst(pageId:body:)` now schedules the canonical `BlockMirror` mirror refresh asynchronously through `scheduleBlockMirrorSync(pageId:body:)` instead of running `BlockMirror.sync(...)` inline on the file-first save path.
- `GraphState.loadGraph(container:)` and `GraphState.loadGraph(context:)` now distinguish empty persisted graph state from dirty persisted graph state:
  - empty store still builds structural graph data immediately;
  - dirty-but-present store marks `pendingRebuild` through `deferStructuralRefreshUntilGraphIsVisible()` and returns the persisted graph first.
- `HologramController` no longer awaits `refreshStructuralDataAsync(container:)` during overlay setup or document reveal startup. It requests a recommit and lets the existing render/update path perform the rebuild.
- MAS source guards were added so the App Store lane fails if the file-first save path regresses to inline `BlockMirror.sync(...)` or if graph startup reintroduces synchronous dirty-store rebuilding.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Graph/GraphState.swift \
  Epistemos/Views/Graph/HologramController.swift \
  EpistemosTests/BackgroundGraphLoadingTests.swift \
  Epistemos/Sync/VaultSyncService.swift \
  EpistemosTests/AppStoreHardeningTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh -showBuildSettings \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' |
rg 'TARGET_NAME|PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_ACTIVE_COMPILATION_CONDITIONS|INFOPLIST_FILE|CODE_SIGN_ENTITLEMENTS'
```

Result:

- `TARGET_NAME = Epistemos-AppStore`
- `PRODUCT_NAME = Epistemos`
- `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
- `INFOPLIST_FILE = Epistemos-AppStore-Info.plist`
- `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- No `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED` in the active Release MAS build settings.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-edit-graph-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed:
  - `App Store lane does not double-schedule block mirrors before file-first saves`
  - `App Store lane keeps dirty graph rebuilds out of graph startup`
- xcresult: `build/xcode-results/2026-07-09-021253-9457.xcresult`

Release archive after meaningful source changes:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/appstore-release-archive-2026-07-09-edit-graph-hardened.xcarchive \
  -derivedDataPath build/appstore-release-archive-derived-2026-07-09-edit-graph-hardened \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `** ARCHIVE SUCCEEDED **`
- Archive app path: `build/appstore-release-archive-2026-07-09-edit-graph-hardened.xcarchive/Products/Applications/Epistemos.app`
- Active archive compiler invocation included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX -D EPISTEMOS_LINK_SUBSTRATE_RT`.
- No archive compiler invocation evidence for `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED`.
- Existing warnings remained in `TextCapturePipeline.swift`, `VaultSyncService.swift`, and `MarkEditShellCompatibility.swift`; no new failure.

Archive app identity and required JuneWeb assets:

```bash
APP='build/appstore-release-archive-2026-07-09-edit-graph-hardened.xcarchive/Products/Applications/Epistemos.app'
codesign --force --deep --sign - --entitlements Epistemos/Epistemos-AppStore.entitlements "$APP" &&
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" &&
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist" &&
test -f "$APP/Contents/Resources/JuneWeb/dist/index.html" &&
test -f "$APP/Contents/Resources/JuneWeb/tauri-internals-shim.js"
```

Result:

- Signature replaced for local launch/gate proof.
- Bundle identifier: `com.epistemos.appstore`
- Executable: `Epistemos`
- Required files present:
  - `Contents/Resources/JuneWeb/dist/index.html`
  - `Contents/Resources/JuneWeb/tauri-internals-shim.js`

Release gate:

```bash
./scripts/keelstone-release-gate.sh --appstore-app build/appstore-release-archive-2026-07-09-edit-graph-hardened.xcarchive/Products/Applications/Epistemos.app
```

Result:

- `KEELSTONE release gate passed`
- Gate confirmed the normal `Epistemos` scheme is mapped to the App Store target/product/tests rather than legacy.
- Gate confirmed MAS entitlements, JuneWeb archive packaging, and existing source guards for Experimental/Goose/Work/HTMLWorkspace/Pyodide/OAuth/Vault runtime exclusions.

Bundle scan:

```bash
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/visible-mas-proof-2026-07-09-edit-graph-hardened/appstore-bundle-scan \
  ./scripts/scan_appstore_bundle.sh build/appstore-release-archive-2026-07-09-edit-graph-hardened.xcarchive/Products/Applications/Epistemos.app
```

Result:

- Passed.
- Scan report directory: `build/visible-mas-proof-2026-07-09-edit-graph-hardened/appstore-bundle-scan`
- No prohibited runtime strings, parked account/backend runtime strings, prohibited runtime symbols, or prohibited research/tool resource residue.
- Executable files in the app bundle remained limited to:
  - `Contents/MacOS/Epistemos`
  - `Contents/Frameworks/libagent_core.dylib`
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libepistemos_shadow.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`

Targeted archive residue scan:

```bash
APP='build/appstore-release-archive-2026-07-09-edit-graph-hardened.xcarchive/Products/Applications/Epistemos.app'
find "$APP" -print | rg '/(ExperimentalWeb|1Code|OpenChamber|goosed|opencode|codex|node|bun|rg|experimental-runtime)(/|$)' || true
strings "$APP/Contents/MacOS/Epistemos" | rg 'EPISTEMOS_APP_STORE|MAS_SANDBOX|EPISTEMOS_EXPERIMENTAL|KINDRED_ENABLED' || true
ls -la "$APP/Contents/Resources/JuneWeb" "$APP/Contents/Resources/JuneWeb/dist/index.html" "$APP/Contents/Resources/JuneWeb/tauri-internals-shim.js"
```

Result:

- No forbidden path hits for `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, or `experimental-runtime`.
- Macro marker strings did not survive into the executable; active flags are proven by build settings and archive compiler invocation instead.
- JuneWeb required files were present in the archive bundle.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Real editor latency in exact archive | Source guards can remove obvious hot-path work but still miss WKWebView/AppKit runtime stalls | Launch exact archive; type in Prose, Source/Code, Epdoc, Quick Capture; capture logs and manual responsiveness proof | HIGH OPEN |
| Graph startup latency in exact archive | Dirty persisted graph source path is fixed, but real graph open may still block on another path | Launch exact archive; open embedded graph and hologram graph; capture startup timing/log proof | HIGH OPEN |
| Vault restore/save | Owner reports vault unselects after relaunch; previous exact archive log showed no active vault | Select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit/reopen exact archive, prove no startup warning, `vaultSync.vaultURL != nil`, and no `no vault URL` save log | HIGH OPEN |
| Voice/Kokoro | Owner says voice still does not work | Exact archive Kokoro gate readiness, preview audible/log proof, and surface matrix for June/Prose/Epdoc/Quick Capture | HIGH OPEN |
| Prompt Forge/Hermes send path | MAS source and bundle markers are disabled, but runtime send proof is still missing | Launch exact archive and send a prompt while log-scanning for Prompt Forge/Hermes prompt-upgrade calls | OPEN |
| Epdoc rich fidelity/edit latency | Owner reports slow load, table/formatting loss on surface switch, and hangs while editing | Manual exact archive Epdoc table switch/edit proof plus additional bridge profiling if still slow | HIGH OPEN |
| Manual launch of this latest archive | Build/gate/scan passed, but this exact `edit-graph-hardened` archive was not relaunched after the last source change | Launch exact archive by path when user testing window allows; avoid stale DerivedData/debug apps as evidence | OPEN |

## 2026-07-09 Update: June Prompt Upgrade / System Prompt Forge Disabled

Owner context:

> also june keeps messing up with the prompt thing wehre it tries to upgrd the prompt on sendng and it should be less aggressive and at least work and if i cant get it to work then get rid of it the prompt upgrade ssystem but rn its still calling hermes for it etc.

Interpretation:

- Normal June sends must preserve the literal owner prompt.
- The earlier per-message Prompt Forge removal was not enough because an accepted Settings System Prompt Forge layer could still compose into future local/cloud conversation instructions.
- Since the owner sees it as unreliable, remove/disable the MAS prompt-upgrade product path rather than making it less aggressive.

Change:

- `Epistemos/JuneAgent/JuneSystemPromptForge.swift` is now a disabled MAS compatibility shim:
  - settings returns empty prompts/patterns plus `disabled: true`;
  - preview returns `upgradedText == originalText`, `changed == false`, no patterns, no citations;
  - save/reset clear the stale `system-prompt-forge.json` state instead of writing accepted behavior;
  - `runtimeLayer(isLocal:)` always returns `""`.
- `Epistemos/JuneAgent/JuneAgentBridge.swift` keeps legacy `system_prompt_forge_*` command names stable for old bundles, but preview no longer uses `Task.detached`, active-vault grounding, or Prompt Forge work.
- `/Users/jojo/dev/june-epistemos/src/components/settings/AgentSettingsSection.tsx` no longer exposes editable System Prompt Forge controls; Behavior shows a disabled prompt-rewrite status.
- Tests updated:
  - `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
  - `EpistemosTests/AppStoreJuneHardeningTests.swift`
  - `/Users/jojo/dev/june-epistemos/src/test/app-settings.test.tsx`

Verification:

```bash
git diff --check -- \
  Epistemos/JuneAgent/JuneSystemPromptForge.swift \
  Epistemos/JuneAgent/JuneAgentBridge.swift \
  EpistemosTests/AppStoreJuneHardeningTests.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift
```

Result:

- Passed.

```bash
cd /Users/jojo/dev/june-epistemos && \
  git diff --check -- src/components/settings/AgentSettingsSection.tsx src/test/app-settings.test.tsx
```

Result:

- Passed.

```bash
cd /Users/jojo/dev/june-epistemos && \
  ./node_modules/.bin/vitest run src/test/app-settings.test.tsx -t "disabled prompt rewriting"
```

Result:

- 1 test passed, 38 skipped.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-prompt-forge-disabled-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneDisablesSystemPromptForgeRuntimeComposition()'
```

Result:

- `** TEST SUCCEEDED **`
- 2 Swift Testing tests passed.
- xcresult: `build/xcode-results/2026-07-09-012923-95694.xcresult`
- `xcresulttool` summary: title `Test - Epistemos-AppStore`, result `Passed`, total `2`, failed `0`.
- The MAS test target retains compile-time `#error` guards for `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`.
- The xcodebuild phase rebuilt and staged the June web fork into `.june-web-stage`; the Debug MAS app bundle included `Contents/Resources/JuneWeb/dist/index.html` and `Contents/Resources/JuneWeb/tauri-internals-shim.js`.

Staged/bundled asset scan:

```bash
rg -n "Custom system prompt|Pattern library|On-device deterministic System Prompt Forge|Accepted System Prompt Forge layer|No accepted System Prompt Forge layer|Sharpening prompt locally|agent-composer-forge|prompt\\.forge_preview" \
  .june-web-stage \
  /Users/jojo/dev/june-epistemos/dist \
  build/derived-mas-prompt-forge-disabled-2026-07-09/Build/Products/Debug/Epistemos.app/Contents/Resources/JuneWeb
```

Result:

- No matches.

Positive bundled marker check:

```bash
rg -o "Prompt rewriting disabled|No Prompt Forge preview" \
  /Users/jojo/dev/june-epistemos/dist \
  build/derived-mas-prompt-forge-disabled-2026-07-09/Build/Products/Debug/Epistemos.app/Contents/Resources/JuneWeb
```

Result:

- Found one `Prompt rewriting disabled` marker and one `No Prompt Forge preview` marker in the June fork `dist` and in the built Debug MAS app bundle.

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact Release archive prompt proof | Debug MAS source/bundle proof can miss Release/archive packaging or runtime send behavior | Rebuild/archive exact normal `Epistemos` MAS app; scan archive JuneWeb and native bundle; launch exact archive and send a prompt while log-scanning for Prompt Forge/Hermes prompt upgrade calls | OPEN NEXT |
| Exact archive Epdoc proof | Debug MAS source/unit guards can miss Release/archive WKWebView latency and formatting regressions | Rebuild/archive exact MAS app; open Epdoc, switch Prose/Source/Document, verify tables stay rich and editing is responsive | HIGH OPEN |
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | OPEN |
| Code editor real edit proof | Source guard shows local editor sessions editable, but owner saw view-only behavior | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Surface read-aloud matrix and exact archive audible/manual proof or fix | HIGH OPEN |
| File-first service mirror cost | `savePageBodyFileFirst` still performs canonical `BlockMirror.sync` inside the service | Decide whether to move service mirror refresh off the main save path; update wider tests if changed | OPEN |

## 2026-07-09 Update: Epdoc Lens-Switch Snapshot Fast Path

Owner context:

> epdoc takes a long tme to load ... transition from one surface to epdoc makes the epdoc lose uts rich tables and formattig ... edittign in epdoc hangs badly

Interpretation:

- Treat Epdoc load/fidelity and lens-switch stalls as Prompt 2 MAS release blockers.
- Preserve clean table fidelity: a clean Document switch must not serialize-and-save a normalized table snapshot.
- Dirty switches should save the already-received Markdown snapshot without forcing an extra WKWebView snapshot round trip.

Change:

- `MarkdownDocumentSurfaceCoordinator.flushPendingMarkdown()` now fast-paths when `latestMarkdown != lastFlushedMarkdown`.
- If the coordinator already has a pending Markdown snapshot from the editor bridge, lens switch/save writes that snapshot directly.
- It only requests a direct/bridge snapshot when the editor is dirty but no newer Markdown snapshot has arrived yet.
- Added MAS regression proof that a pending snapshot switch does not call the webview snapshot provider or enqueue a `flushDocumentSnapshot` command.
- Retained the clean normalized-table guard.

MAS verification:

```bash
git diff --check -- \
  Epistemos/Views/Notes/MarkdownDocumentSurface.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  EpistemosTests/EpdocVisibilitySourceGuardTests.swift \
  docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md
```

Result:

- Passed.

```bash
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-mas-editor-fastness-2026-07-09 \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreMarkdownDocumentPendingSnapshotSwitchSkipsWebViewSnapshotFlush()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreMarkdownDocumentDirtySwitchSavesDirectEditorSnapshot()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreMarkdownDocumentCleanSwitchDoesNotSaveNormalizedTableSnapshot()' \
  -only-testing:'EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()'
```

Result:

- `** TEST SUCCEEDED **`
- 4 Swift Testing tests passed.
- Compile flags included `-D EPISTEMOS_APP_STORE -D MAS_SANDBOX`.
- xcresult: `build/xcode-results/2026-07-09-011242-93855.xcresult`

Remaining verification debt after this slice:

| Item | Risk | Evidence Needed | Status |
|---|---|---|---|
| Exact archive Epdoc proof | Debug MAS source/unit guards can miss Release/archive WKWebView latency and formatting regressions | Rebuild/archive exact MAS app; open Epdoc, switch Prose/Source/Document, verify tables stay rich and editing is responsive | HIGH OPEN |
| Exact archive editor typing proof | Debug MAS source guards can miss Release/archive runtime hitches | Rebuild/archive exact MAS app; manually type in Prose, Source/Code, and Epdoc; capture logs/no hangs | OPEN |
| Code editor real edit proof | Source guard shows local editor sessions editable, but owner saw view-only behavior | Exact archive manual Code/Source edit test with vault write proof | HIGH OPEN |
| File-first service mirror cost | `savePageBodyFileFirst` still performs canonical `BlockMirror.sync` inside the service | Decide whether to move service mirror refresh off the main save path; update wider tests if changed | OPEN |
| Voice owner-visible product surfaces | Owner still reports no working voice | Exact archive audible/manual proof or fix | HIGH OPEN |
| Prompt upgrade/Hermes send path | Owner reports June still tries prompt upgrade/Hermes on send | Exact archive send proof or further removal | OPEN |

## 2026-07-10 Update: Privacy Manifest Hardening And Fresh Static Archive Proof

### Release-audit finding

The current source accesses modification-date metadata for security-scoped,
user-selected vault files. The privacy manifest declared only FileTimestamp
reason `C617.1`, which covers app-container files. Apple's current
required-reason documentation assigns `3B52.1` to files or directories the
user specifically grants access to.

### Test-first correction

- Added `appStorePrivacyManifestCoversUserSelectedVaultTimestamps()` to the
  dedicated MAS proof root. It parses the FileTimestamp entry and requires
  `C617.1` and `3B52.1` in that category.
- Red run: the full 55-test MAS suite recorded exactly the new missing-reason
  issue; result bundle
  `build/xcode-results/2026-07-09-225422-37418.xcresult`.
- Green run: 55/55 MAS tests passed; result bundle
  `build/xcode-results/2026-07-09-225835-42832.xcresult`.
- The earlier focused continuation batch passed 12/12 at
  `build/xcode-results/2026-07-09-223559-9817.xcresult`.

### Shipping and gate changes

- `PrivacyInfo.xcprivacy` now declares `C617.1` and `3B52.1` for
  FileTimestamp.
- The KEELSTONE privacy helper now traverses the plist category and its reason
  array instead of accepting unrelated global strings.
- The built-artifact gate now validates every required reason in the exact
  bundled manifest.
- Shared hardening expectations, Privacy Settings disclosure, current
  release/audit docs, canonical mirrors, and the release-audit Rust
  materializer were updated together.

### Fresh Release artifact evidence

- Xcode `26.4.1` build `17E202`, macOS SDK `26.4`.
- Archive succeeded:
  `build/appstore-release-archive-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100.xcarchive`.
- Exact archived app passed:
  - `scripts/keelstone-release-gate.sh --appstore-app <exact app>`;
  - `scripts/scan_appstore_bundle.sh <exact app>`;
  - `codesign --verify --deep --strict`;
  - effective App Sandbox entitlement inspection;
  - quarantine-attribute absence;
  - byte comparison between source and bundled privacy manifests.
- Negative artifact falsifier: the strengthened gate rejected the immediately
  preceding pre-fix archive specifically for missing FileTimestamp reason
  `3B52.1`.
- Bundle scan reports:
  `build/visible-mas-proof-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100`.
- Bundled privacy manifest SHA-256:
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`.

### Honest status

This closes the current static/archive packaging and privacy blocker. Prompt 2
is not complete: the objective did not include a preceding standalone
`go back`, so no app launch or manual exact-archive behavior proof was
performed. Vault restore/save, Epdoc rich fidelity, editor/code/graph
responsiveness, audible English Kokoro, visible MAS/June base-product truth,
and real June output or precise visible provider/model failure remain HIGH
OPEN.

## 2026-07-10 Update: June-Only Settings, Bootstrap Truth, And Exact Admission

### Owner product boundary

> rmemeber i just want mas june if it is not june then it should ot be in my app the ai models i seen in the settings of my app they msut be connected to june f thye are not im confused on why they are thee

The MAS app now uses one canonical June provider/model truth. Settings exposes
only OpenAI and Anthropic cloud providers, and only model IDs with exact
`agent_core` constructors. Parked provider implementations remain available to
direct builds but are neither shown nor admitted by MAS.

### Source hardening

- `CloudTextModelID.juneAgentModels(for:)` drives Settings, June's model
  catalog, persisted-choice repair, and gateway admission.
- The exact admitted list is GPT-5.5, GPT-5.4/mini/nano, GPT-5.2,
  GPT-4.1/mini, o3-mini, Claude Sonnet 4.6, Opus 4.7, and Haiku 4.5.
- MAS credential bootstrap, API-key reads/saves/validation, and scoped
  `agent_core` environment construction are limited to June's OpenAI and
  Anthropic providers.
- The MAS cloud client rejects a non-June provider/model before credential or
  network work. Runtime Lanes, Privacy, and Deployment Profile now reflect the
  same boundary.
- Claude OAuth/account-token source is compile-parked from the `mas-build`
  Rust branch; MAS Claude auth constructs API-key authentication directly.
- Native June bootstrap derives `providerConfigured` from cached access for
  the canonical June providers. The web fallback reports false, retains its
  visible `5030` unavailable error, and never generates canned output.
- June-only filtering applies to agent/chat models, not voice models. Agent
  Command Center recommendations reuse the active June provider list, while
  Kokoro Voice Pro Settings and installed English Kokoro voice choices remain
  present and source-guarded.
- MAS Settings diagnostics preserve the permitted native WebKit
  Browser/scraper/privacy surface but no longer count or advertise parked
  browser-use Pro, Obscura, or anti-fingerprint lanes.
- The MAS Rust FFI repeats the exact June admission boundary. It refuses
  automatic/dynamic/parked provider overrides, exposes a dedicated
  Claude/OpenAI-only factory, and does not compile Gemini, Perplexity, or the
  generic OpenAI-compatible provider modules into `mas-build`.
- MAS Settings visibly calls the destination “June Models” and the credential
  section “June Provider Setup.” Voice remains a distinct preserved section.
- June's embedded Settings now separates `generation` from `transcription`:
  only generation receives the June text-agent catalog; transcription keeps a
  local dictation row and cannot mutate the agent default. Kokoro voice choices
  remain separate and preserved.
- Its static Venice/FLUX/Qwen image-model section is hidden when the host
  supplies no image-generation model, as MAS does. The donor source and build
  guard are updated, and the embedded sidebar labels the text catalog “June
  models”; staged web assets await a resource-safe rebuild.
- MAS-hosted June Settings hides disconnected Billing, Installed skills, and
  External skill directory tabs; Agent, June models, dictation/audio, and the
  native Kokoro voice surface remain.
- A stale or crafted Settings selection can no longer report false success:
  generation must pass June gateway admission, transcription accepts only the
  local dictation row, and unsupported categories reject visibly. Kokoro voice
  models remain unchanged.
- Unavailable callbacks from June's in-process MAS agent core no longer expose
  Pro, Goose-backend, or NightBrain product copy; their visible errors and
  fallback scratch namespace now identify MAS June.
- The Swift provider-slug mapper now admits only the eleven exact June catalog
  IDs in MAS; dynamic and parked-provider heuristics compile only in the direct
  branch before the Rust factory repeats the same boundary.
- Native MAS provider help now speaks only about June and Keychain-backed
  OpenAI/Anthropic API keys; it no longer advertises parked account-session or
  alternate-product setup paths.
- The normal MAS landing tile and mounted page now visibly say June instead of
  leaving the user to infer that a generic Agent/Workspace label is the June
  surface.
- MAS onboarding now names June Foundation and removes stale MCP/skill-provider
  claims while preserving the full following Kokoro voice setup step.
- Its model sidebar row and page heading both say “June models.”
- The donor and staged June shims are byte-identical and identify the in-process
  MAS agent gateway without Hermes/external-runtime wording.

### Low-memory verification and honest status

Both Swift parser branches, focused test-source parsing, June shim JavaScript
syntax checks, `rustfmt --check`, release-gate shell syntax, scoped diff checks,
and process/RSS inspection pass. Per the owner's resource constraint, this
checkpoint ran no Xcode build/test/archive, Cargo build/check, app launch,
model load, or provider call.

The retained signed archive predates these source/shim changes. Runtime proof
remains HIGH OPEN: a later resource-safe reusable build must visibly prove the
exact provider/model menus, stale-choice repair, API-key save/check, truthful
bootstrap state, one literal June turn or precise admitted-provider error, and
artifact absence of parked OAuth/CLI/Hermes markers.

## 2026-07-10 Update: June Cloud + Selected Local Models + Kokoro

The owner clarified that “MAS June only” means one June product with three
coexisting model organs, not cloud-only: admitted OpenAI/Anthropic agent models,
the selected local GGUF chat set, and separate Kokoro voice models.

- GGUF had been disabled by commit `39df11d0f` as a conservative dependency
  rollback against stale/unverified App Store linkage. It was not an inherent
  MAS prohibition. The explicit owner steer reopens that lane.
- `Epistemos-AppStore` again links the pinned in-process `EpistemosLlama`
  facade. There is no subprocess/server/JIT/runtime download; GGUF files are
  optional model data in the app container.
- June exposes only the July 4 proven three-model set: Qwen3 4B, Qwen3 8B, and
  Qwen2.5 7B. Phi-3.5 and TinyLlama additions are removed from the active
  picker. OpenAI/Anthropic and Kokoro remain unchanged.
- Selection of an uninstalled, memory-admitted GGUF now persists and begins
  its explicit download instead of being rejected by retirement-era repair
  logic. Immutable revision/digest pins, byte caps, atomic install, receipt
  migration, cancellation, bounded streams, and memory-pressure unload guard
  the lane.
- Current Apple policy was rechecked against official guidance: executable code
  remains bundled/self-contained, while machine-learning model downloads are
  an established data-delivery pattern. The App Review audit now encodes that
  distinction and passes with no MAS subprocess surface.
- This Mac has 16 GB RAM. Qwen3 4B stays within the conservative local working-
  set ceiling; Qwen3 8B and Qwen2.5 7B remain visible but unavailable on this
  machine rather than risking swap.

Low-memory verification passes: strict Swift concurrency typecheck, MAS/direct
parse, package manifest dump, PBX validation, fresh temporary XcodeGen linkage
comparison, pinned XCFramework verification, Rust formatting, shell syntax,
App Review source audit, source contracts, and diff checks. No Xcode/Cargo
build, app launch, model load, provider request, or multi-GB hash ran.

Prompt 2 remains open. The next resource-safe runtime checkpoint must prove the
current MAS link/sign/bundle, background verification receipt, exact June model
picker, one Qwen3 4B turn/cancel/teardown, cloud error/output, Kokoro audibility,
embedded-home graph behavior, and Settings-navigation memory repair.

The clean-checkout path is now source-hardened as well: both the shared Xcode
wrapper and CI verify/fetch the pinned b9870 llama XCFramework before package
resolution, with CI caching only as an optimization. The old 222 MB archive
plus the approximately 140 MB macOS framework yields a conservative 362 MB
planning estimate below the 600 MB bundle ceiling. That estimate does not
replace a current archive, exact bundle scan, signing verification, or live
June local-model proof.

The current June donor source has now been rebuilt into `.june-web-stage` under
a 768 MB heap cap. TypeScript/Vite passed in 11 seconds with about 720 MiB peak
RSS and zero swap; the staged main chunk contains `June models`, the shim is
donor-identical, and service-worker/source-map/commercial-font exclusions pass.
After correcting two stale source-gate assertions, the full KEELSTONE source
gate also passes at about 10 MB RSS. Exact-archive packaging and visible/runtime
proof remain open; the staged tree alone is not shipping evidence.

## 2026-07-10 Update: June Consent And Honest Privacy Labels

The release-note audit found that the old no-GGUF/server-key copy also claimed
per-provider consent that June did not enforce. June now requires an explicit,
off-by-default OpenAI or Anthropic consent toggle at the final provider
admission seam, before `agent_core` can start a cloud stream. The disclosure
names the provider host and the prompt/history/approved-tool/selected-context
boundary; it is independently revocable. Missing consent surfaces `Nothing was
sent` and points to `Settings > June Models`. Local Apple/GGUF/Kokoro lanes are
unchanged.

Official Apple, OpenAI, and Anthropic policy checks also falsified the empty
privacy-manifest claim: standard provider API traffic may be retained for up to
30 days. The manifest now declares linked, non-tracking Other User Content and
provider User ID for App Functionality only. Privacy UI, App Review notes, the
Phase S audit/mirror, tests, and release gate agree. Exact plist/source gates
pass without an Xcode/Cargo/model workload.

The generated June stage no longer self-ignores: donor rebuilds are lockfile-
frozen and clean CI can validate/reuse the source-tree stage. It remains
untracked in this dirty worktree because nothing was staged or committed.
Prompt 2 remains open until a current exact archive proves consent/no-network,
the bundled privacy manifest, cloud output/error, local GGUF, Kokoro, vault,
editor/Epdoc, and graph behavior.

## 2026-07-10 Update: June Name Restored, Legacy Proxy Parked, Voice Intake Hardened

The active MAS surface no longer rewrites June to Workspace. The hosted
sidebar/composer, native chat chrome, prompt speaker identity, diagnostics,
loading/errors, read-aloud fallback, and landing copy now consistently say
June. The styling/layout/read-aloud overlay remains; only the product rebrand
and its recurring DOM scan were removed. Source tests and the KEELSTONE gate
pin this literal June-only boundary.

The obsolete receipt-gated proxy cloud engine and StoreKit subscription client
were compiled into the MAS target even though June did not call them. All three
legacy source units are now compile-parked behind an undefined flag, no target
enables it, and the active gateway is guarded from referring to either client.
The Cloud Agent model row no longer advertises proxy/subscription scaffolding;
it describes the active API-key, direct-provider, explicit-consent path.

The cloud-consent audit also closed non-chat request seams: Check Access,
Paste + Save, and the retained `CloudLLMClient` now fail before provider traffic
when consent is off. Kokoro remains fully preserved, and its downloader gained
path-traversal/collision rejection, exact SHA-256 syntax, bounded file/byte
manifests with overflow safety, and downloaded byte-count verification.

Expected-red source gates preceded each change. Focused Swift parsing, shell
syntax, diff checks, and the complete KEELSTONE source gate pass. No Xcode or
Cargo build, app/model launch, provider call, large hash, or voice download ran;
Prompt 2 runtime/archive proof remains open under the owner's RAM constraint.

The generated June bytes were then audited directly. Donor-visible Workspace
identity, false local-API copy, mixed dictation/chat model grouping, and the
incomplete hidden-tab set were corrected at source. MAS host mode now exposes
only General, Shortcuts, Dictation, Audio, June models, and About; hidden routes
are also coerced back to General if a stale/crafted tab ID is supplied. June
text models and the non-chat dictation model are separate sections. One bounded
rebuild completed at about 738 MiB peak RSS with zero swap; current staged main
SHA-256 is `0f28fac9126c5544093c02dd3f31bd2007ad6dc72b4249d9a751c8b410cda4c5`.
Donor-absent validation and the complete source gate pass; exact archive/UI
proof remains open.

Native Settings now mirrors the same boundary: visible Kokoro controls carry no
Pro branding, while MAS Foundation and Privacy describe fixed June tools rather
than MCP product/configuration surfaces. The final in-process runner also
repeats June admission below the UI gateway: only the exact OpenAI/Anthropic
slugs reverse-map, and provider consent is re-read immediately before
`runAgentSession`. Unsupported provider or revoked/missing consent fails before
the scoped agent_core call with `Nothing was sent`. The repeated App Review
source audit passed at roughly 2.2 MB RSS and zero swap.

## 2026-07-10 Update: Vault Selection Is A Relaunch-Grant Transaction

The source audit found a concrete cause for session-only vault attachment:
`connectSelectedVaultAsync` replaced the active vault before proving that the
MAS security-scoped bookmark could be saved. Bookmark failure then left the new
vault active only in memory, while the persistence function also overwrote or
removed pieces of the prior saved selection.

The flow now prepares bookmark bytes without mutating state, switches only
after preparation succeeds, and commits the new bookmark/path/trust record only
after the switch succeeds. A failed replacement preserves the currently active
vault and its saved relaunch grant. Recovery also prepares permission before
snapshot/teardown/derived-state clearing.

Expected-red source and behavior contracts preceded the fix. Focused Swift
parse passed at roughly 45 MB maximum RSS, and the full KEELSTONE source gate
passed at roughly 10 MB maximum RSS with zero swap. No Xcode/app/model workload
ran. Exact signed-archive select -> quit -> relaunch -> edit/save proof remains
HIGH OPEN; this source correction does not claim sandbox runtime completion.

## 2026-07-10 Update: Graph First-Open Store Intake Yields Cooperatively

Background SwiftData loading was not the whole startup path: GraphStore still
indexed all returned records in one uninterrupted MainActor pass. The first-open
path now reuses the same insertion logic but yields after bounded node and edge
batches, allowing window/input/loading work to run during large-vault intake.

An expected-red source probe preceded the change. Focused Swift parsing passed
at roughly 40 MB maximum RSS with zero swap. No graph runtime, Xcode build, or
archive was launched, so exact startup timing and visible responsiveness remain
HIGH OPEN rather than inferred from source.

## 2026-07-10 Update: Epdoc Replacement Cannot Lose Its Save Flusher

The retained Document surface's page-ID-only save registry allowed an old
surface's delayed async teardown to unregister a newly mounted replacement for
the same page. Registration is now coordinator-token-owned; stale teardown is
a no-op once a replacement owns the entry. The focused replacement-race test
and Swift parse pass at roughly 42 MB maximum RSS with zero swap.

This removes one lens/remount data-loss seam. Exact archive table preservation,
typing responsiveness, and Document/Prose/Source visual fidelity remain HIGH
OPEN runtime evidence.

## 2026-07-10 Update: Source Keystrokes Own The Lease Before Autosave

Source/Code text previously reached the note-session write lease only when the
900 ms save debounce fired. The editor's existing early dirty metadata signal
now marks the session dirty first, so a clean-surface handoff cannot steal the
lease while a real keystroke is buffered. The signal is coalesced until the
full text snapshot arrives; persistence cadence is unchanged.

The same audit fixed an always-true JavaScript holder check that scheduled idle
snapshot work every second. Focused parse passed at roughly 45 MB maximum RSS
with zero swap. Exact archive typing, rapid handoff, and relaunch durability
remain HIGH OPEN runtime proof.

## 2026-07-10 Update: Document And Source Share Dirty-Before-Debounce Ownership

Epdoc now marks the shared note session dirty as soon as an accepted Markdown
change reaches Swift, before its two-second autosave. Source already uses the
CoreEditor dirty bridge before its 900 ms save debounce. This prevents either
surface from looking clean to a competing handoff while real text is buffered.

Focused parse and the full low-memory source gate pass with zero swap. Exact
archive rapid typing/switching, Code editability, rich-table fidelity, and
relaunch save durability remain HIGH OPEN.

## 2026-07-10 Update: Installed Kokoro Packages Reactivate Safely

Kokoro was still linked in the MAS target, but an older checked installation
could appear disabled because the retired `EPISTEMOS_KOKORO_VOICE_PRO_V0`
preference defaulted off and current Settings has no enable toggle. Package
presence now triggers the full existing integrity/runtime validation even when
that legacy preference is absent. It does not make an invalid, partial, or
symlinked package ready, and it does not add an AVSpeech fallback.

The no-package state now says `not installed` rather than suggesting a hidden
off switch. A hermetic absent-override fixture pins migrated-package
reactivation. Focused Swift parse and the full source gate pass at roughly
43 MB and 10 MB maximum RSS respectively, both with zero swap. No real Kokoro
bytes were read or hashed and no Xcode/app/audio workload ran. Audible playback
from the exact MAS archive remains HIGH OPEN alongside the rest of Prompt 2's
runtime evidence.

## 2026-07-10 Update: Epdoc Reactivation Keeps Its Current Save Flusher

The first save-registry ownership patch separated old and replacement
coordinators, but one coordinator still reused its token across a rapid
disappear/reappear cycle. The surface now captures the disappearing
registration before async flush and renews ownership on each real appearance;
ordinary content updates keep the active token.
Delayed teardown can remove only the lifecycle it captured, not a reactivated
registration for the same page.

A serialized MAS regression pins this same-instance race. Focused parsing and
the complete low-memory source gate pass at roughly 42 MB and 10 MB maximum RSS
with zero swap. No Xcode/WebKit/app runtime ran; exact archive lens/notebook-tab
switching and saved-content proof remain HIGH OPEN.

The immediate self-audit narrowed renewal from every configuration to real
appearance only, preventing save-triggered updates during disappearance from
leaving an orphan registry entry. Focused parse and the full source gate remain
green at roughly 42 MB and 10 MB maximum RSS with zero swap.

## 2026-07-10 Update: Source Lease Changes No Longer Rebuild The Editor

CoreEditor's writable/read-only state previously participated in the full
reload decision, so normal note-lease acquisition or graph handoff could rebuild
the WebView editor and lose focus. The coordinator now uses MarkEdit's live
`setReadOnlyMode` bridge, verifies the resulting CodeMirror state, and protects
the async result with generation checks. It falls back to reload only when the
bridge fails and never reloads across a pending text snapshot.

The expected-red regression, focused parse, and complete low-memory source gate
pass at roughly 41 MB and 11 MB maximum RSS with zero swap. This is source-
patched, not owner-visible proof: exact archive typing, focus, handoff, and save
behavior remain HIGH OPEN.

## 2026-07-10 Update: Default Source Recovers From WebKit Termination

The default MarkEdit/CoreEditor coordinator no longer leaves a dead blank view
and tells the owner to reopen after its WebKit content process terminates. It
reloads from retained coordinator state, rejects empty-renderer precedence over
non-empty host text, and honestly logs the special case where an edit-dirty
signal arrived before its full text snapshot.

Focused parsing and the full low-memory source gate pass at roughly 41 MB and
11 MB maximum RSS with zero swap. No process was terminated in a running app;
exact archive recovery, continued typing, and save proof remain HIGH OPEN.

## 2026-07-10 Update: Stale Workspace Teardown Cannot Revoke A New Lease

The note workspace's async disappear path correctly flushed before closing, but
it could finish after the same view reappeared and close the newly active note
session. Appearance generations now make that delayed close conditional: the
flush still runs, while a superseded teardown cannot release the current lease.

Focused parsing/order proof and the full source gate pass at roughly 44 MB and
10.5 MB maximum RSS with zero swap. Exact archive rapid reactivation, editor
focus, typing, and persistence remain HIGH OPEN.

## 2026-07-10 Update: Structural Graph Fallback Also Yields

Initial persisted-record intake was cooperative, but a later structural refresh
still fell back to a synchronous MainActor store rebuild when it could not apply
the result incrementally. That fallback now uses the same bounded cooperative
loader, keeping background SwiftData work and eventual renderer recommit
unchanged while allowing window/editor events between indexing batches.

Focused parsing and the complete low-memory source gate pass at roughly 43 MB
and 10 MB maximum RSS with zero swap. Exact archive consistency, refresh
latency, and embedded-editor responsiveness remain HIGH OPEN.

## 2026-07-10 Update: Restore Failure Cannot Unselect The Vault

Four automatic bookmark-restore branches still erased the persisted selection.
Those branches now preserve the bookmark while failing closed and asking for
retry or re-selection; only an explicit disconnect clears it. Suspicious-folder
trust can still be cleared so reconfirmation remains mandatory.

Focused parsing/no-removal proof and the complete source gate pass at roughly
44 MB and 10 MB maximum RSS with zero swap. The signed-archive select, quit,
relaunch, restore, edit, and save sequence remains HIGH OPEN.

## 2026-07-10 Update: Source Final Save Uses The Live Editor Buffer

Source's early dirty signal was correct, but its complete MarkEdit text snapshot
is intentionally delayed to avoid full-document IPC on every keystroke. A rapid
save, lens switch, or close could therefore reach the parent flush while Swift
still held an older snapshot.

The parent now performs one bounded, on-demand CoreEditor text query before a
final Source write and awaits the existing Markdown/code writer. Dismantle
preserves a short-lived, token-owned final query so SwiftUI teardown ordering
cannot silently remove the only exact-buffer path; replacement surfaces cannot
be unregistered by stale cleanup. Dirty Source fails closed when exact text is
unavailable, and the old duplicate teardown debouncer write is suppressed.

Focused parsing and the expanded low-memory source gate pass at roughly 45 MB
and 10 MB maximum RSS with zero swap. No Xcode/WebKit/app runtime ran; exact
archive rapid typing, switch/close, reopen, byte fidelity, and focus remain HIGH
OPEN.

## 2026-07-10 Update: Source Async Writes Cannot Finish Out Of Order

The Source debounce limited frequency but did not serialize suspended
filesystem writes. Debounced and final writes now share a workspace-owned task
chain, so commit order follows enqueue order. Each write also captures the
Source editor revision; an older completion cannot mark a newer edit clean or
replace its in-memory snapshot.

Focused parsing and the expanded source gate pass at roughly 44 MB and 10 MB
maximum RSS with zero swap. Exact archive multi-burst typing, induced slow-write
ordering, failure/retry, and reopen fidelity remain HIGH OPEN.

## 2026-07-10 Update: Epdoc Async Writes Cannot Finish Out Of Order

Document/Epdoc now separates its two-second debounce from an ordered Markdown
write tail. Later edits cannot race an already-started save, and an old
completion cannot mark newer Markdown clean. Concurrent parent/manual flushes
coalesce and keep draining edits that arrive while a write is suspended.

A deterministic delayed-writer regression was added as compile/runtime debt.
Focused parsing and the expanded source gate pass at roughly 43 MB and 11 MB
maximum RSS with zero swap. Exact archive table editing, delayed save ordering,
failure retry, lens switch, and reopen fidelity remain HIGH OPEN.

## 2026-07-10 Update: Every Lens Shares One Per-Note Save Order

Local Source/Epdoc queues are no longer the only ordering boundary.
`VaultSyncService.savePageBodyFileFirst` now serializes the complete transaction
per page, covering Prose, Source, Document, graph inline edits, intents, and diff
application while allowing unrelated notes to save independently.

A deterministic blocked-export regression was added as compile/runtime debt.
Focused parsing and the source gate pass at roughly 44 MB and 11 MB maximum RSS
with zero swap. Exact archive cross-lens delayed-save order and disk bytes remain
HIGH OPEN.

## 2026-07-10 Update: Quit Waits For Live Note Durability

Authorized quit no longer tears down before SwiftUI note surfaces can flush.
Mounted workspaces and Document surfaces expose token-owned final flushes;
VaultSync exposes a per-page tail drain. The app stages visible Prose, awaits
active lens saves and dirty exports, persists recovery drafts, and only then
replies to macOS termination. A 12-second deadline prevents an unbounded quit.

Focused parsing and the expanded source gate pass at roughly 44 MB and 10 MB
maximum RSS with zero swap. Exact signed-archive Cmd-Q/cancel/timeout/relaunch
and newest-byte fidelity remain HIGH OPEN.

## 2026-07-10 Update: Local Model Pressure Unload Is Race-Safe

The local backend used to queue an immediate `llama.cpp` unload while still
advertising its previous model as loaded. A new June turn could therefore skip
reload and arrive behind an operation that had removed its context. Unloading
is now explicit lock-owned state: the backend clears model identity and blocks
new turns before engine work starts, then reopens only after unload completion.

This does not remove or broaden the selected local models. Qwen3 4B remains
admitted on the 16 GB policy; Qwen3 8B and Qwen2.5 7B remain visible but
memory-gated. Focused parsing and the expanded source gate pass at roughly
40 MB and 11 MB maximum RSS with zero swap. Exact signed-archive load,
pressure, in-flight generation, unload, reload, and RAM-reclamation proof
remain HIGH OPEN.

## 2026-07-10 Update: June Cannot Mistake A Recovered Epdoc For Blank

Epdoc's visible recovery already preferred non-empty host Markdown over a
clean blank WebKit snapshot, but June assist did not. Its context closure now
uses a coordinator resolver: clean context is the canonical host Markdown;
dirty context is the current bridge snapshot, including an intentional clear.

Focused parsing and the expanded source gate pass at roughly 46 MB and 10.5 MB
maximum RSS with zero swap. Exact signed-archive Epdoc reactivation plus June
context-byte proof remains HIGH OPEN.

## 2026-07-10 Update: An Older Epdoc Save Cannot Clear A Newer Edit Lease

Epdoc's local queue was revision-aware, but the parent note-session callback
was not. The workspace now captures a Document revision at save start and only
marks the shared lease clean if that revision is still current. A stale success
records persisted truth while preserving the newer dirty state.

Focused parsing and the expanded source gate pass at roughly 47 MB and 10 MB
maximum RSS with zero swap. Exact archive delayed-write, lens-handoff, and
reopen proof remains HIGH OPEN.

## 2026-07-10 Update: Older Prose Work Cannot Delete A Newer Crash Draft

Prose draft cleanup is now exact-content conditional and ordered with draft
writes. Both an older save completion and launch recovery preserve a draft that
was replaced while they were suspended. Empty-body edits also produce a valid
recovery artifact instead of silently retaining an older non-empty draft.

Focused parsing and the expanded source gate pass at roughly 45 MB and 10.6 MB
maximum RSS with zero swap. Exact crash/relaunch and overlapping-write proof
remain HIGH OPEN.

## 2026-07-10 Update: Prose Dirty State No Longer Waits For Autosave

Prose now tells the shared note session about an accepted edit before its save
and recovery-draft debounces begin. A second session cannot treat the lease as
clean merely because the user is still inside that debounce window.

Focused parsing and the expanded source gate pass at roughly 47 MB and 10.3 MB
maximum RSS with zero swap. Exact two-window lease-handoff and TextKit runtime
proof remain HIGH OPEN.

## 2026-07-10 Update: Quick Capture Preview Work No Longer Runs Per Render

The preview-only signal scan is cached and coalesced behind a 120 ms quiet
window, runs off MainActor, and discards stale results. The header and chip row
reuse one result; real capture extraction and persistence remain unchanged.

Focused parsing and the expanded source gate pass at roughly 45.5 MB and
10.3 MB maximum RSS with zero swap. Exact archive keystroke/paste latency and
preview freshness remain HIGH OPEN.

## 2026-07-10 Update: Cooperative Graph Startup Has No Final MainActor Sort

Graph record ingestion already yielded, but its full newest-first node sort did
not. That deterministic ordering now runs at utility priority from Sendable
records and is installed after bounded intake, preserving the prior tie-break
and hidden-node rules.

Focused parsing and the expanded source gate pass at roughly 45.5 MB and
10.5 MB maximum RSS with zero swap. Exact large-vault startup and graph-editor
transition timing remain HIGH OPEN.

## 2026-07-10 Update: Hidden Graph Chrome Stops Competing With Note Typing

The hologram sidebar remained mounted while its host was hidden, so note saves
could still provoke whole-graph cache snapshots. Cache work now cancels/skips
off-canvas and refreshes when the canvas returns.

Focused parsing and the expanded source gate pass at roughly 45 MB and 10 MB
maximum RSS with zero swap. Exact hologram route/editor latency and cache
freshness remain HIGH OPEN.

## 2026-07-10 Update: June Model Rows No Longer Lie About Selection

Restore-time fallback repair and explicit model selection are now separate.
Clicking a model keeps that exact admitted ID or fails with its actual blocker.
A local row gated by RAM says it is connected to June but cannot run on this
Mac; an unconfigured cloud row identifies the provider setup required.

Focused parsing and the expanded source gate pass at roughly 44 MB and 11 MB
maximum RSS with zero swap. No model/provider runtime ran; exact picker UI and
selection persistence remain HIGH OPEN.

## 2026-07-10 Update: June Cannot Silently Ignore A Requested Model

New-session creation, prompt submission, and model changes now all require
exact admission before success. A rejected local/cloud row cannot be reduced to
catalog membership, ignored by turn startup, or silently replaced by the old
session model.

Focused parsing and the expanded source gate pass at roughly 44 MB and 10.5 MB
maximum RSS with zero swap. No model/provider runtime ran; exact archive error
rendering and route persistence remain HIGH OPEN.

## 2026-07-10 Update: Continuation Is Autonomous And RAM-Safe

The current handoff no longer contains an actionable `go back`/keyword stop.
Prompt 2 source hardening continues autonomously while the owner's 25 GB RAM
steer defers Xcode/Cargo/model/broad-manual validation to one resource-safe
exact evidence batch after source convergence.

The active-handoff stale-directive search and focused `git diff --check` pass.
No build, test, archive, app, provider, or model runtime ran for this docs-only
reconciliation. Prompt 2 remains active; its exact runtime blockers remain HIGH
OPEN.

## 2026-07-10 Update: June Session Synchronization Is Exact

The web send path's `ensure_hermes_bridge_session` compatibility call no longer
discards failed model admission. It now persists the exact admitted local/cloud
model or rejects the invoke with the real selection blocker before the later
prompt submission can proceed on stale session state.

Focused parsing and the expanded source gate pass at roughly 41 MB and 10.5 MB
maximum RSS with zero swap. No compiled/app/model/provider runtime ran; exact
archive rejection UI and routed reply identity remain HIGH OPEN.

## 2026-07-10 Update: Persisted June Models Do Not Silently Fall Back

A conversation's non-empty persisted model now remains its exact turn model.
Credential removal, consent changes, RAM gates, download state, or an unknown
legacy ID produce the relevant visible error instead of mutating the session to
another cloud/local lane. Valid restored cloud defaults retain their exact
allowed model ID as well.

Focused parsing and the expanded source gate pass at roughly 41 MB and 10.4 MB
maximum RSS with zero swap. Exact restored-session/runtime identity proof remains
HIGH OPEN.

## 2026-07-10 Update: June Stream Caps Cover The Webview Too

June now bounds reply and reasoning deltas before both persistence and UI
emission, tracks bytes incrementally, and truncates only at valid Unicode-scalar
boundaries. The same helper covers the Apple-FM-to-GGUF fallback stream; the old
append-before-check and repeated whole-response/tail-trimming work are removed.

Focused parsing and the expanded source gate pass at roughly 41 MB and 10.7 MB
maximum RSS with zero swap. Exact adversarial-stream/webview memory proof remains
HIGH OPEN.

## 2026-07-10 Update: Kokoro Readiness Is Cached After Full Validation

SwiftUI availability queries no longer rehash the entire checked Kokoro package
on every render. The default installed package receives one thread-safe process
cache after complete validation; custom/staging validation stays uncached, and
install/remove explicitly invalidate package state.

Focused parsing and the expanded source gate pass at roughly 42.5 MB and 10.3
MB maximum RSS with zero swap. No real voice bytes or audio ran; cold validation
and audible English exact-archive proof remain HIGH OPEN.

## 2026-07-10 Update: Source Teardown Never Queries A Loading Page

MarkEdit/CoreEditor dismantle now uses the exact JavaScript buffer only when the
editor is loaded and stable. During a loading/not-ready teardown it hands the
registry the current host text without evaluating JavaScript against the page
being stopped and detached.

Focused parsing and the expanded source gate pass at roughly 40.6 MB and 10.1
MB maximum RSS with zero swap. Exact lens-switch/appearance/quit behavior remains
HIGH OPEN.

## 2026-07-10 Update: Source Timeout Diagnostics Are Load-Safe

When CoreEditor remains loading through its readiness deadline, Epistemos now
stops that navigation and loads a static escaped diagnostic page instead of
evaluating JavaScript into the unstable document. The diagnostic generation is
terminal and cannot restart readiness polling.

Focused parsing and the expanded source gate pass at roughly 40.6 MB and 10.5
MB maximum RSS with zero swap. Exact appearance/timeout/reload proof remains
HIGH OPEN.

## 2026-07-10 Update: v1 Source Fallback No Longer Stays Blank

The retained explicit WebKit fallback now reloads from its pending-or-last host
state after content-process termination and restores pending selection. It no
longer requires manual reopen or manufactures empty recovery text.

Focused parsing and the expanded source gate pass at roughly 38.9 MB and 10.5
MB maximum RSS with zero swap. Exact fallback edit/save/recovery proof remains
HIGH OPEN.

## 2026-07-10 Update: Epdoc Snapshot Queries Are Load-Safe

While the Epdoc shell is loading or recovering, snapshot requests now reuse the
last full-fidelity host Markdown and avoid page JavaScript. Once stable, the JS
getMarkdown bridge remains authoritative; no lossy projector fallback was added.

Focused parsing and the expanded source gate pass at roughly 40.6 MB and 10.3
MB maximum RSS with zero swap. Exact rich-table/format/lens-switch proof remains
HIGH OPEN.

## 2026-07-10 Update: Epdoc Teardown Detaches Before Stopping WebKit

Epdoc dismantle now invalidates the coordinator, delegates, and script bridge
before stopping its WebView navigation. A queued callback can no longer observe
the editor as attached during teardown.

Focused parsing and the expanded source gate pass at roughly 40.5 MB and 10.3
MB maximum RSS with zero swap. Exact WebKit teardown-race and archive proof
remain HIGH OPEN.

## 2026-07-10 Update: HTML Bridge Replies Cannot Cross A Preview Reload

HTML Workspace now refuses to evaluate an app-bridge response while either its
coordinator or WebView is navigating. A queued request from the outgoing page
cannot inject a reply into the replacement document.

Focused parsing and the expanded source gate pass at roughly 39.2 MB and 10.4
MB maximum RSS with zero swap. Exact preview-navigation/bridge runtime proof
remains HIGH OPEN.

## 2026-07-10 Update: Older HTML Data Patches Cannot Replace Newer Pages

HTML Workspace data-only patch completions now prove that their shell, data,
fallback HTML, and loading state are still current before reloading or
refreshing. A superseded callback cannot restore stale workspace content.

Focused parsing and the expanded source gate pass at roughly 39.3 MB and 10.3
MB maximum RSS with zero swap. Exact rapid data-feed/reload ordering proof
remains HIGH OPEN.

## 2026-07-10 Update: Only The Current HTML Navigation Can Finish

HTML preview finish/failure delegates now match the exact `WKNavigation`
returned by the current load before mutating load state or flushing pending
work. Older cancellation callbacks cannot complete a replacement page.

Focused parsing and the expanded source gate pass at roughly 39.3 MB and 10.4
MB maximum RSS with zero swap. Focused typecheck plus exact cancelled-load
runtime proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: Local June Output Cannot Silently Lose Buffered Tokens

The selected in-process GGUF route retains bounded 256-event buffers at the
llama, adapter, and June layers. Every layer now checks backpressure: overflow
stops/cancels the turn and surfaces a retry error instead of presenting a
successful answer with missing token spans.

Qwen3 4B remains admitted on the 16 GB policy; Qwen3 8B and Qwen2.5 7B remain
visible but RAM-gated. Focused parsing and the expanded source gate pass at
roughly 41.0 MB and 10.7 MB maximum RSS with zero swap. Model/slow-consumer and
focused typecheck proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: Cloud June Output Cannot Silently Lose Agent Events

The active OpenAI/Anthropic `agent_core` stream still uses its 256-event memory
bound, but now treats any dropped event as a failed turn: it surfaces a precise
retry message, cancels the exact agent session, terminates further delegate
callbacks, and clears pending permissions.

Focused parsing and the expanded source gate pass at roughly 41.8 MB and 10.5
MB maximum RSS with zero swap. Provider/slow-consumer and focused typecheck
proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: June Reloads Safely After Renderer Loss

The process-lifetime June surface now tracks page readiness and exact
navigation identity. Native frames never evaluate into a loading/dead page;
renderer termination cancels local/cloud turns and approvals before reloading
the exact bundled `june://` surface, with native session storage retained.

Focused parsing and the expanded source gate pass at roughly 41.0 MB and 10.5
MB maximum RSS with zero swap. Induced renderer-loss, recovered-session UI, and
focused typecheck proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: June WebKit Delivery Cannot Grow Without Bound

June no longer starts one unconstrained asynchronous WebKit evaluation per
token/event. Native scripts are serialized, kept in order, batched by 32, and
hard-capped at 256 queued scripts / 2 MiB. Overflow or evaluation failure
cancels native turns and reloads bundled June instead of growing an IPC heap.

Focused parsing and the expanded source gate pass at roughly 41.3 MB and 10.2
MB maximum RSS with zero swap. Exact IPC stress, visible overflow/recovery, and
focused typecheck proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: Any New June Page Stops Old Native Delivery

June now observes every main-frame provisional navigation, including a full
same-origin reload initiated by the SPA. It marks the old page unready, resets
bounded bridge IPC, installs the new navigation identity, and cancels active
turns before a ready document is replaced.

Focused parsing and the expanded source gate pass at roughly 41.3 MB and 10.3
MB maximum RSS with zero swap. Same-origin replacement and focused typecheck
proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: Vault Bookmark Timeout Is A Real Deadline

The five-second restore timeout no longer uses a structured task group that
waits for blocked synchronous bookmark resolution during child teardown. A
one-shot continuation returns the first resolver/timer result and safely
ignores a late result without deleting the saved bookmark.

Focused parsing and the expanded source gate pass at roughly 44.2 MB and 10.8
MB maximum RSS with zero swap. Blocked-resolution, security-scope, and exact
archive restore proof remain HIGH OPEN for the controlled evidence batch.

## 2026-07-10 Update: Production Vault Preflight Cannot Bypass The Deadline

Startup integrity now awaits the bounded bookmark resolver once, records its
validation, and automatic restore reuses that report. The old synchronous
preflight is no longer on the production path, and a blocked bookmark cannot
consume two consecutive five-second deadlines.

Focused parsing (with the repo's bare-regex flag) and the expanded source gate
pass at roughly 46.3 MB and 10.2 MB maximum RSS with zero swap. Blocked
preflight, security-scope, and exact archive restore proof remain HIGH OPEN.

## 2026-07-10 Update: Valid Vault Startup Resolves Its Bookmark Once

A successful bounded preflight now passes its exact in-memory resolved bookmark
to restore only when current saved bytes are identical. Restore consumes it
once; changed/missing cache uses the bounded resolver, and no resolved URL is
persisted or allowed to bypass scope/readability/stale checks.

Focused parsing (with bare-regex enabled) and the expanded source gate pass at
roughly 46.2 MB and 10.6 MB maximum RSS with zero swap. Exact security-scope,
one-resolution timing, and save/relaunch durability remain HIGH OPEN.

## 2026-07-10 Update: Kokoro Previews Cannot Stack CoreML Renders

Stopping or replacing read-aloud now cancels the detached CoreML render itself.
Kokoro synthesis is process-wide single-flight and checks cancellation between
chunks, so rapid previews cannot leave old models working while a new render
allocates concurrently. English-only voices and starter fallback are preserved.

Focused parsing and the expanded source gate pass at roughly 42.8 MB and 10.4
MB maximum RSS with zero swap. Exact CoreML cancellation/memory and audible
English archive proof remain HIGH OPEN.

## 2026-07-10 Update: Kokoro Says Why It Failed

Read-aloud no longer collapses every package/runtime/synthesis failure into a
generic “check Settings” toast. Curated Kokoro errors are normalized and
bounded for display; other errors expose only safe domain/code, never raw paths
or model/prompt bytes.

Focused parsing and the expanded source gate pass at roughly 42.8 MB and 10.1
MB maximum RSS with zero swap. Exact failure-toast and audible English archive
proof remain HIGH OPEN.

## 2026-07-10 Update: Clean Old Sessions Cannot Strand Source Read-Only

Every newly mounted Source, Prose, or Epdoc session now requests the existing
clean-owner lease handoff after open. An older clean surface transfers ownership
to the new editor; a dirty owner still blocks transfer and protects its unsaved
content.

Focused parsing (with bare-regex enabled) and the expanded source gate pass at
roughly 44.3 MB and 10.1 MB maximum RSS with zero swap. Exact two-window Source
editing/save and dirty-owner conflict proof remain HIGH OPEN.

## 2026-07-10 Update: Prose Input No Longer Creates Telemetry Task Bursts

Prose edit and cursor telemetry is now retained in order and submitted to the
friction actor as one batch per 50 ms window. The live opt-in is read once per
batch, activity tracking no longer adds a redundant main-actor task, and editor
teardown cancels pending telemetry work.

Focused parsing and the expanded source gate pass at roughly 10.2 MB and 2.7
MB maximum RSS with zero swap. Live typing/cursor stress, telemetry persistence,
focused typecheck, and exact archive proof remain HIGH OPEN.

## 2026-07-10 Update: Hologram First Display No Longer Builds Its Full Payload Inline

All hologram/window-attachment initial graph commits now share the existing
version-coalesced utility payload builder instead of synchronously constructing
all visible node and edge arrays on MainActor. Page-mode anchor and close-camera
ordering is preserved through commit completion.

Focused parsing and the expanded source gate pass at roughly 10.3 MB and 2.8
MB maximum RSS with zero swap. Large-vault Metal startup, graph-to-editor
latency, page camera, focused typecheck, and exact archive proof remain HIGH
OPEN.

## 2026-07-10 Update: Source Snapshot Debounce Retains One Worker

Source/Code live snapshot publication now uses a scalar revision and one 140 ms
quiet-window worker. It no longer creates a canceled task capturing each large
String revision, while teardown still publishes and flushes the exact current
buffer before detaching.

Focused parsing and the expanded source gate pass at roughly 10.2 MB and 2.7
MB maximum RSS with zero swap. Large-document typing/allocation profiling,
lens-switch persistence, focused typecheck, and exact archive proof remain HIGH
OPEN.

## 2026-07-10 Update: MAS Copy Now Tells The Truth About Local GGUF

Startup no longer says the app-local model stack was removed. It reports the
MAS June boundary and compile-time in-process GGUF linkage without constructing
the backend. Empty June replies point to June Models, Apple Intelligence, or an
installed local GGUF, while retired MLX state is labeled separately.

Focused parsing (with bare-regex enabled) and the expanded source gate pass at
roughly 10.3 MB and 2.8 MB maximum RSS with zero swap. Exact local/cloud June
output, focused typecheck, and exact archive proof remain HIGH OPEN.

## 2026-07-10 Update: Prose No Longer Retains Every Full-Note Revision In Debouncers

Binding sync and data detection now each retain one revision-driven worker and
read the TextKit buffer only after their quiet windows. Generation checks keep
page-switch/flush/teardown cancellation safe. Optional contextual recall reads
only a bounded live cursor window after delay.

Focused parsing and the expanded source gate pass at roughly 10.2 MB and 2.7
MB maximum RSS with zero swap. Large-note typing/allocation profiling,
data-detection/recall UI, focused typecheck, and exact archive proof remain HIGH
OPEN.

## 2026-07-10 Update: Source Live Preview No Longer Retains Every Revision

When enabled, Code/Source live preview now uses one generation-safe 260 ms
worker driven by a scalar revision and reads current text only when stable.
Preview enable stays immediate; disable and teardown cancel safely.

Focused parsing and the expanded source gate pass at roughly 10.2 MB and 2.8
MB maximum RSS with zero swap. Large-file typing/allocation profiling, WebKit
preview fidelity, focused typecheck, and exact archive proof remain HIGH OPEN.

## 2026-07-10 Update: Source Outline No Longer Retains Every Revision

The visible Source outline now uses one generation-safe worker driven by a
scalar text revision. Adaptive delay calculation and current-text capture occur
off the keystroke callback, and parsing waits for a quiet revision. Immediate
reveal, cache/cap behavior, and hide/teardown cancellation stay intact.

Focused parsing and the expanded source gate pass at roughly 10.2 MB and 2.8
MB maximum RSS with zero swap. Large-file outline/typing profiling, focused
typecheck, and exact archive proof remain HIGH OPEN.

## 2026-07-10 Update: Epdoc Autosave No Longer Retains Every Markdown Revision

Epdoc now keeps one generation-safe autosave worker. Editor changes update the
authoritative latest Markdown and scalar generation; after two seconds of quiet
the worker saves current content through the existing serialized write tail. It
loops if an edit arrives during the write, while flush/page-switch invalidation
and minimal writeback fidelity remain intact.

Focused parsing and the expanded source gate pass at roughly 10.4 MB and 2.7
MB maximum RSS with zero swap. Exact Epdoc editing/autosave/table fidelity,
focused typecheck, and archive proof remain HIGH OPEN.

## 2026-07-10 Update: Embedded Editor Routes Quiesce Inspector Work

Embedded graph routes now clear graph selection and cancel inspector profile,
summary, and reveal tasks when leaving canvas, matching the hologram route.
Those body/model tasks can no longer compete with the embedded editor load and
typing path.

Focused parsing and the expanded source gate pass at roughly 10.3 MB and 2.8
MB maximum RSS with zero swap. Exact embedded/hologram editor latency remains
HIGH OPEN until current MAS runtime proof.

## 2026-07-10 Update: Hologram Editors Stop Canvas-Only Timer Work

The hologram's 30 Hz pinned-inspector timer now stops when navigation leaves
the canvas and restarts only when the canvas returns. Its start function also
refuses non-canvas routes, covering warm show, cold creation, and restore paths.

Focused parsing and the expanded source gate pass with zero swap and peak
footprints of roughly 11.0 MB and 2.7 MB. Exact embedded/hologram editor latency
remains HIGH OPEN until controlled current MAS runtime proof.

## 2026-07-10 Update: GGUF Disconnection Is Now An Artifact-Gate Failure

The newest retained MAS archive shows the selected Qwen model but neither
embeds `llama.framework` nor links it from the app executable. The sandbox's
exact-size Qwen3 4B file also has no current verification receipt. This matches
the owner's report: catalog visibility and downloaded bytes did not equal a
connected June runtime.

The worktree now contains the in-process package linkage and safe existing-file
verification path. The KEELSTONE artifact gate now refuses any future MAS app
that lacks the embedded framework or executable load command. Source parsing
and the source gate pass with zero swap; no model or app was launched. A new
archive and real June token remain HIGH OPEN.

## 2026-07-10 Update: Epdoc Switch Logic Is Source-Reconciled

Lens changes await the active editor's canonical flush; Document remains
mounted while hidden; Source and Prose use the same Markdown snapshot; hidden
Epdoc reloads after a sibling lens changes content. Existing regressions cover
early edits, ordered concurrent flushes, blank recovery, tables, blockquotes,
and stale teardown. Focused parsing passes at roughly 11.0 MB peak footprint
with zero swap. A real multi-lens persisted formatting round trip remains HIGH
OPEN.

## 2026-07-10 Update: Kokoro Package And Runtime Remain Present

The MAS sandbox retains the full checked Kokoro package: all 75 declared files
match declared sizes, the manifest is English `en-US`, and the saved voice is
`af_bella`. The newest retained MAS binary contains the static Kokoro runtime.
Prior exact-archive logs show rendering, audio-engine start, playback start,
and playback completion without a Kokoro failure. No Core ML model or audio was
run now. Fresh current-source surface coverage and owner-audible confirmation
remain HIGH OPEN.

## 2026-07-10 Update: Retained Artifact Has A 12-Finding Exit List

The newest retained MAS archive is red for two GGUF link findings, one parked
account/backend marker finding, seven stale JuneWeb identity/configuration
findings, and two privacy-manifest findings. The full log is
`/tmp/keelstone-retained-app-gate-20260710.log`. The scan built nothing, loaded
no model, used roughly 6.2 MB peak footprint, and had zero swap. Current source
checks are green; the next useful action is one serial fresh MAS archive and the
four exact runtime legs, not more optional source churn.
