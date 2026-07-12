# MAS Base-App Completion Handoff - 2026-07-10

Instruction lock: `OWNER-INTENT-HARDENING-LOCK-2026-07-07`

Repo: `/Users/jojo/Downloads/Epistemos`

Branch observed: `feat/goose-surface`

Current product lock: MAS-only. Ignore the stale old `1Code V2` / Experimental-lane objective for this run.

## Current Autonomous And Resource Condition From Owner

The earlier temporary keyword-based interaction pause is superseded. The owner
explicitly revoked it and instructed agents to continue the full plan without
requesting or waiting for another control word. The later resource steer is
still active: GPT was consuming roughly 25 GB of RAM, so do not run massive
tests or competing heavyweight workloads.

Operational rule for the next agent:

- Continue the dependency-ordered MAS-only plan autonomously; do not stop at a
  prompt boundary and do not request a keyword.
- While the RAM constraint is active, do not run Xcode/Cargo build-test-archive
  workloads, launch models, or drive broad app/manual proof. Continue focused
  source hardening, parsing, shell/source gates, and verification-debt logging.
- Reserve exact archive/manual proof for one resource-safe evidence batch after
  source convergence; never run competing build jobs.
- Do not use stale cached `goosed`, `OpenChamber`, `ExperimentalWeb`, old Debug DerivedData apps, or any visible app the owner opened as MAS evidence.
- Current validation evidence must come from `Epistemos-AppStore` / `MAS_SANDBOX` exact build/archive paths only.

## Required Operating Mode

Use the local repo as source of truth. Read before editing.

Load and follow:

- `/Users/jojo/AGENTS.md`
- `/Users/jojo/.codex/skills/agentic-engineering-protocol/SKILL.md`

Keep coding. Do not get stuck in status-only loops. When live app testing is paused, continue with source patches, source guards, static checks, and durable verification-debt logging.

Do not stage or commit the broad dirty state unless the owner explicitly asks. This repo is very dirty, including unrelated/generated artifacts.

## Canonical Current Evidence Files

Read these first:

- `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`
- `docs/plans/keelstone/INTENT_LEDGER.md`
- `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
- `docs/plans/keelstone/PHASE0_EXCISION_INVENTORY_2026_07_06.md`
- `docs/plans/keelstone/PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md`
- `docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md`

The checkpoint file already records the last verified archive evidence:

- Scheme: `Epistemos-AppStore`
- Target: `Epistemos-AppStore`
- Configuration: `Release`
- Bundle id: `com.epistemos.appstore`
- Archive app path:
  `build/appstore-release-archive-2026-07-09-retired-lane-bundle-prune-20260709-130115.xcarchive/Products/Applications/Epistemos.app`
- Build flags in proof:
  `EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_LINK_SUBSTRATE_RT`
- Absent flags in proof:
  `EPISTEMOS_EXPERIMENTAL`, `KINDRED_ENABLED`
- Release gate result recorded:
  `KEELSTONE release gate passed`
- Bundle scan result recorded:
  no `ExperimentalWeb`, `1Code`, `OpenChamber`, `goosed`, `opencode`, `codex`, `node`, `bun`, `rg`, or `experimental-runtime` in the archived MAS bundle.
- Visible proof recorded:
  exact archive app launched and showed MAS/June rather than the missing Workspace bundle panel.

Do not assume this old archive proves current source after later edits. Rebuild,
rescan, and relaunch only in the planned resource-safe evidence batch.

## Prompt 1 Status

Prompt 1 is effectively complete for the MAS lane:

- Repo/target reality report exists in `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`.
- Current MAS reality is `Epistemos-AppStore` with AppStore target flags.
- Normal/base `Epistemos.xcscheme` was changed toward the AppStore target, and `Epistemos-LegacyDev.xcscheme` exists for legacy/dev.
- Remaining Prompt 1 residual is owner trust/launch ambiguity: the normal app the owner opens must be MAS/June and not old 1Code/OpenChamber. Treat that as part of Prompt 2 completion proof.

## Prompt 2 Current Definition

Prompt 2 is not complete until:

- One active product reality: MAS/June.
- The normal/base app the owner opens matches the MAS App Store product.
- Old 1Code/OpenChamber/Experimental/Goose subprocess/local server/Node/Bun/opencode runtime lanes are deleted or quarantined after inventory.
- MAS archive builds/scans clean.
- Base launch path opens MAS/June, not 1Code/OpenChamber.
- Vault restore/save works in the exact MAS archive.
- JuneWeb is packaged into the MAS archive at `Contents/Resources/JuneWeb`.
- June sends through the native gateway and does not use per-message Prompt Forge/Hermes on normal send.
- Epdoc, source/code, prose, quick capture, graph embedded, and hologram graph are responsive and editable where expected.
- Kokoro/read-aloud works in English or fails visibly with a precise install/status reason.

Do not advance to Prompt 3 until the base-app ambiguity and the current MAS release blockers are resolved or logged as HIGH blockers with exact next actions.

## Current Owner-Visible Open Issues

Treat these as the active bug list, not optional polish:

1. Vault restore/data-loss blocker
   - Owner sees valid vault become unselected or unreadable after quitting/reopening.
   - Startup toast: "Saved vault bookmark points to a missing or unreadable directory. Automatic vault restore was paused."
   - Logs include: `Cannot save page body: no vault URL`.
   - Required exact-archive proof: select `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)`, quit exact archive, reopen exact archive, same vault restored, no warning toast, `vaultSync.vaultURL` non-nil, saves do not log `no vault URL`.

2. Epdoc blanking/fidelity blocker
   - Owner reports Epdoc goes blank when opening or switching to/from other surfaces.
   - Owner reports switching surfaces can make Epdoc lose rich tables/formatting, as if copied/normalized instead of rerendered.
   - This came back after earlier work.

3. Editing performance blocker
   - Owner reports hangs when typing in all editing surfaces: Epdoc, Prose, Source/Code, Quick Capture, graph embedded, hologram graph.
   - Owner reports graph startup specifically takes too long.
   - Owner reports opening nodes from embedded graph/hologram graph to editors is slow and then editing hangs.

4. Code editor editability blocker
   - Owner reports code editor is view-only and will not allow editing.

5. Voice/Kokoro blocker
   - Owner reports voice still does not work.
   - Owner reports voice sounds like another language.
   - Owner wants English. If an English model/voice is not actually being used, fix the product wiring rather than calling it "model missing."

6. June MAS blocker
   - Owner reports June MAS is not really producing outputs.
   - Owner cannot tell if June works.
   - Per-message prompt upgrade must be disabled or much less aggressive. Normal send must not call Hermes/Prompt Forge.
   - Missing host bridge must fail visibly, not return a fake canned answer.

7. Base app/product reality blocker
   - Normal/base app must be MAS/June or legacy/dev must be renamed/quarantined so it cannot be mistaken for product.
   - Old 1Code/OpenChamber/Experimental/Goose runtime lanes are deletion/quarantine targets after inventory, not permanent parked product lanes.

## Source Patches Already Made But Not Fully Reverified

These are source-only or partially verified. Do not claim final success from them.

### Vault Restore

Files touched:

- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/WorkspaceSnapshotTests.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `scripts/keelstone-release-gate.sh`

Patch intent:

- `StartupIntegrityReport.shouldBlockAutomaticVaultRestore` now blocks corrupted managed-body samples only when no vault bookmark exists.
- If a vault bookmark exists and bookmark validation is not blocking, startup integrity suppresses the corrupted-body "Automatic vault restore paused" segment so bookmark restore can repair cache gaps.

Tests/guards added:

- `startupIntegrityLetsSavedVaultRestoreRepairNoteBodyVerificationFailures()`
- `appStoreLaneLetsSavedVaultRestoreRepairManagedBodyCacheGaps()`

Verification still needed:

- Focused tests in the resource-safe evidence batch.
- Exact MAS archive vault select/quit/reopen/save proof.

### Epdoc Blank Snapshot Guards

Files touched:

- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `scripts/keelstone-release-gate.sh`

Patch intent:

- `EpdocEditorChromeController.handleBridgeMessage(.markdownDidChange)` now rejects a clean empty Markdown snapshot when the host still has a non-empty Markdown source.
- It logs:
  `Epdoc clean Markdown snapshot was empty; re-pushing non-empty host Markdown source`
- It calls `reloadMarkdownSourceForCleanReactivation(...)` and does not call `onMarkdownChanged`.
- A dirty editor can still intentionally save an empty document.

Resolved source lead:

- `preferredNonEmptyRememberedMarkdown(hostMarkdown:)` is now present and the
  reactivation/initial-load paths prefer non-empty bridge, retained, or host
  Markdown instead of allowing a clean empty WebKit snapshot to dominate.
- Loading snapshot queries reuse the host Markdown without page JavaScript,
  and Epdoc teardown invalidates coordinator/delegate/handler callbacks before
  stopping WebKit.

Tests/guards already added:

- `chromeControllerRepushesNonEmptyMarkdownSourceAfterCleanPostLoadBlankSnapshot()`
- `appStoreLaneRepushesEpdocMarkdownAfterCleanPostLoadBlankSnapshot()`

Tests/guards now present:

- Coordinator regression for blank latest snapshot plus non-empty host Markdown.
- MAS/source gates for the recovery helper, load-safe snapshots, and teardown
  ordering.

Verification still needed:

- Focused Epdoc tests in the resource-safe evidence batch.
- Exact MAS archive proof that opening/switching/reopening Epdoc preserves tables/formatting and does not blank.

### Graph Startup And Graph Node Opening

Files touched:

- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/Graph/GraphState.swift`
- `EpistemosTests/BackgroundGraphLoadingTests.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`

Patch intent:

- Embedded graph startup starts `graphState.loadGraph(container:)` asynchronously instead of depending on a later panel/render side effect.
- `GraphState.openNode(_:)` routes note-like node types `.note`, `.person`, `.project`, `.topic`, `.decision`, `.event`, `.resource` into `openNote(resolvedId)` instead of preview-only selection.
- `.folder` routes to `openFolder(resolvedId)`.

Verification still needed:

- Focused tests in the resource-safe evidence batch.
- Exact MAS archive proof for embedded graph and hologram graph startup, node open, editor editability, and typing latency.

### Editing Performance

Files touched include:

- `Epistemos/Engine/CodeEditorContentDebouncer.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Views/Notes/NoteTableOfContents.swift`
- `Epistemos/Views/Notes/TransclusionOverlayManager2.swift`
- `Epistemos/Views/Graph/*`
- `js-editor/*`

Known source changes:

- Code editor debounce window increased toward `900ms`.
- Prose reparse debounce scales for large docs.
- Table overlay refresh throttled.
- Heavy outline work is disabled/limited in graph embedded contexts.

Do not assume this is enough. The owner still reports hangs. Next agent should profile/source-audit synchronously executed work on every keystroke and graph-to-editor transitions.

High-probability areas to inspect:

- `NoteDetailWorkspaceView.onReceive(NoteFileStorage.pageBodyDidChange)`
- `schedulePersistedBodyRefresh`
- `scheduleMetricsRefresh`
- outline/TOC/block outline generation
- `ProseTextView2` local reparse path
- `CodeEditorView` snapshot and save path
- `MarkdownDocumentSurface.scheduleMarkdownSave`
- graph structural refresh/rebuild triggers while editors are active
- `js-editor/src/bridge/outbound.ts`, `document-load-state.ts`, and writeback tracker paths

Verification still needed:

- Source-only static checks now.
- Focused tests and manual latency proof in the resource-safe evidence batch.

### Kokoro English Voice / Read-Aloud

Files touched:

- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`
- `Epistemos/Engine/EpistemosAgentReadAloud.swift`
- `Epistemos/Engine/EpistemosVisibleReadAloud.swift`
- `Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift`
- `Epistemos/Views/Shared/ReadAloudButton.swift`
- `Epistemos/Views/Shared/ModelVoicePickerSection.swift`
- `Epistemos/Views/Settings/VoicePreferencesSection.swift`
- `Epistemos/JuneAgent/JuneAgentNavBar.swift`
- `Epistemos/JuneAgent/JuneAgentBridge.swift`
- `Epistemos/JuneAgent/JuneAgentSurfaceView.swift`
- `Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift`
- `Epistemos/Views/Capture/QuickCaptureView.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Meeting/MeetingNoteView.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `EpistemosTests/KokoroVoiceSelectionTests.swift`

Patch intent already present:

- MAS read-aloud is Kokoro-only. AVSpeech is not a runtime fallback.
- `EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(...)` selects installed English Kokoro IDs only, then falls back to `KokoroVoiceGateStatus.starterVoiceIdentifier`.
- `KokoroCoreMLSynthesizer.renderRawText(...)` accepts selected voice embeddings only for English prefixes:
  `af_`, `am_`, `bf_`, `bm_`.
- English phoneme prep exists through `englishPhonemeSymbols(...)`.
- `EpistemosVisibleReadAloudRegistry` has MAS-owned visible surface providers.
- Buttons should show visible unavailable/failure reasons instead of silent no-op.

Resolved source lead:

- `ModelVoicePickerSection.refreshVoicesAndHints()` now normalizes stale Apple
  or non-English identifiers through
  `normalizedEnglishKokoroVoiceIdentifier(...)` against installed English
  voices.
- Kokoro readiness is process-cached only after full default-package validation;
  install/remove invalidates it. Rendering is single-flight and cancellation
  reaches detached CoreML work, so rapid previews cannot stack model renders.
- Curated loader/synthesis failures now reach a bounded visible toast; arbitrary
  raw error/path text does not.

Tests/guards already added:

- `appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput()`
- `appStoreLaneOwnsVisibleReadAloudSurfacePath()`
- `KokoroVoiceSelectionTests` English catalog/phoneme tests.

Tests/guards updated:

- `SSQCGlobalVoiceTests` and `VoiceCodepackPlan3Tests` now require the
  English-only picker and stale-ID normalization, plus render cancellation and
  single-flight source witnesses.

Verification still needed:

- Exact MAS archive readiness log:
  gate resolved true, model root, manifest valid, `KokoroPipelineLinked=true`, `isTextToSpeechAvailable=true`.
- Settings -> Voice preview audible English proof.
- Read-aloud matrix:
  June latest assistant reply, Prose note body, Epdoc selected/visible document text, Quick Capture, Code editor/current MAS surface.

### June MAS Send / Prompt Forge

Files touched:

- `Epistemos/JuneAgent/JuneAgentGateway.swift`
- `Epistemos/JuneAgent/JuneAgentBridge.swift`
- `Epistemos/JuneAgent/JuneAgentSurfaceView.swift`
- `Epistemos/JuneAgent/JuneSystemPromptForge.swift`
- `Epistemos/JuneAgent/JuneWebAssets.swift`
- `.june-web-stage/tauri-internals-shim.js`
- `/Users/jojo/dev/june-epistemos/epistemos/tauri-internals-shim.js`
- `scripts/keelstone-release-gate.sh`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`

Patch intent:

- Per-message `prompt.forge_preview` is disabled for MAS normal send.
- `prompt.submit` uses the submitted text directly.
- Missing MAS host bridge returns visible error code `5030` instead of canned echo.
- Release gate rejects the old fake string:
  `Echo from the Epistemos in-process gateway bridge`
- Release gate rejects Hermes-branded send/session failure drift in staged and built JuneWeb.

Important next verification:

- Rebuild/stage JuneWeb after shim changes.
- Archive AppStore in the resource-safe evidence batch.
- Prove June send routes through `JuneAgentGateway` and either produces streamed output or a visible provider/model configuration error.
- Scan logs and bundle for Prompt Forge/Hermes drift on normal send.

### JuneWeb Bundle Packaging

Already required by release gate:

- `Contents/Resources/JuneWeb/dist/index.html`
- `Contents/Resources/JuneWeb/tauri-internals-shim.js`

Last verified archive had these files present, but later source/staged shim edits
mean the archive must be rebuilt in the resource-safe evidence batch.

## Dirty File Grouping

Do not commit broad dirty state without owner approval. Current worktree has hundreds of changed files.

MAS-safe/product lane examples:

- `Epistemos-AppStore-Info.plist`
- `Epistemos/Epistemos-AppStore.entitlements`
- `Epistemos.xcodeproj/project.pbxproj`
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme`
- `project.yml`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/JuneAgent/*`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`
- `Epistemos/Engine/EpistemosAgentReadAloud.swift`
- `Epistemos/Engine/EpistemosVisibleReadAloud.swift`
- `Epistemos/VoicePro/*`
- `Epistemos/Views/Notes/*`
- `Epistemos/Views/Epdoc/*`
- `Epistemos/Views/Capture/QuickCaptureView.swift`
- `Epistemos/Views/Shared/*`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `scripts/keelstone-release-gate.sh`
- `scripts/scan_appstore_bundle.sh`

Shared substrate examples:

- `agent_core/*`
- `epistemos-core/*`
- `LocalPackages/KokoroPipeline/*`
- `js-editor/*`
- shared graph/editor/vault code under `Epistemos/Graph`, `Epistemos/Vault`, `Epistemos/Engine`

Parked-lane/legacy examples:

- `Epistemos/ExperimentalAgent/*`
- legacy Goose ACP/local server/subprocess files under `Epistemos/Goose/*`
- `Epistemos/Work/*` local runtime/opencode paths
- `Epistemos/VaultMCP/*`
- `Epistemos/Harness/*`
- old Goose/OpenChamber/Experimental docs/prompts

Generated/build artifact examples:

- `build/*`
- `.june-web-stage/*`
- `syntax-core/target/*`
- compressed `Epistemos/Resources/Editor/*.br`
- xcresults, archive proof dirs, DerivedData, screenshots, logs

## Why ExperimentalAgent And Goose Files Changed

ExperimentalAgent files changed because Prompt 2 requires legacy/parked surfaces to be made explicit under MAS source guards and target membership quarantine. The old 1Code/OpenChamber/Experimental surface cannot silently define product reality.

Goose files changed because MAS June may preserve a useful MAS-safe in-process `agent_core` seam, while legacy `goosed`, ACP WebSocket/local server, subprocess, provider-key bridge, and runtime health paths are parked/excluded/deletion targets.

Do not preserve these old lanes just because older docs say "do not delete first." Interpret that as inventory before deletion, not indefinite retention.

## 2026-07-10 Clean Continuation Evidence

- The latest graph, Epdoc, Kokoro, vault, editor, and June source patches were
  compiled together in a focused MAS batch: 12/12 passed at
  `build/xcode-results/2026-07-09-223559-9817.xcresult`.
- `xcresulttool` confirms the focused result is 12/12 and the full dedicated
  MAS lane green result is 55/55, both with zero failures or skips.
- A release audit found the privacy manifest lacked FileTimestamp reason
  `3B52.1` for user-selected vaults. The new MAS regression failed first, then
  passed in a 55/55 suite after the manifest/gate/disclosure correction.
- Fresh current archive:
  `build/appstore-release-archive-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100.xcarchive`.
- Fresh normal Release build settings resolve to `Epistemos-AppStore`, bundle
  ID `com.epistemos.appstore`, App Sandbox, App Store entitlements, and the MAS
  compile conditions.
- The exact archived app passed the KEELSTONE built-app gate, App Store bundle
  scan, strict deep signature verification, effective entitlement inspection,
  quarantine check, and bundled privacy-manifest comparison.
- The strengthened gate rejected the immediately preceding pre-fix archive
  specifically for missing bundled FileTimestamp reason `3B52.1`.
- Scan reports:
  `build/visible-mas-proof-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100`.
- No Epistemos launch or UI control was performed because the active owner RAM
  constraint defers that work to the resource-safe exact evidence batch.

## 2026-07-10 Continued Low-Memory Source Convergence

The autonomous Prompt 2 loop continued under the owner's RAM constraint. No
Xcode/Cargo build, test, archive, app/model/provider launch, real package hash,
or audio run occurred in these slices. Focused Swift parsing stayed around
39-46 MB maximum RSS and the expanded source gate around 10-11 MB, always with
zero swaps.

Additional landed source corrections:

- June exact model selection/session restore no longer silently falls back.
- Local llama, GGUF adapter, June local events, and OpenAI/Anthropic
  `agent_core` events retain bounded buffers but fail visibly on backpressure
  instead of silently dropping output.
- Native-to-June WebKit delivery is serialized, ordered/batched, and capped at
  256 queued scripts / 2 MiB; overflow cancels turns and reloads bundled June.
- June tracks page readiness and exact navigation identity, invalidates every
  new main-frame document, and recovers renderer loss without evaluating into a
  loading/dead page.
- Vault bookmark timeout is a true one-shot deadline, production preflight uses
  it once, and a successful exact-data-matched resolution is consumed by
  restore without resolving twice.
- Newly mounted Source/Prose/Epdoc sessions reclaim clean write leases in every
  presentation; dirty owners still block transfer.
- HTML Workspace app replies, navigation completion, and data patch callbacks
  are load/identity/revision guarded.

The current source gate remains green. These are source corrections, not exact
archive completion. The HIGH exact-runtime matrix below remains mandatory in
one controlled evidence batch after source convergence.

## Next Agent Immediate Plan

While the owner RAM constraint is active:

1. Do not run heavyweight build/test/archive/model workloads or broad manual
   app automation.
2. Preserve the fresh archive above as the current static artifact proof.
3. Continue only evidence-driven source/static release work; do not rerun the
   same archive/gate batch without a concrete source change or new falsifier.
4. Do not advance to Prompt 3 or claim Prompt 2 complete.

In one resource-safe exact evidence batch after source convergence:

1. Launch only the exact archive app above by full path.
2. Prove normal/base product identity is MAS/June.
3. Prove security-scoped vault select, save, quit/reopen restore, and no-loss
   behavior.
4. Prove Epdoc open/switch/reopen rich-table fidelity and responsive editing.
5. Prove input and save behavior in Prose, Source/Code, Quick Capture,
   embedded graph, and hologram graph, including correct graph node routing.
6. Prove audible English Kokoro Settings preview and read-aloud surface matrix,
   or capture a precise truthful visible blocker.
7. Prove June returns real output or a precise provider/model error and collect
   log evidence that normal send performs no Hermes/Prompt Forge rewrite.
8. Run the scoped release-audit/deep-hardening and repeated zero-fail matrix
   after those HIGH blockers close. Only then consider Prompt 2 complete.

## Verification Debt Ledger

| Area | Status | Required evidence |
| --- | --- | --- |
| Prompt 1 repo/target reality | Current static proof complete | Both base and App Store Release settings resolve to `Epistemos-AppStore`, MAS entitlements, and MAS compile conditions. |
| Base app opens MAS/June | Open residual | Owner-opened normal app path or installed app path must resolve to MAS/June, not old 1Code/OpenChamber |
| JuneWeb packaged | Exact archive verified | Current archive contains `Contents/Resources/JuneWeb/dist/index.html` and `tauri-internals-shim.js`; gate and scan pass. |
| Vault restore/save | HIGH open | Exact archive select/quit/reopen/save proof, no warning toast, no `no vault URL` |
| Epdoc blanking/fidelity | HIGH open | Exact archive open/switch/reopen proof preserving content/tables/formatting |
| Editor typing performance | HIGH open | Focused tests plus exact archive latency/profiling proof across all editor surfaces |
| Graph startup/node open/edit | HIGH open | Embedded and hologram graph open note-like nodes into editable surfaces without hangs |
| Code editor editability | HIGH open | Exact archive source/code edit and save proof |
| Kokoro English voice | HIGH open | Gate-ready logs plus audible English Settings preview and surface matrix |
| June MAS send | HIGH open | Exact archive prompt submit reaches native gateway and returns real streamed output or visible provider/model error; no Hermes/Prompt Forge normal-send calls |
| Privacy/entitlements/parked residue | Exact archive verified | Recheck only after relevant source/build changes; current manifest, signature, entitlements, quarantine, KEELSTONE, and scan evidence pass. |

## Commands To Avoid Under The Active RAM Constraint

Avoid app-facing/live commands such as:

- `open -n ...Epistemos.app`
- app screenshots or Computer Use against Epistemos
- killing/quitting Epistemos/goosed/OpenChamber/ExperimentalWeb for proof
- xcode archive launch/manual proof
- broad UI automation

Static reads and edits are fine.

## Static Checks Safe Under The Active RAM Constraint

Examples:

```bash
git diff --check -- <touched files>
bash -n scripts/keelstone-release-gate.sh
node --check .june-web-stage/tauri-internals-shim.js
node --check /Users/jojo/dev/june-epistemos/epistemos/tauri-internals-shim.js
rg -n "pattern" <source paths>
```

## Exact Reminder For Future Final Reports

Do not claim owner-visible issues fixed from source or archive gates alone. Say
"source-patched/archive-gate-passed" until the manual exact-archive behavior
proof has run.

The owner wants an agent that continues coding autonomously without keyword or
status-only pauses. Keep a concrete verification-debt ledger, but spend most
time removing the blockers above.
