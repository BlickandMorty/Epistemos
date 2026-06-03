---
falsifier: F-LatticeStateController
created_on: 2026-06-03
artifact: artifacts/falsifiers/lattice_state_controller/result.json
command: Tools/falsifiers/f_lattice_state_controller.sh
status: PRIMARY METADATA-ONLY WITNESS IMPLEMENTED
---

# F-LatticeStateController

## Purpose

Prove the route-controller layer after the 70B cold assembly plan: a tiny
lattice/recurrent controller must improve route decisions over static policy
baselines and must abstain when uncertainty or conflict is high.

The witness constructs a metadata-only `LatticeStateController` over UAS
addresses. It binds:

- source cards and task signature;
- abstract route state and candidate route actions;
- selected action and static-policy comparison action;
- monotone progress, uncertainty, conflict, and verifier-feedback scores;
- fallback, rollback, and AnswerPacket reference;
- static, random, and always-retrieve baselines.

No model bytes are loaded. No PatternBoost output, cold assembly, mmap, MLX,
Metal, GGUF, provider call, or live route policy mutation becomes hidden live
authority.

## Current Result

PASS on 2026-06-03 as a metadata-only primary witness:

```text
artifacts/falsifiers/lattice_state_controller/result.json
```

The controller selects `verify` in the low-conflict route fixture, abstains in
the high-uncertainty fixture, beats static/random/always-retrieve baselines on
quality, evidence validity, verifier score, route success, abstention accuracy,
active bytes, and cold stall, and rejects missing rollback, missing
AnswerPacket, hidden live authority, hidden-chain exposure, high-uncertainty
non-abstention, and an unbeaten static-policy baseline.

## Meaning

This finishes the default Research Construction cursor that came after
`F-ColdAssemblyPlan-70B-Lite`.

`F-ReasoningStateContinuity` is now implemented as
`docs/falsifiers/F-ReasoningStateContinuity_2026_06_03.md` with artifact
`artifacts/falsifiers/reasoning_state_continuity/result.json`. The 70B
architecture track remains active as proof-carrying cold assembly, route
control, and continuity-card work, while deferred Qwen/GGUF and
provider-reference prompt-level probes stay opt-in heavy work.

The next default Research Construction cursor is:

```text
F-ColdMissLedger
```

## Axis Floor

The schema floor is recorded in
`docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` under
`F-LatticeStateController`.

## Command

```bash
Tools/falsifiers/f_lattice_state_controller.sh
```
