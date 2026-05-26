# Wave 3 / Wave 4 Terminal Dispatch - 2026-05-26

Status: next architecture work from current `main`.

Use this when opening fresh Codex/Claude/Codex-YOLO terminals after the
Wave-2 merge and stash recovery closeout.

Authoritative starting point:

- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/audits/LEGENDARY_POST_WAVE2_ROLLUP_2026_05_26.md`
- `artifacts/lattice-coordinate-explainer/index.html`

Do not start by applying stashes. The active stash recovery queue is closed by
`docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md` and
`docs/audits/STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md`.

## Already Done

- T0 Verified Floor / Settings Truth, including T25 ACS naming lint.
- T1 Runtime Router.
- S Hyperdynamic Schema Loop.
- B-prime Chat citation / provenance UI.
- D-prime Substrate Health row expansion.
- F-prime Falsifier round 2.
- T14 UAS five-plane bridge.
- ACS production gate and CSISafeguard caller gate.

## Universal Prompt Header

Paste this at the top of every new terminal prompt:

```text
You are continuing Epistemos from current main.

cd /Users/jojo/Downloads/Epistemos
git fetch origin
git checkout -b <branch-name> origin/main

Read first:
1. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
2. docs/audits/LEGENDARY_POST_WAVE2_ROLLUP_2026_05_26.md
3. docs/audits/WAVE3_WAVE4_TERMINAL_DISPATCH_2026_05_26.md
4. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md

Rules:
- Do not pop or drop stashes.
- Do not use git checkout from stash.
- Do not bulk apply old work.
- No git add -A.
- Every PR includes: Motion, UAS address, Plane, Residency, WBO/error policy,
  Witness, Falsifier, Tier, Rollback.
- Build/test before PR.
- Stop after PR open; do not merge yourself.
```

## Terminal 1 - AgentBlueprint Replay UI

Branch:

```text
codex/wave3-agentblueprint-replay-ui-2026-05-26
```

Goal:

Make an AgentBlueprint run visible and replayable end to end:
`AgentBlueprint -> MissionPacket -> RunEventLog -> AnswerPacket -> chat row`.

Scope:

1. Add an end-to-end test that creates a minimal AgentBlueprint run and proves
   a replayable AnswerPacket is emitted.
2. Add a System G timeline replay surface that reads RunEventLog events without
   inventing new state.
3. Show deterministic replay status in the existing chat/agent surfaces.
4. Keep the UI compact; do not resurrect the old Agent Command Center shell.

Acceptance:

- A run can be replayed from persisted RunEventLog facts.
- The visible AnswerPacket matches the replay source.
- Failure states are explicit: missing event, missing packet, invalid proof.

## Terminal 2 - Agent Metadata Badges

Branch:

```text
codex/wave3-agent-metadata-badges-2026-05-26
```

Goal:

Every model/agent surface shows honest capability state:
`HONEST`, `EXPERIMENTAL`, or `OFF`.

Scope:

1. Add per-model agent badge data from the Runtime Router lane capabilities.
2. Surface badges in Settings, model picker, and any AgentBlueprint selector.
3. Keep local model claims grounded in `F-LocalToolUse` and route evidence.
4. Do not mark a model as agent-capable unless the named falsifier passes or the
   UI labels it experimental.

Acceptance:

- No hidden "Agent OK" claim without lane witness.
- Power-user mode does not silently upgrade a model into an honest agent.
- Tests cover disabled, experimental, and verified states.

## Terminal 3 - UAS Typed Retrieval / ClaimLedger Bridge

Branch:

```text
codex/wave4-uas-typed-retrieval-claimledger-2026-05-26
```

Goal:

Move the UAS doctrine from Settings witnesses into the data plane.

Scope:

1. `hybrid_search` returns typed `Vec<UasAddress>` or a backwards-compatible
   wrapper carrying typed addresses.
2. Agent traces carry `UasKind`.
3. `AcsAnchor` lands in ClaimLedger where claims cross admission/proof
   boundaries.
4. Update docs/falsifiers or artifacts only when the harness actually measures
   the path.

Acceptance:

- Retrieval traces can be joined to ClaimLedger / AnswerPacket by typed address.
- No string-only address escape hatch for new code.
- Existing product retrieval continues to work.

## Terminal 4 - Page Gather / Vault Escalation

Branch:

```text
codex/wave4-page-gather-vault-escalation-2026-05-26
```

Goal:

Make `page_gather` escalate through vault retrieval instead of staying a tested
substrate primitive with no product caller.

Scope:

1. Identify the current retrieval path used by chat and Shadow/Halo surfaces.
2. Add the smallest production caller that can invoke page-gather when the
   query needs assembly beyond lexical recall.
3. Emit visible trace data into the existing VaultRecall / AnswerPacket
   provenance surfaces.

Acceptance:

- The escalation is visible in a provenance card or health row.
- No green chip until a falsifier or replay trace proves the product path.
- Legacy fallback remains available and logged.

## Terminal 5 - Cognitive DAG Visualizer

Branch:

```text
codex/wave4-cognitive-dag-visualizer-2026-05-26
```

Goal:

Show live Cognitive DAG counts and selected relationships without slowing the
snappy graph/editor path.

Scope:

1. Read the current Cognitive DAG projection/count APIs.
2. Add a lightweight visualizer in `Epistemos/Views/Graph/` or the existing
   provenance/graph surface.
3. Add performance guards for node-count and edge-count rendering.
4. Preserve current graph defaults and gravity/physics performance.

Acceptance:

- No per-frame allocations from the new surface.
- Large graphs remain responsive.
- Graph performance tests continue to pass.

## Terminal 6 - Tri-Fusion Typed Mutations

Branch:

```text
codex/wave4-trifusion-typed-mutations-2026-05-26
```

Goal:

Model-authored note edits become typed operations in `agent_runtime`, not loose
text patches.

Scope:

1. Read `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`.
2. Map current MutationEnvelope / ProposedEnvelope / ClaimLedger surfaces.
3. Add the narrowest typed mutation path for one safe note-edit operation.
4. Ensure admission, witness, rollback, and provenance are all visible.

Acceptance:

- One model-authored note edit travels as a typed mutation.
- Rollback is deterministic.
- No direct text mutation bypasses the envelope.

## Side Hardener Terminals

These can run in parallel with Wave 3 or Wave 4:

1. W-49: `IMessageDriverService` App Store guard.
2. W-50: `MemoryTier` enum reconciliation.
3. W-53: `ModelDownloadManager` SHA256 / LFS verification.
4. D-27: scoped `F-ACS-Anchor-Addressing` harness.

Use one branch per hardener. Keep each PR small.

## Merge Order

Recommended order:

1. Agent Metadata Badges.
2. AgentBlueprint Replay UI.
3. W-49 / W-50 / W-53 hardeners.
4. UAS Typed Retrieval / ClaimLedger Bridge.
5. Page Gather / Vault Escalation.
6. Cognitive DAG Visualizer.
7. Tri-Fusion Typed Mutations.
8. D-27 scoped ACS anchor harness once the bridge is stable.

Run local gates between merges because CI can be account-locked:

```text
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

## What This Is Not

- Not a stash recovery plan.
- Not a replay of old AgentCommandCenter files.
- Not a raw lattice explainer implementation order.
- Not a claim that every W-row is complete.

This is the next executable architecture wave from current main.
