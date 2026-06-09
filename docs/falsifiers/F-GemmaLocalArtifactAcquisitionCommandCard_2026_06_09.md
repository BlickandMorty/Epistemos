# F-GemmaLocalArtifactAcquisitionCommandCard - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

`F-GemmaLocalArtifactAcquisitionCommandCard` consumes
`F-GemmaLocalArtifactAcquisitionPlan` and freezes the owner-approval-pending
command-card shapes for future Gemma artifact acquisition. It is metadata-only:
it starts zero downloads, opens zero files, hashes zero files, canonicalizes
zero paths, arms zero commands, executes zero commands, starts zero servers,
loads zero model/runtime/provider bytes, stores zero raw owner paths, and makes
no Gemma live/default/L2/L3/T4/user-facing claim.

## Evidence

- Command:
  `Tools/falsifiers/f_gemma_local_artifact_acquisition_command_card.sh`
- Artifact:
  `artifacts/falsifiers/gemma_local_artifact_acquisition_command_card/result.json`
- UAS primitive:
  `agent_core/src/uas/gemma_local_artifact_acquisition_command_card.rs`
- Binary:
  `agent_core/src/bin/falsify_gemma_local_artifact_acquisition_command_card.rs`

The artifact passes with 4 command cards, 3 acquisition-mode families, 17
required receipt fields, 10 denied shortcuts, 30 rejection policies, planned
artifact bytes `18401556672`, 31 red fixtures rejected, and next cursor
`gemma_local_artifact_acquisition_receipt_gate`.

## Meaning

The next Gemma step is no longer vague "download the model." The allowed future
paths are explicit and owner-gated:

- owner provides an existing local E2B file
- owner approves HF snapshot download to quarantine for E2B
- owner approves HF snapshot download to quarantine for E4B
- owner approves LiteRT-LM import to quarantine for 12B

All paths still require post-acquisition local-file sha256, byte count, path
digest, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion
proof before any runtime receipt or System G admission can consume them.
This command-card rung feeds `F-GemmaLocalArtifactAcquisitionReceiptGate`
before any owner-approved runtime execution probe.

## Layer Truth

- L1 architecture/canon: advanced as metadata-only T1/L1.
- L2 capability route: unchanged and still red.
- L3 user-facing / release readiness: unchanged and still red.

Correct phrasing: "Gemma now has visible acquisition command cards; no Gemma
artifact has been acquired, loaded, run, admitted, or made user-facing."
