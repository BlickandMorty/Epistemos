# Main Architecture Recovery Status - 2026-05-26

Status: checkpoint audit after PRs `#83`-`#88`, with a later wording-only
Living Index refresh.

Purpose: separate what is actually on `main` from work that is merely preserved
in stashes, draft PRs, old worktrees, or deferred architecture ledgers. This is
the working split for "make main have all the things" without raw-merging stale
branches that would delete current app code.

## Hard Rule

Do not treat a stash or old worktree as complete just because it exists. Do not
treat it as junk just because it is old. Every item below has one of four
states:

- **Merged** - already on `main`.
- **Recovery slice** - valuable work exists, but must be re-promoted in focused
  PRs from current `origin/main`.
- **Deferred architecture** - intentionally not built yet; has a codeword or
  build window.
- **Donor only / dangerous raw merge** - useful ideas may exist, but the branch
  tree is stale and would remove current main if merged directly.

## Current Main

At audit creation, `main` and `origin/main` were aligned at:

```text
a4ea05424f docs(recovery): split finished main from preserved architecture work (#88)
```

Use `git log -1 --oneline` for the exact current commit if later docs-only
checkpoint refreshes have landed.

Recent recovery/checkpoint PRs now on main:

| PR | Status | What landed |
|---|---|---|
| `#83` | Merged | Preserved local UI work, including HTML Workspace direction and related UI/UX restoration. |
| `#84` | Merged | Restored source-guard and verified-floor audit tests. |
| `#85` | Merged | Restored preserved audit documents. |
| `#86` | Merged | Restored snappy graph/editor defaults and HTML Workspace route; removed stale Mermaid active route. |
| `#87` | Merged | Added this recovery ledger lineage and restored additive Landing Wave + Session Intelligence files from `stash@{17}`. |
| `#88` | Merged | Split finished main work from preserved stash/worktree/deferred architecture work and refreshed the Living Index pointer. |

Earlier Phase-2 floor PRs already on main:

| Range | Status |
|---|---|
| `#66`-`#72` | Eidos real bridge, System G path, falsifiers, docs/canon fill, T14 UAS bridge, ACS gate. |
| `#74`-`#79` | Falsifier round 2, Hyperdynamic Loop, Runtime Router, D-prime health rows, T0 verified floor, B-prime chat provenance. |
| Direct hotfix | `77c7efe9ea` repaired the Wave-2 main build gate after `#76`. |

## Open PRs

There are two open PRs, both **draft preservation references**, not merge-ready
feature PRs:

| PR | Branch | State | Meaning |
|---|---|---|---|
| `#81` | `codex/recovery-claude-shadow-handle-2026-05-26` | Draft | Preserves Claude shadow-handle WIP. Raw tree is stale and huge; re-promote focused hunks only. |
| `#82` | `codex/recovery-b-prime-uncommitted-followup-2026-05-26` | Draft | Preserves B-prime follow-up stash. Do not merge raw; it would delete current HTML Workspace/Landing Wave files. |

## Finished / On Main

These are finished enough to count as present on main:

- Verified Floor / Settings Truth: merged in `#78`.
- Runtime Router: merged in `#76` plus build hotfix; MLX is represented as one
  lane, not the architecture.
- Hyperdynamic Schema Loop primitive: merged in `#75`.
- Chat citation/provenance UI: merged in `#79`.
- Substrate Health panel expansion: merged in `#77`.
- Falsifier Round 2: merged in `#74`.
- Eidos real vault bridge and citation gate: merged in `#66`.
- System G run seam/path: merged in `#67`.
- ACS production gate and SCOPERexAdmissionProof: merged in `#72`.
- T14 UAS five-plane bridge and anchor lookup/copy-count witnesses: merged in
  `#71`.
- HTML Workspace direction and UI repromotion: merged through `#83` and guarded
  by `#86`.
- Landing Wave source files and Session Intelligence source: restored in `#87`.
- Snappy graph defaults: restored in `#86`.

## Not Finished But Preserved

These are the highest-value remaining recovery surfaces. They are not done just
because they are stashed or branched.

### 1. B-prime Follow-up (`stash@{0}`, PR `#82`)

State: **Closed for current product recovery.**

Durable references:

- Stash: `stash@{0}` / tag `recovery/stash-b-prime-uncommitted-followup-2026-05-26`
- Draft PR: `#82`
- Plan: `docs/audits/B_PRIME_FOLLOWUP_REPROMOTION_PLAN_2026_05_26.md`
- Closeout: `docs/audits/B_PRIME_FOLLOWUP_CLOSEOUT_2026_05_26.md`

Recovered / superseded slices:

1. HTML Workspace source guard follow-up is archived in
   `docs/audits/B_PRIME_HTML_WORKSPACE_SOURCE_GUARD_2026_05_26.md` and
   guarded by `EpistemosTests/HTMLWorkspaceSourceGuardTests.swift`.
2. UAS/ACS artifact gate follow-up is archived in
   `docs/audits/B_PRIME_UAS_ACS_ARTIFACT_GATES_2026_05_26.md` and guarded by
   `EpistemosTests/SubstrateHealthPanelTests.swift`.
3. Legacy diagram compatibility is archived in
   `docs/audits/B_PRIME_LEGACY_DIAGRAM_COMPATIBILITY_2026_05_26.md`. Old Epdoc
   `mermaid` schema blocks now load as inert source, while active visual
   creation remains routed to HTML Workspace.
4. Settings health-row follow-up is archived in
   `docs/audits/B_PRIME_SETTINGS_HEALTH_SUPERSESSION_2026_05_26.md`. The
   AnswerPacket row now exposes claim-kind histogram data; stale tint-only chip
   rewrites were retired.
5. Production VaultRecall traces and Eidos search-index mirroring are live in
   `SearchIndexService` / `VaultSyncService`, with coverage in
   `VaultRecallWiringTests` and `EidosBridgeProductionTests`.
6. Local-agent tool repair has no remaining filtered delta against current
   `main`.
7. T25 doctrine lint and the Living Index/no-compromise docs are already newer
   on current `main`.
8. Ambient/audio/settings donor deltas are superseded by current main; the
   stash would delete `AmbientFrequencyPlaybackState`.

Do not raw-merge `#82`; the branch tree is stale relative to main and shows
deletions of current main files such as HTML Workspace, Runtime Router, Landing
Wave, and Ambient Frequency state.

### 2. Large Old Main WIP (`stash@{18}`)

State: **Partially recovered.**

This stash is likely the source of many "UI I remember having" concerns.

Recovered slice:

1. Agent Command Center UX donor synthesis landed via PR #91. It archives the
   donor behavior in
   `docs/audits/STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md`
   and guards that the old live `AgentCommandCenter` shell stays deleted.

Remaining candidate slices:

1. Landing/session UI refinements.
2. Editor/note UX refinements.
3. Chat/runtime presentation.
4. Graph/performance changes.
5. Theme/font/physics nuance.

Important: the old `Epistemos/Views/AgentCommandCenter/*` files are not
merge-ready. Current tests explicitly assert that the legacy Agent Command
Center view files stay removed after fusion, because the app now routes mode
selection through the fused chat/landing composer. Recover ideas and UX patterns
from these files; do not restore the old shell raw.

### 3. Chat/VaultRecall WIP (`stash@{6}` and `stash@{3}`)

State: **Recovery slice required.**

`#79` landed chat citation/provenance rows, but these stashes still contain
additional chat/VaultRecall/Eidos bridge/doc nuance. Re-promote only after
diffing against current `ChatCoordinator`, `VaultRecallWiring`,
`MessageBubble`, `ChatInputBar`, `VRMLabelView`, and
`ShadowPanelContent`.

### 4. Settings/Ambient/Voice/App Shell (`stash@{7}`)

State: **Closed for product recovery.**

Initial audit showed possible visible polish for:

- Ambient Frequency playback/settings.
- Voice input permissions.
- Settings health row nuance.
- Root/AppBootstrap shell behavior.

Do not merge as one PR because it crosses runtime, settings, audio, and voice.

Recovered slice:

1. Voice input button service bridge is archived in
   `docs/audits/STASH7_VOICE_INPUT_SERVICE_RECOVERY_2026_05_26.md` and guarded
   by `EpistemosTests/VoiceInputPermissionTests.swift`.

Superseded slice:

1. Remaining ambient/settings/app-shell deltas are retired by
   `docs/audits/STASH7_AMBIENT_SETTINGS_SUPERSESSION_2026_05_26.md`. Current
   `main` already has the newer compact ambient flow, persistent live player,
   richer mixer/music controls, and verified-floor health rows. Raw recovery
   would delete those newer surfaces.

### 5. Graph Filter / Physics WIP (`stash@{15}`)

State: **Closed for product recovery, performance gated.**

This one must be handled carefully because `#86` intentionally restored snappy
graph defaults. Only recover pieces that preserve:

- Gravity Well default `linkDistance = 500`.
- `centerStrength = 0`.
- Fluid field off by default.
- No per-frame allocations or unbounded inspection work.
- Existing graph performance tests passing.

Recovered slice:

1. Selected-neighbor expansion is archived in
   `docs/audits/STASH15_SELECTED_NEIGHBOR_EXPANSION_2026_05_26.md`. The Swift
   filter UI portion was already present on `main`; the recovered Rust slice
   only changes direct selected-neighborhood link rest distance while keeping
   normal no-selection link physics on the original hot path.

### 6. Claude Shadow Handle (`#81`, `stash@{16}` overlap)

State: **Draft preservation / donor recovery.**

Useful targets:

- `RustShadowFFIClient` honest-handle migration.
- `epistemos-shadow/src/honest_handle.rs`.
- `ChatApprovalQueue` / approval modal ideas.

Do not raw-merge `#81`; the branch tree is stale and would delete many current
main files. Extract one small Rust/Swift FFI slice at a time.

## Donor Branches / Worktrees

These worktrees are not clean merge sources. They are donor archives whose
valuable pieces must be re-promoted from current `origin/main`.

| Worktree / Branch | Classification | Why not raw-merge |
|---|---|---|
| `codex/t2-agent-2026-05-16` | Donor / partially salvaged | Huge stale tree diff; contains local-agent/AnswerPacket/route-profile ideas, but would delete many current files. |
| `codex/t4-vault-2026-05-16` | Donor / partially salvaged | VaultRecall commits exist; current main already has newer Eidos/VaultRecall paths. Recover only still-novel trace/scoring pieces. |
| `codex/t5-emlir-2026-05-16` | Donor / partially salvaged | Several T5 IR PRs landed, but the donor branch has more research/Lean material. Continue via docs/deferred Lean/IR tracks. |
| `codex/t6-uiux-2026-05-16` | Donor / deferred UI polish | D-01 tracks this. Recover UX polish in focused UI sessions. |
| `worktree-simulation` | Donor / deferred ceiling | Simulation/Farm work partially landed, but raw tree deletes current app files. Continue via D-11. |
| `claude/vigorous-goldberg-3a2d35` | Donor / Quick Capture canon | Pro-tool and Quick Capture substrate work is deferred under D-12 and related codewords. |

## Stashes That Look Mostly Closed

These should still not be dropped without explicit approval, but current filtered
audit found no urgent product recovery:

| Stash | State |
|---|---|
| `stash@{1}` | Generated target/build churn only. |
| `stash@{4}` | Generated/pre-rebase noise. |
| `stash@{10}` | No filtered actionable product diff. |
| `stash@{11}` | No filtered actionable product diff. |
| `stash@{12}` | Already represented on main in filtered audit. |

## Deferred Architecture, Not Missing Work

These are not "lost"; they are explicitly deferred and must be built later from
the anti-loss ledger:

- D-03: XPC Mastery five-service decomposition (`RESUME XPC MASTERY`).
- D-05: Variant Ladder Generalization (`RESUME T20`).
- D-06: L_SE Self-Evolving Adapter Lane (`RESUME L_SE RESEARCH`).
- D-08: five V6.1 Metal kernels.
- D-09: F-70B Local Cocktail (`RESUME F-70B`).
- D-10: Lean proofs (`RESUME LEAN PROOFS`).
- D-11: Simulation Mode v1.7+.
- D-12: Quick Capture Pro tools (`RESUME PRO TOOLS`).
- D-13: NightBrain V1.x.
- D-15 through D-26: Eidos Form Layer, Executor Trait, Live File Compiler,
  Cognitive Weight enforcement, Residency Governor, Halo/Eidos Control Vectors,
  Lean ClaimLedger Authority, and remaining W-row closures.

Source of truth: `docs/DEFERRED_WORK_GUARANTEE_2026_05_23.md`.

## Architecture Still Unfinished

The floor is much stronger than it was, but the no-compromise architecture is
not fully closed. The next implementation waves are:

### Wave 3 - Agent Path Closure

- AgentBlueprint end-to-end replay UI.
- Deterministic RunEventLog replay into visible AnswerPacket output.
- Per-model agent metadata badges: `HONEST`, `EXPERIMENTAL`, `OFF`.
- System G timeline replay surface.

### Wave 4 - UAS / ClaimLedger / Graph Closure

- `hybrid_search` returns typed `Vec<UasAddress>`.
- `UasKind` appears on agent traces.
- `AcsAnchor` lands in ClaimLedger.
- `page_gather` escalates through vault retrieval.
- Vault Context Contract CI gate remains enforced.
- Cognitive DAG visualizer.
- Tri-Fusion typed mutations in `agent_runtime`.

### Recovery Wave - Local UI/UX Nuance

- Re-promote B-prime follow-up groups from `stash@{0}`.
- Continue mining `stash@{18}` for non-shell UI refinements now that the Agent
  Command Center donor synthesis is archived via PR #91.
- Recover graph-filter ideas from `stash@{15}` only if they pass performance
  gates.
- Recover T6 UI/UX polish from the donor branch under D-01.

## Recommended Next Execution Order

1. **B-prime follow-up slice 1:** HTML Workspace/source-vs-bundle cleanup and
   any missing UI controls, from `stash@{0}` / `#82`.
2. **B-prime follow-up slice 2:** Settings truth/health-row nuance from
   `stash@{0}`.
3. **Old main UI synthesis:** mine the remaining `stash@{18}` slices for
   landing, editor, chat/runtime, graph, and theme nuance.
4. **Graph WIP audit:** mine `stash@{15}` with a graph performance test gate.
5. **VaultRecall/Eidos visibility:** mine `stash@{3}` and `stash@{6}` after the
   current provenance path is stable.
6. **Shadow handle FFI:** split `#81` into one honest-handle FFI PR.
7. **Wave 3 architecture:** AgentBlueprint replay UI + model metadata badges.

## Operational Instruction For Agents

When recovering work:

```text
1. Start from current origin/main.
2. Read this file and STASH_RECOVERY_LEDGER_2026_05_26.md.
3. Pick exactly one recovery slice.
4. Extract a patch with git diff stash/recovery-tag, not git checkout.
5. Apply with git apply --3way.
6. Remove generated noise and stale deletes.
7. Build/test.
8. Open a small PR that names the source stash/branch and what was intentionally not recovered.
```

Anything else risks repeating the original failure mode: work preserved but not
integrated, or worse, raw-merged and deleting newer main.
