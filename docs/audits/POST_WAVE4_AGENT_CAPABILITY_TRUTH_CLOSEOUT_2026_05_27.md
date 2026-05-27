# Post-Wave-4 Agent Capability Truth Closeout - 2026-05-27

Status: closed by existing runtime surfaces plus a focused source guard.

This audit was opened from
`docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`, which kept visible
agent capability truth as the next low-conflict terminal. Reading current code
showed the live product path is already wired: RuntimeRouter derives the state,
Settings and model pickers display it, and AgentBlueprint persists it into the
MissionPacket contract.

## What Is Live

- `RuntimeRouter.agentCapabilityBadgeData(forLocalModelID:)` derives
  `HONEST`, `EXPERIMENTAL`, or `OFF`.
- `F-LocalToolUse` guards every local model that claims `canActAsAgent`.
- `SettingsView` appends the badge to local model picker labels and shows the
  active local agent badge with witness/falsifier text.
- `RootView.LocalModelToolbarMenu` includes the agent badge in local model
  subtitles used by chat/landing-compatible picker surfaces.
- `ActiveConstellationRow` shows runtime temperature, agent badge, and schema
  mode per model.
- `AgentBlueprintSettingsView` shows badge strips in the selector and the
  MissionPacket preview.
- `AgentBlueprintModelChoice` writes badges, strict grammar status, execution
  policy, and cloud-escalation policy into the command text and metadata.

## Honest States

- `HONEST`: the model has a witnessed local tool path and the lane can honor its
  native grammar. Falsifier: `F-LocalToolUse`.
- `EXPERIMENTAL`: the model has tool-use signals or grammar support, but the
  named local falsifier is still pending for that family.
- `OFF`: no model witness or experimental grammar support exists, or the lane
  exposes no local tool-call path.

## Guard Added

`EpistemosTests/AgentCapabilityTruthCloseoutTests.swift` pins:

1. RuntimeRouter badge derivation for `HONEST`, `EXPERIMENTAL`, and `OFF`.
2. Settings/model-picker/ActiveConstellation/AgentBlueprint source surfaces.
3. The old `AgentCommandCenter` donor shell stays absent.

## No-Orphan Check

- Motion: Project/Verify runtime capability truth onto user-visible model and
  agent surfaces.
- UAS: no new address type; this is a visible truth projection over existing
  runtime/model paths.
- Plane: Controller + Verification.
- Residency: local MLX/GGUF/cloud/Apple lane residency remains explicit through
  `RuntimeLane` and the badge witness.
- WBO/error: unsupported or unproven capability is `OFF` or `EXPERIMENTAL`, not
  silently promoted.
- Witness: RuntimeRouter lane capability, LocalTextModelID witness, and
  F-LocalToolUse.
- Falsifier: `F-LocalToolUse`; source guard added here.
- Tier: current app / verified floor.
- Rollback: no migration. A failing guard reopens W-12 without changing runtime
  behavior.

## Result

Do not dispatch another broad Agent Capability Truth terminal. The next active
product-floor terminal is Provenance / Residency Detail. Research-floor
hardware witnesses remain separate.
