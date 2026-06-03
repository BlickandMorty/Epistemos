---
falsifier: F-KVByteBudgetCard
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/kv_byte_budget_card/result.json
---

# F-KVByteBudgetCard

## Purpose

This is the executable fixture-only KV accounting witness for the June 1
Semantic Working-Set Compiler bundle. It proves `KVByteBudgetCard` reports
model identity, context tokens, KV codec, predicted and observed KV bytes,
prompt-cache hit/miss tokens, quality caveat, and compatibility failures
separately from weight bytes.

## Command

```bash
Tools/falsifiers/f_kv_byte_budget_card.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/kv_byte_budget_card/result.json`

The artifact passes only when predicted and observed KV bytes are present,
bounded, and separate from weight bytes; prompt-cache hit/miss token counts are
reported separately; compatible cards carry no compatibility failures;
incompatible cards carry deterministic failure labels; compatibility failures
change the plan address; and missing model ID, codec, quality caveat, context
tokens, predicted bytes, or blank compatibility failures fail closed.

## Non-Promotion Rule

This falsifier does not restore KV pages, run prompt-cache reuse, decode a
model, call MLX/Metal, benchmark context length, install model assets, or mutate
route policy. It is an accounting and schema witness only. Live KV-Direct or
128K-context claims still require `F-KV-Direct-Gate` or a future measured gate.

## Queue Effect

`F-KVByteBudgetCard` closes the KV byte-budget fixture from the Semantic
Working-Set Compiler build order. Cold-fault learning, working-set oracle
baseline, and source-to-residency no-poison promotion guards now have primary
witnesses too, so this bundle's metadata-only gates no longer need to be rebuilt
from scratch.
