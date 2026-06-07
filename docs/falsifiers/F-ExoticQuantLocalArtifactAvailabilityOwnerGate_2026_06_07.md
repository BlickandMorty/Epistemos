# F-ExoticQuantLocalArtifactAvailabilityOwnerGate - 2026-06-07

Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only primary witness.

- Command: `Tools/falsifiers/f_exotic_quant_local_artifact_availability_owner_gate.sh`
- Artifact: `artifacts/falsifiers/exotic_quant_local_artifact_availability_owner_gate/result.json`
- Upstream: `F-ExoticQuantLoaderCompatibilityModelPathGate`
- Scope: T1/L1 research-to-build architecture only
- ProductBuild: Pro
- ProStatus: ResearchCandidate
- L2 capability route: unchanged / still red
- L3 user-facing route: unchanged / not green

## What This Proves

`F-ExoticQuantLocalArtifactAvailabilityOwnerGate` consumes the loader/path gate and proves that exact exotic quant rows remain fail-closed when no owner-approved local artifact manifest exists. It does not open paths, stat files, hash weights, resolve symlinks, arm commands, run loaders, or promote product capability.

Accepted rows:

- `YTan2000/Qwopus3.5-27B-v3-TQ3_4S` -> owner path manifest required, no owner manifest present, no local path verified.
- `caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5` -> owner path manifest required, no owner manifest present, no local path verified.
- `mudler/Qwopus-MoE-35B-A3B-APEX-GGUF` -> owner path manifest required, no owner manifest present, no local path verified.
- `nvidia/Gemma-4-31B-IT-NVFP4` -> server/GPU artifact probe denied on Mac.
- `Intel/gemma-4-31B-it-int4-AutoRound` -> server/GPU artifact probe denied on Mac.

## Measurements

- Gate cards: `5`
- Owner manifests required: `3`
- Owner manifests present: `0`
- Owner manifests approved: `0`
- Local path verified count: `0`
- Path canonicalization required: `3`
- Path canonicalized count: `0`
- Server-only artifact denied count: `2`
- Red fixtures rejected: `66`
- Command executions: `0`
- Owner manifest bytes read: `0`
- Path open attempts: `0`
- File stat calls: `0`
- File hash attempts: `0`
- Symlink resolution attempts: `0`
- Model bytes loaded: `0`
- Runtime bytes loaded: `0`
- Provider calls: `0`
- Source tree bytes read: `0`
- Product bytes copied: `0`
- Benchmark runs: `0`
- Next research-to-build cursor: `exotic_quant_owner_path_manifest_intake_gate` (now landed downstream; downstream path-canonicalization preflight is also landed; downstream next is `exotic_quant_owner_path_byte_envelope_preflight_gate`)

## Non-Promotion Boundary

This witness does not prove a local model exists on disk, a path is safe, a loader can execute, Apple Silicon fit, first token, quality, coding/research usefulness, MAS readiness, L2 capability, or L3 WRV. It only prevents future work from treating local-looking artifact names, Downloads folklore, or loader metadata as path availability proof.

The correct phrasing is: architecture cursor advanced; product capability / user surface did not.

## Failure Classes Rejected

The red fixtures reject duplicate IDs, missing expected models, bad source-pin binding, bad selected artifact paths, bad availability states, bad hardware/runtime/action profiles, owner manifest leaks, owner approval leaks, owner manifest digest binding without the later gate, path canonicalization shortcuts, local path verification, directory-entry laundering, server-only Mac artifact allowance, armed commands, command execution, path opens, file stats, file hashes, symlink following, runtime probes, missing rollback/RunEventLog/AnswerPacket/abstention surfaces, MAS/product route enablement, hidden route/cloud/PatternBoost/lattice/Eidos authority, L2/L3 promotion, live dense 70B claims, SSD-as-RAM claims, source import, benchmark-as-fit laundering, nonzero owner-manifest/model/runtime/provider/source/product bytes, bad proof refs, and bad next cursor.

## Why It Exists

The large-local-model track is becoming more practical because QAT, TurboVec-adjacent compression, TurboQuant-like formats, GGUF, HLWQ, APEX, NVFP4, and AutoRound may shrink selected artifacts or active compute. That ambition is useful only if Epistemos can keep every step witnessed. This gate makes local artifact availability an owner-approved manifest problem rather than a hidden filesystem guess.

The downstream `F-ExoticQuantOwnerPathManifestIntakeGate` has landed as a metadata-only T1/L1 witness at `artifacts/falsifiers/exotic_quant_owner_path_manifest_intake_gate/result.json`.

The downstream `F-ExoticQuantOwnerPathCanonicalizationPreflightGate` has now landed. The next required proof object is `exotic_quant_owner_path_byte_envelope_preflight_gate`. Only after byte-envelope preflight can crash-safe command envelopes and owner-approved probes be considered.
