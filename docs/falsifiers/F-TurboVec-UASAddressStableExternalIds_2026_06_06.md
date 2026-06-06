---
title: F-TurboVec-UASAddressStableExternalIds
created_on: 2026-06-06
status: PASS
artifact: artifacts/falsifiers/turbovec_uas_address_stable_external_ids/result.json
scope: metadata-only T1/L1
---

# F-TurboVec-UASAddressStableExternalIds - 2026-06-06

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Verdict

PASS as a metadata-only primary witness. `F-TurboVec-UASAddressStableExternalIds` turns the prior `F-TurboVec-Eidos-CompressedIndex-Plan` into a typed UAS-to-`u64` external-ID registry plan before any TurboVec index bytes, recall-quality claims, route mutation, or product surfaces can cite compressed retrieval.

Artifact:

- `artifacts/falsifiers/turbovec_uas_address_stable_external_ids/result.json`
- Command: `Tools/falsifiers/f_turbovec_uas_address_stable_external_ids.sh`
- Primitive: `agent_core/src/uas/turbovec_stable_external_id_registry_plan.rs`
- Binary: `agent_core/src/bin/falsify_turbovec_uas_address_stable_external_ids.rs`

## What Passed

- 1 accepted stable-ID registry plan.
- 2 active entries, 1 tombstoned entry, and 1 reinserted generation fixture.
- 1 collision-ledger row proving alias rejection and deterministic reallocation.
- 55 red fixtures rejected.
- Deterministic registry set address:
  `turbovec_stable_external_id_registry_plan:ae1b3fc3949acde1280012131e10616882005dcc58965f1db30a33cd2cfe93b0@1779039100000`
- Next research-to-build unit:
  `turbovec_filter_before_rank_privacy_gate_plan`

## Hardening Axes

The witness proves:

- same UAS address maps to the same external `u64` ID across rebuild order;
- SQLite `rowid`, insert order, and mutable vector slots are rejected as identity sources;
- duplicate UAS addresses, duplicate active external IDs, zero IDs, and mismatched IDs reject;
- deleted IDs require tombstone retention;
- reinserted logical sources require a higher generation;
- collisions require an explicit ledger, alias rejection, deterministic resolved ID, and rebuild flag;
- AppColdStore remains truth and the registry is only a rebuildable cache manifest;
- allowlists must compile from UAS identity before later rank/search gates;
- export/import roundtrip, atomic manifest, corrupt-manifest rebuild, rollback, RunEventLog, AnswerPacket, and compatibility fence are required;
- registry/index/model/runtime/provider/product-file byte counts remain zero;
- hidden route authority, route mutation, hidden cloud fallback, MAS/Live/T2+ promotion, live dense 70B, and SSD-as-RAM claims reject.

## Scope Boundary

This advances L1 architecture cursor truth only for the TurboVec compressed-retrieval research branch. It does not import TurboVec code, build a compressed index, persist registry bytes, run recall, load Gemma/QAT/GGUF/MLX/LiteRT, choose RuntimeRouter/System G routes, advance L2 capability, or make L3 user-facing model capability green.

Correct phrasing:

> Architecture cursor for TurboVec identity hardening advanced; product capability and user surface did not.

## Next

The next retrieval/index research-to-build unit is `turbovec_filter_before_rank_privacy_gate_plan`, because stable UAS external IDs are now specified before privacy allowlists and search masks can be proved.
