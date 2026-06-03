---
falsifier: F-SourceSignalGraph-Intake
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/source_signal_graph_intake/result.json
---

# F-SourceSignalGraph-Intake

## Purpose

This is the executable metadata-only source intake witness for the June 1
Semantic Working-Set Compiler bundle. It proves that bookmark, repo, paper,
doc, and X bookmark source fixtures become deterministic `SourceCard`s with
digest, credibility rank, license/usage note, privacy class, source type,
route affinity, and no-poison status before they can influence a working-set
plan.

## Command

```bash
Tools/falsifiers/f_source_signal_graph_intake.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/source_signal_graph_intake/result.json`

The artifact passes only when source cards are sorted deterministically, the
graph address is order-stable, all five source families are present, blocked
sources are rejected, blocked-source edges are dropped, duplicate source IDs
fail closed, bad digests fail closed, unknown edge endpoints fail closed, and
source metadata carries digest, credibility, usage, privacy, no-poison, and
route-affinity coverage.

## Non-Promotion Rule

This falsifier does not fetch sources, import external code, mutate route
policy, promote layout/cache patches, run MLX/Metal, or install model assets.
It is a schema and provenance gate only: source-derived motifs remain inert
until later working-set, page-table, no-poison, rollback, and AnswerPacket
witnesses pass.

## Queue Effect

`F-SourceSignalGraph-Intake` closes the first schema-only source intake item
from the Semantic Working-Set Compiler build order. The next work in that
bundle remains deterministic task query emission and residency page-table
addressability; the already-existing `F-SemanticWorkingSetPlan-Budget` witness
continues to cover budget rejection before runtime wake paths.
