---
falsifier: F-MetaBreakthrough-CardRegistry
status: PASS
artifact: artifacts/falsifiers/meta_breakthrough_card_registry/result.json
command: Tools/falsifiers/f_meta_breakthrough_card_registry.sh
created_on: 2026-06-03
---

# F-MetaBreakthrough-CardRegistry

## Scope

`F-MetaBreakthrough-CardRegistry` is the first Meta Control witness after the
Research Construction Engine source-intake ladder. It proves that small
meta-control cards are not free-floating doctrine: every card must bind a UAS
address, source reference, budget vector, rollback handle, proof/falsifier
state, AnswerPacket visibility, and shadow-only route authority before future
route policy can cite it.

This is metadata-only architecture work. It does not import SwiftLM code, load
model bytes, mutate route policy, or promote 70B runtime/product claims.

## Artifact

```text
artifacts/falsifiers/meta_breakthrough_card_registry/result.json
```

## What Passed

- Five meta-control cards are present: proof-carrying route, brain route, KV
  page control, cold assembly, and SwiftLM source intake.
- Every card has a deterministic UAS address, source reference, bounded active
  and cold-I/O budget, rollback handle, proof/falsifier state, and
  AnswerPacket reference.
- The registry address is deterministic regardless of input card order.
- Duplicate cards, missing UAS address, missing source, missing budget, missing
  rollback, missing proof state, missing AnswerPacket, and hidden live route
  authority fixtures reject.
- Runtime/model bytes loaded remain `0`.

## Current Meaning

The default main-only architecture cursor moves from:

```text
F-MetaBreakthrough-CardRegistry
```

to:

```text
F-ProofCarryingRouteCard
```

The 70B large-local-model architecture track remains preserved as
proof-carrying cold assembly and route-card work. Qwen/GGUF 128K shards and
provider-reference prompts remain deferred unless
`EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1` is explicitly set for a long-context
probe.

## Verification Command

```bash
Tools/falsifiers/f_meta_breakthrough_card_registry.sh
```
