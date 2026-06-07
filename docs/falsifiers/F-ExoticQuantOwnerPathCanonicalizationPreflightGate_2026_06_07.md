# F-ExoticQuantOwnerPathCanonicalizationPreflightGate - 2026-06-07

Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only primary witness.

- Command: `Tools/falsifiers/f_exotic_quant_owner_path_canonicalization_preflight_gate.sh`
- Artifact: `artifacts/falsifiers/exotic_quant_owner_path_canonicalization_preflight_gate/result.json`
- Upstream: `F-ExoticQuantOwnerPathManifestIntakeGate`
- Scope: T1/L1 research-to-build architecture only
- ProductBuild: Pro
- ProStatus: ResearchCandidate
- L2 capability route: unchanged / still red
- L3 user-facing route: unchanged / not green

## What This Proves

`F-ExoticQuantOwnerPathCanonicalizationPreflightGate` compiles the fail-closed path policy that must exist before exotic quant rows can consume owner-supplied local paths. It does not read owner manifest bytes, does not store raw or canonical paths, does not canonicalize paths, does not open files, does not hash artifacts, does not follow symlinks, does not arm commands, does not import loaders, and promotes no capability.

Accepted rows:

- `YTan2000/Qwopus3.5-27B-v3-TQ3_4S` -> fail-closed path policy compiled, owner manifest still absent, file access blocked.
- `caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5` -> fail-closed path policy compiled, owner manifest still absent, file access blocked.
- `mudler/Qwopus-MoE-35B-A3B-APEX-GGUF` -> fail-closed path policy compiled, owner manifest still absent, file access blocked.
- `nvidia/Gemma-4-31B-IT-NVFP4` -> server/GPU canonicalization preflight denied for Mac.
- `Intel/gemma-4-31B-it-int4-AutoRound` -> server/GPU canonicalization preflight denied for Mac.

## Measurements

- Gate cards: `5`
- Mac fail-closed policies compiled: `3`
- Server-only canonicalization denials: `2`
- Owner manifests present: `0`
- Owner-supplied paths present: `0`
- Raw paths stored: `0`
- Canonical paths bound: `0`
- Path digest attempts: `0`
- Path canonicalization attempts: `0`
- Path open attempts: `0`
- File stat calls: `0`
- File hash attempts: `0`
- Symlink resolution attempts: `0`
- Selected artifact bytes sum: `96318502063`
- Maximum minimum UMA bytes required: `39108307031`
- Red fixtures rejected: `69`
- Command executions: `0`
- Model bytes loaded: `0`
- Runtime bytes loaded: `0`
- Provider calls: `0`
- Source tree bytes read: `0`
- Product bytes copied: `0`
- Benchmark runs: `0`
- Next research-to-build cursor: `exotic_quant_owner_path_byte_envelope_preflight_gate` (now landed downstream as `F-ExoticQuantOwnerPathByteEnvelopePreflightGate`)

## Non-Promotion Boundary

This witness does not prove owner approval, local artifact availability, path safety, byte-envelope success, loader execution, first token, quality, Apple Silicon fit, coding/research usefulness, MAS readiness, L2 capability, or L3 WRV. It only fixes the policy contract that rejects unsafe path shapes and blocks file access before owner-supplied paths can be considered by later gates.

The correct phrasing is: architecture cursor advanced; product capability / user surface did not.

## Failure Classes Rejected

The red fixtures reject duplicate IDs, missing expected models, bad source-pin refs, bad byte-budget refs, owner manifest leaks, owner path leaks, raw path storage, canonical path binding, path digest shortcuts, relative paths, tilde expansion, environment expansion, parent traversal, unicode control characters, NUL characters, symlink following, missing allowed-root policy, file open/stat/hash/symlink allowances, armed commands, command execution, runtime probes, missing rollback/RunEventLog/AnswerPacket/abstention surfaces, MAS/product route enablement, hidden route/cloud/PatternBoost/lattice/Eidos authority, L2/L3 promotion, live dense 70B claims, SSD-as-RAM claims, source import, benchmark-as-fit laundering, nonzero model/runtime/provider/source/product bytes, bad proof refs, and bad next cursor.

## Why It Exists

The large-local-model track is now folding QAT, TurboVec-adjacent compression, TurboQuant-like formats, GGUF, HLWQ, APEX, NVFP4, and AutoRound into Epistemos as research-to-build architecture rather than product hype. This gate makes path policy fail-closed before the system can ever normalize owner-supplied paths, touch local files, or consider command envelopes.

This gate now feeds the landed `F-ExoticQuantOwnerPathByteEnvelopePreflightGate`; the next required proof object is `exotic_quant_crash_safe_command_envelope_preflight_gate`. Only after crash-safe command envelopes, owner-approved probes, rollback, and visible packets exist can runtime experiments be considered.
