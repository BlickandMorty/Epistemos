---
falsifier: F-ReasoningStateContinuity
created_on: 2026-06-03
artifact: artifacts/falsifiers/reasoning_state_continuity/result.json
command: Tools/falsifiers/f_reasoning_state_continuity.sh
status: PRIMARY METADATA-ONLY WITNESS IMPLEMENTED
---

# F-ReasoningStateContinuity

## Purpose

Prove useful resumable state can improve continuity and cache utility without
leaking hidden reasoning, bypassing verification, reusing stale state, or
mutating live cache/runtime policy.

The witness constructs a metadata-only `ReasoningStateContinuityCard` over UAS
addresses. It binds:

- session, model, source cards, and task signature;
- preserved state kind and privacy class;
- visible summary, cache key, restore policy, compatibility fence, verifier
  caveat, purge policy, and ComputeResumeLease reference;
- fallback, rollback, and AnswerPacket reference;
- no-state, naive-cache, and static-summary baselines.

No model bytes are loaded. No hidden chain-of-thought is persisted or exposed.
The preserved state is context and cache policy only, not proof.

## Current Result

PASS on 2026-06-03 as a metadata-only primary witness:

```text
artifacts/falsifiers/reasoning_state_continuity/result.json
```

The card beats all three baselines on continuity, cache utility, verifier
score, latency, and active bytes. It rejects missing purge policy, incompatible
compatibility fence, missing AnswerPacket, hidden-chain exposure, verifier
bypass, stale-state reuse, and an unbeaten naive-cache baseline.

## Meaning

This finishes the default Research Construction cursor that came after
`F-LatticeStateController`. The 70B architecture track now has proof-carrying
cold assembly, route control, and safe continuity-card witnesses while
Qwen/GGUF and provider-reference prompt-level probes remain opt-in heavy work.

`F-ColdMissLedger` is now implemented as
`docs/falsifiers/F-ColdMissLedger_2026_06_03.md` with artifact
`artifacts/falsifiers/cold_miss_ledger/result.json`.

The next default Research Construction cursor is:

```text
F-SwiftLM-SourceIntake
```

## Axis Floor

The schema floor is recorded in
`docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` under
`F-ReasoningStateContinuity`.

## Command

```bash
Tools/falsifiers/f_reasoning_state_continuity.sh
```
