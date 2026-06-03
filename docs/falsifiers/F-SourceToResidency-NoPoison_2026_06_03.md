---
falsifier: F-SourceToResidency-NoPoison
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/source_to_residency_no_poison/result.json
---

# F-SourceToResidency-NoPoison

## Purpose

This is the executable fixture-only source-promotion witness for the June 1
Semantic Working-Set Compiler bundle. It proves source-derived layout, cache,
route, and prompt patches remain shadow candidates and cannot promote from
poisoned, stale/corrupted, private, license-blocked, low-credibility, unknown,
missing-falsifier, missing-rollback, or empty affected-organ fixtures.

## Command

```bash
Tools/falsifiers/f_source_to_residency_no_poison.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/source_to_residency_no_poison/result.json`

The artifact passes only when patch addresses are deterministic, patch kinds
cover layout/cache/route/prompt, the source graph address and digest are bound,
import gate / required falsifier / rollback are present, all successful patches
stay `shadow_candidate`, and all blocked source classes fail closed before any
layout, cache, prompt, or route policy can mutate.

## Non-Promotion Rule

This falsifier does not fetch sources, import code, rewrite layout, mutate cache
state, mutate route policy, alter prompts, decode model/KV pages, call
MLX/Metal, or promote a live source-derived policy. It is a schema and safety
gate only. Runtime source-derived policy still needs working-set oracle
baseline, rollback, RunEventLog, and AnswerPacket evidence; the cold-fault
learning witness now exists but remains non-promotional.

## Queue Effect

`F-SourceToResidency-NoPoison` closes the source-to-residency no-poison fixture
from the Semantic Working-Set Compiler build order. The remaining unfinished
gate in this bundle is working-set oracle baseline.
