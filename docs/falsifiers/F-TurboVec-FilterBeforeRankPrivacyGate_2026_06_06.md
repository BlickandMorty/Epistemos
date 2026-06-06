---
title: F-TurboVec-FilterBeforeRankPrivacyGate
created_on: 2026-06-06
status: PASS
artifact: artifacts/falsifiers/turbovec_filter_before_rank_privacy_gate/result.json
scope: metadata-only T1/L1
---

# F-TurboVec-FilterBeforeRankPrivacyGate - 2026-06-06

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Verdict

PASS as a metadata-only primary witness. `F-TurboVec-FilterBeforeRankPrivacyGate` turns the prior `F-TurboVec-UASAddressStableExternalIds` witness into a fail-closed retrieval privacy rule: Scope/Sovereign allowlists must compile to UAS-derived external `u64` IDs before any TurboVec/Eidos adapter rank, score, or result exposure can happen.

Artifact:

- `artifacts/falsifiers/turbovec_filter_before_rank_privacy_gate/result.json`
- Command: `Tools/falsifiers/f_turbovec_filter_before_rank_privacy_gate.sh`
- Primitive: `agent_core/src/uas/turbovec_filter_before_rank_privacy_gate.rs`
- Binary: `agent_core/src/bin/falsify_turbovec_filter_before_rank_privacy_gate.rs`

## What Passed

- 1 accepted filter-before-rank privacy gate plan.
- 5 synthetic scenarios: one allowed, all denied, duplicate allowed IDs, unknown ID probe, and forbidden-plane probe.
- 67 red fixtures rejected.
- 0 forbidden/private/unknown candidates scored by the adapter.
- 0 forbidden/private/unknown candidates exposed in results.
- Deterministic privacy gate address:
  `turbovec_filter_before_rank_privacy_gate_plan:de30abe8e8e7564126ffac2452b6af6eff19db6249b0909306cb3b9d4ad74c53@1779039200000`
- Next research-to-build unit:
  `turbovec_crash_safe_persistent_index_plan`

## Hardening Axes

The witness proves:

- the upstream stable-ID registry must already be PASS and point at this cursor;
- UAS-derived external IDs are required before allowlists can cite TurboVec candidates;
- Scope-Rex and SovereignGate are mandatory before compressed retrieval scoring;
- allowlists compile before rank/search, and post-rank filtering rejects;
- forbidden-plane, private-scope, and unknown-ID candidates cannot be scored or exposed;
- unknown IDs reject, duplicate allowlist IDs dedupe, and empty allowlists emit visible AnswerPackets;
- exposed allowed results require exact source checks after rank;
- forbidden-hit audit refs, rollback, RunEventLog, AnswerPacket, and compatibility fence are required;
- search/index/model/runtime/provider/product-file byte counts remain zero;
- hidden route authority, Eidos-as-live-router, route mutation, hidden cloud fallback, MAS/Live/T2+ promotion, live dense 70B, and SSD-as-RAM claims reject.

## Scope Boundary

This advances L1 architecture cursor truth only for the TurboVec compressed-retrieval research branch. It does not import TurboVec code, build or persist an index, prove recall quality, load Gemma/QAT/GGUF/MLX/LiteRT, choose RuntimeRouter/System G routes, advance L2 capability, or make L3 user-facing model capability green.

Correct phrasing:

> Architecture cursor for TurboVec privacy hardening advanced; product capability and user surface did not.

## Next

The next retrieval/index research-to-build unit is `turbovec_crash_safe_persistent_index_plan`, because filter-before-rank privacy is now specified before any persistent compressed index can be trusted.
