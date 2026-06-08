---
falsifier: F-GemmaQATRuntimeReplayExecutionArtifactGate
date: 2026-06-08
artifact: artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/result.json
scope: metadata-only L1/T1 Gemma E2B GGUF one-token execution artifact schema gate
---

# F-GemmaQATRuntimeReplayExecutionArtifactGate

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

`F-GemmaQATRuntimeReplayExecutionArtifactGate` is a metadata-only L1/T1 parser
gate for the future owner-approved Gemma E2B GGUF/llama.cpp one-token runtime
artifact. It consumes `F-GemmaQATOwnerApprovedRuntimeReplayProbe` and defines
the exact manifest fields and rejection policies required before any later
execution can count as evidence.

- command: `Tools/falsifiers/f_gemma_qat_runtime_replay_execution_artifact_gate.sh`
- path: `artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/result.json`
- required future manifest fields: 23
- required rejection policies: 20
- red fixtures rejected: 49
- model/runtime/provider bytes loaded: 0
- commands executed: 0
- first tokens observed: 0
- raw prompt/output/stdout/stderr bytes captured: 0
- metadata-only: yes
- L2/L3 effect: none
- next cursor: `gemma_qat_owner_approved_runtime_replay_execution_probe`

This witness does not approve owner paths, open model files, run llama.cpp,
capture a token, prove quality, prove memory fit, prove Swift MLX or LiteRT
parity, make Gemma the live app default, or promote MAS/L2/L3/T4 product
capability.
