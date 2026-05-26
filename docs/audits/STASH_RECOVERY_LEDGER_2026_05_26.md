# Stash Recovery Ledger - 2026-05-26

Status: active recovery queue

Purpose: prevent stashed work from becoming invisible. This ledger records which
local stashes contain real product work, which are already represented on main,
and which are generated build churn. Do not drop any stash until its row is
explicitly closed by a merged PR or a user-approved retirement note.

Ground rules:

- Never `git pop` or bulk-apply a stash onto `main`.
- Never use `git checkout <stash> -- file`.
- Recover by `git diff stash@{N}^1 stash@{N} -- <paths> > /tmp/...patch`,
  then `git apply --3way` onto a focused recovery branch.
- Filter generated paths before deciding anything:
  `target/`, `.build/`, `DerivedData/`, `node_modules/`, `Build/`,
  `test_results/`, `.xcresult`, object files, archives, and Rust dep files.
- Every recovered slice must build/test before merge. If a stash contains
  temporary debug scaffolding, recover the durable intent only and document the
  discarded temporary shell.

## Current Checkpoint

Current main checkpoint before this ledger:

- `#83` restored preserved local UI work.
- `#84` restored source-guard and verified-floor tests.
- `#85` restored audit docs.
- `#86` restored snappy graph/editor defaults and the HTML workspace route.
- Tag: `checkpoint/ui-restored-graph-audited-2026-05-26`.

## Recovery Priority

1. `stash@{13}`, `stash@{14}`, `stash@{8}`, `stash@{9}` - substrate/research
    nuances, recover after UI and graph-visible work.

Closed but preserved:

- `stash@{0}` - B-prime follow-up. Current product recovery is closed by
  `docs/audits/B_PRIME_FOLLOWUP_CLOSEOUT_2026_05_26.md`; keep the stash/tag/PR
  only as a preservation reference until the user approves retiring old recovery
  refs.
- `stash@{18}` - large old-main UI/UX donor. Current product UI/UX recovery is
  closed by `docs/audits/STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md`
  and `docs/audits/STASH18_UI_UX_CLOSEOUT_2026_05_26.md`; keep the stash only as
  a historical donor reference.
- `stash@{15}` - graph filter/physics selected-expansion WIP. Current product
  graph recovery is closed by
  `docs/audits/STASH15_SELECTED_NEIGHBOR_EXPANSION_2026_05_26.md` and
  `docs/audits/STASH15_GRAPH_CLOSEOUT_2026_05_26.md`; keep the stash only as a
  historical graph/performance donor reference.
- `stash@{3}` - VaultRecall visibility and Eidos bridge WIP. Current product
  recovery is closed by
  `docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md`; keep the stash
  only as a preservation reference.
- `stash@{6}` - preserve WIP before merge wave. Current product recovery is
  closed by `docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md` and
  `docs/audits/STASH6_NONCHAT_DONOR_CLOSEOUT_2026_05_26.md`; keep the stash
  only as a preservation reference.
- `stash@{17}` - parallel Landing Wave / Session Intelligence session. Current
  product recovery is closed by
  `docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md`; keep the stash
  only as a historical landing/session UI donor reference.
- `stash@{16}` - April 27 editor/vendor donor. Honest-handle, approval queue,
  and remaining editor/vendor material are closed by
  `docs/audits/CLAUDE_SHADOW_HANDLE_CLOSEOUT_2026_05_26.md`,
  `docs/audits/STASH16_APPROVAL_UI_DONOR_CLOSEOUT_2026_05_26.md`, and
  `docs/audits/STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md`; keep the stash
  only as a historical editor/approval/shadow donor reference.
- `stash@{19}` - old code-editor invisible-text fix. Current product recovery
  is closed by `docs/audits/STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md`;
  keep the stash only as a historical editor donor reference.

## Stash Inventory

### `stash@{0}` - B-prime uncommitted follow-up

Message: `On master: b-prime-uncommitted-followup-2026-05-26`

Classification: closed for current product recovery; keep as preservation
reference until the user approves retiring old recovery refs.

Already mostly represented on main, but still has 27 tracked files that differ
and 1 missing untracked file. Do not bulk apply because it also contains old
Mermaid active-path deletions that were intentionally resolved by `#86`.

Closeout:

- HTML Workspace source guard follow-up recovered in
  `docs/audits/B_PRIME_HTML_WORKSPACE_SOURCE_GUARD_2026_05_26.md`.
- Legacy diagram compatibility recovered in
  `docs/audits/B_PRIME_LEGACY_DIAGRAM_COMPATIBILITY_2026_05_26.md`. The editor
  now preserves old `mermaid` schema blocks as inert source while keeping new
  visual creation on native HTML Workspace.
- UAS/ACS artifact gates recovered in
  `docs/audits/B_PRIME_UAS_ACS_ARTIFACT_GATES_2026_05_26.md`. The row now reads
  `F-UAS-CopyCount` and `F-ACS-AnchorLookup` result artifacts while keeping the
  production MAS adapter non-green.
- Settings health-row follow-up recovered/superseded in
  `docs/audits/B_PRIME_SETTINGS_HEALTH_SUPERSESSION_2026_05_26.md`. The durable
  missing metric was the AnswerPacket `claimKindCounts` histogram; stale
  tint-only chip rewrites were retired.
- Production VaultRecall search traces and Eidos search-index mirroring are on
  current `main`, with coverage in `VaultRecallWiringTests` and
  `EidosBridgeProductionTests`.
- Local-agent tool repair has no remaining filtered delta against current
  `main` for the detector, local loop, parser, bridge, or related tests.
- T25 doctrine lint is already on `main` in
  `agent_core/src/bin/epistemos_doctrine_lint.rs`.
- Full closeout:
  `docs/audits/B_PRIME_FOLLOWUP_CLOSEOUT_2026_05_26.md`.

Superseded or dangerous:

- Mermaid active-path files were removed by `#86` to preserve graph/editor
  performance. Do not restore Mermaid as a live route without a new performance
  gate.
- The draft PR `#82` must not be raw-merged. Its tree is stale and would delete
  newer HTML Workspace guards, the recovered legacy diagram compatibility path,
  current Living Index/no-compromise docs, and current ambient playback state.

### `stash@{1}` - D-prime build churn

Message:
`On phase2-terminal-d-prime-health-rows-2026-05-24: preserve syntax-core target build churn before D-prime rebase`

Classification: generated build churn only. No product recovery needed.

### `stash@{2}` - Terminal E rev-2 docs before fresh main

Message:
`On phase2-terminal-e-acs-gate-2026-05-24: terminal-e-rev2-docs-before-fresh-main-2026-05-24`

Classification: mostly merged. One missing doc may be useful:

- `docs/audits/BLOCKER_ACS_ADMISSION_XCODE_VERIFICATION_2026_05_24.md`

Recover only if the blocker history is still useful for architecture trace.

### `stash@{3}` - auto-pre-pull after PR #72

Message: `On master: auto-pre-pull-after-72-merge`

Classification: closed for current product recovery; keep as a preservation
reference. The useful resumed-verification facts were promoted into
`docs/audits/VAULT_RECALL_VISIBILITY_2026_05_24.md`,
`docs/audits/VAULT_RECALL_VISIBILITY_BLOCKER_2026_05_24.md`, and
`docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md`.

Differs from main:

- `Epistemos/Eidos/EidosBridge.swift`
- `docs/audits/VAULT_RECALL_VISIBILITY_2026_05_24.md`
- `docs/audits/VAULT_RECALL_VISIBILITY_BLOCKER_2026_05_24.md`

### `stash@{4}` - Terminal E pre-rebase

Message:
`On phase2-terminal-e-acs-gate-2026-05-24: wip-pre-rebase-2026-05-24`

Classification: generated/no actionable product diff found in filtered audit.

### `stash@{5}` - Terminal E pre-main rev2

Message:
`On phase2-terminal-e-acs-gate-2026-05-24: terminal-e-pre-main-2026-05-24-rev2`

Classification: likely mostly superseded by PR `#72`, but contains ACS docs and
tests that need comparison before retirement.

Differs from main:

- `Epistemos/Views/Settings/ACSAdmissionHealthRow.swift`
- `EpistemosTests/CloudKnowledgeDistillationTests.swift`
- `EpistemosTests/SearchFusionHealthRowTests.swift`
- `agent_core/src/agent_runtime_v2/mission_run.rs`
- `agent_core/src/agent_runtime_v2/mod.rs`
- `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`
- untracked docs:
  `ACS_ADMISSION_PRODUCTION_GATE_2026_05_24.md`,
  `DECISION_NEEDED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`

### `stash@{6}` - preserve WIP before merge wave

Message: `On master: preserve-wip-before-merge-wave-2026-05-24`

Classification: closed for current product recovery; keep as preservation
reference.

Current closeout:

- The chat/VaultRecall/Eidos visibility slice is closed by
  `docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md`. Do not replay
  the stale chat/code diffs from this stash onto current `main`; current product
  code already has the provenance cards, trace sink, EventStore event,
  `VaultRecallWiringTests`, and Eidos bridge production tests.
- The remaining non-chat docs/lattice slice is closed by
  `docs/audits/STASH6_NONCHAT_DONOR_CLOSEOUT_2026_05_26.md`. The durable deck
  and research-index addenda were ported; the lattice-coordinate explainer on
  current `main` is newer than the stash donor and was not downgraded.

Differs from main:

- Chat and provenance:
  `ChatCoordinator`, `AnswerPacket`, `ChatTypes`, `SDMessage`, `ChatState`,
  `EventStore`, `VaultRecallWiring`, `ChatInputBar`, `MessageBubble`,
  `NotesMentionDropdown`, `VRMLabelView`, `ShadowPanelContent`,
  `MiniChatView`, `NoteChatSidebar`.
- UI/docs:
  `LandingView`, `artifacts/lattice-coordinate-explainer/index.html`,
  `LEGENDARY_CODEWORD_2026_05_23.md`,
  `PHASE_2_TERMINAL_PROMPTS_2026_05_23.md`,
  `MASTER_RESEARCH_INDEX_2026_05_02.md`.
- CI/test:
  `.github/workflows/ci.yml`,
  `SearchFusionHealthRowTests`, `VaultRecallWiringTests`.

### `stash@{7}` - auto-stash for fast-forward pull

Message: `On master: auto-stash for ff pull 160254`

Classification: real UI/settings/ambient/voice nuance; recover after larger
UI slices.

Recovered slice:

- Voice input button service bridge recovered in
  `docs/audits/STASH7_VOICE_INPUT_SERVICE_RECOVERY_2026_05_26.md`. The button
  now uses `ComposerVoiceInputService` instead of directly owning the older live
  `EpistemosSpeechAnalyzer` stream.

Superseded slice:

- Remaining ambient/settings/app-shell deltas reviewed in
  `docs/audits/STASH7_AMBIENT_SETTINGS_SUPERSESSION_2026_05_26.md`. Current
  `main` already carries the newer compact ambient flow, persistent live player,
  richer mixer/music controls, and verified-floor health rows. Do not raw-apply
  this stash over those surfaces.

Differs from main include:

- App shell and bootstrap: `AppBootstrap`, `RootView`, `ChatCoordinator`.
- Ambient: `AmbientFrequencyLivePlayer`, `AmbientFrequencySettingsView`,
  `AmbientFrequencyAudioGeneratorTests`.
- Settings health rows and diagnostics.
- Voice input: `VoiceInputButton`, `VoiceInputPermissionTests`.
- Search: `SearchIndexService`.

### `stash@{8}` - T12 F-ULP oracle

Message:
`WIP on codex/t12-f-ulp-oracle-2026-05-18: a279fe2a38 test(t12): reject missing raw worst case`

Classification: research/substrate nuance.

Differs:

- `agent_core/src/research/eml_ir/witness.rs`

Recover after floor-visible UI work.

### `stash@{9}` - T11 agent runtime v2 handoff

Message:
`On codex/t11-agent-runtime-v2-2026-05-18: PRE-CURSOR-HANDOFF-1779175040`

Classification: small agent-runtime nuance.

Differs:

- `agent_core/src/agent_runtime_v2/capability.rs`

### `stash@{10}` and `stash@{11}` - removed old terminal branches

Messages:

- `PRE-REMOVAL-STASH-t2-agent-20260518-224503`
- `PRE-REMOVAL-STASH-t1-trifusion-20260518-224439`

Classification: no filtered actionable product diff found.

### `stash@{12}` - run-b post-v1 research

Message: `On run-b-post-v1-research: PRE-REMOVAL-STASH-runB-20260518-224424`

Classification: already represented on main in filtered audit.

### `stash@{13}` - multi-terminal recovery

Message:
`On master: wip-multi-terminal-recovery-2026-05-18: lib.rs + acs_admission/ + docs/falsifiers/`

Classification: substrate/ACS nuance.

Differs or missing:

- `agent_core/src/lib.rs`
- `agent_core/src/acs_admission/mod.rs`
- `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md`

### `stash@{14}` - T17B lattice format

Message: `On master: codex-preserve-t17b-lattice-format-before-t12`

Classification: WBO/lattice nuance.

Differs:

- `agent_core/src/lattice_wbo/mod.rs`

### `stash@{15}` - graph filters selected expansion

Message: `On master: wip-codex-graph-filters-selected-expansion`

Classification: closed for current product graph recovery; keep as a preserved
historical graph/performance donor reference. Do not bulk apply because `#86`
intentionally restored snappy physics defaults.

Recovered slice:

- Selected-neighbor expansion recovered in
  `docs/audits/STASH15_SELECTED_NEIGHBOR_EXPANSION_2026_05_26.md`. Filter UI
  was already present on current `main`; only the Rust selected-neighborhood
  rest-distance behavior was ported, with a three-pass graph physics audit.
- Closeout recorded in
  `docs/audits/STASH15_GRAPH_CLOSEOUT_2026_05_26.md`. The remaining raw stash
  tree is stale and would remove newer graph-engine tests/modules if applied
  wholesale.

Differs:

- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Views/Graph/GraphForceSettings.swift`
- `EpistemosTests/FilterEngineTests.swift`
- `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- `graph-engine/src/engine.rs`
- `graph-engine/src/forces.rs`
- `graph-engine/src/simulation.rs`

### `stash@{16}` - April 27 session stash

Message:
`On master: session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user`

Classification: closed for current product recovery; keep as a historical
editor/approval/shadow donor reference.

Recovered / superseded slice:

- Claude shadow-handle preservation is closed in
  `docs/audits/CLAUDE_SHADOW_HANDLE_CLOSEOUT_2026_05_26.md`. Current main
  already has the newer `RustShadowFFIClient` honest-handle consumer,
  `epistemos-shadow/src/honest_handle.rs`, and `ShadowHonestHandleSourceGuardTests`.
- Approval UI donor behavior is closed in
  `docs/audits/STASH16_APPROVAL_UI_DONOR_CLOSEOUT_2026_05_26.md`. Current main
  now keeps the fused SwiftUI approval sheet while porting per-session args
  dedup and `<session>/approvals.jsonl` audit rows.
- Remaining editor/vendor donor material is closed in
  `docs/audits/STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md`. Current main
  keeps the compressed editor bundle, KaTeX `.woff2` assets, Xcode-style color
  tokens, and `CodeEditSourceEditor` path. Do not raw-restore uncompressed
  editor bundle files or `vendor/mermaid/mermaid.min.js`.

Tracked differs:

- `AppBootstrap`, `ChatCoordinator`, `EpistemosApp`,
  `RustShadowFFIClient`, `ApprovalModalView`, `agent_core/Cargo.lock`,
  `CRITIQUE_LOG.md`, `epistemos-shadow/src/honest_handle.rs`.

Missing untracked includes:

- `Epistemos/State/ChatApprovalQueue.swift`
- uncompressed editor assets and vendor files
- `Epistemos/Resources/Editor/editor.html` differs

Do not revive Mermaid/vendor/editor assets without a new source guard and
performance gate. Current product recovery is closed.

### `stash@{17}` - parallel landing wave session

Message: `On master: codex-wip-parallel-during-landing-wave-session`

Classification: closed for current product UI recovery; keep as a historical
landing/session UI donor reference.

Closeout:

- `docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md` records that the
  Landing Wave and Session Intelligence files are already present on current
  `main`, and that the remaining raw stash tree would downgrade newer fused
  landing/chat/ambient surfaces if applied wholesale.

Differs:

- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme`
- `Epistemos/Engine/NoteInsightService.swift`
- `Epistemos/Vault/LiveNoteScanner.swift`
- `Epistemos/Views/Graph/NodeInspectorState.swift`
- `Epistemos/Views/Graph/PinnedInspector.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/Views/Notes/NoteBacklinksPanel.swift`
- tests: `NonAgentPruningValidationTests`,
  `PhaseR5ChatGrantWiringTests`, `RuntimeValidationTests`.

Missing files:

- `Epistemos/Views/Landing/Wave/LandingWaveDesign.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveSearchBar.swift`

### `stash@{18}` - large old main WIP

Message: `WIP on main: 31214a4d Update progress and mark three runtime issues as patched`

Classification: very important, very large. Split into multiple branches.

Recovered slice:

- Agent Command Center donor UX archived in
  `docs/audits/STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md`
  and guarded by
  `EpistemosTests/Stash18AgentCommandCenterDonorSynthesisTests.swift`
  via PR #91. The legacy `Epistemos/Views/AgentCommandCenter/*` files remain
  intentionally absent from live source.

Likely recovery slices:

1. Landing/session UI:
   `LandingView`, `SessionIntelligenceOverlay`.
2. Editor/note UX:
   `CodeEditorView`, `MarkdownContentStorage`, `ProseEditorView`,
   `AIPartnerInlineView`, `AIPartnerService`, `NotesSidebar`,
   `NoteDetailWorkspaceView`, `NoteWindowManager`.
3. Graph/performance:
   `GraphState`, `MetalGraphView`, `HologramOverlay`,
   `graph-engine/src/engine.rs`, `graph-engine/src/simulation.rs`.
4. Chat/runtime:
   `ChatCoordinator`, `AgentChatState`, `InferenceState`,
   `ArtifactBlockView`, `ContextWindowIndicator`, `MessageBubble`,
   `TaggedMarkdownTextView`.
5. Theme:
   `EpistemosTheme`, `EpistemosFont`, `PhysicsModifiers`.

Do not apply this stash whole. It spans too many ownership boundaries and old
project metadata.

### `stash@{19}` - old code editor invisible-text fix

Message:
`WIP on main: 29c0ca83 Fix: Invisible text in code editor — isRichText must be true`

Classification: closed for current product recovery; keep as a historical code
editor donor reference.

Current audit:

- The Xcode color palette and `xcodeColors` mapping from this stash are already
  present on main.
- The remaining old `CodeEditorView` patch contains a temporary "MINIMAL TEST"
  rewrite that removes the old gutter/minimap shell. It should not be applied
  wholesale.
- Current main still has two `NSTextView` inspector paths with
  `isRichText = false`; recover only if a focused test proves attributes are
  lost or text can become invisible in those paths.
- Closeout:
  `docs/audits/STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md` records why the
  old "MINIMAL TEST" `CodeEditorView` rewrite was not restored and why the
  remaining `isRichText = false` sites are graph-inspector helper views, not
  the live `CodeEditSourceEditor` canvas.

## Closure Rule

A stash row can be closed only by one of:

- A merged PR that names the stash row and paths recovered.
- A merged PR that adds a retirement note proving the stash is generated noise
  or already fully represented on main.
- An explicit user request to drop the stash after the recovery tag/branch is
  pushed.
