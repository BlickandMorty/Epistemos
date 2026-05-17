# T2 Gated After-Merge Tracker - 2026-05-17

Owner: T2, Model Gating Liberation + Local Agent Excellence.

Purpose: this file is the post-merge checklist for T2 work that was intentionally not fully built, live-smoked, or cross-terminal-integrated during the disk-constrained pass. It tracks the things that should be coded or verified after all terminal branches are merged.

## Landed On This Branch

| Area | Landed code | Commit range |
|---|---|---|
| AnswerPacket binding | Runtime chat/agent completions emit AnswerPackets; assistant messages can persist packet id, VRM label, and encoded packet body; SDMessage persistence guard added. | `bbbd2e388` plus prior V6.2 wiring |
| AgentBlueprint replay | Recent AgentBlueprint mission records resolve latest RunEventLog event snapshots and embed existing timeline replay. | `6a60081a8` |
| AgentBlueprint badges | Model choices expose `Agent OK`, `Experimental - soft guidance`, and `No agent grammar` badges. | `a766c5d48` |
| Settings model badges | Settings -> Inference local picker shows the same agent capability badge and separate power-user OOM badge. | `4077f1df2` |
| Active constellation row | Active constellation diagnostics show hot/warm/cold, strict/soft, grammar, and agent capability badge. | `460ed632e` |
| Mistral Small gate | Mistral Small is agent-capable, native-tool-capable, parsed locally, and routed for reasoning/synthesis/local research. | `8e9c7979f`, `dd41fe8a9`, `21bf77046`, `3cf3df766` |
| Route policy diagnostics | ConfidenceRouter exposes task-class route profiles and 30s/deep idle-unload contract to Settings diagnostics. | `b73bc32e9` |
| 36B opt-in | Picker selection writes the explicit LocalAgent 4.3 36B opt-in flag. | `d511f0fdd` |

## Still Gated Or Not Fully Built

| Gate | Current state | Not built / not proven | Next T2 action after merge | Cross-terminal dependency |
|---|---|---|---|---|
| Fully local Research Assistant acceptance | Structural pieces exist: AgentBlueprint, local-only mission contract, badges, local route table, AnswerPacket binding, run timeline view. | No end-to-end live smoke proving `vault.search -> note.create -> AnswerPacket -> replay` with zero cloud round trips. | Run one disk-safe live smoke after merge, then add a focused fixture or UI test around the final trace. | T4 prepared retrieval, T5 Info-IR confidence, T6 UI audit. |
| AnswerPacket completeness | Packet id, VRM label, attention mode, interrupt bucket, and encoded packet body persist with messages. | RunEventLog completion metadata still carries only packet summary fields, not full packet JSON. No long-scroll replay proof past live ring in app run. | Decide whether RunEventLog should store full packet JSON or only message persistence remains canonical. Then wire one path and guard it. | T1/T5 if ClaimGraph or confidence semantics become packet source of truth. |
| Per-model grammar strictness | LocalToolGrammar has native profiles and parser coverage for Qwen, Hermes-format parity, DeepSeek-Coder, Llama 3.3, Mistral Small, Phi-4, Phi-4-mini. | Strict masking is still a global import gate, not per-family runtime confidence. DeepSeek/Llama/Phi native parser fixtures need broader corpus coverage. | Add per-family grammar confidence counters and demotion rules: STRICT-CAPABLE, SOFT-GUIDED, OFF. | None, T2-owned. |
| Mistral Small | Agent gate and router enabled; named `[ARGS]` and JSON-array fixtures covered. | No live MLX run with installed Mistral Small on this machine in this pass. | Live-smoke one Mistral Small tool call after disk pressure clears; record result in grammar matrix. | None, T2-owned. |
| Devstral | Native-tool-capable badge shows experimental soft guidance, but `canActAsAgent` remains false. | Not promoted to local agent because no Devstral parser fixture or live proof. | Add Devstral-specific fixture before enabling. | None, T2-owned. |
| Gemma 3/4 | Honest OFF / no agent grammar in picker and constellation badges. | No new grammar work. | Only revisit if Gemma JSON function-call fixture passes without XML leakage. | None, T2-owned. |
| Idle unload | Diagnostics and route profiles expose `30s/deep` policy. | Actual model residency/unload enforcement is not proven by runtime instrumentation here. | Wire runtime unload telemetry or prove existing unload path observes this policy. | T6 may audit UI wording; engine owner may own residency internals. |
| Power-user 36B | Settings toggle exists; picker writes explicit 36B opt-in; OOM badge visible. | No live 16 GB/18 GB 36B run proof; no ternary/KV-Direct real memory reduction. | Keep as explicit experimental opt-in until runtime probe proves stable. | Kernel/model infra work outside T2 may be needed. |
| Run timeline replay | AgentRunTimelineView exists; AgentBlueprint recents resolve matching RunEventLog snapshots. | Replay is not yet a full export/import or deterministic re-execution system. | Add a replay verifier for AgentEvent ordering and visible UI reconstruction. | T1/T3 if events gain TriFusion/UAS payloads. |
| RL / LoRA / self-evolution | Not started in this pass. | Atropos trajectory collection, MLX-Swift LoRA, and skill discovery remain phase C. | Do not start until B1-B8 acceptance is live-smoked. | T7/T8 or future training terminal. |

## Cross-Terminal Conflict Guard

T2 should keep future writes inside:

- `agent_core/src/agent_runtime/`
- `agent_core/src/providers/`
- `Epistemos/LocalAgent/`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Views/Settings/*`
- `Epistemos/Bridge/StreamingDelegate.swift`
- `Epistemos/ViewModels/AgentViewModel.swift` if the file is added later
- T2 docs under `docs/audits/`, `docs/fusion/`, and `docs/agent-system/`

Do not take ownership of T1 `tri_fusion`, T3 `uas`, T4 `vault.rs`, T6 AmbientFrequency, T7 `research/eml`, or T8 biometric work. If T2 needs their payloads, add an adapter boundary or tracker row instead of editing their files.

## Merge Aftercare Checks

1. Search for stale T2 status claims after merge:

   ```bash
   rg -n 'Mistral.*OF''F|durable AnswerPacket pers''istence|Settings does not expos''e|Active constellation.*ABS''ENT|runtime emission not wir''ed' docs Epistemos EpistemosTests
   ```

2. Re-run source-only checks first if disk is still tight:

   ```bash
   git diff --check
   xcrun swiftc -parse Epistemos/LocalAgent/AgentBlueprint.swift
   xcrun swiftc -parse Epistemos/LocalAgent/ConfidenceRouter.swift
   xcrun swiftc -parse Epistemos/Views/Settings/SettingsView.swift
   ```

3. Only after disk pressure clears, run the full acceptance build/smoke:

   - focused Swift tests for `AgentBlueprintTests`, `ConfidenceRouterTests`, `LocalAgentDiagnosticsTests`, `SDMessageTests`, `IncrementalToolCallDetectorTests`
   - one live local Research Assistant mission with cloud disabled
   - inspect persisted `SDMessage` rows for `answerPacketId`, `answerPacketUILabel`, and non-empty `answerPacketData`
   - inspect RunEventLog timeline for mission packet id, tool events, and completion packet metadata
