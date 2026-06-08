---
falsifier: F-GemmaQATOwnerApprovedRuntimeReplayProbe
date: 2026-06-08
artifact: artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_probe/result.json
scope: metadata-only L1/T1 Gemma E2B GGUF runtime replay probe envelope
---

# F-GemmaQATOwnerApprovedRuntimeReplayProbe

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

`F-GemmaQATOwnerApprovedRuntimeReplayProbe` is a metadata-only L1/T1
side-ladder witness for the smallest Gemma 4 E2B QAT GGUF/llama.cpp runtime
replay probe envelope. It consumes
`F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate` and binds the selected
E2B GGUF transcript card to an offline one-token command template, owner
approval pending state, model-path pending state, forbidden download/server/
mmap args, redacted prompt/output digest policies, fresh memory sample
requirements, cancellation, rollback, RunEventLog, AnswerPacket, abstention,
and non-promotion.

- command: `Tools/falsifiers/f_gemma_qat_owner_approved_runtime_replay_probe.sh`
- path: `artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_probe/result.json`
- accepted probe envelopes: 1
- selected lane: `google/gemma-4-E2B-it-qat-q4_0-gguf` via GGUF/llama.cpp
- red fixtures rejected: 45
- model/runtime/provider bytes loaded: 0
- commands executed: 0
- first tokens observed: 0
- raw prompt/output/stdout/stderr bytes captured: 0
- metadata-only: yes
- L2/L3 effect: none
- next cursor: `gemma_qat_runtime_replay_execution_artifact_gate`

This witness does not approve owner paths, open model files, run llama.cpp,
capture a token, prove quality, prove memory fit, prove Swift MLX or LiteRT
parity, make Gemma the live app default, or promote MAS/L2/L3/T4 product
capability.
