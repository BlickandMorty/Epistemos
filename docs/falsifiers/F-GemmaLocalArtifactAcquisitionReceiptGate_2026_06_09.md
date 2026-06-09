# F-GemmaLocalArtifactAcquisitionReceiptGate - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

`F-GemmaLocalArtifactAcquisitionReceiptGate` consumes
`F-GemmaLocalArtifactAcquisitionCommandCard` and freezes the future receipt
contract required after an owner-approved Gemma artifact acquisition. It is
metadata-only: it writes zero receipts, reads zero receipts, opens zero local
files, computes zero hashes, canonicalizes zero paths, starts zero downloads,
arms zero commands, executes zero commands, starts zero servers, loads zero
model/runtime/provider bytes, stores zero raw owner paths, and makes no Gemma
live/default/L2/L3/T4/user-facing claim.

## Evidence

- Command:
  `Tools/falsifiers/f_gemma_local_artifact_acquisition_receipt_gate.sh`
- Artifact:
  `artifacts/falsifiers/gemma_local_artifact_acquisition_receipt_gate/result.json`
- UAS primitive:
  `agent_core/src/uas/gemma_local_artifact_acquisition_receipt_gate.rs`
- Binary:
  `agent_core/src/bin/falsify_gemma_local_artifact_acquisition_receipt_gate.rs`

The artifact passes with 24 required receipt fields, 4 selectable command-card
IDs, 12 denied shortcuts, 32 rejection policies, and 36 red fixtures rejected.

## Meaning

The future acquisition receipt must bind owner approval, selected command-card
ID, model ID, filename, source revision, expected bytes, acquisition mode,
path digest, local sha256, local byte count, tool digest, disk-space
observation, rollback, RunEventLog, AnswerPacket, abstention, and
non-promotion. Public repo metadata, download completion, HF cache paths,
ETags, local endpoints, and servers are not runtime proof.

## Layer Truth

- L1 architecture/canon: advanced as metadata-only T1/L1.
- L2 capability route: unchanged and still red.
- L3 user-facing / release readiness: unchanged and still red.

Correct phrasing: "Gemma now has an acquisition receipt contract; no Gemma
artifact has been acquired, hashed, loaded, run, admitted, or made user-facing."
