# F-GemmaLocalArtifactAcquisitionPlan - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Verdict

PASS as metadata-only T1/L1 research-to-build evidence.

`F-GemmaLocalArtifactAcquisitionPlan` consumes
`F-GemmaDirectHarnessFirstRuntimeProofReceiptGate` and proves the missing
Gemma model-artifact step is now fail-closed. It pins three source cards:

- `google/gemma-4-E2B-it-qat-q4_0-gguf`, revision
  `1894d1fc0a19d86697abd40483f5983c867df03f`,
  `gemma-4-E2B_q4_0-it.gguf`, `3349514112` bytes.
- `google/gemma-4-E4B-it-qat-q4_0-gguf`, revision
  `bb3b92e6f031fa438b409f898dd9f14f499a0cb0`,
  `gemma-4-E4B_q4_0-it.gguf`, `5154939136` bytes.
- `litert-community/gemma-4-12B-it-litert-lm`, revision
  `44cf85a326f79b814fa86a60af414c042755b43a`,
  `gemma-4-12B-it.litertlm`, `6547589312` bytes.

The witness allows only owner-provided existing local files or owner-approved
quarantine imports/downloads. It rejects treating `llama-cli -hf`,
`llama-server`, Hugging Face cache paths, model cards, repo revisions, download
completion, local endpoints, or hidden providers as Epistemos runtime proof.

## Evidence

- Command: `Tools/falsifiers/f_gemma_local_artifact_acquisition_plan.sh`
- Artifact:
  `artifacts/falsifiers/gemma_local_artifact_acquisition_plan/result.json`
- Source primitive:
  `agent_core/src/uas/gemma_local_artifact_acquisition_plan.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_gemma_local_artifact_acquisition_plan.rs`

The artifact passes with 3 source cards, 4 allowed acquisition modes, 10 denied
proof shortcuts, 33 rejection policies, 38 red fixtures rejected, zero downloads
started, zero file opens, zero file hashes, zero path canonicalization, zero
commands armed or executed, zero server starts, zero model/runtime/provider
bytes loaded, zero route/default mutation, and zero L2/L3/T4 or user-facing
Gemma claim.

## Layer Truth

- L1 architecture/canon: advanced as metadata-only T1/L1.
- L2 capability route: unchanged; this does not run Gemma.
- L3 user-facing: unchanged; no settings row, receipt, default model, or user
  capability was activated.

Correct phrasing: "Gemma now has a fail-closed local artifact acquisition plan;
Gemma still has not run locally inside Epistemos."

## Next

`gemma_direct_harness_owner_approved_first_runtime_execution_probe` can only
proceed after the owner supplies or approves an exact local E2B/E4B GGUF file
and the follow-up path manifest, sha256, byte-count, command, receipt, rollback,
RunEventLog, and AnswerPacket proof are present.
