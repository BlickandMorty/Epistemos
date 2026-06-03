---
falsifier: F-ProofCarryingRouteCard
status: PASS
artifact: artifacts/falsifiers/proof_carrying_route_card/result.json
command: Tools/falsifiers/f_proof_carrying_route_card.sh
created_on: 2026-06-03
---

# F-ProofCarryingRouteCard

## Scope

`F-ProofCarryingRouteCard` is the second Meta Control primary witness after
`F-MetaBreakthrough-CardRegistry`. It proves route decisions are carried by
typed route cards before later Rust route-kernel model checking can cite them.

Each card binds route ID, mission ID, preconditions, postconditions, budget
invariants, state transition, allowed mutations, rollback handle, proof or
model-check artifact, pinned toolchain version, AnswerPacket reference, and
required AnswerPacket fields.

This is metadata-only architecture work. It does not load model bytes, wake
70B tiles, repair Qwen/GGUF shards, call a provider, or mutate live route
policy.

## Artifact

```text
artifacts/falsifiers/proof_carrying_route_card/result.json
```

## What Passed

- Three route cards are present: cold assembly verification, lattice
  abstention, and SwiftLM source intake.
- Every card binds mission, route, precondition, postcondition, budget,
  transition, mutation, rollback, proof/model-check artifact, pinned
  toolchain, and AnswerPacket evidence.
- The route-card registry address is deterministic:
  `uas:route-card:50d71586af9c33b985b925f9e59818851d4b5615a4154856fda8ce404a7d7bd6`.
- Duplicate cards, missing preconditions, missing postconditions, missing
  rollback, missing proof artifact, unpinned toolchain, missing AnswerPacket,
  budget increase, and hidden live mutation fixtures reject.
- Runtime/model bytes loaded remain `0`.

## Current Meaning

The default main-only architecture cursor moves from:

```text
F-ProofCarryingRouteCard
```

to:

```text
F-RustRouteKernel-ModelCheck
```

The 70B large-local-model architecture remains preserved as proof-carrying
cold assembly, route control, continuity, cold-miss learning, source-intake,
meta-control card, and proof-route-card work. The Qwen/GGUF 128K shard repair
and provider-reference prompt lanes remain deferred unless
`EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1` is explicitly set for a heavy probe.

## Verification Command

```bash
Tools/falsifiers/f_proof_carrying_route_card.sh
```
