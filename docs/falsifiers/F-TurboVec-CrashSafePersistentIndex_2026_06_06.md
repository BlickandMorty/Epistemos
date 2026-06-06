---
title: F-TurboVec-CrashSafePersistentIndex
created_on: 2026-06-06
status: PASS
artifact: artifacts/falsifiers/turbovec_crash_safe_persistent_index/result.json
scope: metadata-only T1/L1
---

# F-TurboVec-CrashSafePersistentIndex - 2026-06-06

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Verdict

PASS as a metadata-only primary witness. `F-TurboVec-CrashSafePersistentIndex` turns the prior `F-TurboVec-FilterBeforeRankPrivacyGate` witness into a fail-closed persistent-index plan: `.tvim` / manifest cache material must be atomic, digest-bound, rollback-capable, rebuildable from AppColdStore truth, and unable to promote itself into route authority or product capability.

Artifact:

- `artifacts/falsifiers/turbovec_crash_safe_persistent_index/result.json`
- Command: `Tools/falsifiers/f_turbovec_crash_safe_persistent_index.sh`
- Primitive: `agent_core/src/uas/turbovec_crash_safe_persistent_index_plan.rs`
- Binary: `agent_core/src/bin/falsify_turbovec_crash_safe_persistent_index.rs`

## What Passed

- 1 accepted crash-safe persistent-index plan.
- 4 planned persistent files: `IdMapTvim`, `ManifestJson`, `TempFile`, and `PreviousManifestPointer`.
- 9 crash/corruption/compatibility scenarios: clean commit, partial write, corrupt magic, version mismatch, digest mismatch, duplicate external ID, missing AppColdStore source, permission denied, and stale manifest pointer.
- 89 red fixtures rejected.
- Deterministic persistent-index plan address:
  `turbovec_crash_safe_persistent_index_plan:04b2c79884199631f604c3436b157ac988b988c991ff266fe7d443ab52d9371b@1779039300000`
- Next research-to-build unit after recall quality, latency/memory abstention, and runtime shadow planning:
  `turbovec_quarantine_adapter_microbench_probe`

## Hardening Axes

The witness proves:

- the upstream filter-before-rank privacy gate must already be PASS and point at this cursor;
- `.tvim` / manifest paths must be content-addressed under AppColdStore cache material, not treated as durable truth;
- temp writes, fsync policy, atomic rename, previous-manifest retention, manifest digest, magic/version checks, and source-card refs are required;
- duplicate external IDs, zero IDs, digest mismatch, corrupt magic, version mismatch, stale manifest pointer, missing AppColdStore source, and permission-denied promotion all fail closed;
- partial writes roll back to the prior manifest and corrupt cache files rebuild from AppColdStore truth;
- rollback, RunEventLog, AnswerPacket, and compatibility fence are required for every failure scenario;
- model/index/runtime/provider/product-file byte counts remain zero;
- hidden route authority, Eidos-as-live-router, route mutation, hidden cloud fallback, MAS/Live/T2+ promotion, live dense 70B, and SSD-as-RAM claims reject.

## Scope Boundary

This advances L1 architecture cursor truth only for the TurboVec compressed-retrieval research branch. It does not import TurboVec code, write `.tv` / `.tvim` files, open model/index bytes, prove recall quality, prove latency, load Gemma/QAT/GGUF/MLX/LiteRT, choose RuntimeRouter/System G routes, advance L2 capability, or make L3 user-facing model capability green. Exact-baseline recall quality is now covered by `F-TurboVec-RecallQualityExactBaseline`, and latency/memory abstention is now covered by `F-TurboVec-LatencyMemoryAbstention`.

Correct phrasing:

> Architecture cursor for TurboVec persistence hardening advanced; product capability and user surface did not.

## Next

The recall-quality unit is now covered by `F-TurboVec-RecallQualityExactBaseline`, latency/memory abstention is now covered by `F-TurboVec-LatencyMemoryAbstention`, and runtime shadow benchmark planning is now covered by `F-TurboVec-RuntimeShadowBenchmarkPlan`. The next retrieval/index research-to-build unit is `turbovec_quarantine_adapter_microbench_probe`, because compressed retrieval still needs a quarantined, non-authoritative adapter microbench before it can help large-local-model context selection.
