---
state: auxiliary-branch-salvage-ledger
created_on: 2026-05-23
worktree: /Users/jojo/Downloads/Epistemos-wrv-salvage
main_head: 24b5052cf2
decision: audit-only-no-code-mined
---

# Auxiliary Branch Salvage Ledger - 2026-05-23

## Scope

This ledger audits non-T donor branches for pure-additive salvage value.
It excludes current `salvage/*`, `mine/*`, `wiring/*`, and active
T-track branches as mining sources. Those are output branches or
separate T-track work, not auxiliary donors.

Audit method:

```bash
base=$(git merge-base origin/main "$branch")
git diff --name-status "$base..$branch" | awk '$1=="A"{print $2}'
# then filter out paths already present on origin/main
git cat-file -e "origin/main:$path"
```

## Summary

| Branch | Head | Pure-additive files absent on main | Classification | Action |
|---|---:|---:|---|---|
| `worktree-simulation` | `3163b170d0` | 121 | mine | Mine only AgentEvent/normalizer/applier guard if later proven pure and compiling. Archive visual surface. |
| `claude/vigorous-goldberg-3a2d35` | `0e0234d9f1` | 89 | mine-gated | Do not mine route/heal/effect/undo/nightbrain. Revisit only `workspace/` after System G/T11 path is stable. |
| `worktree-agent-a0550f9c` | `6cd4748119` | 0 | archive-candidate | Inspect only under M5. Do not remove worktree without user approval. |
| `claude/serene-wright` | `2283240e40` | 0 | archive | Ancestor of current main. |
| `codex/research-snapshot-2026-05-08` | `dcf8825a10` | 0 | archive | Added docs already exist on main. |
| `codex/post-audit-feature-work` | `0909c591ba` | 0 | archive | Ancestor of current main. |
| `codex/release-stabilization-and-runtime-hardening` | `e5d0114ae4` | 0 | archive | Ancestor of current main. |
| `codex/runtime-input-audit` | `70c98ea24f` | 0 | archive | Ancestor of current main. |
| `codex/runtime-memory-hardening` | `6c8a070ce4` | 0 | archive | Ancestor of current main. |
| `feature/knowledge-fusion-v1` | `e593a7896e` | 0 | archive | Ancestor of current main. |
| `feature/landing-liquid-wave` | `bf35bdacc9` | 0 | archive | Ancestor of current main. |
| `lane-A` | `12183f29a7` | 0 | archive | Ancestor of current main. |
| `run-b-post-v1-research` | `28385bdea0` | 0 | archive | Ancestor of current main. |
| `run-c-audit` | `8085deafd4` | 0 | archive | Ancestor of current main. |
| `run-d-providers` | `9c83757d89` | 0 | archive | Ancestor of current main. |
| `run-e-decisions` | `6bbb475c49` | 0 | archive | Ancestor of current main. |
| `run-f-integrations` | `4726720fd1` | 0 | archive | Ancestor of current main. |
| `docs/may16-archeology-2026-05-23` | `589e79ed17` | 0 | archive | Already represented by current docs. |
| `docs/canon-chronicle-2026-05-23` | `24b5052cf2` | 0 | archive | Same commit as main. |

No auxiliary branch qualifies for immediate `salvage` in this M2 pass.
The only positive branches are `mine` candidates, and both fail the
"compile without dragging old architecture back in" bar today.

## Donor Details

### `worktree-simulation`

Classification: **mine**, not salvage.

Pure-additive groups absent on main:

| Group | Count |
|---|---:|
| `Epistemos/Hermes/*` | 5 |
| `Epistemos/Resources/CompanionAssets/*` | 25 |
| `Epistemos/Simulation/*` | 30 |
| `Tools/asset_pipeline/*` | 9 |
| `Tools/branding_pipeline/*` | 2 |
| `Tools/*` | 3 |
| `agent_core/benches/*` | 1 |
| `agent_core/src/*` | 6 |
| `agent_core/src/adapters/*` | 9 |
| `agent_core/src/audit/*` | 4 |
| `agent_core/src/companions/*` | 6 |
| `agent_core/src/ffi/*` | 3 |
| `agent_core/src/normalize/*` | 6 |
| `agent_core/src/simulation/*` | 4 |
| `docs/simulation-mode/*` | 8 |

Sampled substantial files:

| Path | Lines | Assessment |
|---|---:|---|
| `docs/simulation-mode/DOCTRINE.md` | 1982 | Real doctrine, but product-surface heavy and not current spine-critical code. |
| `agent_core/src/events.rs` | 713 | Real AgentEvent substrate. Imports companion types, so it is not a clean standalone drop-in. |
| `agent_core/src/normalize/hermes.rs` | 307 | Real normalizer pattern, but Hermes namespace is retired. Would require rename and provider-neutral extraction. |
| `agent_core/src/adapters/epbox.rs` | 556 | Real `.epbox` parser. Contains vault-root sandbox guard and tests; tied to companion gift-box domain. |
| `agent_core/src/adapters/applier/mod.rs` | 128 | Real applier trait and preflight checks; depends on companion registry. |
| `agent_core/src/audit/ledger.rs` | 740 | Real audit ledger, but coupled to simulation/companion event model. |
| `agent_core/src/companions/bridge.rs` | 1770 | Substantial bridge, but presentation-surface dominated. |
| `agent_core/src/simulation/reducer.rs` | 1058 | Real event-sourced reducer, but tangential until product surface is selected. |

Pure-additive file list:

```text
Epistemos/Hermes/{AsciiPortraitView.swift,HermesGoldHaloView.swift,HermesLandingPhases.swift,HermesLandingRitualView.swift,HermesSession.swift}
Epistemos/Resources/CompanionAssets/atlas/{block_compact.json,block_compact.png,block_compact.provenance.json,block_wide.json,block_wide.png,block_wide.provenance.json,hermes_snake.json,hermes_snake.png,hermes_snake.provenance.json,orb.json,orb.png,orb.provenance.json,sage.json,sage.png,sage.provenance.json}
Epistemos/Resources/CompanionAssets/effects/{eye_glow.png,halo_active.png,provenance.json}
Epistemos/Resources/CompanionAssets/palettes/{_index.json,claude_warm_v1.json,codex_neutral_v1.json,gpt_neutral_v1.json,hermes_gold_v1.json,kimi_indigo_v1.json,local_teal_v1.json}
Epistemos/Simulation/{AtlasLoader.swift,DeltaRingBridge.swift,MetalSimulationRenderer.swift,PaletteRegistry.swift,Perf.swift,PipelineArchive.swift}
Epistemos/Simulation/Bridges/{CompanionRegistryBridge.swift,SimulationBridge.swift}
Epistemos/Simulation/Creation/{CompanionCreationFlow.swift,CompanionPreviewView.swift,CreationStep.swift,PresetCatalog.swift}
Epistemos/Simulation/GiftBox/{MailroomView.swift,UnwrapAnimationView.swift,UnwrapAnimationViewModel.swift}
Epistemos/Simulation/Shaders/Companion.metal
Epistemos/Simulation/State/SidebarToggleState.swift
Epistemos/Simulation/Theme/{KnowledgeBrickStyle.swift,RoomTilingLayout.swift}
Epistemos/Simulation/ViewModels/{CreationFlowViewModel.swift,GraphTheaterViewModel.swift,LandingFarmViewModel.swift,MailroomViewModel.swift}
Epistemos/Simulation/Views/{CompanionsPickerView.swift,EntityVaultsView.swift,GraphTheaterView.swift,LandingFarmView.swift,SessionToggleChipRow.swift,SimulationSidebarView.swift,TheaterMTKView.swift}
Tools/{build_halo_textures.py,build_pipeline_archive.sh,perf_check.sh}
Tools/asset_pipeline/{__init__.py,_png.py,aseprite_refine.lua,atlas_pack.py,auto_slice.py,concept_gen.py,manifest_gen.py,procedural_atlas_v1.py,validate.py}
Tools/branding_pipeline/{fetch_hermes_canonical.py,fetch_lobe_icons.py}
agent_core/benches/reducer_bench.rs
agent_core/src/{digest.rs,event_log.rs,events.rs,hermes/mod.rs,perf.rs,replay.rs}
agent_core/src/adapters/{epbox.rs,mod.rs,tests.rs}
agent_core/src/adapters/applier/{accessory_unlock.rs,mod.rs,palette_unlock.rs,prop_unlock.rs,system_prompt_preset.rs,tool_affinity_bundle.rs}
agent_core/src/audit/{delta.rs,ledger.rs,mod.rs,origin.rs}
agent_core/src/companions/{activity.rs,audit.rs,bridge.rs,mod.rs,registry.rs,transaction.rs}
agent_core/src/ffi/{delta_ring.rs,mod.rs,per_instance.rs}
agent_core/src/normalize/{anthropic.rs,hermes.rs,kimi.rs,local_mlx.rs,mod.rs,openai.rs}
agent_core/src/simulation/{mod.rs,reducer.rs,sim.rs,state.rs}
docs/simulation-mode/{DOCTRINE.md,IMPLEMENTATION.md,SESSION_KICKOFF.md}
docs/simulation-mode/character-dna/{block_compact.md,block_wide.md,hermes_snake.md,orb.md,sage.md}
```

Donor-mining test:

| Question | Result |
|---|---|
| Unique vs main? | Yes. Main lacks these simulation, normalizer, applier, audit-ledger, and asset files. |
| Pure-additive? | File-additive, but not behavior-additive if wired. It would require new `lib.rs` exports and module ownership decisions. |
| Compiles without old architecture? | Not proven. `events.rs` imports companion types, `normalize/hermes.rs` revives Hermes naming, and appliers depend on companion registry. |
| Preserves current doctrine? | Partly. AgentEvent normalization and sandbox guard are spine-adjacent. Hermes/companion visuals are tangential and conflict with current product doctrine if revived wholesale. |
| Spine class | AgentEvent/applier guard are spine-adjacent; renderer/assets/Swift Simulation UI are tangential. |

M2 verdict: **status-only for now**. M3 may inspect only
AgentEvent normalizer and applier sandbox guard. If either needs broad
module exports, companion registry, Hermes revival, or Swift Simulation
surface wiring, write a status doc instead of mining.

### `claude/vigorous-goldberg-3a2d35`

Classification: **mine-gated**, not salvage.

Pure-additive groups absent on main:

| Group | Count |
|---|---:|
| `agent_core/src/tools/v2_catalog/*` | 74 |
| `agent_core/src/tools/*` | 6 |
| `agent_core/src/workspace/*` | 1 |
| `agent_core/src/bin/*` | 2 |
| `agent_core/src/eval/*` | 2 |
| `agent_core/eval/*` | 1 |
| `agent_core/src/format/*` | 1 |
| `agent_core/souls/*` | 2 |

Sampled substantial files:

| Path | Lines | Assessment |
|---|---:|---|
| `agent_core/src/workspace/mod.rs` | 525 | Self-contained Model Workspace Protocol primitives, but current main lacks `ulid` dependency and no production caller owns it yet. |
| `agent_core/src/tools/runner.rs` | 680 | Byte-identical to main's `agent_core/src/tools_v2/runner.rs`. Archive branch path. |
| `agent_core/src/tools/v2_catalog/mod.rs` | 622 | Byte-identical to main's `agent_core/src/tools_v2/v2_catalog/mod.rs`. Archive branch path. |
| `agent_core/src/tools/capture.rs` | 153 | Capture tool in old namespace. Needs typed-dispatch ownership decision before mining. |
| `agent_core/src/bin/heal_eval.rs` | 92 | Depends on diverged `heal`; blocked. |

Pure-additive file list:

```text
agent_core/eval/route_v1.jsonl
agent_core/souls/{diagnostician.soul.json,diagnostician.soul.md}
agent_core/src/bin/{heal_eval.rs,route_eval.rs}
agent_core/src/eval/{heal_recovery.rs,mod.rs}
agent_core/src/format/soul.rs
agent_core/src/tools/{breaker.rs,capture.rs,legacy_adapter.rs,mod.rs,reason_think.rs,runner.rs}
agent_core/src/tools/v2_catalog/{action_bash.rs,action_terminal.rs,apple_calendar.rs,apple_mail.rs,apple_notes.rs,apple_reminders.rs,browser_back.rs,browser_click.rs,browser_close.rs,browser_console.rs,browser_get_images.rs,browser_navigate.rs,browser_press.rs,browser_scroll.rs,browser_snapshot.rs,browser_type.rs,browser_vision.rs,capture_clipboard.rs,capture_screenshot.rs,capture_voice.rs,chunk_reduce.rs,clarify_ask.rs,communication_channel_contacts.rs,communication_imessage.rs,communication_imessage_contacts.rs,communication_send_message.rs,discovery_mcp_discover.rs,discovery_model_catalog.rs,file_patch.rs,file_read.rs,file_search.rs,file_write.rs,graph_neighbors.rs,graph_query.rs,graph_vault_navigate.rs,inference_constrained_generate.rs,inference_route_private.rs,inference_ssm_resume.rs,intelligence_inline_partner.rs,intelligence_mixture_of_minds.rs,intelligence_nightbrain_trigger.rs,intelligence_self_evolve.rs,knowledge_contradiction.rs,knowledge_neural_recall.rs,knowledge_recall.rs,knowledge_session_search.rs,macos_interact.rs,macos_perceive.rs,macos_screen_watch.rs,media_image_generate.rs,media_text_to_speech.rs,media_vision_analyze.rs,memory_curated.rs,mod.rs,skills_list.rs,skills_manage.rs,skills_view.rs,system_cron.rs,system_process.rs,system_todo.rs,trajectory_export.rs,vault_read.rs,vault_search.rs,vault_write.rs,web_crawl.rs,web_extract.rs,web_fetch.rs,web_search.rs,workspace_find_symbol.rs,workspace_get_change_impact.rs,workspace_get_dependencies.rs,workspace_get_dependents.rs,workspace_get_function_source.rs,workspace_search.rs}
agent_core/src/workspace/mod.rs
```

Donor-mining test:

| Question | Result |
|---|---|
| Unique vs main? | `workspace/mod.rs`, eval files, `capture.rs`, `format/soul.rs`, and souls are unique. The v2 catalog/runner/breaker/reason_think are already present on main under `agent_core/src/tools_v2/`. |
| Pure-additive? | File-additive, but not safe to wire. `workspace/mod.rs` requires a new `ulid` dependency and `lib.rs` export. Eval binaries depend on diverged route/heal. |
| Compiles without old architecture? | Not as a batch. Mining all files would reintroduce old `tools/` namespace, souls, route/heal evals, and gated Quick Capture architecture. |
| Preserves current doctrine? | Only if deferred. Current doctrine says do not mine route/heal/effect/undo/nightbrain until System G and typed dispatch are real. |
| Spine class | `workspace/mod.rs` is spine-adjacent; eval/souls are tangential or blocked; v2 tool files are already handled. |

M2 verdict: **no immediate salvage**. `workspace/mod.rs` remains the only
credible future mine target, and only after T11/System G typed-dispatch
ownership is stable. M4 should write a Quick Capture status doc rather
than mining gated route/heal/effect/undo/nightbrain work.

## Zero-Additive Branches

The following branches have zero pure-additive files absent from current
main.

```text
claude/serene-wright
worktree-agent-a0550f9c
codex/post-audit-feature-work
codex/release-stabilization-and-runtime-hardening
codex/runtime-input-audit
codex/runtime-memory-hardening
feature/knowledge-fusion-v1
feature/landing-liquid-wave
lane-A
run-b-post-v1-research
run-c-audit
run-d-providers
run-e-decisions
run-f-integrations
docs/may16-archeology-2026-05-23
docs/canon-chronicle-2026-05-23
```

`codex/research-snapshot-2026-05-08` has three commits ahead of main,
but its two added docs are already present on current main:

```text
docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md
docs/CODEX_HANDOFF_2026_05_16.md
```

## Hardening Notes

- No wholesale branch merge is justified by this audit.
- No auxiliary donor should touch broad existing files in this pass.
- Do not delete any worktree from this ledger without explicit user
  approval.
- `worktree-agent-a0550f9c` remains inspect-only for M5. Its branch is
  an ancestor of main, but its worktree has known dirty local files from
  the May-22 audit and must be diffed before any archive recommendation.
- The five redundant Claude session worktrees from the May-22 donor memo
  are not present as refs in this checkout. If they reappear, classify
  them as archive only after confirming their heads are ancestors of
  main.
- `worktree-simulation` and `claude/vigorous-goldberg-3a2d35` both have
  preservation tags or origin refs. Preserve them; mine only scoped,
  tested pieces.

## WRV Classification

| Candidate | WRV class | Why |
|---|---|---|
| Simulation AgentEvent/normalizer/applier guard | implemented-not-wired | Real code exists, but current main has no caller chain and compile impact is unknown. |
| Simulation renderer/assets/Swift UI | scaffold-only/tangential | Presentation surface without current product-surface decision. |
| Quick Capture `workspace/mod.rs` | implemented-not-wired/gated | Real code exists, but it needs dependency/export/caller ownership and T11/System G context. |
| Quick Capture `tools/v2_catalog` path | archive | Already on main under `tools_v2`. |
| Quick Capture route/heal evals and souls | blocked/archive | Depend on diverged old modules or Hermes-era patterns. |
| Zero-additive branches | archive | No unique additive files absent from main. |

## Verification Performed

```bash
git for-each-ref --format='%(refname:short) %(objectname:short) %(committerdate:short)' refs/heads refs/remotes/origin
git worktree list --porcelain
git merge-base origin/main <branch>
git diff --name-status <merge-base>..<branch>
git cat-file -e origin/main:<path>
git merge-base --is-ancestor <branch> origin/main
git show <branch>:<sample-path> | sed -n '1,220p'
git show <branch>:<sample-path> | wc -l
```

Decision verification for this doc:

```bash
test -f docs/AUXILIARY_BRANCH_SALVAGE_LEDGER_2026_05_23.md
rg 'worktree-simulation|claude/vigorous-goldberg-3a2d35|mine-gated|Zero-Additive Branches|WRV Classification' docs/AUXILIARY_BRANCH_SALVAGE_LEDGER_2026_05_23.md
LC_ALL=C rg --pcre2 '[^\x00-\x7F]' docs/AUXILIARY_BRANCH_SALVAGE_LEDGER_2026_05_23.md
```

## Final M2 Status

M2 is complete as an audit/decision unit.

Classification result:

- `worktree-simulation`: **mine**, but only narrow spine-adjacent pieces
  after M3 proves purity and compile path.
- `claude/vigorous-goldberg-3a2d35`: **mine-gated**, with no code mined
  until System G/T11 ownership is stable.
- All other audited auxiliary branches: **archive** or
  **archive-candidate**, with no deletion authorized.
